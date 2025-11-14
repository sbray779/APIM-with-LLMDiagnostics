# Logic App Integration Guide

This document describes how to deploy and configure the Logic App for API Management Token Usage Reporting that has been integrated into the APIM-with-LLMDiagnostics repository.

## Overview

The Logic App solution provides automated token usage reporting for Azure API Management (APIM) with OpenAI backend. It:

- Queries API Management gateway logs and LLM gateway logs from Log Analytics
- Extracts token usage data (prompt tokens, completion tokens, total tokens)
- Aggregates data by ProductId and ModelName
- Generates CSV reports stored in Azure Blob Storage
- Runs on a scheduled basis (daily by default)

## Prerequisites

### 1. App Service Plan Configuration
The Logic App module automatically creates a dedicated App Service Plan with the specified SKU. You can choose between:

- **Workflow Standard (WS1, WS2, WS3)**: Optimized for Logic Apps Standard
- **Elastic Premium (EP1, EP2, EP3)**: High-performance option with pre-warmed instances

No manual App Service Plan creation is required - the module handles this automatically.

### 2. APIM Configuration
Ensure your API Management instance has:
- LLM Gateway Logging enabled
- Diagnostic settings configured to send logs to Log Analytics
- Required log categories: `ApiManagementGatewayLogs` and `ApiManagementGatewayLlmLog`

## Deployment Steps

### Step 1: Configure Terraform Variables

Update your `terraform.tfvars` file:

```hcl
# Enable Logic App deployment
deploy_logic_app = true

# Configure App Service Plan SKU for Logic App
logic_app_service_plan_sku = "WS1"  # Options: WS1, WS2, WS3 (Workflow Standard) or EP1, EP2, EP3 (Elastic Premium)

# Configure storage container name
logic_app_storage_container_name = "token-reports"
logic_app_always_on = true
```

### Step 2: Deploy Infrastructure

```bash
# Initialize Terraform (if not done already)
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

The Terraform deployment will create:
- Logic App Standard instance
- Storage account for Logic App runtime
- Storage account for token usage reports  
- Blob container for reports
- API connections for Azure Blob and Azure Monitor Logs
- RBAC role assignments

### Step 3: Deploy Workflow Files

After infrastructure deployment, you need to upload the Logic App workflow files manually.

#### Option A: Using Azure CLI

```bash
# Set variables from Terraform outputs
LOGIC_APP_NAME=$(terraform output -raw logic_app_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
WORKSPACE_NAME=$(terraform output -raw log_analytics_workspace_name)
SUBSCRIPTION_ID="your-subscription-id"

# Navigate to the logicapp workflows directory
cd modules/logicapp/workflows

# Update workflow template with actual values
sed -i "s/\${log_analytics_workspace_name}/$WORKSPACE_NAME/g" workflow.json
sed -i "s/\${resource_group_name}/$RESOURCE_GROUP/g" workflow.json
sed -i "s/\${subscription_id}/$SUBSCRIPTION_ID/g" workflow.json
sed -i "s/\${storage_container_name}/token-reports/g" workflow.json

# Deploy workflow
az logicapp deploy --resource-group $RESOURCE_GROUP --name $LOGIC_APP_NAME --src-path .
```

#### Option B: Using PowerShell

```powershell
# Get Terraform outputs
$logicAppName = terraform output -raw logic_app_name
$resourceGroup = terraform output -raw resource_group_name
$workspaceName = terraform output -raw log_analytics_workspace_name
$subscriptionId = "your-subscription-id"

# Navigate to workflows directory
Set-Location "modules\logicapp\workflows"

# Update workflow files with actual values
(Get-Content workflow.json) -replace '\${log_analytics_workspace_name}', $workspaceName | Set-Content workflow.json
(Get-Content workflow.json) -replace '\${resource_group_name}', $resourceGroup | Set-Content workflow.json
(Get-Content workflow.json) -replace '\${subscription_id}', $subscriptionId | Set-Content workflow.json
(Get-Content workflow.json) -replace '\${storage_container_name}', 'token-reports' | Set-Content workflow.json

# Deploy workflow
Publish-AzLogicApp -ResourceGroupName $resourceGroup -Name $logicAppName -SourcePath .
```

#### Option C: Manual Upload via Azure Portal

1. Navigate to the Logic App in Azure Portal
2. Go to **Development Tools** > **Advanced Tools** 
3. Click **Go** to open Kudu
4. Navigate to **site/wwwroot**
5. Create folder structure: **TokenUsageReporting**
6. Upload the workflow files:
   - `workflow.json` (update placeholders first)
   - `connections.json` (update placeholders first) 
   - `host.json`

### Step 4: Configure API Connections

Update the connections to use Managed Identity:

1. Navigate to **Logic App** > **API connections**
2. Configure **azureblob** connection:
   - Authentication type: **Managed Identity**
   - Storage account: Use the one created by Terraform
3. Configure **azuremonitorlogs** connection:
   - Authentication type: **Managed Identity**
   - Log Analytics workspace: Use existing workspace

### Step 5: Test the Workflow

1. Go to **Logic App** > **Workflows** > **TokenUsageReporting**
2. Click **Run Trigger** to test manually
3. Monitor execution in **Run History**
4. Check the storage container for generated CSV reports
5. Verify the KQL query returns data from Log Analytics

## Configuration Options

### Modify Schedule

Edit the recurrence trigger in `workflow.json`:

```json
"recurrence": {
  "interval": 6,
  "frequency": "Hour",
  "timeZone": "UTC"
}
```

### Customize KQL Query

The default query aggregates token usage by ProductId and ModelName:

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

You can modify this to:
- Change time range (e.g., `ago(7d)` for weekly reports)
- Add additional fields (Region, CallerIpAddress, etc.)
- Filter by specific products or backends
- Extract client ID information from TraceRecords

### Report Output Location

Reports are stored in the blob container with naming pattern:
`token-usage-report_YYYY-MM-DD-HHMM.csv`

## Monitoring and Troubleshooting

### Monitor Workflow Execution
- **Logic App Overview**: Check run history and success/failure rates
- **Application Insights**: View detailed telemetry and errors
- **Log Analytics**: Query for Logic App execution logs

### Common Issues

1. **Authentication Errors**
   - Verify Managed Identity is enabled
   - Check RBAC role assignments are applied
   - Ensure API connections use correct authentication

2. **Query Failures**  
   - Validate KQL syntax in Log Analytics workspace
   - Ensure APIM diagnostic settings are configured
   - Check that log data exists for the query time range

3. **Storage Access Errors**
   - Verify blob container exists
   - Check storage account permissions
   - Ensure firewall rules allow Logic App access

### Logs and Diagnostics

Query Logic App execution logs:

```kql
// Logic App execution logs
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.WEB"
| where ResourceType == "SITES" 
| where Resource contains "logic-app-name"
| order by TimeGenerated desc

// Token usage query results
ApiManagementGatewayLogs 
| join ApiManagementGatewayLlmLog on CorrelationId
| where TimeGenerated >= ago(24h)
| where SequenceNumber == 0 and IsRequestSuccess == true
| summarize TotalTokens = sum(TotalTokens) by ProductId, ModelName
```

## Cost Optimization

- Use **Consumption** App Service Plan for lower usage scenarios
- Configure appropriate Log Analytics retention periods
- Set cool storage tier for archival report data
- Monitor Logic App execution frequency and optimize schedule

## Security Considerations

- All connections use Managed Identity (no stored credentials)
- Storage accounts block public access
- HTTPS-only traffic enforced
- RBAC permissions follow least privilege principle
- TLS 1.2 minimum encryption standard

## Integration with Existing Infrastructure

The Logic App module integrates seamlessly with the existing APIM infrastructure:

- **Reuses Log Analytics workspace** from the monitoring module
- **No impact on APIM performance** - queries historical log data
- **Separate storage** for reports doesn't affect APIM operations  
- **Optional deployment** - can be disabled by setting `deploy_logic_app = false`

This provides automated token usage reporting without requiring any changes to the existing APIM configuration or API policies.