output "namespace" {
  value       = var.namespace
  description = "Namespace where cert-manager is installed."
}

output "release_name" {
  value       = coalesce(try(helm_release.cert_manager_repo[0].name, null),
                         try(helm_release.cert_manager_oci[0].name, null))
  description = "Helm release name for cert-manager."
}

