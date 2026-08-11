locals {
  student            = data.terraform_remote_state.infra.outputs.students[var.inst_id]
  middleware_student = data.terraform_remote_state.middleware.outputs.students[var.inst_id]

  resource_group_name  = local.student.resource_group_name
  aks_name             = local.student.aks_name
  ingress_dns_root     = coalesce(local.student.dns_root, try(replace(local.student.dns_wildcard, "*.", ""), null))
  gateway_name         = local.middleware_student.gateway_name
  sparql_tls_secret    = local.middleware_student.sparql_tls_secret
  launchpad_tls_secret = local.middleware_student.launchpad_tls_secret

  tenant_id         = data.azurerm_key_vault_secret.tenant_id.value
  issuer            = "https://login.microsoftonline.com/${local.tenant_id}/v2.0"
  key_url           = "https://login.microsoftonline.com/${local.tenant_id}/discovery/v2.0/keys"
  sparql_endpoint   = "https://sparql.${local.ingress_dns_root}"
  stardog_chart_url = var.stardog_chart_url != "" ? var.stardog_chart_url : "https://stardog-oss.github.io/kube-stardog-stack/kube-stardog-stack-${var.stardog_chart_version}.tgz"
  image_registry    = data.terraform_remote_state.infra.outputs.shared_acr.login_server
  voicebox_azure_ai_endpoint_raw = trimsuffix(
    data.azurerm_key_vault_secret.voicebox_azure_ai_server_url.value,
    "/"
  )
  voicebox_azure_ai_server_url = strcontains(local.voicebox_azure_ai_endpoint_raw, "/models") ? local.voicebox_azure_ai_endpoint_raw : "${replace(local.voicebox_azure_ai_endpoint_raw, ".cognitiveservices.azure.com", ".services.ai.azure.com")}/models"

  voicebox_config = jsonencode({
    agent_selection_type     = "llm"
    enable_lineage           = true
    enable_external_llm      = true
    enable_analytics         = true
    enable_charts            = true
    use_agents_automatically = false
    default_llm_config = {
      llm_provider = "azure"
      llm_name     = data.azurerm_key_vault_secret.voicebox_azure_ai_deployment.value
      server_url   = local.voicebox_azure_ai_server_url
    }
    query_kg_config = {
      generate_query_config = {
        llm_config = {
          max_tokens = 7000
        }
      }
    }
  })
  voicebox_config_helm_set = replace(
    replace(
      replace(local.voicebox_config, "{", "\\{"),
      "}",
      "\\}"
    ),
    ",",
    "\\,"
  )

  helm_set = [
    { name = "stardog.ingress.url", value = local.ingress_dns_root },
    { name = "stardog.jwtConfig.signer.issuer", value = "https://sparql.${local.ingress_dns_root}:5820" },
    { name = "stardog.jwtConfig.signer.secret", value = "some-kind-of-secret-key-here" },

    { name = "global.gateway.name", value = local.gateway_name },
    { name = "global.gateway.domain", value = local.ingress_dns_root },
    { name = "global.gateway.tls.sparqlSecretName", value = local.sparql_tls_secret },
    { name = "global.gateway.tls.launchpadSecretName", value = local.launchpad_tls_secret },

    { name = "stardog.image.registry", value = local.image_registry },
    { name = "stardog.image.repository", value = "stardog/stardog" },
    { name = "stardog.image.tag", value = var.stardog_image_tag },

    { name = "stardog.jwtConfig.issuers[0].issuer", value = local.issuer },
    { name = "stardog.jwtConfig.issuers[0].audience", value = data.azurerm_key_vault_secret.sparql_client_id.value },
    { name = "stardog.jwtConfig.issuers[0].algorithms[0].keyUrl", value = local.key_url },

    { name = "global.launchpad.enabled", value = "true" },
    { name = "launchpad.ingress.url", value = local.ingress_dns_root },
    { name = "launchpad.image.registry", value = local.image_registry },
    { name = "launchpad.image.repository", value = "stardog/launchpad" },
    { name = "launchpad.image.tag", value = var.launchpad_image_tag },

    { name = "launchpad.environmentVariables.AZURE_TENANT", value = local.tenant_id },
    { name = "launchpad.environmentVariables.AZURE_CLIENT_ID", value = data.azurerm_key_vault_secret.launchpad_client_id.value },
    { name = "launchpad.environmentVariables.AZURE_CLIENT_SECRET", value = data.azurerm_key_vault_secret.launchpad_client_secret.value },
    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_CLIENT_ID", value = data.azurerm_key_vault_secret.sparql_client_id.value },
    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_CLIENT_SECRET", value = data.azurerm_key_vault_secret.sparql_client_secret.value },
    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_TENANT", value = local.tenant_id },
    { name = "launchpad.environmentVariables.SSOCONNECTION_MSENTRA_AZURE_STARDOG_ENDPOINT", value = local.sparql_endpoint },

    { name = "voicebox.image.registry", value = local.image_registry },
    { name = "voicebox.image.repository", value = "stardog/voicebox-service" },
    { name = "voicebox.image.tag", value = var.voicebox_image_tag },
    { name = "voicebox.environmentVariables.AZURE_API_KEY", value = data.azurerm_key_vault_secret.voicebox_azure_api_key.value },
    { name = "voicebox.configFile", value = local.voicebox_config_helm_set },
    { name = "voicebox.bitesService.image.registry", value = local.image_registry },
    { name = "voicebox.bitesService.image.repository", value = "stardog/voicebox-bites" },
    { name = "voicebox.bitesService.image.tag", value = var.voicebox_bites_image_tag },
  ]
}
