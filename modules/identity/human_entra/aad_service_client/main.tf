locals {
  effective_display_name = coalesce(var.display_name, "${var.inst_id} - Service")
}

data "azuread_client_config" "current" {}

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
  owners           = local.desired_owner_ids

  required_resource_access {
    resource_app_id = var.resource_app_id
    resource_access {
      id   = var.app_role_id
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
}

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
