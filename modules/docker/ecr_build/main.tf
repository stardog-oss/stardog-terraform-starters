locals {
  context_abs  = abspath("${path.root}/${var.source_dir}")
  files        = fileset(local.context_abs, var.include_glob)
  hash_inputs  = [for f in local.files : "${f}:${filesha256("${local.context_abs}/${f}")}"]
  context_hash = sha256(join(";", local.hash_inputs))

  tag_prefix = var.tag_prefix != null && trimspace(var.tag_prefix) != "" ? "${trimspace(var.tag_prefix)}-" : ""
  short_hash = substr(local.context_hash, 0, 8)

  registry_host   = split("/", var.repository_url)[0]
  repository_path = join("/", slice(split("/", var.repository_url), 1, length(split("/", var.repository_url))))
  image_uri       = "${var.repository_url}:${local.tag_prefix}${local.short_hash}"

  docker_build_args = concat([
    "build",
    "-t", local.image_uri,
    "-f", var.dockerfile
  ], var.build_args, ["."])

  # Each token individually quoted, not joined with bare spaces - real bug this fixes: source_dir,
  # dockerfile, or any build_args entry containing a space (user/pipeline-controlled input) broke
  # tokenization (wrong cd target, or a build arg silently split into two words) since the whole
  # command was built as one unquoted string.
  docker_build_args_quoted = join(" ", [for arg in local.docker_build_args : "\"${arg}\""])

  login_command = <<-EOT
    aws ecr get-login-password --region "${var.aws_region}" | docker login --username AWS --password-stdin "${local.registry_host}"
  EOT

  platform_export = var.target_platform != null ? "export DOCKER_DEFAULT_PLATFORM='${var.target_platform}'" : ""

  build_push_command = <<-EOT
    set -euo pipefail
    cd "${local.context_abs}"
    ${local.login_command}
    ${local.platform_export}
    docker ${local.docker_build_args_quoted}
    docker push "${local.image_uri}"
    docker logout "${local.registry_host}" >/dev/null 2>&1 || true
  EOT
}

resource "null_resource" "build" {
  triggers = merge(
    {
      context_hash = local.context_hash
      image_uri    = local.image_uri
      repository   = var.repository_url
      # coalesce() requires at least one non-null AND non-empty-string argument - coalesce(x, "")
      # always errors when x is null, since "" doesn't count as a valid fallback either (same
      # coalesce() misuse bug already found and fixed elsewhere in this project). Only actually
      # surfaced once target_platform's own default was corrected from "linux/amd64" to null.
      platform = var.target_platform != null ? var.target_platform : ""
    },
    var.extra_triggers,
  )

  provisioner "local-exec" {
    command     = local.build_push_command
    interpreter = var.shell_interpreter
    environment = var.environment
  }
}
