locals {
  automation_account_name_effective                = var.existing_automation_account_name != null ? trimspace(var.existing_automation_account_name) : ""
  automation_account_resource_group_name_effective = var.existing_automation_account_resource_group_name != null ? trimspace(var.existing_automation_account_resource_group_name) : ""
  install_automation_modules                       = coalesce(var.install_automation_modules, false)
  use_powershell72                                 = lower(var.runbook_type) == "powershell72"

  runbook_clean = join("", regexall("[0-9a-z-]", lower("${var.cluster_name}-daily-stop")))
  runbook_name  = substr(local.runbook_clean, 0, 49)
  stop_times_by_id = var.daily_stop_times_by_id != null ? var.daily_stop_times_by_id : {
    for t in var.daily_stop_times : replace(t, ":", "") => t
  }
  stop_schedule_specs = {
    for schedule_id, t in local.stop_times_by_id : schedule_id => {
      time = t
      time_formatted = format(
        "%02d:%02d:00",
        tonumber(split(":", t)[0]),
        tonumber(split(":", t)[1])
      )
      schedule_name = substr(
        join("", regexall("[0-9a-z-]", lower("${var.cluster_name}-stop-daily-${schedule_id}"))),
        0,
        49
      )
    }
  }
}

resource "time_static" "schedule_anchor" {
  count = var.enabled ? 1 : 0
}

locals {
  schedule_start_date = var.enabled ? formatdate("YYYY-MM-DD", time_static.schedule_anchor[0].rfc3339) : null
}

data "external" "schedule_utc" {
  for_each = var.enabled ? local.stop_schedule_specs : {}
  program  = ["python3", "${path.module}/scripts/localtime_to_utc.py"]

  query = {
    date     = local.schedule_start_date
    time     = each.value.time_formatted
    timezone = var.schedule_timezone
  }
}

locals {
  schedule_start_times = {
    for key, value in data.external.schedule_utc : key => value.result.utc_time
  }
}

data "azurerm_automation_account" "existing" {
  count               = var.enabled ? 1 : 0
  name                = local.automation_account_name_effective
  resource_group_name = local.automation_account_resource_group_name_effective
}

locals {
  automation_account_principal_id = var.enabled ? try(data.azurerm_automation_account.existing[0].identity[0].principal_id, null) : null
  automation_account_id_effective = var.enabled ? try(data.azurerm_automation_account.existing[0].id, null) : null
}

resource "azurerm_automation_module" "az_accounts" {
  count                   = var.enabled && local.install_automation_modules && !local.use_powershell72 ? 1 : 0
  name                    = "Az.Accounts"
  resource_group_name     = local.automation_account_resource_group_name_effective
  automation_account_name = local.automation_account_name_effective

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.12.1"
  }

  depends_on = [data.azurerm_automation_account.existing]
}

resource "azurerm_automation_module" "az_aks" {
  count                   = var.enabled && local.install_automation_modules && !local.use_powershell72 ? 1 : 0
  name                    = "Az.Aks"
  resource_group_name     = local.automation_account_resource_group_name_effective
  automation_account_name = local.automation_account_name_effective

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Aks/5.2.0"
  }

  depends_on = [data.azurerm_automation_account.existing, azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_powershell72_module" "az_accounts_ps72" {
  count                 = var.enabled && local.install_automation_modules && local.use_powershell72 ? 1 : 0
  name                  = "Az.Accounts"
  automation_account_id = local.automation_account_id_effective
  tags                  = var.tags

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.12.1"
  }

  depends_on = [data.azurerm_automation_account.existing]
}

resource "azurerm_automation_powershell72_module" "az_aks_ps72" {
  count                 = var.enabled && local.install_automation_modules && local.use_powershell72 ? 1 : 0
  name                  = "Az.Aks"
  automation_account_id = local.automation_account_id_effective
  tags                  = var.tags

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Aks/5.2.0"
  }

  depends_on = [data.azurerm_automation_account.existing, azurerm_automation_powershell72_module.az_accounts_ps72]
}

resource "azurerm_automation_runbook" "stop_aks" {
  count                   = var.enabled ? 1 : 0
  name                    = local.runbook_name
  resource_group_name     = local.automation_account_resource_group_name_effective
  automation_account_name = local.automation_account_name_effective
  location                = var.location
  log_verbose             = false
  log_progress            = true
  runbook_type            = var.runbook_type
  description             = "Stops the AKS cluster if it is still running."
  content                 = file("${path.module}/scripts/stop-aks-runbook.ps1")

  depends_on = [
    azurerm_automation_module.az_accounts,
    azurerm_automation_module.az_aks,
    azurerm_automation_powershell72_module.az_accounts_ps72,
    azurerm_automation_powershell72_module.az_aks_ps72,
  ]
}

resource "azurerm_automation_schedule" "daily_stop" {
  for_each                = var.enabled ? local.stop_schedule_specs : {}
  name                    = each.value.schedule_name
  resource_group_name     = local.automation_account_resource_group_name_effective
  automation_account_name = local.automation_account_name_effective
  description             = "Daily stop of AKS at ${each.value.time} (${var.schedule_timezone})."
  frequency               = "Day"
  interval                = 1
  timezone                = var.schedule_timezone
  start_time              = local.schedule_start_times[each.key]

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "stop_aks" {
  for_each                = var.enabled ? local.stop_schedule_specs : {}
  resource_group_name     = local.automation_account_resource_group_name_effective
  automation_account_name = local.automation_account_name_effective
  runbook_name            = azurerm_automation_runbook.stop_aks[0].name
  schedule_name           = azurerm_automation_schedule.daily_stop[each.key].name

  parameters = {
    resourcegroupname = var.resource_group_name
    clustername       = var.cluster_name
  }
}

resource "azurerm_role_assignment" "automation_stop" {
  count                = var.enabled ? 1 : 0
  scope                = var.cluster_id
  role_definition_name = var.role_definition_name
  principal_id         = local.automation_account_principal_id

  lifecycle {
    precondition {
      condition     = local.automation_account_principal_id != null && trimspace(local.automation_account_principal_id) != ""
      error_message = "Automation Account must have a system-assigned identity to manage the AKS stop schedule."
    }
  }
}
