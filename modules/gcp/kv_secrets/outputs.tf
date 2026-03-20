output "secret_names" {
  description = "Map of logical name to created secret resource name."
  value       = { for k, v in google_secret_manager_secret.entry : k => v.name }
}

output "aggregate_payload" {
  description = "JSON payload written to aggregate secret when enabled."
  value       = var.aggregate_json ? local.aggregate_payload : null
}
