variable "secret_arn" {
  description = "ARN of the base Secrets Manager secret (used for optional aggregated storage and deriving per-secret names)."
  type        = string
}

variable "secrets" {
  description = "Map of secret name => { value, content_type? } entries to persist."
  # Not marked sensitive at the variable level, deliberately: the map's KEYS feed for_each
  # (sanitized_entries -> aws_secretsmanager_secret.entry), and Terraform forbids sensitive values
  # as for_each keys (the keys would leak into resource addresses/state, defeating the point).
  # aws_secretsmanager_secret_version.entry's own secret_string is already provider-schema-sensitive
  # on its own - the real gap was only the hand-rolled aggregate_payload output, fixed below.
  type = map(object({
    value        = string
    content_type = optional(string)
  }))
  default = {}
}

variable "secret_name_prefix" {
  description = "Optional prefix for per-entry Secrets Manager secret names. Defaults to the base secret's name."
  type        = string
  default     = null
}

variable "aggregate_json" {
  description = "When true, also write a single JSON payload containing all entries to the base secret_arn."
  type        = bool
  default     = false
}
