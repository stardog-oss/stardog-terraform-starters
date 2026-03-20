variable "inst_id" {
  description = "Short instance identifier used to derive default names and URLs (e.g., 'profile-a')."
  type        = string
}

# NOTE: don't reference other variables in a variable's default.
# Use a local to compute a fallback from inst_id instead (see below).
variable "display_name" {
  description = "Explicit display name for the app registration. If null, it will default to \"<inst_id> - Launchpad\" via a local."
  type        = string
  default     = null
}

variable "redirect_uris" {
  description = "List of redirect URIs for the app's web platform (e.g., 'https://launchpad.<inst_id>.<domain>/oauth/azure/redirect')."
  type        = list(string)
}

variable "owner_object_ids" {
  description = "List of AAD object IDs (users or service principals) to set as owners of the app registration. If empty, the current authenticated principal will be used."
  type        = list(string)
  default     = []
}

variable "secret_backend" {
  description = <<-EOT
    Configuration for where to persist application secrets.
    Example (Azure Key Vault):
      { kind = "azure_key_vault", config = { key_vault_id = "..." } }
    Example (AWS Secrets Manager):
      { kind = "aws_secrets_manager", config = { secret_arn = "..." } }
  EOT
  type = object({
    kind   = string
    config = map(any)
  })
}

variable "graph_openid_resource_access_id" {
  description = "(Optional) The resource_access id GUID for Microsoft Graph 'openid' delegated permission. If provided, the module will add a required_resource_access entry for Microsoft Graph so Terraform requests the 'openid' permission declaratively. Obtain via Graph/servicePrincipal oauth2PermissionScopes."
  type        = string
  default     = null
}
