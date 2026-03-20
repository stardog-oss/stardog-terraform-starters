# Stardog Role

Manages a single Stardog role by running the `stardog_ops` CLI in an ephemeral Kubernetes pod.

## Features
- Ensures a role exists (or is removed) using the stardog-manager image.
- Supports custom CLI arguments, environment variables, and service accounts.
- Optionally runs a destroy-time command to delete the role.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | n/a | Name of the Stardog role. |
| `namespace` | `string` | n/a | Kubernetes namespace for the temporary pod. |
| `kubeconfig_path` | `string` | `"~/.kube/config"` | Path to kubeconfig used by `kubectl`. |
| `image` | `string` | n/a | Container image containing the `stardog_ops` CLI. |
| `stardog_url` | `string` | `"http://stardog:5820"` | Stardog admin endpoint URL. |
| `state` | `string` | `"present"` | Desired state: `present` or `absent`. |
| `skip_status` | `bool` | `true` | Skip writing status ConfigMaps. |
| `additional_cli_args` | `list(string)` | `[]` | Extra arguments passed to `stardog_ops cli`. |
| `destroy_on_deprovision` | `bool` | `false` | Remove the role when Terraform destroys the resource. |
| `container_env` | `map(string)` | `{}` | Environment variables injected into the pod. |
| `local_exec_env` | `map(string)` | `{}` | Environment variables for the local `kubectl` command. |
| `service_account_name` | `string` | `null` | Service account used by the temporary pod. |

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
  image              = module.stardog_manager_image.image_uri
  stardog_url        = "https://stardog.${local.ingress_dns_root}"
  kubeconfig_path    = "~/.kube/config"
  container_env = {
    STARDOG_USERNAME = var.stardog_admin_username
    STARDOG_PASSWORD = var.stardog_admin_password
  }
}
```

## See Also
- [Stardog Helm stack](../../kubernetes/stardog/README.md) - deploys the Stardog application components that these roles manage access for.
