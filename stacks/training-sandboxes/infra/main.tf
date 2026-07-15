provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

data "terraform_remote_state" "bootstrap" {
  count   = var.enable_aks_stop_schedule ? 1 : 0
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate"
    key                  = "envs/bootstrap/terraform.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  prefix = trim(lower(replace(var.name_prefix, "/[^a-z0-9-]/", "-")), "-")

  students = {
    for id, s in var.students : id => {
      email                      = s.email
      cc                         = s.cc != null ? trimspace(s.cc) : ""
      aks_stop_daily_times       = s.aks_stop_daily_times
      aks_stop_schedule_timezone = s.aks_stop_schedule_timezone != null && trimspace(s.aks_stop_schedule_timezone) != "" ? trimspace(s.aks_stop_schedule_timezone) : null
      slug                       = lower(replace(id, "/[^a-z0-9]/", ""))
      slug_dash                  = trim(lower(replace(id, "/[^a-z0-9-]/", "-")), "-")
    }
  }

  tfstate_container_raw = coalesce(var.student_tfstate_container_name, "${local.prefix}-tfstate")
  tfstate_container_name = replace(
    trim(
      lower(replace(local.tfstate_container_raw, "/[^a-z0-9-]/", "-")),
      "-"
    ),
    "/-+$/",
    ""
  )

  tfstate_group_name_raw = coalesce(var.student_tfstate_group_name, "${local.prefix}-tfstate-writers")
  tfstate_group_name     = trim(local.tfstate_group_name_raw, " ")
  tfstate_mail_nickname = substr(
    replace(lower(local.tfstate_group_name_raw), "/[^a-z0-9-]/", ""),
    0,
    64
  )

  invite_redirect_url = var.invite_redirect_url != "" ? var.invite_redirect_url : "https://portal.azure.com/?tenantId=${var.tenant_id}"

  dns_enabled = var.create_student_dns_records && var.dns_zone_name != null && var.dns_zone_resource_group != null

  bootstrap_outputs = var.enable_aks_stop_schedule ? try(data.terraform_remote_state.bootstrap[0].outputs, {}) : {}
  aks_stop_automation_account_name_effective = (
    var.aks_stop_automation_account_name != null && trimspace(var.aks_stop_automation_account_name) != ""
  ) ? trimspace(var.aks_stop_automation_account_name) : try(local.bootstrap_outputs.automation_account_name, null)
  aks_stop_automation_account_rg_effective = (
    var.aks_stop_automation_account_resource_group_name != null && trimspace(var.aks_stop_automation_account_resource_group_name) != ""
  ) ? trimspace(var.aks_stop_automation_account_resource_group_name) : try(local.bootstrap_outputs.resource_group_name, null)

  common_tags = merge(var.tags, { name_prefix = local.prefix })
}

data "azurerm_dns_zone" "students" {
  count               = local.dns_enabled ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

data "azurerm_storage_account" "tfstate" {
  name                = var.tfstate_storage_account_name
  resource_group_name = var.tfstate_resource_group_name
}

resource "azurerm_storage_container" "student_tfstate" {
  count = var.create_student_tfstate_container ? 1 : 0

  name                  = local.tfstate_container_name
  storage_account_id    = data.azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azuread_group" "tfstate_writers" {
  count = var.create_student_tfstate_group ? 1 : 0

  display_name     = local.tfstate_group_name
  mail_nickname    = local.tfstate_mail_nickname
  security_enabled = true
}

resource "random_id" "name_suffix" {
  for_each    = local.students
  byte_length = 2

  keepers = {
    inst_id = each.key
  }
}

resource "random_id" "acr_shared_suffix" {
  byte_length = 2
}

resource "azurerm_resource_group" "rg" {
  for_each = local.students

  name     = trim(substr("${local.prefix}-${local.students[each.key].slug_dash}-rg", 0, 90), "-")
  location = var.location
  tags     = merge(local.common_tags, { student = each.key })
}

resource "azurerm_resource_group" "shared" {
  name     = trim(substr("${local.prefix}-shared-rg", 0, 90), "-")
  location = var.location
  tags     = merge(local.common_tags, { scope = "shared" })
}

resource "azuread_invitation" "student" {
  for_each = var.invite_students ? local.students : {}

  user_email_address = each.value.email
  redirect_url       = local.invite_redirect_url
}

locals {
  student_principal_ids = var.invite_students ? { for k in keys(local.students) : k => azuread_invitation.student[k].user_id } : var.student_object_ids
}

resource "azurerm_role_assignment" "student_rg_contributor" {
  for_each = local.students

  scope                = azurerm_resource_group.rg[each.key].id
  role_definition_name = var.student_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "student_acr_push_group" {
  count = var.create_student_tfstate_group ? 1 : 0

  scope                = module.acr_shared.id
  role_definition_name = var.student_acr_role_definition_name
  principal_id         = azuread_group.tfstate_writers[0].object_id
}

resource "azurerm_role_assignment" "student_acr_reader_group" {
  count = var.create_student_tfstate_group ? 1 : 0

  scope                = module.acr_shared.id
  role_definition_name = var.student_acr_reader_role_definition_name
  principal_id         = azuread_group.tfstate_writers[0].object_id
}

resource "azurerm_role_assignment" "student_acr_push_user" {
  for_each = var.create_student_tfstate_group ? {} : local.students

  scope                = module.acr_shared.id
  role_definition_name = var.student_acr_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "student_acr_reader_user" {
  for_each = var.create_student_tfstate_group ? {} : local.students

  scope                = module.acr_shared.id
  role_definition_name = var.student_acr_reader_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_public_ip" "student" {
  for_each = local.students

  name                = trim(substr("${local.prefix}-${local.students[each.key].slug_dash}-pip", 0, 80), "-")
  resource_group_name = azurerm_resource_group.rg[each.key].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = var.public_ip_sku
  tags                = merge(local.common_tags, { student = each.key })
}

module "aks" {
  for_each = local.students

  source              = "./modules/azure/aks"
  subscription_id     = var.subscription_id
  resource_group_name = azurerm_resource_group.rg[each.key].name
  location            = var.location
  name                = trim(substr("${local.prefix}-${local.students[each.key].slug_dash}-aks", 0, 63), "-")

  system_os_disk_size_gb = var.system_os_disk_size_gb
  system_count           = var.system_count
  system_vm_size         = var.system_vm_size
  user_node_pools        = var.user_node_pools

  create_log_analytics      = var.aks_create_log_analytics
  enable_nodeport_nsg_rules = false

  kubeconfig_path = "${path.module}/kubeconfigs/${each.key}.yaml"
  tags            = merge(local.common_tags, { student = each.key })
}

locals {
  acr_shared_base      = replace(lower("${var.acr_prefix}${local.prefix}shared"), "/[^a-z0-9]/", "")
  acr_shared_base_trim = substr(local.acr_shared_base, 0, 50 - length(random_id.acr_shared_suffix.hex))
  acr_shared_name      = "${local.acr_shared_base_trim}${random_id.acr_shared_suffix.hex}"
}

module "acr_shared" {
  source                   = "./modules/azure/acr"
  resource_group_name      = azurerm_resource_group.shared.name
  location                 = var.location
  acr_name                 = local.acr_shared_name
  acr_sku                  = var.acr_sku
  acr_admin_enabled        = var.acr_admin_enabled
  cluster                  = { for k, m in module.aks : k => { kubelet_object_id = m.kubelet_object_id } }
  import_images            = var.import_images
  images_to_import         = var.images_to_import
  import_charts            = var.import_charts
  charts_to_import         = var.charts_to_import
  jfrog_registry_username  = var.jfrog_registry_username
  jfrog_registry_password  = var.jfrog_registry_password
  source_registry_username = var.source_registry_username
  source_registry_password = var.source_registry_password
  tags                     = merge(local.common_tags, { scope = "shared" })
}

module "akv" {
  for_each = local.students

  source              = "./modules/azure/akv"
  resource_group_name = azurerm_resource_group.rg[each.key].name
  location            = var.location
  name = replace(
    substr(
      trim(
        lower(
          replace(
            "akv-${local.prefix}-${local.students[each.key].slug_dash}-${random_id.name_suffix[each.key].hex}",
            "/[^a-z0-9-]/",
            ""
          )
        ),
        "-"
      ),
      0,
      24
    ),
    "/-+$/",
    ""
  )
  tags = merge(local.common_tags, { student = each.key })
}

resource "azurerm_role_assignment" "student_key_vault_secrets" {
  for_each = local.students

  scope                = module.akv[each.key].id
  role_definition_name = var.student_key_vault_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "student_key_vault_keys" {
  for_each = local.students

  scope                = module.akv[each.key].id
  role_definition_name = var.student_key_vault_key_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "student_key_vault_certificates" {
  for_each = local.students

  scope                = module.akv[each.key].id
  role_definition_name = var.student_key_vault_certificate_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "student_aks_role" {
  for_each = var.aks_role_definition_name == null ? {} : local.students

  scope                = module.aks[each.key].cluster_id
  role_definition_name = var.aks_role_definition_name
  principal_id         = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "aks_pip_network_contributor" {
  for_each = local.students

  scope                = azurerm_public_ip.student[each.key].id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks[each.key].cluster_identity_principal_id
}

module "aks_stop_schedule" {
  for_each = local.students

  source = "./modules/azure/aks_stop_schedule"

  enabled             = var.enable_aks_stop_schedule
  resource_group_name = azurerm_resource_group.rg[each.key].name
  location            = var.location
  cluster_id          = module.aks[each.key].cluster_id
  cluster_name        = module.aks[each.key].name

  daily_stop_times                                = coalesce(each.value.aks_stop_daily_times, var.aks_stop_daily_times)
  schedule_timezone                               = coalesce(each.value.aks_stop_schedule_timezone, var.aks_stop_schedule_timezone)
  role_definition_name                            = var.aks_stop_role_definition_name
  runbook_type                                    = var.aks_stop_runbook_type
  existing_automation_account_name                = local.aks_stop_automation_account_name_effective
  existing_automation_account_resource_group_name = local.aks_stop_automation_account_rg_effective
  install_automation_modules                      = var.aks_stop_install_automation_modules
  tags                                            = merge(local.common_tags, { student = each.key })
}

resource "azuread_group_member" "tfstate_writers" {
  for_each = var.create_student_tfstate_group ? local.students : {}

  group_object_id  = azuread_group.tfstate_writers[0].object_id
  member_object_id = local.student_principal_ids[each.key]
}

resource "azurerm_role_assignment" "tfstate_container_access" {
  count = var.create_student_tfstate_group ? 1 : 0

  scope                = "${data.azurerm_storage_account.tfstate.id}/blobServices/default/containers/${local.tfstate_container_name}"
  role_definition_name = var.student_tfstate_role_definition_name
  principal_id         = azuread_group.tfstate_writers[0].object_id

  depends_on = [azurerm_storage_container.student_tfstate]
}

resource "azurerm_dns_a_record" "student_wildcard" {
  for_each = local.dns_enabled ? local.students : {}

  name                = "*.${each.value.slug_dash}"
  zone_name           = data.azurerm_dns_zone.students[0].name
  resource_group_name = data.azurerm_dns_zone.students[0].resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [azurerm_public_ip.student[each.key].ip_address]
}

resource "azurerm_dns_a_record" "student_root" {
  for_each = local.dns_enabled && var.create_student_dns_root_record ? local.students : {}

  name                = each.value.slug_dash
  zone_name           = data.azurerm_dns_zone.students[0].name
  resource_group_name = data.azurerm_dns_zone.students[0].resource_group_name
  ttl                 = var.dns_record_ttl
  records             = [azurerm_public_ip.student[each.key].ip_address]
}
