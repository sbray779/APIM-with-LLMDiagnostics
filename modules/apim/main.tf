# API Management Service
resource "azurerm_api_management" "main" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  
  sku_name = "${var.apim_sku}_${var.apim_sku_capacity}"
  
  # Enable virtual network integration
  virtual_network_type = "External"
  
  virtual_network_configuration {
    subnet_id = var.apim_subnet_id
  }
  
  # Configure managed identity
  identity {
    type         = "UserAssigned"
    identity_ids = [var.apim_identity_id]
  }
  
  # Security configurations - disable weak cipher suites and protocols
  security {
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes128_gcm_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_gcm_sha384_ciphers_enabled      = false
    triple_des_ciphers_enabled                          = false
  }
  
  tags = var.tags
}

# Named Values for OpenAI API Key and Managed Identity Client ID
resource "azurerm_api_management_named_value" "openai_api_key" {
  name                = "openai-api-key"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "OpenAI-API-Key"
  secret              = true
  
  value_from_key_vault {
    secret_id = "${var.keyvault_uri}secrets/openai-api-key"
    identity_client_id = var.apim_identity_client_id
  }
}

resource "azurerm_api_management_named_value" "apim_client_id" {
  name                = "apim-client-id"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "APIM-Managed-Identity-Client-ID"
  secret              = true
  value               = var.apim_identity_client_id
}

# OpenAI Backend
resource "azurerm_api_management_backend" "openai" {
  name                = "openai-backend"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  protocol            = "http"
  url                 = "${var.openai_endpoint}openai/"
  description         = "Azure OpenAI Service Backend"
  
  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# Import OpenAI API specification
resource "azurerm_api_management_api" "openai" {
  name                  = "azure-openai-service-api"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "Azure OpenAI Service API"
  path                  = "openai"
  protocols             = ["https"]
  subscription_required = true
  
  import {
    content_format = "openapi+json"
    content_value = jsonencode({
      openapi = "3.0.1"
      info = {
        title   = "Azure OpenAI Service API"
        version = "2023-05-15"
      }
      servers = [
        {
          url = "https://your-resource-name.openai.azure.com/openai"
        }
      ]
      paths = {
        "/deployments/{deployment-id}/chat/completions" = {
          post = {
            operationId = "ChatCompletions_Create"
            parameters = [
              {
                name     = "deployment-id"
                in       = "path"
                required = true
                schema = {
                  type = "string"
                }
              },
              {
                name     = "api-version"
                in       = "query"
                required = true
                schema = {
                  type = "string"
                }
              }
            ]
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Success"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                    }
                  }
                }
              }
            }
          }
        }
        "/deployments/{deployment-id}/completions" = {
          post = {
            operationId = "Completions_Create"
            parameters = [
              {
                name     = "deployment-id"
                in       = "path"
                required = true
                schema = {
                  type = "string"
                }
              },
              {
                name     = "api-version"
                in       = "query"
                required = true
                schema = {
                  type = "string"
                }
              }
            ]
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Success"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                    }
                  }
                }
              }
            }
          }
        }
        "/deployments/{deployment-id}/embeddings" = {
          post = {
            operationId = "Embeddings_Create"
            parameters = [
              {
                name     = "deployment-id"
                in       = "path"
                required = true
                schema = {
                  type = "string"
                }
              },
              {
                name     = "api-version"
                in       = "query"
                required = true
                schema = {
                  type = "string"
                }
              }
            ]
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Success"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

# Product for OpenAI APIs
resource "azurerm_api_management_product" "openai" {
  product_id            = "openai"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "OpenAI"
  description           = "Azure OpenAI Service APIs"
  subscription_required = true
  approval_required     = false
  published             = true
  subscriptions_limit   = 100
}

# Associate API with Product
resource "azurerm_api_management_product_api" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.openai.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# Subscription for testing
resource "azurerm_api_management_subscription" "openai" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "OpenAI Subscription"
  product_id          = azurerm_api_management_product.openai.id
  state               = "active"
  allow_tracing       = false
}

# Event Hub Logger
resource "azurerm_api_management_logger" "eventhub" {
  name                = "openai-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  eventhub {
    name              = var.eventhub_name
    connection_string = var.eventhub_connection_string
  }
  
  description = "Event Hub logger for OpenAI requests"
}

# Application Insights Logger
resource "azurerm_api_management_logger" "applicationinsights" {
  name                = "applicationinsights"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
  
  description = "Application Insights logger for diagnostics"
}

# Diagnostic Settings for APIM to enable Gateway and GenAI logs
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                               = "apim-diagnostics"
  target_resource_id                 = azurerm_api_management.main.id
  log_analytics_workspace_id         = var.log_analytics_workspace_id
  log_analytics_destination_type     = "Dedicated"

  # API Management Gateway Logs
  enabled_log {
    category = "GatewayLogs"
  }
  
  # Generative AI Gateway Logs (LLM logs for Azure OpenAI integration)
  enabled_log {
    category = "GatewayLlmLogs"
  }
  
  # WebSocket Connection Logs (for WebSocket APIs)
  enabled_log {
    category = "WebSocketConnectionLogs"
  }
  
  # Additional useful log categories
  enabled_log {
    category = "DeveloperPortalAuditLogs"
  }
}

# API Policy for authentication and backend routing
resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <!-- Set backend service -->
        <set-backend-service backend-id="openai-backend" />
        <!-- Remove subscription key from query parameters -->
        <set-query-parameter name="subscription-key" exists-action="delete" />
        <!-- Set required headers -->
        <set-header name="api-key" exists-action="override">
            <value>{{openai-api-key}}</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}