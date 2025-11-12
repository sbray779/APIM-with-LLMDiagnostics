variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "apim_service_name" {
  description = "Name of the API Management service"
  type        = string
}

variable "openai_api_name" {
  description = "Name of the OpenAI API in APIM"
  type        = string
}

variable "applicationinsights_logger_id" {
  description = "ID of the Application Insights logger in APIM"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for Azure Monitor diagnostics"
  type        = string
}

