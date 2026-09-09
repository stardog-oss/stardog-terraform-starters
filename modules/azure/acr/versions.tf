terraform {
  required_providers {
    # Used by import_images.tf's azapi_resource_action - a direct call to ACR's own importImage
    # ARM action (the exact operation `az acr import` itself wraps), so image import needs no `az`
    # CLI, no bash, no local-exec at all. Chosen over a null_resource + `az acr import` shell-out
    # after confirming live that tofu-controller's runner pod (ghcr.io/flux-iac/tf-runner) ships
    # nothing but the terraform/opentofu binary and `apk` - no bash, no az, no docker, no jq.
    azapi = {
      source = "Azure/azapi"
    }
  }
}
