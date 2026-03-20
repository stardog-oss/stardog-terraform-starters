
resource "azurerm_container_registry" "this" {
  count = var.manage_acr ? 1 : 0

  name                = var.acr_name # <-- only this
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = var.acr_admin_enabled
  tags                = var.tags
}

data "azurerm_container_registry" "existing" {
  count = var.manage_acr ? 0 : 1

  name                = var.acr_name
  resource_group_name = var.resource_group_name
}

locals {
  acr_id           = var.manage_acr ? azurerm_container_registry.this[0].id : data.azurerm_container_registry.existing[0].id
  acr_name         = var.manage_acr ? azurerm_container_registry.this[0].name : data.azurerm_container_registry.existing[0].name
  acr_login_server = var.manage_acr ? azurerm_container_registry.this[0].login_server : data.azurerm_container_registry.existing[0].login_server
}

resource "azurerm_role_assignment" "acr_pull" {
  for_each             = var.cluster == null ? {} : var.cluster
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = try(each.value.kubelet_object_id, null)

  lifecycle {
    precondition {
      condition     = try(each.value.kubelet_object_id, null) != null
      error_message = "kubelet_object_id must be set when creating the AcrPull assignment."
    }
  }
}
