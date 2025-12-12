# Azure Infrastructure for ZavaStorefront

This directory contains the Azure infrastructure code for deploying the ZavaStorefront web application using Azure Developer CLI (azd) and Bicep templates.

## Architecture Overview

The infrastructure provisions the following Azure resources:

- **Resource Group**: Contains all resources in the westus3 region
- **Azure Container Registry**: Stores Docker images with RBAC authentication (no admin passwords)
- **App Service Plan**: Linux-based hosting plan for containers
- **App Service**: Web application host with managed identity and container deployment
- **Application Insights**: Application monitoring and telemetry
- **Log Analytics Workspace**: Centralized logging
- **Azure OpenAI Service**: Microsoft Foundry with GPT-4 and Phi-3 models

## Key Features

### Security & RBAC
- Container Registry uses managed identity authentication (no passwords)
- App Service uses user-assigned managed identity for ACR pulls
- Azure OpenAI access via RBAC roles
- HTTPS-only enforcement with TLS 1.2 minimum

### Monitoring & Observability
- Application Insights integrated with App Service
- Log Analytics workspace for centralized logging
- Diagnostic settings configured for all services
- Automatic telemetry collection for .NET applications

### Modular Design
- Separate Bicep modules for each service type
- Consistent tagging and naming conventions
- Environment-specific configuration support
- Easy extension for additional environments

## File Structure

```
infra/
├── main.bicep                    # Main template orchestrating all modules
├── abbreviations.json            # Azure resource naming abbreviations
└── modules/
    ├── container-registry.bicep  # Azure Container Registry
    ├── app-service.bicep        # App Service Plan and App Service
    ├── monitoring.bicep         # Application Insights and Log Analytics
    └── foundry.bicep           # Azure OpenAI (Microsoft Foundry)
```

## Key Variables and Configuration

### Environment Configuration (.env.dev)
- `AZURE_LOCATION`: westus3 (as required)
- `APPLICATION_NAME`: zavastorefrontapp
- `ENVIRONMENT_NAME`: dev
- Security and SKU settings

### Bicep Parameters
- `environmentName`: Environment identifier (dev/staging/prod)
- `location`: Azure region (default: westus3)
- `principalId`: User or service principal for RBAC assignments
- `applicationName`: Application identifier for resource naming

## Deployment Guide

### Prerequisites
1. Azure CLI installed and authenticated
2. Azure Developer CLI (azd) installed
3. Docker installed (for local building)
4. .NET 6.0 SDK (for local development)

### Initial Deployment

1. **Initialize azd environment**:
   ```bash
   azd init
   ```

2. **Set environment variables**:
   ```bash
   azd env set AZURE_LOCATION westus3
   azd env set APPLICATION_NAME zavastorefrontapp
   ```

3. **Deploy infrastructure**:
   ```bash
   azd provision
   ```

4. **Deploy application**:
   ```bash
   azd deploy
   ```

### Manual Deployment Steps

1. **Create Resource Group**:
   ```bash
   az group create --name rg-zavastorefrontapp-dev --location westus3
   ```

2. **Deploy Bicep template**:
   ```bash
   az deployment group create \
     --resource-group rg-zavastorefrontapp-dev \
     --template-file infra/main.bicep \
     --parameters environmentName=dev \
     --parameters applicationName=zavastorefrontapp \
     --parameters principalId=$(az ad signed-in-user show --query id -o tsv)
   ```

3. **Build and push container**:
   ```bash
   # Get ACR login server
   ACR_NAME=$(az deployment group show -g rg-zavastorefrontapp-dev -n main --query properties.outputs.AZURE_CONTAINER_REGISTRY_NAME.value -o tsv)
   
   # Build and push image
   az acr build --registry $ACR_NAME --image zavastorefrontapp:latest ./src
   ```

## Microsoft Foundry Integration

The Azure OpenAI service (Microsoft Foundry) is configured with:

### Available Models
- **GPT-4**: For advanced language understanding and generation
  - Deployment: `gpt-4-deployment`
  - Version: `1106-Preview`
  - Capacity: 10 TPM (tokens per minute)

- **Phi-3 Mini**: Microsoft's efficient small language model
  - Deployment: `phi-3-mini-deployment`
  - Version: `1`
  - Capacity: 10 TPM

### Usage in Application
Add these environment variables to your App Service configuration:

```bash
AZURE_OPENAI_ENDPOINT=https://oai-zavastorefrontapp-dev.openai.azure.com/
AZURE_OPENAI_API_VERSION=2024-02-01
GPT4_DEPLOYMENT_NAME=gpt-4-deployment
PHI3_DEPLOYMENT_NAME=phi-3-mini-deployment
```

### SDK Integration Example
```csharp
// In your .NET application
services.AddSingleton<OpenAIClient>(provider =>
{
    var endpoint = configuration["AZURE_OPENAI_ENDPOINT"];
    return new OpenAIClient(new Uri(endpoint), new DefaultAzureCredential());
});
```

## Monitoring Integration

### Application Insights
- Connection string automatically configured in App Service
- .NET Agent enabled for automatic telemetry
- Custom metrics and logging available

### Log Analytics Queries
Common queries for monitoring:

```kusto
// Application performance
requests
| where timestamp > ago(1h)
| summarize avg(duration), count() by bin(timestamp, 5m)

// Container logs
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc

// OpenAI API calls
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| where Category == "RequestResponse"
```

## Environment Extension

### Adding New Environments

1. **Create new environment file**:
   ```bash
   cp .env.dev .env.staging
   # Edit values for staging environment
   ```

2. **Deploy with environment parameter**:
   ```bash
   azd provision --environment staging
   ```

3. **Update CI/CD pipeline**: Add environment-specific deployment jobs

### Scaling Considerations

For production environments, consider:

- **App Service Plan**: Upgrade to Premium V3 for auto-scaling
- **Container Registry**: Use Premium SKU for geo-replication
- **Azure OpenAI**: Increase TPM quotas based on usage
- **Application Insights**: Configure sampling for high-volume applications

## Troubleshooting

### Common Issues

1. **RBAC Permissions**: Ensure proper role assignments for managed identity
2. **Container Pull Errors**: Verify ACR permissions and image existence
3. **OpenAI Quota**: Check regional quota limits for westus3
4. **Networking**: Verify all services can communicate (especially if using private endpoints)

### Diagnostic Commands

```bash
# Check App Service logs
az webapp log tail --name app-zavastorefrontapp-dev --resource-group rg-zavastorefrontapp-dev

# Verify container registry access
az acr login --name cr-zavastorefrontapp-dev

# Test OpenAI connectivity
az cognitiveservices account list-keys --name oai-zavastorefrontapp-dev --resource-group rg-zavastorefrontapp-dev
```

This infrastructure setup provides a robust, secure, and scalable foundation for the ZavaStorefront application with comprehensive monitoring and AI capabilities through Microsoft Foundry.