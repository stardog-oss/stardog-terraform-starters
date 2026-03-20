locals {
  formatted_format = upper(var.format)
  format_domains = {
    APT    = "apt.pkg.dev"
    DOCKER = "docker.pkg.dev"
    HELM   = "helm.pkg.dev"
    MAVEN  = "maven.pkg.dev"
    NPM    = "npm.pkg.dev"
    OCI    = "docker.pkg.dev"
    PYTHON = "python.pkg.dev"
    YUM    = "yum.pkg.dev"
  }
  registry_domain = lookup(local.format_domains, local.formatted_format, "docker.pkg.dev")
  registry_host   = "${var.location}-${local.registry_domain}"
  repository_uri  = "${local.registry_host}/${var.project_id}/${var.repository_id}"
  import_enabled  = var.import_images && length(var.images_to_import) > 0
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = local.formatted_format
  kms_key_name  = var.kms_key_name
  labels        = var.labels
}

resource "google_artifact_registry_repository_iam_binding" "this" {
  for_each = { for idx, binding in var.iam_bindings : idx => binding }

  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.this.repository_id
  role       = each.value.role
  members    = each.value.members

  dynamic "condition" {
    for_each = each.value.condition != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      description = condition.value.description
      expression  = condition.value.expression
    }
  }
}

resource "null_resource" "import" {
  count = local.import_enabled ? length(var.images_to_import) : 0

  triggers = {
    image              = element(var.images_to_import, count.index)
    repository_uri     = local.repository_uri
    source_registry    = var.source_registry_url
    source_credentials = var.source_registry_username == null ? "anon" : "auth"
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    environment = {
      IMAGE      = element(var.images_to_import, count.index)
      SRC_REG    = var.source_registry_url
      SRC_USER   = coalesce(var.source_registry_username, "")
      SRC_PASS   = coalesce(var.source_registry_password, "")
      DEST_HOST  = local.registry_host
      DEST_URI   = local.repository_uri
      PROJECT_ID = var.project_id
      REGION     = var.location
      ALLOW_ANON = var.source_registry_allow_anonymous_fallback ? "true" : "false"
    }
    command = <<-EOT
      set -euo pipefail

      if [[ -n "$SRC_USER" && -n "$SRC_PASS" ]]; then
        if echo "$SRC_PASS" | docker login "$SRC_REG" --username "$SRC_USER" --password-stdin; then
          echo "Logged in to source registry $SRC_REG as $SRC_USER"
        else
          if [[ "$ALLOW_ANON" == "true" ]]; then
            echo "Source registry login failed; continuing with anonymous pull from $SRC_REG" >&2
          else
            echo "Source registry login failed and anonymous fallback disabled." >&2
            exit 1
          fi
        fi
      elif [[ -n "$SRC_REG" ]]; then
        echo "No source credentials provided; pulling $IMAGE anonymously from $SRC_REG"
      fi

      DEST_IMAGE_PATH="$DEST_URI/$IMAGE"

      gcloud auth configure-docker "$DEST_HOST" --project "$PROJECT_ID" >/dev/null
      docker pull "${SRC_REG:+$SRC_REG/}$IMAGE"
      docker tag "${SRC_REG:+$SRC_REG/}$IMAGE" "$DEST_IMAGE_PATH"
      docker push "$DEST_IMAGE_PATH"

      docker logout "$DEST_HOST" >/dev/null 2>&1 || true
      if [[ -n "$SRC_USER" && -n "$SRC_PASS" ]]; then
        docker logout "$SRC_REG" >/dev/null 2>&1 || true
      fi
    EOT
  }
}
