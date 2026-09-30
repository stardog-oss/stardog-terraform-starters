variable "inst_id" {
  description = "Short instance identifier used for naming and labels (e.g., 'profile-a')."
  type        = string
}

variable "display_name" {
  description = "Explicit display name for the SPARQL app registration. If null, it will default to \"<inst_id> - SPARQL\" via a local."
  type        = string
  default     = null
}

variable "identifier_uri" {
  description = "Optional Identifier URI for the application (e.g., 'api://<guid>' or a verified domain URI). Set null to let the module compute one or skip."
  type        = string
  default     = null
}

variable "redirect_uris" {
  description = "List of web redirect URIs for this application (e.g., 'https://launchpad.<inst_id>.<domain>/auth/sso-connection')."
  type        = list(string)
  default     = []
}

variable "owner_object_ids" {
  description = "(Preferred) List of AAD object IDs (users or service principals) to set as owners of the app registration. If empty, the current authenticated principal will be used."
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

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec helpers (override on Windows if /usr/bin/env is unavailable)."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}

variable "app_roles" {
  description = <<-EOT
    Entra app roles to define on this application - a name (the map key) plus descriptive
    metadata only. Each role's real Entra appRole.id is derived deterministically from its own key
    (see local.app_role_ids in main.tf, and the app_role_ids output) rather than accepted here -
    callers never invent or pass a GUID. Defaults to this module's original 3 roles, preserving
    their exact allowed_member_types asymmetry (writer is Application-only; reader/admin are
    User+Application).
  EOT
  type = map(object({
    display_name         = string
    description          = optional(string, "")
    allowed_member_types = optional(list(string), ["User", "Application"])
  }))
  default = {
    reader = { display_name = "reader", description = "reader", allowed_member_types = ["User", "Application"] }
    writer = { display_name = "writer", description = "writer", allowed_member_types = ["Application"] }
    admin  = { display_name = "admin", description = "admin", allowed_member_types = ["User", "Application"] }
  }
}
