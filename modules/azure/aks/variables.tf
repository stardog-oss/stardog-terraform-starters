variable "subscription_id" {
  description = "Azure subscription UUID where the AKS cluster and related resources will be created/managed."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group that will contain the AKS control plane resource."
  type        = string
}

variable "location" {
  description = "Azure region for AKS (e.g., eastus). Use the lowercase Azure API name."
  type        = string
}

variable "name" {
  description = "Logical name of the AKS cluster (used for the azurerm_kubernetes_cluster resource)."
  type        = string
}

variable "kubernetes_version" {
  description = "Cluster Kubernetes version to deploy (e.g., 1.31.8). Set null to let Azure pick the default/auto-upgrade."
  type        = string
  default     = null
}

variable "node_resource_group" {
  description = "Name of the managed node resource group for AKS worker resources. If null, Azure will generate one."
  type        = string
  default     = null
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes Services (cluster IPs). Must not overlap with pod or VNet address spaces."
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address within service_cidr to assign to kube-dns/CoreDNS (e.g., 10.0.0.10)."
  type        = string
  default     = "10.0.0.10"
}

variable "pod_cidr" {
  description = "CIDR range for Kubernetes Pods when using kubenet (e.g., 10.244.0.0/16)."
  type        = string
  default     = "10.244.0.0/16"
}

variable "enable_ingress_application_gateway" {
  description = "Enable the AKS-managed Application Gateway Ingress Controller add-on."
  type        = bool
  default     = false
}

variable "ingress_application_gateway_name" {
  description = "Optional name for the managed Application Gateway. If null, a name is derived from the cluster name."
  type        = string
  default     = null
}

variable "ingress_application_gateway_subnet_cidr" {
  description = "CIDR block (within the managed node resource group) used when AKS creates the Application Gateway subnet. Required when enabling the ingress Application Gateway add-on."
  type        = string
  default     = null
}

variable "system_vm_size" {
  description = "VM size for the System node pool (e.g., Standard_D2_v2)."
  type        = string
}

variable "system_count" {
  description = "Initial node count for the System node pool."
  type        = number
}

variable "system_os_disk_size_gb" {
  description = "OS disk size (GB) for nodes in the System pool."
  type        = number
}

variable "tags" {
  description = "Tags to apply to all AKS resources created by this module."
  type        = map(string)
  default     = {}
}

# One or more ACR IDs to attach (can be empty)
variable "attach_acr_ids" {
  description = "List of ACR resource IDs to grant AcrPull to the AKS kubelet identity (in addition to attach_acr_id if set)."
  type        = list(string)
  default     = []
}

variable "attach_acr_id" {
  description = "Single ACR resource ID (e.g., the one just created) to grant AcrPull to the AKS kubelet identity. Set null to skip."
  type        = string
  default     = null
}

variable "user_node_pools" {
  description = <<-EOT
    Map of additional (User mode) AKS node pools. Key = pool name (1–12 lowercase alphanumeric).
    Each value supports:

    - vm_size (string): VM size for this pool (e.g., Standard_D4s_v4).
    - os_disk_size_gb (number): OS disk size in GB.
    - orchestrator_version (optional string): Pool’s k8s version. Omit to inherit cluster version.
    - auto_scaling_enabled (optional bool, default: true): Enable/disable autoscaling.
    - min_count (optional number): Minimum nodes when autoscaling is enabled.
    - max_count (optional number): Maximum nodes when autoscaling is enabled.
    - node_count (optional number): Fixed node count when autoscaling is disabled.
    - mode (optional string, default: "User"): Pool mode; keep as "User".
    - node_taints (optional list(string), default: []): Taints to apply (e.g., ["workload=stardog:NoSchedule"]).
    - node_labels (optional map(string), default: {}): Node labels to apply to this pool’s nodes.
    - tags (optional map(string), default: {}): Additional tags merged with the module-level tags.
  EOT
  type = map(object({
    vm_size              = string
    os_disk_size_gb      = number
    orchestrator_version = optional(string)
    auto_scaling_enabled = optional(bool, true)
    min_count            = optional(number)
    max_count            = optional(number)
    node_count           = optional(number)
    mode                 = optional(string, "User")
    node_taints          = optional(list(string), [])
    node_labels          = optional(map(string), {})
    tags                 = optional(map(string), {})
  }))
}

variable "create_log_analytics" {
  description = "Whether to create a Log Analytics workspace for AKS monitoring (used by the OMS/ContainerInsights addon)."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "If not creating a workspace, provide the ARM ID of an existing Log Analytics workspace to use."
  type        = string
  default     = null
}
variable "kubeconfig_path" {
  description = "Path where az aks get-credentials should write when enable_kubectl_helpers is true."
  type        = string
  default     = "~/.kube/config"
}

variable "enable_nodeport_nsg_rules" {
  description = "When true, run a local-exec to ensure node NSGs allow Azure Load Balancer -> NodePort traffic."
  type        = bool
  default     = true
}

variable "shell_interpreter" {
  description = "List of interpreter tokens used for local-exec provisioners (override on Windows, default uses env/bash)."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
