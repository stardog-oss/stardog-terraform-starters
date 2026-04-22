output "students" {
  description = "Per-student gateway details."
  value = {
    for k in keys(local.selected_students) : k => {
      aks_name       = local.selected_students[k].aks_name
      resource_group = local.selected_students[k].resource_group_name
      public_ip      = local.selected_students[k].public_ip_address
      gateway_class  = var.gateway_class_name
      gateway_name   = local.cilium_gateway_name_by_student[k]
      tls_secret     = local.cilium_tls_secret_by_student[k]
    }
  }
}
