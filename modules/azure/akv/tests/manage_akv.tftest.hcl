
# Make the module testable without a real Azure config
mock_provider "azurerm" {}

run "manage_akv_true_creates_the_vault" {
  command = plan

  variables {
    name                = "ut-kv"
    resource_group_name = "ut-kv-rg"
    location            = "eastus"
    tenant_id           = "00000000-0000-0000-0000-000000000000"
    tags                = { env = "test" }
  }

  assert {
    condition     = length(azurerm_key_vault.this) == 1
    error_message = "manage_akv defaults to true - the vault must be created."
  }

  assert {
    condition     = length(data.azurerm_key_vault.existing) == 0
    error_message = "No data source lookup should happen when manage_akv is true."
  }
}

run "manage_akv_false_references_the_existing_vault" {
  command = plan

  variables {
    name                = "ut-kv-shared"
    resource_group_name = "ut-shared-rg"
    location            = "eastus"
    tenant_id           = "00000000-0000-0000-0000-000000000000"
    manage_akv          = false
    tags                = { env = "test" }
  }

  # Only computed attributes can be overridden - `name` is an input argument of this data source
  # (set from var.name in main.tf), not computed, so it isn't listed here; it already resolves to
  # whatever the config passed in.
  override_data {
    target = data.azurerm_key_vault.existing
    values = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ut-shared-rg/providers/Microsoft.KeyVault/vaults/ut-kv-shared"
      vault_uri = "https://ut-kv-shared.vault.azure.net/"
    }
  }

  # Real bug this guards against: module.akv_shared in envctl's infra/main.tf had no manage_akv-
  # style gate at all, so every isolated per-instance stack created (and forked) its own duplicate
  # "shared" Key Vault instead of referencing the one real vault - confirmed live: three
  # akvenvctlshared* vaults existed where there should have been one.
  assert {
    condition     = length(azurerm_key_vault.this) == 0
    error_message = "No vault should be created when manage_akv is false."
  }

  assert {
    condition     = output.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ut-shared-rg/providers/Microsoft.KeyVault/vaults/ut-kv-shared"
    error_message = "The module's own id output must resolve to the existing vault's id, not a newly created one."
  }

  assert {
    condition     = output.name == "ut-kv-shared"
    error_message = "The module's own name output must resolve to the existing vault's name."
  }
}

run "manage_akv_false_still_allows_attaching_role_assignments" {
  command = plan

  variables {
    name                       = "ut-kv-shared"
    resource_group_name        = "ut-shared-rg"
    location                   = "eastus"
    tenant_id                  = "00000000-0000-0000-0000-000000000000"
    manage_akv                 = false
    rbac_authorization_enabled = true
    admin_object_id            = "11111111-1111-1111-1111-111111111111"
    tags                       = { env = "test" }
  }

  # Only computed attributes can be overridden - `name` is an input argument of this data source
  # (set from var.name in main.tf), not computed, so it isn't listed here; it already resolves to
  # whatever the config passed in.
  override_data {
    target = data.azurerm_key_vault.existing
    values = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ut-shared-rg/providers/Microsoft.KeyVault/vaults/ut-kv-shared"
      vault_uri = "https://ut-kv-shared.vault.azure.net/"
    }
  }

  # This is the whole point of manage_akv=false over a plain import: consuming stacks still need
  # to attach their own role assignments (and, outside this module, secrets) to the shared vault -
  # a data source is sufficient for that, since these are separate child resources referencing the
  # vault by id, not properties of the vault resource itself.
  assert {
    condition     = azurerm_role_assignment.kv_secret_officer_admin_object[0].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ut-shared-rg/providers/Microsoft.KeyVault/vaults/ut-kv-shared"
    error_message = "Role assignments must attach to the existing (data-sourced) vault's id."
  }
}
