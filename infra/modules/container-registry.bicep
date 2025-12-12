// Azure Container Registry module
// Creates an Azure Container Registry with RBAC-based authentication

@description('Location for all resources')
param location string

@description('Resource tags')
param tags object

@description('Container Registry name')
param containerRegistryName string

@description('Container Registry SKU')
param sku string = 'Basic'

// Container Registry (Basic)
// Note: Basic SKU does not support some network rule and policy features.
resource containerRegistryBasic 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = if (toLower(sku) == 'basic') {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: false
  }
}

// Container Registry (Standard/Premium)
resource containerRegistryAdvanced 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = if (toLower(sku) != 'basic') {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      // Retention policy is supported on Premium; keep enabled here for non-Basic templates.
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
      softDeletePolicy: {
        retentionDays: 7
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

// Outputs
output containerRegistryName string = toLower(sku) == 'basic' ? containerRegistryBasic.name : containerRegistryAdvanced.name
output containerRegistryUrl string = toLower(sku) == 'basic' ? containerRegistryBasic.properties.loginServer : containerRegistryAdvanced.properties.loginServer
output containerRegistryId string = toLower(sku) == 'basic' ? containerRegistryBasic.id : containerRegistryAdvanced.id