terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    # Real Terraform provider for registry-to-registry image copies (vendors a fork of skopeo
    # 1.5.1 rather than shelling out to a skopeo binary) - used instead of a null_resource +
    # local-exec so image import works inside tofu-controller's runner pod, which ships nothing
    # but the terraform/opentofu binary itself and `apk` (no bash, no docker, no aws-cli, no
    # skopeo binary - confirmed live by exec'ing into ghcr.io/flux-iac/tf-runner:v0.16.5).
    skopeo = {
      source = "abergmeier/skopeo"
    }
  }
}
