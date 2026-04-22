data "azurerm_kubernetes_cluster" "target" {
  name                = var.aks_name
  resource_group_name = var.resource_group_name
}

locals {
  kube_config_source = (
    length(data.azurerm_kubernetes_cluster.target.kube_admin_config) > 0 ?
    data.azurerm_kubernetes_cluster.target.kube_admin_config[0] :
    data.azurerm_kubernetes_cluster.target.kube_config[0]
  )
  kube_host  = local.kube_config_source.host
  client_key = base64decode(local.kube_config_source.client_key)
  client_crt = base64decode(local.kube_config_source.client_certificate)
  ca_crt     = base64decode(local.kube_config_source.cluster_ca_certificate)
}

provider "kubernetes" {
  host                   = local.kube_host
  client_certificate     = local.client_crt
  client_key             = local.client_key
  cluster_ca_certificate = local.ca_crt
}

provider "helm" {
  kubernetes = {
    host                   = local.kube_host
    client_certificate     = local.client_crt
    client_key             = local.client_key
    cluster_ca_certificate = local.ca_crt
  }
}
