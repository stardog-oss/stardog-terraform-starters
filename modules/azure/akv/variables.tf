variable "resource_group_name" {
  description = "Name of the Azure Resource Group that will contain the Key Vault. Set to null to accept a value passed from a parent module."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for the Key Vault (e.g., eastus). Must be a valid Azure location for the specified subscription."
  type        = string
}

variable "name" {
  description = "Key Vault name (globally unique per Azure DNS). Follow Azure KV naming rules (typically 3–24 chars; alphanumeric and '-' allowed; lowercase recommended). Set null to let a parent module compute/provide it."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the Key Vault resource (e.g., { env = \"stage\", owner = \"platform\" })."
  type        = map(string)
  default     = {}
}

variable "admin_group_object_id" {
  description = "Microsoft Entra ID (AAD) group object ID that should administer the vault. With RBAC mode, this module grants the Key Vault Secrets Officer role."
  type        = string
  default     = null
}

# RBAC vs Access Policy
variable "rbac_authorization_enabled" {
  description = "Use Key Vault **RBAC authorization** model when true (recommended). When true, data-plane access is governed by Azure RBAC roles instead of classic access policies."
  type        = bool
  default     = true
}

variable "use_access_policies" {
  description = "Use **classic access policies** when true. Typically set this to true only if you cannot use RBAC (legacy scenarios). Should not be true at the same time as rbac_authorization_enabled."
  type        = bool
  default     = false
}

# Optional overrides (handy for tests & cross-tenant)
variable "tenant_id" {
  description = "AAD tenant ID to associate with the Key Vault. Defaults to the current provider tenant when null (useful for cross-tenant/testing scenarios)."
  type        = string
  default     = null
}

variable "admin_object_id" {
  description = "Object ID of a **user or service principal** to grant admin access. Used for access policies when use_access_policies = true; when RBAC is enabled the module also grants Key Vault Secrets Officer."
  type        = string
  default     = null
}
