variable "subscription_id" {
  description = "Azure subscription UUID where all resources in this environment are managed."
  type        = string
}

variable "resource_group_name" {
  description = "Name of resource_group_name used by application"
  type        = string
  default     = null
}

variable "ingress_dns_root" { 
  description = "DNS root used by ingress, for example stardog.example.com."
  type = string
}

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service (AKS)."
  type        = string
}

## ACR
variable "acr_name" {
  description = "Name of the Azure Container Registry (ACR). Must be 5–50 lowercase alphanumeric."
  type        = string
}
variable "images_to_import" {
  description = "Images to upload"
  type        = list(string)
}
variable "charts_to_import" {
  description = "OCI or HTTPS url  (e.g. oci://registry.jfrog.io/stardog:11.2.0)"
  type        = list(string)
}

## JFrog registry credentials for chart import (optional)
variable "jfrog_registry_username" {
  description = "Username to authenticate to JFrog registry. Default is 'apikey' for Artifactory API keys."
  type        = string
  default     = "apikey"
}

variable "jfrog_registry_password" {
  description = "Password/token for JFrog registry (sensitive). Pass via environment var TF_VAR_jfrog_registry_password or a tfvars file."
  type        = string
  default     = ""
  sensitive   = true
}


##########################################################
# Stardog 
##########################################################
#

variable "stardog_namespace" { 
  description = "The namespace to deploy within"
  type = string
}

variable "stardog_release" { 
  description = "The release name of deployment"
  type = string
}

variable "stardog_helm_timeout" {
  description = "Timeout in seconds for Helm operations that install or upgrade the Stardog stack."
  type        = number
  default     = 300
}

variable "stardog_license_base64" {
  description = "Optional base64-encoded Stardog license content. Preferred for CI; sensitive. If set, it is used directly."
  type        = string
  default     = null
  sensitive   = true
}

variable "deploy_stardog_stack" {
  description = "Whether to deploy the Stardog stack"
  type        = bool
  default     = true
}

variable "enabled_bi_port" {
  description = "Enable the BI port for Stardog."
  type        = bool
  default     = false
}

variable "enable_cache_target" {
  description = "Enable Stardog CacheTarget service within the Helm chart."
  default = false
}

variable "stardog_chart_url" {
  description = "The chart to use to install stardog echo system"
  type        = string
}

variable "stardog_chart_version" {
  description = "The chart version to use to install stardog echo system (optional if provided in url)"
  type        = string
  default     = null
}

variable "stardog_image_tag" { 
  description = "The version of Stardog to deploy"
  type = string
}

variable "stardog_storage_class" {
  description = "StorageClass name to use for Stardog persistence (and cachetarget if enabled). Leave null to rely on the cluster default."
  type        = string
  default     = ""
}


variable "launchpad_enabled" {
  description = "Whether Launchpad is enabled or not"
  type = bool
}

variable "launchpad_image_tag" { 
  description = "The version of Launchpad to deploy"
  type = string
}

variable "voicebox_image_tag" { 
  description = "The version of Voicebox to deploy"
  type = string
}

#variable "enable_stardog_backup" {
#  description = "When true, provision Azure Blob storage for Stardog backups and configure the Helm chart to use it."
#  type        = bool
#  default     = false
#}
#
#variable "backup_storage_account_name" {
#  description = "Name of the Azure Storage Account that will store Stardog backups."
#  type        = string
#  default     = null
#}
#
#variable "backup_storage_container_name" {
#  description = "Name of the blob container used for Stardog backups."
#  type        = string
#  default     = "stardog-backups"
#}



#
#variable "app_owner_object_ids" {
#  description = "Preferred list of owner object IDs (users or service principals) for created applications. If empty, the current authenticated principal will be used by the module."
#  type        = list(string)
#  default     = []
#}
#
#variable "app_owner_upns" {
#  description = "Optional list of user principal names (UPNs / emails) to use as owners for created AAD applications. These will be resolved to object IDs at plan time and merged with app_owner_object_ids."
#  type        = list(string)
#  default     = []
#}
#
#variable "app_admin_role_group_object_id" {
#  description = "A MS Entra group to be associated with the admin role"
#  type        = string
#}
#
## Stardog license inputs: prefer passing base64 via TF_VAR_stardog_license_base64
## in CI. When running locally you may set `stardog_license_file` to point to the
## binary and the module will read and encode it.
#variable "stardog_license_file" {
#  description = "Optional local path to the Stardog license binary. Used by the env module to populate stardog_license_base64 when set."
#  type        = string
#  default     = null
#}
#
#
#variable "stardog_admin_url" {
#  description = "Base URL for the Stardog admin endpoint. Defaults to https://stardog.<ingress_dns_root> when unset."
#  type        = string
#  default     = null
#}
#
#variable "stardog_admin_username" {
#  description = "Username for the Stardog admin API."
#  type        = string
#  default     = "admin"
#}
#
#variable "stardog_admin_password" {
#  description = "Password for the Stardog admin API."
#  type        = string
#  default     = "admin"
#  sensitive   = true
#}
#
#variable "stardog_admin_tls_insecure" {
#  description = "Set true to skip TLS verification when talking to the Stardog admin endpoint."
#  type        = bool
#  default     = false
#}
#
#variable "stardog_roles" {
#  description = "Map of role_name => list of permission specs (role assignment inputs). Each element must include action, resource_type, resource, and can optionally specify state/idempotent (mirrors stardog_role_assignment spec)."
#  type = map(list(object({
#    action        = string
#    resource_type = string
#    resource      = string
#    state         = optional(string)
#    idempotent    = optional(bool)
#  })))
#  default = {}
#}
#
## Define all roles and permissions here (easy to scale to 100+)
## if the resource is an actual resource like db:name, it may be better
## to not defined the permission here, but doing a resource to resource assignment (not yet implemented)
#variable "roles" {
#  description = "Map of role_name -> list of {action, resource}"
#  type = map(list(object({
#    action   = string
#    resource = string
#  })))
#  default = {
#    admin = [
#      { action = "all", resource = "*:*" }
#    ]
#    writer = [
#      { action = "write", resource = "*:*" },
#      { action = "read", resource = "*:*" }
#    ]
#    reader = [
#      { action = "read", resource = "*:*" }
#    ]
#    backup_operators = [
#      { action = "execute ", resource = "dbms-admin:backup-all" },
#      { action = "execute ", resource = "admin:*" }
#    ]
#    monitor_operators = [
#      { action = "read ", resource = "dbms-admin:metrics" },
#      { action = "read ", resource = "metadata:*" },
#      { action = "read ", resource = "db:*" }
#    ]
#  }
#}
#
