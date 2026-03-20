# Terraform Remote State — Backend Setup

## AWS S3/DynamoDB backend

### Bootstrap bucket, table, and policy
```bash
./scripts/aws-backend-bootstrap.sh \
  --bucket proserv-tfstate-usw1 \
  --region us-west-1 \
  --dynamodb-table terraform-locks \
  --grant-arn arn:aws:iam::651105574733:role/proserv-tfstate-access
```

### Create IAM role for Terraform state access

`trust-proserv-tfstate.json`
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::651105574733:root" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

`policy-proserv-tfstate.json`
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::proserv-tfstate-usw1"
    },
    {
      "Sid": "TerraformStateObjectAccess",
      "Effect": "Allow",
      "Action": ["s3:GetObject","s3:PutObject","s3:DeleteObject"],
      "Resource": "arn:aws:s3:::proserv-tfstate-usw1/*"
    }
  ]
}
```

```bash
aws iam create-role \
  --role-name proserv-tfstate-access \
  --assume-role-policy-document file://trust-proserv-tfstate.json

aws iam put-role-policy \
  --role-name proserv-tfstate-access \
  --policy-name terraform-state-access \
  --policy-document file://policy-proserv-tfstate.json
```

> ⚠️ Assign the role: update your IAM users/groups to allow `sts:AssumeRole` into `proserv-tfstate-access` (for example via a group policy or trust condition) before running Terraform.

## Azure Blob backend

### One-time bootstrap
```bash
./scripts/azurerm-backend-bootstrap.sh   --rg tfstate-rg   --location eastus   --storage-account tfstateacct123   --container tfstate   --subscription <SUBSCRIPTION_ID>
```

### Initialize backend in this env
```bash
export TF_BACKEND_RG=tfstate-rg
export TF_BACKEND_SA=tfstateacct123
export TF_BACKEND_CONTAINER=tfstate

cd envs/profile-01b~azure-nginx
./init_backend.sh
```

State key used:
```
envs/profile-01b~azure-nginx/terraform.tfstate
```
