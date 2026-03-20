# Azure Kubernetes Service (AKS) – Terraform Module

This module provisions an **AKS cluster** and supports:
- Custom **system** pool sizing (VM size, count, OS disk).
- One or many **user node pools** via a typed map (autoscaling or fixed size).
- Pluggable **Log Analytics** (create new or use existing).
- Optional **AcrPull** attachment to one or more **ACR** registries.
- Consistent **tags** across resources.

> This README matches the variable set you provided and includes usage examples, validations guidance, and common patterns.

---

## Requirements

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.0.0" }
  }
}

provider "azurerm" {
  features {}
}
```
Authenticate via Azure CLI, Managed Identity, or environment variables per the azurerm provider docs.

---

## Quick Start

```hcl
module "aks" {
  source = "../../modules/azure/aks"

  subscription_id        = var.subscription_id
  resource_group_name    = var.resource_group_name
  location               = var.location
  name                   = "profile-a-aks"

  # Cluster networking (kubenet example)
  service_cidr           = "10.0.0.0/16"
  dns_service_ip         = "10.0.0.10"
  pod_cidr               = "10.244.0.0/16"

  # System pool
  system_vm_size         = "Standard_D2_v2"
  system_count           = 2
  system_os_disk_size_gb = 128

  # Optional: pin version (or leave null for platform default)
  kubernetes_version     = null

  # Optional: managed node RG name (else Azure generates one)
  node_resource_group    = null

  # Optional: attach ACR(s) for pulls
  attach_acr_id          = var.acr_id           # single ACR id (or null)
  attach_acr_ids         = []                   # additional ACR ids if any

  # Optional: extra user pools
  user_node_pools = {
    sdpool = {
      vm_size              = "Standard_D4s_v4"
      os_disk_size_gb      = 128
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
      node_taints          = ["workload=stardog:NoSchedule"]
      node_labels          = { role = "stardog" }
    }
  }

  # Monitoring
  create_log_analytics       = true
  log_analytics_workspace_id = null

  tags = {
    env   = "stage"
    owner = "platform"
  }
}
```

Apply:
```bash
terraform init -reconfigure
terraform plan -out tfplan
terraform apply tfplan
```

---

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `subscription_id` | `string` | n/a | Azure subscription UUID where the AKS cluster is created. |
| `resource_group_name` | `string` | n/a | Resource Group that will contain the AKS control-plane resource. |
| `location` | `string` | n/a | Azure region (API name, e.g. `eastus`). |
| `name` | `string` | n/a | Logical AKS cluster name. |
| `kubernetes_version` | `string` | `null` | Cluster Kubernetes version (e.g., `1.31.8`). `null` lets the platform choose. |
| `node_resource_group` | `string` | `null` | Managed **node** resource group name; if `null`, Azure will generate it. |
| `service_cidr` | `string` | `"10.0.0.0/16"` | Service CIDR (cluster IP range for Services). Must not overlap with pod/VNet. |
| `dns_service_ip` | `string` | `"10.0.0.10"` | IP inside `service_cidr` for CoreDNS. |
| `pod_cidr` | `string` | `"10.244.0.0/16"` | Pod CIDR when using **kubenet**. |
| `system_vm_size` | `string` | n/a | VM size for the **System** pool (e.g., `Standard_D2_v2`). |
| `system_count` | `number` | n/a | Initial node count for the System pool. |
| `system_os_disk_size_gb` | `number` | n/a | OS disk size (GB) for the System pool. |
| `tags` | `map(string)` | `{}` | Tags applied to AKS resources. |
| `attach_acr_ids` | `list(string)` | `[]` | **Additional** ACR resource IDs to grant **AcrPull** to the kubelet identity. |
| `attach_acr_id` | `string` | `null` | Single ACR resource ID (e.g., newly created) to grant **AcrPull**. |
| `user_node_pools` | `map(object)` | n/a | Additional **User** pools (see details below). |
| `create_log_analytics` | `bool` | `true` | Create a Log Analytics workspace for monitoring. |
| `log_analytics_workspace_id` | `string` | `null` | If not creating, pass an **existing** workspace ARM ID. |

### `user_node_pools` shape
Key = pool name (1–12 lowercase alphanumeric). Value is:
```hcl
{
  vm_size               = string
  os_disk_size_gb       = number
  orchestrator_version  = optional(string)         # omit to inherit cluster version
  auto_scaling_enabled  = optional(bool, true)
  min_count             = optional(number)
  max_count             = optional(number)
  node_count            = optional(number)         # use when autoscaling is false
  mode                  = optional(string, "User") # keep as "User"
  node_taints           = optional(list(string), [])
  node_labels           = optional(map(string), {})
  tags                  = optional(map(string), {})
}
```

**Rules of thumb**
- If `auto_scaling_enabled = true`, set `min_count` and `max_count` and **do not** set `node_count`.
- If `auto_scaling_enabled = false`, set `node_count` and **omit** `min_count`/`max_count`.

---

## ACR attachments (AcrPull)

You can attach none, one, or many registries. The module will grant **AcrPull** to the cluster’s **kubelet managed identity**.

```hcl
# Single newly created ACR
attach_acr_id  = module.acr.id
# Additional existing ACRs
attach_acr_ids = [
  "/subscriptions/.../resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/anotheracr"
]
```

> If the kubelet identity isn’t known until apply, the module uses plan‑safe patterns and validates at apply time.

---

## Monitoring

- `create_log_analytics = true` → module creates a Log Analytics Workspace and wires AKS (via the OMS/ContainerInsights addon).
- `create_log_analytics = false` + `log_analytics_workspace_id = "<ARM ID>"` → re-use an existing workspace.

---

## Common Patterns

**Two user pools (one autoscaled, one fixed):**
```hcl
user_node_pools = {
  sdpool = {
    vm_size              = "Standard_D4s_v4"
    os_disk_size_gb      = 128
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 3
    node_taints          = ["workload=stardog:NoSchedule"]
  }
  tools = {
    vm_size         = "Standard_D2s_v5"
    os_disk_size_gb = 64
    node_count      = 1
    node_labels     = { usage = "tools" }
  }
}
```

**Use a custom node RG name (needed if you pre‑create LB public IPs):**
```hcl
node_resource_group = "my-aks-nodes-rg"
```

---

## Outputs (example)

> Adjust this section to match your `outputs.tf`. Typical outputs include:

```hcl
output "id"                 { value = azurerm_kubernetes_cluster.this.id }
output "name"               { value = azurerm_kubernetes_cluster.this.name }
output "node_resource_group"{ value = azurerm_kubernetes_cluster.this.node_resource_group }
output "kubelet_object_id"  { value = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, null) }
output "oidc_issuer_url"    { value = try(azurerm_kubernetes_cluster.this.oidc_issuer_url, null) }
```

---

## Tips & Gotchas

- **Address spaces**: Ensure `service_cidr`, `dns_service_ip`, and `pod_cidr` do not overlap with your VNet.
- **Autoscaling vs fixed size**: Only set `node_count` when autoscaling is **disabled**.
- **ACR name rules**: ACR names are lowercase alphanumeric (5–50). Provide full ARM IDs in `attach_acr_*`.
- **Apply order**: If ACR or Log Analytics are created in other modules, pass their IDs here (or run those modules first).

---

## Destroy

```bash
terraform destroy
```
Make sure you detach external dependencies (e.g., ACR role assignments in other stacks) before tearing down the cluster.
