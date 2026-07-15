output "students" {
  description = "Per-student gateway details."
  value = {
    for k, student in local.infra_students : k => {
      aks_name             = student.aks_name
      resource_group       = student.resource_group_name
      public_ip            = student.public_ip_address
      gateway_class        = var.gateway_class_name
      gateway_name         = "${k}-envoy-gateway"
      tls_secret           = "${k}-envoy-tls"
      launchpad_tls_secret = "launchpad-${k}-training-tls"
      sparql_tls_secret    = "sparql-${k}-training-tls"
    }
  }
}
