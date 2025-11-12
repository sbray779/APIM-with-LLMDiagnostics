output "openai_id" {
  description = "The ID of the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_name" {
  description = "The name of the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.name
}

output "endpoint" {
  description = "The endpoint URL of the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "primary_access_key" {
  description = "The primary access key for the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "The secondary access key for the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.secondary_access_key
  sensitive   = true
}

output "gpt_deployment_name" {
  description = "The name of the GPT model deployment"
  value       = azurerm_cognitive_deployment.gpt_model.name
}

output "embedding_deployment_name" {
  description = "The name of the embedding model deployment"
  value       = azurerm_cognitive_deployment.embedding_model.name
}

output "private_endpoint_id" {
  description = "The ID of the OpenAI private endpoint"
  value       = azurerm_private_endpoint.openai.id
}