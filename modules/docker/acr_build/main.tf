locals {
  context_abs = abspath("${path.root}/${var.source_dir}")
  files       = fileset(local.context_abs, var.include_glob)
  hash_inputs = [for f in local.files : "${f}:${filesha256("${local.context_abs}/${f}")}"]
  context_hash = sha256(join(";", local.hash_inputs))

  tag_prefix  = var.tag_prefix != null && trimspace(var.tag_prefix) != "" ? "${trimspace(var.tag_prefix)}-" : ""
  short_hash  = substr(local.context_hash, 0, 8)
  repo_path   = "terraform/${trimspace(var.image_name)}"
  image_tag   = "${local.repo_path}:${local.tag_prefix}${local.short_hash}"
  image_uri   = "${trim(var.registry_login_server, "/")}/${local.image_tag}"

  subscription_flag = var.subscription_id != null ? ["--subscription", var.subscription_id] : []
  build_args_tokens = concat(
    local.subscription_flag,
    ["--registry", var.registry_name, "--image", local.image_tag, "--file", var.dockerfile],
    var.additional_build_args
  )
  # Each token individually quoted, not joined with bare spaces - real bug this fixes: source_dir,
  # dockerfile, or any additional_build_args entry containing a space (user/pipeline-controlled
  # input) broke tokenization (wrong cd target, or an arg silently split into two words) since the
  # whole command was built as one unquoted string.
  build_args_tokens_quoted = join(" ", [for arg in local.build_args_tokens : "\"${arg}\""])
  build_command = <<-EOT
    set -euo pipefail
    cd "${local.context_abs}"
    az acr build ${local.build_args_tokens_quoted} .
  EOT
}

resource "null_resource" "build" {
  triggers = merge(
    {
      context_hash = local.context_hash
      image_tag    = local.image_tag
      registry     = var.registry_name
    },
    var.extra_triggers,
  )

  provisioner "local-exec" {
    command     = local.build_command
    interpreter = var.shell_interpreter
    environment = var.environment
  }
}
