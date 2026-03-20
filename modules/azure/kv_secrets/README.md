# Azure Key Vault Secrets

Creates or updates multiple secrets inside an existing Azure Key Vault.

## Features
- Writes a map of secrets in a single apply.
- Optionally records `content_type` metadata for each entry.
- Returns the IDs of the created secrets for downstream wiring.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `key_vault_id` | `string` | n/a | Target Key Vault resource ID. |
| `secrets` | `map(object({ value = string, content_type = optional(string) }))` | `{}` | Map of secret names to payloads and optional content types. |

## Outputs
| Name | Description |
|------|-------------|
| `ids` | Map of secret name to Key Vault secret resource ID. |

## Example
```hcl
module "kv_secrets" {
  source       = "../../modules/azure/kv_secrets"
  key_vault_id = azurerm_key_vault.app.id

  secrets = {
    "launchpad-client-secret" = {
      value        = var.launchpad_client_secret
      content_type = "application/x-azuread-client-secret"
    }
    "sparql-client-id" = {
      value = module.aad_sparql.client_id
    }
  }
}
```

## See Also
- [Azure Key Vault module](../akv/README.md) - provision or configure the vault these secrets target.
