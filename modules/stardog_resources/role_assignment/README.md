# Stardog Role Assignment module

Creates or deletes a single Stardog role permission assignment by running the `stardog-manager` container inside the target cluster. The module mirrors the flow used by `modules/stardog_resources/role`, but writes a spec that includes `action`, `resource_type`, and `resource`, so the CLI performs a role-assignment reconciliation.

## Requirements

* `kubectl` on the Terraform host.
* Access to the `stardog-manager` image that ships the `stardog_ops` CLI.
* `pystardog` bundled in the image (already true for the repo image).

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `role` | Role name to mutate. | `string` | n/a |
| `action` | Permission action (read, write, execute, etc.). | `string` | n/a |
| `resource_type` | Stardog resource type (e.g. `db`, `dbms_admin`, `all`). | `string` | n/a |
| `resource` | Resource identifier or wildcard (e.g. `*`, `backup-all`, `db:mydb`). | `string` | n/a |
| `state` | `present` to grant, `absent` to revoke. | `string` | `present` |
| `namespace` | Kubernetes namespace for the ephemeral pod. | `string` | n/a |
| `kubeconfig_path` | Kubeconfig path for `kubectl`. | `string` | `~/.kube/config` |
| `image` | Fully-qualified `stardog-manager` image reference. | `string` | n/a |
| `stardog_url` | Override Stardog admin endpoint (falls back to spec/CLI default). | `string` | `null` |
| `skip_status` | Skip status ConfigMap writes (CLI prints JSON to stdout). | `bool` | `true` |
| `idempotent_create` | Pass `--idempotent-create` to the CLI and set `idempotent=true` in the spec. | `bool` | `false` |
| `additional_spec_fields` | Map merged into the spec JSON (last-wins). | `map(any)` | `{}` |
| `additional_cli_args` | Extra CLI flags appended after defaults. | `list(string)` | `[]` |
| `container_env` | Environment variables injected into the container (typically credentials). | `map(string)` | `{}` |
| `local_exec_env` | Environment variables for the local `kubectl` call. | `map(string)` | `{}` |
| `service_account_name` | Optional service account for the temporary pod. | `string` | `null` |
| `destroy_on_deprovision` | Whether to revoke the assignment during Terraform destroy. | `bool` | `true` |

## Behaviour

* Apply-time: writes a spec with the requested state, base64-encodes it, and invokes `python -m stardog_ops.cli --spec-file=/tmp/spec.json …`.
* Status reporting mirrors `modules/stardog_resources/role`: when `skip_status = true` the CLI prints status to stdout only; provide `--output-configmap` (via module inputs) if you need Kubernetes status objects.
* Destroy-time: defaults to running the same command with `state = "absent"` so the grant is revoked. Set `destroy_on_deprovision = false` to skip the destroy phase.
* Pod names are derived from a hash of the role/action/resource tuple and the spec hash to keep them unique but short.

## Example

```hcl
module "writer_write_all" {
  source            = "../../modules/stardog_resources/role_assignment"
  role              = "writer"
  action            = "write"
  resource_type     = "all"
  resource          = "*"
  namespace         = var.stardog_namespace
  kubeconfig_path   = var.kubeconfig_path
  image             = module.stardog_manager_image.image_uri
  stardog_url       = local.stardog_internal_service_url
  container_env = {
    STARDOG_USERNAME = var.stardog_admin_username
    STARDOG_PASSWORD = var.stardog_admin_password
  }
}
```

When the module is removed, it will revoke the permission unless `destroy_on_deprovision` is set to `false`.
