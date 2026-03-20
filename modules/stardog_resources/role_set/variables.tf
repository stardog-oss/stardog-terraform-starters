variable "deploy" {
  description = "Whether to manage Stardog roles and assignments."
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace where the temporary pods should run."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file used for kubectl commands."
  type        = string
  default     = "~/.kube/config"
}

variable "image" {
  description = "Container image (including tag) for the stardog-manager CLI."
  type        = string
}

variable "stardog_url" {
  description = "Base URL for the Stardog admin endpoint."
  type        = string
}

variable "stardog_username" {
  description = "Stardog admin username."
  type        = string
}

variable "stardog_password" {
  description = "Stardog admin password."
  type        = string
  sensitive   = true
}

variable "stardog_insecure" {
  description = "If true, skip TLS verification when connecting to Stardog."
  type        = bool
  default     = false
}

variable "roles" {
  description = "Map of role name => list of permission objects."
  type = map(list(object({
    action        = string
    resource_type = string
    resource      = string
    state         = optional(string)
    idempotent    = optional(bool)
  })))
  default = {}
}

variable "remove_builtin_reader" {
  description = "If true, remove the built-in 'reader' role before applying custom roles."
  type        = bool
  default     = true
}

variable "service_account_name" {
  description = "Optional Kubernetes service account for the ephemeral pods."
  type        = string
  default     = null
}

variable "extra_cli_args" {
  description = "Additional CLI arguments to pass to stardog_ops.cli."
  type        = list(string)
  default     = []
}

variable "container_env_extra" {
  description = "Additional environment variables to inject into the ephemeral container."
  type        = map(string)
  default     = {}
}

variable "local_exec_env" {
  description = "Environment variables for the local kubectl command execution."
  type        = map(string)
  default     = {}
}

variable "kubeconfig_refresh_command" {
  description = "Optional shell command that ensures the kubeconfig points at the target cluster before running kubectl."
  type        = string
  default     = null
}
