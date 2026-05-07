<#
.SYNOPSIS
    Creates V2 managed API connections for Logic App with MSI authentication.

.DESCRIPTION
    This script creates Azure Monitor Logs and Azure Blob connections as V2 managed
    connections using Managed Service Identity authentication. This is required because
    Terraform's azurerm_api_connection resource doesn't properly support V2 connections
    with MSI authentication.

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER ResourceGroupName
    Resource group name where connections will be created

.PARAMETER Location
    Azure region for the connections

.PARAMETER LogicAppIdentityObjectId
    Object ID of the Logic App's managed identity (for access policies)

.EXAMPLE
    .\create-api-connections.ps1 -SubscriptionId "xxx" -ResourceGroupName "rg-name" -Location "eastus2" -LogicAppIdentityObjectId "xxx"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$Location,

    [Parameter(Mandatory=$true)]
    [string]$LogicAppIdentityObjectId
)

$ErrorActionPreference = "Stop"

Write-Host "Creating V2 API Connections with MSI Authentication..." -ForegroundColor Cyan
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host "  Logic App Identity: $LogicAppIdentityObjectId" -ForegroundColor Gray

# Get tenant ID
$tenantId = (az account show --query tenantId --output tsv)
if (-not $tenantId) {
    Write-Host "ERROR: Unable to get tenant ID. Ensure you're logged in via 'az login'" -ForegroundColor Red
    exit 1
}

# ============================================
# Create Azure Monitor Logs Connection (V2)
# ============================================
Write-Host "`nCreating Azure Monitor Logs connection..." -ForegroundColor Yellow

$azureMonitorLogsConnectionBody = @{
    location = $Location
    kind = "V2"
    properties = @{
        api = @{
            id = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/azuremonitorlogs"
        }
        parameterValueSet = @{
            name = "managedIdentityAuth"
            values = @{}
        }
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
$azureMonitorLogsConnectionBody | ConvertTo-Json -Depth 10 | Set-Content $tempFile -Encoding UTF8

$result = az rest --method PUT `
    --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azuremonitorlogs?api-version=2018-07-01-preview" `
    --headers "Content-Type=application/json" `
    --body "@$tempFile" 2>&1

Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR creating Azure Monitor Logs connection: $result" -ForegroundColor Red
    exit 1
}

# Wait for connection to provision
Start-Sleep -Seconds 5

# Add access policy for Logic App identity
Write-Host "  Adding access policy for Logic App identity..." -ForegroundColor Gray
$azureMonitorLogsAccessPolicyBody = @{
    location = $Location
    properties = @{
        principal = @{
            type = "ActiveDirectory"
            identity = @{
                tenantId = $tenantId
                objectId = $LogicAppIdentityObjectId
            }
        }
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
$azureMonitorLogsAccessPolicyBody | ConvertTo-Json -Depth 10 | Set-Content $tempFile -Encoding UTF8

$result = az rest --method PUT `
    --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azuremonitorlogs/accessPolicies/$LogicAppIdentityObjectId`?api-version=2018-07-01-preview" `
    --headers "Content-Type=application/json" `
    --body "@$tempFile" 2>&1

Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR creating Azure Monitor Logs access policy: $result" -ForegroundColor Red
    exit 1
}

Write-Host "  Azure Monitor Logs connection created successfully" -ForegroundColor Green

# ============================================
# Create Azure Blob Connection (V2)
# ============================================
Write-Host "`nCreating Azure Blob connection..." -ForegroundColor Yellow

$azureBlobConnectionBody = @{
    location = $Location
    kind = "V2"
    properties = @{
        api = @{
            id = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/azureblob"
        }
        parameterValueSet = @{
            name = "managedIdentityAuth"
            values = @{}
        }
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
$azureBlobConnectionBody | ConvertTo-Json -Depth 10 | Set-Content $tempFile -Encoding UTF8

$result = az rest --method PUT `
    --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azureblob?api-version=2018-07-01-preview" `
    --headers "Content-Type=application/json" `
    --body "@$tempFile" 2>&1

Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR creating Azure Blob connection: $result" -ForegroundColor Red
    exit 1
}

# Wait for connection to provision
Write-Host "  Waiting for connection to provision..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Add access policy for Logic App identity
Write-Host "  Adding access policy for Logic App identity..." -ForegroundColor Gray
$azureBlobAccessPolicyBody = @{
    location = $Location
    properties = @{
        principal = @{
            type = "ActiveDirectory"
            identity = @{
                tenantId = $tenantId
                objectId = $LogicAppIdentityObjectId
            }
        }
    }
}

$tempFile = [System.IO.Path]::GetTempFileName()
$azureBlobAccessPolicyBody | ConvertTo-Json -Depth 10 | Set-Content $tempFile -Encoding UTF8

$result = az rest --method PUT `
    --uri "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azureblob/accessPolicies/$LogicAppIdentityObjectId`?api-version=2018-07-01-preview" `
    --headers "Content-Type=application/json" `
    --body "@$tempFile" 2>&1

Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR creating Azure Blob access policy: $result" -ForegroundColor Red
    exit 1
}

Write-Host "  Azure Blob connection created successfully" -ForegroundColor Green

# ============================================
# Output connection IDs
# ============================================
Write-Host "`n=== Connection IDs ===" -ForegroundColor Cyan
$blobConnectionId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azureblob"
$logsConnectionId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/connections/azuremonitorlogs"

Write-Host "Blob Connection ID: $blobConnectionId" -ForegroundColor Gray
Write-Host "Logs Connection ID: $logsConnectionId" -ForegroundColor Gray

Write-Host "`nAPI Connections created successfully!" -ForegroundColor Green
