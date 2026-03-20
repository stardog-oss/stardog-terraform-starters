output "namespace" {
  description = "The Kubernetes namespace where the Stardog release is deployed."
  value       = var.namespace
}

output "release" {
  description = "The Helm release name used for the Stardog deployment."
  value       = var.release_name
}

output "auto_configure_resources_warning" {
  description = "Displays a warning when auto resource sizing is enabled."
  value       = var.auto_configure_resources ? "WARNING: auto_configure_resources is intended for initial sizing only. Review the generated CPU/memory values and hard-code production-ready requests/limits before going live." : null
}
