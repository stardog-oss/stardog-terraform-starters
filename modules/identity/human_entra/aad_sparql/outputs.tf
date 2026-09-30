output "client_id" { value = azuread_application.app.client_id }
output "sp_object_id" { value = azuread_service_principal.sp.object_id }
output "secret" {
  value     = azuread_application_password.pwd.value
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
output "app_role_ids" {
  # {role_key => derived GUID} - consumed by callers (e.g. envctl's infra/main.tf) to assign this
  # app's own app roles to a principal without ever needing to know/pass a GUID themselves.
  value = local.app_role_ids
}
