# PaletAI Backend Migration - Execution Checklist

Use this checklist on migration day to ensure nothing is missed.

## Pre-Migration (1-2 Days Before)

### Information Gathering
- [ ] Collected new Azure Tenant ID: `_______________________`
- [ ] Collected new Azure Subscription ID: `_______________________`
- [ ] Verified Contributor/Owner access to new subscription
- [ ] MongoDB connection string ready: `mongodb://...`
- [ ] AI provider API keys ready (OpenAI/Anthropic/Azure OpenAI)
- [ ] OneSignal credentials ready (if using push notifications)

### Old Environment Documentation
- [ ] Exported current app settings to file:
  ```bash
  az webapp config appsettings list \
    --name emailgeniebackend \
    --resource-group huddleup \
    --output json > old-app-settings.json
  ```
- [ ] Documented custom domains (if any): `_______________________`
- [ ] Noted current SKU/tier: `_______________________`
- [ ] Recorded average daily traffic/metrics
- [ ] Listed any third-party integrations

### Database Preparation
- [ ] Full MongoDB backup created:
  ```bash
  mongodump --uri="OLD_URI" --out=/backup/paletai-$(date +%Y%m%d)
  ```
- [ ] Backup verified (can restore to test instance)
- [ ] Tested MongoDB connectivity from new Azure region
- [ ] Decided on migration strategy:
  - [ ] Keep same MongoDB (update connection only)
  - [ ] Migrate to new MongoDB (backup/restore)
  - [ ] Use continuous sync (zero downtime)

### Testing Preparation
- [ ] Test user accounts identified for post-migration testing
- [ ] Test game prompts prepared
- [ ] API test scripts ready
- [ ] Health check URLs bookmarked

### Communication
- [ ] Maintenance window scheduled (if needed): `_______________________`
- [ ] Users notified of potential downtime
- [ ] Status page prepared (if applicable)
- [ ] Team members briefed on migration plan

## Migration Day - Phase 1: Infrastructure Deployment

**Estimated Time: 10-15 minutes**

### Deploy Infrastructure
- [ ] Navigated to deployment directory:
  ```bash
  cd /mnt/d/Dev2/clients/HuddleUp/deployment
  ```

- [ ] Reviewed deployment script parameters
- [ ] Executed deployment:
  ```powershell
  .\Deploy-PaletAI.ps1 `
    -TenantId "..." `
    -SubscriptionId "..." `
    -ResourceGroupName "rg-paletai-prod" `
    -Location "westus3" `
    -MongoDbConnectionString "..." `
    -OpenAiApiKey "..." `
    -AiProvider "openai"
  ```

- [ ] Deployment completed successfully
- [ ] Saved deployment outputs file
- [ ] Recorded new App Service URL: `https://_______.azurewebsites.net`
- [ ] Recorded Storage Account name: `_______________________`

### Verify Infrastructure
- [ ] Resource group created in Azure Portal
- [ ] App Service Plan created (B1 SKU)
- [ ] App Service created
- [ ] Storage Account created
- [ ] Blob container "game-images" exists with public access
- [ ] Application Insights created

## Migration Day - Phase 2: Application Deployment

**Estimated Time: 5-10 minutes**

### Deploy Application Code

Choose one method:

#### Method A: GitHub Actions (Recommended)
- [ ] Retrieved publish profile from Azure Portal or CLI
- [ ] Added `AZURE_WEBAPP_PUBLISH_PROFILE` to GitHub secrets
- [ ] Triggered GitHub Actions workflow
- [ ] Workflow completed successfully
- [ ] Verified deployment in Azure Portal

#### Method B: ZIP Deploy
- [ ] Cloned repository: `git clone https://github.com/HuddleUp-AI/paletaibackend.git`
- [ ] Created ZIP package (excluding .git, __pycache__, etc.)
- [ ] Deployed via Azure CLI:
  ```bash
  az webapp deployment source config-zip \
    --resource-group rg-paletai-prod \
    --name APP_NAME \
    --src deploy.zip
  ```
- [ ] Deployment completed successfully

### Verify Application Deployment
- [ ] App Service shows "Running" status in Azure Portal
- [ ] Accessed URL in browser (should show API welcome message or redirect to /docs)
- [ ] No deployment errors in Azure Portal → Deployment Center

## Migration Day - Phase 3: Database Migration

**Choose your strategy:**

### Strategy A: Same MongoDB (Simplest)
- [ ] Verified connection string in new app service
- [ ] Connection string is correct
- [ ] No migration needed - SKIP to Phase 4

### Strategy B: New MongoDB (Backup/Restore)
- [ ] Stopped old app service (optional, for consistency):
  ```bash
  az webapp stop --name emailgeniebackend --resource-group huddleup
  ```
- [ ] Created final backup from old database
- [ ] Restored to new MongoDB instance:
  ```bash
  mongorestore --uri="NEW_URI" --dir=/backup/paletai-final
  ```
- [ ] Verified data in new database:
  ```bash
  mongosh "NEW_URI" --eval "db.users.countDocuments({})"
  mongosh "NEW_URI" --eval "db.games.countDocuments({})"
  ```
- [ ] Updated app service connection string (if different)
- [ ] Restarted app service

### Strategy C: Continuous Sync (Zero Downtime)
- [ ] Set up MongoDB replication/sync
- [ ] Verified sync is working
- [ ] Monitored replication lag
- [ ] Ready for cutover to new database

## Migration Day - Phase 4: Configuration Verification

**Estimated Time: 10 minutes**

### Test Health Endpoint
- [ ] Accessed: `https://NEW_APP_URL/health`
- [ ] Response status: `200 OK`
- [ ] Response body shows:
  - `"status": "healthy"`
  - `"database": "healthy"`
  - `"api": "healthy"`

### Test API Documentation
- [ ] Accessed: `https://NEW_APP_URL/docs`
- [ ] Swagger UI loads correctly
- [ ] All endpoints visible

### Test Authentication
- [ ] Registered new test user via `/auth/register`
  - Email: `test@example.com`
  - Response: 200 OK, user created
- [ ] Logged in via `/auth/login`
  - Response: 200 OK, JWT token received
- [ ] Token stored: `_______________________`

### Test Game Creation
- [ ] Created game via `/games` with test token
  - Prompt: "Create a simple snake game"
  - Response: Task ID received
- [ ] Polled task status until complete
- [ ] Game created successfully
- [ ] Game ID: `_______________________`

### Test Image Storage
- [ ] Verified game has image URL
- [ ] Image URL accessible: `https://STORAGE_ACCOUNT.blob.core.windows.net/game-images/...`
- [ ] Image loads in browser
- [ ] Listed blobs in Azure Portal → Storage Account → game-images
- [ ] At least one blob exists

### Test Game Feed
- [ ] Accessed `/games/feed`
- [ ] Response includes created game
- [ ] All game fields populated correctly

### Test Push Notifications (if configured)
- [ ] Subscribed to notifications via `/notifications/subscribe`
- [ ] Subscription created successfully
- [ ] OneSignal dashboard shows subscription (if applicable)

## Migration Day - Phase 5: DNS Cutover (If Using Custom Domain)

**Estimated Time: 5 minutes + DNS propagation (5-60 minutes)**

### Pre-Cutover
- [ ] Lowered DNS TTL to 300 seconds (done 24+ hours ago)
- [ ] Old TTL has expired
- [ ] Custom domain added to new App Service:
  ```bash
  az webapp config hostname add \
    --webapp-name NEW_APP_NAME \
    --resource-group rg-paletai-prod \
    --hostname api.paletai.com
  ```

### DNS Update
- [ ] Updated DNS CNAME record:
  - Type: `CNAME`
  - Name: `api` (or `@`)
  - Value: `NEW_APP_NAME.azurewebsites.net`
  - TTL: `300`
- [ ] Saved DNS changes
- [ ] Timestamp of DNS update: `_______________________`

### Verify DNS Propagation
- [ ] Tested with `nslookup api.paletai.com`
- [ ] Tested with `curl https://api.paletai.com/health`
- [ ] Response from new server confirmed
- [ ] SSL certificate working (if configured)

## Migration Day - Phase 6: Monitoring & Verification

**Estimated Time: 30 minutes**

### Application Insights
- [ ] Opened Application Insights in Azure Portal
- [ ] Live Metrics shows active requests
- [ ] No errors or exceptions appearing
- [ ] Response times acceptable (<2 seconds)

### Log Streaming
- [ ] Started log stream:
  ```bash
  az webapp log tail --name NEW_APP_NAME --resource-group rg-paletai-prod
  ```
- [ ] Logs show normal activity
- [ ] No error messages
- [ ] Database connections successful

### Performance Testing
- [ ] Created 5-10 test games
- [ ] Response times acceptable
- [ ] No timeouts or errors
- [ ] All games have images
- [ ] Feed loads quickly

### Production Testing (with real users if possible)
- [ ] Logged in with production user account
- [ ] Created game
- [ ] Viewed feed
- [ ] Liked game
- [ ] All features working
- [ ] User feedback: `_______________________`

## Migration Day - Phase 7: Old Environment Decommission

**⚠️ DO NOT DO THIS IMMEDIATELY - Wait 24-48 hours!**

### After 24-48 Hours of Stable Operation
- [ ] Confirmed new environment is stable
- [ ] No critical issues reported
- [ ] Metrics look normal
- [ ] Users are happy

### Stop Old Services
- [ ] Stopped old app service:
  ```bash
  az webapp stop --name emailgeniebackend --resource-group huddleup
  ```
- [ ] Monitored for any issues (users should be on new service)
- [ ] No complaints received

### After 7 Days (Recommended)
- [ ] Confirmed everything is working perfectly
- [ ] Exported any remaining logs/data from old environment
- [ ] Deleted old app service:
  ```bash
  az webapp delete --name emailgeniebackend --resource-group huddleup
  ```

### After 30 Days (When Confident)
- [ ] Final backup of old environment (if not already deleted)
- [ ] Deleted old resource group:
  ```bash
  az group delete --name huddleup --yes
  ```

## Post-Migration Tasks

### Documentation Updates
- [ ] Updated internal documentation with new URLs
- [ ] Updated API documentation (if separate)
- [ ] Updated README with new deployment info
- [ ] Documented lessons learned

### Optimization
- [ ] Reviewed Application Insights metrics
- [ ] Identified any performance issues
- [ ] Adjusted SKU if needed (scale up/down)
- [ ] Configured auto-scaling rules (if S1+)

### Cost Management
- [ ] Set up cost alerts in Azure
- [ ] Configured budget: $50/month (or as needed)
- [ ] Scheduled monthly cost review

### Monitoring & Alerts
- [ ] Configured Application Insights alerts:
  - HTTP 5xx errors > 5 in 5 minutes
  - Response time > 5 seconds
  - Availability < 99%
- [ ] Configured Azure Monitor alerts:
  - CPU > 80% for 10 minutes
  - Memory > 80% for 10 minutes
  - Disk space > 85%
- [ ] Tested alert delivery (email/SMS)

### Security Hardening
- [ ] Reviewed IP restrictions (if needed)
- [ ] Enabled managed identities (if applicable)
- [ ] Rotated API keys (if required)
- [ ] Reviewed CORS settings
- [ ] Ensured HTTPS only is enforced

### Backup Strategy
- [ ] Set up automated MongoDB backups
- [ ] Documented restore procedure
- [ ] Tested backup restoration
- [ ] Configured retention policy

## Rollback Plan (If Needed)

**If critical issues are discovered:**

### Immediate Rollback (DNS)
- [ ] Reverted DNS CNAME to old app service
- [ ] Waited for DNS propagation (5-10 minutes)
- [ ] Started old app service
- [ ] Verified old service working
- [ ] Notified users of issue

### Database Rollback (If Migrated)
- [ ] Restored from backup to old database
- [ ] Verified data integrity
- [ ] Updated old app service connection string
- [ ] Restarted old app service

### Post-Rollback
- [ ] Investigated root cause
- [ ] Fixed issues in new environment
- [ ] Scheduled new migration date
- [ ] Documented what went wrong

## Success Criteria

**Migration is successful when:**
- ✅ Health endpoint returns 200 OK
- ✅ All API endpoints functional
- ✅ Database connectivity confirmed
- ✅ Game creation working
- ✅ Image upload to Blob Storage working
- ✅ No errors in Application Insights
- ✅ Response times < 2 seconds average
- ✅ Users can log in and use the app
- ✅ No critical bugs reported
- ✅ Cost is within expected range ($15-20/month for B1)

## Notes / Issues Encountered

```
Date/Time: _______________
Issue: _______________________________________________________________
Resolution: ___________________________________________________________

Date/Time: _______________
Issue: _______________________________________________________________
Resolution: ___________________________________________________________

Date/Time: _______________
Issue: _______________________________________________________________
Resolution: ___________________________________________________________
```

## Sign-Off

- [ ] Technical lead sign-off: `_______________________` Date: `_______`
- [ ] Migration completed successfully
- [ ] All systems operational
- [ ] Documentation updated
- [ ] Old environment scheduled for decommission

---

**Migration Duration:** Start: `_______` End: `_______` Total: `_______ hours`

**Total Downtime:** `_______ minutes` (goal: < 15 minutes)
