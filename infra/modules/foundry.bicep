// Microsoft Foundry (Azure OpenAI) module
// Provisions Azure OpenAI service with GPT-4 and Phi models

@description('Location for all resources')
param location string

@description('Resource tags')
param tags object

@description('Azure OpenAI account name')
param openAIAccountName string

@description('Principal ID for RBAC assignment')
param principalId string

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Azure OpenAI SKU')
param sku string = 'S0'

@description('Whether to deploy the Phi-3 model deployment (availability can be region/subscription dependent)')
param deployPhi3 bool = false

@description('Phi-3 model name')
param phi3ModelName string = 'Phi-3-mini-4k-instruct'

@description('Phi-3 model version (see Azure Portal for supported versions)')
param phi3ModelVersion string = '15'

@description('Phi-3 model format (some regions/accounts require Microsoft-published model format)')
param phi3ModelFormat string = 'Microsoft'

@description('Phi-3 model publisher')
param phi3ModelPublisher string = 'Microsoft'

// Azure OpenAI Service
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAIAccountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: openAIAccountName
    // Enforce identity-only access (disables API key auth)
    disableLocalAuth: true
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

// GPT-4 Deployment
resource gpt4Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAIAccount
  name: 'gpt-4.1-deployment'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
      version: '2025-04-14'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

// Phi-3 Mini Deployment (Microsoft's small language model)
resource phi3Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = if (deployPhi3) {
  parent: openAIAccount
  name: 'phi-3-mini-deployment'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: phi3ModelFormat
      name: phi3ModelName
      publisher: phi3ModelPublisher
      version: phi3ModelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 10
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    gpt4Deployment
  ]
}

// Assign Cognitive Services OpenAI User role to the principal
resource openAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  scope: openAIAccount
  name: guid(openAIAccount.id, principalId, 'cognitiveservicesopenaiuser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User role
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings for Azure OpenAI
resource openAIDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: openAIAccount
  name: 'diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RequestResponse'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Trace'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Outputs
output openAIAccountName string = openAIAccount.name
output openAIEndpoint string = openAIAccount.properties.endpoint
output openAIAccountId string = openAIAccount.id
output gpt4DeploymentName string = gpt4Deployment.name
output phi3DeploymentName string = deployPhi3 ? phi3Deployment.name : ''
