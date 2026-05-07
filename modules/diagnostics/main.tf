# Get current subscription ID
data "azurerm_subscription" "current" {}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Create APIM service diagnostics using azapi provider for LLM logging
resource "azapi_resource" "apim_service_diagnostics" {
  type      = "Microsoft.ApiManagement/service/diagnostics@2025-03-01-preview"
  name      = "applicationinsights"
  parent_id = var.apim_id

  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  body = {
    properties = {
      alwaysLog               = "allErrors"
      httpCorrelationProtocol = "Legacy"
      verbosity               = "information"
      logClientIp             = true
      loggerId                = var.applicationinsights_logger_id
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }
      frontend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
        }
        response = {
          headers = ["x-ms-spillover-from-deployment"]
          body = {
            bytes = 0
          }
        }
      }
      backend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
        }
        response = {
          headers = []
          body = {
            bytes = 0
          }
        }
      }
    }
  }
}

# Create API-level diagnostics for the OpenAI API with data masking
resource "azapi_resource" "openai_api_diagnostics" {
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2025-03-01-preview"
  name      = "applicationinsights"
  parent_id = "${var.apim_id}/apis/${var.openai_api_name}"

  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  body = {
    properties = {
      alwaysLog               = "allErrors"
      httpCorrelationProtocol = "W3C"
      verbosity               = "verbose"
      logClientIp             = true
      loggerId                = var.applicationinsights_logger_id
      metrics                 = true
      operationNameFormat     = "Name"
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }
      frontend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
          dataMasking = {
            queryParams = [
              {
                value = "*"
                mode  = "Mask"
              }
            ]
            headers = [
              {
                value = "Authorization"
                mode  = "Mask"
              },
              {
                value = "api-key"
                mode  = "Mask"
              },
              {
                value = "Ocp-Apim-Subscription-Key"
                mode  = "Mask"
              }
            ]
          }
        }
        response = {
          headers = ["x-ms-spillover-from-deployment"]
          body = {
            bytes = 0
          }
        }
      }
      backend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
          dataMasking = {
            queryParams = [
              {
                value = "*"
                mode  = "Mask"
              }
            ]
            headers = [
              {
                value = "Authorization"
                mode  = "Mask"
              },
              {
                value = "api-key"
                mode  = "Mask"
              }
            ]
          }
        }
        response = {
          headers = []
          body = {
            bytes = 0
          }
        }
      }
    }
  }
}
# Note: Azure Monitor logger already exists and will be referenced by resource ID

# Create Azure Monitor diagnostics for OpenAI API with LLM logging enabled
resource "azapi_resource" "openai_api_azure_monitor_diagnostics" {
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2025-03-01-preview"
  name      = "azuremonitor"
  parent_id = "${var.apim_id}/apis/${var.openai_api_name}"

  schema_validation_enabled = false

  body = {
    properties = {
      alwaysLog   = "allErrors"
      verbosity   = "information"
      logClientIp = true
      loggerId    = "${var.apim_id}/loggers/azuremonitor"
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }

      # LLM Logging - captures full prompts and responses (max 131072 bytes each)
      llmLogging = {
        request = {
          maxPromptTokens = 131072
        }
        response = {
          maxResponseTokens = 131072
        }
      }

      frontend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
          dataMasking = {
            queryParams = [
              {
                value = "*"
                mode  = "Mask"
              }
            ]
            headers = [
              {
                value = "Authorization"
                mode  = "Mask"
              },
              {
                value = "api-key"
                mode  = "Mask"
              },
              {
                value = "Ocp-Apim-Subscription-Key"
                mode  = "Mask"
              }
            ]
          }
        }
        response = {
          headers = ["x-ms-spillover-from-deployment"]
          body = {
            bytes = 0
          }
        }
      }
      backend = {
        request = {
          headers = []
          body = {
            bytes = 0
          }
          dataMasking = {
            queryParams = [
              {
                value = "*"
                mode  = "Mask"
              }
            ]
            headers = [
              {
                value = "Authorization"
                mode  = "Mask"
              },
              {
                value = "api-key"
                mode  = "Mask"
              }
            ]
          }
        }
        response = {
          headers = []
          body = {
            bytes = 0
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Workspace Transformation DCR to strip request/response body content
# from ApiManagementGatewayLogs for security (prevents LLM content logging)
# ---------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "apim_gateway_logs_transform" {
  name                = "dcr-apim-gateway-logs-transform"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "WorkspaceTransforms"

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "logAnalyticsDestination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Table-ApiManagementGatewayLogs"]
    destinations = ["logAnalyticsDestination"]
    # Strip body content from logs to prevent sensitive LLM data exposure
    # Usage metrics are preserved in ResponseHeaders via X-Prompt-Tokens, X-Completion-Tokens, etc.
    transform_kql = <<-EOT
      source
      | extend ResponseBody = ""
      | extend RequestBody = ""
      | extend BackendResponseBody = ""
      | extend BackendRequestBody = ""
    EOT
  }

  tags = merge(var.tags, {
    Purpose = "Strip LLM content from ApiManagementGatewayLogs"
  })
}

# ---------------------------------------------------------------------------
# Workspace Transformation DCR to strip RequestMessages and ResponseMessages
# from ApiManagementGatewayLlmLogs for security (prevents prompt/response logging)
# ---------------------------------------------------------------------------

resource "azurerm_monitor_data_collection_rule" "apim_llm_logs_transform" {
  name                = "dcr-apim-llm-logs-transform"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "WorkspaceTransforms"

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "logAnalyticsDestination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Table-ApiManagementGatewayLlmLogs"]
    destinations = ["logAnalyticsDestination"]
    # Strip RequestMessages and ResponseMessages to prevent sensitive LLM content exposure
    # Token metrics (PromptTokens, CompletionTokens, TotalTokens, CachedTokens) are preserved
    transform_kql = <<-EOT
      source
      | extend RequestMessages = ""
      | extend ResponseMessages = ""
    EOT
  }

  tags = merge(var.tags, {
    Purpose = "Strip prompts/responses from ApiManagementGatewayLlmLogs"
  })
}