locals {
  default_replication = {
    automatic = true
    locations = []
  }

  effective_replication = merge(
    local.default_replication,
    {
      automatic = var.replication.automatic
      locations = coalesce(var.replication.locations, [])
    }
  )
}

resource "google_secret_manager_secret" "this" {
  project  = var.project_id
  secret_id = var.secret_id
  labels    = var.labels

  replication {
    dynamic "automatic" {
      for_each = local.effective_replication.automatic ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = local.effective_replication.automatic ? [] : [local.effective_replication]
      content {
        dynamic "replicas" {
          for_each = user_managed.value.locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }
}

resource "google_secret_manager_secret_iam_binding" "this" {
  for_each = { for idx, binding in var.iam_bindings : idx => binding }

  project = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role    = each.value.role
  members = each.value.members

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = condition.value.description
      expression  = condition.value.expression
    }
  }
}
