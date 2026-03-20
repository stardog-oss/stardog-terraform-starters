variable "enabled" {
  description = "Whether to create the automation schedule."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Resource group that hosts the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region for the automation account."
  type        = string
}

variable "cluster_id" {
  description = "Resource ID of the AKS cluster."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "existing_automation_account_name" {
  description = "Existing Automation Account name to host the AKS stop schedule."
  type        = string
  default     = null

  validation {
    condition     = !var.enabled || (var.existing_automation_account_name != null && trimspace(var.existing_automation_account_name) != "")
    error_message = "existing_automation_account_name must be set when enabled is true."
  }
}

variable "existing_automation_account_resource_group_name" {
  description = "Resource group for the existing Automation Account."
  type        = string
  default     = null

  validation {
    condition     = !var.enabled || (var.existing_automation_account_resource_group_name != null && trimspace(var.existing_automation_account_resource_group_name) != "")
    error_message = "existing_automation_account_resource_group_name must be set when enabled is true."
  }
}

variable "install_automation_modules" {
  description = "Whether to manage Az.Accounts/Az.Aks modules in the Automation Account."
  type        = bool
  default     = false
}

variable "daily_stop_time" {
  description = "Local time (HH:MM, 24h) when the cluster should be stopped."
  type        = string
  default     = "20:00"
  validation {
    condition     = can(regex("^\\d{2}:\\d{2}$", var.daily_stop_time))
    error_message = "daily_stop_time must be in HH:MM format (24-hour clock)."
  }
}

variable "schedule_timezone" {
  description = "IANA timezone name used by the automation schedule (e.g., America/Toronto)."
  type        = string
  default     = "America/Toronto"
}

variable "role_definition_name" {
  description = "Role assigned to the automation account so it can stop the AKS cluster."
  type        = string
  default     = "Azure Kubernetes Service Cluster Admin Role"
}

variable "runbook_type" {
  description = "Automation runbook type (e.g., PowerShell72)."
  type        = string
  default     = "PowerShell72"
  validation {
    condition     = contains(["PowerShell", "PowerShell72"], var.runbook_type)
    error_message = "runbook_type must be PowerShell or PowerShell72."
  }
}

variable "tags" {
  description = "Tags applied to the automation account."
  type        = map(string)
  default     = {}
}
