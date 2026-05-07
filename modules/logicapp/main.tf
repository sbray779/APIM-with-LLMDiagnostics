# Logic App module for API Management Token Usage Reporting
# Converted from ARM templates: azuredeploy.json and rbac.json

locals {
  unique_suffix        = substr(sha256("${var.resource_group_name}-${var.logic_app_name}"), 0, 5)
  logic_app_name       = "${var.logic_app_name}-${local.unique_suffix}"
  app_service_plan_name = "${var.logic_app_name}-asp-${local.unique_suffix}"
  log_analytics_name   = var.use_existing_log_analytics ? var.log_analytics_workspace_name : "${var.logic_app_name}-logs-${local.unique_suffix}"
  storage_account_name = lower(substr(replace(replace("${var.storage_account_name}${local.unique_suffix}", "-", ""), "_", ""), 0, 24))
  logic_storage_name   = lower(substr(replace(replace("${var.logic_app_name}${local.unique_suffix}", "-", ""), "_", ""), 0, 24))

  # V2 API connection IDs (created by script, not Terraform)
  # These are predictable resource IDs based on subscription/resource group
  blob_connection_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/azureblob"
  logs_connection_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/azuremonitorlogs"
  
  # Error logging resources
  error_workspace_name = "law-errors-${var.environment}-${local.unique_suffix}"
  dce_endpoint_name    = "dce-${var.environment}-${local.unique_suffix}"
  dcr_name             = "dcr-${var.environment}-${local.unique_suffix}"
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

# Log Analytics Workspace (only create if not using existing)
resource "azurerm_log_analytics_workspace" "logicapp" {
  count               = var.use_existing_log_analytics ? 0 : 1
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

# V2 API Connections are created via PowerShell script (create-api-connections.ps1)
# because Terraform's azurerm_api_connection doesn't support V2 connections with MSI authentication.
# See: https://github.com/hashicorp/terraform-provider-azurerm/issues/
#
# The script creates:
# - Azure Blob connection with managedIdentityAuth
# - Azure Monitor Logs connection with managedIdentityAuth
# - Access policies for the Logic App's managed identity

resource "null_resource" "api_connections" {
  triggers = {
    # Recreate connections if Logic App identity changes
    logic_app_identity = azurerm_logic_app_standard.main.identity[0].principal_id
    resource_group     = var.resource_group_name
  }

  provisioner "local-exec" {
    command     = <<-EOT
      powershell -ExecutionPolicy Bypass -File "${path.module}/create-api-connections.ps1" `
        -SubscriptionId "${data.azurerm_subscription.current.subscription_id}" `
        -ResourceGroupName "${var.resource_group_name}" `
        -Location "${var.location}" `
        -LogicAppIdentityObjectId "${azurerm_logic_app_standard.main.identity[0].principal_id}"
    EOT
    interpreter = ["powershell", "-Command"]
  }

  depends_on = [azurerm_logic_app_standard.main]
}

# Logic App (Standard)
resource "azurerm_logic_app_standard" "main" {
  name                       = local.logic_app_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = azurerm_service_plan.logicapp.id
  storage_account_name       = azurerm_storage_account.logicapp_runtime.name
  storage_account_access_key = azurerm_storage_account.logicapp_runtime.primary_access_key
  virtual_network_subnet_id  = var.enable_vnet_integration ? var.logicapp_subnet_id : null
  version                    = "~4"

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"                          = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"                      = "~18"
    "AzureBlob_blobStorageEndpoint"                     = azurerm_storage_account.logicapp_data.primary_blob_endpoint
    "LogAnalytics_WorkspaceName"                        = var.log_analytics_workspace_name != null ? var.log_analytics_workspace_name : azurerm_log_analytics_workspace.logicapp[0].name
    "LogAnalytics_WorkspaceId"                          = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.logicapp[0].workspace_id
    "WEBSITE_CONTENTOVERVNET"                           = var.enable_vnet_integration ? "1" : "0"
    "WEBSITE_VNET_ROUTE_ALL"                            = var.enable_vnet_integration ? "1" : "0"
  }

  site_config {
    use_32_bit_worker_process   = false
    dotnet_framework_version    = "v6.0"
    ftps_state                  = "Disabled"
    min_tls_version             = "1.2"
    scm_use_main_ip_restriction = false
    always_on                   = var.always_on
    vnet_route_all_enabled      = var.enable_vnet_integration
  }

  https_only = true

  depends_on = [
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
  scope                = var.use_existing_log_analytics ? data.azurerm_log_analytics_workspace.existing[0].id : azurerm_log_analytics_workspace.logicapp[0].id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# =====================================
# Error Logging Infrastructure (DCE/DCR)
# =====================================

# Log Analytics Workspace for error logging
resource "azurerm_log_analytics_workspace" "errors" {
  name                = local.error_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

# Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "logicapp" {
  name                          = local.dce_endpoint_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = true

  tags = var.tags
}

# Custom Log Analytics Table for workflow failures
# Must be created BEFORE the DCR that references it
resource "azapi_resource" "workflow_failures_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  name      = "WorkflowFailures_CL"
  parent_id = azurerm_log_analytics_workspace.errors.id

  body = {
    properties = {
      schema = {
        name = "WorkflowFailures_CL"
        columns = [
          { name = "TimeGenerated", type = "datetime", description = "Time the event was generated" },
          { name = "WorkflowName", type = "string", description = "Name of the workflow" },
          { name = "WorkflowRunId", type = "string", description = "Run ID of the workflow" },
          { name = "FailureType", type = "string", description = "Type of failure" },
          { name = "ActionName", type = "string", description = "Name of the failed action" },
          { name = "ErrorCode", type = "string", description = "Error code" },
          { name = "ErrorMessage", type = "string", description = "Error message" },
          { name = "Severity", type = "string", description = "Severity level" },
          { name = "BlobPath", type = "string", description = "Path to blob with details" }
        ]
      }
      retentionInDays      = var.log_analytics_retention_days
      totalRetentionInDays = var.log_analytics_retention_days
    }
  }
}

# Data Collection Rule for workflow failures
# Using azapi for custom log DCR to have more control over the API payload
resource "azapi_resource" "logicapp_dcr" {
  type      = "Microsoft.Insights/dataCollectionRules@2023-03-11"
  name      = local.dcr_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {
    properties = {
      dataCollectionEndpointId = azurerm_monitor_data_collection_endpoint.logicapp.id
      streamDeclarations = {
        "Custom-WorkflowFailures" = {
          columns = [
            { name = "TimeGenerated", type = "datetime" },
            { name = "WorkflowName", type = "string" },
            { name = "WorkflowRunId", type = "string" },
            { name = "FailureType", type = "string" },
            { name = "ActionName", type = "string" },
            { name = "ErrorCode", type = "string" },
            { name = "ErrorMessage", type = "string" },
            { name = "Severity", type = "string" },
            { name = "BlobPath", type = "string" }
          ]
        }
      }
      destinations = {
        logAnalytics = [
          {
            workspaceResourceId = azurerm_log_analytics_workspace.errors.id
            name                = "errorWorkspace"
          }
        ]
      }
      dataFlows = [
        {
          streams      = ["Custom-WorkflowFailures"]
          destinations = ["errorWorkspace"]
          transformKql = "source"
          outputStream = "Custom-WorkflowFailures_CL"
        }
      ]
    }
  }

  tags = var.tags

  response_export_values = ["properties.immutableId"]

  depends_on = [azapi_resource.workflow_failures_table]
}

# RBAC - Monitoring Metrics Publisher on DCR for Logic App
resource "azurerm_role_assignment" "logic_app_dcr" {
  scope                = azapi_resource.logicapp_dcr.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# RBAC - Monitoring Metrics Publisher on DCE for Logic App
resource "azurerm_role_assignment" "logic_app_dce" {
  scope                = azurerm_monitor_data_collection_endpoint.logicapp.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# RBAC - Reader on source workspace for resource metadata access
resource "azurerm_role_assignment" "logic_app_reader" {
  scope                = var.use_existing_log_analytics ? data.azurerm_log_analytics_workspace.existing[0].id : azurerm_log_analytics_workspace.logicapp[0].id
  role_definition_name = "Reader"
  principal_id         = azurerm_logic_app_standard.main.identity[0].principal_id
}

# Note: Workflow files need to be deployed manually after infrastructure is created
# The workflow files are provided in the workflows/ directory and need to be uploaded
# to the Logic App using Azure CLI, PowerShell, or Azure Portal
# See the deployment instructions in the module documentation