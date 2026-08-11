output "stardog_release" {
  value = {
    release_name  = var.stardog_release
    namespace     = var.stardog_namespace
    domain        = local.ingress_dns_root
    sparql_url    = local.sparql_endpoint
    launchpad_url = "https://launchpad.${local.ingress_dns_root}"
  }
}

