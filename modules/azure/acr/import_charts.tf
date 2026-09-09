variable "import_charts" {
  description = "Whether to import Helm charts from OCI registries into the ACR."
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

locals {
  # A Helm chart stored in an OCI registry is just an OCI artifact - ACR's importImage ARM action
  # (the same one import_images.tf calls) works on it identically to a docker image, so charts get
  # no special handling here beyond stripping the "oci://" scheme and the "charts/" destination
  # prefix the old script also used.
  acr_import_chart_source_no_scheme = {
    for chart in var.charts_to_import : chart => trimprefix(chart, "oci://")
  }
  # repo:tag -> "chart-name:version" (everything after the last "/", same as the old script's sed)
  acr_import_chart_name_version = {
    for chart, no_scheme in local.acr_import_chart_source_no_scheme :
    chart => element(split("/", no_scheme), length(split("/", no_scheme)) - 1)
  }
}

# Calls ACR's own importImage ARM action directly - see import_images.tf for the full rationale
# (no bash/az CLI/helm in tofu-controller's runner pod, confirmed live). The old script's "if az acr
# import fails, fall back to raw helm pull/export/save/push" escape hatch is dropped: that fallback
# needed a shell and the helm binary too, so it could never have worked here either - and modern
# ACR's importImage handles OCI artifacts (including Helm charts) natively, which is why that
# fallback existed as a workaround for older API/CLI limitations, not a fundamentally different
# transfer mechanism.
resource "azapi_resource_action" "acr_import_charts" {
  # for_each over a set, not count over the list - see import_images.tf's acr_import resource for the
  # same fix and full rationale (reordering/inserting/removing then only affects that one entry).
  for_each = var.import_charts ? toset(var.charts_to_import) : []

  type        = "Microsoft.ContainerRegistry/registries@2023-07-01"
  resource_id = local.acr_id
  action      = "importImage"
  method      = "POST"

  body = {
    source = merge(
      {
        registryUri = split("/", local.acr_import_chart_source_no_scheme[each.value])[0]
        sourceImage = trimprefix(local.acr_import_chart_source_no_scheme[each.value], "${split("/", local.acr_import_chart_source_no_scheme[each.value])[0]}/")
      },
      (var.jfrog_registry_password != "") ? {
        credentials = {
          username = var.jfrog_registry_username
          password = var.jfrog_registry_password
        }
      } : {}
    )
    targetTags = ["charts/${local.acr_import_chart_name_version[each.value]}"]
    mode       = "Force"
  }
}

output "import_charts_enabled" {
  value       = var.import_charts
  description = "Whether chart import was enabled for this module"
}
