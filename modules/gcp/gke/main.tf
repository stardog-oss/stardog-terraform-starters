locals {
  formatted_release_channel = var.release_channel == null ? null : upper(var.release_channel)
  effective_node_pools      = var.enable_autopilot ? {} : var.node_pools
}

resource "google_container_cluster" "this" {
  project                  = var.project_id
  name                     = var.name
  location                 = var.location
  description              = var.description
  enable_autopilot         = var.enable_autopilot
  remove_default_node_pool = !var.enable_autopilot
  initial_node_count       = var.enable_autopilot ? null : 1
  network                  = var.network
  subnetwork               = var.subnetwork
  logging_service          = var.logging_service
  monitoring_service       = var.monitoring_service
  min_master_version       = var.master_version

  dynamic "release_channel" {
    for_each = local.formatted_release_channel != null ? [local.formatted_release_channel] : []
    content {
      channel = release_channel.value
    }
  }

  dynamic "ip_allocation_policy" {
    for_each = (var.ip_allocation_policy == null) ? [] : [var.ip_allocation_policy]
    content {
      cluster_secondary_range_name  = lookup(ip_allocation_policy.value, "cluster_secondary_range_name", null)
      services_secondary_range_name = lookup(ip_allocation_policy.value, "services_secondary_range_name", null)
    }
  }

  dynamic "private_cluster_config" {
    for_each = var.private_cluster == null ? [] : [var.private_cluster]
    content {
      enable_private_nodes    = lookup(private_cluster_config.value, "enable_private_nodes", false)
      enable_private_endpoint = lookup(private_cluster_config.value, "enable_private_endpoint", false)
      master_ipv4_cidr_block  = lookup(private_cluster_config.value, "master_ipv4_cidr_block", null)
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_ranges) > 0 ? [var.master_authorized_ranges] : []
    content {
      dynamic "cidr_blocks" {
        for_each = master_authorized_networks_config.value
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  dynamic "workload_identity_config" {
    for_each = var.workload_identity_pool != null ? [var.workload_identity_pool] : []
    content {
      workload_pool = workload_identity_config.value
    }
  }

  dynamic "maintenance_policy" {
    for_each = var.maintenance_policy != null ? [var.maintenance_policy] : []
    content {
      dynamic "daily_maintenance_window" {
        for_each = lookup(maintenance_policy.value, "daily_window", null) != null ? [maintenance_policy.value.daily_window] : []
        content {
          start_time = daily_maintenance_window.value.start_time
          duration   = daily_maintenance_window.value.duration
        }
      }
      dynamic "recurring_window" {
        for_each = lookup(maintenance_policy.value, "recurring_window", null) != null ? [maintenance_policy.value.recurring_window] : []
        content {
          start_time = recurring_window.value.start_time
          end_time   = recurring_window.value.end_time
          recurrence = recurring_window.value.recurrence
        }
      }
    }
  }
}

resource "google_container_node_pool" "this" {
  for_each = local.effective_node_pools

  project  = var.project_id
  cluster  = google_container_cluster.this.name
  location = var.location
  name     = each.key

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    image_type   = each.value.image_type
    service_account = each.value.service_account
    oauth_scopes    = each.value.oauth_scopes
    metadata        = each.value.metadata
    labels          = each.value.labels
    tags            = each.value.tags

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  autoscaling {
    min_node_count = each.value.min_count
    max_node_count = each.value.max_count
  }

  initial_node_count = each.value.initial_count
  max_pods_per_node  = each.value.max_pods_per_node
}
