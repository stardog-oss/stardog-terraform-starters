output "name" {
  value = azurerm_kubernetes_cluster.this.name
}
output "kube_config" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}
output "kubelet_object_id" {
  value       = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, null)
  description = "Object ID of the AKS kubelet managed identity."
}
output "cluster_identity_principal_id" {
  value       = try(azurerm_kubernetes_cluster.this.identity[0].principal_id, null)
  description = "Principal ID of the AKS control plane managed identity."
}
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "cluster_id" { value = azurerm_kubernetes_cluster.this.id }

output "log_analytics_workspace_id" {
  value       = try(azurerm_log_analytics_workspace.this[0].id, null)
  description = "ID of the Log Analytics workspace created by this module (if create_log_analytics = true)."
}

output "log_analytics_workspace_name" {
  value       = try(azurerm_log_analytics_workspace.this[0].name, null)
  description = "Name of the Log Analytics workspace created by this module (if create_log_analytics = true)."
}

output "kube_host" {
  value = azurerm_kubernetes_cluster.this.kube_config[0].host
}
output "kube_client_certificate" {
  value = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
}
output "kube_client_key" {
  value = azurerm_kubernetes_cluster.this.kube_config[0].client_key
}
output "kube_cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
}
# (If you prefer admin config, export kube_admin_config equivalents instead.)

output "ingress_application_gateway_id" {
  description = "Resource ID of the Application Gateway managed by the AKS ingress add-on (if enabled)."
  value       = var.enable_ingress_application_gateway ? try(azurerm_kubernetes_cluster.this.ingress_application_gateway[0].effective_gateway_id, null) : null
}

output "node_resource_group" {
  description = "Name of the AKS node resource group (where load balancers and node resources live)."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
