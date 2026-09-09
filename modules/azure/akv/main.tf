data "azurerm_client_config" "current" {}

locals {
  # use explicit values if provided; otherwise fall back to data source
  tenant_id       = coalesce(var.tenant_id, try(data.azurerm_client_config.current.tenant_id, null))
  admin_object_id = coalesce(var.admin_object_id, try(data.azurerm_client_config.current.object_id, null))
}

resource "azurerm_key_vault" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = local.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = var.rbac_authorization_enabled
  tags                       = var.tags

  # Only create access policies if explicitly requested and we have valid IDs
  dynamic "access_policy" {
    for_each = var.use_access_policies && local.tenant_id != null && local.admin_object_id != null ? [1] : []
    content {
      tenant_id          = local.tenant_id
      object_id          = local.admin_object_id
      secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
    }
  }

  lifecycle {
    precondition {
      condition     = local.tenant_id != null
      error_message = "tenant_id must be provided explicitly or resolvable from azurerm_client_config."
    }
  }
}

# Grant Key Vault Secrets Officer to the admin group (when provided)
resource "azurerm_role_assignment" "kv_secret_officer_admin_group" {
  # rbac_authorization_enabled gate added - real bug this fixes: this assignment was missing the
  # same gate its sibling (kv_secret_officer_admin_object, right below) already has. In
  # access-policy mode (rbac_authorization_enabled = false), Key Vault ignores RBAC role
  # assignments entirely - so a caller setting use_access_policies=true,
  # rbac_authorization_enabled=false, and admin_group_object_id (matching this variable's own
  # description promising the group gets administered) silently ended up with zero real access,
  # since the access_policy block above only ever covers admin_object_id, never the group.
  count                = var.rbac_authorization_enabled && var.admin_group_object_id != null && trimspace(var.admin_group_object_id) != "" ? 1 : 0
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_group_object_id
}

# Optionally grant the specified admin_object_id (single user/SP) the role
resource "azurerm_role_assignment" "kv_secret_officer_admin_object" {
  count                = var.rbac_authorization_enabled && var.admin_object_id != null && var.admin_object_id != "" ? 1 : 0
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_id
}
