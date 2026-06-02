variable "deploy" {
  description = "Whether to manage Stardog roles and assignments."
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Legacy no-op. Previously used as the Kubernetes namespace for temporary role-management pods."
  type        = string
}

variable "kubeconfig_path" {
  description = "Legacy no-op. Previously used by kubectl-based role helpers."
  type        = string
  default     = "~/.kube/config"
}

variable "image" {
  description = "Legacy no-op. Previously identified the stardog-manager helper image."
  type        = string
  default     = null
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
  description = "Legacy no-op for the local Stardog CLI path. Configure local JVM trust if the public endpoint uses a private CA."
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
  description = "Legacy no-op. Previously used as the Kubernetes service account for temporary pods."
  type        = string
  default     = null
}

variable "extra_cli_args" {
  description = "Reserved for compatibility. The local stardog-admin implementation currently ignores these arguments."
  type        = list(string)
  default     = []
}

variable "container_env_extra" {
  description = "Additional environment variables carried for compatibility."
  type        = map(string)
  default     = {}
}

variable "local_exec_env" {
  description = "Environment variables for local stardog-admin command execution."
  type        = map(string)
  default     = {}
}

variable "wait_for_stardog" {
  description = "Wait for the Stardog public admin endpoint before creating roles."
  type        = bool
  default     = true
}

variable "stardog_ready_path" {
  description = "HTTP path used to check Stardog readiness before creating roles."
  type        = string
  default     = "/admin/alive"
}

variable "stardog_ready_attempts" {
  description = "Number of readiness attempts before failing role creation."
  type        = number
  default     = 60
}

variable "stardog_ready_interval_seconds" {
  description = "Seconds to sleep between Stardog readiness attempts."
  type        = number
  default     = 10
}

variable "kubeconfig_refresh_command" {
  description = "Legacy no-op. Previously refreshed kubeconfig before running kubectl."
  type        = string
  default     = null
}
