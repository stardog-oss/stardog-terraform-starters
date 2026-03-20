#provider "azuread" {}

locals {
  graph_app_id           = "00000003-0000-0000-c000-000000000000"
  user_read_id           = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
  effective_display_name = coalesce(var.display_name, "${var.inst_id} - SPARQL")
}

# Get the current authenticated client (user or service principal)
data "azuread_client_config" "current" {}

# Compute the list of owner object IDs to use: prefer explicit owner_object_ids, else the current authenticated principal.
locals {
  desired_owner_ids = distinct(
    length(var.owner_object_ids) > 0 ?
    concat(var.owner_object_ids, [data.azuread_client_config.current.object_id]) :
    [data.azuread_client_config.current.object_id]
  )
}

resource "azuread_application" "app" {
  display_name     = local.effective_display_name
  sign_in_audience = "AzureADMultipleOrgs"
  # identifier_uris will be set post-creation via azuread_application_identifier_uri.primary
  fallback_public_client_enabled = true

  lifecycle {
    # identifier_uris managed via separate resource; ignore changes
    ignore_changes = [identifier_uris]
  }

  owners = local.desired_owner_ids

  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      admin_consent_display_name = "user_login"
      admin_consent_description  = "user_login"
      user_consent_display_name  = "user_login"
      user_consent_description   = "user_login"
      enabled                    = true
      type                       = "User"
      value                      = "user_login"
      id                         = "b318d0d6-d13e-461b-b22b-46d9ac3459b6"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "reader"
    display_name         = "reader"
    enabled              = true
    id                   = "8797249a-1696-4ccf-85f7-d7b2a5ef514e"
    value                = "reader"
  }
  app_role {
    allowed_member_types = ["Application"]
    description          = "writer"
    display_name         = "writer"
    enabled              = true
    id                   = "3955cf75-ad5a-4e69-b08c-ad5d4798e732"
    value                = "writer"
  }
  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "admin"
    display_name         = "admin"
    enabled              = true
    id                   = "97932c93-52c2-4561-a7a7-7fea2443c6d7"
    value                = "admin"
  }

  web {
    redirect_uris = var.redirect_uris
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  public_client { redirect_uris = ["http://localhost:443"] }

  required_resource_access {
    resource_app_id = local.graph_app_id
    resource_access {
      id   = local.user_read_id
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "sp" { client_id = azuread_application.app.client_id }

# Recommended: compute a stable end_date (no perpetual drift)
resource "time_static" "app_pwd_start" {}
locals {
  app_password_ttl = "8760h" # 1 year
  app_password_end = timeadd(time_static.app_pwd_start.rfc3339, local.app_password_ttl)
  secret_name_base = replace(lower(local.effective_display_name), " ", "-")
  secret_entries = {
    "aad-${local.secret_name_base}-client-secret" = {
      value        = azuread_application_password.pwd.value
      content_type = "application/x-azuread-client-secret"
    }
    "aad-${local.secret_name_base}-client-id" = {
      value        = azuread_application.app.client_id
      content_type = "text/plain"
    }
  }
}
resource "azuread_application_password" "pwd" {
  application_id = azuread_application.app.id
  display_name   = "puppy"
  end_date       = local.app_password_end
}

# Ensure the provided owners have Key Vault Secrets Officer role for the target vault when using Azure Key Vault
resource "null_resource" "kv_secret_officer" {
  for_each = var.secret_backend.kind == "azure_key_vault" && length(var.owner_object_ids) > 0 ? { for id in var.owner_object_ids : id => id } : {}

  triggers = {
    principal = each.value
    scope     = lookup(var.secret_backend.config, "key_vault_id", null)
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<EOT
existing=$(az role assignment list --scope "$${KEY_VAULT_ID}" --assignee "$${PRINCIPAL}" --role "Key Vault Secrets Officer" --query '[].id' -o tsv || true)
if [ -n "$${existing}" ]; then
  echo "Role assignment already exists for $${PRINCIPAL}; skipping"
else
  echo "Creating role assignment for $${PRINCIPAL} on $${KEY_VAULT_ID}"
  az role assignment create --role "Key Vault Secrets Officer" --assignee "$${PRINCIPAL}" --scope "$${KEY_VAULT_ID}"
fi
EOT
    environment = {
      PRINCIPAL    = each.value
      KEY_VAULT_ID = lookup(var.secret_backend.config, "key_vault_id", "")
    }
  }
}

# Also ensure the current authenticated principal (the Terraform operator)
# has the same role so it can manage secrets that Terraform created. This is
# required during destroy if the operator is not included in the owners list.
// Key Vault role assignments are handled in the AKV module.

# Then set a single Identifier URI, defaulting to api://<application_id>
resource "azuread_application_identifier_uri" "primary" {
  application_id = azuread_application.app.id
  identifier_uri = (
    var.identifier_uri != null && var.identifier_uri != ""
    ? var.identifier_uri
    : format("api://%s", azuread_application.app.client_id, )
  )
}
