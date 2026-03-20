#provider "azuread" {}
resource "azuread_app_role_assignment" "this" {
  app_role_id         = var.app_role_id
  principal_object_id = var.principal_object_id
  resource_object_id  = var.resource_sp_object_id
}
