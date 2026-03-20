# GCP Secret Entries

> **Warning:** Yet to be tested.

Creates individual Secret Manager secrets for a set of logical entries and optionally writes an aggregated JSON payload to an existing secret.

## Features
- Generates deterministic secret IDs with optional prefixing.
- Per-entry or default replication policies.
- Optional aggregate JSON secret version for CSI or file-based consumption.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | `string` | n/a | GCP project ID. |
| `secrets` | `map(object({ value = string, labels = optional(map(string)), replication = optional(object({ automatic = optional(bool), locations = optional(list(string)) })) }))` | `{}` | Secret entries to create. |
| `secret_name_prefix` | `string` | `null` | Prefix for generated secret IDs. |
| `default_replication` | `object({ automatic = optional(bool), locations = optional(list(string)) })` | `{ automatic = true, locations = [] }` | Default replication policy. |
| `aggregate_secret_id` | `string` | `null` | Existing Secret Manager secret resource name for aggregate JSON. |
| `aggregate_json` | `bool` | `false` | Enable aggregate JSON payload. |

## Outputs
| Name | Description |
|------|-------------|
| `secret_names` | Map of logical name to created secret resource name. |
| `aggregate_payload` | JSON payload stored in the aggregate secret when enabled. |

## Example
```hcl
module "gcp_secrets" {
  source      = "../../modules/gcp/kv_secrets"
  project_id  = var.project_id
  secret_name_prefix = "stardog"
  aggregate_secret_id = "projects/${var.project_id}/secrets/stardog-aggregate"
  aggregate_json = true

  secrets = {
    "launchpad-client-id" = { value = module.human_entra.launchpad_application_client_id }
    "launchpad-client-secret" = {
      value  = module.human_entra.launchpad_client_secret
      labels = { content_type = "application/x-azuread-client-secret" }
    }
  }
}
```

## See Also
- [GCP Secret Manager module](../secret_manager/README.md) - create the base secret used for aggregate payload storage.
