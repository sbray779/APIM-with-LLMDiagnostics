# Logic App Module for API Management Token Usage Reporting

This Terraform module deploys a Logic App Standard solution that queries API Management gateway logs to extract token usage data and stores reports in a Storage Account.

## Architecture

The module creates the following resources:
- **App Service Plan**: Dedicated Workflow Standard (WS1) or Elastic Premium tier plan for Logic App
- **Logic App (Standard)**: Workflow engine hosted on the created App Service Plan
- **Log Analytics Workspace**: For querying API Management gateway logs (optional - can use existing)
- **Storage Account**: For storing token usage reports as CSV files
- **Storage Account**: Separate account for Logic App runtime
- **API Connections**: Secure connections using access keys and Managed Identity
- **Blob Container**: Dedicated container for report data
- **RBAC Assignments**: Permissions for Logic App to access Log Analytics and Storage

## Prerequisites

1. **API Management Instance**: Must have LLM gateway logging enabled
2. **Diagnostic Settings**: APIM must send logs to Log Analytics workspace:
   - `ApiManagementGatewayLogs`
   - `ApiManagementGatewayLlmLog`

## Usage

```hcl
module "logicapp" {
  source = "./modules/logicapp"

  logic_app_name                   = "apim-token-reporting"
  resource_group_name              = "my-resource-group"
  location                         = "East US 2"
  app_service_plan_sku_name        = "WS1"  # WS1/WS2/WS3 (Workflow Standard) or EP1/EP2/EP3 (Elastic Premium)
  
  # Use existing Log Analytics workspace from APIM module
  log_analytics_workspace_name     = "my-existing-workspace"
  log_analytics_workspace_id       = "workspace-guid-id"
  
  storage_account_name             = "tokenreports"
  storage_container_name           = "reports"
  
  tags = {
    Environment = "Production"
    Purpose     = "APIM Token Reporting"
  }
}
```

## Post-Deployment Steps

After Terraform creates the infrastructure, you need to deploy the Logic App workflows:

### 1. Upload Workflow Files

The workflow files are in the `workflows/` directory and need to be uploaded to the Logic App:

**Using Azure CLI:**
```bash
# Set variables
LOGIC_APP_NAME="your-logic-app-name"
RESOURCE_GROUP="your-resource-group"
SUBSCRIPTION_ID="your-subscription-id"
WORKSPACE_NAME="your-log-analytics-workspace"

# Create the workflow directory structure
az logicapp deploy --resource-group $RESOURCE_GROUP --name $LOGIC_APP_NAME --src-path ./workflows
```

**Using PowerShell:**
```powershell
# Upload workflow files using Azure PowerShell
$logicAppName = "your-logic-app-name"
$resourceGroup = "your-resource-group"

# Deploy the workflow package
Publish-AzLogicApp -ResourceGroupName $resourceGroup -Name $logicAppName -SourcePath "./workflows"
```

### 2. Configure Workflow Parameters

The workflow template includes placeholders that need to be replaced:
- `${log_analytics_workspace_name}`: Your Log Analytics workspace name
- `${resource_group_name}`: Your resource group name  
- `${subscription_id}`: Your Azure subscription ID
- `${storage_container_name}`: Your blob container name

### 3. Update Connection References

Update the `connections.json` file with actual resource IDs before uploading:
- Replace `${subscription_id}` with your subscription ID
- Replace `${resource_group_name}` with your resource group name
- Replace `${location}` with your Azure region
- Replace connection IDs with actual values from Terraform outputs

### 4. Test the Workflow

1. Navigate to the Logic App in the Azure Portal
2. Go to **Workflows** and select the **TokenUsageReporting** workflow
3. Click **Run Trigger** to test manually
4. Check the **Run History** for execution status
5. Verify that CSV reports are created in the storage container

## Outputs

The module provides these outputs for integration:

- `logic_app_name`: Name of the created Logic App
- `logic_app_id`: Resource ID of the Logic App
- `logic_app_principal_id`: Managed identity principal ID
- `storage_account_name`: Name of the data storage account
- `log_analytics_workspace_name`: Name of the Log Analytics workspace
- `blob_connection_id`: ID of the blob storage API connection
- `logs_connection_id`: ID of the Log Analytics API connection

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `logic_app_name` | string | | Name of the Logic App |
| `resource_group_name` | string | | Resource group name |
| `location` | string | | Azure region |
| `app_service_plan_id` | string | | Existing App Service Plan resource ID |
| `storage_account_name` | string | "logicappstorage" | Base name for storage account |
| `storage_container_name` | string | "workflow-data" | Blob container name |
| `log_analytics_workspace_name` | string | null | Existing workspace name (optional) |
| `log_analytics_workspace_id` | string | null | Existing workspace ID (optional) |
| `log_analytics_retention_days` | number | 30 | Log retention period |
| `always_on` | bool | true | Keep Logic App always on |
| `tags` | map(string) | {} | Resource tags |

## KQL Query Customization

The default query in `workflow.json` extracts token usage data:

```kql
ApiManagementGatewayLogs
| where TimeGenerated >= ago(24h)
| join kind=inner ApiManagementGatewayLlmLog on CorrelationId
| where SequenceNumber == 0 and IsRequestSuccess
| summarize
    TotalTokens = sum(TotalTokens),
    CompletionTokens = sum(CompletionTokens),
    PromptTokens = sum(PromptTokens),
    Calls = count()
  by ProductId, ModelName
| order by TotalTokens desc
```

You can customize this query to:
- Filter by specific time ranges
- Add additional fields
- Modify client ID extraction logic
- Include/exclude specific products or backends

## Security Features

- **Managed Identity**: No stored credentials required
- **HTTPS Only**: All traffic encrypted
- **Private Storage**: Blob public access disabled
- **RBAC**: Minimal required permissions
- **TLS 1.2**: Minimum encryption standard

## Troubleshooting

1. **Workflow Upload Issues**: Ensure the Logic App is in a running state before uploading workflows
2. **Connection Failures**: Verify API connections are properly configured with Managed Identity
3. **Query Errors**: Check that the Log Analytics workspace has the required APIM log data
4. **Permission Denied**: Ensure RBAC role assignments are applied and propagated