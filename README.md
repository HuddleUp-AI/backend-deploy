# PaletAI Backend - Azure Deployment Repository

Complete Azure infrastructure deployment for PaletAI Backend with cost optimization and migration tools.

## 🎯 Purpose

This repository contains everything needed to deploy PaletAI Backend to a new Azure subscription/tenant with minimal cost configuration (B1 App Service Plan - $13/month).

**Use Case:** Migrating from old Azure subscription to new subscription/tenant while reducing costs by 70-85%.

## 📁 Repository Contents

| File | Purpose | Audience |
|------|---------|----------|
| **PM-INTRODUCTION.md** | Non-technical overview & business case | 📋 Product Managers |
| **MIGRATION-GUIDE.md** | Complete step-by-step migration guide | 🔧 DevOps Engineers |
| **MIGRATION-CHECKLIST.md** | Day-of-migration execution checklist | 🔧 DevOps Engineers |
| **Deploy-PaletAI.ps1** | Automated deployment script | 🔧 DevOps Engineers |
| **main.bicep** | Azure infrastructure template (IaC) | 🔧 DevOps Engineers |
| **QUICK-REFERENCE.md** | Common commands reference card | 🔧 DevOps Engineers |
| **env-template.txt** | Environment variables reference | 🔧 DevOps Engineers |
| **parameters.json** | Default deployment parameters | 🔧 DevOps Engineers |
| **README.md** | Repository overview | 👥 Everyone |

## 🚀 Quick Start

### Prerequisites

- **Azure PowerShell Module** (`Install-Module -Name Az`) or **Azure CLI**
- **Contributor/Owner** access to target Azure subscription
- **MongoDB connection string**
- **AI provider API key** (OpenAI, Azure OpenAI, or Anthropic)

### Deploy in 3 Commands

```powershell
# 1. Clone this repository
git clone https://github.com/HuddleUp-AI/backend-deploy.git
cd backend-deploy

# 2. Run deployment script
.\Deploy-PaletAI.ps1 `
  -TenantId "YOUR_TENANT_ID" `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroupName "rg-paletai-prod" `
  -MongoDbConnectionString "mongodb://..." `
  -OpenAiApiKey "sk-..." `
  -AiProvider "openai"

# 3. Deploy application code (see MIGRATION-GUIDE.md)
```

**Total Time:** ~8 minutes (5 min infrastructure + 3 min application)

## 💰 Cost Savings

| Environment | Monthly Cost | Savings |
|-------------|--------------|---------|
| **Old Subscription** | $70-100/month | - |
| **New Subscription (B1)** | $15-16/month | **$55-85/month** |

**Annual Savings:** $660-$1,020/year (70-85% reduction)

## 📖 Documentation

### For Product Managers
- **[PM-INTRODUCTION.md](PM-INTRODUCTION.md)** - 📋 **Non-technical overview** - Business value, timeline, risks, stakeholder communication

### Getting Started (Technical)
1. **[README.md](README.md)** - Quick overview and deployment scenarios
2. **[MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)** - Comprehensive migration guide (START HERE for engineers)
3. **[MIGRATION-CHECKLIST.md](MIGRATION-CHECKLIST.md)** - Day-of-migration execution checklist

### Reference
- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Command reference card
- **[env-template.txt](env-template.txt)** - Environment variables documentation

## 🏗️ What Gets Deployed

### Azure Resources

- **App Service Plan (B1)** - Linux, Python 3.12
  - 1 vCPU, 1.75GB RAM
  - AlwaysOn enabled
  - Custom domain support

- **App Service (Web App)** - PaletAI Backend API
  - Python 3.12 runtime
  - Gunicorn + Uvicorn (ASGI)
  - HTTPS only, TLS 1.2+
  - Configured for FastAPI

- **Storage Account (LRS)** - Game image storage
  - Blob container: `game-images`
  - Public blob access enabled
  - CORS configured for web access

- **Application Insights** - Monitoring and diagnostics
  - Live metrics
  - Performance tracking
  - Error logging

### Estimated Monthly Costs

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| App Service Plan | B1 | $13.00 |
| Storage Account | Standard LRS | $1-2.00 |
| Application Insights | Pay-as-you-go | $0-1.00 (5GB free) |
| **Total** | | **~$15-16** |

## ⚙️ Configuration

### Supported Azure Regions

- `westus3` (default - newest, cost-effective)
- `eastus` (established, highly available)
- `westus2`, `centralus`, `eastus2`, etc.

### App Service Plan SKUs

| SKU | Monthly Cost | Use Case |
|-----|--------------|----------|
| **B1** | $13 | ✅ Recommended for most workloads |
| B2 | $26 | Higher traffic, more CPU/RAM |
| B3 | $52 | High performance requirements |
| S1 | $70 | Auto-scaling, staging slots |
| P1V2 | $140 | Premium performance |

### AI Provider Options

- **OpenAI** (GPT-4o, GPT-4 Turbo, GPT-3.5)
- **Azure OpenAI** (GPT-4o, GPT-4)
- **Anthropic** (Claude 3.5 Sonnet, Claude 3 Opus)

Choose provider via `-AiProvider` parameter.

## 🔧 Common Operations

### Deploy to Different Region

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "..." `
  -SubscriptionId "..." `
  -ResourceGroupName "rg-paletai-eastus" `
  -Location "eastus" `
  -MongoDbConnectionString "..." `
  -OpenAiApiKey "..."
```

### Deploy Development Environment

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "..." `
  -SubscriptionId "..." `
  -ResourceGroupName "rg-paletai-dev" `
  -Environment "dev" `
  -AppServicePlanSku "B1" `
  -MongoDbConnectionString "..." `
  -AnthropicApiKey "..." `
  -AiProvider "anthropic"
```

### Scale Up/Down

```bash
# Scale to B2 (2 vCPU, 3.5GB RAM)
az appservice plan update \
  --name PLAN_NAME \
  --resource-group rg-paletai-prod \
  --sku B2

# Scale back to B1
az appservice plan update \
  --name PLAN_NAME \
  --resource-group rg-paletai-prod \
  --sku B1
```

## 📋 Migration Process Overview

1. **Pre-Migration** (1-2 days before)
   - Gather credentials and connection strings
   - Backup MongoDB database
   - Test connectivity from new region
   - Lower DNS TTL (if using custom domain)

2. **Deploy Infrastructure** (~5 minutes)
   - Run `Deploy-PaletAI.ps1` script
   - Verify resources created in Azure Portal

3. **Deploy Application** (~3 minutes)
   - GitHub Actions (recommended) or ZIP deploy
   - Verify health endpoint

4. **Database Migration** (varies)
   - Same MongoDB: No migration needed
   - New MongoDB: Backup/restore
   - Zero downtime: Use continuous sync

5. **DNS Cutover** (if applicable)
   - Update CNAME to new app service
   - Wait for propagation (5-60 minutes)

6. **Verification** (~30 minutes)
   - Test all endpoints
   - Monitor Application Insights
   - Verify user functionality

7. **Decommission Old Environment** (after 24-48 hours)
   - Stop old app service
   - Delete after 7-30 days

**See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for detailed instructions.**

## 🔐 Security

- ✅ All secrets passed as secure parameters
- ✅ HTTPS enforced for all connections
- ✅ TLS 1.2 minimum version
- ✅ No secrets in version control
- ✅ Application Insights for monitoring
- ✅ Managed identities support (future)

**Warning:** Never commit filled `parameters.json` or `.env` files with real secrets to git!

## 🆘 Troubleshooting

### Deployment Fails

```powershell
# Check deployment logs
az deployment group show \
  --name DEPLOYMENT_NAME \
  --resource-group rg-paletai-prod

# Retry with verbose logging
.\Deploy-PaletAI.ps1 ... -Verbose
```

### Health Endpoint Returns 500

```bash
# Stream application logs
az webapp log tail \
  --name APP_NAME \
  --resource-group rg-paletai-prod

# Check app settings (especially DB_PATH)
az webapp config appsettings list \
  --name APP_NAME \
  --resource-group rg-paletai-prod
```

### Database Connection Fails

- Verify MongoDB connection string is correct
- Check MongoDB allows connections from Azure IPs
- Test connection with `mongosh` from local machine
- Verify connection string in app settings

**Full troubleshooting guide:** [MIGRATION-GUIDE.md#troubleshooting](MIGRATION-GUIDE.md#troubleshooting)

## 🔄 Updates and Maintenance

### Update Application Code

**Recommended:** Use GitHub Actions
1. Get publish profile: `az webapp deployment list-publishing-profiles ...`
2. Add to GitHub secrets as `AZURE_WEBAPP_PUBLISH_PROFILE`
3. Push to main branch → auto-deploys

**Alternative:** ZIP deploy
```bash
az webapp deployment source config-zip \
  --resource-group rg-paletai-prod \
  --name APP_NAME \
  --src deploy.zip
```

### Update Configuration

```bash
# Update environment variables
az webapp config appsettings set \
  --name APP_NAME \
  --resource-group rg-paletai-prod \
  --settings DAILY_PROMPT_LIMIT=50

# Restart app service
az webapp restart \
  --name APP_NAME \
  --resource-group rg-paletai-prod
```

## 📊 Monitoring

### Application Insights

Access via: **Azure Portal → Application Insights → YOUR_APP_NAME**

Key metrics:
- Live Metrics (real-time requests)
- Failures (exceptions and errors)
- Performance (response times)
- Availability (uptime monitoring)

### Cost Monitoring

```bash
# Create budget alert
az consumption budget create \
  --budget-name paletai-monthly \
  --amount 50 \
  --time-grain monthly \
  --resource-group rg-paletai-prod
```

## 🤝 Contributing

This repository is maintained by the HuddleUp-AI team. For issues or improvements:

1. Create an issue in this repository
2. Submit a pull request with proposed changes
3. Contact the DevOps team

## 📞 Support

- **Application Repository:** https://github.com/HuddleUp-AI/paletaibackend
- **Azure Documentation:** https://docs.microsoft.com/azure/
- **Issues:** Create an issue in this repository

## 📜 License

Internal use for HuddleUp-AI projects.

---

**Ready to deploy?** Start with [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)!
