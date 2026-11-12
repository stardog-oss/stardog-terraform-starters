mock_provider "azurerm" {
  mock_data "azurerm_automation_account" {
    defaults = {
      identity = [{ type = "SystemAssigned", identity_ids = [], principal_id = "11111111-2222-3333-4444-555555555555", tenant_id = "22222222-3333-4444-5555-666666666666" }]
    }
  }
}
mock_provider "time" {}
mock_provider "external" {
  mock_data "external" {
    defaults = { result = { utc_time = "2030-11-12T01:00:00Z" } }
  }
}
override_resource {
  target = time_static.schedule_anchor[0]
  values = { rfc3339 = "2030-11-11T12:00:00Z" }
}

variables {
  resource_group_name                             = "unit-aks-rg"
  location                                        = "westus3"
  cluster_id                                      = "/subscriptions/11111111-2222-3333-4444-555555555555/resourceGroups/unit-aks-rg/providers/Microsoft.ContainerService/managedClusters/unit-aks"
  cluster_name                                    = "unit-aks"
  existing_automation_account_name                = "unit-automation"
  existing_automation_account_resource_group_name = "unit-automation-rg"
  daily_stop_times                                = ["18:00", "23:59"]
}

run "legacy_defaults_preserve_keys_and_names" {
  command = plan
  assert {
    condition     = keys(azurerm_automation_schedule.daily_stop) == ["1800", "2359"] && azurerm_automation_schedule.daily_stop["1800"].name == "unit-aks-stop-daily-1800"
    error_message = "Legacy list inputs must preserve resource addresses and names."
  }
}

run "changed_times_preserve_identity_and_bindings" {
  command = plan
  variables {
    daily_stop_times_by_id = { "1800" = "19:00", "2359" = "00:00" }
    schedule_timezone      = "America/Chicago"
  }
  assert {
    condition     = keys(azurerm_automation_schedule.daily_stop) == ["1800", "2359"] && azurerm_automation_schedule.daily_stop["1800"].name == "unit-aks-stop-daily-1800" && azurerm_automation_job_schedule.stop_aks["2359"].schedule_name == "unit-aks-stop-daily-2359"
    error_message = "Changing local time must not rename schedules or rebind runbooks."
  }
  assert {
    condition     = data.external.schedule_utc["1800"].query.time == "19:00:00" && data.external.schedule_utc["2359"].query.time == "00:00:00" && azurerm_automation_schedule.daily_stop["1800"].timezone == "America/Chicago"
    error_message = "Stable IDs must not be interpreted as clock times."
  }
}

run "invalid_clock_time_is_rejected" {
  command = plan
  variables { daily_stop_times_by_id = { evening = "24:00" } }
  expect_failures = [var.daily_stop_times_by_id]
}
