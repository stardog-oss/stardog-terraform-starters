output "namespace" { value = kubernetes_namespace_v1.ingress.metadata[0].name }

output "release_name" {
  value = coalesce(
    try(helm_release.ingress_repo[0].name, null),
    try(helm_release.ingress_oci[0].name, null)
  )
}
