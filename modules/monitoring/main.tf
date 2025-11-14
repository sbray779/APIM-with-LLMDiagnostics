# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  # Disable public network access for security
  internet_ingestion_enabled = false
  internet_query_enabled     = true

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  # Disable public network access for security
  internet_ingestion_enabled = false
  internet_query_enabled     = true

  tags = var.tags
}

# Private Link Scope for Monitor
resource "azurerm_monitor_private_link_scope" "main" {
  name                = "pls-monitor-${var.log_analytics_name}"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Associate Log Analytics with Private Link Scope
resource "azurerm_monitor_private_link_scoped_service" "log_analytics" {
  name                = "pls-log-analytics"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

# Associate Application Insights with Private Link Scope
resource "azurerm_monitor_private_link_scoped_service" "app_insights" {
  name                = "pls-app-insights"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_application_insights.main.id
}



