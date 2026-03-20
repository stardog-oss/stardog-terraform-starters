# Make the module testable without a real Azure config
mock_provider "azurerm" {}

run "nodepools_autoscale" {
  command = plan

  variables  {
    subscription_id        = "00000000-0000-0000-0000-000000000000"
    name                   = "ut-aks"
    location               = "eastus"
    resource_group_name    = "ut-aks-rg"
    kubernetes_version     = "1.31.8"
    system_vm_size         = "Standard_D2_v2"
    system_os_disk_size_gb = 128
    system_count           = 2

    user_node_pools = {
      sdpool = {
        vm_size              = "Standard_D4s_v4"
        os_disk_size_gb      = 128
        auto_scaling_enabled = true
        min_count            = 1
        max_count            = 3
        mode                 = "User"
        node_taints          = ["workload=stardog:NoSchedule"]
      }
    }

    attach_acr_names  = []
    tags            = { env = "test" }
  }

  # Assert the node pool resource exists and autoscaling variables are carried through
  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.user["sdpool"].auto_scaling_enabled == true
    error_message = "sdpool must have autoscaling enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.user["sdpool"].min_count == 1 && azurerm_kubernetes_cluster_node_pool.user["sdpool"].max_count == 3
    error_message = "sdpool min/max counts mismatch."
  }
}
