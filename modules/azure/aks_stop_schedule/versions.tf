terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
    }
  }
}
