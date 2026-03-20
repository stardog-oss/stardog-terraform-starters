output "secret_id" {
  description = "Secret ID."
  value       = google_secret_manager_secret.this.secret_id
}

output "secret_name" {
  description = "Resource name of the secret."
  value       = google_secret_manager_secret.this.name
}

output "project_id" {
  description = "Project that owns the secret."
  value       = google_secret_manager_secret.this.project
}
