# Test Chat Completions API
param(
    [Parameter(Mandatory=$true)]
    [string]$GatewayUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionKey,
    
    [Parameter(Mandatory=$true)]
    [string]$DeploymentName,
    
    [string]$Message = "Hello! Can you explain what Azure OpenAI is?",
    [int]$MaxTokens = 150,
    [double]$Temperature = 0.7
)

# Prepare headers
$headers = @{
    'Ocp-Apim-Subscription-Key' = $SubscriptionKey
    'Content-Type' = 'application/json'
}

# Prepare request body
$body = @{
    messages = @(
        @{ 
            role = "system"
            content = "You are a helpful AI assistant."
        },
        @{
            role = "user"
            content = $Message
        }
    )
    max_tokens = $MaxTokens
    temperature = $Temperature
    stream = $false
} | ConvertTo-Json -Depth 10

# API endpoint
$uri = "$GatewayUrl/openai/deployments/$DeploymentName/chat/completions?api-version=2023-05-15"

Write-Host "Testing Chat Completions API..." -ForegroundColor Yellow
Write-Host "Endpoint: $uri" -ForegroundColor Cyan
Write-Host "Message: $Message" -ForegroundColor Cyan
Write-Host ""

try {
    # Make the API call
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -ErrorAction Stop
    
    # Display results
    Write-Host "✅ API call successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Yellow
    Write-Host $response.choices[0].message.content -ForegroundColor White
    Write-Host ""
    Write-Host "Usage Statistics:" -ForegroundColor Yellow
    Write-Host "  Prompt Tokens: $($response.usage.prompt_tokens)" -ForegroundColor Cyan
    Write-Host "  Completion Tokens: $($response.usage.completion_tokens)" -ForegroundColor Cyan
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