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

locals {
  # Registry-prefix detection: a "/"-separated first path segment counts as an explicit source
  # registry host only if it looks like one (has a dot, a colon, or is "localhost") - otherwise
  # it's just a Docker Hub namespace (e.g. "stardog/stardog" has no registry prefix, docker.io is
  # implied). Mirrors the parsing the old bash script did by hand, kept in Terraform now that the
  # copy itself is a real provider resource rather than a shelled-out script.
  import_source_has_registry = {
    for image in var.images_to_import : image => (
      length(regexall("^[^/]+[.:][^/]*/", image)) > 0 || startswith(image, "localhost/")
    )
  }
  import_source_registry = {
    for image, has_registry in local.import_source_has_registry :
    image => has_registry ? split("/", image)[0] : "docker.io"
  }
  import_source_path = {
    for image, has_registry in local.import_source_has_registry :
    image => has_registry ? substr(image, length(split("/", image)[0]) + 1, -1) : image
  }
  import_tag = {
    for image in var.images_to_import : image => reverse(split(":", image))[0]
  }
}

# A real, native data source for ECR's own login - no CLI, no docker login. Recomputed on every
# plan/apply since the token is short-lived (12h); always reflects the current apply, never one
# cached from an earlier run. Its value flows directly into skopeo2_copy's own destination.login_*
# arguments below (not a file) - see that resource's own comment for why that distinction matters.
data "aws_ecr_authorization_token" "this" {
  count = var.import_images ? 1 : 0
}

resource "skopeo2_copy" "import" {
  # for_each over a set, not count over the list - each instance is keyed by the image string itself
  # (skopeo2_copy.import["repo/image:tag"]), not its position. Reordering, inserting, or removing an
  # entry then only affects that one entry's resource, instead of shifting every later index and
  # forcing a spurious re-import of everything after it.
  for_each = var.import_images ? toset(var.images_to_import) : []

  # bsquare-corp/skopeo2, not abergmeier/skopeo (this repo's own earlier choice) - both vendor the
  # same containers/image/v5 library rather than shelling out to a skopeo binary, but only skopeo2
  # takes credentials as direct per-resource arguments. abergmeier's provider only reads a
  # REGISTRY_AUTH_FILE env var pointing at a file - fine for a one-shot apply, but a real failure
  # confirmed live in tofu-controller: every reconcile after the first spins up a brand-new,
  # ephemeral runner pod, and the local_file resource that wrote that file only physically runs
  # during an apply, so the very next plan's refresh (calling the resource's own read()) had no
  # file to read and failed "authentication required" - forever, on every future reconcile, even
  # though the images were already correctly copied. Computing credentials fresh as resource
  # arguments on every single plan/apply (like data.aws_ecr_authorization_token already does)
  # avoids that whole class of problem.
  source {
    image = "docker://${local.import_source_registry[each.value]}/${local.import_source_path[each.value]}"
    # Only applied to images with an explicit, non-default registry prefix (e.g. a private JFrog
    # host) - source_registry_username/password are meant for that one configured registry, not
    # blanket-applied to every image regardless of where it actually comes from. Without this
    # guard, a JFrog credential would also be sent (and likely rejected or simply wrong) when
    # pulling the plain Docker Hub images alongside it.
    login_username = local.import_source_registry[each.value] != "docker.io" ? var.source_registry_username : null
    login_password = local.import_source_registry[each.value] != "docker.io" ? var.source_registry_password : null
  }

  destination {
    image          = "docker://${aws_ecr_repository.this.repository_url}:${local.import_tag[each.value]}"
    login_username = "AWS"
    login_password = data.aws_ecr_authorization_token.this[0].password
  }
}
