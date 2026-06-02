# Stardog Role

Manages a single Stardog role by running the local `stardog-admin` CLI against a Stardog admin endpoint.

## Features
- Ensures a role exists or is removed without requiring Kubernetes access.
- Uses `STARDOG_USERNAME` and `STARDOG_PASSWORD` from `container_env` for compatibility with existing callers.
- Optionally runs a destroy-time command to delete the role.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Name of the Stardog role. |
| `namespace` | `string` | n/a | Legacy no-op retained for compatibility. |
| `kubeconfig_path` | `string` | `"~/.kube/config"` | Legacy no-op retained for compatibility. |
| `image` | `string` | `null` | Legacy no-op retained for compatibility. |
| `stardog_url` | `string` | `"http://stardog:5820"` | Stardog admin endpoint URL. |
| `state` | `string` | `"present"` | Desired state: `present` or `absent`. |
| `skip_status` | `bool` | `true` | Legacy no-op retained for compatibility. |
| `additional_cli_args` | `list(string)` | `[]` | Reserved for compatibility. |
| `destroy_on_deprovision` | `bool` | `false` | Remove the role when Terraform destroys the resource. |
| `container_env` | `map(string)` | `{}` | Environment variables carrying Stardog credentials. |
| `local_exec_env` | `map(string)` | `{}` | Environment variables for local `stardog-admin` execution. |
| `service_account_name` | `string` | `null` | Legacy no-op retained for compatibility. |

## Outputs
| Name | Description |
|------|-------------|
| `role_name` | Managed role name (echo of `var.name`). |
| `apply_command` | Command executed to ensure the role (sensitive). |
| `destroy_command` | Command executed during destroy (sensitive). |

## Example
```hcl
module "stardog_reader_role" {
  source             = "../../modules/stardog_resources/role"
  name               = "reader"
  namespace          = "stardog"
  stardog_url        = "https://stardog.${local.ingress_dns_root}"
  container_env = {
    STARDOG_USERNAME = var.stardog_admin_username
    STARDOG_PASSWORD = var.stardog_admin_password
  }
}
```

## See Also
- [Stardog Helm stack](../../kubernetes/stardog/README.md) - deploys the Stardog application components that these roles manage access for.
