variable "name" {
  description = "Stardog role name to manage."
  type        = string
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
  description = "Additional CLI arguments to pass to stardog_ops.cli."
  type        = list(string)
  default     = []
}

variable "destroy_on_deprovision" {
  description = "If true, run the destroy-time command to set the role state to absent when Terraform destroys this resource."
  type        = bool
  default     = false
}

variable "container_env" {
  description = "Environment variables to inject into the ephemeral container (e.g., STARDOG_USERNAME)."
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
