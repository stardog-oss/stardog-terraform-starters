# Make the module testable without a real Azure config
mock_provider "azurerm" {}

run "acr_plan" {
  command = plan

  variables  {
    resource_group_name = "ut-acr-rg"
    location            = "eastus"
    cluster_name        = "ut-aks"
    acr_name            = "unittestacr"
    acr_sku             = "Basic"
    acr_admin_enabled   = true
    tags                = { env = "test" }
    cluster_kubelet_object_id = null
  }

  assert {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5–50 lowercase alphanumerics."
  }

  assert {
    condition     = azurerm_container_registry.this[0].admin_enabled == true
    error_message = "ACR admin should be enabled in this test."
  }
}

run "acr_admin_disabled_by_default" {
  command = plan

  variables {
    resource_group_name       = "ut-acr-rg"
    location                  = "eastus"
    cluster_name              = "ut-aks"
    acr_name                  = "unittestacr"
    acr_sku                   = "Basic"
    tags                      = { env = "test" }
    cluster_kubelet_object_id = null
  }

  # Real bug this guards against: acr_admin_enabled used to default to true, directly contradicting
  # its own description ("Consider false for production") - RBAC (AcrPull to the kubelet identity)
  # already covers the real use case, making the admin user/password unnecessary attack surface.
  assert {
    condition     = azurerm_container_registry.this[0].admin_enabled == false
    error_message = "ACR admin should default to disabled, matching this variable's own description."
  }
}
