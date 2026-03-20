output "client_id" { value = azuread_application.app.client_id }
output "sp_object_id" { value = azuread_service_principal.sp.object_id }
output "secret" {
    value = azuread_application_password.pwd.value
    sensitive = true
}
output "secret_entries" { value = local.secret_entries }
