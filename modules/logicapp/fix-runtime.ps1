#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes the Logic App runtime by setting FUNCTIONS_WORKER_RUNTIME to 'node'.

.DESCRIPTION
    The Terraform azurerm_logic_app_standard provider has a bug where it forces
    FUNCTIONS_WORKER_RUNTIME to 'dotnet' even though Logic Apps Standard workflows
    require Node.js runtime. This script corrects the setting.

.PARAMETER ResourceGroupName
    Name of the resource group containing the Logic App.

.PARAMETER LogicAppName
    Name of the Logic App Standard instance.

.EXAMPLE
    .\fix-runtime.ps1 -ResourceGroupName "rg-apim-openai-dev-x7zrb4go" -LogicAppName "apim-token-reporting-dev-x7zrb4go-b89dd"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName
)

$ErrorActionPreference = "Stop"

Write-Host "Fixing Logic App runtime configuration..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Logic App: $LogicAppName" -ForegroundColor White

# Check current runtime setting
Write-Host "`nChecking current FUNCTIONS_WORKER_RUNTIME..." -ForegroundColor Yellow
$currentRuntime = az functionapp config appsettings list `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --query "[?name=='FUNCTIONS_WORKER_RUNTIME'].value" `
    -o tsv

if ($currentRuntime) {
    Write-Host "Current runtime: $currentRuntime" -ForegroundColor White
} else {
    Write-Host "FUNCTIONS_WORKER_RUNTIME not set" -ForegroundColor White
}

# Set to node
Write-Host "`nSetting FUNCTIONS_WORKER_RUNTIME to 'node'..." -ForegroundColor Yellow
az functionapp config appsettings set `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --settings "FUNCTIONS_WORKER_RUNTIME=node" `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set FUNCTIONS_WORKER_RUNTIME"
    exit 1
}

Write-Host "✓ FUNCTIONS_WORKER_RUNTIME set to 'node'" -ForegroundColor Green

# Restart Logic App to apply changes
Write-Host "`nRestarting Logic App to apply changes..." -ForegroundColor Yellow
az functionapp restart `
    --name $LogicAppName `
    --resource-group $ResourceGroupName

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to restart Logic App"
    exit 1
}

Write-Host "✓ Logic App restarted successfully" -ForegroundColor Green

# Verify the change
Write-Host "`nVerifying runtime setting..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$newRuntime = az functionapp config appsettings list `
    --name $LogicAppName `
    --resource-group $ResourceGroupName `
    --query "[?name=='FUNCTIONS_WORKER_RUNTIME'].value" `
    -o tsv

if ($newRuntime -eq "node") {
    Write-Host "✓ Verified: FUNCTIONS_WORKER_RUNTIME = $newRuntime" -ForegroundColor Green
    Write-Host "`n✓✓✓ Runtime fix completed successfully! ✓✓✓" -ForegroundColor Green
} else {
    Write-Warning "Runtime is set to '$newRuntime' but expected 'node'"
    Write-Warning "You may need to set it manually in the Azure Portal"
}
