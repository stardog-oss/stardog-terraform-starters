# Envoy Gateway Module

Installs [Envoy Gateway](https://github.com/envoyproxy/gateway) using the official `gateway-helm` chart. The module creates the target namespace and exposes a simple interface to configure Helm inputs without repeating boilerplate across environments.

## Example

```hcl
module "envoy_gateway" {
  source = "../../modules/kubernetes/envoy_gateway"

  namespace     = "envoy-gateway"
  release_name  = "eg"
  chart_version = "v1.2.0"

  values = {
    envoyGateway = {
      replicas = 2
    }
  }

  extra_values = {
    serviceAccount = {
      annotations = {
        "azure.workload.identity/client-id" = "..."
      }
    }
  }
}
```

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `namespace` | Namespace for the Helm release. | `string` | `envoy-gateway` |
| `release_name` | Helm release name. | `string` | `envoy-gateway` |
| `chart_url` | Helm chart reference (`oci://` or repo URL). | `string` | `oci://docker.io/envoyproxy/gateway-helm` |
| `chart_version` | Chart version (empty = latest). | `string` | `""` |
| `helm_atomic` / `helm_wait` / `helm_cleanup_on_fail` / `helm_force_update` / `helm_timeout` | Standard Helm toggles. | various | see `variables.tf` |
| `values` | Base values map passed to the chart. | `map(any)` | `{}` |
| `extra_values` | Overrides merged on top of `values`. | `map(any)` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `namespace` | Namespace where Envoy Gateway is installed. |
| `release_name` | Helm release name. |
