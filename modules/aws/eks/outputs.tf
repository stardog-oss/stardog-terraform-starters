output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "nodes_security_group_id" {
  value = aws_security_group.nodes.id
}

output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  value = aws_iam_role.nodes.arn
}

output "oidc_provider_arn" {
  value       = var.create_iam_oidc_provider && length(aws_iam_openid_connect_provider.this) == 1 ? aws_iam_openid_connect_provider.this[0].arn : null
  description = "ARN of the IAM OIDC provider associated with the EKS cluster (if created)."
}

output "kubeconfig" {
  value = yamlencode({
    apiVersion = "v1"
    clusters = [{
      cluster = {
        certificate-authority-data = data.aws_eks_cluster.this.certificate_authority[0].data
        server                     = data.aws_eks_cluster.this.endpoint
      }
      name = aws_eks_cluster.this.name
    }]
    contexts = [{
      context = {
        cluster = aws_eks_cluster.this.name
        user    = aws_eks_cluster.this.name
      }
      name = aws_eks_cluster.this.name
    }]
    current-context = aws_eks_cluster.this.name
    kind            = "Config"
    preferences     = {}
    users = [{
      name = aws_eks_cluster.this.name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
        }
      }
    }]
  })
  sensitive = true
}
