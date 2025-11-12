# Resource Group Output
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "The Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

# Networking Outputs
output "vnet_id" {
  description = "The ID of the virtual network"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.networking.vnet_name
}

# OpenAI Outputs
output "openai_service_name" {
  description = "The name of the Azure OpenAI service"
  value       = module.openai.openai_name
}

output "openai_endpoint" {
  description = "The endpoint URL of the Azure OpenAI service"
  value       = module.openai.endpoint
}

output "gpt_deployment_name" {
  description = "The name of the GPT model deployment"
  value       = module.openai.gpt_deployment_name
}

output "embedding_deployment_name" {
  description = "The name of the embedding model deployment"
  value       = module.openai.embedding_deployment_name
}

# API Management Outputs
output "apim_service_name" {
  description = "The name of the API Management service"
  value       = module.apim.apim_name
}

output "apim_gateway_url" {
  description = "The gateway URL of the API Management service"
  value       = module.apim.apim_gateway_url
}

output "apim_portal_url" {
  description = "The developer portal URL of the API Management service"
  value       = module.apim.apim_portal_url
}

output "openai_api_url" {
  description = "The full URL to access OpenAI API through APIM"
  value       = "${module.apim.apim_gateway_url}/${module.apim.openai_api_path}"
}

output "subscription_key" {
  description = "The primary subscription key for accessing OpenAI API through APIM"
  value       = module.apim.subscription_key
  sensitive   = true
}

# Monitoring Outputs
output "log_analytics_workspace_name" {
  description = "The name of the Log Analytics workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_name" {
  description = "The name of the Application Insights instance"
  value       = module.monitoring.application_insights_name
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key of the Application Insights instance"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "eventhub_namespace_name" {
  description = "The name of the Event Hub namespace"
  value       = module.monitoring.eventhub_namespace_name
}

output "eventhub_name" {
  description = "The name of the Event Hub for APIM logging"
  value       = module.monitoring.eventhub_name
}

# Key Vault Outputs
output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Managed Identity Outputs
output "apim_identity_principal_id" {
  description = "The principal ID of the APIM managed identity"
  value       = azurerm_user_assigned_identity.apim_identity.principal_id
}

output "apim_identity_client_id" {
  description = "The client ID of the APIM managed identity"
  value       = azurerm_user_assigned_identity.apim_identity.client_id
}

# Testing Endpoints
output "test_chat_completions_url" {
  description = "URL for testing chat completions API"
  value       = "${module.apim.apim_gateway_url}/${module.apim.openai_api_path}/deployments/${module.openai.gpt_deployment_name}/chat/completions?api-version=2023-05-15"
}

output "test_completions_url" {
  description = "URL for testing completions API"
  value       = "${module.apim.apim_gateway_url}/${module.apim.openai_api_path}/deployments/${module.openai.gpt_deployment_name}/completions?api-version=2023-05-15"
}

output "test_embeddings_url" {
  description = "URL for testing embeddings API"
  value       = "${module.apim.apim_gateway_url}/${module.apim.openai_api_path}/deployments/${module.openai.embedding_deployment_name}/embeddings?api-version=2023-05-15"
}

# Connection Information
output "connection_info" {
  description = "Connection information for the deployed resources"
  value = {
    apim_gateway_url    = module.apim.apim_gateway_url
    openai_api_path     = module.apim.openai_api_path
    subscription_key    = module.apim.subscription_key
    gpt_deployment     = module.openai.gpt_deployment_name
    embedding_deployment = module.openai.embedding_deployment_name
  }
  sensitive = true
}