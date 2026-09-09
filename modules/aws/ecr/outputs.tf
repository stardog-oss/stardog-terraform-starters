output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "dest_registry_host" {
  description = "Registry host stripped of the repository path - used by the image-import provisioner's docker login/logout, exposed here so tests/ can verify it directly."
  value       = local.dest_registry_host
}
