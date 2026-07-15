variable "role" {
  description = "Target Stardog role name."
  type        = string
}

variable "action" {
  description = "Permission action to grant (e.g., read, write, execute)."
  type        = string
}

variable "resource_type" {
  description = "Stardog resource type (e.g., db, dbms_admin, all)."
  type        = string
}

variable "resource" {
  description = "Stardog resource identifier or wildcard."
  type        = string
}

variable "state" {
  description = "Desired assignment state (present or absent)."
  type        = string
  default     = "present"
  validation {
    condition     = contains(["present", "absent"], lower(trimspace(var.state)))
    error_message = "state must be either \"present\" or \"absent\"."
  }
}

variable "namespace" {
  description = "Legacy no-op. Previously used as the Kubernetes namespace for a temporary role-management pod."
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
  default     = null
}

variable "skip_status" {
  description = "If true, skip writing status to ConfigMap (CLI prints to stdout)."
  type        = bool
  default     = true
}

variable "idempotent_create" {
  description = "Request idempotent create behaviour (no-op when missing)."
  type        = bool
  default     = false
}

variable "additional_spec_fields" {
  description = "Extra key/value pairs to merge into the spec JSON."
  type        = map(any)
  default     = {}
}

variable "additional_cli_args" {
  description = "Reserved for compatibility. The local stardog-admin implementation currently ignores these arguments."
  type        = list(string)
  default     = []
}

variable "container_env" {
  description = "Environment variables carrying Stardog credentials. STARDOG_USERNAME and STARDOG_PASSWORD are used by local stardog-admin commands."
  type        = map(string)
  default     = {}
}

variable "local_exec_env" {
  description = "Environment variables for local stardog-admin command execution."
  type        = map(string)
  default     = {}
}

variable "service_account_name" {
  description = "Legacy no-op. Previously used as the Kubernetes service account for a temporary pod."
  type        = string
  default     = null
}

variable "destroy_on_deprovision" {
  description = "If true, run the destroy-time command to revoke the assignment when Terraform destroys this resource."
  type        = bool
  default     = true
}

variable "kubeconfig_refresh_command" {
  description = "Legacy no-op. Previously refreshed kubeconfig before invoking kubectl."
  type        = string
  default     = null
}

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec helpers."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
