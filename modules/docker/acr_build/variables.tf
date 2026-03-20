variable "source_dir" {
  description = "Path to the Docker build context directory, relative to the root module (e.g., ../../containers/stardog-manager)."
  type        = string
}

variable "dockerfile" {
  description = "Dockerfile path relative to the context directory."
  type        = string
  default     = "Dockerfile"
}

variable "registry_name" {
  description = "Name of the Azure Container Registry (ACR)."
  type        = string
}

variable "registry_login_server" {
  description = "Login server of the Azure Container Registry (e.g., myacr.azurecr.io)."
  type        = string
}

variable "image_name" {
  description = "Repository name for the image (without tag)."
  type        = string
}

variable "tag_prefix" {
  description = "Optional prefix to include in the generated tag (e.g., environment name)."
  type        = string
  default     = null
}

variable "additional_build_args" {
  description = "Additional arguments to pass to `az acr build` (each entry is a separate argument token)."
  type        = list(string)
  default     = []
}

variable "subscription_id" {
  description = "Optional Azure subscription ID for the build command."
  type        = string
  default     = null
}

variable "include_glob" {
  description = "Glob pattern (relative to context dir) to include when computing the content hash."
  type        = string
  default     = "**"
}

variable "extra_triggers" {
  description = "Additional trigger values that should force a rebuild when changed."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment variables to pass to the local-exec provisioner."
  type        = map(string)
  default     = {}
}

variable "shell_interpreter" {
  description = "Interpreter tokens for the local-exec provisioner."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
