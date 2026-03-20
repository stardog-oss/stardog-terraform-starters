#!/usr/bin/env bash
#
# azurerm-backend-bootstrap.sh
#
# Bootstrap an Azure Storage backend for Terraform state AND grant data‑plane
# permissions (Storage Blob Data Contributor) to the current principal and/or
# additional groups/principals.
#
# Examples:
#   ./azurerm-backend-bootstrap.sh \
#     --rg tfstate-rg \
#     --location eastus \
#     --storage-account tfstateacct123 \
#     --container tfstate \
#     --subscription <SUBSCRIPTION_ID> \
#     --grant-current \
#     --grant-group 4bce3531-c720-41f0-acb8-b93ba6fa0182
#
#   # grant a specific principal (user/SP/managed identity objectId)
#   ./azurerm-backend-bootstrap.sh ... --grant-principal 00000000-0000-0000-0000-000000000000
#
# Notes:
# - Grants are applied at the **container** scope (least privilege for TF state).
# - Requires Azure CLI logged in with sufficient rights to create resources + role assignments.
#
set -euo pipefail

# --------------------------
# Defaults
# --------------------------
RG="tfstate-rg"
LOCATION="eastus"
SA=""
CONTAINER="tfstate"
SUBSCRIPTION_ID=""
ROLE_NAME="Storage Blob Data Contributor"   # data-plane access to blobs
GRANT_CURRENT=false
GRANT_GROUPS=()        # list of AAD group object IDs
GRANT_PRINCIPALS=()    # list of principal object IDs (users, SPs, MIs)

# --------------------------
# Args
# --------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rg) RG="$2"; shift 2;;
    --location) LOCATION="$2"; shift 2;;
    --storage-account) SA="$2"; shift 2;;
    --container) CONTAINER="$2"; shift 2;;
    --subscription) SUBSCRIPTION_ID="$2"; shift 2;;
    --role) ROLE_NAME="$2"; shift 2;;
    --grant-current) GRANT_CURRENT=true; shift 1;;
    --grant-group) GRANT_GROUPS+=("$2"); shift 2;;
    --grant-principal) GRANT_PRINCIPALS+=("$2"); shift 2;;
    -h|--help)
      sed -n '1,120p' "$0"; exit 0;;
    *)
      echo "Unknown arg: $1"; exit 1;;
  esac
done

# --------------------------
# Helpers
# --------------------------
info(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR]\033[0m  $*" >&2; }

require_az(){
  command -v az >/dev/null 2>&1 || { err "Azure CLI not found. Install Azure CLI."; exit 1; }
}

resolve_current_object_id(){
  # Try to determine the objectId of the signed-in entity.
  # Works for user (UPN) and service principal (appId).
  local user_type user_name oid
  user_type=$(az account show --query 'user.type' -o tsv 2>/dev/null || echo "")
  user_name=$(az account show --query 'user.name' -o tsv 2>/dev/null || echo "")
  if [[ -z "$user_type" || -z "$user_name" ]]; then
    warn "Could not resolve current Azure account context. Use --subscription and/or provide --grant-principal manually if needed."
    return 1
  fi
  if [[ "$user_type" == "user" ]]; then
    oid=$(az ad user show --id "$user_name" --query id -o tsv 2>/dev/null || true)
  else
    # servicePrincipal or application
    oid=$(az ad sp show --id "$user_name" --query id -o tsv 2>/dev/null || true)
  fi
  if [[ -z "$oid" ]]; then
    warn "Failed to resolve current principal objectId for user.type=$user_type name=$user_name. Provide --grant-principal <objectId>."
    return 1
  fi
  echo "$oid"
  return 0
}

assign_role_if_missing(){
  local principal_id="$1" scope="$2" role="$3"
  # Check if assignment exists
  local exists
  exists=$(az role assignment list \
    --assignee "$principal_id" \
    --scope "$scope" \
    --role "$role" \
    --query "[0].id" -o tsv 2>/dev/null || true)
  if [[ -n "$exists" ]]; then
    info "Role '$role' already assigned at scope: $scope  (principal: $principal_id)"
  else
    info "Granting role '$role' at scope: $scope  (principal: $principal_id)"
    az role assignment create --assignee "$principal_id" --role "$role" --scope "$scope" 1>/dev/null
  fi
}

# --------------------------
# Main
# --------------------------
require_az

if [[ -n "${SUBSCRIPTION_ID}" ]]; then
  info "Setting subscription: ${SUBSCRIPTION_ID}"
  az account set --subscription "${SUBSCRIPTION_ID}"
fi

if [[ -z "${SA}" ]]; then
  RAND=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 6)
  SA="tfstate${RAND}"
  info "Storage account not provided. Generated: ${SA}"
fi

info "Creating resource group: ${RG} (${LOCATION})"
az group create --name "${RG}" --location "${LOCATION}" 1>/dev/null

info "Creating storage account: ${SA}"
az storage account create \
  --name "${SA}" \
  --resource-group "${RG}" \
  --location "${LOCATION}" \
  --sku Standard_RAGRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  1>/dev/null

info "Enabling blob versioning, soft delete (30d), container soft delete (30d) & change feed"
az storage account blob-service-properties update \
  --account-name "${SA}" \
  --resource-group "${RG}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 30 \
  --enable-change-feed true \
  1>/dev/null

info "Creating state container: ${CONTAINER}"
az storage container create \
  --account-name "${SA}" \
  --name "${CONTAINER}" \
  --auth-mode login \
  1>/dev/null

# Build scopes
ACCOUNT_SCOPE=$(az storage account show -g "${RG}" -n "${SA}" --query id -o tsv)
CONTAINER_SCOPE="${ACCOUNT_SCOPE}/blobServices/default/containers/${CONTAINER}"

# Grants
if [[ "${GRANT_CURRENT}" == "true" ]]; then
  if oid=$(resolve_current_object_id); then
    assign_role_if_missing "$oid" "$CONTAINER_SCOPE" "$ROLE_NAME"
  else
    warn "Skipping --grant-current because current objectId could not be resolved."
  fi
fi

# Accept comma-separated or multiple flags for groups/principals
_norm_list(){
  local arr=()
  for item in "$@"; do
    IFS=',' read -ra parts <<< "$item"
    for p in "${parts[@]}"; do
      p_trim=$(echo "$p" | xargs)
      [[ -n "$p_trim" ]] && arr+=("$p_trim")
    done
  done
  echo "${arr[@]}"
}

if [[ ${#GRANT_GROUPS[@]} -gt 0 ]]; then
  read -r -a groups <<< "$(_norm_list "${GRANT_GROUPS[@]}")"
  for gid in "${groups[@]}"; do
    assign_role_if_missing "$gid" "$CONTAINER_SCOPE" "$ROLE_NAME"
  done
fi

if [[ ${#GRANT_PRINCIPALS[@]} -gt 0 ]]; then
  read -r -a pris <<< "$(_norm_list "${GRANT_PRINCIPALS[@]}")"
  for pid in "${pris[@]}"; do
    assign_role_if_missing "$pid" "$CONTAINER_SCOPE" "$ROLE_NAME"
  done
fi

cat <<EOF

✅ Backend ready.

Export these for convenience:
  export TF_BACKEND_RG=${RG}
  export TF_BACKEND_SA=${SA}
  export TF_BACKEND_CONTAINER=${CONTAINER}

Initialize Terraform:
  terraform init \\
    -backend-config="resource_group_name=${RG}" \\
    -backend-config="storage_account_name=${SA}" \\
    -backend-config="container_name=${CONTAINER}" \\
    -backend-config="key=envs/<your-env>/terraform.tfstate" \\
    -backend-config="use_azuread_auth=true"

RBAC granted at container scope: ${CONTAINER_SCOPE}
- Role: ${ROLE_NAME}
- Principals:
    - Current: ${GRANT_CURRENT}
    - Groups:   ${GRANT_GROUPS[*]:-"(none)"}
    - Explicit: ${GRANT_PRINCIPALS[*]:-"(none)"}

Tip: RBAC propagation can take a few minutes. If you still see 403s, wait and re-run 'terraform init -reconfigure'.
EOF
