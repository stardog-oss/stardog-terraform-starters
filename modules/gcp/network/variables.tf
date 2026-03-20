variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
}

variable "auto_create_subnetworks" {
  description = "Whether to create Google-managed subnetworks."
  type        = bool
  default     = false
}

variable "routing_mode" {
  description = "Routing mode for the network (GLOBAL or REGIONAL)."
  type        = string
  default     = "GLOBAL"
}

variable "mtu" {
  description = "Maximum transmission unit for the network."
  type        = number
  default     = 1460
}

variable "description" {
  description = "Optional description for the network."
  type        = string
  default     = null
}

variable "subnets" {
  description = "List of subnet configurations to create."
  type = list(object({
    name                     = string
    region                   = string
    ip_cidr_range            = string
    purpose                  = optional(string)
    role                     = optional(string)
    stack_type               = optional(string)
    private_ip_google_access = optional(bool, true)
    secondary_ip_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
    enable_flow_logs               = optional(bool, false)
    flow_logs_aggregation_interval = optional(string)
    flow_logs_sampling             = optional(number)
    flow_logs_metadata             = optional(string)
  }))
  default = []
}
