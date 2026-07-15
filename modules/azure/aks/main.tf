
resource "azurerm_log_analytics_workspace" "this" {
  count               = var.create_log_analytics ? 1 : 0
  name                = "law-${var.name}-${random_id.la_suffix[0].hex}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

/* Ensure node NSGs allow Azure Load Balancer -> NodePort traffic.
   This uses an idempotent az CLI local-exec so it can run in the same
   terraform apply that creates the AKS cluster and its node resource group.
   Requirements: the machine running `terraform apply` must have `az` CLI
   installed and be authenticated with permissions to update NSGs.
*/
resource "null_resource" "ensure_node_nsg_allow_azure_lb" {
  count = (var.enable_ingress_application_gateway || !var.enable_nodeport_nsg_rules) ? 0 : 1
  # rerun when cluster or node RG changes
  triggers = {
    cluster_id       = azurerm_kubernetes_cluster.this.id
    node_resource_rg = azurerm_kubernetes_cluster.this.node_resource_group
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    command     = <<-EOT
      set -euo pipefail

      NODE_RG="${azurerm_kubernetes_cluster.this.node_resource_group}"
      AKS_RG="${azurerm_kubernetes_cluster.this.resource_group_name}"
      AKS_NAME="${azurerm_kubernetes_cluster.this.name}"

      if [ -z "$NODE_RG" ]; then
        echo "No node resource group available; skipping NSG updates"
        exit 0
      fi

      echo "Ensuring NSG rules in node resource group: $NODE_RG"

      # list NSG names in the node resource group
      NSGS=$(az network nsg list -g "$NODE_RG" --query "[].name" -o tsv)

      if [ -z "$NSGS" ]; then
        echo "No NSGs found in $NODE_RG; skipping"
        exit 0
      fi

      # Fetch AKS credentials so we can query the ingress service
      echo "Fetching AKS credentials for $AKS_NAME (rg=$AKS_RG)"
      KUBECONFIG_PATH="$(eval echo "${var.kubeconfig_path}")"
      mkdir -p "$(dirname "$KUBECONFIG_PATH")"
      az aks get-credentials -g "$AKS_RG" -n "$AKS_NAME" --file "$KUBECONFIG_PATH" --overwrite-existing >/dev/null

      # Poll for the ingress service to appear and extract nodePorts
      echo "Polling for ingress-nginx-controller service (namespace: ingress-objects) to discover nodePorts"
      PORTS=""
      for i in $(seq 1 30); do
        PORTS=$(kubectl get svc -n ingress-objects ingress-nginx-controller -o jsonpath='{.spec.ports[*].nodePort}' 2>/dev/null || true)
        if [ -n "$PORTS" ]; then
          echo "Found nodePorts: $PORTS"
          break
        fi
        echo "Waiting for ingress svc to appear... ($i/30)"
        sleep 10
      done

      if [ -z "$PORTS" ]; then
        echo "Ingress service not found; using NodePort range fallback 30000-32767"
        DEST_PORTS="30000-32767"
      else
        DEST_PORTS="$PORTS"
      fi

      # Create NSG rules for each NSG found
      for nsg in $NSGS; do
        echo "Ensuring rule on $nsg for ports: $DEST_PORTS"
        az network nsg rule create \
          --resource-group "$NODE_RG" \
          --nsg-name "$nsg" \
          --name allow-aks-nodeports-from-azlb \
          --priority 100 \
          --direction Inbound \
          --access Allow \
          --protocol Tcp \
          --source-address-prefixes AzureLoadBalancer \
          --destination-address-prefixes '*' \
          --destination-port-ranges $DEST_PORTS \
          --description "Allow Azure LoadBalancer to forward NodePort traffic to nodes" \
          --output none || true
      done

      # If we discovered nodePorts, annotate the svc health probe path
      if [ -n "$PORTS" ]; then
        echo "Annotating ingress service with health probe path"
        kubectl annotate svc -n ingress-objects ingress-nginx-controller \
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path=/healthz" --overwrite || true
      else
        echo "Skipping svc annotation because ingress service was not found"
      fi

      echo "NSG rules ensured and service annotated (if present)"
    EOT
  }

  depends_on = [azurerm_kubernetes_cluster.this]
}


# Pick the workspace ID safely
locals {
  la_workspace_id                  = var.create_log_analytics ? azurerm_log_analytics_workspace.this[0].id : var.log_analytics_workspace_id
  ingress_application_gateway_name = coalesce(var.ingress_application_gateway_name, "${var.name}-appgw")
}

// Stable random suffix for Log Analytics workspace name when created by this module
resource "random_id" "la_suffix" {
  count       = var.create_log_analytics ? 1 : 0
  byte_length = 3
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = replace(var.name, "_", "-")
  kubernetes_version  = var.kubernetes_version

  node_resource_group = var.node_resource_group == null ? null : var.node_resource_group

  identity { type = "SystemAssigned" }

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_vm_size
    os_disk_size_gb      = var.system_os_disk_size_gb
    orchestrator_version = var.kubernetes_version
    type                 = "VirtualMachineScaleSets"
    auto_scaling_enabled = var.system_auto_scaling_enabled
    node_count           = var.system_auto_scaling_enabled ? null : var.system_count
    min_count            = var.system_auto_scaling_enabled ? var.system_min_count : null
    max_count            = var.system_auto_scaling_enabled ? var.system_max_count : null
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    pod_cidr          = var.pod_cidr
  }

  dynamic "ingress_application_gateway" {
    for_each = var.enable_ingress_application_gateway ? [1] : []
    content {
      gateway_name = local.ingress_application_gateway_name
      subnet_cidr  = var.ingress_application_gateway_subnet_cidr
    }
  }

  # Only emit the block if we have a valid ID
  dynamic "oms_agent" {
    for_each = local.la_workspace_id == null ? [] : [1]
    content {
      log_analytics_workspace_id = local.la_workspace_id
    }
  }

  storage_profile {
    blob_driver_enabled = true # enable Azure Blob CSI driver
    # (optional, shown for clarity—these default to true on AKS)
    # disk_driver_enabled         = true
    # file_driver_enabled         = true
    # snapshot_controller_enabled = true
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true

  # AKV CSI driver add-on (v4 syntax)
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2h" # optional
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.enable_ingress_application_gateway ? (var.ingress_application_gateway_subnet_cidr != null && trimspace(var.ingress_application_gateway_subnet_cidr) != "") : true
      error_message = "Set ingress_application_gateway_subnet_cidr when enable_ingress_application_gateway is true."
    }
    precondition {
      condition     = var.system_auto_scaling_enabled ? (var.system_min_count != null && var.system_max_count != null && var.system_min_count <= var.system_max_count) : true
      error_message = "Set system_min_count and system_max_count when system_auto_scaling_enabled is true."
    }
  }
}

locals {
  kubelet_oid = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, null)
}

# Existing registries (plan-known keys)
resource "azurerm_role_assignment" "acr_pull_existing" {
  for_each             = { for id in var.attach_acr_ids : id => id }
  scope                = each.value # ACR resource ID
  role_definition_name = "AcrPull"
  principal_id         = local.kubelet_oid
  depends_on           = [azurerm_kubernetes_cluster.this]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each              = var.user_node_pools
  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  os_disk_size_gb       = each.value.os_disk_size_gb
  mode                  = each.value.mode
  orchestrator_version  = try(each.value.orchestrator_version, null)

  # Autoscaling (v4.x schema)
  auto_scaling_enabled = try(each.value.auto_scaling_enabled, true)
  min_count            = try(each.value.min_count, null)
  max_count            = try(each.value.max_count, null)
  node_count           = try(each.value.node_count, null) # set only if autoscaling=false

  node_taints = try(each.value.node_taints, [])
  node_labels = try(each.value.node_labels, {})
  tags        = merge(var.tags, try(each.value.tags, {}))

  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  lifecycle {
    # helpful guardrails
    precondition {
      condition     = length(each.key) >= 1 && length(each.key) <= 12 && can(regex("^[a-z0-9]+$", each.key))
      error_message = "Node pool name '${each.key}' must be 1–12 chars, lowercase letters and digits only."
    }
    precondition {
      condition     = (try(each.value.auto_scaling_enabled, true) == true && try(each.value.min_count, null) != null && try(each.value.max_count, null) != null) || (try(each.value.auto_scaling_enabled, true) == false && try(each.value.node_count, null) != null)
      error_message = "Pool '${each.key}': when autoscaling is true set min_count/max_count; when false set node_count."
    }
  }
}
