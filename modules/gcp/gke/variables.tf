variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "location" {
  description = "Region or zone for the cluster."
  type        = string
}

variable "description" {
  description = "Optional cluster description."
  type        = string
  default     = null
}

variable "enable_autopilot" {
  description = "Enable Autopilot mode."
  type        = bool
  default     = false
}

variable "network" {
  description = "VPC network self link or name."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork self link or name."
  type        = string
  default     = null
}

variable "logging_service" {
  description = "Logging service for the cluster."
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  description = "Monitoring service for the cluster."
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "master_version" {
  description = "Desired master version."
  type        = string
  default     = null
}

variable "release_channel" {
  description = "Release channel (RAPID, REGULAR, STABLE)."
  type        = string
  default     = null
}

variable "ip_allocation_policy" {
  description = "IP allocation policy for VPC-native clusters."
  type = object({
    cluster_secondary_range_name  = optional(string)
    services_secondary_range_name = optional(string)
  })
  default = null
}

variable "private_cluster" {
  description = "Private cluster configuration."
  type = object({
    enable_private_nodes    = optional(bool, true)
    enable_private_endpoint = optional(bool, false)
    master_ipv4_cidr_block  = optional(string)
  })
  default = null
}

variable "master_authorized_ranges" {
  description = "Authorized CIDR ranges for master access."
  type = list(object({
    cidr_block   = string
    display_name = optional(string)
  }))
  default = []
}

variable "workload_identity_pool" {
  description = "Workload identity pool to enable workfload identity."
  type        = string
  default     = null
}

variable "maintenance_policy" {
  description = "Maintenance policy configuration."
  type = object({
    daily_window = optional(object({
      start_time = string
      duration   = optional(string)
    }))
    recurring_window = optional(object({
      start_time = string
      end_time   = string
      recurrence = string
    }))
  })
  default = null
}

variable "node_pools" {
  description = "Map of node pool configurations (ignored when Autopilot is enabled)."
  type = map(object({
    machine_type     = string
    disk_size_gb     = optional(number, 100)
    disk_type        = optional(string, "pd-standard")
    image_type       = optional(string, "COS_CONTAINERD")
    service_account  = optional(string)
    oauth_scopes     = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
    metadata         = optional(map(string), {})
    labels           = optional(map(string), {})
    tags             = optional(list(string), [])
    taints           = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    auto_repair      = optional(bool, true)
    auto_upgrade     = optional(bool, true)
    min_count        = optional(number, 1)
    max_count        = optional(number, 3)
    initial_count    = optional(number, 1)
    max_pods_per_node = optional(number, null)
  }))
  default = {}
}
