variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secret_id" {
  description = "Secret identifier."
  type        = string
}

variable "labels" {
  description = "Labels applied to the secret."
  type        = map(string)
  default     = {}
}

variable "replication" {
  description = "Replication configuration."
  type = object({
    automatic = optional(bool, true)
    locations = optional(list(string), [])
  })
  default = {}
}

variable "iam_bindings" {
  description = "IAM bindings applied to the secret."
  type = list(object({
    role    = string
    members = list(string)
    condition = optional(object({
      title       = string
      description = optional(string)
      expression  = string
    }))
  }))
  default = []
}
