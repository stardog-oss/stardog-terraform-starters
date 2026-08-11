data "terraform_remote_state" "infra" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = var.infra_state_key
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "middleware" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = var.middleware_state_key
    use_azuread_auth     = true
  }
}

data "azurerm_key_vault" "student" {
  name                = local.student.akv_name
  resource_group_name = local.resource_group_name
}

data "azurerm_key_vault" "shared" {
  name                = data.terraform_remote_state.infra.outputs.shared_key_vault.name
  resource_group_name = data.terraform_remote_state.infra.outputs.shared_key_vault.resource_group
}

data "azurerm_key_vault_secret" "tenant_id" {
  name         = "aad-tenant-id"
  key_vault_id = data.azurerm_key_vault.student.id
}

data "azurerm_key_vault_secret" "launchpad_client_id" {
  name         = "aad-launchpad-client-id"
  key_vault_id = data.azurerm_key_vault.student.id
}

data "azurerm_key_vault_secret" "launchpad_client_secret" {
  name         = "aad-launchpad-client-secret"
  key_vault_id = data.azurerm_key_vault.student.id
}

data "azurerm_key_vault_secret" "sparql_client_id" {
  name         = "aad-sparql-client-id"
  key_vault_id = data.azurerm_key_vault.student.id
}

data "azurerm_key_vault_secret" "sparql_client_secret" {
  name         = "aad-sparql-client-secret"
  key_vault_id = data.azurerm_key_vault.student.id
}

data "azurerm_key_vault_secret" "voicebox_azure_api_key" {
  name         = "ai-services-primary-key"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "voicebox_azure_ai_server_url" {
  name         = "ai-services-endpoint"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "voicebox_azure_ai_deployment" {
  name         = "ai-deployment-gpt-4o"
  key_vault_id = data.azurerm_key_vault.shared.id
}
