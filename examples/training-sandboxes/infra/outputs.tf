output "students" {
  description = "Per-student resource summary."
  value = {
    for k in keys(var.students) : k => {
      email                = var.students[k].email
      resource_group_name  = azurerm_resource_group.rg[k].name
      location             = var.location
      public_ip_name       = azurerm_public_ip.student[k].name
      public_ip_address    = azurerm_public_ip.student[k].ip_address
      aks_name             = module.aks[k].name
      aks_cluster_id       = module.aks[k].cluster_id
      aks_node_resource_rg = module.aks[k].node_resource_group
      acr_name             = module.acr_shared.name
      acr_login_server     = module.acr_shared.login_server
      akv_name             = module.akv[k].name
      akv_uri              = module.akv[k].vault_uri
      dns_root             = var.create_student_dns_records && var.create_student_dns_root_record && var.dns_zone_name != null ? "${local.students[k].slug_dash}.${var.dns_zone_name}" : null
      dns_wildcard         = var.create_student_dns_records && var.dns_zone_name != null ? "*.${local.students[k].slug_dash}.${var.dns_zone_name}" : null
    }
  }
}

output "student_principal_ids" {
  description = "Entra object IDs for students (useful for auditing)."
  value       = local.student_principal_ids
}

output "student_tfstate" {
  description = "Student tfstate container + group details."
  value = {
    container_name = local.tfstate_container_name
    group_name     = var.create_student_tfstate_group ? azuread_group.tfstate_writers[0].display_name : null
    group_id       = var.create_student_tfstate_group ? azuread_group.tfstate_writers[0].object_id : null
    scope          = "${data.azurerm_storage_account.tfstate.id}/blobServices/default/containers/${local.tfstate_container_name}"
  }
}

output "shared_acr" {
  description = "Shared ACR details used by all student AKS clusters."
  value = {
    name           = module.acr_shared.name
    login_server   = module.acr_shared.login_server
    resource_group = azurerm_resource_group.shared.name
  }
}
