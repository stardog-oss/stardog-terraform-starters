# Docker ACR Build

Builds a container image using Azure Container Registry’s `az acr build` command and pushes it to a repository inside the registry.

## Features
- Hashes the build context to trigger rebuilds only when sources change.
- Supports additional build arguments and environment variables.
- Exposes the resulting image URI and tag.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `source_dir` | `string` | n/a | Path (relative to root module) of the Docker build context. |
| `dockerfile` | `string` | `"Dockerfile"` | Dockerfile path relative to `source_dir`. |
| `registry_name` | `string` | n/a | Azure Container Registry name. |
| `registry_login_server` | `string` | n/a | ACR login server (e.g., `myacr.azurecr.io`). |
| `image_name` | `string` | n/a | Repository name inside the registry. |
| `tag_prefix` | `string` | `null` | Optional prefix added to auto-generated tag. |
| `additional_build_args` | `list(string)` | `[]` | Extra tokens appended to `az acr build`. |
| `subscription_id` | `string` | `null` | Azure subscription ID passed to `az acr build`. |
| `include_glob` | `string` | `"**"` | Glob pattern of files considered when hashing the context. |
| `extra_triggers` | `map(string)` | `{}` | Additional triggers that force rebuilds. |
| `environment` | `map(string)` | `{}` | Environment variables for the `local-exec` provisioner. |

## Outputs
| Name | Description |
|------|-------------|
| `context_hash` | Hash of the build context used for change detection. |
| `image_tag` | Repository tag (`repository:tag`). |
| `image_uri` | Fully qualified image reference (`registry/repository:tag`). |
| `build_trigger_id` | ID of the build resource (changes when rebuild occurs). |

## Example
```hcl
module "stardog_manager_image" {
  source                = "../../modules/docker/acr_build"
  source_dir            = "../../containers/stardog-manager"
  registry_name         = module.acr.name
  registry_login_server = module.acr.login_server
  image_name            = "stardog-manager"
  tag_prefix            = var.inst_id
  subscription_id       = var.subscription_id
}
```
