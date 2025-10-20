# ServiceNow DevOps Change API Integration

**Status**: Ready for implementation
**Created**: 2025-10-16
**Workflow**: `.github/workflows/deploy-with-servicenow-devops.yaml`

---

## Overview

This integration uses the **official ServiceNow DevOps Change GitHub Actions** to create and manage change requests. Unlike the basic REST API approach, this method:

✅ **Integrates with DevOps Change Velocity workspace**
✅ **Automatically tracks pipeline execution**
✅ **Shows changes in DevOps Change workspace**
✅ **Enables DORA metrics calculation**
✅ **Provides real-time pipeline status**
✅ **Links changes to specific workflow runs**

---

## What's Different from Basic API

### Old Approach (Basic REST API):
```yaml
# Manual REST API call
curl -X POST .../api/now/table/change_request
```
**Result**: Change created but **NOT visible in DevOps Change workspace**

### New Approach (DevOps Change API):
```yaml
# Official GitHub Action
uses: ServiceNow/servicenow-devops-change@v4.0.0
```
**Result**: Change created **AND tracked in DevOps Change workspace** ✅

---

## Prerequisites

### 1. GitHub Tool Sys ID

Your GitHubARC tool sys_id (already exists):
```
4eaebb06c320f690e1bbf0cb05013135
```

### 2. GitHub Secrets Required

**Go to**: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions

**Add these secrets**:
- **Name**: `SERVICENOW_TOOL_ID`
- **Value**: `4eaebb06c320f690e1bbf0cb05013135`

- **Name**: `SN_DEVOPS_INTEGRATION_TOKEN` ⭐ **NEW!**
- **Value**: `<token generated from ServiceNow OAuth setup>`

### 3. Existing Secrets (already configured):
- ✅ `SERVICENOW_INSTANCE_URL`
- ✅ `SERVICENOW_APP_SYS_ID`
- ✅ `AWS_ACCESS_KEY_ID`
- ✅ `AWS_SECRET_ACCESS_KEY`

### 4. Authentication Method: Token-Based (Recommended)

The workflow now uses **token-based authentication** instead of username/password:
- More secure
- Better for CI/CD automation
- Recommended by ServiceNow for v4.0.0+

---

## How It Works

### Step 1: Create Change Request

```yaml
uses: ServiceNow/servicenow-devops-change@v6.1.0
with:
  # Token-based authentication (recommended)
  devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
  context-github: ${{ toJSON(github) }}
  job-name: 'Create Change Request'
  change-request: |
    {
      "setCloseCode": "true",
      "autoCloseChange": true,  # For dev only
      "attributes": {
        "short_description": "Deploy Online Boutique to dev",
        "business_service": "...",
        "u_environment": "dev"
      }
    }
  interval: '30'
  timeout: '3600'
```

**What happens**:
1. GitHub Action calls ServiceNow DevOps Change API
2. ServiceNow creates change request
3. ServiceNow **links change to GitHub workflow run**
4. Action **waits for approval** (if required)
5. Returns change request number and sys_id

### Step 2: Deploy Application

```yaml
deploy:
  needs: create-change-request
  # Only runs after change is created (and approved if needed)
```

### Step 3: Update Change on Success

```yaml
uses: ServiceNow/servicenow-devops-update-change@v5.1.0
with:
  # Token-based authentication
  devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
  context-github: ${{ toJSON(github) }}
  change-request-number: ${{ needs.create-change-request.outputs.change_request_number }}
  change-request-details: |
    {
      "state": "3",
      "close_code": "successful",
      "close_notes": "Deployment completed successfully"
    }
```

### Step 4: Update Change on Failure

```yaml
rollback:
  if: failure()
  uses: ServiceNow/servicenow-devops-update-change@v4.0.0
  with:
    change-request-details: |
      {
        "state": "4",
        "close_code": "unsuccessful"
      }
```

---

## Environment-Specific Behavior

### Dev Environment:
```yaml
"autoCloseChange": true   # Auto-approve and close on success
timeout: '3600'           # 1 hour timeout
```
- Change created
- **Auto-approved** (no manual step)
- Deployment proceeds immediately
- Auto-closed on success

### QA Environment:
```yaml
"autoCloseChange": false  # Requires manual approval
timeout: '7200'           # 2 hour timeout
```
- Change created in "Pending Approval" state
- **QA Team must approve** in ServiceNow
- Workflow **pauses** until approved
- Deployment proceeds after approval

### Prod Environment:
```yaml
"autoCloseChange": false  # Requires CAB approval
timeout: '86400'          # 24 hour timeout
```
- Change created in "Pending Approval" state
- **Change Advisory Board must approve**
- Workflow **pauses** up to 24 hours
- Deployment proceeds after approval

---

## ServiceNow DevOps Change Workspace Integration

### What You'll See in Workspace

Once the workflow runs with DevOps Change API:

#### 1. Pipelines Tab:
```
📊 Pipelines
├─ Deploy with ServiceNow DevOps Change
   ├─ Status: Running / Success / Failed
   ├─ Last Run: 2025-10-16 23:30:00
   ├─ Change: CHG0030014
   └─ Environment: dev
```

#### 2. Changes Tab:
```
📋 Changes
├─ CHG0030014 - Deploy Online Boutique to dev
   ├─ State: Closed Complete
   ├─ Pipeline: Deploy with ServiceNow DevOps Change
   ├─ Run: #123
   ├─ Triggered by: olafkfreund
   └─ Duration: 5m 32s
```

#### 3. Applications Tab:
```
🏢 Applications
└─ Online Boutique
   ├─ Recent Changes: 3
   ├─ Success Rate: 100%
   ├─ Last Deployment: 2 hours ago
   └─ Environment: dev, qa, prod
```

#### 4. Dashboard (DORA Metrics):
```
📊 DORA Metrics - Online Boutique
├─ Deployment Frequency: 12/week
├─ Lead Time for Changes: 2.5 hours
├─ Mean Time to Restore: 15 minutes
└─ Change Failure Rate: 5%
```

---

## Testing the Integration

### 1. Add GitHub Secret

```bash
# Go to GitHub repository settings
https://github.com/Freundcloud/microservices-demo/settings/secrets/actions

# Add SERVICENOW_TOOL_ID = 4eaebb06c320f690e1bbf0cb05013135
```

### 2. Trigger Workflow

```bash
gh workflow run deploy-with-servicenow-devops.yaml --field environment=dev
```

### 3. Monitor Progress

**GitHub Actions**:
https://github.com/Freundcloud/microservices-demo/actions

**ServiceNow DevOps Workspace**:
https://calitiiltddemo3.service-now.com/now/devops-change/home

**Watch for**:
- ✅ Change request created
- ✅ Shows in Pipelines tab
- ✅ Shows in Changes tab
- ✅ Links to GitHub run
- ✅ Updates on success/failure

### 4. Verify in Workspace

1. **Open DevOps Change Workspace**:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/home
   ```

2. **Click Pipelines tab**:
   - Should see: "Deploy with ServiceNow DevOps Change"
   - Should show: Status, last run, linked change

3. **Click Changes tab**:
   - Should see: CHG number
   - Should show: Pipeline name, run link, status

4. **Click change number**:
   - Should show: Full change details
   - Should show: **Related Pipeline Run** section
   - Should have: Link back to GitHub Actions run

---

## Comparison: Basic API vs DevOps Change API

| Feature | Basic REST API | DevOps Change API |
|---------|----------------|-------------------|
| Creates change request | ✅ Yes | ✅ Yes |
| Visible in classic change list | ✅ Yes | ✅ Yes |
| Visible in DevOps workspace | ❌ No | ✅ Yes |
| Links to pipeline run | ❌ No | ✅ Yes |
| Real-time status updates | ❌ No | ✅ Yes |
| DORA metrics | ❌ No | ✅ Yes |
| Pipeline topology view | ❌ No | ✅ Yes |
| Automatic approval handling | ❌ Manual | ✅ Built-in |

---

## GitHub Actions Used

### 1. ServiceNow DevOps Change
**Action**: `ServiceNow/servicenow-devops-change@v4.0.0`
**Purpose**: Create change request and wait for approval
**Outputs**:
- `change-request-number` - Change number (CHG0030014)
- `change-request-sys-id` - Sys ID for API calls

### 2. ServiceNow DevOps Update Change
**Action**: `ServiceNow/servicenow-devops-update-change@v4.0.0`
**Purpose**: Update existing change request
**Use cases**:
- Mark as successful
- Mark as failed
- Add closure notes
- Update state

### 3. ServiceNow DevOps Get Change (optional)
**Action**: `ServiceNow/servicenow-devops-get-change@v4.0.0`
**Purpose**: Retrieve change request details
**Not used in current workflow** (but available if needed)

---

## Troubleshooting

### Issue: "Invalid tool-id"
**Solution**: Verify `SERVICENOW_TOOL_ID` secret is set correctly
```bash
# Value should be: 4eaebb06c320f690e1bbf0cb05013135
```

### Issue: Change created but not visible in workspace
**Possible causes**:
1. Using wrong API (check you're using `ServiceNow/servicenow-devops-change` action)
2. Tool not properly registered
3. Workspace needs refresh (F5)

### Issue: Workflow hangs on "Waiting for approval"
**Expected behavior**: This is normal for QA/Prod
**Solution**: Go to ServiceNow and approve the change request

### Issue: "Permission denied" when creating change
**Solution**: Verify `github_integration` user has DevOps roles:
- `sn_devops.integration`
- `sn_devops.admin`

---

## Migration from Basic API

### Option 1: Keep Both Workflows (Recommended)

**Use `deploy-with-servicenow-basic.yaml` for**:
- Quick deployments
- Testing
- When workspace visibility not needed

**Use `deploy-with-servicenow-devops.yaml` for**:
- Production deployments
- When you want workspace tracking
- When you need DORA metrics

### Option 2: Migrate Completely

1. Test new workflow in dev:
   ```bash
   gh workflow run deploy-with-servicenow-devops.yaml --field environment=dev
   ```

2. Verify in workspace:
   - Check Pipelines tab
   - Check Changes tab
   - Verify change details

3. Once confirmed working:
   - Rename old workflow (add `.deprecated`)
   - Update documentation
   - Notify team

---

## Next Steps

### Immediate:
1. ✅ Add `SERVICENOW_TOOL_ID` GitHub secret
2. ✅ Test workflow with dev deployment
3. ✅ Verify change appears in workspace

### Short-term:
1. Configure approval policies in ServiceNow for QA/Prod
2. Set up DORA metrics dashboards
3. Train team on workspace usage

### Long-term:
1. Migrate all workflows to DevOps Change API
2. Establish DORA metrics targets
3. Use insights for continuous improvement

---

## Additional Resources

### GitHub Actions:
- **DevOps Change**: https://github.com/ServiceNow/servicenow-devops-change
- **Update Change**: https://github.com/ServiceNow/servicenow-devops-update-change
- **Get Change**: https://github.com/ServiceNow/servicenow-devops-get-change

### ServiceNow Documentation:
- **DevOps Change Velocity**: https://www.servicenow.com/products/devops-change-velocity.html
- **GitHub Integration**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/task/github-tool-registration.html

### Related Docs:
- [SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md) - Workspace access guide
- [SERVICENOW-APPROVALS-QUICKSTART.md](SERVICENOW-APPROVALS-QUICKSTART.md) - Approval setup
- [SERVICENOW-NAVIGATION-URLS.md](SERVICENOW-NAVIGATION-URLS.md) - All ServiceNow URLs

---

**Status**: ✅ Ready to use
**Last Updated**: 2025-10-16
**Workflow File**: `.github/workflows/deploy-with-servicenow-devops.yaml`
**GitHubARC Tool ID**: `4eaebb06c320f690e1bbf0cb05013135`
