# modules/azure/container_registry/outputs.tf
output "id" { value = local.acr_id }
output "name" { value = local.acr_name }
output "login_server" { value = local.acr_login_server } # e.g. myacr.azurecr.io
output "login_server_url" { value = "https://${local.acr_login_server}" }
