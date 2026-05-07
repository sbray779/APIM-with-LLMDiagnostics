# Migration Guide: From Broken to Working Logic App Module

## Summary of Changes

Based on https://medium.com/@bladesmaster.12/azure-logic-apps-terraform-the-challenges-for-a-devops-engineer-09ea0fb3d368

### Critical Fixes

1. **Changed from Linux to Windows** - Logic Apps Standard works reliably on Windows
2. **Removed ALL Terraform API Connection Resources** - These don't work with Logic Apps Standard
3. **Implemented Service Provider Connections** - Defined in connections.json, not Terraform
4. **Fixed App Settings** - Proper FUNCTIONS_WORKER_RUNTIME and version configuration
5. **Simplified Deployment** - Infrastructure via Terraform, workflows via ZIP deployment

## Migration Steps

### 1. Backup Current State

```powershell
# Export current terraform state
terraform show > terraform-state-backup.txt

# List current resources
az resource list --resource-group <rg-name> --query "[?contains(type, 'Logic')]" -o table
```

### 2. Destroy Old Infrastructure

Since the new approach is fundamentally different (Windows vs Linux, no API connections), it's cleanest to destroy and recreate:

```powershell
terraform destroy
```

Or target destroy if you want to preserve other resources:

```powershell
terraform destroy -target=module.logicapp
```

### 3. Replace Module Files

Replace the old files with the new corrected versions:

```powershell
# Backup old files
Move-Item modules/logicapp/main.tf modules/logicapp/main.tf.old
Move-Item modules/logicapp/variables.tf modules/logicapp/variables.tf.old
Move-Item modules/logicapp/outputs.tf modules/logicapp/outputs.tf.old
Move-Item modules/logicapp/versions.tf modules/logicapp/versions.tf.old
Move-Item modules/logicapp/workflows/connections.json modules/logicapp/workflows/connections.json.old
Move-Item modules/logicapp/workflows/TokenUsageReporting/workflow.json modules/logicapp/workflows/TokenUsageReporting/workflow.json.old

# Rename new files
Move-Item modules/logicapp/main.tf.new modules/logicapp/main.tf
Move-Item modules/logicapp/variables.tf.new modules/logicapp/variables.tf
Move-Item modules/logicapp/outputs.tf.new modules/logicapp/outputs.tf
Move-Item modules/logicapp/versions.tf.new modules/logicapp/versions.tf
Move-Item modules/logicapp/workflows/connections.json.new modules/logicapp/workflows/connections.json
Move-Item modules/logicapp/workflows/TokenUsageReporting/workflow.json.new modules/logicapp/workflows/TokenUsageReporting/workflow.json
```

### 4. Update Root Module

The new logicapp module has simplified outputs. Update your root `main.tf` where you call the module:

**Before:**
```hcl
module "logicapp" {
  source = "./modules/logicapp"
  
  enable                          = true
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.location
  logic_app_name                  = "apim-token-reporting"
  storage_account_name            = "apimreports"
  app_service_plan_sku_name       = "WS1"
  
  subnet_id                       = module.networking.logic_app_subnet_id
  storage_private_dns_zone_id     = module.networking.storage_private_dns_zone_id
  
  log_analytics_workspace_id      = module.monitoring.log_analytics_workspace_id
  log_analytics_workspace_name    = module.monitoring.log_analytics_workspace_name
  
  appinsights_instrumentation_key = module.monitoring.appinsights_instrumentation_key
  appinsights_connection_string   = module.monitoring.appinsights_connection_string
  
  subscription_id                 = data.azurerm_client_config.current.subscription_id
  
  # Many other variables...
}
```

**After:**
```hcl
module "logicapp" {
  source = "./modules/logicapp"
  
  resource_group_name               = azurerm_resource_group.this.name
  location                          = var.location
  logic_app_name                    = "apim-token-reporting"
  storage_account_name              = "apimreports"
  app_service_plan_sku_name         = "WS1"
  
  log_analytics_workspace_id        = module.monitoring.log_analytics_workspace_id
  appinsights_instrumentation_key   = module.monitoring.appinsights_instrumentation_key
  appinsights_connection_string     = module.monitoring.appinsights_connection_string
  
  user_assigned_identity_id         = azurerm_user_assigned_identity.logic_app.id
  user_assigned_identity_principal_id = azurerm_user_assigned_identity.logic_app.principal_id
  
  tags = var.tags
}
```

Note: You'll need to create the user-assigned identity in your root module:

```hcl
resource "azurerm_user_assigned_identity" "logic_app" {
  name                = "mi-logicapp-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}
```

### 5. Deploy New Infrastructure

```powershell
# Initialize (clean .terraform if needed)
Remove-Item -Recurse -Force .terraform
terraform init

# Plan and review
terraform plan

# Apply
terraform apply
```

### 6. Deploy Workflows

```powershell
# Get the Logic App name from outputs
$logicAppName = terraform output -raw logicapp_name
$rgName = terraform output -raw resource_group_name

# Deploy workflows
cd modules/logicapp
.\deploy-workflow-fixed.ps1 -ResourceGroupName $rgName -LogicAppName $logicAppName
```

### 7. Verify Deployment

```powershell
# Check Logic App is running
az webapp show --resource-group $rgName --name $logicAppName --query "{name:name,state:state,kind:kind}" -o table

# List workflows
az rest --method get --url "/subscriptions/<sub-id>/resourceGroups/$rgName/providers/Microsoft.Web/sites/$logicAppName/workflows?api-version=2022-03-01" --query "value[].{name:name,state:properties.state}" -o table

# Check app settings
az webapp config appsettings list --resource-group $rgName --name $logicAppName --query "[?name=='FUNCTIONS_WORKER_RUNTIME' || name=='WEBSITE_NODE_DEFAULT_VERSION']" -o table
```

### 8. Test Workflow Execution

In Azure Portal:
1. Navigate to Logic App → Workflows → TokenUsageReporting
2. Click "Run Trigger" → "Run"
3. Check Run History for successful execution
4. Verify CSV file created in storage account's `token-reports` container

## What Changed Technically

### Infrastructure (Terraform)

| Component | Old Approach | New Approach |
|-----------|-------------|--------------|
| OS Type | Linux | **Windows** |
| API Connections | azurerm_api_connection + azapi_resource | **NONE** |
| Functions Runtime | dotnet | **node** |
| Version Setting | In app_settings | **version property** |
| Connection Auth | Terraform parameters | **connections.json** |

### Workflows

| Component | Old Approach | New Approach |
|-----------|-------------|--------------|
| Connection Type | managedApiConnections | **serviceProviderConnections** |
| Auth Configuration | Terraform | **parameterSetName in JSON** |
| Action Type | ApiConnection | **ServiceProvider** |
| Connection Reference | runtime URLs | **serviceProviderConfiguration** |

## Why This Fix Works

### The Root Cause

Azure Logic Apps Standard has **two types of connections**:

1. **Managed API Connections** (azurerm_api_connection)
   - For Consumption Logic Apps
   - Created as separate ARM resources
   - Referenced by connection ID and runtime URL
   - **Does NOT work reliably with Standard Logic Apps**

2. **Service Provider Connections**
   - Built-in to Logic Apps Standard
   - Defined in `connections.json`
   - No separate ARM resources
   - Integrated with managed identity
   - **The correct approach for Standard Logic Apps**

### What Was Failing

When using `azurerm_api_connection`:
- Terraform creates the resource successfully
- Azure shows status "Ready" or "Connected"
- **BUT: connectionRuntimeUrl = null**
- Workflows can't resolve the connection
- Error: "Cannot read properties of undefined (reading 'headers')"

### Why Service Provider Connections Work

Service Provider Connections:
- Are part of the workflow package (not ARM resources)
- Use the `/serviceProviders/` namespace
- Automatically integrate with Logic App's managed identity
- Don't require runtime URL resolution
- Work reliably on Windows-based Logic Apps

## Troubleshooting

### If Terraform Apply Fails

**Error: Storage account name already exists**
```powershell
# The name is globally unique - check if old storage still exists
az storage account list --query "[?contains(name, 'apim')].name" -o table

# Delete if needed
az storage account delete --name <old-storage-name> --resource-group <rg-name> --yes
```

**Error: Logic App name already exists**
```powershell
# Check for zombie Logic Apps
az webapp list --query "[?contains(name, 'apim')].{name:name,state:state}" -o table

# Delete if needed
az webapp delete --name <old-logicapp-name> --resource-group <rg-name>
```

### If Workflow Deployment Fails

**Error: Could not get publish profile**
- Ensure Logic App is running: `az webapp start --name <name> --resource-group <rg>`
- Check you have permissions: Should have Contributor or Website Contributor role

**Error: ZIP deployment fails**
- Check Logic App state: Should be "Running"
- Verify network connectivity to SCM endpoint
- Try manual upload via Azure Portal → Advanced Tools → Drag & Drop

### If Workflow Execution Fails

**Workflow not visible**
- Check Kudu console (`https://<logicapp>.scm.azurewebsites.net`)
- Navigate to `C:\home\site\wwwroot`
- Verify folder structure and files

**Connection errors**
- Check managed identity role assignments
- Verify app settings have correct endpoints
- Review workflow definition uses `ServiceProvider` actions, not `ApiConnection`

## Rollback Plan

If the new approach doesn't work:

1. Keep the `.old` backup files
2. Restore old files:
   ```powershell
   Move-Item modules/logicapp/main.tf.old modules/logicapp/main.tf -Force
   # ... restore other files
   ```
3. Run `terraform init -reconfigure`
4. Run `terraform apply`

However, the old approach was fundamentally broken (NULL connection runtime URLs), so this new approach based on the proven Medium article pattern is the correct path forward.

## Additional Resources

- [Original Medium Article](https://medium.com/@bladesmaster.12/azure-logic-apps-terraform-the-challenges-for-a-devops-engineer-09ea0fb3d368)
- [GitHub Example](https://github.com/niksjk92/azure-logic-app-blog/tree/blog)
- [Logic Apps Standard Docs](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare)
- [Service Provider Reference](https://learn.microsoft.com/azure/logic-apps/connectors/built-in/reference/serviceProvider/)
