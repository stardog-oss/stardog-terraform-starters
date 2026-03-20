# GCP GKE Cluster

> **Warning:** Yet to be tested.

Creates a Google Kubernetes Engine cluster with optional node pools, private control plane, and workload identity support.

## Features
- Supports both standard and Autopilot clusters.
- Optional release channels, private clusters, authorized networks, and maintenance windows.
- Individual node pool definitions with autoscaling, taints, and metadata controls.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | `string` | n/a | GCP project ID. |
| `name` | `string` | n/a | Cluster name. |
| `location` | `string` | n/a | Region or zone. |
| `description` | `string` | `null` | Optional description. |
| `enable_autopilot` | `bool` | `false` | Enable Autopilot mode (node pool map ignored). |
| `network` | `string` | `null` | VPC network self link or name. |
| `subnetwork` | `string` | `null` | Subnetwork self link or name. |
| `logging_service` | `string` | `"logging.googleapis.com/kubernetes"` | Logging service. |
| `monitoring_service` | `string` | `"monitoring.googleapis.com/kubernetes"` | Monitoring service. |
| `master_version` | `string` | `null` | Target master version. |
| `release_channel` | `string` | `null` | Release channel (`RAPID`, `REGULAR`, `STABLE`). |
| `ip_allocation_policy` | `object({ cluster_secondary_range_name = optional(string), services_secondary_range_name = optional(string) })` | `null` | Pod/service secondary ranges. |
| `private_cluster` | `object({ enable_private_nodes = optional(bool), enable_private_endpoint = optional(bool), master_ipv4_cidr_block = optional(string) })` | `null` | Private cluster settings. |
| `master_authorized_ranges` | `list(object({ cidr_block = string, display_name = optional(string) }))` | `[]` | Master authorized networks. |
| `workload_identity_pool` | `string` | `null` | Workload identity pool (`PROJECT_ID.svc.id.goog`). |
| `maintenance_policy` | `object({ daily_window = optional(object({ start_time = string, duration = optional(string) })), recurring_window = optional(object({ start_time = string, end_time = string, recurrence = string })) })` | `null` | Maintenance policy. |
| `node_pools` | `map(object({ machine_type = string, disk_size_gb = optional(number), disk_type = optional(string), image_type = optional(string), service_account = optional(string), oauth_scopes = optional(list(string)), metadata = optional(map(string)), labels = optional(map(string)), tags = optional(list(string)), taints = optional(list(object({ key = string, value = string, effect = string }))), auto_repair = optional(bool), auto_upgrade = optional(bool), min_count = optional(number), max_count = optional(number), initial_count = optional(number), max_pods_per_node = optional(number) }))` | `{}` | Node pool configurations (ignored in Autopilot). |

## Outputs
| Name | Description |
|------|-------------|
| `cluster_name` | Cluster name. |
| `cluster_endpoint` | API endpoint. |
| `cluster_ca_certificate` | Base64 CA certificate. |
| `location` | Cluster location. |
| `node_pool_names` | Managed node pool names. |

## Example
```hcl
module "gke" {
  source     = "../../modules/gcp/gke"
  project_id = var.project_id
  name       = "${var.inst_id}-gke"
  location   = "us-central1"
  network    = module.network.network_self_link
  subnetwork = module.network.subnet_self_links["${var.inst_id}-primary"]

  ip_allocation_policy = {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  node_pools = {
    stardog = {
      machine_type  = "e2-standard-8"
      min_count     = 1
      max_count     = 3
      labels        = { workload = "stardog" }
      taints        = [{ key = "workload", value = "stardog", effect = "NO_SCHEDULE" }]
    }
  }
}
```

## See Also
- [GCP VPC module](../network/README.md) - provisions the network and subnets consumed by this cluster.
- [Artifact Registry module](../artifact_registry/README.md) - store container images deployed onto the cluster.
