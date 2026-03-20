variable "namespace" {
  description = "Namespace where NGF will be installed."
  type        = string
  default     = "nginx-gateway"
}

variable "release_name" {
  description = "Helm release name for NGF."
  type        = string
  default     = "ngf"
}

variable "chart_url" {
  description = "Helm chart reference (supports OCI or repo URLs)."
  type        = string
  default     = "oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric"
}

variable "chart_version" {
  description = "Chart version to install. Leave empty for latest."
  type        = string
  default     = "2.2.1"
}

variable "helm_atomic" {
  description = "Enable Helm atomic installs."
  type        = bool
  default     = true
}

variable "helm_wait" {
  description = "Wait for all resources to become ready before marking Helm release successful."
  type        = bool
  default     = true
}

variable "helm_cleanup_on_fail" {
  description = "Cleanup resources created by a failed Helm install."
  type        = bool
  default     = true
}

variable "helm_force_update" {
  description = "Force Helm to recreate resources even if no changes are detected."
  type        = bool
  default     = false
}

variable "helm_timeout" {
  description = "Timeout (in seconds) for Helm operations."
  type        = number
  default     = 300
}

variable "gateway_class_name" {
  description = "GatewayClass name managed by this NGF installation."
  type        = string
  default     = "nginx"
}

variable "gateway_controller_name" {
  description = "Fully-qualified controller name used by NGF."
  type        = string
  default     = "gateway.nginx.org/nginx-gateway-controller"
}

variable "nginx_gateway_replicas" {
  description = "Replica count for the NGF control plane deployment."
  type        = number
  default     = 2
}

variable "nginx_gateway_service_annotations" {
  description = "Annotations applied to the NGF control plane Service."
  type        = map(string)
  default     = {}
}

variable "nginx_gateway_service_labels" {
  description = "Labels applied to the NGF control plane Service."
  type        = map(string)
  default     = {}
}

variable "nginx_data_plane_kind" {
  description = "Kind of NGINX data plane workload (deployment or daemonSet)."
  type        = string
  default     = "deployment"
}

variable "nginx_data_plane_replicas" {
  description = "Replica count for the data plane when kind=deployment."
  type        = number
  default     = 2
}

variable "nginx_data_plane_service_type" {
  description = "Service type for the NGINX data plane."
  type        = string
  default     = "LoadBalancer"
}

variable "nginx_data_plane_external_traffic_policy" {
  description = "External traffic policy for the NGINX data plane Service."
  type        = string
  default     = "Local"
}

variable "nginx_data_plane_load_balancer_ip" {
  description = "Optional static IP for the NGINX data plane Service."
  type        = string
  default     = null
}

variable "nginx_data_plane_load_balancer_source_ranges" {
  description = "Optional list of CIDRs allowed to access the data plane load balancer."
  type        = list(string)
  default     = []
}

variable "nginx_data_plane_service_annotations" {
  description = "Annotations applied to the NGINX data plane Service."
  type        = map(string)
  default     = {}
}

variable "nginx_data_plane_service_labels" {
  description = "Labels applied to the NGINX data plane Service."
  type        = map(string)
  default     = {}
}

variable "gateways" {
  description = "Optional list of Gateway manifests to render via Helm (matches chart gateways[] structure)."
  type        = list(any)
  default     = []
}

variable "extra_values" {
  description = "Additional raw values to merge into the Helm release."
  type        = any
  default     = {}
}
