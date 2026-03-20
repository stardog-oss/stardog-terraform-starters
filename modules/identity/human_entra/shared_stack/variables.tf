variable "inst_id" {
  description = "Environment instance identifier used in app display names and redirect URIs."
  type        = string
}

variable "dns_zone_name" {
  description = "Base DNS zone used to build public redirect URIs."
  type        = string
}

variable "owner_object_ids" {
  description = "Object IDs that should own the created Azure AD applications."
  type        = list(string)
  default     = []
}

variable "secret_backend" {
  description = "Secret storage backend configuration consumed by the underlying app modules (e.g., determine if Key Vault-specific role assignments are required)."
  type = object({
    kind   = string
    config = map(any)
  })
}

variable "app_admin_role_group_object_id" {
  description = "Azure AD group object ID that should receive the SPARQL admin app role."
  type        = string
  default     = null
}

variable "extra_sparql_redirect_uris" {
  description = "Additional redirect URIs appended to the default SPARQL application set."
  type        = list(string)
  default     = []
}
