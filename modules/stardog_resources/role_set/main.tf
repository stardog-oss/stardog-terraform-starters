locals {
  effective_cli_args = concat(var.extra_cli_args, var.stardog_insecure ? ["--insecure-tls"] : [])

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

module "remove_builtin_reader" {
  count  = var.deploy && var.remove_builtin_reader ? 1 : 0
  source = "../role"

  name                   = "reader"
  state                  = "absent"
  namespace              = var.namespace
  kubeconfig_path        = var.kubeconfig_path
  image                  = var.image
  stardog_url            = var.stardog_url
  additional_cli_args    = local.effective_cli_args
  container_env          = local.container_env_base
  local_exec_env         = var.local_exec_env
  service_account_name   = var.service_account_name
  destroy_on_deprovision = true
  kubeconfig_refresh_command = var.kubeconfig_refresh_command
}

module "roles" {
  for_each = var.deploy ? var.roles : {}
  source   = "../role"

  name                   = each.key
  namespace              = var.namespace
  kubeconfig_path        = var.kubeconfig_path
  image                  = var.image
  stardog_url            = var.stardog_url
  additional_cli_args    = local.effective_cli_args
  container_env          = local.container_env_base
  local_exec_env         = var.local_exec_env
  service_account_name   = var.service_account_name
  destroy_on_deprovision = false
  depends_on             = [module.remove_builtin_reader]
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

  namespace            = var.namespace
  kubeconfig_path      = var.kubeconfig_path
  image                = var.image
  stardog_url          = var.stardog_url
  additional_cli_args  = local.effective_cli_args
  container_env        = local.container_env_base
  local_exec_env       = var.local_exec_env
  service_account_name = var.service_account_name
  kubeconfig_refresh_command = var.kubeconfig_refresh_command

  depends_on = [module.roles]
}
