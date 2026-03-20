output "namespace" {
  description = "Namespace where NGF was installed."
  value       = kubernetes_namespace_v1.ngf.metadata[0].name
}

output "release_name" {
  description = "Name of the NGF Helm release."
  value       = helm_release.ngf.name
}

output "gateway_class_name" {
  description = "GatewayClass managed by this NGF installation."
  value       = var.gateway_class_name
}
