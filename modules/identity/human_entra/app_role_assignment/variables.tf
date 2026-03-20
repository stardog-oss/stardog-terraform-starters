variable "principal_object_id" {
  description = "Object ID (GUID) of the principal receiving the role assignment (user, group, service principal, or managed identity)."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.principal_object_id))
    error_message = "principal_object_id must be a valid GUID (Azure AD object ID)."
  }
}

variable "resource_sp_object_id" {
  description = "Object ID (GUID) of the **resource** service principal that exposes the app role (e.g., azuread_service_principal.resource.id). Note: this is the SP's objectId, not the application (client) ID."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.resource_sp_object_id))
    error_message = "resource_sp_object_id must be a valid GUID (service principal object ID)."
  }
}

variable "app_role_id" {
  description = "GUID of the app role to assign (must match the `id` of an `app_role` on the resource service principal)."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.app_role_id))
    error_message = "app_role_id must be a valid GUID (the app role's ID)."
  }
}