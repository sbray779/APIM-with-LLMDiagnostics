variable "logic_app_name" {
  description = "Name of the Logic App"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "app_service_plan_sku_name" {
  description = "SKU name for the App Service Plan (Standard tier recommended for Logic Apps)"
  type        = string
  default     = "WS1"

  validation {
    condition = can(regex("^(WS1|WS2|WS3|EP1|EP2|EP3)$", var.app_service_plan_sku_name))
    error_message = "App Service Plan SKU must be one of: WS1, WS2, WS3 (Workflow Standard) or EP1, EP2, EP3 (Elastic Premium)."
  }
}

variable "storage_account_name" {
  description = "Base name for the storage account (will be made globally unique)"
  type        = string
  default     = "logicappstorage"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "storage_container_name" {
  description = "Name of the blob container for Logic App data"
  type        = string
  default     = "workflow-data"
}

variable "log_analytics_workspace_name" {
  description = "Name of existing Log Analytics workspace. If null, a new one will be created."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Workspace ID of existing Log Analytics workspace. Required if log_analytics_workspace_name is provided."
  type        = string
  default     = null
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace"
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 7 && var.log_analytics_retention_days <= 730
    error_message = "Log retention must be between 7 and 730 days."
  }
}

variable "always_on" {
  description = "Should the Logic App be always on"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}