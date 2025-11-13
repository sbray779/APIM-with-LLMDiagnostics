variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}

variable "apim_name" {
  description = "Name of the API Management service"
  type        = string
}

variable "apim_subnet_id" {
  description = "ID of the APIM subnet"
  type        = string
}

variable "apim_identity_id" {
  description = "ID of the APIM managed identity"
  type        = string
}

variable "apim_identity_principal_id" {
  description = "Principal ID of the APIM managed identity"
  type        = string
}

variable "apim_identity_client_id" {
  description = "Client ID of the APIM managed identity"
  type        = string
}

variable "openai_endpoint" {
  description = "Endpoint URL of the Azure OpenAI service"
  type        = string
}

variable "keyvault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "keyvault_uri" {
  description = "URI of the Key Vault"
  type        = string
}



variable "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  type        = string
}

variable "publisher_email" {
  description = "Email address of the APIM publisher"
  type        = string
  default     = "admin@company.com"
}

variable "publisher_name" {
  description = "Name of the APIM publisher"
  type        = string
  default     = "API Publisher"
}

variable "apim_sku" {
  description = "SKU for API Management service"
  type        = string
  default     = "Developer"
}

variable "apim_sku_capacity" {
  description = "Capacity for API Management service"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}