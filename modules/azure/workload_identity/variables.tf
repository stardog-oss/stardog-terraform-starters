variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "cluster_oidc_issuer" { type = string }
variable "namespace" { type = string }
variable "service_account" { type = string }
variable "cluster_name" { type = string }
variable "tags" {
	type    = map(string)
	default = {}
}
