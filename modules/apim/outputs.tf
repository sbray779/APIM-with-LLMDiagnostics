output "apim_id" {
  description = "The ID of the API Management service"
  value       = azurerm_api_management.main.id
}

output "apim_name" {
  description = "The name of the API Management service"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "The gateway URL of the API Management service"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_portal_url" {
  description = "The developer portal URL of the API Management service"
  value       = azurerm_api_management.main.developer_portal_url
}

output "apim_management_api_url" {
  description = "The management API URL of the API Management service"
  value       = azurerm_api_management.main.management_api_url
}

output "openai_api_name" {
  description = "The name of the OpenAI API in APIM"
  value       = azurerm_api_management_api.openai.name
}

output "openai_api_path" {
  description = "The path of the OpenAI API in APIM"
  value       = azurerm_api_management_api.openai.path
}

output "subscription_key" {
  description = "The primary key for the OpenAI subscription"
  value       = azurerm_api_management_subscription.openai.primary_key
  sensitive   = true
}

output "subscription_id" {
  description = "The ID of the OpenAI subscription"
  value       = azurerm_api_management_subscription.openai.id
}

output "applicationinsights_logger_id" {
  description = "The ID of the Application Insights logger"
  value       = azurerm_api_management_logger.applicationinsights.id
}

