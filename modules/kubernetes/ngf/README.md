# NGINX Gateway Fabric Module

Installs the [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) control plane and data plane via the official Helm chart. The module creates the target namespace, renders strongly typed defaults (gateway class name, replicas, service settings) and exposes hooks for additional Helm values so environments can tailor the deployment.

## Example

```hcl
module "ngf" {
  source = "../../modules/kubernetes/ngf"

  namespace             = "nginx-gateway"
  release_name          = "ngf"
  chart_url             = "oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric"
  chart_version         = "2.2.1"
  gateway_class_name    = "profile-a-ngf"
  gateway_controller_name = "gateway.nginx.org/nginx-gateway-controller"

  nginx_gateway_replicas = 2
  nginx_data_plane_replicas = 2

  extra_values = {
    nginx = {
      service = {
        loadBalancerIP          = "1.2.3.4"
        loadBalancerSourceRanges = ["10.0.0.0/8"]
      }
    }
  }
}
```

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `namespace` | Namespace for the Helm release. | `string` | `nginx-gateway` |
| `release_name` | Helm release name. | `string` | `ngf` |
| `chart_url` | Helm chart reference (supports OCI URLs). | `string` | `oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric` |
| `chart_version` | Chart version to install (empty = latest). | `string` | `2.2.1` |
| `helm_atomic` / `helm_wait` / `helm_cleanup_on_fail` / `helm_force_update` / `helm_timeout` | Standard Helm release toggles. | various | see `variables.tf` |
| `gateway_class_name` | GatewayClass name managed by this NGF instance. | `string` | `nginx` |
| `gateway_controller_name` | Controller name string. | `string` | `gateway.nginx.org/nginx-gateway-controller` |
| `nginx_gateway_replicas` | Control plane replica count. | `number` | `2` |
| `nginx_gateway_service_annotations` / `nginx_gateway_service_labels` | Maps applied to the control plane Service. | `map(string)` | `{}` |
| `nginx_data_plane_kind` | Data plane workload kind (`deployment` or `daemonSet`). | `string` | `deployment` |
| `nginx_data_plane_replicas` | Data plane replicas (used for deployments). | `number` | `2` |
| `nginx_data_plane_service_*` | Service configuration for the data plane (type, policy, annotations, labels, LB IP/source ranges). | see `variables.tf` | |
| `gateways` | Optional list of Gateway manifests rendered by the chart. | `list(any)` | `[]` |
| `extra_values` | Raw map merged into the Helm values (override/extend anything). | `any` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `namespace` | Namespace where NGF is installed. |
| `release_name` | Helm release name. |
| `gateway_class_name` | GatewayClass managed by this release. |
