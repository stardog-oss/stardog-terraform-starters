#!/usr/bin/env bash

set -euo pipefail

: "${TF_VAR_inst_id:?Set TF_VAR_inst_id before running init_backend.sh}"

if [ ! -d "../../modules/kubernetes/stardog" ]; then
  cat >&2 <<'EOF'
This stack must run from:

  stardog-terraform-starters/stacks/stardog-terraform-lab

Move it under the starter repo's stacks/ directory, then run init again.
EOF
  exit 1
fi

STARDOG_TF_BACKEND_RG="${STARDOG_TF_BACKEND_RG:-sd-proserv-rg}"
STARDOG_TF_BACKEND_SA="${STARDOG_TF_BACKEND_SA:-sdtraining}"
STARDOG_TF_BACKEND_CONTAINER="${STARDOG_TF_BACKEND_CONTAINER:-sdtraining-tfstate}"
STARDOG_TF_BACKEND_KEY="${STARDOG_TF_BACKEND_KEY:-envs/${TF_VAR_inst_id}/stardog/terraform.tfstate}"

terraform init \
  -backend-config="resource_group_name=${STARDOG_TF_BACKEND_RG}" \
  -backend-config="storage_account_name=${STARDOG_TF_BACKEND_SA}" \
  -backend-config="container_name=${STARDOG_TF_BACKEND_CONTAINER}" \
  -backend-config="key=${STARDOG_TF_BACKEND_KEY}" \
  -backend-config="use_azuread_auth=true" \
  "$@"
