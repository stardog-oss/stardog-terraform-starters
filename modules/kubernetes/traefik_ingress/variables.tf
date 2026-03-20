variable "namespace" {
  description = "Namespace where Traefik will be installed."
  type        = string
  default     = "traefik"
}

variable "replica_count" {
  description = "Desired number of Traefik pods."
  type        = number
  default     = 2
}

variable "service_type" {
  description = "Kubernetes Service type for the main Traefik Service."
  type        = string
  default     = "LoadBalancer"
}

variable "service_annotations" {
  description = "Annotations applied to the Traefik Service."
  type        = map(string)
  default     = {}
}

variable "extra_values" {
  description = "Additional Helm values (map) merged with the defaults."
  type        = any
  default     = {}
}

variable "chart_source" {
  description = "Helm chart source: 'repo' or 'oci'."
  type        = string
  default     = "repo"

  validation {
    condition     = contains(["repo", "oci"], var.chart_source)
    error_message = "chart_source must be either 'repo' or 'oci'."
  }
}

variable "chart_repo_url" {
  description = "Helm repository URL when chart_source = 'repo'."
  type        = string
  default     = "https://traefik.github.io/charts"
}

variable "chart_name" {
  description = "Helm chart name when chart_source = 'repo'."
  type        = string
  default     = "traefik"
}

variable "chart_version" {
  description = "Optional chart version when chart_source = 'repo'. Leave empty to use the latest."
  type        = string
  default     = ""
}

variable "oci_chart_url" {
  description = "OCI chart reference when chart_source = 'oci'."
  type        = string
  default     = null
}

variable "oci_chart_version" {
  description = "OCI chart version when chart_source = 'oci'."
  type        = string
  default     = null
}

variable "install_gateway_api_crds" {
  description = "When true, install Gateway API CRDs via kubectl before deploying Traefik."
  type        = bool
  default     = false
}

variable "install_gateway_api_experimental_crds" {
  description = "When true, also install the experimental Gateway API CRDs (TCPRoute/UDPRoute) after the standard set."
  type        = bool
  default     = false
}

variable "gateway_api_crds_version" {
  description = "Gateway API release version used for CRD installation."
  type        = string
  default     = "v1.1.0"
}

variable "aks_resource_group_name" {
  description = "AKS resource group name (required when install_gateway_api_crds = true)."
  type        = string
  default     = null

  validation {
    condition = (
      var.install_gateway_api_crds ? var.aks_resource_group_name != null && trimspace(var.aks_resource_group_name) != "" : true
    )
    error_message = "Set aks_resource_group_name when install_gateway_api_crds = true."
  }
}

variable "aks_cluster_name" {
  description = "AKS cluster name (required when install_gateway_api_crds = true)."
  type        = string
  default     = null

  validation {
    condition = (
      var.install_gateway_api_crds ? var.aks_cluster_name != null && trimspace(var.aks_cluster_name) != "" : true
    )
    error_message = "Set aks_cluster_name when install_gateway_api_crds = true."
  }
}

variable "kubeconfig_path" {
  description = "Path where kubectl credentials should be written."
  type        = string
  default     = "~/.kube/config"
}

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec helpers."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
