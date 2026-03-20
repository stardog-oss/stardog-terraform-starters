#!/usr/bin/env bash

set -euo pipefail
TF_BACKEND_RG=${TF_BACKEND_RG:-CHANGE_ME_RG}
TF_BACKEND_SA=${TF_BACKEND_SA:-CHANGE_ME_SA}
TF_BACKEND_CONTAINER=${TF_BACKEND_CONTAINER:-tfstate}

NAME_PREFIX=$(grep -E '^\s*name_prefix\s*=' terraform.tfvars | head -n1 | awk -F'=' '{gsub(/["[:space:]]/, "", $2); print $2}')
KEY_DEFAULT="envs/${NAME_PREFIX:-training-sandboxes}/middleware/terraform.tfstate"
KEY=${TF_BACKEND_KEY:-$KEY_DEFAULT}

if [[ "${1:-}" == "--delete-backend" ]]; then
  echo "About to delete backend blob:\n  account: ${TF_BACKEND_SA}\n  container: ${TF_BACKEND_CONTAINER}\n  blob: ${KEY}"
  if [[ "${TF_BACKEND_FORCE_DELETE:-}" != "true" ]]; then
    read -r -p "Type DELETE to confirm: " CONFIRM
    if [[ "${CONFIRM}" != "DELETE" ]]; then
      echo "Aborted. Backend blob not deleted." >&2
      exit 1
    fi
  fi

  az storage blob delete \
    --account-name "${TF_BACKEND_SA}" \
    --container-name "${TF_BACKEND_CONTAINER}" \
    --name "${KEY}" \
    --auth-mode login

  echo "Deleted backend blob: ${KEY} (if it existed)."
  exit 0
fi

echo "${KEY}"

terraform init \
  -backend-config="resource_group_name=${TF_BACKEND_RG}" \
  -backend-config="storage_account_name=${TF_BACKEND_SA}" \
  -backend-config="container_name=${TF_BACKEND_CONTAINER}" \
  -backend-config="key=${KEY}" \
  -backend-config="use_azuread_auth=true" \
  "$@"
