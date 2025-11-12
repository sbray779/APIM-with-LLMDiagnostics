terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.9.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}