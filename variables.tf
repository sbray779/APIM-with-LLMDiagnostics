variable "environment_name" {
  description = "Name of the environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.environment_name))
    error_message = "Environment name must contain only alphanumeric characters and hyphens."
  }
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "East US"
  
  validation {
    condition = can(index([
      "East US", "East US 2", "West US", "West US 2", "West US 3", 
      "Central US", "North Central US", "South Central US", 
      "Canada East", "Canada Central", "Brazil South", "UK South", 
      "UK West", "West Europe", "North Europe", "France Central", 
      "Germany West Central", "Switzerland North", "Norway East", 
      "Sweden Central", "Australia East", "Australia Southeast", 
      "Japan East", "Japan West", "Korea Central", "Southeast Asia", 
      "East Asia", "India Central"
    ], var.location))
    error_message = "Location must be a valid Azure region."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group. If empty, will be auto-generated"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# API Management Variables
variable "publisher_email" {
  description = "Email address of the APIM publisher"
  type        = string
  default     = "admin@company.com"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.publisher_email))
    error_message = "Publisher email must be a valid email address."
  }
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
  
  validation {
    condition     = contains(["Developer", "Standard", "Premium"], var.apim_sku)
    error_message = "APIM SKU must be one of: Developer, Standard, Premium."
  }
}

variable "apim_sku_capacity" {
  description = "Capacity for API Management service"
  type        = number
  default     = 1
  
  validation {
    condition     = var.apim_sku_capacity >= 1 && var.apim_sku_capacity <= 10
    error_message = "APIM SKU capacity must be between 1 and 10."
  }
}

# OpenAI Variables
variable "openai_sku_name" {
  description = "SKU name for OpenAI service"
  type        = string
  default     = "S0"
  
  validation {
    condition     = contains(["S0"], var.openai_sku_name)
    error_message = "OpenAI SKU must be S0."
  }
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
  
  validation {
    condition = contains([
      "gpt-35-turbo", "gpt-35-turbo-16k", "gpt-4", "gpt-4-32k", 
      "gpt-4-turbo", "gpt-4o"
    ], var.gpt_model_name)
    error_message = "GPT model must be a valid Azure OpenAI model."
  }
}

variable "gpt_model_version" {
  description = "Version of the GPT model"
  type        = string
  default     = "0125"
}

variable "gpt_model_capacity" {
  description = "Capacity for GPT model deployment (TPM in thousands)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.gpt_model_capacity >= 1 && var.gpt_model_capacity <= 300
    error_message = "GPT model capacity must be between 1 and 300."
  }
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
  
  validation {
    condition = contains([
      "text-embedding-ada-002", "text-embedding-3-small", "text-embedding-3-large"
    ], var.embedding_model_name)
    error_message = "Embedding model must be a valid Azure OpenAI embedding model."
  }
}

variable "embedding_model_version" {
  description = "Version of the embedding model"
  type        = string
  default     = "2"
}

variable "embedding_model_capacity" {
  description = "Capacity for embedding model deployment (TPM in thousands)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.embedding_model_capacity >= 1 && var.embedding_model_capacity <= 300
    error_message = "Embedding model capacity must be between 1 and 300."
  }
}

# Networking Variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "apim_subnet_address_prefix" {
  description = "Address prefix for APIM subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoint_subnet_address_prefix" {
  description = "Address prefix for private endpoint subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Monitoring Variables
variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}



# Security Variables
variable "enable_private_endpoints" {
  description = "Enable private endpoints for Azure services"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access public endpoints (when private endpoints are disabled)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))
    ])
    error_message = "All allowed IP ranges must be valid CIDR blocks."
  }
}