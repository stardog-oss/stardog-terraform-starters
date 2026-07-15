output "role_name" {
  description = "Managed Stardog role name."
  value       = var.name
}

output "apply_command" {
  description = "Local stardog-admin command used to ensure the role (for debugging)."
  value       = local.ensure_command
  sensitive   = true
}

output "destroy_command" {
  description = "Local stardog-admin command used to remove the role (for debugging)."
  value       = local.destroy_command
  sensitive   = true
}
