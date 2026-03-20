output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
}

output "location" {
  description = "Cluster location (region or zone)."
  value       = google_container_cluster.this.location
}

output "node_pool_names" {
  description = "Names of managed node pools."
  value       = keys(local.effective_node_pools)
}
