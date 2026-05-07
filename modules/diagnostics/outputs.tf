output "apim_service_diagnostics_id" {
  description = "The ID of the APIM service diagnostics"
  value       = azapi_resource.apim_service_diagnostics.id
}

output "openai_api_diagnostics_id" {
  description = "The ID of the OpenAI API diagnostics"
  value       = azapi_resource.openai_api_diagnostics.id
}

output "openai_api_azure_monitor_diagnostics_id" {
  description = "The ID of the OpenAI API Azure Monitor diagnostics with LLM logging"
  value       = azapi_resource.openai_api_azure_monitor_diagnostics.id
}

output "apim_gateway_logs_dcr_id" {
  description = "The ID of the workspace transformation DCR for ApiManagementGatewayLogs"
  value       = azurerm_monitor_data_collection_rule.apim_gateway_logs_transform.id
}