
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

run "admin_group_role_assignment_gated_on_rbac_enabled" {
  command = plan

  variables {
    name                       = "ut-kv"
    resource_group_name        = "ut-kv-rg"
    location                   = "eastus"
    tenant_id                  = "00000000-0000-0000-0000-000000000000"
    admin_group_object_id      = "22222222-2222-2222-2222-222222222222"
    rbac_authorization_enabled = false
    use_access_policies        = false
    tags                       = { env = "test" }
  }

  # Real bug this guards against: this assignment used to be missing the same
  # rbac_authorization_enabled gate its sibling (kv_secret_officer_admin_object) already has - in
  # access-policy mode, Key Vault ignores RBAC role assignments entirely, so this assignment would
  # be created but grant no real access, silently.
  assert {
    condition     = length(azurerm_role_assignment.kv_secret_officer_admin_group) == 0
    error_message = "No RBAC role assignment should be created when rbac_authorization_enabled is false."
  }
}
