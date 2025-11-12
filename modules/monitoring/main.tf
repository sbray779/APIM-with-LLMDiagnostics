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

# Private Endpoint for Monitor
resource "azurerm_private_endpoint" "monitor" {
  name                = "pe-monitor-${var.log_analytics_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "psc-monitor"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }
  
  private_dns_zone_group {
    name                 = "monitor-dns-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.monitor.id]
  }
  
  tags = var.tags
}

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "main" {
  name                = var.eventhub_namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  capacity            = 1
  
  # Disable public network access for security
  public_network_access_enabled = false
  
  # Enable local authentication for SAS keys (required for APIM logger)
  local_authentication_enabled = true
  
  tags = var.tags
}

# Event Hub for APIM logging
resource "azurerm_eventhub" "apim_logging" {
  name              = "apim-logging"
  namespace_id      = azurerm_eventhub_namespace.main.id
  partition_count   = var.eventhub_partition_count
  message_retention = var.eventhub_message_retention
}

# Event Hub Authorization Rule
resource "azurerm_eventhub_authorization_rule" "listen_send" {
  name         = "ListenSend"
  eventhub_name = azurerm_eventhub.apim_logging.name
  namespace_name = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  
  listen = true
  send   = true
  manage = false
}

# Private Endpoint for Event Hub
resource "azurerm_private_endpoint" "eventhub" {
  name                = "pe-eventhub-${var.eventhub_namespace_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "psc-eventhub"
    private_connection_resource_id = azurerm_eventhub_namespace.main.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }
  
  private_dns_zone_group {
    name                 = "eventhub-dns-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.eventhubs.id]
  }
  
  tags = var.tags
}

# Data sources for private DNS zones
data "azurerm_private_dns_zone" "monitor" {
  name                = "privatelink.monitor.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "eventhubs" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
}