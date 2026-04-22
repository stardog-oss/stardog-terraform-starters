variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID."
  type        = string
}

variable "location" {
  description = "Azure region for the bootstrap resources. Defaults to the resource group's location."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for tags."
  type        = string
  default     = "sdtraining"
}

variable "resource_group_name" {
  description = "Resource group for shared training resources."
  type        = string
  default     = "sd-proserv-rg"
}

variable "tfstate_storage_account_name" {
  description = "Storage account that hosts the remote Terraform state."
  type        = string
}

variable "tfstate_resource_group_name" {
  description = "Resource group that contains the tfstate storage account."
  type        = string
  default     = "sd-proserv-rg"
}

variable "automation_account_name" {
  description = "Central Automation Account name for AKS stop schedules."
  type        = string
  default     = "automations"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,50}$", var.automation_account_name))
    error_message = "automation_account_name must be 3-50 characters and contain only letters, numbers, or hyphens."
  }
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default     = {}
}
