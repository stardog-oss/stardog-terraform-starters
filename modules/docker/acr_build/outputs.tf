output "context_hash" {
  description = "Hash of the build context used to trigger rebuilds."
  value       = local.context_hash
}

output "image_tag" {
  description = "Image tag (repository:tag)."
  value       = local.image_tag
}

output "image_uri" {
  description = "Fully-qualified image reference (registry/repository:tag)."
  value       = local.image_uri
}

output "build_trigger_id" {
  description = "ID of the build null_resource (changes whenever a rebuild runs)."
  value       = null_resource.build.id
}
