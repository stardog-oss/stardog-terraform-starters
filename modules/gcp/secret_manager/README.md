# GCP Secret Manager Secret

> **Warning:** Yet to be tested.

Creates a Secret Manager secret with configurable replication and IAM bindings.

## Features
- Automatic or user-managed replication policies.
- Custom IAM bindings with optional conditions.
- Labels for organising secrets.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | `string` | n/a | GCP project ID. |
| `secret_id` | `string` | n/a | Secret identifier. |
| `labels` | `map(string)` | `{}` | Labels attached to the secret. |
| `replication` | `object({ automatic = optional(bool), locations = optional(list(string)) })` | `{}` | Replication policy (automatic by default). |
| `iam_bindings` | `list(object({ role = string, members = list(string), condition = optional(object({ title = string, description = optional(string), expression = string })) }))` | `[]` | IAM bindings. |

## Outputs
| Name | Description |
|------|-------------|
| `secret_id` | Secret ID. |
| `secret_name` | Full resource name. |
| `project_id` | Owning project. |

## Example
```hcl
module "secret_vault" {
  source    = "../../modules/gcp/secret_manager"
  project_id = var.project_id
  secret_id  = "stardog-credentials"

  iam_bindings = [
    {
      role    = "roles/secretmanager.secretAccessor"
      members = ["serviceAccount:${module.gke.node_sa_email}"]
    }
  ]
}
```

## See Also
- [GCP secret entries module](../kv_secrets/README.md) - populate per-application secret data and optional aggregated payloads.
