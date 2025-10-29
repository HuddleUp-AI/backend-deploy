# PaletAI Backend - Azure Migration Guide

Complete guide for migrating PaletAI Backend from the old Azure subscription/tenant to a new subscription.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Deployment Process](#deployment-process)
4. [Application Deployment](#application-deployment)
5. [DNS and Custom Domain Migration](#dns-and-custom-domain-migration)
6. [Database Migration](#database-migration)
7. [Post-Migration Verification](#post-migration-verification)
8. [Rollback Plan](#rollback-plan)
9. [Cost Optimization](#cost-optimization)

## Prerequisites

### Required Tools

- **Azure CLI** (2.50+) or **Az PowerShell Module** (10.0+)
  ```bash
  # Install Azure CLI
  winget install Microsoft.AzureCLI

  # Install Az PowerShell
  Install-Module -Name Az -Scope CurrentUser -Force
  ```

- **Git** - For cloning the application repository
- **GitHub Account** - With access to HuddleUp-AI/paletaibackend repository

### Required Access

- **New Azure Subscription** - Contributor or Owner role
- **New Azure AD Tenant** - Application Administrator (for service principal creation)
- **Old Environment Access** - To extract configuration and data
- **MongoDB Access** - Connection strings for old and new databases

### Required Information

Gather the following from the old environment:

1. **MongoDB Connection String**
   - Location: Azure Portal → App Service → Configuration → Application Settings → `DB_PATH`

2. **AI Provider Credentials**
   - OpenAI API Key (if using OpenAI)
   - Azure OpenAI Endpoint + API Key (if using Azure OpenAI)
   - Anthropic API Key (if using Anthropic)

3. **OneSignal Configuration**
   - App ID
   - REST API Key

4. **Custom Domain Names** (if applicable)
   - Current domains pointing to the old app service
   - SSL certificates

5. **GitHub Deployment Credentials**
   - Current publish profile or service principal

## Pre-Migration Checklist

- [ ] **Backup MongoDB Database**
  ```bash
  mongodump --uri="mongodb://user:pass@host:27017/dbname" --out=/backup/paletai-$(date +%Y%m%d)
  ```

- [ ] **Document Current Configuration**
  ```bash
  # Export app settings from old environment
  az webapp config appsettings list \
    --name emailgeniebackend \
    --resource-group huddleup \
    --output json > old-app-settings.json
  ```

- [ ] **Test Database Connectivity** from your local machine or new Azure region
  ```bash
  mongosh "mongodb://user:pass@host:27017/dbname" --eval "db.runCommand({ping: 1})"
  ```

- [ ] **Verify GitHub Repository Access**
  ```bash
  git clone https://github.com/HuddleUp-AI/paletaibackend.git
  ```

- [ ] **Confirm New Subscription Limits**
  - Check quota for App Service Plans in target region
  - Verify Storage Account limits
  - Confirm available vCPU quota

- [ ] **Plan Downtime Window** (if required)
  - Notify users of maintenance window
  - Prepare status page updates

## Deployment Process

### Step 1: Prepare Deployment Files

1. Navigate to the deployment directory:
   ```powershell
   cd /mnt/d/Dev2/clients/HuddleUp/deployment
   ```

2. Review and customize `parameters.json` if needed (optional - script accepts all parameters)

### Step 2: Execute Deployment

**Option A: Using PowerShell Script (Recommended)**

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "YOUR_NEW_TENANT_ID" `
  -SubscriptionId "YOUR_NEW_SUBSCRIPTION_ID" `
  -ResourceGroupName "rg-paletai-prod" `
  -Location "westus3" `
  -Environment "prod" `
  -AppServicePlanSku "B1" `
  -MongoDbConnectionString "mongodb://user:pass@host:27017/dbname" `
  -OpenAiApiKey "sk-..." `
  -AiProvider "openai" `
  -OneSignalAppId "your-onesignal-app-id" `
  -OneSignalRestApiKey "your-onesignal-key"
```

**Option B: Using Azure CLI with Bicep**

```bash
# Login to new tenant/subscription
az login --tenant YOUR_NEW_TENANT_ID
az account set --subscription YOUR_NEW_SUBSCRIPTION_ID

# Create resource group
az group create \
  --name rg-paletai-prod \
  --location westus3

# Deploy infrastructure
az deployment group create \
  --name PaletAI-Deployment \
  --resource-group rg-paletai-prod \
  --template-file main.bicep \
  --parameters @parameters.json \
  --parameters mongoDbConnectionString="mongodb://..." \
               openAiApiKey="sk-..." \
  --verbose
```

**Deployment Time:** Approximately 3-5 minutes

### Step 3: Verify Infrastructure Deployment

```powershell
# Get deployment outputs
az deployment group show \
  --name PaletAI-Deployment \
  --resource-group rg-paletai-prod \
  --query properties.outputs

# Test app service is running (should return default Azure page initially)
curl https://YOUR_APP_SERVICE_NAME.azurewebsites.net
```

## Application Deployment

### Method 1: GitHub Actions (Recommended for Production)

1. **Get Publish Profile:**
   ```bash
   az webapp deployment list-publishing-profiles \
     --name YOUR_APP_SERVICE_NAME \
     --resource-group rg-paletai-prod \
     --xml
   ```

2. **Add GitHub Secret:**
   - Go to: https://github.com/HuddleUp-AI/paletaibackend/settings/secrets/actions
   - Create new secret: `AZURE_WEBAPP_PUBLISH_PROFILE`
   - Paste the XML from step 1

3. **Trigger Deployment:**
   - Push to main branch, or
   - Manually trigger workflow in GitHub Actions

### Method 2: Local ZIP Deploy

```bash
# From the application repository root
cd /path/to/paletaibackend

# Create deployment package
zip -r deploy.zip . \
  -x "*.git*" \
  -x "*__pycache__*" \
  -x "*.pyc" \
  -x "*tests/*" \
  -x "venv/*" \
  -x "antenv/*"

# Deploy to Azure
az webapp deployment source config-zip \
  --resource-group rg-paletai-prod \
  --name YOUR_APP_SERVICE_NAME \
  --src deploy.zip
```

### Method 3: Azure CLI with GitHub Integration

```bash
# Configure continuous deployment from GitHub
az webapp deployment source config \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --repo-url https://github.com/HuddleUp-AI/paletaibackend \
  --branch main \
  --manual-integration
```

## DNS and Custom Domain Migration

If you have custom domains (e.g., api.paletai.com):

### Step 1: Add Custom Domain to New App Service

```bash
# Add custom domain
az webapp config hostname add \
  --webapp-name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --hostname api.paletai.com

# Bind SSL certificate (if you have one)
az webapp config ssl upload \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --certificate-file /path/to/cert.pfx \
  --certificate-password YOUR_PASSWORD

az webapp config ssl bind \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --certificate-thumbprint THUMBPRINT \
  --ssl-type SNI
```

### Step 2: Update DNS Records

**Before switching (preparation):**
1. Lower TTL on current DNS records to 300 seconds (5 minutes)
2. Wait for old TTL to expire (usually 1-24 hours)

**During migration:**
```
# Update your DNS provider (NameCheap, GoDaddy, Route53, etc.)
Type: CNAME
Name: api (or @)
Value: YOUR_APP_SERVICE_NAME.azurewebsites.net
TTL: 300 seconds
```

**After migration:**
1. Verify new endpoint is working: `curl https://api.paletai.com/health`
2. Increase TTL back to 3600 (1 hour) or higher

## Database Migration

### Option 1: Continuous Sync (Zero Downtime)

If your MongoDB provider supports it:

1. **Set up replica/sync** from old to new MongoDB instance
2. **Deploy new application** pointing to new DB (read-only initially)
3. **Verify data sync** is working
4. **Switch to read-write** on new DB
5. **Update DNS** to point to new app service
6. **Stop old application**

### Option 2: Backup and Restore (Minimal Downtime)

```bash
# 1. Enable maintenance mode on old application (if possible)
az webapp stop --name emailgeniebackend --resource-group huddleup

# 2. Backup database
mongodump --uri="OLD_MONGODB_URI" --out=/backup/paletai-final

# 3. Restore to new database
mongorestore --uri="NEW_MONGODB_URI" --dir=/backup/paletai-final

# 4. Verify data
mongosh "NEW_MONGODB_URI" --eval "db.users.countDocuments({})"
mongosh "NEW_MONGODB_URI" --eval "db.games.countDocuments({})"

# 5. Update new app service to point to new MongoDB (if different)
az webapp config appsettings set \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --settings DB_PATH="NEW_MONGODB_URI"

# 6. Restart new app service
az webapp restart --name YOUR_APP_SERVICE_NAME --resource-group rg-paletai-prod
```

### Option 3: Same MongoDB Instance (Simplest)

If you're keeping the same MongoDB instance:
- No migration needed!
- Just ensure the new app service can reach the MongoDB endpoint
- Verify connection string is correct in app settings

## Post-Migration Verification

### 1. Health Check

```bash
# Test health endpoint
curl https://YOUR_APP_SERVICE_NAME.azurewebsites.net/health

# Expected response:
# {
#   "status": "healthy",
#   "version": "1.0.0",
#   "components": {
#     "database": "healthy",
#     "api": "healthy"
#   },
#   "timestamp": "2025-10-29T..."
# }
```

### 2. API Documentation

Visit: `https://YOUR_APP_SERVICE_NAME.azurewebsites.net/docs`

### 3. Test Authentication

```bash
# Register a test user
curl -X POST https://YOUR_APP_SERVICE_NAME.azurewebsites.net/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass123"}'

# Login
curl -X POST https://YOUR_APP_SERVICE_NAME.azurewebsites.net/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "testpass123"}'
```

### 4. Test Game Creation

```bash
# Use token from login response
curl -X POST https://YOUR_APP_SERVICE_NAME.azurewebsites.net/games \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"prompt": "Create a simple snake game"}'
```

### 5. Verify Blob Storage

Check that game images are being uploaded to Azure Blob Storage:

```bash
# List blobs in container
az storage blob list \
  --account-name YOUR_STORAGE_ACCOUNT_NAME \
  --container-name game-images \
  --output table
```

### 6. Test Push Notifications (if configured)

```bash
# Subscribe to notifications
curl -X POST https://YOUR_APP_SERVICE_NAME.azurewebsites.net/notifications/subscribe \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"player_id": "test-player-id"}'
```

### 7. Monitor Application Insights

- Go to Azure Portal → Application Insights → YOUR_APP_INSIGHTS_NAME
- Check Live Metrics
- Review Failures and Performance

### 8. Check Logs

```bash
# Stream application logs
az webapp log tail \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod

# Or download logs
az webapp log download \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --log-file app-logs.zip
```

## Rollback Plan

If issues are discovered after migration:

### Immediate Rollback (DNS)

```bash
# Revert DNS to old app service
# Update CNAME: api.paletai.com → emailgeniebackend.azurewebsites.net

# Restart old app service if stopped
az webapp start --name emailgeniebackend --resource-group huddleup
```

### Database Rollback

If you migrated the database:

```bash
# Restore from backup
mongorestore --uri="OLD_MONGODB_URI" --dir=/backup/paletai-backup --drop
```

### Partial Rollback (Canary)

Use Azure Traffic Manager or Application Gateway to split traffic:
- 10% to new environment
- 90% to old environment
- Gradually increase as confidence grows

## Cost Optimization

### Current vs. New Cost Comparison

**Old Environment (estimated):**
- App Service Plan: Unknown tier (likely S1 or higher) → ~$70-100/month
- Storage: Variable
- App Insights: Pay-as-you-go

**New Environment (B1 Minimum):**
- App Service Plan B1: ~$13/month
- Storage Account (LRS): ~$0.02/GB/month + transactions
- App Insights: First 5GB/month free, then $2.30/GB

**Monthly Savings: ~$50-85/month (60-85% reduction)**

### SKU Recommendations

| Environment | Users | SKU | Cost/Month | Notes |
|-------------|-------|-----|------------|-------|
| Dev/Test | <100 | B1 | $13 | Minimum for AlwaysOn |
| Staging | 100-500 | B2 | $26 | Better for load testing |
| Production (Small) | <1,000 | B1 | $13 | Start here, scale up if needed |
| Production (Medium) | 1,000-10,000 | B3 or S1 | $52-$70 | Auto-scaling with S1 |
| Production (Large) | >10,000 | S2+ or P1V2 | $140+ | Premium performance |

### Monitoring and Alerts

Set up cost alerts:

```bash
# Create budget alert at $50/month
az consumption budget create \
  --budget-name paletai-monthly-budget \
  --amount 50 \
  --time-grain monthly \
  --start-date $(date +%Y-%m-01) \
  --end-date 2026-12-31 \
  --resource-group rg-paletai-prod
```

### Scale-Up Strategy

Monitor these metrics to know when to scale:

- **CPU > 80%** for sustained periods → Scale up
- **Memory > 80%** for sustained periods → Scale up
- **Response time > 3s** consistently → Scale up
- **HTTP 5xx errors** increasing → Investigate, possibly scale

## Troubleshooting

### Common Issues

**1. Database Connection Fails**
```bash
# Check app settings
az webapp config appsettings list \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --query "[?name=='DB_PATH']"

# Test connection from app service SSH
az webapp ssh --name YOUR_APP_SERVICE_NAME --resource-group rg-paletai-prod
# Then in SSH: pip install pymongo && python -c "import pymongo; pymongo.MongoClient('YOUR_URI').admin.command('ping')"
```

**2. Application Won't Start**
```bash
# Check startup command
az webapp config show \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --query "appCommandLine"

# Should be: gunicorn app.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --timeout 600 --keep-alive 5 --log-level info
```

**3. AI Generation Fails**
```bash
# Verify API keys are set
az webapp config appsettings list \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --query "[?name=='OPENAI_API_KEY' || name=='ANTHROPIC_API_KEY']"

# Check endpoint selection
az webapp config appsettings list \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --query "[?name=='IS_OPENAI_ENDPOINT' || name=='IS_ANTHROPIC_ENDPOINT']"
```

**4. Images Not Loading**
```bash
# Verify blob storage connection
az webapp config appsettings list \
  --name YOUR_APP_SERVICE_NAME \
  --resource-group rg-paletai-prod \
  --query "[?name=='AZURE_STORAGE_CONNECTION_STRING']"

# Check container public access
az storage container show \
  --account-name YOUR_STORAGE_ACCOUNT_NAME \
  --name game-images \
  --query "properties.publicAccess"
# Should be: "blob" or "container"
```

## Support and Resources

- **Azure Documentation:** https://docs.microsoft.com/azure/app-service/
- **Bicep Documentation:** https://docs.microsoft.com/azure/azure-resource-manager/bicep/
- **Application Repository:** https://github.com/HuddleUp-AI/paletaibackend
- **Azure Support:** https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade

## Appendix: Environment Variables Reference

See `deployment/env-template.txt` for complete list of environment variables and their purposes.
