# Stardog Role Set

Manages a collection of Stardog roles and permission assignments by running the local `stardog-admin` CLI against a Stardog admin endpoint.

## Features
- Creates or updates multiple roles and their permissions in one place.
- Supports optional removal of the built-in `reader` role before applying custom definitions.
- Reuses the `stardog_resources/role` and `role_assignment` modules for idempotent management.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `deploy` | `bool` | `true` | Enable or disable management of roles/assignments. |
| `namespace` | `string` | n/a | Legacy no-op retained for compatibility. |
| `kubeconfig_path` | `string` | `"~/.kube/config"` | Legacy no-op retained for compatibility. |
| `image` | `string` | `null` | Legacy no-op retained for compatibility. |
| `stardog_url` | `string` | n/a | Stardog admin endpoint URL. |
| `stardog_username` | `string` | n/a | Stardog admin username. |
| `stardog_password` | `string` | n/a | Stardog admin password. |
| `stardog_insecure` | `bool` | `false` | Legacy no-op for this local CLI path. Configure local JVM trust for private CAs. |
| `roles` | `map(list(object({ action = string, resource_type = string, resource = string, state = optional(string), idempotent = optional(bool) })))` | `{}` | Map of role name to permission list. |
| `remove_builtin_reader` | `bool` | `true` | Remove the default `reader` role prior to applying custom roles. |
| `service_account_name` | `string` | `null` | Legacy no-op retained for compatibility. |
| `extra_cli_args` | `list(string)` | `[]` | Reserved for compatibility. |
| `container_env_extra` | `map(string)` | `{}` | Additional environment variables carried for compatibility. |
| `local_exec_env` | `map(string)` | `{}` | Environment variables for local `stardog-admin` execution. |
| `wait_for_stardog` | `bool` | `true` | Wait for the Stardog public admin endpoint before creating roles. |
| `stardog_ready_path` | `string` | `"/admin/alive"` | HTTP path used for the readiness check. |
| `stardog_ready_attempts` | `number` | `60` | Number of readiness attempts before failing. |
| `stardog_ready_interval_seconds` | `number` | `10` | Seconds between readiness attempts. |

## Outputs
This module does not export outputs; downstream modules can rely on the side effects (roles/assignments in Stardog).

## Example
```hcl
module "stardog_roles" {
  source            = "../../modules/stardog_resources/role_set"
  namespace         = "stardog"
  stardog_url       = "https://sparql.${local.ingress_dns_root}"
  stardog_username  = var.stardog_admin_username
  stardog_password  = var.stardog_admin_password

  roles = {
    writer = [
      { action = "read",  resource_type = "all", resource = "*" },
      { action = "write", resource_type = "all", resource = "*" }
    ]
    "backup-operators" = [
      { action = "execute", resource_type = "dbms-admin", resource = "backup-all" }
    ]
  }
}
```

## See Also
- [Stardog Helm stack](../../kubernetes/stardog/README.md) - installs the Stardog services and secrets that this module configures through the CLI.
