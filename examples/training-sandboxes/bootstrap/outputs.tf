output "resource_group_name" {
  value       = data.azurerm_resource_group.bootstrap.name
  description = "Resource group used for shared training resources."
}

output "automation_account_name" {
  value       = azurerm_automation_account.central.name
  description = "Central Automation Account name."
}

output "automation_account_id" {
  value       = azurerm_automation_account.central.id
  description = "Central Automation Account resource ID."
}

output "automation_account_principal_id" {
  value       = azurerm_automation_account.central.identity[0].principal_id
  description = "Principal ID for the Automation Account managed identity."
}

output "tfstate_storage_account_id" {
  value       = data.azurerm_storage_account.tfstate.id
  description = "Storage account ID for the shared tfstate."
}
