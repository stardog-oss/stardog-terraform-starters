resource "azurerm_key_vault_secret" "this" {
  for_each     = var.secrets
  name         = each.key
  value        = each.value.value
  key_vault_id = var.key_vault_id
  content_type = lookup(each.value, "content_type", null)
  # secrets are expected to be created after the AKV module ensures the
  # operator has the necessary role assignment (if RBAC is enabled).
}
