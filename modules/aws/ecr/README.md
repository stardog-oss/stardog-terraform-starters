# AWS ECR Repository

Creates an Amazon Elastic Container Registry repository, optional lifecycle/policy rules, and (optionally) mirrors images from another registry.

## Features
- Provisions an ECR repository with configurable encryption, scanning, and tag mutability.
- Supports lifecycle and repository policies, including convenience pull access based on principal ARNs.
- Imports container images via Docker (with optional credential fallback and anonymous mode).
- Detects multi-architecture manifests and, when Docker Buildx is available, mirrors every platform into ECR (falls back to host-architecture pull/push otherwise).
- Uses a temporary `DOCKER_CONFIG` (with an empty `auths` map) during imports so existing credential helpers (e.g., macOS keychain) don’t leak stale logins or block the automation.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `repository_name` | `string` | n/a | Name of the ECR repository. |
| `image_tag_mutability` | `string` | `"MUTABLE"` | `MUTABLE` or `IMMUTABLE`. |
| `scan_on_push` | `bool` | `true` | Enable image scanning on push. |
| `encryption_type` | `string` | `"AES256"` | `AES256` or `KMS`. |
| `kms_key_arn` | `string` | `null` | KMS key ARN when `encryption_type = "KMS"`. |
| `force_delete` | `bool` | `false` | Force delete repository even if images exist. |
| `lifecycle_policy` | `string` | `null` | Lifecycle policy JSON. |
| `repository_policy_json` | `string` | `null` | Custom repository policy JSON. |
| `pull_principal_arns` | `list(string)` | `[]` | Principal ARNs granted pull access when `repository_policy_json` is not provided. |
| `tags` | `map(string)` | `{}` | Tags applied to the repository. |
| `source_registry_username` | `string` | `null` | Username for source registry authentication - only applied to images whose own parsed registry (from the image string itself) isn't the default docker.io. |
| `source_registry_password` | `string` | `null` | Password/token for source registry authentication. |
| `import_images` | `bool` | `false` | Mirror images from the source registry when `true`. |
| `images_to_import` | `list(string)` | `[]` | List of `<repo>:<tag>` entries to mirror into ECR. |

## Outputs
| Name | Description |
|------|-------------|
| `repository_name` | ECR repository name. |
| `repository_arn` | ECR repository ARN. |
| `repository_url` | Fully qualified repository URI. |

## Example
```hcl
module "stardog_ecr" {
  source           = "../../modules/aws/ecr"
  repository_name  = "stardog-manager"
  scan_on_push     = true
  import_images    = true
  images_to_import = ["stardog/stardog:latest"]

  tags = {
    environment = var.inst_id
    managed_by  = "terraform"
  }
}
```
