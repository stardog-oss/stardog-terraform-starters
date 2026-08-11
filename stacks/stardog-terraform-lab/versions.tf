terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {}

  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = ">= 3.100.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.38.0" }
    helm       = { source = "hashicorp/helm", version = ">= 3.1.0" }
  }
}

