# Terraform configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1.0"
    }
  }
}

# Provider configurations
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azapi" {
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Generate a random string for unique resource names
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

# Local values for common naming and configuration
locals {
  suffix = random_string.suffix.result
  common_tags = merge(var.tags, {
    "Environment"  = var.environment_name
    "Project"      = "APIM-OpenAI"
    "DeployedBy"   = "Terraform"
    "DeployedDate" = timestamp()
  })

  # Resource naming
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "rg-apim-openai-${var.environment_name}-${local.suffix}"
  vnet_name           = "vnet-apim-openai-${var.environment_name}-${local.suffix}"
  openai_name         = "openai-${var.environment_name}-${local.suffix}"
  apim_name           = "apim-${var.environment_name}-${local.suffix}"
  keyvault_name       = "kv-${var.environment_name}-${local.suffix}"
  log_analytics_name  = "log-${var.environment_name}-${local.suffix}"
  app_insights_name   = "ai-${var.environment_name}-${local.suffix}"
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# User Assigned Managed Identity for APIM
resource "azurerm_user_assigned_identity" "apim_identity" {
  name                = "mi-apim-${var.environment_name}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# User Assigned Managed Identity for Function App
resource "azurerm_user_assigned_identity" "function_identity" {
  name                = "mi-func-${var.environment_name}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  resource_group_name                    = azurerm_resource_group.main.name
  location                               = azurerm_resource_group.main.location
  vnet_name                              = local.vnet_name
  vnet_address_space                     = var.vnet_address_space
  apim_subnet_address_prefix             = var.apim_subnet_address_prefix
  private_endpoint_subnet_address_prefix = var.private_endpoint_subnet_address_prefix
  tags                                   = local.common_tags
}

# Azure OpenAI Module
module "openai" {
  source = "./modules/openai"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  openai_name                = local.openai_name
  vnet_id                    = module.networking.vnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  openai_private_dns_zone_id = module.networking.openai_private_dns_zone_id
  apim_identity_principal_id = azurerm_user_assigned_identity.apim_identity.principal_id
  tags                       = local.common_tags

  # Model deployments
  gpt_model_deployment_name       = var.gpt_model_deployment_name
  gpt_model_name                  = var.gpt_model_name
  gpt_model_version               = var.gpt_model_version
  gpt_model_capacity              = var.gpt_model_capacity
  embedding_model_deployment_name = var.embedding_model_deployment_name
  embedding_model_name            = var.embedding_model_name
  embedding_model_version         = var.embedding_model_version
  embedding_model_capacity        = var.embedding_model_capacity
  openai_sku_name                 = var.openai_sku_name
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  log_analytics_name           = local.log_analytics_name
  app_insights_name            = local.app_insights_name
  log_analytics_retention_days = var.log_analytics_retention_days
  tags                         = local.common_tags
}

# Key Vault for storing secrets
resource "azurerm_key_vault" "main" {
  name                = local.keyvault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = true
  
  # Enable purge protection to prevent accidental deletion
  purge_protection_enabled = false
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.apim_identity.principal_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.function_identity.principal_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }

  tags = local.common_tags
}

# Store OpenAI API key in Key Vault
resource "azurerm_key_vault_secret" "openai_key" {
  name         = "openai-api-key"
  value        = module.openai.primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
  
  # Lifecycle management to prevent issues during destroy
  lifecycle {
    ignore_changes = [value]
  }
}

# API Management Module
module "apim" {
  source = "./modules/apim"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  apim_name                  = local.apim_name
  apim_subnet_id             = module.networking.apim_subnet_id
  apim_identity_id           = azurerm_user_assigned_identity.apim_identity.id
  apim_identity_principal_id = azurerm_user_assigned_identity.apim_identity.principal_id
  apim_identity_client_id    = azurerm_user_assigned_identity.apim_identity.client_id
  openai_endpoint            = module.openai.endpoint
  keyvault_id                = azurerm_key_vault.main.id
  keyvault_uri               = azurerm_key_vault.main.vault_uri

  application_insights_instrumentation_key = module.monitoring.application_insights_instrumentation_key
  log_analytics_workspace_id               = module.monitoring.log_analytics_workspace_id
  publisher_email                          = var.publisher_email
  publisher_name                           = var.publisher_name
  apim_sku                                 = var.apim_sku
  apim_sku_capacity                        = var.apim_sku_capacity
  tags                                     = local.common_tags

  # Explicit dependencies to ensure proper creation order
  depends_on = [
    azurerm_key_vault_secret.openai_key,
    module.networking,
    module.openai,
    module.monitoring
  ]
}

#Wait before attempting to create loggers after diagnostic setting is configured

resource "time_sleep" "monitor_create" {
  depends_on = [module.apim]
  create_duration = "45m"  
  
  lifecycle {
    create_before_destroy = true
  }
}

# Diagnostics Module (using azapi provider)
module "diagnostics" {
  source = "./modules/diagnostics"

  resource_group_name           = azurerm_resource_group.main.name
  apim_service_name             = module.apim.apim_name
  openai_api_name               = module.apim.openai_api_name
  applicationinsights_logger_id = module.apim.applicationinsights_logger_id
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id

  # Ensure diagnostics are created after all APIM resources are fully configured
  depends_on = [module.apim, time_sleep.monitor_create]
}

# Ensure proper destroy order with explicit dependencies
resource "null_resource" "destroy_order" {
  # This ensures diagnostics are destroyed before APIM and networking
  depends_on = [
    module.diagnostics,
    module.apim,
    module.networking
  ]
  
  # Triggers ensure this runs during destroy
  triggers = {
    diagnostics_id = try(module.diagnostics, null) != null ? "exists" : "none"
    apim_id       = module.apim.apim_id
    networking_id = module.networking.vnet_id
  }
}

# Logic App Module for Token Usage Reporting (Optional)
module "logicapp" {
  count  = var.deploy_logic_app ? 1 : 0
  source = "./modules/logicapp"

  logic_app_name           = "apim-token-reporting-${var.environment_name}-${local.suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  app_service_plan_sku_name = var.logic_app_service_plan_sku

  # Use existing Log Analytics workspace from monitoring module
  log_analytics_workspace_name = module.monitoring.log_analytics_workspace_name
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id

  storage_account_name         = "apimtokenreports${var.environment_name}"
  storage_container_name       = var.logic_app_storage_container_name
  log_analytics_retention_days = var.log_analytics_retention_days
  always_on                    = var.logic_app_always_on

  tags = local.common_tags

  depends_on = [module.monitoring, module.apim]
}
