
# Make the module testable without a real Azure config
mock_provider "azurerm" {}

run "kv_plan" {
  command = plan

  variables {
    name                = "ut-kv" # let module auto-generate or compute
    resource_group_name = "ut-kv-rg"
    location            = "eastus"

    # add these if your module uses data.azurerm_client_config.current.*
    tenant_id       = "00000000-0000-0000-0000-000000000000"
    admin_object_id = "11111111-1111-1111-1111-111111111111" # only if you still create access_policy

    # if your module supports RBAC (recommended):
    rbac_authorization_enabled = true
    use_access_policies        = false # only if you have a toggle (see option B)

    tags = { env = "test" }
  }

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled == true
    error_message = "Key Vault must have RBAC authorization enabled."
  }

  assert {
    condition     = length(azurerm_key_vault.this.name) <= 24
    error_message = "Key Vault name should be <= 24 chars."
  }
}
