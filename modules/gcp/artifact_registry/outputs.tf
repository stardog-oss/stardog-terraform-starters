output "repository_id" {
  description = "Repository ID."
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Repository resource name."
  value       = google_artifact_registry_repository.this.name
}

output "repository_uri" {
  description = "Convenience URI for referencing the repository."
  value       = local.repository_uri
}
