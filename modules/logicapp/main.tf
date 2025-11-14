# Logic App module for API Management Token Usage Reporting
# Converted from ARM templates: azuredeploy.json and rbac.json

locals {
  unique_suffix        = substr(sha256("${var.resource_group_name}-${var.logic_app_name}"), 0, 5)
  logic_app_name       = "${var.logic_app_name}-${local.unique_suffix}"
  app_service_plan_name = "${var.logic_app_name}-asp-${local.unique_suffix}"
  log_analytics_name   = var.log_analytics_workspace_name != null ? var.log_analytics_workspace_name : "${var.logic_app_name}-logs-${local.unique_suffix}"
  storage_account_name = lower(substr(replace(replace("${var.storage_account_name}${local.unique_suffix}", "-", ""), "_", ""), 0, 24))
  logic_storage_name   = lower(substr(replace(replace("${var.logic_app_name}${local.unique_suffix}", "-", ""), "_", ""), 0, 24))

  blob_connection_name = "${local.logic_app_name}-azureblob"
  logs_connection_name = "${local.logic_app_name}-azuremonitorlogs"
}

# App Service Plan for Logic App
resource "azurerm_service_plan" "logicapp" {
  name                = local.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  os_type  = "Windows"
  sku_name = var.app_service_plan_sku_name

  tags = var.tags
}

# Log Analytics Workspace (only create if not provided)
resource "azurerm_log_analytics_workspace" "logicapp" {
  count               = var.log_analytics_workspace_name == null ? 1 : 0
  name                = local.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

# Storage Account for Logic App data
resource "azurerm_storage_account" "logicapp_data" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Blob container for Logic App workflow data
resource "azurerm_storage_container" "logicapp_container" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.logicapp_data.name
  container_access_type = "private"
}

# Storage Account for Logic App runtime
resource "azurerm_storage_account" "logicapp_runtime" {
  name                     = local.logic_storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Azure Blob Connection for Logic App
resource "azurerm_api_connection" "blob" {
  name                = local.blob_connection_name
  resource_group_name = var.resource_group_name

  managed_api_id = data.azurerm_managed_api.blob.id
  display_name   = "Azure Blob Storage Connection"

  parameter_values = {
    accountName = azurerm_storage_account.logicapp_data.name
    accessKey   = azurerm_storage_account.logicapp_data.primary_access_key
  }

  tags = var.tags
}

# Azure Monitor Logs Connection for Logic App
resource "azurerm_api_connection" "logs" {
  name                = local.logs_connection_name
  resource_group_name = var.resource_group_name

  managed_api_id = data.azurerm_managed_api.logs.id
  display_name   = "Azure Monitor Logs Connection"

  tags = var.tags
}

# Logic App (Standard)
resource "azurerm_logic_app_standard" "main" {
  name                       = local.logic_app_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = azurerm_service_plan.logicapp.id
  storage_account_name       = azurerm_storage_account.logicapp_runtime.name
  storage_account_access_key = azurerm_storage_account.logicapp_runtime.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_EXTENSION_VERSION"   = "~4"
    "FUNCTIONS_WORKER_RUNTIME"      = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"  = "~18"
    "APP_KIND"                      = "workflowApp"
    "AzureBlob_blobStorageEndpoint" = azurerm_storage_account.logicapp_data.primary_blob_endpoint
    "LogAnalytics_WorkspaceName"    = var.log_analytics_workspace_name != null ? var.log_analytics_workspace_name : azurerm_log_analytics_workspace.logicapp[0].name
    "LogAnalytics_WorkspaceId"      = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.logicapp[0].workspace_id
  }

  site_config {
    use_32_bit_worker_process   = false
    dotnet_framework_version    = "v6.0"
    ftps_state                  = "Disabled"
    min_tls_version             = "1.2"
    scm_use_main_ip_restriction = false
    always_on                   = var.always_on
  }

  https_only = true

  depends_on = [
    azurerm_api_connection.blob,
    azurerm_api_connection.logs,
    azurerm_storage_account.logicapp_runtime,
  ]

  tags = var.tags
}

# RBAC - Storage Blob Data Contributor for Logic App
resource "azurerm_role_assignment" "logic_app_storage" {
  scope                = azurerm_storage_account.logicapp_data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# RBAC - Log Analytics Reader for Logic App
resource "azurerm_role_assignment" "logic_app_logs" {
  scope                = var.log_analytics_workspace_name != null ? data.azurerm_log_analytics_workspace.existing[0].id : azurerm_log_analytics_workspace.logicapp[0].id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# Note: Workflow files need to be deployed manually after infrastructure is created
# The workflow files are provided in the workflows/ directory and need to be uploaded
# to the Logic App using Azure CLI, PowerShell, or Azure Portal
# See the deployment instructions in the module documentation