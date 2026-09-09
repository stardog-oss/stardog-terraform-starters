locals {
  aggregate_payload = jsonencode({
    for name, entry in var.secrets : name => {
      value        = entry.value
      content_type = lookup(entry, "content_type", null)
    }
  })

  base_secret_name = try(
    regex("arn:aws:secretsmanager:[^:]+:[^:]+:secret:(.+)", var.secret_arn)[0],
    # Same missing-delimiter bug as sanitized_entries below - without `/.../` this was a literal
    # substring match that could never fire, silently returning the ARN unstripped if the regex()
    # above ever failed to match a malformed/non-standard secret_arn.
    replace(var.secret_arn, "/arn:aws:secretsmanager:[^:]+:[^:]+:secret:/", "")
  )

  name_prefix = coalesce(var.secret_name_prefix, local.base_secret_name)

  sanitized_entries = {
    for name, entry in var.secrets : name => merge(entry, {
      # Must be delimited with `/.../` to be treated as a regex at all - without it, replace()
      # does a literal substring match (which never matches this pattern), silently skipping the
      # sanitization this line's own intent clearly calls for. The internal `/` (secret names may
      # contain path separators) must itself be escaped so it isn't read as the closing delimiter.
      secret_name = replace(format("%s/%s", local.name_prefix, name), "/[^a-zA-Z0-9\\/_+=.@-]/", "-")
    })
  }
}

resource "aws_secretsmanager_secret" "entry" {
  for_each = local.sanitized_entries

  name = each.value.secret_name

  tags = lookup(each.value, "content_type", null) != null ? {
    ContentType = each.value.content_type
  } : null
}

resource "aws_secretsmanager_secret_version" "entry" {
  for_each = local.sanitized_entries

  secret_id     = aws_secretsmanager_secret.entry[each.key].id
  secret_string = each.value.value
}

resource "aws_secretsmanager_secret_version" "aggregate" {
  count         = var.aggregate_json ? 1 : 0
  secret_id     = var.secret_arn
  secret_string = local.aggregate_payload
}

output "secret_names" {
  description = "Map of logical entry name -> Secrets Manager secret name."
  value       = { for k, v in aws_secretsmanager_secret.entry : k => v.name }
}

output "aggregate_payload" {
  description = "JSON payload written when aggregate_json = true."
  # Real leak this fixes: local.aggregate_payload embeds every entry's plaintext value, built
  # independently of aws_secretsmanager_secret_version.entry (whose own secret_string IS
  # provider-schema-sensitive) - that protection doesn't propagate to this hand-rolled local/output,
  # so without this, `terraform apply`/`output`/`show` printed every secret in clear text.
  sensitive = true
  value     = var.aggregate_json ? local.aggregate_payload : null
}
