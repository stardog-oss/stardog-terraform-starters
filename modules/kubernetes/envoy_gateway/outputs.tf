output "namespace" {
  description = "Namespace where Envoy Gateway is installed."
  value       = kubernetes_namespace_v1.envoy_gateway.metadata[0].name
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.envoy_gateway.name
}
