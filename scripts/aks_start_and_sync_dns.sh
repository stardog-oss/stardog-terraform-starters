#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: aks_start_and_sync_dns.sh <environment-dir>

Starts the AKS cluster, waits for it to report Running, fetches the
Envoy Gateway IP, and rewrites the DNS root + wildcard records to that IP.

Requirements:
  - az CLI (logged in, subscription selected)
  - terraform (state initialized/applied for the environment)
  - jq
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

ENV_DIR=$(cd "$1" && pwd)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HELPER="${SCRIPT_DIR}/get_service_lb_ip.py"

if [[ ! -x "$HELPER" ]]; then
  echo "Helper script not found at $HELPER" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if ! TF_JSON=$(terraform -chdir="$ENV_DIR" output -json 2>/dev/null); then
  echo "terraform output failed; run terraform apply in $ENV_DIR first." >&2
  exit 1
fi

tf_val() {
  local key=$1
  local value
  value=$(echo "$TF_JSON" | jq -r --arg key "$key" '.[$key].value // empty' 2>/dev/null || echo "")
  [[ "$value" == "null" ]] && value=""
  echo "$value"
}

RG_NAME=$(tf_val "rg_name")
AKS_NAME=$(tf_val "aks_name")
ROOT_FQDN=$(tf_val "ingress_dns_root")
ZONE_NAME=$(tf_val "dns_zone_name")
ZONE_RG=$(tf_val "dns_zone_resource_group")
INST_ID=$(tf_val "inst_id")
GATEWAY_NAME=$(tf_val "envoy_gateway_name")
GATEWAY_NS=$(tf_val "envoy_gateway_namespace")

if [[ -z "$RG_NAME" || -z "$AKS_NAME" ]]; then
  echo "rg_name and aks_name outputs are required." >&2
  exit 1
fi

if [[ -z "$ROOT_FQDN" ]]; then
  echo "ingress_dns_root output is required." >&2
  exit 1
fi

if [[ -z "$INST_ID" ]]; then
  INST_ID=${ROOT_FQDN%%.*}
fi

if [[ -z "$ZONE_NAME" ]]; then
  ZONE_NAME=${ROOT_FQDN#${INST_ID}.}
fi

if [[ -z "$ZONE_RG" ]]; then
  ZONE_RG=$(az network dns zone list --query "[?name=='$ZONE_NAME'].resourceGroup" -o tsv | head -n 1)
fi

if [[ -z "$ZONE_RG" ]]; then
  echo "Unable to determine DNS zone resource group for zone $ZONE_NAME." >&2
  exit 1
fi

[[ -z "$GATEWAY_NAME" ]] && GATEWAY_NAME="${INST_ID}-envoy-gateway"
[[ -z "$GATEWAY_NS" ]] && GATEWAY_NS="envoy-gateway"

echo "Starting AKS cluster ${AKS_NAME}..."
az aks start -g "$RG_NAME" -n "$AKS_NAME" >/dev/null

echo -n "Waiting for cluster to report Running"
for _ in {1..30}; do
  STATE=$(az aks show -g "$RG_NAME" -n "$AKS_NAME" --query 'powerState.code' -o tsv)
  if [[ "$STATE" == "Running" ]]; then
    echo " -> Running"
    break
  fi
  printf '.'
  sleep 20
done

if [[ "$STATE" != "Running" ]]; then
  echo "Cluster failed to reach Running state." >&2
  exit 1
fi

KUBECONFIG_PATH="${HOME}/.kube/${AKS_NAME}.yaml"

LB_JSON=$(python3 "$HELPER" <<EOF
{
  "kind": "gateway",
  "name": "$GATEWAY_NAME",
  "namespace": "$GATEWAY_NS",
  "kubeconfig": "$KUBECONFIG_PATH",
  "aks_resource_group": "$RG_NAME",
  "aks_cluster_name": "$AKS_NAME"
}
EOF
)

LB_IP=$(echo "$LB_JSON" | jq -r '.ip // empty')

if [[ -z "$LB_IP" ]]; then
  echo "Failed to resolve Envoy Gateway IP." >&2
  exit 1
fi

echo "Gateway IP: $LB_IP"

ensure_record() {
  local name=$1
  if ! az network dns record-set a show -g "$ZONE_RG" -z "$ZONE_NAME" -n "$name" >/dev/null 2>&1; then
    az network dns record-set a create -g "$ZONE_RG" -z "$ZONE_NAME" -n "$name" --ttl 60 >/dev/null
  fi
  az network dns record-set a update -g "$ZONE_RG" -z "$ZONE_NAME" -n "$name" --set "arecords=[]" >/dev/null
  az network dns record-set a add-record -g "$ZONE_RG" -z "$ZONE_NAME" -n "$name" --ipv4-address "$LB_IP" >/dev/null
}

ROOT_RECORD="$INST_ID"
WILDCARD_RECORD="*.${INST_ID}"

echo "Updating DNS record ${ROOT_RECORD}.${ZONE_NAME}"
ensure_record "$ROOT_RECORD"

echo "Updating DNS record ${WILDCARD_RECORD}.${ZONE_NAME}"
ensure_record "$WILDCARD_RECORD"

echo "DNS synchronized."
