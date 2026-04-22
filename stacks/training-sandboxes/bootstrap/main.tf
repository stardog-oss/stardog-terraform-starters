provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

locals {
  rg_location = coalesce(var.location, data.azurerm_resource_group.bootstrap.location)
  common_tags = merge(var.tags, { name_prefix = var.name_prefix })
}

data "azurerm_resource_group" "bootstrap" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "tfstate" {
  name                = var.tfstate_storage_account_name
  resource_group_name = var.tfstate_resource_group_name
}

resource "azurerm_automation_account" "central" {
  name                = var.automation_account_name
  location            = local.rg_location
  resource_group_name = data.azurerm_resource_group.bootstrap.name
  sku_name            = "Basic"
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }
}
