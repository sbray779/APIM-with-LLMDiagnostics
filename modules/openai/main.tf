# Azure OpenAI Service
resource "azurerm_cognitive_account" "openai" {
  name                = var.openai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  
  sku_name = var.openai_sku_name
  
  # Disable public network access for security
  public_network_access_enabled = false
  
  # Custom subdomain is required for private endpoints
  custom_subdomain_name = var.openai_name
  
  tags = var.tags
}

# Role assignment for APIM managed identity
resource "azurerm_role_assignment" "apim_openai_user" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.apim_identity_principal_id
}

# GPT Model Deployment
resource "azurerm_cognitive_deployment" "gpt_model" {
  name                 = var.gpt_model_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = var.gpt_model_name
    version = var.gpt_model_version
  }
  
  sku {
    name     = "Standard"
    capacity = var.gpt_model_capacity
  }
}

# Embedding Model Deployment
resource "azurerm_cognitive_deployment" "embedding_model" {
  name                 = var.embedding_model_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }
  
  sku {
    name     = "Standard"
    capacity = var.embedding_model_capacity
  }
}

# Private Endpoint for OpenAI
resource "azurerm_private_endpoint" "openai" {
  name                = "${var.openai_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.openai_name}-psc"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }
  
  private_dns_zone_group {
    name                 = "${var.openai_name}-dns-zone-group"
    private_dns_zone_ids = [var.openai_private_dns_zone_id]
  }
  
  tags = var.tags
}