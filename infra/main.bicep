// Main infrastructure template for ZavaStorefront
// This template provisions all required Azure resources for the development environment

@description('Environment name (dev, staging, prod)')
param environmentName string = 'dev'

@description('Primary location for all resources')
param location string = 'westus3'

@description('Unique suffix for resource naming')
param resourceToken string = uniqueString(subscription().subscriptionId, resourceGroup().id)

@description('Application name for resource naming')
param applicationName string = 'zavastorefrontapp'

// Variables for resource naming
var abbrs = loadJsonContent('./abbreviations.json')
var tags = {
  'azd-env-name': environmentName
  'azd-project': applicationName
  'azd-service-name': 'web'
  environment: environmentName
  application: applicationName
}

// Container Registry module
module containerRegistry './modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    tags: tags
    containerRegistryName: '${abbrs.containerRegistry}${applicationName}${resourceToken}'
  }
}

// Application Insights module
module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    applicationInsightsName: '${abbrs.applicationInsights}${applicationName}-${environmentName}'
    logAnalyticsWorkspaceName: '${abbrs.logAnalyticsWorkspace}${applicationName}-${environmentName}'
  }
}

// App Service module  
module appService './modules/app-service.bicep' = {
  name: 'app-service'
  params: {
    location: location
    tags: tags
    appServicePlanName: '${abbrs.appServicePlan}${applicationName}-${environmentName}'
    appServiceName: '${abbrs.appService}${applicationName}-${environmentName}'
    containerRegistryName: containerRegistry.outputs.containerRegistryName
    containerRegistryUrl: containerRegistry.outputs.containerRegistryUrl
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Microsoft Foundry module (Azure OpenAI)
module foundry './modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    tags: tags
    openAIAccountName: '${abbrs.openAIAccount}${applicationName}-${environmentName}'
    principalId: appService.outputs.systemAssignedPrincipalId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Outputs for AZD and other tools
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId

output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.containerRegistryName
output AZURE_CONTAINER_REGISTRY_URL string = containerRegistry.outputs.containerRegistryUrl

output AZURE_APP_SERVICE_NAME string = appService.outputs.appServiceName
output AZURE_APP_SERVICE_URL string = appService.outputs.appServiceUrl
output AZURE_APP_SERVICE_PLAN_NAME string = appService.outputs.appServicePlanName

output APPLICATION_INSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.logAnalyticsWorkspaceName

output AZURE_OPENAI_ACCOUNT_NAME string = foundry.outputs.openAIAccountName
output AZURE_OPENAI_ENDPOINT string = foundry.outputs.openAIEndpoint