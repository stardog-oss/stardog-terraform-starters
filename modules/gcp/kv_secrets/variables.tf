variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secrets" {
  description = "Map of logical secret names to payload definitions."
  type = map(object({
    value       = string
    labels      = optional(map(string))
    replication = optional(object({
      automatic = optional(bool, true)
      locations = optional(list(string), [])
    }))
  }))
  default = {}
}

variable "secret_name_prefix" {
  description = "Optional prefix for generated secret IDs."
  type        = string
  default     = null
}

variable "default_replication" {
  description = "Default replication policy for generated secrets."
  type = object({
    automatic = optional(bool, true)
    locations = optional(list(string), [])
  })
  default = {
    automatic = true
    locations = []
  }
}

variable "aggregate_secret_id" {
  description = "Optional existing secret resource name to store aggregate JSON payload."
  type        = string
  default     = null
}

variable "aggregate_json" {
  description = "When true, writes a JSON document of all entries to aggregate_secret_id."
  type        = bool
  default     = false
}
