output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "The name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "application_insights_id" {
  description = "The ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "application_insights_name" {
  description = "The name of the Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key of the Application Insights instance"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "The connection string of the Application Insights instance"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "eventhub_namespace_id" {
  description = "The ID of the Event Hub namespace"
  value       = azurerm_eventhub_namespace.main.id
}

output "eventhub_namespace_name" {
  description = "The name of the Event Hub namespace"
  value       = azurerm_eventhub_namespace.main.name
}

output "eventhub_id" {
  description = "The ID of the Event Hub"
  value       = azurerm_eventhub.apim_logging.id
}

output "eventhub_name" {
  description = "The name of the Event Hub"
  value       = azurerm_eventhub.apim_logging.name
}

output "eventhub_connection_string" {
  description = "The connection string for the Event Hub"
  value       = azurerm_eventhub_authorization_rule.listen_send.primary_connection_string
  sensitive   = true
}