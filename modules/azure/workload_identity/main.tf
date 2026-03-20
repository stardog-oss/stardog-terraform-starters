resource "azurerm_user_assigned_identity" "uami" {
  name                = "uami-${var.cluster_name}-stardog"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "fic" {
  name                = "fic-${var.cluster_name}-stardog"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.uami.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.cluster_oidc_issuer
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}
