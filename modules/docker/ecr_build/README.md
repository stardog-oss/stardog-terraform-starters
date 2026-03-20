# Docker ECR Build

Builds a container image locally with Docker and pushes it to an Amazon ECR repository.

## Features
- Hashes the build context to detect changes and trigger rebuilds.
- Performs secure login to ECR before pushing.
- Allows custom build arguments and environment variables.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `source_dir` | `string` | n/a | Path (relative to root module) of the Docker build context. |
| `dockerfile` | `string` | `"Dockerfile"` | Dockerfile path relative to `source_dir`. |
| `repository_url` | `string` | n/a | Full ECR repository URI (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/app`). |
| `aws_region` | `string` | n/a | AWS region of the repository. |
| `tag_prefix` | `string` | `null` | Optional prefix prepended to the generated tag. |
| `build_args` | `list(string)` | `[]` | Extra tokens passed to `docker build`. |
| `include_glob` | `string` | `"**"` | Glob pattern of files included in the content hash. |
| `extra_triggers` | `map(string)` | `{}` | Additional triggers that force rebuilds. |
| `environment` | `map(string)` | `{}` | Environment variables for the `local-exec` provisioner. |
| `target_platform` | `string` | `"linux/amd64"` | Value assigned to `DOCKER_DEFAULT_PLATFORM` during the build (set `null` to disable). |

## Outputs
| Name | Description |
|------|-------------|
| `image_uri` | Fully qualified image reference (`repository:tag`). |
| `image_tag` | Generated tag component. |
| `repository_path` | Repository path portion of the URI. |

## Example
```hcl
module "stardog_manager_image" {
  source         = "../../modules/docker/ecr_build"
  source_dir     = "../../containers/stardog-manager"
  repository_url = module.ecr.repository_url
  aws_region     = var.aws_region
  tag_prefix     = var.inst_id
}
```
