# GCP VPC Network

> **Warning:** Yet to be tested.

Creates a VPC network and optional subnetworks suitable for GKE or other workloads.

## Features
- Configurable routing mode, MTU, and description.
- Manages multiple subnetworks with optional secondary IP ranges for GKE.
- Supports enabling flow logs per subnet.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_id` | `string` | n/a | GCP project ID. |
| `network_name` | `string` | n/a | VPC network name. |
| `auto_create_subnetworks` | `bool` | `false` | Enable Google-managed subnetworks. |
| `routing_mode` | `string` | `"GLOBAL"` | Network routing mode. |
| `mtu` | `number` | `1460` | Network MTU. |
| `description` | `string` | `null` | Optional description. |
| `subnets` | `list(object({ name = string, region = string, ip_cidr_range = string, purpose = optional(string), role = optional(string), stack_type = optional(string), private_ip_google_access = optional(bool), secondary_ip_ranges = optional(list(object({ range_name = string, ip_cidr_range = string }))), enable_flow_logs = optional(bool), flow_logs_aggregation_interval = optional(string), flow_logs_sampling = optional(number), flow_logs_metadata = optional(string) }))` | `[]` | Subnet definitions. |

## Outputs
| Name | Description |
|------|-------------|
| `network_self_link` | Self link of the VPC. |
| `network_name` | Name of the VPC. |
| `subnet_self_links` | Map of subnet name to self link. |
| `subnet_secondary_ranges` | Map of subnet name to secondary ranges. |

## Example
```hcl
module "network" {
  source      = "../../modules/gcp/network"
  project_id  = var.project_id
  network_name = "${var.inst_id}-network"

  subnets = [
    {
      name          = "${var.inst_id}-primary"
      region        = "us-central1"
      ip_cidr_range = "10.70.0.0/16"
      secondary_ip_ranges = [
        { range_name = "pods",     ip_cidr_range = "10.72.0.0/18" },
        { range_name = "services", ip_cidr_range = "10.73.0.0/24" }
      ]
    }
  ]
}
```

## See Also
- [GKE module](../gke/README.md) - consumes the network and subnets created here.
