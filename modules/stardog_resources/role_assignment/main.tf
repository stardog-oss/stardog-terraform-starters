locals {
  normalized_state   = lower(trimspace(var.state))
  role_trim          = trimspace(var.role)
  action_trim        = trimspace(var.action)
  action_normalized  = lower(local.action_trim)
  resource_type_trim = trimspace(var.resource_type)
  resource_trim      = trimspace(var.resource)
  idempotent_enabled = coalesce(var.idempotent_create, false)
  spec_common = {
    role          = local.role_trim
    action        = local.action_normalized
    resource_type = local.resource_type_trim
    resource      = local.resource_trim
  }
  spec_optional = merge(
    var.stardog_url != null ? { stardog_url = var.stardog_url } : {},
    local.idempotent_enabled ? { idempotent = true } : {},
    var.additional_spec_fields,
  )

  spec_present_json = jsonencode(merge(local.spec_common, { state = local.normalized_state }, local.spec_optional))
  spec_absent_json  = jsonencode(merge(local.spec_common, { state = "absent" }, local.spec_optional))

  spec_present_hash = sha256(local.spec_present_json)

  name_seed        = "${local.role_trim}-${local.action_normalized}-${local.resource_type_trim}-${local.resource_trim}"
  name_hash        = substr(sha256(local.name_seed), 0, 8)
  base_pod_name    = substr("stardog-role-assign-${local.name_hash}", 0, 40)
  pod_suffix       = substr(local.spec_present_hash, 0, 6)
  pod_name         = substr("${local.base_pod_name}-${local.pod_suffix}", 0, 56)
  pod_name_escaped = replace(local.pod_name, "'", "'\"'\"'")

  kubeconfig_raw_path   = trimspace(replace(var.kubeconfig_path, "\\", "/"))
  kubeconfig_flag       = "--kubeconfig=\"$KCFG\""
  kubeconfig_arg        = "--kubeconfig=$KCFG"
  kubeconfig_resolve_command = format("KCFG=\"$(eval echo %s)\"", local.kubeconfig_raw_path)

  namespace_escaped  = replace(var.namespace, "'", "'\"'\"'")
  image_escaped      = replace(var.image, "'", "'\"'\"'")

  base_args = [
    "kubectl",
    local.kubeconfig_arg,
    "-n",
    format("'%s'", local.namespace_escaped),
    "run",
    format("'%s'", local.pod_name_escaped),
    "--image",
    format("'%s'", local.image_escaped),
    "--restart=Never",
    "--rm",
    "--attach",
  ]

  service_account_arg = var.service_account_name != null ? [
    format("--serviceaccount='%s'", replace(var.service_account_name, "'", "'\"'\"'"))
  ] : []

  env_args = [for k, v in var.container_env : format("--env='%s'", replace(format("%s=%s", k, v), "'", "'\"'\"'"))]

  cli_args_list = concat(
    ["--spec-file=/tmp/spec.json"],
    var.skip_status ? ["--skip-status"] : [],
    local.idempotent_enabled ? ["--idempotent-create"] : [],
    var.additional_cli_args,
  )

  cli_args_quoted = [for arg in local.cli_args_list : format("'%s'", replace(arg, "'", "'\"'\"'"))]
  cli_arg_string  = join(" ", local.cli_args_quoted)

  spec_present_b64        = base64encode(local.spec_present_json)
  spec_present_b64_escape = replace(local.spec_present_b64, "'", "'\"'\"'")

  spec_absent_b64        = base64encode(local.spec_absent_json)
  spec_absent_b64_escape = replace(local.spec_absent_b64, "'", "'\"'\"'")

  ensure_script = <<-SCRIPT
    #!/bin/sh
    set -euo pipefail
    echo '${local.spec_present_b64_escape}' | base64 -d >/tmp/spec.json
    python -m stardog_ops.cli ${local.cli_arg_string}
  SCRIPT

  destroy_script = <<-SCRIPT
    #!/bin/sh
    set -euo pipefail
    echo '${local.spec_absent_b64_escape}' | base64 -d >/tmp/spec.json
    python -m stardog_ops.cli ${local.cli_arg_string}
  SCRIPT

  ensure_script_b64        = base64encode(local.ensure_script)
  ensure_script_b64_escape = replace(local.ensure_script_b64, "'", "'\"'\"'")

  destroy_script_b64        = base64encode(local.destroy_script)
  destroy_script_b64_escape = replace(local.destroy_script_b64, "'", "'\"'\"'")

  pod_run_command = join(
    " ",
    concat(
      local.base_args,
      local.service_account_arg,
      local.env_args,
      [
        "--command",
        "--",
        "/bin/sh",
        "-c",
      ],
    )
  )

  ensure_container_command = replace(
    format(
      "echo '%s' | base64 -d > /tmp/run.sh && chmod +x /tmp/run.sh && /tmp/run.sh",
      local.ensure_script_b64_escape
    ),
    "\"",
    "\\\""
  )

  destroy_container_command = replace(
    format(
      "echo '%s' | base64 -d > /tmp/run.sh && chmod +x /tmp/run.sh && /tmp/run.sh",
      local.destroy_script_b64_escape
    ),
    "\"",
    "\\\""
  )

  pod_name_safe = replace(local.pod_name, "'", "")

  ensure_run_with_logging = format(
    "(LOG_PATH=/tmp/stardog-role-%s.log; : > \"$LOG_PATH\"; set -o pipefail; %s \"%s\" 2>&1 | tee \"$LOG_PATH\"; STATUS=$${PIPESTATUS[0]}; if [ $STATUS -ne 0 ]; then echo \"stardog role helper failed (pod=%s). Log: $LOG_PATH\" >&2; cat \"$LOG_PATH\" >&2; exit $STATUS; fi; rm -f \"$LOG_PATH\")",
    local.pod_name_safe,
    local.pod_run_command,
    local.ensure_container_command,
    local.pod_name_safe,
  )

  destroy_run_with_logging = format(
    "(LOG_PATH=/tmp/stardog-role-%s-destroy.log; : > \"$LOG_PATH\"; set -o pipefail; %s \"%s\" 2>&1 | tee \"$LOG_PATH\"; STATUS=$${PIPESTATUS[0]}; if [ $STATUS -ne 0 ]; then echo \"stardog role cleanup failed (pod=%s). Log: $LOG_PATH\" >&2; cat \"$LOG_PATH\" >&2; exit $STATUS; fi; rm -f \"$LOG_PATH\")",
    local.pod_name_safe,
    local.pod_run_command,
    local.destroy_container_command,
    local.pod_name_safe,
  )

  pre_delete_command = format(
    "kubectl %s -n '%s' delete pod '%s' --grace-period=0 --force --ignore-not-found --wait=true --timeout=180s",
    local.kubeconfig_flag,
    local.namespace_escaped,
    local.pod_name_escaped,
  )

  refresh_command = trimspace(coalesce(var.kubeconfig_refresh_command, ""))
  refresh_parts   = length(local.refresh_command) > 0 ? [local.refresh_command] : []
  kubeconfig_parts = [local.kubeconfig_resolve_command]

  kubeconfig_check_command = "if [ ! -s \"$KCFG\" ]; then echo \"Kubeconfig file missing or empty: $KCFG\" >&2; exit 1; fi"

  kubeconfig_ready_command = format(
    "ready=0; for attempt in $(seq 1 20); do if kubectl %s api-resources >/dev/null 2>&1; then ready=1; break; fi; echo \"Waiting for Kubernetes API discovery... ($attempt/20)\"; sleep 10; done; if [ \"$ready\" -ne 1 ]; then echo \"Kubernetes API discovery failed after multiple attempts; cluster is not ready yet.\" >&2; exit 1; fi",
    local.kubeconfig_flag,
  )

  ensure_command  = join(" && ", concat(local.kubeconfig_parts, local.refresh_parts, [local.kubeconfig_check_command, local.kubeconfig_ready_command, "${local.pre_delete_command} && ${local.ensure_run_with_logging}"]))

  destroy_wrapper = format(
    "if kubectl %s get namespace '%s' >/dev/null 2>&1; then %s; else echo \"Namespace %s not found; skipping role assignment cleanup\"; fi",
    local.kubeconfig_flag,
    local.namespace_escaped,
    "${local.pre_delete_command} && ${local.destroy_run_with_logging}",
    local.namespace_escaped,
  )

  destroy_command = join(" && ", concat(local.kubeconfig_parts, local.refresh_parts, [local.destroy_wrapper]))
  destroy_command_effective = var.destroy_on_deprovision ? local.destroy_command : "true"
}

resource "null_resource" "assignment" {
  triggers = {
    spec_hash       = local.spec_present_hash
    image           = var.image
    namespace       = var.namespace
    kubeconfig      = var.kubeconfig_path
    ensure_command  = local.ensure_command
    destroy_command = local.destroy_command_effective
    local_exec_env  = jsonencode(var.local_exec_env)
  }

  provisioner "local-exec" {
    when        = create
    command     = self.triggers.ensure_command
    interpreter = var.shell_interpreter
    environment = jsondecode(self.triggers.local_exec_env)
  }

  provisioner "local-exec" {
    when        = destroy
    command     = self.triggers.destroy_command
    environment = jsondecode(self.triggers.local_exec_env)
  }
}
