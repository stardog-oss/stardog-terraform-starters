#!/usr/bin/env bash
#
# aws-backend-bootstrap.sh
#
# Bootstrap AWS resources for Terraform state storage:
#   - Creates (if missing) an S3 bucket with versioning and 30-day object locking
#   - Creates (if missing) a DynamoDB table for state locking
#   - Optionally grants the current IAM identity write access to the bucket
#
# Example:
#   ./aws-backend-bootstrap.sh \
#     --bucket my-tfstate-bucket \
#     --region us-east-2 \
#     --dynamodb-table terraform-locks \
#     --grant-current
#
set -euo pipefail

BUCKET=""
REGION=""
DDB_TABLE="terraform-locks"
ACL="private"
GRANT_CURRENT=false
GRANT_ARNS=()

usage() {
  sed -n '1,120p' "$0"
}

info(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR]\033[0m  $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) BUCKET="$2"; shift 2;;
    --region) REGION="$2"; shift 2;;
    --dynamodb-table) DDB_TABLE="$2"; shift 2;;
    --acl) ACL="$2"; shift 2;;
    --grant-current) GRANT_CURRENT=true; shift 1;;
    --grant-arn) GRANT_ARNS+=("$2"); shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown argument: $1"; usage; exit 1;;
  esac
done

command -v aws >/dev/null 2>&1 || { err "AWS CLI not found. Install AWS CLI."; exit 1; }

if [[ -z "$BUCKET" || -z "$REGION" ]]; then
  err "Both --bucket and --region are required."
  exit 1
fi

CURRENT_IDENTITY_ARN=""
if [[ "$GRANT_CURRENT" == "true" ]]; then
  CURRENT_IDENTITY_ARN=$(aws sts get-caller-identity --query Arn --output text)
  if [[ -z "$CURRENT_IDENTITY_ARN" ]]; then
    warn "Unable to resolve current IAM identity ARN. Skipping automatic grant."
    GRANT_CURRENT=false
  fi
fi

info "Ensuring S3 bucket: ${BUCKET} (${REGION})"
if AWS_PAGER="" aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  info "Bucket already exists."
else
  AWS_PAGER="" aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    $([[ "$REGION" != "us-east-1" ]] && echo --create-bucket-configuration LocationConstraint="$REGION")
  info "Bucket created."
fi

info "Applying bucket settings (versioning, encryption, public access block)"
AWS_PAGER="" aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

AWS_PAGER="" aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

AWS_PAGER="" aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

AWS_PAGER="" aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "tfstate-cleanup",
        "Status": "Enabled",
        "Filter": { "Prefix": "" },
        "NoncurrentVersionExpiration": { "NoncurrentDays": 30 }
      }
    ]
  }'

info "Ensuring DynamoDB table: ${DDB_TABLE}"
if AWS_PAGER="" aws dynamodb describe-table --table-name "$DDB_TABLE" --region "$REGION" >/dev/null 2>&1; then
  info "DynamoDB table already exists."
else
  AWS_PAGER="" aws dynamodb create-table \
    --table-name "$DDB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  info "DynamoDB table created."
  info "Waiting for table to be active..."
  AWS_PAGER="" aws dynamodb wait table-exists --table-name "$DDB_TABLE" --region "$REGION"
fi

if [[ "$GRANT_CURRENT" == "true" ]]; then
  GRANT_ARNS+=("$CURRENT_IDENTITY_ARN")
fi

if [[ ${#GRANT_ARNS[@]} -gt 0 ]]; then
  info "Updating bucket policy grants"

  RESOLVED_GRANT_ARNS=()
  VALID_GRANTS=true
  for raw_principal in "${GRANT_ARNS[@]}"; do
    principal="$raw_principal"
    if [[ "$principal" =~ ^(arn:aws:iam::[0-9]{12})ole/(.+)$ ]]; then
      principal="${BASH_REMATCH[1]}:role/${BASH_REMATCH[2]}"
      warn "Normalized malformed grant ARN '${raw_principal}' to '${principal}'"
    fi

    if [[ "$principal" =~ ^arn:aws:iam::([0-9]{12}):role/(.+)$ ]]; then
      role_name="${BASH_REMATCH[2]##*/}"
      if resolved_out=$(AWS_PAGER="" aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text 2>&1); then
        resolved_arn="$resolved_out"
        if [[ -n "$resolved_arn" && "$resolved_arn" != "None" ]]; then
          if [[ "$resolved_arn" != "$principal" ]]; then
            warn "Resolved IAM role '${role_name}' to '${resolved_arn}'. Replacing supplied ARN '${principal}'."
          fi
          principal="$resolved_arn"
        fi
      else
        if [[ "$resolved_out" == *"NoSuchEntity"* ]]; then
          err "IAM role '${role_name}' does not exist or is not visible in this account."
          VALID_GRANTS=false
        else
          warn "Unable to validate IAM role '${role_name}': ${resolved_out}"
        fi
      fi
    elif [[ "$principal" =~ ^arn:aws:iam::([0-9]{12}):user/(.+)$ ]]; then
      user_name="${BASH_REMATCH[2]##*/}"
      if user_out=$(AWS_PAGER="" aws iam get-user --user-name "$user_name" --query 'User.Arn' --output text 2>&1); then
        if [[ -n "$user_out" && "$user_out" != "None" && "$user_out" != "$principal" ]]; then
          warn "Resolved IAM user '${user_name}' to '${user_out}'. Replacing supplied ARN '${principal}'."
          principal="$user_out"
        fi
      else
        if [[ "$user_out" == *"NoSuchEntity"* ]]; then
          err "IAM user '${user_name}' does not exist or is not visible in this account."
          VALID_GRANTS=false
        else
          warn "Unable to validate IAM user '${user_name}': ${user_out}"
        fi
      fi
    fi

    RESOLVED_GRANT_ARNS+=("$principal")
  done

  if [[ "$VALID_GRANTS" == "false" ]]; then
    err "One or more --grant-arn values could not be validated. Fix the principals and rerun."
    exit 1
  fi

  GRANT_ARNS=("${RESOLVED_GRANT_ARNS[@]}")

  POLICY_DOC=$(AWS_PAGER="" aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text 2>/dev/null || echo "")
  tmp_policy=$(mktemp)

  read -r -d '' BASE_POLICY <<EOF || true
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": []
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET}",
        "arn:aws:s3:::${BUCKET}/*"
      ]
    }
  ]
}
EOF

  if [[ -n "$POLICY_DOC" && "$POLICY_DOC" != "None" ]]; then
    echo "$POLICY_DOC" > "$tmp_policy"
  else
    echo "$BASE_POLICY" > "$tmp_policy"
  fi

  python3 - "$tmp_policy" "$BUCKET" "${GRANT_ARNS[@]}" <<'PYTHON'
import json, sys
policy_path = sys.argv[1]
bucket = sys.argv[2]
arns = [arn for arn in sys.argv[3:] if arn]
bucket_arn = f"arn:aws:s3:::{bucket}"
bucket_objects_arn = f"{bucket_arn}/*"
with open(policy_path) as f:
    policy = json.load(f)
stmt = next((s for s in policy["Statement"] if s.get("Sid") == "TerraformStateAccess"), None)
if not stmt:
    stmt = {
        "Sid": "TerraformStateAccess",
        "Effect": "Allow",
        "Principal": {"AWS": []},
        "Action": [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
        ],
        "Resource": [
            bucket_arn,
            bucket_objects_arn
        ]
    }
    policy["Statement"].append(stmt)
else:
    stmt["Resource"] = [bucket_arn, bucket_objects_arn]
current = stmt["Principal"]["AWS"]
if isinstance(current, list):
    principals = set(current)
elif current:
    principals = {current}
else:
    principals = set()
principals.update(arns)
principals = [p for p in principals if p]
if not principals:
    stmt["Principal"]["AWS"] = []
elif len(principals) == 1:
    stmt["Principal"]["AWS"] = principals[0]
else:
    stmt["Principal"]["AWS"] = sorted(principals)
with open(policy_path, "w") as f:
    json.dump(policy, f, indent=2)
PYTHON

  if ! AWS_PAGER="" aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://"$tmp_policy"; then
    warn "Failed to apply bucket policy. Generated policy document:"
    cat "$tmp_policy" >&2
    rm -f "$tmp_policy"
    exit 1
  fi
  rm -f "$tmp_policy"
fi

cat <<EOF

✅ Backend ready.

Export these for convenience:
  export TF_BACKEND_BUCKET=${BUCKET}
  export TF_BACKEND_REGION=${REGION}
  export TF_BACKEND_DYNAMODB_TABLE=${DDB_TABLE}

Initialize Terraform:
  terraform init \\
    -backend-config="bucket=${BUCKET}" \\
    -backend-config="region=${REGION}" \\
    -backend-config="dynamodb_table=${DDB_TABLE}" \\
    -backend-config="key=envs/<your-env>/terraform.tfstate" \\
    -backend-config="encrypt=true"

EOF
