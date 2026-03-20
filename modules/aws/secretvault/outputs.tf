output "secret_arn" {
  value = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.this.name
}

output "kms_key_arn" {
  value = local.kms_key_arn_effective
}
