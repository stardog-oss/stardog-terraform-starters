variable "inst_id" {
  description = "Short instance identifier used for naming and labels."
  type        = string
}

variable "display_name" {
  description = "Explicit display name for the service app registration. If null, it defaults to \"<inst_id> - Service\"."
  type        = string
  default     = null
}

variable "owner_object_ids" {
  description = "List of AAD object IDs to set as owners of the app registration. If empty, the current authenticated principal will be used."
  type        = list(string)
  default     = []
}

variable "resource_app_id" {
  description = "Client ID of the resource application that exposes the app role."
  type        = string
}

variable "app_role_id" {
  description = "App role ID requested by this service application."
  type        = string
}
