variable "name" {
  description = "Base name used for tagging resources (e.g., <inst_id>-network)."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. Can be empty if only public subnets are needed."
  type        = list(string)
  default     = []
}

variable "create_internet_gateway" {
  description = "Whether to create and attach an Internet Gateway to the VPC."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Create a single shared NAT gateway for all private subnets."
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Provision a NAT gateway for private subnet egress. Requires at least one private subnet and public subnet."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
