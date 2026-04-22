#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <source-training-sandboxes-dir>" >&2
  exit 1
fi

SOURCE_ROOT=$(cd "$1" && pwd)

link_tfvars() {
  local source_dir=$1
  local target_dir=$2
  local source_file="${SOURCE_ROOT}/${source_dir}/terraform.tfvars"
  local target_file="${SCRIPT_DIR}/${target_dir}/terraform.tfvars"

  if [[ ! -f "${source_file}" ]]; then
    echo "Skipping ${target_dir}: missing ${source_file}" >&2
    return 0
  fi

  ln -sfn "${source_file}" "${target_file}"
  echo "Linked ${target_file} -> ${source_file}"
}

link_tfvars "bootstrap" "bootstrap"
link_tfvars "infra" "infra"
link_tfvars "middleware" "middleware-envoy"
link_tfvars "middleware-cilium" "middleware-cilium"
link_tfvars "stardog" "stardog"
