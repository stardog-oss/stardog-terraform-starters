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
  description = "Kubernetes namespace where the temporary pod should run."
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
  description = "Additional CLI arguments to pass to stardog_ops.cli."
  type        = list(string)
  default     = []
}

variable "container_env" {
  description = "Environment variables to inject into the ephemeral container (e.g., STARDOG_USERNAME/PASSWORD)."
  type        = map(string)
  default     = {}
}

variable "local_exec_env" {
  description = "Environment variables for the local kubectl command execution."
  type        = map(string)
  default     = {}
}

variable "service_account_name" {
  description = "Optional service account for the ephemeral pod."
  type        = string
  default     = null
}

variable "destroy_on_deprovision" {
  description = "If true, run the destroy-time command to revoke the assignment when Terraform destroys this resource."
  type        = bool
  default     = true
}

variable "kubeconfig_refresh_command" {
  description = "Optional shell command to run before invoking kubectl (e.g., az aks get-credentials)."
  type        = string
  default     = null
}

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec helpers."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
