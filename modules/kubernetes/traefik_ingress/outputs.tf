output "namespace" {
  value = kubernetes_namespace_v1.traefik.metadata[0].name
}

output "release_name" {
  value = coalesce(
    try(helm_release.traefik_repo[0].name, null),
    try(helm_release.traefik_oci[0].name, null)
  )
}
