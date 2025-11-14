# Data sources for the Logic App module

data "azurerm_subscription" "current" {}

data "azurerm_managed_api" "blob" {
  name     = "azureblob"
  location = var.location
}

data "azurerm_managed_api" "logs" {
  name     = "azuremonitorlogs"
  location = var.location
}

data "azurerm_log_analytics_workspace" "existing" {
  count               = var.log_analytics_workspace_name != null ? 1 : 0
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}