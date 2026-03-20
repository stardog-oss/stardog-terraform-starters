variable "name" {
  description = "Name of the Secrets Manager secret."
  type        = string
}

variable "description" {
  description = "Description for the secret."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Whether to create a dedicated KMS key for encrypting the secret."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN to use. When provided, create_kms_key must be false."
  type        = string
  default     = null
}

variable "kms_key_alias" {
  description = "Alias for the created KMS key (if create_kms_key = true)."
  type        = string
  default     = null
}

variable "admin_principal_arns" {
  description = "Principals granted full permissions on the created KMS key (in addition to the account root)."
  type        = list(string)
  default     = []
}

variable "read_principal_arns" {
  description = "Principals granted read access to the secret."
  type        = list(string)
  default     = []
}

variable "write_principal_arns" {
  description = "Principals granted write access to the secret."
  type        = list(string)
  default     = []
}

variable "secret_policy_json" {
  description = "Optional custom secret resource policy JSON. Overrides read/write principal lists when provided."
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Recovery window in days for the secret deletion."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to the secret (and created KMS key)."
  type        = map(string)
  default     = {}
}
