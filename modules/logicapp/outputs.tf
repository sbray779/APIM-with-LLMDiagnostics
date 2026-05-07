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
  value       = var.use_existing_log_analytics ? var.log_analytics_workspace_name : azurerm_log_analytics_workspace.logicapp[0].name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.use_existing_log_analytics ? data.azurerm_log_analytics_workspace.existing[0].id : azurerm_log_analytics_workspace.logicapp[0].id
}

output "log_analytics_workspace_workspace_id" {
  description = "Workspace ID (GUID) of the Log Analytics workspace"
  value       = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.logicapp[0].workspace_id
}

# Error Logging Outputs
output "error_workspace_name" {
  description = "Name of the error Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.errors.name
}

output "error_workspace_id" {
  description = "ID of the error Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.errors.id
}

output "error_workspace_customer_id" {
  description = "Workspace ID (GUID) of the error Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.errors.workspace_id
}

output "dce_endpoint" {
  description = "Data Collection Endpoint URL for logs ingestion"
  value       = azurerm_monitor_data_collection_endpoint.logicapp.logs_ingestion_endpoint
}

output "dce_id" {
  description = "Data Collection Endpoint ID"
  value       = azurerm_monitor_data_collection_endpoint.logicapp.id
}

output "dcr_immutable_id" {
  description = "Data Collection Rule immutable ID"
  value       = azapi_resource.logicapp_dcr.output.properties.immutableId
}

output "dcr_id" {
  description = "Data Collection Rule ID"
  value       = azapi_resource.logicapp_dcr.id
}

output "blob_connection_id" {
  description = "ID of the Azure Blob API connection (created via PowerShell script)"
  value       = local.blob_connection_id
}

output "logs_connection_id" {
  description = "ID of the Azure Monitor Logs API connection (created via PowerShell script)"
  value       = local.logs_connection_id
}