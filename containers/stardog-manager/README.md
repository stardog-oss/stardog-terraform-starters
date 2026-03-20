# Stardog Manager Container

This directory contains the build context for the `stardog-manager` image. The image packages the `stardog_ops` CLI and supporting utilities used to manage Stardog roles and permissions from Terraform.

## Purpose
- Provides a lightweight runtime for executing `stardog_ops` commands via `kubectl run`.
- Used by the `modules/stardog_resources` Terraform modules to create, update, or remove Stardog roles and assignments in an automated fashion.
- Designed to be built and pushed by the Docker build helper modules:
  - Azure environments: `modules/docker/acr_build`
  - AWS environments: `modules/docker/ecr_build`

## Build & Publish

To build and push the image using Terraform, reference the appropriate build module from your environment configuration. For example, in the AWS profile:

```hcl
module "stardog_manager_image" {
  source         = "../../modules/docker/ecr_build"
  source_dir     = "../../containers/stardog-manager"
  repository_url = module.ecr.repository_url
  aws_region     = var.aws_region
  tag_prefix     = var.inst_id
}
```

The resulting image URI is exposed via module outputs and consumed by the `stardog_resources/role` and `stardog_resources/role_set` modules to execute the CLI.
