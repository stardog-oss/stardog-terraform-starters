output "namespace" {
  value       = kubernetes_namespace_v1.haproxy_gateway.metadata[0].name
  description = "Namespace for the HAProxy Gateway installation."
}

output "release_name" {
  value       = helm_release.haproxy_gateway.name
  description = "Helm release name for HAProxy Gateway."
}
