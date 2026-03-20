# GCP Artifact Registry

> **Warning:** Yet to be tested.

Creates an Artifact Registry repository for storing container or language artifacts.

## Features
- Supports all Artifact Registry formats (Docker, OCI, Maven, npm, Python, etc.).
- Optional KMS encryption key and labels.
- Configurable IAM bindings for repository access control.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | `string` | n/a | GCP project owning the repository. |
| `location` | `string` | n/a | Region (e.g., `us-central1`). |
| `repository_id` | `string` | n/a | Repository identifier. |
| `format` | `string` | `"DOCKER"` | Repository format (`DOCKER`, `OCI`, `MAVEN`, `NPM`, `PYTHON`, `APT`, `YUM`, `HELM`). |
| `description` | `string` | `null` | Optional description. |
| `labels` | `map(string)` | `{}` | Key/value labels. |
| `kms_key_name` | `string` | `null` | KMS key resource name for encryption. |
| `iam_bindings` | `list(object({ role = string, members = list(string), condition = optional(object({ title = string, description = optional(string), expression = string })) }))` | `[]` | Additional IAM bindings. |
| `import_images` | `bool` | `false` | Mirror images from a source registry. |
| `images_to_import` | `list(string)` | `[]` | Images (`repo:tag`) to mirror. |
| `source_registry_url` | `string` | `"docker.io"` | Source registry hostname. |
| `source_registry_username` | `string` | `null` | Source registry username (if required). |
| `source_registry_password` | `string` | `null` | Source registry password/token. |
| `source_registry_allow_anonymous_fallback` | `bool` | `true` | Allow anonymous pulls when login fails. |

## Outputs
| Name | Description |
|------|-------------|
| `repository_id` | Repository ID. |
| `repository_name` | Fully qualified resource name. |
| `repository_uri` | Convenience URI for pushing and pulling artifacts. |

## Example
```hcl
module "artifact_registry" {
  source        = "../../modules/gcp/artifact_registry"
  project_id    = var.project_id
  location      = "us-central1"
  repository_id = "stardog-manager"
  format        = "DOCKER"

  import_images = true
  images_to_import = [
    "stardog/stardog:latest",
    "stardog/launchpad:latest"
  ]

  source_registry_username = var.jfrog_username
  source_registry_password = var.jfrog_password

  iam_bindings = [
    {
      role    = "roles/artifactregistry.writer"
      members = ["serviceAccount:${module.gke.node_sa_email}"]
    }
  ]
}
```

## See Also
- [GKE module](../gke/README.md) - deploys Kubernetes clusters that can pull images from this registry.
