variable "inst_id" {
  description = "Student sandbox id, for example serge."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription id. If null, the active Azure CLI subscription is used by the provider."
  type        = string
  default     = null
}

variable "tfstate_resource_group" {
  description = "Resource group that contains the Terraform state storage account."
  type        = string
  default     = "sd-proserv-rg"
}

variable "tfstate_storage_account" {
  description = "Storage account that contains the Terraform state blobs."
  type        = string
  default     = "sdtraining"
}

variable "tfstate_container" {
  description = "Blob container for shared infra remote state."
  type        = string
  default     = "tfstate"
}

variable "infra_state_key" {
  description = "Remote state key for the training infrastructure layer."
  type        = string
  default     = "envs/sdtraining/terraform.tfstate"
}

variable "middleware_state_key" {
  description = "Remote state key for the training middleware layer."
  type        = string
  default     = "envs/sdtraining/middleware/terraform.tfstate"
}

variable "stardog_namespace" {
  description = "Kubernetes namespace for the Stardog release."
  type        = string
  default     = "stardog"
}

variable "stardog_release" {
  description = "Helm release name."
  type        = string
  default     = "sd-stack"
}

variable "stardog_chart_url" {
  description = "Optional chart archive URL. If empty, the GitHub Pages chart archive URL is derived from stardog_chart_version."
  type        = string
  default     = ""
}

variable "stardog_chart_version" {
  description = "Umbrella chart version."
  type        = string
}

variable "stardog_image_tag" {
  description = "Stardog image tag."
  type        = string
  default     = "12.0.2"
}

variable "launchpad_image_tag" {
  description = "Launchpad image tag."
  type        = string
  default     = "v3.9.1"
}

variable "voicebox_image_tag" {
  description = "Voicebox image tag."
  type        = string
  default     = "v0.27.0"
}

variable "voicebox_bites_image_tag" {
  description = "Voicebox Bites image tag."
  type        = string
  default     = "0.3.0"
}

variable "stardog_license_base64" {
  description = "Base64-encoded Stardog license."
  type        = string
  sensitive   = true
}
