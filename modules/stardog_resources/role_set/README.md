# Stardog Role Set

Manages a collection of Stardog roles and permission assignments via the `stardog_ops` CLI, orchestrated through ephemeral Kubernetes pods.

## Features
- Creates or updates multiple roles and their permissions in one place.
- Supports optional removal of the built-in `reader` role before applying custom definitions.
- Reuses the `stardog_resources/role` and `role_assignment` modules for idempotent management.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `deploy` | `bool` | `true` | Enable or disable management of roles/assignments. |
| `namespace` | `string` | n/a | Kubernetes namespace for the temporary pods. |
| `kubeconfig_path` | `string` | `"~/.kube/config"` | Kubeconfig used by `kubectl`. |
| `image` | `string` | n/a | Container image containing the `stardog_ops` CLI. |
| `stardog_url` | `string` | n/a | Stardog admin endpoint URL. |
| `stardog_username` | `string` | n/a | Stardog admin username. |
| `stardog_password` | `string` | n/a | Stardog admin password. |
| `stardog_insecure` | `bool` | `false` | Skip TLS verification when contacting Stardog. |
| `roles` | `map(list(object({ action = string, resource_type = string, resource = string, state = optional(string), idempotent = optional(bool) })))` | `{}` | Map of role name to permission list. |
| `remove_builtin_reader` | `bool` | `true` | Remove the default `reader` role prior to applying custom roles. |
| `service_account_name` | `string` | `null` | Service account for the ephemeral pods. |
| `extra_cli_args` | `list(string)` | `[]` | Additional CLI arguments passed to `stardog_ops`. |
| `container_env_extra` | `map(string)` | `{}` | Additional environment variables for the container. |
| `local_exec_env` | `map(string)` | `{}` | Environment variables for the local `kubectl` command. |

## Outputs
This module does not export outputs; downstream modules can rely on the side effects (roles/assignments in Stardog).

## Example
```hcl
module "stardog_roles" {
  source            = "../../modules/stardog_resources/role_set"
  namespace         = "stardog"
  image             = module.stardog_manager_image.image_uri
  stardog_url       = "https://stardog.${local.ingress_dns_root}"
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
