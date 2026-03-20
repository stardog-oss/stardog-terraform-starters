variable "namespace" {
  description = "Namespace where HAProxy Gateway will be installed."
  type        = string
  default     = "haproxy-controller"
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "haproxy-gateway"
}

variable "chart_repo_url" {
  description = "Helm chart repository URL."
  type        = string
  default     = "https://haproxy-ingress.github.io/charts"
}

variable "chart_name" {
  description = "Helm chart name."
  type        = string
  default     = "haproxy-ingress"
}

variable "chart_version" {
  description = "Specific chart version to install. Leave empty for latest."
  type        = string
  default     = "0.15.1"
}

variable "helm_atomic" {
  description = "Use Helm atomic installs."
  type        = bool
  default     = true
}

variable "helm_wait" {
  description = "Wait for resources to become ready before finishing."
  type        = bool
  default     = true
}

variable "helm_cleanup_on_fail" {
  description = "Cleanup resources created by a failed install."
  type        = bool
  default     = true
}

variable "helm_force_update" {
  description = "Force resource recreation even when no diff detected."
  type        = bool
  default     = false
}

variable "helm_timeout" {
  description = "Timeout (in seconds) for Helm actions."
  type        = number
  default     = 300
}

variable "values" {
  description = "Base values map passed to the Helm chart."
  type        = any
  default     = {}
}

variable "extra_values" {
  description = "Additional map merged on top of `values` (late precedence)."
  type        = any
  default     = {}
}
