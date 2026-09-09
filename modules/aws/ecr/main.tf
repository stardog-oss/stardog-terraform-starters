data "aws_region" "current" {}

locals {
  generated_repository_policy = length(var.pull_principal_arns) > 0 ? jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid       = "AllowPull"
        Effect    = "Allow"
        Principal = { AWS = var.pull_principal_arns }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy"
        ]
      }
    ]
  }) : null

  repository_policy = var.repository_policy_json != null ? var.repository_policy_json : local.generated_repository_policy

  # Extracted so it's a real, independently testable value (see tests/) rather than only visible
  # inside a provisioner's environment map. Must be delimited with /.../ to be treated as a regex at
  # all - without it, replace() does a literal substring match for the 4 characters "/.*$", which
  # never appears in a real repository URL, so this silently never stripped anything and docker
  # login/logout targeted "registry/repo-name" (an invalid host) instead of just the registry host.
  # The internal `/` (part of what we're matching, not the delimiter) is escaped so it isn't read as
  # the closer.
  dest_registry_host = replace(aws_ecr_repository.this.repository_url, "/\\/.*$/", "")
}

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete
  tags                 = var.tags

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  lifecycle {
    precondition {
      condition     = var.encryption_type != "KMS" || var.kms_key_arn != null
      error_message = "kms_key_arn must be provided when encryption_type is KMS."
    }
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.lifecycle_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.lifecycle_policy
}

resource "aws_ecr_repository_policy" "this" {
  count      = local.repository_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = local.repository_policy
}

resource "null_resource" "import" {
  # for_each over a set, not count over the list - each instance is keyed by the image string itself
  # (null_resource.import["repo/image:tag"]), not its position. Reordering, inserting, or removing an
  # entry then only affects that one entry's resource, instead of shifting every later index and
  # forcing a spurious re-import of everything after it.
  for_each = var.import_images ? toset(var.images_to_import) : []

  triggers = {
    image           = each.value
    repository      = aws_ecr_repository.this.repository_url
    source_registry = var.source_registry_url
    source_user     = var.source_registry_username == null ? "" : var.source_registry_username
  }

  provisioner "local-exec" {
    interpreter = var.shell_interpreter
    environment = {
      IMAGE     = each.value
      SRC_REG   = coalesce(var.source_registry_url, "")
      SRC_USER  = coalesce(var.source_registry_username, "")
      SRC_PASS  = coalesce(var.source_registry_password, "")
      DEST_REPO  = aws_ecr_repository.this.repository_url
      DEST_REG   = local.dest_registry_host
      AWS_REGION = data.aws_region.current.name
      ALLOW_ANON = var.source_registry_allow_anonymous_fallback ? "true" : "false"
    }
    command = <<-EOT
      set -euo pipefail
      TMP_DOCKER_CONFIG="$(mktemp -d)"
      export DOCKER_CONFIG="$TMP_DOCKER_CONFIG"
      trap 'rm -rf "$TMP_DOCKER_CONFIG"' EXIT
      cat >"$DOCKER_CONFIG/config.json" <<'JSON'
{
  "auths": {},
  "credsStore": "",
  "credHelpers": {}
}
JSON

      if [[ -n "$SRC_USER" && -n "$SRC_PASS" ]]; then
        if echo "$SRC_PASS" | docker login "$SRC_REG" --username "$SRC_USER" --password-stdin; then
          echo "Logged in to source registry: $SRC_REG as $SRC_USER"
        else
          if [[ "$ALLOW_ANON" == "true" ]]; then
            echo "Source registry login failed; falling back to anonymous pulls from $SRC_REG" >&2
          else
            echo "Source registry login failed and anonymous fallback disabled. Check credentials." >&2
            exit 1
          fi
        fi
      elif [[ -n "$SRC_REG" ]]; then
        echo "No source credentials supplied; attempting anonymous pull from $SRC_REG"
      fi

      # Login to ECR registry (not repository path)
      aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$DEST_REG"

      if [[ -n "$SRC_REG" ]]; then
        SRC_IMAGE="$SRC_REG/$IMAGE"
      else
        SRC_IMAGE="$IMAGE"
      fi

      TAG="$${IMAGE##*:}"

      TMP_MANIFEST="$(mktemp)"
      MULTIARCH_COPIED="false"
      if command -v jq >/dev/null 2>&1; then
        if docker manifest inspect "$SRC_IMAGE" >"$TMP_MANIFEST" 2>/dev/null; then
          if jq -e 'has("manifests") and (.manifests | length > 0)' "$TMP_MANIFEST" >/dev/null 2>&1; then
            if docker buildx imagetools create --help >/dev/null 2>&1; then
              echo "Detected multi-architecture manifest; mirroring all platforms via docker buildx imagetools"
              docker buildx imagetools create --tag "$DEST_REPO:$TAG" "$SRC_IMAGE"
              MULTIARCH_COPIED="true"
            else
              echo "Multi-architecture manifest detected but docker buildx is unavailable; falling back to host-architecture pull/push" >&2
            fi
          fi
        fi
        rm -f "$TMP_MANIFEST"
      else
        echo "jq not available; skipping manifest inspection and relying on host-architecture pull/push" >&2
      fi

      if [[ "$MULTIARCH_COPIED" != "true" ]]; then
        docker pull "$SRC_IMAGE"
        docker tag "$SRC_IMAGE" "$DEST_REPO:$TAG"
        docker push "$DEST_REPO:$TAG"
      fi

      docker logout "$DEST_REG"
      if [[ -n "$SRC_USER" && -n "$SRC_PASS" ]]; then
        docker logout "$SRC_REG"
      fi
    EOT
  }
}
