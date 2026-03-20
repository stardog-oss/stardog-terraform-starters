output "network_self_link" {
  description = "Self link of the created VPC network."
  value       = google_compute_network.this.self_link
}

output "network_name" {
  description = "Network name."
  value       = google_compute_network.this.name
}

output "subnet_self_links" {
  description = "Map of subnet name to self link."
  value       = { for k, v in google_compute_subnetwork.this : k => v.self_link }
}

output "subnet_secondary_ranges" {
  description = "Map of subnet name to secondary range definitions."
  value = {
    for k, v in google_compute_subnetwork.this :
    k => v.secondary_ip_range
  }
}
