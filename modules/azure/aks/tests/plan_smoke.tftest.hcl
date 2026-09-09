# Make the module testable without a real Azure config
mock_provider "azurerm" {
  # A generic mock otherwise generates an empty kube_config list, and this module's own
  # kube_host/kube_client_certificate/kube_client_key/kube_cluster_ca_certificate outputs all index
  # into kube_config[0] - needed for those outputs to evaluate at all under a mocked apply.
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      kube_config = [{
        host                   = "https://ut-aks.example.com"
        client_certificate     = "mock-client-cert"
        client_key             = "mock-client-key"
        cluster_ca_certificate = "mock-ca-cert"
        username               = "mock-user"
        password               = "mock-password"
      }]
    }
  }
}

run "plan_smoke" {
  command = apply

  variables  {
    subscription_id        = "00000000-0000-0000-0000-000000000000"
    name                   = "ut-aks"
    location               = "eastus"
    resource_group_name    = "ut-aks-rg"
    kubernetes_version     = "1.31.8"
    system_vm_size         = "Standard_D2_v2"
    system_os_disk_size_gb = 128
    system_count           = 2

    # Network (explicit for stability)
    service_cidr   = "10.0.0.0/16"
    dns_service_ip = "10.0.0.10"
    pod_cidr       = "10.244.0.0/16"

    # no extra pools; no ACR attached
    user_node_pools = {}
    attach_acr_names  = []
    tags            = { env = "test" }

    # Skips the ensure_node_nsg_allow_azure_lb local-exec provisioner entirely - it shells out to
    # real `az`/`kubectl` regardless of the mocked provider (mocking only replaces the provider's own
    # API calls, not arbitrary local-exec commands), which this test isn't exercising and shouldn't
    # depend on real Azure access for.
    enable_nodeport_nsg_rules = false

    create_log_analytics = false
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/workspaceName"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled == true
    error_message = "OIDC issuer must be enabled for Workload Identity."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.workload_identity_enabled == true
    error_message = "Workload Identity must be enabled."
  }

  assert {
    condition     = can(azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0])
    error_message = "AKV CSI add-on must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_D2_v2"
    error_message = "Default node pool VM size mismatch."
  }
}
