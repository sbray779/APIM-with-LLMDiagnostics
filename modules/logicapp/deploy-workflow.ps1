#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys workflow files to Azure Logic App Standard.

.DESCRIPTION
    This script uploads workflow definition files (workflow.json, connections.json, host.json)
    to the Logic App's storage account and restarts the app to load the new workflow.

.PARAMETER ResourceGroupName
    Name of the resource group containing the Logic App.

.PARAMETER LogicAppName
    Name of the Logic App Standard instance.

.EXAMPLE
    .\deploy-workflow.ps1 -ResourceGroupName "rg-apim-openai-dev" -LogicAppName "apim-token-reporting-dev"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName
)

$ErrorActionPreference = "Stop"

Write-Host "Deploying workflow to Logic App: $LogicAppName" -ForegroundColor Cyan

# CRITICAL: Set FUNCTIONS_WORKER_RUNTIME to node (Terraform forces it to dotnet)
Write-Host "`nSetting FUNCTIONS_WORKER_RUNTIME to 'node'..." -ForegroundColor Yellow
az functionapp config appsettings set `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --settings "FUNCTIONS_WORKER_RUNTIME=node" `
    --output none

Write-Host "✓ Runtime set to Node.js" -ForegroundColor Green

# Get Logic App details to find the storage account
Write-Host "`nGetting Logic App storage configuration..." -ForegroundColor Yellow
$appSettings = az functionapp config appsettings list `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --query "[?name=='AzureWebJobsStorage'].value" `
    -o tsv

if (-not $appSettings) {
    Write-Error "Failed to retrieve AzureWebJobsStorage setting from Logic App"
    exit 1
}

# Extract storage account name from connection string
$storageAccountName = ($appSettings -split "AccountName=")[1].Split(";")[0]
Write-Host "Storage Account: $storageAccountName" -ForegroundColor Green

# Get storage account key
Write-Host "Retrieving storage account key..." -ForegroundColor Yellow
$accountKey = az storage account keys list `
    --account-name $storageAccountName `
    --resource-group $ResourceGroupName `
    --query "[0].value" `
    -o tsv

if (-not $accountKey) {
    Write-Error "Failed to retrieve storage account key"
    exit 1
}

# Determine content share name
$contentShareSetting = az functionapp config appsettings list `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --query "[?name=='WEBSITE_CONTENTSHARE'].value" `
    -o tsv

$shareName = if ($contentShareSetting) { $contentShareSetting } else { "$LogicAppName-content" }
Write-Host "Content Share: $shareName" -ForegroundColor Green

# Set script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workflowsDir = Join-Path $scriptDir "workflows"

if (-not (Test-Path $workflowsDir)) {
    Write-Error "Workflows directory not found at: $workflowsDir"
    exit 1
}

# Upload host.json
Write-Host "`nUploading host.json..." -ForegroundColor Yellow
az storage file upload `
    --account-name $storageAccountName `
    --account-key $accountKey `
    --share-name $shareName `
    --source (Join-Path $workflowsDir "host.json") `
    --path "site/wwwroot/host.json" `
    --no-progress

# Upload connections.json
Write-Host "Uploading connections.json..." -ForegroundColor Yellow
az storage file upload `
    --account-name $storageAccountName `
    --account-key $accountKey `
    --share-name $shareName `
    --source (Join-Path $workflowsDir "connections.json") `
    --path "site/wwwroot/connections.json" `
    --no-progress

# Create TokenReporting directory
Write-Host "Creating TokenReporting workflow directory..." -ForegroundColor Yellow
az storage directory create `
    --account-name $storageAccountName `
    --account-key $accountKey `
    --share-name $shareName `
    --name "site/wwwroot/TokenReporting" `
    --output none 2>$null

# Upload workflow.json
Write-Host "Uploading workflow.json..." -ForegroundColor Yellow
az storage file upload `
    --account-name $storageAccountName `
    --account-key $accountKey `
    --share-name $shareName `
    --source (Join-Path $workflowsDir "TokenReporting\workflow.json") `
    --path "site/wwwroot/TokenReporting/workflow.json" `
    --no-progress

# Restart Logic App to load new workflow
Write-Host "`nRestarting Logic App to load workflow..." -ForegroundColor Yellow
az functionapp restart `
    --name $LogicAppName `
    --resource-group $ResourceGroupName

Write-Host "`n✓ Workflow deployed successfully!" -ForegroundColor Green
Write-Host "The TokenReporting workflow should now appear in the Azure Portal." -ForegroundColor Cyan
