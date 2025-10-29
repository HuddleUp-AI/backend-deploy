# PaletAI Azure Deployment - Quick Reference Card

## 🚀 Deploy Infrastructure

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "YOUR_TENANT_ID" `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroupName "rg-paletai-prod" `
  -MongoDbConnectionString "mongodb://..." `
  -OpenAiApiKey "sk-..." `
  -AiProvider "openai"
```

## 📦 Deploy Application

### Method 1: GitHub Actions (Recommended)
```bash
# Get publish profile
az webapp deployment list-publishing-profiles \
  --name APP_NAME --resource-group rg-paletai-prod --xml

# Add to GitHub secrets as: AZURE_WEBAPP_PUBLISH_PROFILE
# Push to main branch → auto-deploys
```

### Method 2: ZIP Deploy
```bash
zip -r deploy.zip . -x "*.git*" "*__pycache__*" "*.pyc" "*tests/*"
az webapp deployment source config-zip \
  --resource-group rg-paletai-prod \
  --name APP_NAME \
  --src deploy.zip
```

## 🔍 Verification Commands

```bash
# Health check
curl https://APP_NAME.azurewebsites.net/health

# API docs
open https://APP_NAME.azurewebsites.net/docs

# Stream logs
az webapp log tail --name APP_NAME --resource-group rg-paletai-prod

# Download logs
az webapp log download --name APP_NAME --resource-group rg-paletai-prod
```

## ⚙️ Configuration Management

```bash
# List all settings
az webapp config appsettings list \
  --name APP_NAME --resource-group rg-paletai-prod

# Update setting
az webapp config appsettings set \
  --name APP_NAME --resource-group rg-paletai-prod \
  --settings DAILY_PROMPT_LIMIT=50

# Delete setting
az webapp config appsettings delete \
  --name APP_NAME --resource-group rg-paletai-prod \
  --setting-names SETTING_NAME
```

## 🔄 App Service Control

```bash
# Restart
az webapp restart --name APP_NAME --resource-group rg-paletai-prod

# Stop
az webapp stop --name APP_NAME --resource-group rg-paletai-prod

# Start
az webapp start --name APP_NAME --resource-group rg-paletai-prod

# SSH into container
az webapp ssh --name APP_NAME --resource-group rg-paletai-prod
```

## 📊 Monitoring

```bash
# Get deployment outputs
cat deployment-outputs-prod.json

# View metrics
az monitor metrics list \
  --resource APP_RESOURCE_ID \
  --metric CpuPercentage MemoryPercentage HttpResponseTime

# Check Application Insights
az monitor app-insights component show \
  --app APP_INSIGHTS_NAME --resource-group rg-paletai-prod
```

## 💾 Database Operations

```bash
# Backup MongoDB
mongodump --uri="CONNECTION_STRING" --out=/backup/paletai-$(date +%Y%m%d)

# Restore MongoDB
mongorestore --uri="CONNECTION_STRING" --dir=/backup/paletai-20251029

# Test connection
mongosh "CONNECTION_STRING" --eval "db.runCommand({ping: 1})"

# Count documents
mongosh "CONNECTION_STRING" --eval "db.users.countDocuments({})"
```

## 🗄️ Blob Storage

```bash
# List containers
az storage container list --account-name STORAGE_ACCOUNT

# List blobs
az storage blob list \
  --account-name STORAGE_ACCOUNT \
  --container-name game-images --output table

# Upload blob
az storage blob upload \
  --account-name STORAGE_ACCOUNT \
  --container-name game-images \
  --name test.png --file test.png

# Set public access
az storage container set-permission \
  --account-name STORAGE_ACCOUNT \
  --name game-images --public-access blob
```

## 🌐 Custom Domain Setup

```bash
# Add custom domain
az webapp config hostname add \
  --webapp-name APP_NAME \
  --resource-group rg-paletai-prod \
  --hostname api.paletai.com

# Bind SSL (if you have certificate)
az webapp config ssl upload \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --certificate-file cert.pfx

az webapp config ssl bind \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --certificate-thumbprint THUMBPRINT \
  --ssl-type SNI
```

## 📈 Scaling

```bash
# Scale App Service Plan
az appservice plan update \
  --name PLAN_NAME \
  --resource-group rg-paletai-prod \
  --sku B2

# Scale instance count (Standard tier+)
az appservice plan update \
  --name PLAN_NAME \
  --resource-group rg-paletai-prod \
  --number-of-workers 2
```

## 🧹 Cleanup

```bash
# Delete entire resource group (CAREFUL!)
az group delete --name rg-paletai-prod --yes --no-wait

# Delete specific app service
az webapp delete --name APP_NAME --resource-group rg-paletai-prod

# Delete storage account
az storage account delete \
  --name STORAGE_ACCOUNT \
  --resource-group rg-paletai-prod --yes
```

## 🔐 Security

```bash
# Get connection strings
az webapp config connection-string list \
  --name APP_NAME --resource-group rg-paletai-prod

# Get app settings (masked)
az webapp config appsettings list \
  --name APP_NAME --resource-group rg-paletai-prod

# Enable HTTPS only
az webapp update \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --https-only true

# Set minimum TLS version
az webapp config set \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --min-tls-version 1.2
```

## 💰 Cost Management

```bash
# View current costs
az consumption usage list \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --output table

# Create budget alert
az consumption budget create \
  --budget-name paletai-monthly \
  --amount 50 \
  --time-grain monthly \
  --resource-group rg-paletai-prod
```

## 🆘 Troubleshooting

```bash
# Check deployment status
az deployment group show \
  --name DEPLOYMENT_NAME \
  --resource-group rg-paletai-prod

# View deployment operations
az deployment operation group list \
  --name DEPLOYMENT_NAME \
  --resource-group rg-paletai-prod

# Get app service URL
az webapp show \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --query "defaultHostName" -o tsv

# Check if app is running
az webapp show \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --query "state" -o tsv
```

## 📋 SKU Quick Reference

| SKU | Monthly Cost | vCPU | RAM | Features |
|-----|--------------|------|-----|----------|
| B1 | $13 | 1 | 1.75GB | AlwaysOn, Custom Domains |
| B2 | $26 | 2 | 3.5GB | 2x resources |
| B3 | $52 | 4 | 7GB | 4x resources |
| S1 | $70 | 1 | 1.75GB | Auto-scale, Slots |
| P1V2 | $140 | 1 | 3.5GB | Premium performance |

## 🔑 Environment Variables

| Variable | Required | Example |
|----------|----------|---------|
| `DB_PATH` | ✅ | `mongodb://...` |
| `OPENAI_API_KEY` | * | `sk-...` |
| `ANTHROPIC_API_KEY` | * | `sk-ant-...` |
| `IS_OPENAI_ENDPOINT` | ✅ | `True` or `False` |
| `IS_ANTHROPIC_ENDPOINT` | ✅ | `True` or `False` |
| `AZURE_STORAGE_CONNECTION_STRING` | ✅ | Auto-set by Bicep |
| `ONESIGNAL_APP_ID` | ❌ | `12345...` |
| `DAILY_PROMPT_LIMIT` | ❌ | `20` |

\* At least one AI provider key required

## 📞 Quick Links

- **Deployment Guide:** [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)
- **Environment Vars:** [env-template.txt](env-template.txt)
- **Azure Portal:** https://portal.azure.com
- **GitHub Repo:** https://github.com/HuddleUp-AI/paletaibackend
