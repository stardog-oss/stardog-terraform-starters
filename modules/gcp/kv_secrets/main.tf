locals {
  default_replication = {
    automatic = lookup(var.default_replication, "automatic", true)
    locations = lookup(var.default_replication, "locations", [])
  }

  normalized_entries = {
    for name, entry in var.secrets :
    name => merge({
      labels      = lookup(entry, "labels", {})
      replication = coalesce(lookup(entry, "replication", null), local.default_replication)
      secret_id   = substr(replace(lower(format("%s-%s", coalesce(var.secret_name_prefix, var.aggregate_secret_id != null ? var.aggregate_secret_id : var.project_id), name)), "[^a-z0-9-]", "-"), 0, 255)
      value       = entry.value
    }, {})
  }

  aggregate_payload = jsonencode({
    for name, entry in local.normalized_entries :
    name => {
      value  = entry.value
      labels = entry.labels
    }
  })
}

resource "google_secret_manager_secret" "entry" {
  for_each = local.normalized_entries

  project  = var.project_id
  secret_id = each.value.secret_id
  labels    = each.value.labels

  replication {
    dynamic "automatic" {
      for_each = lookup(each.value.replication, "automatic", true) ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = lookup(each.value.replication, "automatic", true) ? [] : [each.value.replication]
      content {
        dynamic "replicas" {
          for_each = lookup(user_managed.value, "locations", [])
          content {
            location = replicas.value
          }
        }
      }
    }
  }
}

resource "google_secret_manager_secret_version" "entry" {
  for_each = local.normalized_entries

  secret      = google_secret_manager_secret.entry[each.key].name
  secret_data = each.value.value
}

resource "google_secret_manager_secret_version" "aggregate" {
  count       = var.aggregate_json && var.aggregate_secret_id != null ? 1 : 0
  secret      = var.aggregate_secret_id
  secret_data = local.aggregate_payload
}
