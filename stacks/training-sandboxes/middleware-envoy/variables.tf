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

variable "target_groups" {
  description = "Optional list of student group names to upgrade; empty means all. Matching is case-insensitive."
  type        = list(string)
  default     = []
}

variable "infra_kubeconfig_dir" {
  description = "Directory containing per-student kubeconfig files created by infra."
  type        = string
  default     = "../infra/kubeconfigs"
}

variable "enable_gateway_install" {
  description = "Install Envoy Gateway + cert-manager (pattern #1) for each selected student."
  type        = bool
  default     = true
}


variable "gateway_api_crds_version" {
  description = "Gateway API CRDs version tag. Keep this compatible with Envoy Gateway chart version."
  type        = string
  default     = "v1.5.0"
}

variable "cert_manager_chart_version" {
  description = "Optional cert-manager chart version. Empty means default/latest."
  type        = string
  default     = ""
}

variable "envoy_gateway_chart_version" {
  description = "Envoy Gateway chart version. Pin this instead of floating latest so it stays compatible with Gateway API CRDs."
  type        = string
  default     = "1.8.0"
}

variable "gateway_class_name" {
  description = "GatewayClass name for Envoy Gateway."
  type        = string
  default     = "stardog-envoy-gateway-class"
}

variable "gateway_namespace" {
  description = "Namespace for Envoy Gateway resources."
  type        = string
  default     = "envoy-gateway"
}
