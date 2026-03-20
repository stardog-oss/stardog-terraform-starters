variable "subscription_id" {
  description = "Azure subscription UUID where all resources will be created."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID used for AzureRM + AzureAD providers."
  type        = string
}

variable "location" {
  description = "Azure region for all student sandboxes (e.g., westus2)."
  type        = string
  default     = "westus2"
}

variable "name_prefix" {
  description = "Prefix applied to student resource names."
  type        = string
  default     = "training"
}

variable "tfstate_resource_group_name" {
  description = "Resource group that contains the shared tfstate storage account."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Shared tfstate storage account name."
  type        = string
}

variable "student_tfstate_container_name" {
  description = "Optional container name for student tfstate (defaults to <name_prefix>-tfstate)."
  type        = string
  default     = null
}

variable "create_student_tfstate_container" {
  description = "When true, create the student tfstate container in the shared storage account."
  type        = bool
  default     = true
}

variable "create_student_tfstate_group" {
  description = "When true, create a group for student tfstate access."
  type        = bool
  default     = true
}

variable "student_tfstate_group_name" {
  description = "Optional Entra group display name for tfstate access (defaults to <name_prefix>-tfstate-writers)."
  type        = string
  default     = null
}

variable "student_tfstate_role_definition_name" {
  description = "Role assigned to the tfstate group at the container scope."
  type        = string
  default     = "Storage Blob Data Contributor"
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}

variable "students" {
  description = "Map of students keyed by inst_id. Example: { sd1 = { email = \"user@example.com\" } }"
  type = map(object({
    email = string
    cc    = optional(string)
  }))

  validation {
    condition     = length(var.students) > 0
    error_message = "students must contain at least one entry."
  }

  validation {
    condition = alltrue([
      for k in keys(var.students) : length(replace(k, "/[^a-zA-Z0-9]/", "")) > 0
    ])
    error_message = "Each student key (inst_id) must contain at least one alphanumeric character."
  }

  validation {
    condition = alltrue([
      for s in values(var.students) : s.cc == null || s.cc == "" || can(regex("@", s.cc))
    ])
    error_message = "Each student cc must be empty or a valid email address."
  }
}

variable "invite_students" {
  description = "When true, send Entra B2B invitations for each student email."
  type        = bool
  default     = true
}

variable "invite_redirect_url" {
  description = "Redirect URL used in B2B invitations (must include tenantId). Leave empty to use the default portal URL."
  type        = string
  default     = ""

  validation {
    condition = var.invite_redirect_url == "" || can(regex("tenantId=", var.invite_redirect_url)) || can(regex(var.tenant_id, var.invite_redirect_url))
    error_message = "invite_redirect_url must include the tenantId query parameter or the tenant GUID."
  }
}

variable "send_invitation_message" {
  description = "Whether to send invitation email to students."
  type        = bool
  default     = true
}

variable "invite_cc_email" {
  description = "Optional CC email for B2B invitations (single address)."
  type        = string
  default     = ""

  validation {
    condition     = var.invite_cc_email == "" || can(regex("@", var.invite_cc_email))
    error_message = "invite_cc_email must be empty or contain a valid email address."
  }
}

variable "student_object_ids" {
  description = "Optional map of existing Entra object IDs keyed by inst_id (used when invite_students = false)."
  type        = map(string)
  default     = {}

  validation {
    condition     = var.invite_students || length(var.student_object_ids) == length(var.students)
    error_message = "When invite_students is false, student_object_ids must include one entry per student."
  }
}

variable "student_role_definition_name" {
  description = "Azure role assigned to each student at their RG scope."
  type        = string
  default     = "Contributor"
}

variable "student_acr_role_definition_name" {
  description = "Role assigned to students on the shared ACR (AcrPush includes AcrPull)."
  type        = string
  default     = "AcrPush"
}

variable "aks_role_definition_name" {
  description = "Optional AKS role assigned to each student at the AKS resource scope (set null to skip)."
  type        = string
  default     = null
}

variable "acr_prefix" {
  description = "Prefix for ACR names (lowercase alphanumeric only)."
  type        = string
  default     = "sd"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.acr_prefix))
    error_message = "acr_prefix must be 2-10 lowercase alphanumeric characters."
  }
}

variable "acr_sku" {
  description = "ACR SKU tier."
  type        = string
  default     = "Basic"
}

variable "acr_admin_enabled" {
  description = "Enable ACR admin user (dev/test convenience)."
  type        = bool
  default     = true
}

# Optional ACR content import (matches gateway-01 pattern)
variable "import_charts" {
  description = "Enable importing Helm charts from external OCI registries into ACR via the module's local-exec helper."
  type        = bool
  default     = false
}

variable "charts_to_import" {
  description = "List of Helm charts to import into ACR (OCI refs)."
  type        = list(string)
  default     = []
}

variable "import_images" {
  description = "Enable importing container images into ACR via az acr import."
  type        = bool
  default     = false
}

variable "images_to_import" {
  description = "List of container images to import into ACR (format: <image>:<tag>)."
  type        = list(string)
  default     = []
}

variable "jfrog_registry_username" {
  description = "Username to authenticate to JFrog registry. Default is 'apikey' for Artifactory API keys."
  type        = string
  default     = "apikey"
}

variable "jfrog_registry_password" {
  description = "Password/token for JFrog registry (sensitive). Pass via TF_VAR_jfrog_registry_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "source_registry_username" {
  description = "Optional source registry username for ACR image imports (e.g., Docker Hub username)."
  type        = string
  default     = ""
}

variable "source_registry_password" {
  description = "Optional source registry password/token for ACR image imports."
  type        = string
  default     = ""
  sensitive   = true
}

variable "public_ip_sku" {
  description = "Public IP SKU (Standard recommended)."
  type        = string
  default     = "Standard"
}

variable "system_vm_size" {
  description = "AKS system pool VM size."
  type        = string
  default     = "Standard_D2as_v5"
}

variable "system_count" {
  description = "AKS system pool node count."
  type        = number
  default     = 2
}

variable "system_os_disk_size_gb" {
  description = "AKS system pool OS disk size."
  type        = number
  default     = 128
}

variable "user_node_pools" {
  description = "AKS user node pools."
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

  default = {
    sdpool = {
      vm_size              = "Standard_D4as_v5"
      os_disk_size_gb      = 128
      auto_scaling_enabled = true
      min_count            = 1
      max_count            = 3
      node_labels          = { target = "stardog" }
      node_taints          = ["workload=stardog:NoSchedule"]
    }
    zkpool = {
      vm_size              = "Standard_D2as_v5"
      os_disk_size_gb      = 128
      auto_scaling_enabled = true
      min_count            = 0
      max_count            = 3
      node_labels          = { target = "zookeeper" }
      node_taints          = ["workload=zookeeper:NoSchedule"]
    }
  }
}

variable "aks_create_log_analytics" {
  description = "Whether AKS should create a Log Analytics workspace."
  type        = bool
  default     = false
}

variable "enable_aks_stop_schedule" {
  description = "When true, create a daily AKS stop schedule as a safety net."
  type        = bool
  default     = true
}

variable "aks_stop_daily_time" {
  description = "Local time (HH:MM, 24h) when AKS should stop."
  type        = string
  default     = "20:00"
}

variable "aks_stop_schedule_timezone" {
  description = "IANA timezone for the AKS stop schedule."
  type        = string
  default     = "America/Los_Angeles"
}

variable "aks_stop_role_definition_name" {
  description = "Role assigned to the automation account for stopping AKS."
  type        = string
  default     = "Azure Kubernetes Service Cluster Admin Role"
}

variable "aks_stop_automation_account_name" {
  description = "Existing Automation Account name to use for all students (optional when using bootstrap remote state)."
  type        = string
  default     = null
}

variable "aks_stop_automation_account_resource_group_name" {
  description = "Resource group of the existing Automation Account (optional when using bootstrap remote state)."
  type        = string
  default     = null
}

variable "aks_stop_install_automation_modules" {
  description = "Override whether to install Az.Accounts/Az.Aks modules in the Automation Account."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "DNS zone name for student records (e.g., training.sd-testlab.com)."
  type        = string
  default     = null
}

variable "dns_zone_resource_group" {
  description = "Resource group that contains the DNS zone."
  type        = string
  default     = null
}

variable "create_student_dns_records" {
  description = "When true, create per-student DNS A records in the specified zone."
  type        = bool
  default     = false
}

variable "create_student_dns_root_record" {
  description = "When true, create the root A record (<student>.<zone>) in addition to wildcard."
  type        = bool
  default     = false
}

variable "dns_record_ttl" {
  description = "TTL for student DNS records."
  type        = number
  default     = 60
}
