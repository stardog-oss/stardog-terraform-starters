variable "namespace" {
  description = "Kubernetes namespace to install Stardog into"
  type        = string
  default     = "stardog"
}

variable "values_yaml" {
  description = "Optional values.yaml content (string). If empty, the module installs with only set overrides."
  type        = string
  default     = ""
}

variable "values_file" {
  description = "Optional path to a local values.yaml file. If provided, the module will read this file (using file()) and pass it to Helm as the base values document. Path is resolved relative to the Terraform working directory (caller)."
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "Chart version when chart_source = 'repo'"
  type        = string
  default     = null
}

variable "helm_replace" {
  description = "If true, the helm_release will use replace behavior to reuse a release name that already exists (maps to helm install --replace behavior)."
  type        = bool
  default     = true
}

variable "helm_atomic" {
  description = "If true, the helm release will be installed/upgraded atomically (rollback on failure)."
  type        = bool
  default     = true
}

variable "helm_cleanup_on_fail" {
  description = "If true, Helm will cleanup resources created in case of a failed install/upgrade."
  type        = bool
  default     = true
}

variable "helm_force_update" {
  description = "If true, allows force-updating resources through the provider (maps to helm --force)."
  type        = bool
  default     = false
}

variable "helm_timeout" {
  description = "Timeout for Helm operations (e.g. '5m' or as number of seconds)."
  type        = number
  default     = 300
}

variable "helm_wait" {
  description = "If true, helm will wait until resources are ready before marking release as successful."
  type        = bool
  default     = true
}


variable "stardog_license_base64" {
  description = "Base64-encoded Stardog license content. If provided, this will be used instead of reading a local file."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.stardog_license_base64)) > 0
    error_message = "The module requires `stardog_license_base64` to be set (provide base64-encoded license content)."
  }
}

variable "stardog_license_file" {
  description = "(Deprecated) Path to the Stardog license file on the machine running Terraform. Use module caller to convert a local file to base64 and pass via `stardog_license_base64` instead."
  type        = string
  default     = null
}

variable "stardog_license_secret_name" {
  description = "Name of the Kubernetes secret that will hold the Stardog license"
  type        = string
  default     = "stardog-license"
}

variable "stardog_license_key_filename" {
  description = "Filename/key to use inside the secret for the license binary"
  type        = string
  default     = "stardog-license-key.bin"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "stardog"
}


variable "debug_print_helm_command" {
  description = "When true the module will write the merged values.yaml to ./.debug/values.yaml and print example helm CLI commands to install the chart (helpful for troubleshooting)."
  type        = bool
  default     = false
}

variable "helm_set" {
  description = "Optional list of Helm set entries to pass as `set` blocks to the helm_release resource. Each item should be an object with `name` and `value` keys, e.g. [{ name = \"stardog.ingress.url\", value = \"example.com\" }]."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "cachetarget_enabled" {
  description = "Enable the cache target service and mirror the auto-configured Stardog resource/JVM settings when auto_configure_resources is true."
  type        = bool
  default     = false
}

variable "auto_configure_resources" {
  description = "When true, the module will inspect Kubernetes node allocatable resources and automatically set Stardog CPU/memory requests/limits and the JVM ActiveProcessorCount."
  type        = bool
  default     = false 
}

variable "allocatable_label_selector" {
  description = "Map of Kubernetes node labels that identify the nodes to inspect when auto-configuring resources. Leave empty to consider all nodes."
  type        = map(string)
  default     = {}
}

variable "auto_active_processor_offset" {
  description = "How many vCPUs to hold back when deriving -XX:ActiveProcessorCount (defaults to 1 so the JVM uses node_cores - 1)."
  type        = number
  default     = 1
}

variable "auto_reserved_cpu" {
  description = "CPU quantity (e.g., \"500m\" or \"0.5\") to subtract from the detected allocatable CPU before auto-configuring requests/limits."
  type        = string
  default     = null
}

variable "auto_reserved_memory" {
  description = "Memory quantity (e.g., \"512Mi\" or \"0.5Gi\") to subtract from the detected allocatable memory before auto-configuring requests/limits."
  type        = string
  default     = null
}

variable "chart_url" {
  description = "OCI/HTTPS chart URL when chart_source = 'oci' (e.g., oci://myregistry/repo/chart)"
  type        = string
  default     = null
}

variable "chart_username" {
  type    = string
  default = null
}
variable "chart_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "shell_interpreter" {
  description = "Interpreter tokens for the module's local-exec helpers."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
