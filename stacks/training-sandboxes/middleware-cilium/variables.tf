variable "subscription_id" {
  description = "Azure subscription UUID where middleware resources are managed."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant UUID."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to derive default names and infra state key."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}

variable "tfstate_resource_group_name" {
  description = "Resource group hosting the Terraform state storage account."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name hosting the Terraform state container."
  type        = string
}

variable "tfstate_container_name" {
  description = "Container name for Terraform state (default: tfstate)."
  type        = string
  default     = "tfstate"
}

variable "infra_state_key" {
  description = "Optional override for the infra state key."
  type        = string
  default     = ""
}

variable "target_students" {
  description = "Optional list of student IDs to upgrade; empty means all."
  type        = list(string)
  default     = []
}

variable "infra_kubeconfig_dir" {
  description = "Directory containing per-student kubeconfig files created by infra."
  type        = string
  default     = "../infra/kubeconfigs"
}

variable "enable_gateway_install" {
  description = "Enable Cilium Gateway API + cert-manager for each selected student. Requires Cilium to already be installed on the target clusters."
  type        = bool
  default     = true
}

variable "gateway_api_crds_version" {
  description = "Gateway API CRDs version tag (for example, v1.4.1)."
  type        = string
  default     = "v1.4.1"
}

variable "cert_manager_chart_version" {
  description = "Optional cert-manager chart version. Empty means default/latest."
  type        = string
  default     = ""
}

variable "cilium_chart_version" {
  description = "Optional Cilium chart version used when enabling Gateway API on an existing Cilium install."
  type        = string
  default     = "1.19.2"
}

variable "cilium_namespace" {
  description = "Namespace where the Cilium Helm release already exists."
  type        = string
  default     = "kube-system"
}

variable "cilium_release_name" {
  description = "Existing Helm release name for Cilium."
  type        = string
  default     = "cilium"
}

variable "cilium_repo_name" {
  description = "Helm repo alias used to resolve the Cilium chart."
  type        = string
  default     = "cilium"
}

variable "cilium_repo_url" {
  description = "Helm repo URL for the Cilium chart."
  type        = string
  default     = "https://helm.cilium.io"
}

variable "gateway_class_name" {
  description = "GatewayClass name for Cilium Gateway API."
  type        = string
  default     = "stardog-cilium-gateway-class"
}

variable "gateway_namespace" {
  description = "Namespace for shared Cilium Gateway resources."
  type        = string
  default     = "cilium-gateway"
}
