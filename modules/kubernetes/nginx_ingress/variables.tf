variable "namespace"  {
  type = string
   default = "ingress-objects"
}
variable "replica_count" {
  type = number
  default = 2
}
variable "health_probe_path" {
  type = string
  default = "/healthz"
}

variable "enable_bi_port"    {
  type = bool
  default = false
}
variable "bi_port"           {
  type = number
  default = 5806
}
variable "stardog_namespace" {
  type = string
  default = null
}
variable "stardog_release"   {
  type = string
  default = null
}

variable "label_disable_cert_manager_validation" {
  type = bool
  default = true
}
variable "disable_admission_webhook"             {
  type = bool
  default = true
}
variable "chart_source" {
  type    = string
  default = "repo"
  validation {
    condition     = contains(["repo", "oci"], var.chart_source)
    error_message = "chart_source must be \"repo\" or \"oci\"."
  }
}
variable "chart_repo_url" {
  type = string
  default = "https://kubernetes.github.io/ingress-nginx"
}
variable "chart_name"     {
  type = string
  default = "ingress-nginx"
}
variable "chart_version"  {
  type = string
  default = null
}
variable "service_type" {
  type    = string
  default = "LoadBalancer"
  description = "Kubernetes Service type for the ingress controller (LoadBalancer, NodePort, ClusterIP)."
}
variable "oci_chart_url"     {
  type = string
  default = null
}
variable "oci_chart_version" {
  type = string
   default = null
}
variable "extra_values" {
  type = map(any)
  default = {}
}