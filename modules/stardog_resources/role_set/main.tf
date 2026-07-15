locals {
  stardog_url_trimmed   = trimsuffix(trimspace(var.stardog_url), "/")
  stardog_ready_path    = startswith(var.stardog_ready_path, "/") ? var.stardog_ready_path : "/${var.stardog_ready_path}"
  stardog_ready_url     = "${local.stardog_url_trimmed}${local.stardog_ready_path}"
  stardog_ready_url_esc = replace(local.stardog_ready_url, "'", "'\"'\"'")
  curl_tls_args         = var.stardog_insecure ? "-k" : ""

  container_env_base = merge(
    {
      STARDOG_USERNAME = var.stardog_username
      STARDOG_PASSWORD = var.stardog_password
    },
    var.stardog_insecure ? { STARDOG_INSECURE = "1" } : {},
    var.container_env_extra,
  )

  role_assignment_specs = {
    for item in flatten([
      for role_name, permissions in var.roles : [
        for perm in permissions : {
          key = format(
            "%s:%s:%s:%s",
            lower(trimspace(role_name)),
            lower(trimspace(perm.action)),
            lower(trimspace(perm.resource_type)),
            trimspace(perm.resource)
          )
          role          = role_name
          action        = perm.action
          resource_type = perm.resource_type
          resource      = perm.resource
          state         = try(perm.state, null)
          idempotent    = try(perm.idempotent, null)
        }
      ]
      ]) : item.key => {
      role          = item.role
      action        = item.action
      resource_type = item.resource_type
      resource      = item.resource
      state         = item.state
      idempotent    = item.idempotent
    }
  }
}

resource "null_resource" "wait_for_stardog" {
  count = var.deploy && var.wait_for_stardog ? 1 : 0

  triggers = {
    url      = local.stardog_ready_url
    attempts = tostring(var.stardog_ready_attempts)
    interval = tostring(var.stardog_ready_interval_seconds)
    insecure = tostring(var.stardog_insecure)
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-SCRIPT
      set -euo pipefail

      URL='${local.stardog_ready_url_esc}'
      ATTEMPTS=${var.stardog_ready_attempts}
      INTERVAL=${var.stardog_ready_interval_seconds}

      for attempt in $(seq 1 "$ATTEMPTS"); do
        if curl -fsS ${local.curl_tls_args} --connect-timeout 5 --max-time 15 "$URL" >/dev/null; then
          echo "Stardog endpoint is ready: $URL"
          exit 0
        fi
        echo "Waiting for Stardog endpoint $URL ($attempt/$ATTEMPTS)"
        sleep "$INTERVAL"
      done

      echo "Stardog endpoint did not become ready: $URL" >&2
      exit 1
    SCRIPT
  }
}

module "remove_builtin_reader" {
  count  = var.deploy && var.remove_builtin_reader ? 1 : 0
  source = "../role"

  name                       = "reader"
  state                      = "absent"
  namespace                  = var.namespace
  kubeconfig_path            = var.kubeconfig_path
  image                      = var.image
  stardog_url                = var.stardog_url
  additional_cli_args        = var.extra_cli_args
  container_env              = local.container_env_base
  local_exec_env             = var.local_exec_env
  service_account_name       = var.service_account_name
  destroy_on_deprovision     = true
  kubeconfig_refresh_command = var.kubeconfig_refresh_command
  depends_on                 = [null_resource.wait_for_stardog]
}

module "roles" {
  for_each = var.deploy ? var.roles : {}
  source   = "../role"

  name                       = each.key
  namespace                  = var.namespace
  kubeconfig_path            = var.kubeconfig_path
  image                      = var.image
  stardog_url                = var.stardog_url
  additional_cli_args        = var.extra_cli_args
  container_env              = local.container_env_base
  local_exec_env             = var.local_exec_env
  service_account_name       = var.service_account_name
  destroy_on_deprovision     = false
  depends_on                 = [null_resource.wait_for_stardog, module.remove_builtin_reader]
  kubeconfig_refresh_command = var.kubeconfig_refresh_command
}

module "assignments" {
  for_each = var.deploy ? local.role_assignment_specs : {}
  source   = "../role_assignment"

  role              = each.value.role
  action            = each.value.action
  resource_type     = each.value.resource_type
  resource          = each.value.resource
  state             = coalesce(each.value.state, "present")
  idempotent_create = coalesce(each.value.idempotent, false)

  namespace                  = var.namespace
  kubeconfig_path            = var.kubeconfig_path
  image                      = var.image
  stardog_url                = var.stardog_url
  additional_cli_args        = var.extra_cli_args
  container_env              = local.container_env_base
  local_exec_env             = var.local_exec_env
  service_account_name       = var.service_account_name
  kubeconfig_refresh_command = var.kubeconfig_refresh_command

  depends_on = [module.roles]
}
