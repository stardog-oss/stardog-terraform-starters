variable "repository_name" {
  description = "ECR repository name."
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository."
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable image scanning on push."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type for the repository (AES256 or KMS)."
  type        = string
  default     = "AES256"
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN when encryption_type is KMS."
  type        = string
  default     = null
}

variable "force_delete" {
  description = "Force delete the repository even if images exist."
  type        = bool
  default     = false
}

variable "lifecycle_policy" {
  description = "Optional lifecycle policy JSON for the repository."
  type        = string
  default     = null
}

variable "repository_policy_json" {
  description = "Optional custom repository policy JSON. Overrides pull_principal_arns when set."
  type        = string
  default     = null
}

variable "pull_principal_arns" {
  description = "List of IAM principal ARNs granted pull access via repository policy when repository_policy_json is not provided."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the repository."
  type        = map(string)
  default     = {}
}

variable "source_registry_username" {
  description = "Optional source registry username, applied only to images whose parsed registry (from the image string itself) isn't the default docker.io - see local.import_source_registry."
  type        = string
  default     = null
}

variable "source_registry_password" {
  description = "Optional source registry password or access token used with source_registry_username when importing images."
  type        = string
  default     = null
  sensitive   = true
}

variable "import_images" {
  description = "Whether to import images from the source registry into this ECR repository."
  type        = bool
  default     = false
}

variable "images_to_import" {
  description = "List of images (repository:tag) to import from the source registry into this ECR repository."
  type        = list(string)
  default     = []
}
