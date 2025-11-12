# Test Embeddings API
param(
    [Parameter(Mandatory=$true)]
    [string]$GatewayUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionKey,
    
    [Parameter(Mandatory=$true)]
    [string]$DeploymentName,
    
    [string]$Text = "The quick brown fox jumps over the lazy dog"
)

# Prepare headers
$headers = @{
    'Ocp-Apim-Subscription-Key' = $SubscriptionKey
    'Content-Type' = 'application/json'
}

# Prepare request body
$body = @{
    input = $Text
} | ConvertTo-Json

# API endpoint
$uri = "$GatewayUrl/openai/deployments/$DeploymentName/embeddings?api-version=2023-05-15"

Write-Host "Testing Embeddings API..." -ForegroundColor Yellow
Write-Host "Endpoint: $uri" -ForegroundColor Cyan
Write-Host "Input Text: $Text" -ForegroundColor Cyan
Write-Host ""

try {
    # Make the API call
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -ErrorAction Stop
    
    # Display results
    Write-Host "✅ API call successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Embedding Results:" -ForegroundColor Yellow
    Write-Host "  Model: $($response.model)" -ForegroundColor Cyan
    Write-Host "  Embedding Dimension: $($response.data[0].embedding.Count)" -ForegroundColor Cyan
    Write-Host "  First 5 values: $($response.data[0].embedding[0..4] -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage Statistics:" -ForegroundColor Yellow
    Write-Host "  Prompt Tokens: $($response.usage.prompt_tokens)" -ForegroundColor Cyan
    Write-Host "  Total Tokens: $($response.usage.total_tokens)" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "❌ API call failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = [System.IO.StreamReader]::new($errorResponse)
        $errorContent = $reader.ReadToEnd()
        Write-Host "Error details: $errorContent" -ForegroundColor Red
    }
}