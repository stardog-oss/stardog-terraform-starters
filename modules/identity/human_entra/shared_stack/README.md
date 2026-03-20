# Human Entra Shared Stack

Composes the Launchpad and SPARQL Azure AD application registrations, wiring shared configuration and optional admin role assignments.

## Features
- Creates both application registrations with consistent redirect URIs based on environment DNS.
- Delegates secret storage to the provided backend configuration.
- Optionally grants the SPARQL admin role to an Azure AD group.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `inst_id` | `string` | n/a | Environment identifier used in display names and URIs. |
| `dns_zone_name` | `string` | n/a | DNS zone appended to redirect URIs. |
| `owner_object_ids` | `list(string)` | `[]` | Owners for the created applications. |
| `secret_backend` | `object({ kind = string, config = map(any) })` | n/a | Secret storage backend definition passed to child modules. |
| `app_admin_role_group_object_id` | `string` | `null` | Azure AD group granted the SPARQL admin app role. |
| `extra_sparql_redirect_uris` | `list(string)` | `[]` | Additional redirect URIs for the SPARQL application. |

## Outputs
| Name | Description |
|------|-------------|
| `sparql_application_client_id` | Client ID of the SPARQL application registration. |
| `sparql_service_principal_object_id` | Service principal object ID for SPARQL. |
| `launchpad_application_client_id` | Client ID of the Launchpad application registration. |
| `sparql_client_secret` | Secret reference/details returned by the SPARQL module. |
| `launchpad_client_secret` | Secret reference/details returned by the Launchpad module. |
| `sparql_secret_entries` | Map of secret payloads emitted by the SPARQL module. |
| `launchpad_secret_entries` | Map of secret payloads emitted by the Launchpad module. |

## Example
```hcl
module "human_entra" {
  source      = "../../modules/identity/human_entra/shared_stack"
  inst_id     = var.inst_id
  dns_zone_name = var.dns_zone_name
  owner_object_ids = concat(var.app_owner_object_ids, data.azuread_users.team.ids)
  secret_backend = {
    kind   = "azurekv"
    config = { key_vault_id = module.akv.id }
  }
  app_admin_role_group_object_id = var.app_admin_role_group_object_id
}
```

## See Also
- [Launchpad application module](../aad_launchpad/README.md) - underlying module this stack calls to create the Launchpad registration.
- [SPARQL application module](../aad_sparql/README.md) - underlying module for the SPARQL registration and app roles.
- [App role assignment helper](../app_role_assignment/README.md) - use for additional role grants beyond the built-in admin group wiring.
