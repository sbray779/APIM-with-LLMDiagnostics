# Get current subscription ID
data "azurerm_subscription" "current" {}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Create APIM service diagnostics using azapi provider for LLM logging
resource "azapi_resource" "apim_service_diagnostics" {
  type      = "Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview"
  name      = "applicationinsights"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_service_name}"
  
  # Lifecycle management for destroy operations
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
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
        response = {
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
      backend = {
        request = {
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
        response = {
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
    }
  }
}

# Create API-level diagnostics for the OpenAI API with data masking
resource "azapi_resource" "openai_api_diagnostics" {
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2023-05-01-preview"
  name      = "applicationinsights"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_service_name}/apis/${var.openai_api_name}"
  
  # Lifecycle management for destroy operations
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
          headers = ["*"]
          body = {
            bytes = 8192
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
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
      backend = {
        request = {
          headers = ["*"]
          body = {
            bytes = 8192
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
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
    }
  }
}
# Note: Azure Monitor logger already exists and will be referenced by resource ID

# Create Azure Monitor diagnostics for OpenAI API with LLM logging
resource "azapi_resource" "openai_api_azure_monitor_diagnostics" {
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview"
  name      = "azuremonitor"
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_service_name}/apis/${var.openai_api_name}"

  schema_validation_enabled = false

  body = {
    properties = {
      alwaysLog   = "allErrors"
      verbosity   = "information"
      logClientIp = true
      loggerId    = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_service_name}/loggers/azuremonitor"
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }

      largeLanguageModel = {
        logs = "enabled"
        requests = {
          maxSizeInBytes = 32768
          messages       = "all"
        }
        responses = {
          maxSizeInBytes = 32768
          messages       = "all"
        }
      }
      frontend = {
        request = {
          headers = ["*"]
          body = {
            bytes = 8192
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
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
      backend = {
        request = {
          headers = ["*"]
          body = {
            bytes = 8192
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
          headers = ["*"]
          body = {
            bytes = 8192
          }
        }
      }
    }
  }
}