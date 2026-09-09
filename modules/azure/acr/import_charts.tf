variable "import_charts" {
  description = "Whether to import Helm charts from OCI registries into the ACR. Runs locally via Helm and az CLI when true."
  type        = bool
  default     = false
}

variable "charts_to_import" {
  description = "List of OCI chart references to import (format: oci://host/repo/chart:version)."
  type        = list(string)
  default = [
    # Intentionally empty by default. Callers may set `charts_to_import` when
    # they want server-side import into the ACR.
  ]
}

variable "jfrog_registry_username" {
  description = "Optional JFrog registry username used for helm registry login. If left empty and a token is required, set jfrog_registry_password to the token and username to 'apikey' or as needed."
  type        = string
  default     = "apikey"
}

variable "jfrog_registry_password" {
  description = "JFrog registry password/token (sensitive). Set via TF_VAR_jfrog_registry_password or in a tfvars file."
  type        = string
  default     = ""
  sensitive   = true
}

resource "null_resource" "acr_import_charts" {
  # for_each over a set, not count over the list - see import_images.tf's acr_import resource for the
  # same fix and full rationale (reordering/inserting/removing then only affects that one entry).
  for_each = var.import_charts ? toset(var.charts_to_import) : []

  triggers = {
    chart = each.value
    acr   = local.acr_login_server
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<EOT
set -euo pipefail
CHART_REF="${each.value}"
JFROG_USER="${var.jfrog_registry_username}"
JFROG_PASS="${var.jfrog_registry_password}"
ACR_LOGIN_SERVER="${local.acr_login_server}"
ACR_NAME="${local.acr_name}"

echo "Preparing to import chart $${CHART_REF} into ACR $${ACR_LOGIN_SERVER} (server-side import)..."

# Ensure az CLI is authenticated and has permission to the target ACR
echo "Checking az CLI and ACR access..."
az account show >/dev/null 2>&1 || { echo "az CLI not logged in or not installed" >&2; exit 2; }

DEST_IMAGE="charts/$(echo "$${CHART_REF}" | sed -E 's|^.*/([^:]+):(.+)$|\1:\2|')"

# az acr import often expects the source in the form <registry>/<repo>:<tag> (no oci:// scheme).
SRC_NO_SCHEME="$${CHART_REF#oci://}"
echo "Using source=$${SRC_NO_SCHEME} for az import"

# Real bugs fixed in this block: (1) the command string (including the raw JFrog password) used to
# be echoed before eval'ing it, leaking the credential into apply/CI logs - the sibling
# import_images.tf never does this. (2) eval on a string built from unescaped image/tag
# substitutions was an injection risk if a charts_to_import entry ever contained shell
# metacharacters. (3) under this script's own `set -e`, "eval ...; RC=$?" never actually reached the
# RC=$? line on failure - the script aborted immediately, so the "try with creds, fall back without
# creds" retry never ran. Real `if cmd; then/else` conditionals (exempt from set -e) with direct,
# properly-quoted arguments fix all three at once.
if [ -n "$${JFROG_PASS}" ]; then
  echo "JFROG credentials provided — trying az acr import with --username/--password first"
  if az acr import --name "$${ACR_NAME}" --source "$${SRC_NO_SCHEME}" --image "$${DEST_IMAGE}" --username "$${JFROG_USER}" --password "$${JFROG_PASS}" --force; then
    echo "Imported $${CHART_REF} -> $${ACR_LOGIN_SERVER}/$${DEST_IMAGE} (via az acr import with creds)"
    exit 0
  fi
  echo "az acr import with creds failed; trying without creds next"
fi

echo "Attempting server-side import via az acr import (no source creds)..."
if az acr import --name "$${ACR_NAME}" --source "$${SRC_NO_SCHEME}" --image "$${DEST_IMAGE}" --force; then
  echo "Imported $${CHART_REF} -> $${ACR_LOGIN_SERVER}/$${DEST_IMAGE} (via az acr import)"
else
  echo "az acr import failed"
  if [ -n "$${JFROG_PASS}" ]; then
    echo "Falling back to Helm OCI pull / export / push flow"
    # Ensure helm exists and supports chart commands
    if ! command -v helm >/dev/null 2>&1; then
      echo "helm not found in PATH; cannot perform fallback import" >&2
      exit 3
    fi
    HELM_VER=$(helm version --short 2>/dev/null || true)
    echo "Detected Helm: $${HELM_VER}"
    # Try helm chart commands
    echo "Logging into source registry and pulling chart with Helm..."
    SOURCE_HOST=$(echo "$${CHART_REF}" | sed -E 's|^oci://([^/]+)/.*$|\\1|')
    echo "Logging into source registry $${SOURCE_HOST} as $${JFROG_USER}..."
    helm registry login "$${SOURCE_HOST}" --username "$${JFROG_USER}" --password "$${JFROG_PASS}"
    echo "Pulling chart $${CHART_REF}..."
    helm chart pull "$${CHART_REF}"
    WORKDIR=$(mktemp -d)
    echo "Exporting chart to $${WORKDIR}..."
    helm chart export "$${CHART_REF}" -d "$${WORKDIR}"
    TGZ_FILE=$(ls "$${WORKDIR}"/*.tgz | head -n1 || true)
    if [ -z "$${TGZ_FILE}" ]; then
      echo "Failed to find exported chart archive in $${WORKDIR}" >&2
      exit 4
    fi
    TGZ_BASENAME=$(basename "$${TGZ_FILE}")
    CHART_NAME_VER="$${TGZ_BASENAME%.tgz}"
    DEST_REF="oci://$${ACR_LOGIN_SERVER}/charts/$${CHART_NAME_VER}"
    echo "Saving $${TGZ_FILE} as $${DEST_REF}..."
    helm chart save "$${TGZ_FILE}" "$${DEST_REF}"
    echo "Pushing $${DEST_REF} to ACR..."
    # Same set -e pitfall as the az acr import calls above: "cmd; RC=$?" never reaches the capture
    # line on failure. A real `if cmd; then/else` (exempt from set -e) fixes it here too.
    if ! helm chart push "$${DEST_REF}"; then
      echo "Helm push failed" >&2
      exit 1
    fi
    echo "Imported $${CHART_REF} -> $${ACR_LOGIN_SERVER}/charts/$${CHART_NAME_VER} (via Helm fallback)"
  else
    echo "No JFROG credentials provided; cannot access private source. Failing." >&2
    exit 1
  fi
fi
EOT
  }
}

output "import_charts_enabled" {
  value       = var.import_charts
  description = "Whether chart import was enabled for this module"
}
