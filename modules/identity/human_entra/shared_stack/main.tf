locals {
  default_sparql_redirect_uris = [
    "http://localhost:49998/",
    "http://localhost/",
    "https://launchpad.${var.inst_id}.${var.dns_zone_name}/auth/sso-connection",
  ]

  sparql_redirect_uris = concat(local.default_sparql_redirect_uris, var.extra_sparql_redirect_uris)

  launchpad_redirect_uris = [
    "http://localhost:49998/",
    "http://localhost/",
    "https://launchpad.${var.inst_id}.${var.dns_zone_name}/oauth/azure/redirect",
  ]
}

module "aad_sparql" {
  source           = "../aad_sparql"
  inst_id          = var.inst_id
  redirect_uris    = local.sparql_redirect_uris
  owner_object_ids = var.owner_object_ids
  secret_backend   = var.secret_backend
}

module "aad_launchpad" {
  source           = "../aad_launchpad"
  inst_id          = var.inst_id
  redirect_uris    = local.launchpad_redirect_uris
  owner_object_ids = var.owner_object_ids
  secret_backend   = var.secret_backend
}

module "sparql_admin_role_group" {
  count = var.app_admin_role_group_object_id != null ? 1 : 0

  source                = "../app_role_assignment"
  principal_object_id   = var.app_admin_role_group_object_id
  resource_sp_object_id = module.aad_sparql.sp_object_id
  app_role_id           = "97932c93-52c2-4561-a7a7-7fea2443c6d7"
}

output "sparql_application_client_id" {
  value = module.aad_sparql.client_id
}

output "sparql_service_principal_object_id" {
  value = module.aad_sparql.sp_object_id
}

output "launchpad_application_client_id" {
  value = module.aad_launchpad.client_id
}

output "sparql_client_secret" {
  value     = module.aad_sparql.secret
  sensitive = true
}

output "launchpad_client_secret" {
  value     = module.aad_launchpad.secret
  sensitive = true
}

output "sparql_secret_entries" {
  value     = module.aad_sparql.secret_entries
  sensitive = true
}

output "launchpad_secret_entries" {
  value     = module.aad_launchpad.secret_entries
  sensitive = true
}
