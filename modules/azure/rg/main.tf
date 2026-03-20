# When create=true we create the RG; otherwise we just look it up.
resource "azurerm_resource_group" "this" {
  count    = var.create ? 1 : 0
  name     = var.name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create ? 0 : 1
  name  = var.name
}

# Optional lock (only when we created it here)
resource "azurerm_management_lock" "rg_lock" {
  count      = var.create && var.lock ? 1 : 0
  name       = "can-not-delete"
  scope      = azurerm_resource_group.this[0].id
  lock_level = "CanNotDelete"
  notes      = "Locked by Terraform"
}

locals {
  # Unified outputs regardless of create/use-existing switch
  rg_id       = var.create ? azurerm_resource_group.this[0].id       : data.azurerm_resource_group.existing[0].id
  rg_name     = var.create ? azurerm_resource_group.this[0].name     : data.azurerm_resource_group.existing[0].name
  rg_location = var.create ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
  location_normalized = replace(lower(var.location), " ", "")  # "East US" -> "eastus"
}

# Nice safety: if using an existing RG, ensure location matches (prevents typos).
resource "null_resource" "validate_location" {
  count = var.create ? 0 : 1

  lifecycle {
    precondition {
      condition     = lower(local.rg_location) == local.location_normalized
      error_message = "Existing RG '${local.rg_name}' is in location '${local.rg_location}', which does not match requested '${local.location_normalized}'"
    }
  }
}
