# Updates:

11-14 Updated to take into account delays between enabling diagnostic setting enablement on the APIM instance and enabling LLM logging on the API. This ensures that the diagnostic setting enablement has completed attempting to enable LLM logging.


# Azure APIM with OpenAI Backend - Terraform

This Terraform repository deploys Azure API Management (APIM) with Azure OpenAI backend services, including comprehensive LLM logging and diagnostics capabilities using the azapi provider.

## 🏗️ Architecture Overview

The deployment creates a secure, enterprise-ready infrastructure with the following components:

- **Azure OpenAI Service**: Private deployment with GPT and embedding models
- **Azure API Management**: Gateway for OpenAI APIs with advanced policies
- **Comprehensive Monitoring**: Application Insights, Log Analytics
- **Advanced Diagnostics**: LLM-specific logging using azapi provider
- **Token Usage Reporting**: Optional Logic App for automated chargeback reports
- **Network Security**: Private endpoints, VNet integration, NSGs
- **Identity Management**: Managed identities for secure service-to-service authentication

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI**: Install and authenticate with your Azure subscription
   ```powershell
   # Install Azure CLI (if not already installed)
   winget install Microsoft.AzureCli
   
   # Login to Azure
   az login
   ```

2. **Terraform**: Install Terraform (>= 1.5)
   ```powershell
   # Install Terraform
   winget install Hashicorp.Terraform
   ```

3. **Azure Permissions**: Ensure you have the following permissions:
   - Contributor or Owner on the target subscription/resource group
   - Ability to create managed identities and role assignments

### Deployment Steps

1. **Clone and Configure**
   ```powershell
   # Clone the repository (or copy the files to your local directory)
   cd APIMDiag
   
   # Copy the example configuration
   Copy-Item "examples\terraform.tfvars.example" -Destination "terraform.tfvars"
   ```

2. **Customize Configuration**
   Edit `terraform.tfvars` with your specific requirements:
   ```hcl
   environment_name = "prod"
   location         = "East US"
   publisher_email  = "admin@yourcompany.com"
   publisher_name   = "Your Company"
   # ... additional configurations
   ```

3. **Initialize and Deploy**
   ```powershell
   # Initialize Terraform
   terraform init
   
   # Validate the configuration
   terraform validate
   
   # Plan the deployment
   terraform plan
   
   # Apply the configuration
   terraform apply -auto-approve
   ```

4. **Retrieve Connection Information**
   ```powershell
   # Get APIM gateway URL
   terraform output apim_gateway_url
   
   # Get subscription key (sensitive output)
   terraform output -raw subscription_key
   ```

## 📋 Module Structure

```
├── main.tf                 # Provider configuration
├── resources.tf           # Main resource definitions
├── variables.tf           # Input variables
├── outputs.tf            # Output values
├── LOGIC_APP_INTEGRATION.md  # Logic App deployment guide
├── modules/
│   ├── networking/       # VNet, subnets, NSGs, private DNS
│   ├── openai/          # Azure OpenAI service and deployments
│   ├── apim/            # API Management service and configuration
│   ├── monitoring/      # Log Analytics, App Insights
│   ├── diagnostics/     # APIM diagnostics using azapi provider
│   └── logicapp/        # Logic App for token usage reporting (optional)
│       ├── workflows/   # Logic App workflow definitions
│       └── README.md    # Module-specific documentation
└── examples/
    └── terraform.tfvars.example  # Example configuration
```

## 🔧 Configuration Options

### Core Configuration

| Variable | Description | Default | Options |
|----------|-------------|---------|---------|
| `environment_name` | Environment identifier | `dev` | Any alphanumeric string |
| `location` | Azure region | `East US` | Any valid Azure region |
| `publisher_email` | APIM publisher email | `admin@company.com` | Valid email address |

### Logic App Token Usage Reporting (Optional)

| Variable | Description | Default | Required When Enabled |
|----------|-------------|---------|---------------------|
| `deploy_logic_app` | Enable Logic App deployment | `false` | Set to `true` to enable |
| `logic_app_service_plan_sku` | App Service Plan SKU for Logic App | `WS1` | WS1/WS2/WS3 or EP1/EP2/EP3 |
| `logic_app_storage_container_name` | Container for reports | `token-reports` | Optional |
| `logic_app_always_on` | Keep Logic App always on | `true` | Optional |

**Note**: The Logic App automatically creates a dedicated App Service Plan with the specified SKU (Workflow Standard or Elastic Premium). See [LOGIC_APP_INTEGRATION.md](LOGIC_APP_INTEGRATION.md) for detailed setup instructions.

### API Management SKUs

| SKU | Description | Use Case | Capacity |
|-----|-------------|----------|----------|
| `Developer` | Development/testing | Non-production | 1 unit |
| `Standard` | Production workloads | Standard production | 1-10 units |
| `Premium` | Enterprise features | High availability | 1-10 units |

### OpenAI Models

#### Supported GPT Models
- `gpt-4o-mini` (Default - Version: 2024-07-18) ⭐ **Cost-Effective & Recommended**
- `gpt-4o` (Full capability version)
- `gpt-4-turbo` (Previous generation)
- `gpt-35-turbo` (Legacy - consider upgrading)
- `gpt-35-turbo-16k`
- `gpt-4`
- `gpt-4-32k`

#### Supported Embedding Models
- `text-embedding-3-small` (Default - Version: 1) ⭐ **Latest & Recommended**
- `text-embedding-3-large` (Higher capability, more dimensions)
- `text-embedding-ada-002` (Legacy - consider upgrading)

> **Note**: The configuration now defaults to cost-effective yet capable models (`gpt-4o-mini` and `text-embedding-3-small`) which offer excellent performance-to-cost ratio. GPT-4o-mini provides nearly the same capabilities as GPT-4o at a significantly lower cost, while the new embedding models provide better multi-language performance and support adjustable dimensions for cost optimization.

## 🔒 Security Features

### Network Security
- **Private Endpoints**: All services use private endpoints
- **VNet Integration**: APIM integrated with virtual network
- **NSG Rules**: Restrictive network security group rules
- **Private DNS**: Private DNS zones for service resolution

### Identity and Access Management
- **Managed Identities**: User-assigned identities for APIM and Function App
- **RBAC**: Role-based access control for OpenAI service
- **Key Vault**: Secure storage of secrets and API keys
- **Certificate Validation**: TLS certificate chain validation

### API Security
- **Subscription Keys**: Required for API access
- **Rate Limiting**: Built-in throttling policies
- **IP Filtering**: Optional IP address restrictions
- **Data Masking**: Sensitive headers masked in logs

## 📊 Monitoring and Diagnostics

### Comprehensive Logging
The deployment includes advanced diagnostics using the azapi provider:

- **Service-Level Diagnostics**: Overall APIM service monitoring
- **API-Level Diagnostics**: OpenAI API specific logging
- **Operation-Level Diagnostics**: Individual operation tracking
  - Chat Completions (65KB request/response logging)
  - Completions (65KB request/response logging)
  - Embeddings (32KB request/response logging)

### Log Analytics Queries

Query token usage by subscription:
```kusto
ApiManagementGatewayLogs
| where OperationName in ("ChatCompletions_Create", "Completions_Create")
| extend RequestBody = parse_json(RequestBody)
| extend ResponseBody = parse_json(ResponseBody)
| extend PromptTokens = toint(ResponseBody.usage.prompt_tokens)
| extend CompletionTokens = toint(ResponseBody.usage.completion_tokens)
| extend TotalTokens = toint(ResponseBody.usage.total_tokens)
| summarize 
    TotalRequests = count(),
    TotalPromptTokens = sum(PromptTokens),
    TotalCompletionTokens = sum(CompletionTokens),
    TotalTokens = sum(TotalTokens)
by SubscriptionId, OperationName
```

### Event Hub Integration
- Real-time streaming of API requests/responses
- Integration with Azure Functions for token calculation
- Custom event processing for chargeback scenarios

## 🧪 Testing the Deployment

### Test Chat Completions
```powershell
# Set variables from Terraform outputs
$gatewayUrl = terraform output -raw apim_gateway_url
$subscriptionKey = terraform output -raw subscription_key
$gptDeployment = terraform output -raw gpt_deployment_name

# Test chat completions
$headers = @{
    'Ocp-Apim-Subscription-Key' = $subscriptionKey
    'Content-Type' = 'application/json'
}

$body = @{
    messages = @(
        @{ role = "system"; content = "You are a helpful assistant." }
        @{ role = "user"; content = "Hello, how are you?" }
    )
    max_tokens = 100
    temperature = 0.7
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "$gatewayUrl/openai/deployments/$gptDeployment/chat/completions?api-version=2023-05-15" -Method POST -Headers $headers -Body $body

Write-Output $response.choices[0].message.content
```

### Test Embeddings
```powershell
$embeddingDeployment = terraform output -raw embedding_deployment_name

$body = @{
    input = "The quick brown fox jumps over the lazy dog"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$gatewayUrl/openai/deployments/$embeddingDeployment/embeddings?api-version=2023-05-15" -Method POST -Headers $headers -Body $body

Write-Output "Embedding dimension: $($response.data[0].embedding.Count)"
```

## 🔧 Customization

### Adding Custom Policies

To add custom APIM policies, modify the `modules/apim/main.tf` file:

```hcl
resource "azurerm_api_management_api_policy" "openai" {
  # ... existing configuration
  
  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <!-- Add your custom policies here -->
        <rate-limit calls="100" renewal-period="60" />
        <quota calls="1000" renewal-period="3600" />
    </inbound>
    <!-- ... rest of policy -->
</policies>
XML
}
```

### Environment-Specific Configurations

Create environment-specific `.tfvars` files:

```
environments/
├── dev.tfvars
├── staging.tfvars
└── prod.tfvars
```

Deploy with: `terraform apply -var-file="environments/prod.tfvars"`

## 🚨 Troubleshooting

### Common Issues

1. **APIM Deployment Timeout**
   - APIM deployment can take 45+ minutes
   - Check Azure portal for deployment status
   - Ensure subnet has sufficient address space

2. **OpenAI Model Availability**
   - Verify model availability in target region
   - Check Azure OpenAI quotas
   - Ensure proper permissions for model deployment

3. **Private Endpoint Resolution**
   - Verify private DNS zone configuration
   - Check VNet links to DNS zones
   - Ensure NSG rules allow traffic

4. **Authentication Issues**
   - Verify managed identity permissions
   - Check Key Vault access policies
   - Validate RBAC assignments

### Debug Commands

```powershell
# Check Terraform state
terraform state list

# Show specific resource
terraform state show module.apim.azurerm_api_management.main

# Import existing resource (if needed)
terraform import azurerm_resource_group.main /subscriptions/{subscription-id}/resourceGroups/{rg-name}

# Force refresh
terraform refresh
```

## 🧹 Cleanup

To destroy all resources:

```powershell
terraform destroy -auto-approve
```

**Warning**: This will permanently delete all resources. Ensure you have backups of any important data.

## 📈 Cost Optimization

### Resource Costs (Approximate monthly costs in East US)

| Resource | SKU | Estimated Cost |
|----------|-----|----------------|
| API Management (Developer) | 1 unit | $50 |
| Azure OpenAI (30K TPM) | S0 | $900* |
| Log Analytics (5GB/month) | PerGB2018 | $12 |
| Event Hub (Standard) | 1 TU | $22 |
| VNet & Private Endpoints | Standard | $15 |

*Actual OpenAI costs depend on usage (tokens consumed)

### Cost Optimization Tips

1. **Right-size APIM SKU**: Use Developer for non-prod
2. **Monitor Token Usage**: Set up alerts for high consumption
3. **Log Retention**: Adjust retention periods based on compliance needs
4. **Reserved Capacity**: Consider reserved instances for predictable workloads

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🔗 Additional Resources

- [Azure OpenAI Service Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Azure APIM Policies Reference](https://docs.microsoft.com/azure/api-management/api-management-policies)

---

**Note**: This deployment creates production-ready infrastructure with private endpoints and comprehensive monitoring. Always review security configurations and adjust based on your organization's requirements.