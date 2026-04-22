terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = ">= 3.100.0" }
    azuread    = { source = "hashicorp/azuread", version = ">= 3.0.0" }
    random     = { source = "hashicorp/random", version = ">= 3.6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.38.0" }
    helm       = { source = "hashicorp/helm", version = ">= 3.1.0" }
    time       = { source = "hashicorp/time", version = "~> 0.11" }
    # azapi removed; use azurerm_log_analytics_solution instead
  }
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
provider "azuread" {}
