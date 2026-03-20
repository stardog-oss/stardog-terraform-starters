variable "project_id" {
  description = "GCP project ID that owns the repository."
  type        = string
}

variable "location" {
  description = "Region for the repository (e.g., us-central1)."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
}

variable "format" {
  description = "Repository format (DOCKER, OCI, MAVEN, NPM, PYTHON, APT, YUM, HELM)."
  type        = string
  default     = "DOCKER"
}

variable "description" {
  description = "Optional repository description."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  default     = {}
}

variable "kms_key_name" {
  description = "Optional KMS key resource name for encryption."
  type        = string
  default     = null
}

variable "iam_bindings" {
  description = "List of IAM bindings to apply to the repository."
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

variable "import_images" {
  description = "When true, mirror images from a source registry into this repository."
  type        = bool
  default     = false
}

variable "images_to_import" {
  description = "List of image names (repository:tag) to import from the source registry."
  type        = list(string)
  default     = []
}

variable "source_registry_url" {
  description = "Optional source registry hostname (e.g., docker.io, ghcr.io)."
  type        = string
  default     = "docker.io"
}

variable "source_registry_username" {
  description = "Optional username for authenticating to the source registry."
  type        = string
  default     = null
}

variable "source_registry_password" {
  description = "Optional password/token for authenticating to the source registry."
  type        = string
  default     = null
  sensitive   = true
}

variable "source_registry_allow_anonymous_fallback" {
  description = "When true, fall back to anonymous pulls if authentication to the source registry fails."
  type        = bool
  default     = true
}

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec provisioners (override on Windows if /usr/bin/env is unavailable)."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
