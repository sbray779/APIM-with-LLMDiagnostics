output "logic_app_name" {
  description = "Name of the created Logic App"
  value       = azurerm_logic_app_standard.main.name
}

output "logic_app_id" {
  description = "ID of the created Logic App"
  value       = azurerm_logic_app_standard.main.id
}

output "logic_app_principal_id" {
  description = "Principal ID of the Logic App's managed identity"
  value       = azurerm_logic_app_standard.main.identity[0].principal_id
}

output "app_service_plan_id" {
  description = "ID of the created App Service Plan"
  value       = azurerm_service_plan.logicapp.id
}

output "app_service_plan_name" {
  description = "Name of the created App Service Plan"
  value       = azurerm_service_plan.logicapp.name
}

output "storage_account_name" {
  description = "Name of the storage account for Logic App data"
  value       = azurerm_storage_account.logicapp_data.name
}

output "storage_account_id" {
  description = "ID of the storage account for Logic App data"
  value       = azurerm_storage_account.logicapp_data.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.log_analytics_workspace_name != null ? var.log_analytics_workspace_name : azurerm_log_analytics_workspace.logicapp[0].name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.log_analytics_workspace_name != null ? data.azurerm_log_analytics_workspace.existing[0].id : azurerm_log_analytics_workspace.logicapp[0].id
}

output "log_analytics_workspace_workspace_id" {
  description = "Workspace ID (GUID) of the Log Analytics workspace"
  value       = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.logicapp[0].workspace_id
}

output "blob_connection_id" {
  description = "ID of the Azure Blob API connection"
  value       = azurerm_api_connection.blob.id
}

output "logs_connection_id" {
  description = "ID of the Azure Monitor Logs API connection"
  value       = azurerm_api_connection.logs.id
}