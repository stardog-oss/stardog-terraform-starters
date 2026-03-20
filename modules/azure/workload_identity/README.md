# Azure Workload Identity

Creates a user-assigned managed identity (UAMI) and federated credential for AKS workload identity integration.

## Features
- Provisions a dedicated UAMI for the workload.
- Configures a federated identity credential targeting a specific service account and namespace.
- Returns identifiers for wiring RBAC or secret access policies.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `resource_group_name` | `string` | n/a | Resource group where the UAMI is created. |
| `location` | `string` | n/a | Azure region. |
| `cluster_oidc_issuer` | `string` | n/a | AKS OIDC issuer URL. |
| `namespace` | `string` | n/a | Kubernetes namespace owning the service account. |
| `service_account` | `string` | n/a | Kubernetes service account name. |
| `cluster_name` | `string` | n/a | AKS cluster name, used for naming convention. |
| `tags` | `map(string)` | `{}` | Tags applied to the UAMI. |

## Outputs
| Name | Description |
|------|-------------|
| `uami_client_id` | Client ID of the managed identity. |
| `uami_object_id` | Principal (object) ID of the managed identity. |

## Example
```hcl
module "stardog_workload_identity" {
  source               = "../../modules/azure/workload_identity"
  resource_group_name  = azurerm_resource_group.cluster.name
  location             = azurerm_resource_group.cluster.location
  cluster_name         = module.aks.name
  cluster_oidc_issuer  = module.aks.oidc_issuer
  namespace            = "stardog"
  service_account      = "stardog-launchpad"
  tags                 = var.tags
}
```
