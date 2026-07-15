# Stardog Role Assignment module

Creates or deletes a single Stardog role permission assignment by running the local `stardog-admin` CLI against a Stardog admin endpoint.

## Requirements

* `stardog-admin` on the Terraform host.
* Network access from the Terraform host to `stardog_url`.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `role` | Role name to mutate. | `string` | n/a |
| `action` | Permission action (read, write, execute, etc.). | `string` | n/a |
| `resource_type` | Stardog resource type (e.g. `db`, `dbms_admin`, `all`). | `string` | n/a |
| `resource` | Resource identifier or wildcard (e.g. `*`, `backup-all`, `db:mydb`). | `string` | n/a |
| `state` | `present` to grant, `absent` to revoke. | `string` | `present` |
| `namespace` | Legacy no-op retained for compatibility. | `string` | n/a |
| `kubeconfig_path` | Legacy no-op retained for compatibility. | `string` | `~/.kube/config` |
| `image` | Legacy no-op retained for compatibility. | `string` | `null` |
| `stardog_url` | Override Stardog admin endpoint (falls back to spec/CLI default). | `string` | `null` |
| `skip_status` | Legacy no-op retained for compatibility. | `bool` | `true` |
| `idempotent_create` | Preserved in the resource hash for compatibility. | `bool` | `false` |
| `additional_spec_fields` | Map merged into the spec JSON (last-wins). | `map(any)` | `{}` |
| `additional_cli_args` | Reserved for compatibility. | `list(string)` | `[]` |
| `container_env` | Environment variables carrying Stardog credentials. | `map(string)` | `{}` |
| `local_exec_env` | Environment variables for local `stardog-admin` execution. | `map(string)` | `{}` |
| `service_account_name` | Legacy no-op retained for compatibility. | `string` | `null` |
| `destroy_on_deprovision` | Whether to revoke the assignment during Terraform destroy. | `bool` | `true` |

## Behaviour

* Apply-time: ensures the role exists when granting, then runs `stardog-admin role grant`.
* Permission state checks use `stardog-admin role permission` before grant or revoke.
* Destroy-time: defaults to running the same command with `state = "absent"` so the grant is revoked. Set `destroy_on_deprovision = false` to skip the destroy phase.

## Example

```hcl
module "writer_write_all" {
  source            = "../../modules/stardog_resources/role_assignment"
  role              = "writer"
  action            = "write"
  resource_type     = "all"
  resource          = "*"
  stardog_url       = "https://stardog.${local.ingress_dns_root}"
  container_env = {
    STARDOG_USERNAME = var.stardog_admin_username
    STARDOG_PASSWORD = var.stardog_admin_password
  }
}
```

When the module is removed, it will revoke the permission unless `destroy_on_deprovision` is set to `false`.
