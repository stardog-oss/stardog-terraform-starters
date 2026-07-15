variable "name" {
  description = "Stardog role name to manage."
  type        = string
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
  default     = "http://stardog:5820"
}

variable "state" {
  description = "Desired state for the role (present or absent)."
  type        = string
  default     = "present"
  validation {
    condition     = contains(["present", "absent"], lower(trimspace(var.state)))
    error_message = "state must be either \"present\" or \"absent\"."
  }
}

variable "skip_status" {
  description = "If true, skip writing status to ConfigMap (CLI will print to stdout)."
  type        = bool
  default     = true
}

variable "additional_cli_args" {
  description = "Reserved for compatibility. The local stardog-admin implementation currently ignores these arguments."
  type        = list(string)
  default     = []
}

variable "destroy_on_deprovision" {
  description = "If true, run the destroy-time command to set the role state to absent when Terraform destroys this resource."
  type        = bool
  default     = false
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
