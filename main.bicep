// PaletAI Backend - Complete Azure Infrastructure
// Minimum cost configuration with B1 App Service Plan

@description('Name of the application (will be used as prefix for resources)')
param appName string = 'paletai'

@description('Azure region for deployment')
param location string = 'westus3'

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('App Service Plan SKU')
@allowed([
  'B1'   // Basic - Minimum for AlwaysOn, Custom Domains ($13/month)
  'B2'   // Basic - More CPU/Memory
  'B3'   // Basic - Even more CPU/Memory
  'S1'   // Standard - Auto-scaling support
  'P1V2' // Premium - Enhanced performance
])
param appServicePlanSku string = 'B1'

@description('Number of workers for Gunicorn')
param gunicornWorkers int = 4

@description('Timeout for Gunicorn in seconds')
param gunicornTimeout int = 600

@description('MongoDB connection string (required - not stored in template)')
@secure()
param mongoDbConnectionString string

@description('OpenAI API Key (if using OpenAI)')
@secure()
param openAiApiKey string = ''

@description('OpenAI Model name')
param openAiModel string = 'gpt-4o'

@description('Azure OpenAI Endpoint (if using Azure OpenAI)')
param azureOpenAiEndpoint string = ''

@description('Azure OpenAI API Key (if using Azure OpenAI)')
@secure()
param azureOpenAiApiKey string = ''

@description('Azure OpenAI Model deployment name')
param azureOpenAiModel string = 'gpt-4o'

@description('Anthropic API Key (if using Anthropic)')
@secure()
param anthropicApiKey string = ''

@description('Anthropic Model name')
param anthropicModel string = 'claude-3-5-sonnet-20241022'

@description('Which AI endpoint to use (openai or anthropic)')
@allowed([
  'openai'
  'azure-openai'
  'anthropic'
])
param aiProvider string = 'openai'

@description('OneSignal App ID for push notifications')
param oneSignalAppId string = ''

@description('OneSignal REST API Key')
@secure()
param oneSignalRestApiKey string = ''

@description('Enable streaming responses')
param enableStreaming bool = false

@description('Daily prompt limit per user')
param dailyPromptLimit int = 20

@description('Tags to apply to all resources')
param tags object = {
  Application: 'PaletAI'
  Environment: environment
  ManagedBy: 'Bicep'
}

// Generate unique resource names
var uniqueSuffix = uniqueString(resourceGroup().id)
var appServicePlanName = '${appName}-plan-${environment}-${uniqueSuffix}'
var appServiceName = '${appName}-api-${environment}-${uniqueSuffix}'
var storageAccountName = '${toLower(appName)}${toLower(environment)}${uniqueSuffix}'
var appInsightsName = '${appName}-insights-${environment}-${uniqueSuffix}'

// Storage Account for Azure Blob Storage (game images)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: take(storageAccountName, 24) // Storage account names must be 24 chars or less
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS' // Locally redundant storage (cheapest)
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true // Required for public game image access
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Blob service for storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'HEAD'
            'OPTIONS'
          ]
          maxAgeInSeconds: 3600
          exposedHeaders: [
            '*'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      ]
    }
  }
}

// Container for game images
resource gameImagesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'game-images'
  properties: {
    publicAccess: 'Blob' // Allow public read access to blobs
  }
}

// Application Insights for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanSku == 'B1' || appServicePlanSku == 'B2' || appServicePlanSku == 'B3' ? 'Basic' : (appServicePlanSku == 'S1' ? 'Standard' : 'PremiumV2')
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
  }
}

// App Service (Web App)
resource appService 'Microsoft.Web/sites@2024-04-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      alwaysOn: true
      numberOfWorkers: 1
      http20Enabled: false
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      appCommandLine: 'gunicorn app.main:app --workers ${gunicornWorkers} --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --timeout ${gunicornTimeout} --keep-alive 5 --log-level info'
      appSettings: [
        {
          name: 'DB_PATH'
          value: mongoDbConnectionString
        }
        {
          name: 'OPENAI_API_KEY'
          value: openAiApiKey
        }
        {
          name: 'OPENAI_MODEL'
          value: openAiModel
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: azureOpenAiEndpoint
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: azureOpenAiApiKey
        }
        {
          name: 'AZURE_OPENAI_MODEL'
          value: azureOpenAiModel
        }
        {
          name: 'ANTHROPIC_API_KEY'
          value: anthropicApiKey
        }
        {
          name: 'ANTHROPIC_MODEL'
          value: anthropicModel
        }
        {
          name: 'IS_ANTHROPIC_ENDPOINT'
          value: aiProvider == 'anthropic' ? 'True' : 'False'
        }
        {
          name: 'IS_OPENAI_ENDPOINT'
          value: aiProvider == 'openai' || aiProvider == 'azure-openai' ? 'True' : 'False'
        }
        {
          name: 'IS_LOCAL_ENV'
          value: 'False' // Always use Azure Blob Storage in deployed environments
        }
        {
          name: 'ENABLE_STREAMING'
          value: enableStreaming ? 'True' : 'False'
        }
        {
          name: 'STREAMING_THINKING_TOKENS'
          value: '16000'
        }
        {
          name: 'ONESIGNAL_APP_ID'
          value: oneSignalAppId
        }
        {
          name: 'ONESIGNAL_REST_API_KEY'
          value: oneSignalRestApiKey
        }
        {
          name: 'ONESIGNAL_API_URL'
          value: 'https://api.onesignal.com'
        }
        {
          name: 'AZURE_STORAGE_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'AZURE_STORAGE_CONTAINER'
          value: 'game-images'
        }
        {
          name: 'DAILY_PROMPT_LIMIT'
          value: string(dailyPromptLimit)
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '3'
        }
      ]
    }
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

// Output values for reference
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceName string = appService.name
output storageAccountName string = storageAccount.name
output storageContainerName string = gameImagesContainer.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output resourceGroupName string = resourceGroup().name
