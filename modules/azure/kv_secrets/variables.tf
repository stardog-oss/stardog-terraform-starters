variable "key_vault_id" {
  description = "Target Key Vault ID."
  type        = string
}

variable "secrets" {
  description = "Map of secret name => { value, content_type? } entries to store in Key Vault."
  type = map(object({
    value        = string
    content_type = optional(string)
  }))
  default = {}
}
