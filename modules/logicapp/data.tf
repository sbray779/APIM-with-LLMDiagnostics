# Data sources for the Logic App module

data "azurerm_subscription" "current" {}

# Note: azurerm_managed_api data sources removed because V2 API connections
# are created via PowerShell script instead of Terraform (see create-api-connections.ps1)

data "azurerm_log_analytics_workspace" "existing" {
  count               = var.use_existing_log_analytics ? 1 : 0
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}