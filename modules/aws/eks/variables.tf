variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster and node groups will run."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs used by the EKS control plane and node group."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.29"
}

variable "endpoint_private_access" {
  description = "Enable private access to the Kubernetes API server endpoint."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public access to the Kubernetes API server endpoint."
  type        = bool
  default     = true
}

variable "node_instance_type" {
  description = "Instance type for the default node group."
  type        = string
  default     = "m5.large"
}

variable "node_desired_size" {
  description = "Desired number of nodes in the default node group."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of nodes in the default node group."
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of nodes in the default node group."
  type        = number
  default     = 5
}

variable "aws_region" {
  description = "AWS region where the EKS cluster resides (used for helper CLI commands such as aws eks update-kubeconfig)."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path where aws eks update-kubeconfig should write when enable_kubectl_helpers is true."
  type        = string
  default     = "~/.kube/config"
}

variable "node_disk_size" {
  description = "Disk size in GiB for nodes in the default node group."
  type        = number
  default     = 100
}

variable "user_node_pools" {
  description = <<-EOT
    Map of additional EKS managed node groups. Key = pool name.
    Each value supports:

    - vm_size (string): Instance type for this node group (e.g., m5.2xlarge).
    - os_disk_size_gb (number): Node disk size in GiB.
    - orchestrator_version (optional string): Kubernetes version for the group. Inherit cluster version when omitted.
    - auto_scaling_enabled (optional bool, default true): Enable/disable autoscaling.
    - min_count / max_count (optional numbers): Bounds when autoscaling is enabled.
    - node_count (optional number): Fixed size when autoscaling is disabled.
    - node_taints (optional list(string)): e.g., ["workload=stardog:NoSchedule"].
    - node_labels (optional map(string)): Labels applied to nodes.
    - tags (optional map(string)): Extra tags merged with module-level tags.
  EOT
  type = map(object({
    vm_size              = string
    os_disk_size_gb      = number
    orchestrator_version = optional(string)
    auto_scaling_enabled = optional(bool, true)
    min_count            = optional(number)
    max_count            = optional(number)
    node_count           = optional(number)
    node_taints          = optional(list(string), [])
    node_labels          = optional(map(string), {})
    tags                 = optional(map(string), {})
    ami_type             = optional(string)
  }))
  default = {}
}

variable "additional_security_group_ids" {
  description = "Additional security groups to associate with the worker nodes."
  type        = list(string)
  default     = []
}

variable "create_iam_oidc_provider" {
  description = "Create an IAM OIDC provider for the cluster (enables IRSA)."
  type        = bool
  default     = true
}

variable "enable_kubectl_helpers" {
  description = "Run helper CLI commands (such as aws eks update-kubeconfig) so kubectl-based submodules can target this cluster."
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Install the AWS EBS CSI driver add-on (requires IRSA)."
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "Optional AWS-managed add-on version for the EBS CSI driver (leave null for the latest compatible version)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}

variable "shell_interpreter" {
  description = "Interpreter tokens for local-exec provisioners (override on Windows if /usr/bin/env is unavailable)."
  type        = list(string)
  default     = ["/usr/bin/env", "bash", "-c"]
}
