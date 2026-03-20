# AWS EKS Cluster

Creates an Amazon EKS cluster, managed node groups, security groups, and optional OIDC provider for IRSA.

## Features
- Sets up control plane IAM roles, security groups, and the default node group.
- Supports additional managed node groups with autoscaling, labels, taints, and tags.
- Optionally provisions IAM OIDC provider for service account federation.
- Installs the AWS EBS CSI driver add-on (tagged for ABAC) so dynamic volumes work out of the box.
- (Optional) Updates the local kubeconfig (via `aws eks update-kubeconfig`) on each apply when `enable_kubectl_helpers = true`, so kubectl-based helpers point at the cluster Terraform just created.
- Exposes kubeconfig data and helper outputs for other modules.

## Requirements
- AWS CLI v2 (`aws`) must be installed and authenticated if you enable `enable_kubectl_helpers`, because the module shells out to `aws eks update-kubeconfig` to keep the kubeconfig context in sync for kubectl-based helpers.

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | n/a | Name of the EKS cluster. |
| `vpc_id` | `string` | n/a | VPC ID for the cluster. |
| `private_subnet_ids` | `list(string)` | n/a | Subnets for control plane and node groups. |
| `kubernetes_version` | `string` | `"1.29"` | Kubernetes version for control plane. |
| `endpoint_private_access` | `bool` | `true` | Enable private API endpoint access. |
| `endpoint_public_access` | `bool` | `true` | Enable public API endpoint access. |
| `node_instance_type` | `string` | `"m5.large"` | Instance type for default node group. |
| `node_desired_size` | `number` | `3` | Desired size of default node group. |
| `node_min_size` | `number` | `3` | Minimum size of default node group. |
| `node_max_size` | `number` | `5` | Maximum size of default node group. |
| `aws_region` | `string` | n/a | AWS region where the cluster resides (used for `aws eks update-kubeconfig`). |
| `node_disk_size` | `number` | `100` | Node disk size (GiB) for default group. |
| `user_node_pools` | `map(list(object))` | `{}` | Additional managed node groups; see `variables.tf` for schema (supports overrides such as `ami_type`). |
| `additional_security_group_ids` | `list(string)` | `[]` | Extra SGs allowed to talk to worker nodes. |
| `create_iam_oidc_provider` | `bool` | `true` | Create IAM OIDC provider for IRSA. |
| `enable_kubectl_helpers` | `bool` | `false` | Run helper CLI commands (e.g., `aws eks update-kubeconfig`) so kubectl-based submodules can target this cluster. |
| `enable_ebs_csi_driver` | `bool` | `true` | Install the AWS-managed EBS CSI driver add-on. |
| `ebs_csi_driver_version` | `string` | `null` | Optional explicit EBS CSI add-on version (use `null` for latest). |
| `tags` | `map(string)` | `{}` | Tags applied to created resources. |

## Outputs
| Name | Description |
|------|-------------|
| `cluster_name` | Name of the EKS cluster. |
| `cluster_endpoint` | API server endpoint URL. |
| `cluster_ca_certificate` | Base64 CA bundle for the cluster. |
| `cluster_security_group_id` | Security group ID for control plane. |
| `nodes_security_group_id` | Security group ID for nodes. |
| `cluster_role_arn` | IAM role ARN for control plane. |
| `node_role_arn` | IAM role ARN for worker nodes. |
| `oidc_provider_arn` | ARN of IAM OIDC provider (when created). |
| `kubeconfig` | Serialized kubeconfig for use with automation (sensitive). |

## Example
```hcl
module "eks" {
  source              = "../../modules/aws/eks"
  cluster_name        = "${var.inst_id}-eks"
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  kubernetes_version  = "1.29"
  node_instance_type  = "m5.xlarge"
  node_desired_size   = 3
  node_min_size       = 3
  node_max_size       = 6

  user_node_pools = {
    stardog = {
      vm_size         = "m5.2xlarge"
      os_disk_size_gb = 128
      node_labels     = { workload = "stardog" }
      node_taints     = ["workload=stardog:NoSchedule"]
      min_count       = 1
      max_count       = 3
    }
  }

  tags = {
    environment = var.inst_id
  }
}
```
