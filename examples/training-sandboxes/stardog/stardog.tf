
module "stardog" {
  count  = var.deploy_stardog_stack ? 1 : 0
  source = "./modules/kubernetes/stardog"

  namespace    = coalesce(var.stardog_namespace, "stardog")
  helm_timeout = var.stardog_helm_timeout
  helm_atomic  = false

  release_name = coalesce(var.stardog_release, "sd-stack")
  values_file  = "./values.stardog.yaml"

  chart_url      = var.stardog_chart_url
  chart_version  = var.stardog_chart_version
  chart_username = var.jfrog_registry_username
  chart_password = var.jfrog_registry_password

  debug_print_helm_command = true

  stardog_license_base64     = var.stardog_license_base64
  cachetarget_enabled        = var.enable_cache_target

  helm_set = concat([
    { name = "stardog.ingress.url", value = var.ingress_dns_root },
    #signer
    {
      name  = "stardog.jwtConfig.signer.issuer",
      value = "https://sparql.${var.ingress_dns_root}:5820"
    },
    {
      name  = "stardog.jwtConfig.signer.secret",
      value = "some-kind-of-secret-key-here"
    },

#    #MS Entra ID
#    {
#      name  = "stardog.jwtConfig.issuers[0].issuer",
#      value = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
#    },
#    {
#      name  = "stardog.jwtConfig.issuers[0].audience",
#      value = module.aad_sparql.client_id
#    },
#    {
#      name  = "stardog.jwtConfig.issuers[0].algorithms[0].keyUrl",
#      value = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/discovery/v2.0/keys"
#    },


    { name = "stardog.image.registry", value = module.acr.login_server },
    { name = "stardog.image.repository", value = "stardog/stardog" },
    { name = "stardog.image.tag", value = var.stardog_image_tag },
    { name = "stardog.persistence.storageClass", value = var.stardog_storage_class },

    { name = "global.launchpad.enabled", value = var.launchpad_enabled },
    { name = "launchpad.ingress.url", value = var.ingress_dns_root },

#    { name = "launchpad.environmentVariables.AZURE_TENANT", value = data.azurerm_client_config.current.tenant_id },
#    { name = "launchpad.environmentVariables.AZURE_CLIENT_ID", value = module.aad_launchpad.client_id },
#    { name = "launchpad.environmentVariables.AZURE_CLIENT_SECRET", value = module.aad_launchpad.secret },
#    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_CLIENT_ID", value = module.aad_sparql.client_id },
#    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_CLIENT_SECRET", value = module.aad_sparql.secret },
#    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_TENANT", value = data.azurerm_client_config.current.tenant_id },
#    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_STARDOG_ENDPOINT", value = "https://sparql.${local.ingress_dns_root}" },
#

    { name = "launchpad.image.registry", value = module.acr.login_server },
    { name = "launchpad.image.repository", value = "stardog/launchpad" },
    { name = "launchpad.image.tag", value = var.launchpad_image_tag },

#    { name = "global.voicebox.enabled", value = var.enable_voicebox },
#    { name = "voicebox.image.registry", value = module.acr.login_server },
#    { name = "voicebox.image.repository", value = "stardog/voicebox-service" },
#    { name = "voicebox.image.tag", value = var.voicebox_image_tag },
#    { name = "voicebox.environmentVariables.AZURE_API_KEY", value = local.central_secrets["vbx-azure-api-key"] },

  ], []) 

  depends_on = [module.acr]
}


#module "stardog_roles" {
#  source = "./modules/stardog_resources/role_set"
#
#  deploy                     = var.deploy_stardog_stack
#  namespace                  = local.stardog_namespace_effective
#  kubeconfig_path            = local.kubeconfig_path
#  image                      = module.stardog_manager_image.image_uri
#  stardog_url                = local.stardog_internal_service_url
#  stardog_username           = var.stardog_admin_username
#  stardog_password           = var.stardog_admin_password
#  stardog_insecure           = var.stardog_admin_tls_insecure
#  roles                      = var.stardog_roles
#  container_env_extra        = {}
#  extra_cli_args             = []
#  local_exec_env             = {}
#  kubeconfig_refresh_command = <<-EOT
#    if az aks show -g ${azurerm_resource_group.rg.name} -n ${module.aks.name} >/dev/null 2>&1; then
#      az aks get-credentials -g ${azurerm_resource_group.rg.name} -n ${module.aks.name} --file "${local.kubeconfig_path}" --overwrite-existing >/dev/null
#    else
#      echo "AKS cluster ${module.aks.name} not available; skipping kubeconfig refresh"
#    fi
#  EOT
#
#  depends_on = [module.stardog, module.stardog_manager_image]
#}
