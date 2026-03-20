output "ids" { value = { for k, v in azurerm_key_vault_secret.this : k => v.id } }
