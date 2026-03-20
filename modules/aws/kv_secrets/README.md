# AWS Secrets Manager Entries

Materialises individual Secrets Manager secrets for each entry in a map and optionally stores an aggregated JSON document in an existing base secret.

## Features
- Creates one secret per entry with deterministic naming based on a prefix.
- Optionally writes a JSON payload (all entries) to an existing parent secret.
- Preserves `content_type` metadata via secret tags.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `secret_arn` | `string` | n/a | ARN of the base secret used for aggregation and name derivation. |
| `secrets` | `map(object({ value = string, content_type = optional(string) }))` | `{}` | Map of secret entries to persist. |
| `secret_name_prefix` | `string` | `null` | Override prefix for per-entry secret names. |
| `aggregate_json` | `bool` | `false` | When true, also write a JSON document of all entries to `secret_arn`. |

## Outputs
| Name | Description |
|------|-------------|
| `secret_names` | Map of logical name to Secrets Manager secret name. |
| `aggregate_payload` | JSON string stored in the aggregate secret (when enabled). |

## Example
```hcl
module "stardog_secrets" {
  source      = "../../modules/aws/kv_secrets"
  secret_arn  = module.secret_vault.secret_arn
  aggregate_json = false

  secrets = {
    "launchpad-client-id" = {
      value        = module.human_entra.launchpad_application_client_id
      content_type = "text/plain"
    }
    "launchpad-client-secret" = {
      value        = module.human_entra.launchpad_client_secret
      content_type = "application/x-azuread-client-secret"
    }
  }
}
```

## See Also
- [AWS secret vault module](../secretvault/README.md) - create the base Secrets Manager secret and optional KMS key referenced here.
