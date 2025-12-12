# GitHub Actions Deployment Setup

This repository contains a GitHub Actions workflow that automatically builds and deploys the ZavaStorefront .NET application as a container to Azure App Service.

## Prerequisites

Before the workflow can run successfully, you need to configure the following GitHub secrets and variables.

## Required GitHub Secrets

### 1. AZURE_CREDENTIALS
Create an Azure service principal and add its credentials as a GitHub secret.

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "github-actions-zavastorefrontapp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name} \
  --sdk-auth
```

Copy the JSON output and add it as a secret named `AZURE_CREDENTIALS`.

## Required GitHub Variables

Add the following repository variables in GitHub Settings > Secrets and variables > Actions > Variables:

- **AZURE_SUBSCRIPTION_ID**: The subscription ID that contains your resources
- **AZURE_CONTAINER_REGISTRY_NAME**: Your Azure Container Registry name (e.g., `crzavastorefrontappdev123`)
- **AZURE_APP_SERVICE_NAME**: Your App Service name (e.g., `app-zavastorefrontapp-dev-123`)
- **AZURE_RESOURCE_GROUP**: (Optional) Your Azure resource group name

> Note: You do NOT need to set `AZURE_CONTAINER_REGISTRY_URL`. The workflow resolves the ACR login server from `AZURE_CONTAINER_REGISTRY_NAME` using Azure CLI.

> Note: If you omit `AZURE_RESOURCE_GROUP`, the workflow will resolve it from `AZURE_APP_SERVICE_NAME`.

## Workflow Behavior

The workflow:
- Triggers on push to `main` branch when files in `src/` folder are changed
- Can also be manually triggered via workflow dispatch
- Builds the Docker image from the `src/Dockerfile`
- Pushes the image to Azure Container Registry with both commit SHA and `latest` tags
- Updates the App Service to use the new image
- Restarts the App Service to apply changes

## Service Principal Permissions

The service principal needs the following permissions:
- **Contributor** role on the resource group (for App Service updates)
- **AcrPush** role on the Container Registry (automatically assigned when using `az acr login`)

## Finding Your Resource Names

You can find your resource names using Azure CLI:

```bash
# List resource groups
az group list --output table

# List resources in your resource group
az resource list --resource-group {your-resource-group} --output table

# Get container registry login server
az acr show --name {your-registry-name} --query loginServer --output tsv
```