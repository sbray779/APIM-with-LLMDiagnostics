# Quick deployment script for Azure APIM with OpenAI
param(
    [string]$Environment = "dev",
    [string]$Location = "East US",
    [string]$PublisherEmail = $env:USER_EMAIL
)

Write-Host "🚀 Starting Azure APIM with OpenAI deployment..." -ForegroundColor Green
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check if Terraform is installed
try {
    $terraformVersion = terraform --version
    Write-Host "✅ Terraform is installed: $($terraformVersion[0])" -ForegroundColor Green
}
catch {
    Write-Host "❌ Terraform is not installed. Please install it first:" -ForegroundColor Red
    Write-Host "   winget install Hashicorp.Terraform" -ForegroundColor Cyan
    exit 1
}

# Check if Azure CLI is installed and authenticated
try {
    $azAccount = az account show --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI is authenticated" -ForegroundColor Green
    Write-Host "   Subscription: $($azAccount.name)" -ForegroundColor Cyan
    Write-Host "   Tenant: $($azAccount.tenantId)" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Azure CLI is not authenticated. Please login first:" -ForegroundColor Red
    Write-Host "   az login" -ForegroundColor Cyan
    exit 1
}

# Check if publisher email is provided
if (-not $PublisherEmail) {
    Write-Host "❌ Publisher email is required. Set USER_EMAIL environment variable or pass -PublisherEmail parameter" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Initialize Terraform if not already done
if (-not (Test-Path ".terraform")) {
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init
}

# Create terraform.tfvars file if it doesn't exist
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "Creating terraform.tfvars file..." -ForegroundColor Yellow
    
    $tfvarsContent = @"
environment_name = "$Environment"
location         = "$Location"
publisher_email  = "$PublisherEmail"
publisher_name   = "API Team"

# Use smaller capacity for development
gpt_model_capacity       = 10
embedding_model_capacity = 10

tags = {
  Environment = "$Environment"
  Project     = "OpenAI-APIM"
  DeployedBy  = "PowerShell Script"
}
"@
    
    $tfvarsContent | Out-File -FilePath "terraform.tfvars" -Encoding utf8
    Write-Host "✅ Created terraform.tfvars with basic configuration" -ForegroundColor Green
}

# Validate Terraform configuration
Write-Host "Validating Terraform configuration..." -ForegroundColor Yellow
$validateResult = terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform validation failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Terraform configuration is valid" -ForegroundColor Green

# Show deployment plan
Write-Host ""
Write-Host "Generating deployment plan..." -ForegroundColor Yellow
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform plan failed" -ForegroundColor Red
    exit 1
}

# Ask for confirmation
Write-Host ""
$confirmation = Read-Host "Do you want to proceed with the deployment? This may take 45+ minutes. (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

# Apply the configuration
Write-Host ""
Write-Host "🚀 Starting deployment..." -ForegroundColor Green
Write-Host "⚠️  This will take 45+ minutes due to APIM provisioning time" -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform apply failed" -ForegroundColor Red
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "   Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host ""

# Display connection information
Write-Host "📋 Connection Information:" -ForegroundColor Yellow
Write-Host ""

$gatewayUrl = terraform output -raw apim_gateway_url
$gptDeployment = terraform output -raw gpt_deployment_name
$embeddingDeployment = terraform output -raw embedding_deployment_name
$subscriptionKey = terraform output -raw subscription_key

Write-Host "APIM Gateway URL: $gatewayUrl" -ForegroundColor Cyan
Write-Host "GPT Deployment: $gptDeployment" -ForegroundColor Cyan  
Write-Host "Embedding Deployment: $embeddingDeployment" -ForegroundColor Cyan
Write-Host "Subscription Key: $($subscriptionKey.Substring(0,8))..." -ForegroundColor Cyan

Write-Host ""
Write-Host "🧪 Test URLs:" -ForegroundColor Yellow
$chatUrl = terraform output -raw test_chat_completions_url
$embeddingUrl = terraform output -raw test_embeddings_url

Write-Host "Chat Completions: $chatUrl" -ForegroundColor Cyan
Write-Host "Embeddings: $embeddingUrl" -ForegroundColor Cyan

Write-Host ""
Write-Host "🔧 Test Commands:" -ForegroundColor Yellow
Write-Host ".\examples\test-chat-completions.ps1 -GatewayUrl '$gatewayUrl' -SubscriptionKey '$subscriptionKey' -DeploymentName '$gptDeployment'" -ForegroundColor Cyan
Write-Host ".\examples\test-embeddings.ps1 -GatewayUrl '$gatewayUrl' -SubscriptionKey '$subscriptionKey' -DeploymentName '$embeddingDeployment'" -ForegroundColor Cyan

Write-Host ""
Write-Host "🌐 Azure Portal:" -ForegroundColor Yellow
$resourceGroupName = terraform output -raw resource_group_name
$subscriptionId = $azAccount.id
Write-Host "https://portal.azure.com/#@$($azAccount.tenantId)/resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/overview" -ForegroundColor Cyan

Write-Host ""
Write-Host "✅ Deployment complete! Your Azure APIM with OpenAI is ready to use." -ForegroundColor Green