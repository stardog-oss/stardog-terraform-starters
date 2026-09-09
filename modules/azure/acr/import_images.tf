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

locals {
  # Registry-prefix detection: a "/"-separated first path segment counts as an explicit source
  # registry host only if it looks like one (has a dot, a colon, or is "localhost") - otherwise
  # it's just a Docker Hub namespace (e.g. "stardog/stardog" has no registry prefix). Mirrors the
  # parsing the old bash script did by hand.
  acr_import_has_registry = {
    for image in var.images_to_import : image => (
      length(regexall("^[^/]+[.:][^/]*/", image)) > 0 || startswith(image, "localhost/")
    )
  }
  # "registry.hub.docker.com" is the exact host Azure's own importImage examples use for public
  # Docker Hub sources (not "docker.io" - that alias is an `az` CLI-ism this module no longer goes
  # through now that it calls the ARM importImage action directly).
  acr_import_registry = {
    for image, has_registry in local.acr_import_has_registry :
    image => has_registry ? split("/", image)[0] : "registry.hub.docker.com"
  }
  acr_import_path = {
    for image, has_registry in local.acr_import_has_registry :
    image => has_registry ? substr(image, length(split("/", image)[0]) + 1, -1) : image
  }
  acr_import_is_jfrog = {
    for image, registry in local.acr_import_registry : image => strcontains(registry, "jfrog")
  }
  acr_import_credentials = {
    for image, is_jfrog in local.acr_import_is_jfrog : image => is_jfrog ? {
      username = var.jfrog_registry_username
      password = var.jfrog_registry_password
      } : {
      username = var.source_registry_username
      password = var.source_registry_password
    }
  }
}

# Calls ACR's own importImage ARM action directly - the exact operation `az acr import` itself
# wraps (server-side: ACR's control plane does the pull itself, no image bytes ever pass through
# whatever runs this). Chosen over a null_resource + `az acr import` shell-out after confirming
# live that tofu-controller's runner pod (ghcr.io/flux-iac/tf-runner) ships nothing but the
# terraform/opentofu binary and `apk` - no bash, no az CLI, no docker.
resource "azapi_resource_action" "acr_import" {
  # for_each over a set, not count over the list - each instance is keyed by the image string itself
  # (azapi_resource_action.acr_import["repo/image:tag"]), not its position. Reordering, inserting,
  # or removing an entry then only affects that one entry's resource, instead of shifting every
  # later index and forcing a spurious re-import of everything after it.
  for_each = var.import_images ? toset(var.images_to_import) : []

  type        = "Microsoft.ContainerRegistry/registries@2023-07-01"
  resource_id = local.acr_id
  action      = "importImage"
  method      = "POST"

  body = {
    source = merge(
      {
        registryUri = local.acr_import_registry[each.value]
        sourceImage = local.acr_import_path[each.value]
      },
      (local.acr_import_credentials[each.value].username != null && local.acr_import_credentials[each.value].password != null) ? {
        credentials = {
          username = local.acr_import_credentials[each.value].username
          password = local.acr_import_credentials[each.value].password
        }
      } : {}
    )
    targetTags = ["${local.acr_import_path[each.value]}"]
    mode       = "Force"
  }
}

output "import_images_enabled" {
  value       = var.import_images
  description = "Whether image import was enabled for this module"
}
