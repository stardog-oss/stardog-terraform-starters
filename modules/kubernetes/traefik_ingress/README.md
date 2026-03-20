# Traefik Ingress Module

Installs the official Traefik Helm chart into a Kubernetes cluster. The module mirrors the structure of the existing `nginx_ingress` module so environments can optionally deploy Traefik without duplicating Helm logic.

## Inputs

| Name | Description | Type | Default |
| --- | --- | --- | --- |
| `namespace` | Namespace where Traefik will be installed. | `string` | `traefik` |
| `replica_count` | Desired number of Traefik pods. | `number` | `2` |
| `service_type` | Kubernetes Service type (`LoadBalancer`, `ClusterIP`, etc.). | `string` | `LoadBalancer` |
| `service_annotations` | Map of annotations applied to the Service. | `map(string)` | `{}` |
| `extra_values` | Arbitrary Helm values merged with the defaults. | `any` | `{}` |
| `chart_source` | `repo` (default) or `oci`. | `string` | `repo` |
| `chart_repo_url` | Helm repository URL when `chart_source = "repo"`. | `string` | `https://traefik.github.io/charts` |
| `chart_name` | Helm chart name when `chart_source = "repo"`. | `string` | `traefik` |
| `chart_version` | Version when using the repo source (empty = latest). | `string` | `""` |
| `oci_chart_url` | OCI chart reference when `chart_source = "oci"`. | `string` | `null` |
| `oci_chart_version` | OCI chart version when `chart_source = "oci"`. | `string` | `null` |
| `install_gateway_api_crds` | Install Gateway API CRDs before deploying Traefik. | `bool` | `false` |
| `gateway_api_crds_version` | Gateway API release used for CRDs. | `string` | `v1.1.0` |
| `aks_resource_group_name` | AKS resource group (required when installing CRDs). | `string` | `null` |
| `aks_cluster_name` | AKS cluster name (required when installing CRDs). | `string` | `null` |
| `kubeconfig_path` | Path where AKS credentials will be written. | `string` | `~/.kube/config` |

## Outputs

This module intentionally does not export outputs. Consume Helm resources directly if needed.

## Example

```hcl
module "traefik_ingress" {
  source        = "../../modules/kubernetes/traefik_ingress"
  namespace     = "traefik"
  replica_count = 3
  service_type  = "LoadBalancer"

  chart_version = "23.1.0"
  service_annotations = {
    "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/ping"
  }

  install_gateway_api_crds = true
  gateway_api_crds_version = "v1.1.0"
  aks_resource_group_name  = azurerm_resource_group.rg.name
  aks_cluster_name         = module.aks.name
  kubeconfig_path          = local.kubeconfig_path
}
```

When `install_gateway_api_crds` is `true`, the module runs `az aks get-credentials` followed by `kubectl apply` to install the specified Gateway API CRDs before Helm installs Traefik. This keeps Gateway deployments self-contained without repeating the CRD bootstrap logic in every environment.
