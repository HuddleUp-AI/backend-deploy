<#
.SYNOPSIS
    Deploy PaletAI Backend to a new Azure subscription and tenant

.DESCRIPTION
    This script automates the complete deployment of PaletAI Backend infrastructure
    to a new Azure subscription, including resource group creation, infrastructure
    deployment, and application deployment.

.PARAMETER TenantId
    Azure AD Tenant ID for the target subscription

.PARAMETER SubscriptionId
    Azure Subscription ID for deployment

.PARAMETER ResourceGroupName
    Name of the resource group to create/use

.PARAMETER Location
    Azure region for deployment (default: westus3)

.PARAMETER Environment
    Environment name: dev, staging, or prod (default: prod)

.PARAMETER AppServicePlanSku
    App Service Plan SKU: B1, B2, B3, S1, P1V2 (default: B1)

.PARAMETER MongoDbConnectionString
    MongoDB connection string (required)

.PARAMETER OpenAiApiKey
    OpenAI API Key (optional, unless using OpenAI provider)

.PARAMETER AnthropicApiKey
    Anthropic API Key (optional, unless using Anthropic provider)

.PARAMETER AiProvider
    AI provider to use: openai, azure-openai, or anthropic (default: openai)

.PARAMETER OneSignalAppId
    OneSignal App ID for push notifications (optional)

.PARAMETER OneSignalRestApiKey
    OneSignal REST API Key (optional)

.PARAMETER DryRun
    Preview deployment without making changes

.PARAMETER WhatIf
    Show what would be deployed without actually deploying

.EXAMPLE
    .\Deploy-PaletAI.ps1 `
        -TenantId "12345678-1234-1234-1234-123456789012" `
        -SubscriptionId "87654321-4321-4321-4321-210987654321" `
        -ResourceGroupName "rg-paletai-prod" `
        -MongoDbConnectionString "mongodb://user:pass@host:27017"

.EXAMPLE
    .\Deploy-PaletAI.ps1 `
        -TenantId "12345678-1234-1234-1234-123456789012" `
        -SubscriptionId "87654321-4321-4321-4321-210987654321" `
        -ResourceGroupName "rg-paletai-dev" `
        -Location "eastus" `
        -Environment "dev" `
        -AppServicePlanSku "B1" `
        -MongoDbConnectionString "mongodb://localhost:27017" `
        -WhatIf

.NOTES
    Author: PaletAI DevOps
    Version: 1.0.0
    Requires: Az PowerShell Module 10.0+
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure AD Tenant ID")]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory = $true, HelpMessage = "Azure Subscription ID")]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true, HelpMessage = "Resource Group Name")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure Region")]
    [ValidateSet("westus3", "eastus", "eastus2", "westus", "westus2", "centralus", "northcentralus", "southcentralus", "westcentralus")]
    [string]$Location = "westus3",

    [Parameter(Mandatory = $false, HelpMessage = "Environment Name")]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "prod",

    [Parameter(Mandatory = $false, HelpMessage = "App Service Plan SKU")]
    [ValidateSet("B1", "B2", "B3", "S1", "P1V2")]
    [string]$AppServicePlanSku = "B1",

    [Parameter(Mandatory = $true, HelpMessage = "MongoDB Connection String")]
    [ValidateNotNullOrEmpty()]
    [string]$MongoDbConnectionString,

    [Parameter(Mandatory = $false, HelpMessage = "OpenAI API Key")]
    [string]$OpenAiApiKey = "",

    [Parameter(Mandatory = $false, HelpMessage = "OpenAI Model")]
    [string]$OpenAiModel = "gpt-4o",

    [Parameter(Mandatory = $false, HelpMessage = "Azure OpenAI Endpoint")]
    [string]$AzureOpenAiEndpoint = "",

    [Parameter(Mandatory = $false, HelpMessage = "Azure OpenAI API Key")]
    [string]$AzureOpenAiApiKey = "",

    [Parameter(Mandatory = $false, HelpMessage = "Azure OpenAI Model")]
    [string]$AzureOpenAiModel = "gpt-4o",

    [Parameter(Mandatory = $false, HelpMessage = "Anthropic API Key")]
    [string]$AnthropicApiKey = "",

    [Parameter(Mandatory = $false, HelpMessage = "Anthropic Model")]
    [string]$AnthropicModel = "claude-3-5-sonnet-20241022",

    [Parameter(Mandatory = $false, HelpMessage = "AI Provider")]
    [ValidateSet("openai", "azure-openai", "anthropic")]
    [string]$AiProvider = "openai",

    [Parameter(Mandatory = $false, HelpMessage = "OneSignal App ID")]
    [string]$OneSignalAppId = "",

    [Parameter(Mandatory = $false, HelpMessage = "OneSignal REST API Key")]
    [string]$OneSignalRestApiKey = "",

    [Parameter(Mandatory = $false, HelpMessage = "Enable Streaming Responses")]
    [bool]$EnableStreaming = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Daily Prompt Limit per User")]
    [int]$DailyPromptLimit = 20,

    [Parameter(Mandatory = $false, HelpMessage = "Number of Gunicorn Workers")]
    [ValidateRange(1, 20)]
    [int]$GunicornWorkers = 4,

    [Parameter(Mandatory = $false, HelpMessage = "Gunicorn Timeout in Seconds")]
    [ValidateRange(60, 1800)]
    [int]$GunicornTimeout = 600,

    [Parameter(Mandatory = $false, HelpMessage = "Preview deployment without making changes")]
    [switch]$DryRun
)

# Strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n═══ $Message ═══" -ForegroundColor Magenta
}

# Validate prerequisites
Write-Step "Validating Prerequisites"

# Check for Az module
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Error "Az PowerShell module not found. Install with: Install-Module -Name Az -Scope CurrentUser"
    exit 1
}
Write-Success "Az PowerShell module found"

# Validate AI provider configuration
Write-Step "Validating AI Provider Configuration"
switch ($AiProvider) {
    "openai" {
        if ([string]::IsNullOrWhiteSpace($OpenAiApiKey)) {
            Write-Error "OpenAI API Key is required when using 'openai' provider"
            exit 1
        }
        Write-Success "OpenAI configuration validated"
    }
    "azure-openai" {
        if ([string]::IsNullOrWhiteSpace($AzureOpenAiEndpoint) -or [string]::IsNullOrWhiteSpace($AzureOpenAiApiKey)) {
            Write-Error "Azure OpenAI Endpoint and API Key are required when using 'azure-openai' provider"
            exit 1
        }
        Write-Success "Azure OpenAI configuration validated"
    }
    "anthropic" {
        if ([string]::IsNullOrWhiteSpace($AnthropicApiKey)) {
            Write-Error "Anthropic API Key is required when using 'anthropic' provider"
            exit 1
        }
        Write-Success "Anthropic configuration validated"
    }
}

# Connect to Azure
Write-Step "Connecting to Azure"
try {
    Write-Info "Connecting to tenant: $TenantId"
    Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
    Write-Success "Connected to Azure"

    # Verify subscription
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop
    Write-Info "Subscription: $($subscription.Name)"
    Write-Info "Tenant: $($subscription.TenantId)"

    # Set context
    Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId | Out-Null
    Write-Success "Azure context set"
}
catch {
    Write-Error "Failed to connect to Azure: $_"
    exit 1
}

# Create or verify resource group
Write-Step "Managing Resource Group"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group")) {
        Write-Info "Creating resource group: $ResourceGroupName in $Location"
        if (-not $DryRun) {
            New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{
                Environment = $Environment
                Application = "PaletAI"
                ManagedBy   = "PowerShell"
                CreatedDate = (Get-Date -Format "yyyy-MM-dd")
            } | Out-Null
            Write-Success "Resource group created"
        }
        else {
            Write-Info "[DRY RUN] Would create resource group: $ResourceGroupName"
        }
    }
}
else {
    Write-Info "Resource group already exists: $ResourceGroupName"
    Write-Warning "Existing resource group location: $($rg.Location)"
    if ($rg.Location -ne $Location) {
        Write-Warning "Location mismatch! Existing: $($rg.Location), Requested: $Location"
        Write-Warning "Using existing location: $($rg.Location)"
        $Location = $rg.Location
    }
}

# Prepare deployment parameters
Write-Step "Preparing Deployment Parameters"
$deploymentParams = @{
    appName                   = "paletai"
    location                  = $Location
    environment               = $Environment
    appServicePlanSku         = $AppServicePlanSku
    gunicornWorkers           = $GunicornWorkers
    gunicornTimeout           = $GunicornTimeout
    mongoDbConnectionString   = $MongoDbConnectionString
    openAiApiKey              = $OpenAiApiKey
    openAiModel               = $OpenAiModel
    azureOpenAiEndpoint       = $AzureOpenAiEndpoint
    azureOpenAiApiKey         = $AzureOpenAiApiKey
    azureOpenAiModel          = $AzureOpenAiModel
    anthropicApiKey           = $AnthropicApiKey
    anthropicModel            = $AnthropicModel
    aiProvider                = $AiProvider
    oneSignalAppId            = $OneSignalAppId
    oneSignalRestApiKey       = $OneSignalRestApiKey
    enableStreaming           = $EnableStreaming
    dailyPromptLimit          = $DailyPromptLimit
}

Write-Info "Deployment Configuration:"
Write-Host "  App Name: paletai" -ForegroundColor White
Write-Host "  Environment: $Environment" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  App Service Plan SKU: $AppServicePlanSku" -ForegroundColor White
Write-Host "  AI Provider: $AiProvider" -ForegroundColor White
Write-Host "  Gunicorn Workers: $GunicornWorkers" -ForegroundColor White
Write-Host "  Gunicorn Timeout: $GunicornTimeout seconds" -ForegroundColor White
Write-Host "  Daily Prompt Limit: $DailyPromptLimit" -ForegroundColor White
Write-Host "  Streaming Enabled: $EnableStreaming" -ForegroundColor White

# Deploy infrastructure
Write-Step "Deploying Azure Infrastructure"
$bicepFile = Join-Path $ScriptDir "main.bicep"

if (-not (Test-Path $bicepFile)) {
    Write-Error "Bicep template not found: $bicepFile"
    exit 1
}

if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy Infrastructure")) {
    if (-not $DryRun) {
        try {
            Write-Info "Starting Bicep deployment..."
            $deployment = New-AzResourceGroupDeployment `
                -Name "PaletAI-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
                -ResourceGroupName $ResourceGroupName `
                -TemplateFile $bicepFile `
                -TemplateParameterObject $deploymentParams `
                -Verbose

            Write-Success "Infrastructure deployment completed"

            # Display outputs
            Write-Step "Deployment Outputs"
            Write-Host "App Service URL: $($deployment.Outputs.appServiceUrl.Value)" -ForegroundColor Green
            Write-Host "App Service Name: $($deployment.Outputs.appServiceName.Value)" -ForegroundColor White
            Write-Host "Storage Account: $($deployment.Outputs.storageAccountName.Value)" -ForegroundColor White
            Write-Host "Storage Container: $($deployment.Outputs.storageContainerName.Value)" -ForegroundColor White
            Write-Host "App Insights Key: $($deployment.Outputs.appInsightsInstrumentationKey.Value)" -ForegroundColor White

            # Save outputs to file
            $outputFile = Join-Path $ScriptDir "deployment-outputs-$Environment.json"
            $deployment.Outputs | ConvertTo-Json -Depth 10 | Out-File $outputFile
            Write-Success "Deployment outputs saved to: $outputFile"
        }
        catch {
            Write-Error "Deployment failed: $_"
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Info "[DRY RUN] Would deploy infrastructure to: $ResourceGroupName"
        Write-Info "[DRY RUN] Template: $bicepFile"
    }
}

# Summary
Write-Step "Deployment Summary"
if (-not $DryRun) {
    Write-Success "PaletAI Backend infrastructure deployed successfully!"
    Write-Info ""
    Write-Info "Next Steps:"
    Write-Host "  1. Deploy application code using GitHub Actions or Azure DevOps" -ForegroundColor Yellow
    Write-Host "  2. Configure custom domain (if needed)" -ForegroundColor Yellow
    Write-Host "  3. Set up GitHub deployment credentials" -ForegroundColor Yellow
    Write-Host "  4. Test the /health endpoint: $($deployment.Outputs.appServiceUrl.Value)/health" -ForegroundColor Yellow
    Write-Host "  5. Access API docs: $($deployment.Outputs.appServiceUrl.Value)/docs" -ForegroundColor Yellow
}
else {
    Write-Info "[DRY RUN] Deployment preview completed. Remove -DryRun to execute."
}

Write-Info ""
Write-Success "Script completed successfully!"
