locals {
  default_subnet = {
    purpose                        = null
    role                           = null
    private_ip_google_access       = true
    stack_type                     = null
    enable_flow_logs               = false
    flow_logs_aggregation_interval = null
    flow_logs_sampling             = null
    flow_logs_metadata             = null
  }
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks
  description             = var.description
  routing_mode            = var.routing_mode
  mtu                     = var.mtu
}

resource "google_compute_subnetwork" "this" {
  for_each = {
    for subnet in var.subnets :
    subnet.name => merge(local.default_subnet, subnet)
  }

  project                  = var.project_id
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.this.self_link
  purpose                  = each.value.purpose
  role                     = each.value.role
  stack_type               = each.value.stack_type
  private_ip_google_access = each.value.private_ip_google_access

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  dynamic "log_config" {
    for_each = each.value.enable_flow_logs ? [each.value] : []
    content {
      aggregation_interval = coalesce(log_config.value.flow_logs_aggregation_interval, "INTERVAL_5_MIN")
      flow_sampling        = coalesce(log_config.value.flow_logs_sampling, 0.5)
      metadata             = coalesce(log_config.value.flow_logs_metadata, "INCLUDE_ALL_METADATA")
    }
  }
}
