variable "namespace" {
  description = "Kubernetes namespace to install cert-manager into."
  type        = string
  default     = "cert-manager"
}

# Create the namespace via a Kubernetes resource (idempotent and matches the doc's intent)
variable "create_namespace" {
  type        = bool
  default     = true
}

# Where to fetch the chart from
variable "chart_source" {
  description = "\"repo\" (classic HTTP Helm repo) or \"oci\" (OCI registry)"
  type        = string
  default     = "repo"
  validation {
    condition     = contains(["repo", "oci"], var.chart_source)
    error_message = "chart_source must be \"repo\" or \"oci\"."
  }
}

# For chart_source = "repo"
variable "chart_repo_url" {
  description = "HTTP Helm repo URL for cert-manager (Jetstack)."
  type        = string
  default     = "https://charts.jetstack.io"
}

variable "chart_name" {
  description = "Chart name within the repo."
  type        = string
  default     = "cert-manager"
}

# Pin if you want; your doc shows v1.8.0
variable "chart_version" {
  description = "Chart version to install (e.g., v1.8.0 per doc)."
  type        = string
  default     = null
}

# For chart_source = "oci"
variable "oci_chart_url" {
  description = "Fully-qualified OCI URL, e.g. oci://<registry>/helm/cert-manager"
  type        = string
  default     = null
}

variable "oci_chart_version" {
  description = "Version/tag for the OCI chart (required for OCI installs)."
  type        = string
  default     = null
}

# Values
variable "install_crds" {
  description = "Set installCRDs=true as recommended."
  type        = bool
  default     = true
}

variable "extra_values" {
  description = "Additional Helm values to merge."
  type        = any
  default     = {}
}
