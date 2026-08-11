module "stardog" {
  source = "../../modules/kubernetes/stardog"

  namespace    = var.stardog_namespace
  release_name = var.stardog_release
  values_file  = "${path.module}/terraform.values.yaml"

  chart_url      = local.stardog_chart_url
  chart_version  = null
  chart_username = ""
  chart_password = ""

  debug_print_helm_command = false

  stardog_license_base64 = var.stardog_license_base64
  helm_set               = local.helm_set
}

module "stardog_roles" {
  source = "../../modules/stardog_resources/role_set"

  namespace        = var.stardog_namespace
  stardog_url      = local.sparql_endpoint
  stardog_username = "admin"
  stardog_password = "admin"
  remove_builtin_reader = false

  roles = {
    admin = [
      { action = "all", resource_type = "all", resource = "*" }
    ]
  }

  depends_on = [module.stardog]
}
