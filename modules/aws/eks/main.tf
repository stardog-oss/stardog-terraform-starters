locals {
  tags = merge(
    {
      Name = var.cluster_name
    },
    var.tags
  )

  user_node_pool_defaults = {
    orchestrator_version = null
    auto_scaling_enabled = true
    min_count            = null
    max_count            = null
    node_count           = null
    node_taints          = []
    node_labels          = {}
    tags                 = {}
    ami_type             = null
  }

  normalized_user_node_pools = {
    for name, cfg in var.user_node_pools :
    name => merge(local.user_node_pool_defaults, cfg, {
      node_taints = [
        for t in lookup(cfg, "node_taints", []) : {
          key   = split("=", t)[0]
          value = split(":", split("=", t)[1])[0]
          effect = lookup({
            "NOSCHEDULE"       = "NO_SCHEDULE",
            "NOEXECUTE"        = "NO_EXECUTE",
            "PREFERNOSCHEDULE" = "PREFER_NO_SCHEDULE"
          }, upper(replace(split(":", t)[1], "-", "_")), upper(replace(split(":", t)[1], "-", "_")))
        }
      ]
    })
  }

  # Real bug this fixes: min/max/desired_size used to fall back to var.node_min_size/node_max_size/
  # node_desired_size when a pool left min_count/max_count/node_count unset - but those vars are the
  # DEFAULT node group's own sizing, not a per-user-pool fallback. A pool that set only
  # max_count = 2 (leaving min_count unset) inherited min_size = var.node_min_size (3 by default),
  # producing min(3) > max(2) - a genuine EKS API rejection at apply, not just a style issue. Fixed
  # by computing min_size first from pool-local values only, then constraining max/desired relative
  # to it so they're always >= it by construction - never cross-contaminated by the default pool's
  # own sizing.
  user_node_pool_min_size = {
    for name, cfg in local.normalized_user_node_pools :
    name => cfg.auto_scaling_enabled ? coalesce(cfg.min_count, cfg.node_count, 1) : cfg.node_count
  }

  user_node_pool_max_size = {
    for name, cfg in local.normalized_user_node_pools :
    name => cfg.auto_scaling_enabled ? max(
      coalesce(cfg.max_count, cfg.node_count, local.user_node_pool_min_size[name]),
      local.user_node_pool_min_size[name]
    ) : cfg.node_count
  }

  user_node_pool_desired_size = {
    for name, cfg in local.normalized_user_node_pools :
    name => cfg.auto_scaling_enabled ? min(
      max(
        coalesce(cfg.node_count, cfg.min_count, cfg.max_count, local.user_node_pool_min_size[name]),
        local.user_node_pool_min_size[name]
      ),
      local.user_node_pool_max_size[name]
    ) : cfg.node_count
  }
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS managed node group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.cluster_name}-nodes-sg" })
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  description              = "Allow worker nodes to communicate with the control plane"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_from_cluster" {
  description              = "Allow the control plane to communicate with worker nodes"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_internal" {
  description              = "Allow nodes to communicate with each other"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_additional" {
  for_each = toset(var.additional_security_group_ids)

  description              = "Allow inbound traffic from provided security groups"
  security_group_id        = aws_security_group.nodes.id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  type                     = "ingress"
  source_security_group_id = each.value
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = [var.node_instance_type]
  disk_size      = var.node_disk_size

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]
}

resource "aws_eks_node_group" "user" {
  for_each = local.normalized_user_node_pools

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [each.value.vm_size]
  disk_size       = each.value.os_disk_size_gb
  version         = each.value.orchestrator_version
  labels          = each.value.node_labels

  scaling_config {
    desired_size = local.user_node_pool_desired_size[each.key]
    min_size     = local.user_node_pool_min_size[each.key]
    max_size     = local.user_node_pool_max_size[each.key]
  }

  dynamic "taint" {
    for_each = each.value.node_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  ami_type = each.value.ami_type
  tags     = merge(local.tags, each.value.tags)

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]

  lifecycle {
    precondition {
      condition     = each.value.auto_scaling_enabled || each.value.node_count != null
      error_message = "node_count must be provided when auto_scaling_enabled is false."
    }
  }
}

data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.this.name
}

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

locals {
  oidc_issuer        = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
  oidc_provider_host = local.oidc_issuer != null ? replace(local.oidc_issuer, "https://", "") : null
  oidc_provider_arn  = var.create_iam_oidc_provider ? aws_iam_openid_connect_provider.this[0].arn : null
}

data "tls_certificate" "this" {
  // Avoid unknowns in count: gate only by variable
  count      = var.create_iam_oidc_provider ? 1 : 0
  url        = aws_eks_cluster.this.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.this]
}

resource "aws_iam_openid_connect_provider" "this" {
  // Avoid unknowns in count: gate only by variable
  count = var.create_iam_oidc_provider ? 1 : 0

  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this[0].certificates[0].sha1_fingerprint]
  tags            = local.tags
  depends_on      = [aws_eks_cluster.this]
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.cluster_name}-ebs-csi"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com",
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = local.tags

  depends_on = [aws_eks_cluster.this]

  lifecycle {
    precondition {
      condition     = var.create_iam_oidc_provider
      error_message = "enable_ebs_csi_driver requires create_iam_oidc_provider to be true."
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_ebs_csi_driver ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  service_account_role_arn    = aws_iam_role.ebs_csi[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

resource "null_resource" "ensure_kubeconfig" {
  count = var.enable_kubectl_helpers ? 1 : 0

  triggers = {
    cluster_name = aws_eks_cluster.this.name
    region       = var.aws_region
    alias        = var.cluster_name
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    # Passed via environment, not interpolated into the command string - matches the safer pattern
    # already used elsewhere in this codebase (see aws/ecr's import provisioner), avoiding quoting/
    # injection issues from a Terraform value (e.g. a cluster_name containing a `"`) landing
    # directly in command text.
    environment = {
      CLUSTER_NAME    = aws_eks_cluster.this.name
      AWS_REGION      = var.aws_region
      ALIAS           = var.cluster_name
      KUBECONFIG_PATH = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      # Expand a leading ~ to $HOME without eval - real bug this fixes: eval on an unvalidated,
      # Terraform-variable-sourced path is a genuine shell-injection surface (a kubeconfig_path
      # containing a backtick or $(...) would execute arbitrary commands here).
      RESOLVED_KUBECONFIG_PATH="$${KUBECONFIG_PATH/#\~/$HOME}"
      mkdir -p "$(dirname "$RESOLVED_KUBECONFIG_PATH")"
      aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --alias "$ALIAS" --kubeconfig "$RESOLVED_KUBECONFIG_PATH"
    EOT
  }

  depends_on = [aws_eks_cluster.this]
}
