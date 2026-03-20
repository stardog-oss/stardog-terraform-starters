variable "import_images" {
  description = "Whether to import images from external registries into the ACR. Useful for one-off mirroring."
  type        = bool
  default     = false
}

variable "images_to_import" {
  description = "List of images to import from the source registry (format: namespace/name:tag). Defaults assume docker.io."
  type        = list(string)
  default = [
    "stardog/stardog:11.2.0",
    "stardog/launchpad:3.6.0",
    "stardog/voicebox-service:v0.22.0",
  ]
}

resource "null_resource" "acr_import" {
  count = var.import_images ? length(var.images_to_import) : 0

  triggers = {
    image = element(var.images_to_import, count.index)
    acr   = local.acr_name
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<EOT
set -euo pipefail
IMAGE="${element(var.images_to_import, count.index)}"
ACR="${local.acr_name}"
SRC_USER="${var.source_registry_username == null ? "" : var.source_registry_username}"
SRC_PASS="${var.source_registry_password == null ? "" : var.source_registry_password}"
JFROG_USER="${var.jfrog_registry_username == null ? "" : var.jfrog_registry_username}"
JFROG_PASS="${var.jfrog_registry_password == null ? "" : var.jfrog_registry_password}"

SOURCE_REGISTRY=""
SRC_PATH="$${IMAGE}"

if [[ "$${IMAGE}" == */* ]]; then
  FIRST_SEGMENT="$${IMAGE%%/*}"
  if [[ "$${FIRST_SEGMENT}" == *.* || "$${FIRST_SEGMENT}" == *:* || "$${FIRST_SEGMENT}" == "localhost" ]]; then
    SOURCE_REGISTRY="$${FIRST_SEGMENT}"
    SRC_PATH="$${IMAGE#*/}"
  fi
fi

if [[ -z "$${SOURCE_REGISTRY}" ]]; then
  SOURCE_REGISTRY="docker.io"
fi

SOURCE_REF="$${SOURCE_REGISTRY}/$${SRC_PATH}"
DEST_IMAGE="$${SRC_PATH}"

AUTH_USER="$${SRC_USER}"
AUTH_PASS="$${SRC_PASS}"
if [[ "$${SOURCE_REGISTRY}" == *"jfrog.io"* || "$${SOURCE_REGISTRY}" == *"jfrog"* ]]; then
  if [[ -n "$${JFROG_USER}" || -n "$${JFROG_PASS}" ]]; then
    AUTH_USER="$${JFROG_USER}"
    AUTH_PASS="$${JFROG_PASS}"
  else
    echo "No JFrog credentials provided; import may fail if $${SOURCE_REGISTRY} requires auth."
  fi
fi

echo "Importing $${SOURCE_REF} into ACR $${ACR} as $${DEST_IMAGE}..."
IMPORT_ARGS=(--name "$${ACR}" --source "$${SOURCE_REF}" --image "$${DEST_IMAGE}" --force)

if [[ -n "$${AUTH_USER}" && -n "$${AUTH_PASS}" ]]; then
  echo "Using source registry credentials for az acr import."
  IMPORT_ARGS+=(--username "$${AUTH_USER}" --password "$${AUTH_PASS}")
fi

# Use az acr import which pulls directly from Docker Hub into ACR (no local docker required)
az acr import "$${IMPORT_ARGS[@]}"
EOT
  }
}

output "import_images_enabled" {
  value       = var.import_images
  description = "Whether image import was enabled for this module"
}
