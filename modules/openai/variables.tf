variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}

variable "openai_name" {
  description = "Name of the Azure OpenAI service"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "ID of the private endpoint subnet"
  type        = string
}

variable "openai_private_dns_zone_id" {
  description = "ID of the OpenAI private DNS zone"
  type        = string
}

variable "apim_identity_principal_id" {
  description = "Principal ID of the APIM managed identity"
  type        = string
}

variable "openai_sku_name" {
  description = "SKU name for OpenAI service"
  type        = string
  default     = "S0"
}

variable "gpt_model_deployment_name" {
  description = "Name for the GPT model deployment"
  type        = string
  default     = "gpt-35-turbo"
}

variable "gpt_model_name" {
  description = "Name of the GPT model"
  type        = string
  default     = "gpt-35-turbo"
}

variable "gpt_model_version" {
  description = "Version of the GPT model"
  type        = string
  default     = "0125"
}

variable "gpt_model_capacity" {
  description = "Capacity for GPT model deployment"
  type        = number
  default     = 30
}

variable "embedding_model_deployment_name" {
  description = "Name for the embedding model deployment"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_model_name" {
  description = "Name of the embedding model"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_model_version" {
  description = "Version of the embedding model"
  type        = string
  default     = "2"
}

variable "embedding_model_capacity" {
  description = "Capacity for embedding model deployment"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}