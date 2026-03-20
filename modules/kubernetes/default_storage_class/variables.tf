variable "kubeconfig_path" {
  description = "Path to the kubeconfig that should be used for kubectl commands."
  type        = string
}

variable "storage_class_name" {
  description = "Name of the StorageClass that should be marked as default."
  type        = string
}

variable "enabled" {
  description = "Whether to run the logic that marks the StorageClass as default."
  type        = bool
  default     = true
}

variable "shell_interpreter" {
  description = "Interpreter tokens for the kubectl helper."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
