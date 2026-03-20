#!/usr/bin/env bash
set -euo pipefail

if ! kubectl get storageclass "$DESIRED_SC" >/dev/null 2>&1; then
  echo "StorageClass $DESIRED_SC not found; skipping default annotation."
  exit 0
fi

existing_defaults=$(kubectl get storageclass -o jsonpath='{range .items[*]}{@.metadata.name}{"\t"}{@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}' \
  | awk -v desired="$DESIRED_SC" '$2=="true" && $1!=desired {print $1}')

if [[ -n "$existing_defaults" ]]; then
  for sc in $existing_defaults; do
    kubectl annotate storageclass "$sc" storageclass.kubernetes.io/is-default-class- --overwrite >/dev/null 2>&1 || true
  done
fi

kubectl annotate storageclass "$DESIRED_SC" storageclass.kubernetes.io/is-default-class="true" --overwrite >/dev/null
