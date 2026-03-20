variable "name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location (ignored if create=false, but validated when known)"
  type        = string
}

variable "create" {
  description = "If true, create the RG. If false, use an existing RG with the given name."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply (if create=true)"
  type        = map(string)
  default     = {}
}

variable "lock" {
  description = "Create a management lock on the RG (CanNotDelete). Only when create=true."
  type        = bool
  default     = false
}
