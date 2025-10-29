# PaletAI Backend - Azure Deployment

This directory contains everything needed to deploy PaletAI Backend to a new Azure subscription with minimum cost configuration.

## 🚀 Quick Start

### Prerequisites

1. **Azure PowerShell Module** or **Azure CLI** installed
2. **Access** to target Azure subscription (Contributor or Owner role)
3. **MongoDB connection string** ready
4. **AI provider API keys** (OpenAI, Azure OpenAI, or Anthropic)

### Deploy in 3 Steps

```powershell
# 1. Navigate to deployment directory
cd /mnt/d/Dev2/clients/HuddleUp/deployment

# 2. Run deployment script
.\Deploy-PaletAI.ps1 `
  -TenantId "YOUR_TENANT_ID" `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroupName "rg-paletai-prod" `
  -MongoDbConnectionString "mongodb://user:pass@host:27017/dbname" `
  -OpenAiApiKey "sk-..." `
  -AiProvider "openai"

# 3. Deploy application code (see Migration Guide)
```

**Deployment Time:** ~5 minutes for infrastructure + ~3 minutes for application = **8 minutes total**

## 📁 Files in This Directory

| File | Purpose |
|------|---------|
| `main.bicep` | Azure infrastructure template (App Service, Storage, App Insights) |
| `parameters.json` | Default parameter values (optional - script accepts all params) |
| `Deploy-PaletAI.ps1` | PowerShell deployment automation script |
| `MIGRATION-GUIDE.md` | **Complete migration guide** with step-by-step instructions |
| `env-template.txt` | Environment variables reference |
| `README.md` | This file |

## 💰 Cost Optimization

### Minimum Cost Configuration (B1 SKU)

**Monthly Cost Breakdown:**
- App Service Plan (B1): **$13/month**
- Storage Account (LRS): **~$1-2/month** (depends on usage)
- Application Insights: **Free tier** (5GB/month included)
- **Total: ~$15-16/month**

**vs. Old Environment: ~$70-100/month → Saves $55-85/month (70-85% reduction)**

### SKU Comparison

| SKU | Cost/Month | vCPU | RAM | Notes |
|-----|-----------|------|-----|-------|
| **B1** | $13 | 1 | 1.75GB | ✅ Minimum for AlwaysOn, Custom Domains |
| B2 | $26 | 2 | 3.5GB | Better performance, 2x resources |
| B3 | $52 | 4 | 7GB | High performance, 4x resources |
| S1 | $70 | 1 | 1.75GB | Auto-scaling, staging slots |
| P1V2 | $140 | 1 | 3.5GB | Premium tier, enhanced performance |

**Recommendation:** Start with **B1** for production. Monitor metrics and scale up only if needed.

## 🔧 Configuration Options

### AI Provider Selection

Choose one of:
- **OpenAI** (default): `-AiProvider "openai"` + `-OpenAiApiKey "sk-..."`
- **Azure OpenAI**: `-AiProvider "azure-openai"` + `-AzureOpenAiEndpoint "..."` + `-AzureOpenAiApiKey "..."`
- **Anthropic**: `-AiProvider "anthropic"` + `-AnthropicApiKey "..."`

### Region Selection

Available regions (use any US region):
- `westus3` (default - newest, cost-effective)
- `eastus` (established, highly available)
- `westus2` (West Coast, low latency)
- `centralus` (Central US, good connectivity)

### Environment Types

- `dev` - Development environment
- `staging` - Pre-production testing
- `prod` - Production (default)

## 📚 Documentation

### For Complete Migration Instructions
👉 **See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)**

The migration guide includes:
- Pre-migration checklist
- Detailed deployment steps
- Database migration strategies
- DNS/custom domain setup
- Post-migration verification
- Rollback procedures
- Troubleshooting guide

### For Environment Variables
👉 **See [env-template.txt](env-template.txt)**

Complete reference of all environment variables with explanations and examples.

## 🎯 Deployment Scenarios

### Scenario 1: New Production Deployment

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "12345678-..." `
  -SubscriptionId "87654321-..." `
  -ResourceGroupName "rg-paletai-prod" `
  -Location "westus3" `
  -Environment "prod" `
  -AppServicePlanSku "B1" `
  -MongoDbConnectionString "mongodb://..." `
  -OpenAiApiKey "sk-..." `
  -AiProvider "openai" `
  -OneSignalAppId "..." `
  -OneSignalRestApiKey "..."
```

### Scenario 2: Development Environment

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "12345678-..." `
  -SubscriptionId "87654321-..." `
  -ResourceGroupName "rg-paletai-dev" `
  -Location "westus3" `
  -Environment "dev" `
  -AppServicePlanSku "B1" `
  -MongoDbConnectionString "mongodb://localhost:27017" `
  -AnthropicApiKey "sk-ant-..." `
  -AiProvider "anthropic" `
  -DailyPromptLimit 100
```

### Scenario 3: Preview (Dry Run)

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "12345678-..." `
  -SubscriptionId "87654321-..." `
  -ResourceGroupName "rg-paletai-test" `
  -MongoDbConnectionString "mongodb://..." `
  -OpenAiApiKey "sk-..." `
  -DryRun
```

### Scenario 4: Using Azure OpenAI

```powershell
.\Deploy-PaletAI.ps1 `
  -TenantId "12345678-..." `
  -SubscriptionId "87654321-..." `
  -ResourceGroupName "rg-paletai-prod" `
  -MongoDbConnectionString "mongodb://..." `
  -AzureOpenAiEndpoint "https://your-resource.openai.azure.com/" `
  -AzureOpenAiApiKey "..." `
  -AzureOpenAiModel "gpt-4o" `
  -AiProvider "azure-openai"
```

## 🔍 Verification

After deployment, verify everything works:

```bash
# 1. Get the app service URL from deployment outputs
# Example: https://paletai-api-prod-abc123.azurewebsites.net

# 2. Test health endpoint
curl https://YOUR_APP_SERVICE_URL/health

# 3. View API documentation
open https://YOUR_APP_SERVICE_URL/docs

# 4. Check Application Insights
# Azure Portal → Application Insights → YOUR_APP_INSIGHTS → Live Metrics
```

## 🆘 Troubleshooting

### Common Issues

**1. "Az module not found"**
```powershell
Install-Module -Name Az -Scope CurrentUser -Force
```

**2. "Insufficient permissions"**
- Verify you have Contributor or Owner role on the subscription
- Check you're logged into the correct tenant

**3. "Deployment failed: InvalidTemplate"**
- Ensure all required parameters are provided
- Check parameter values match allowed values (e.g., SKU names)

**4. "MongoDB connection failed"**
- Verify connection string is correct
- Check MongoDB allows connections from Azure IPs
- Test connection locally first

**5. "Application won't start"**
- Check Application Logs in Azure Portal
- Verify all environment variables are set correctly
- Ensure MongoDB connection string is valid

### Getting Help

1. **Check deployment outputs:**
   ```powershell
   cat deployment-outputs-prod.json
   ```

2. **View application logs:**
   ```bash
   az webapp log tail --name YOUR_APP_SERVICE --resource-group rg-paletai-prod
   ```

3. **Review detailed migration guide:**
   See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for comprehensive troubleshooting section

## 🔐 Security Best Practices

- ✅ All secrets passed as secure parameters (not stored in templates)
- ✅ HTTPS enforced for all connections
- ✅ TLS 1.2 minimum for App Service
- ✅ Blob storage requires HTTPS
- ✅ Application Insights for monitoring and alerting
- ✅ No public repository access to secrets

**Important:** Never commit filled parameter files or environment files with real secrets to git!

## 📊 Monitoring

After deployment, set up monitoring:

1. **Application Insights** - Already configured
   - Live Metrics: Real-time monitoring
   - Failures: Track errors and exceptions
   - Performance: Response times and dependencies

2. **Cost Management**
   - Set up budget alerts in Azure Portal
   - Monitor daily costs
   - Review resource utilization

3. **App Service Metrics**
   - CPU percentage
   - Memory percentage
   - HTTP response times
   - HTTP 5xx errors

## 🔄 Updates and Maintenance

### Updating Application Code

Use GitHub Actions (recommended):
1. Configure publish profile in GitHub secrets
2. Push to main branch
3. Automatic deployment via GitHub Actions

### Scaling Up/Down

```bash
# Scale to B2 (2 vCPU, 3.5GB RAM)
az appservice plan update \
  --name YOUR_APP_SERVICE_PLAN \
  --resource-group rg-paletai-prod \
  --sku B2

# Scale back to B1
az appservice plan update \
  --name YOUR_APP_SERVICE_PLAN \
  --resource-group rg-paletai-prod \
  --sku B1
```

### Updating Configuration

```bash
# Update environment variables
az webapp config appsettings set \
  --name YOUR_APP_SERVICE \
  --resource-group rg-paletai-prod \
  --settings DAILY_PROMPT_LIMIT=50

# Restart to apply changes
az webapp restart \
  --name YOUR_APP_SERVICE \
  --resource-group rg-paletai-prod
```

## 📞 Support

- **Azure Documentation:** https://docs.microsoft.com/azure/
- **Application Repository:** https://github.com/HuddleUp-AI/paletaibackend
- **Report Issues:** Create issue in GitHub repository

---

**Ready to deploy?** Start with the [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for complete step-by-step instructions!
