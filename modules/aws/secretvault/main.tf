data "aws_caller_identity" "current" {}

locals {
  account_root_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

  kms_admin_principals = concat([local.account_root_arn], var.admin_principal_arns)

  kms_policy_statements = [for principal in local.kms_admin_principals : {
    Sid       = "Allow-${replace(principal, ":", "-")}"
    Effect    = "Allow"
    Principal = { AWS = principal }
    Action    = "kms:*"
    Resource  = "*"
  }]

  kms_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.kms_policy_statements
  })
}

resource "aws_kms_key" "this" {
  count                   = var.create_kms_key ? 1 : 0
  description             = "KMS key for ${var.name} secrets"
  deletion_window_in_days = 30
  policy                  = local.kms_policy
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  count         = var.create_kms_key && var.kms_key_alias != null ? 1 : 0
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.this[0].key_id
}

locals {
  kms_key_arn_effective = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
}

resource "aws_secretsmanager_secret" "this" {
  name                    = var.name
  description             = var.description
  kms_key_id              = local.kms_key_arn_effective
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Either set create_kms_key = true or provide kms_key_arn."
    }
  }
}

locals {
  generated_secret_policy = var.secret_policy_json != null ? null : jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "AccountRootFullAccess"
          Effect    = "Allow"
          Principal = { AWS = local.account_root_arn }
          Action    = "secretsmanager:*"
          Resource  = aws_secretsmanager_secret.this.arn
        }
      ],
      length(var.read_principal_arns) > 0 ? [{
        Sid       = "AllowRead"
        Effect    = "Allow"
        Principal = { AWS = var.read_principal_arns }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      }] : [],
      length(var.write_principal_arns) > 0 ? [{
        Sid       = "AllowWrite"
        Effect    = "Allow"
        Principal = { AWS = var.write_principal_arns }
        Action = [
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      }] : []
    )
  })

  secret_policy = var.secret_policy_json != null ? var.secret_policy_json : local.generated_secret_policy
}

resource "aws_secretsmanager_secret_policy" "this" {
  count      = local.secret_policy != null ? 1 : 0
  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = local.secret_policy
}
