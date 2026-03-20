#provider "azuread" {}

# Recommended pattern to derive the display name from inst_id when not provided:
locals {
  effective_display_name = coalesce(var.display_name, "${var.inst_id} - Launchpad")
}

# current authenticated principal
data "azuread_client_config" "current" {}

locals {
  desired_owner_ids = distinct(
    length(var.owner_object_ids) > 0 ?
    concat(var.owner_object_ids, [data.azuread_client_config.current.object_id]) :
    [data.azuread_client_config.current.object_id]
  )
}

# Discover Microsoft Graph SP and the "openid" scope without external/CLI
data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  discovered_openid_scope_id = one([
    for s in data.azuread_service_principal.msgraph.oauth2_permission_scopes :
    s.id if s.value == "openid"
  ])
  openid_scope_id = coalesce(var.graph_openid_resource_access_id, local.discovered_openid_scope_id)
}

resource "azuread_application" "app" {
  display_name     = local.effective_display_name
  sign_in_audience = "AzureADMultipleOrgs"

  # keep existing behavior: do not drift on owners/identifier_uris set elsewhere
  lifecycle {
    ignore_changes = [identifier_uris]
  }

  owners = local.desired_owner_ids

  api {
    requested_access_token_version = 2
  }

  # Request Microsoft Graph delegated permission: openid
  # Request Microsoft Graph delegated permission: openid (only when discovered/provided)
  dynamic "required_resource_access" {
    for_each = local.openid_scope_id == null ? [] : [local.openid_scope_id]
    content {
      resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
      resource_access {
        id   = required_resource_access.value
        type = "Scope"
      }
    }
  }

  # Existing web/implicit/login settings preserved below if present in your original file
  dynamic "web" {
    for_each = length(var.redirect_uris) > 0 ? [1] : []
    content {
      redirect_uris = var.redirect_uris
      implicit_grant {
        access_token_issuance_enabled = true
        id_token_issuance_enabled     = true
      }
    }
  }
}

resource "azuread_service_principal" "sp" { client_id = azuread_application.app.client_id }


resource "time_static" "app_pwd_start" {}

locals {
  app_password_ttl = "8760h"
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
  display_name   = var.inst_id
  end_date       = local.app_password_end
}

# Ensure the current authenticated principal (the Terraform operator) has
# Key Vault Secrets Officer role on the target vault so create/destroy works.
// Key Vault role assignments are handled in the AKV module.
