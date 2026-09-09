variable "resource_group_name" {
  description = "Name of the Azure Resource Group where the Azure Container Registry (ACR) will be created."
  type        = string
  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must be a non-empty string."
  }
}

variable "location" {
  description = "Azure region for the ACR (e.g., eastus). Required when manage_acr = true."
  type        = string
  default     = null
  validation {
    condition     = var.manage_acr ? length(trimspace(var.location)) > 0 : true
    error_message = "location must be set when manage_acr = true."
  }
}

variable "cluster" {
  description = <<-EOT
    Optional metadata about the AKS cluster(s) this ACR should attach to.
    Map is keyed by any label you choose; each value may include `kubelet_object_id`.
    If provided, the module can grant AcrPull to the AKS kubelet managed identity.
    Set to null to skip attaching ACR permissions.
  EOT
  type = map(object({
    kubelet_object_id = optional(string)
  }))
  default = null

  # If the map is provided, ensure that any kubelet_object_id present is non-empty.
  validation {
    condition = var.cluster == null || alltrue([
      for c in values(var.cluster) :
      c.kubelet_object_id == null || length(trimspace(c.kubelet_object_id)) > 0
    ])
    error_message = "Each provided kubelet_object_id (if present) must be a non-empty string."
  }
}

variable "acr_name" {
  description = "Name of the Azure Container Registry. Must be 5–50 chars, lowercase alphanumeric only (e.g., 'myteamacr')."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5–50 characters of lowercase letters and digits only (no dashes or underscores)."
  }
}

variable "acr_sku" {
  description = "ACR SKU tier."
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}

variable "acr_admin_enabled" {
  description = "Whether to enable the ACR admin user (username/password). Consider false for production."
  type        = bool
  # false, not true - the old default directly contradicted this variable's own description, and
  # RBAC (this module already wires up AcrPull to the kubelet identity) already covers the real
  # pull-access use case, making the admin user/password unnecessary attack surface enabled by
  # default. Callers that explicitly pass their own value (e.g. envctl's shared/variables.tf, which
  # has its own separate default) are unaffected either way.
  default = false
}

variable "manage_acr" {
  description = "When true, Terraform creates/manages the ACR resource. When false, the module references an existing registry via data source (read-only)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

variable "source_registry_username" {
  description = "Optional source registry username used when importing images with az acr import to avoid anonymous pull rate limits."
  type        = string
  default     = null
}

variable "source_registry_password" {
  description = "Optional source registry password or access token used with source_registry_username when importing images."
  type        = string
  default     = null
  sensitive   = true
}

variable "shell_interpreter" {
  description = "List of interpreter tokens for local-exec provisioners (override on Windows if /usr/bin/env is unavailable)."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-lc"]
}
