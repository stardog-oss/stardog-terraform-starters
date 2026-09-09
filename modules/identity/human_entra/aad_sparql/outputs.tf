output "client_id" { value = azuread_application.app.client_id }
output "sp_object_id" { value = azuread_service_principal.sp.object_id }
output "secret" {
    value = azuread_application_password.pwd.value
    sensitive = true
}
output "app_object_id" { value = azuread_application.app.id }
output "secret_entries" {
  # Real leak this fixes: secret_entries embeds the same plaintext azuread_application_password.pwd
  # value as the "secret" output right above it - that one is correctly marked sensitive, this one
  # wasn't, printing the client secret to apply/output/CI logs.
  value     = local.secret_entries
  sensitive = true
}
