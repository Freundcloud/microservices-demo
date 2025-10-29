# ServiceNow DevOps Changes - Troubleshooting Guide

## Issue: Changes Not Visible in DevOps UI

### Problem
Navigating to the ServiceNow DevOps Changes view shows no changes, even though the DevOps Change action has been executed successfully.

**URL**: `https://<instance>.service-now.com/now/devops-change/changes/`

### Root Causes

#### 1. **No Deployments Run Yet with New Action**

The most common reason - the Master pipeline hasn't run since migrating to the official ServiceNow DevOps Change action.

**Check:**
- Look at recent GitHub Actions workflow runs
- Verify that `servicenow-devops-change.yaml` workflow has been called
- Check if runs occurred after commit `ea53f45b` (migration commit)

**Solution:**
```bash
# Trigger a deployment to populate DevOps changes
gh workflow run MASTER-PIPELINE.yaml --field environment=dev
```

#### 2. **UI Filter Applied**

The URL you're viewing might have a filter that excludes your changes.

**Direct URLs with filter parameters:**
```
/now/devops-change/changes/params/list-id/.../tiny-id/...
```

**Solution:**
Try these alternative URLs:

1. **Main DevOps Changes List:**
   ```
   https://<instance>.service-now.com/now/nav/ui/classic/params/target/sn_devops_change_request_list.do
   ```

2. **All Apps Navigator:**
   - Click hamburger menu (☰)
   - Type "DevOps"
   - Navigate to **DevOps > Change Management > Changes**

3. **Remove Filters:**
   - In the changes list, click the filter icon
   - Clear all filters
   - Refresh the page

#### 3. **changeControl: false Setting**

The ServiceNow DevOps API can be configured to NOT create traditional change requests.

**When this happens:**
- Deployment is registered in DevOps tables
- NO change request is created in `change_request` table
- DevOps Changes UI might be empty (expects traditional CRs)

**Check via API:**
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID" \
  -H "Accept: application/json" | jq '.result[] | {buildNumber, pipelineName, changeControl}'
```

**Look for:**
```json
{
  "buildNumber": "18908760047/attempts/1",
  "pipelineName": "Freundcloud/microservices-demo/Test ServiceNow DevOps Change Action",
  "changeControl": false  ← This means no traditional CR was created
}
```

**Solution:**
If you need traditional change requests created, configure ServiceNow DevOps plugin to enable `changeControl`.

**Alternative - View Deployments Instead:**
- Go to **DevOps > Deployments**
- These show all deployment registrations regardless of `changeControl` setting

#### 4. **Wrong Table/View**

You might be looking in the wrong ServiceNow table.

**Different Places to Check:**

| Table | URL | What It Shows |
|-------|-----|---------------|
| Traditional Change Requests | `/change_request_list.do` | All CRs (including non-DevOps) |
| DevOps Change Requests | `/sn_devops_change_request_list.do` | DevOps-created CRs only |
| DevOps Deployments | `/sn_devops_deployment_list.do` | All deployment registrations |
| DevOps Task Executions | `/sn_devops_task_execution_list.do` | Pipeline task executions |

**Try:**
```
https://<instance>.service-now.com/now/nav/ui/classic/params/target/sn_devops_deployment_list.do
```

#### 5. **Plugin Not Configured**

The ServiceNow DevOps plugin needs proper configuration.

**Check:**
1. Navigate to **DevOps > Configuration > Orchestration Tools**
2. Verify your Tool ID exists: `f62c4e49c3fcf614e1bbf0cb050131ef`
3. Check that GitHub is properly configured as a tool

**Verify Tool Registration:**
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/sn_devops/devops/tool/orchestration?toolId=$SN_ORCHESTRATION_TOOL_ID" \
  -H "Accept: application/json" | jq '.'
```

Expected response:
```json
{
  "result": {
    "name": "GitHub Actions",
    "type": "orchestration",
    "active": "true"
  }
}
```

#### 6. **Test Runs Not in Production View**

Test workflow runs might not appear in production views.

**Test workflows:**
- `.github/workflows/test-servicenow-devops-change.yaml`

**These are for:**
- Testing the action functionality
- Verifying authentication
- Validating outputs

**They may not appear in DevOps UI because:**
- Not associated with a production application
- Different tool configuration
- Filtered out by default

**Solution:**
Use the Master pipeline for production deployments:
```bash
gh workflow run MASTER-PIPELINE.yaml --field environment=dev
```

## Verification Steps

### Step 1: Check if Registrations Exist (API)

```bash
#!/bin/bash
source .envrc

# Query DevOps API
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID" \
  -H "Accept: application/json" | jq -r '.result | length'
```

**Expected:** Number of registrations (e.g., `2`)

**If 0:** No registrations exist - run Master pipeline first

### Step 2: Check Recent Workflow Runs

```bash
gh run list --repo Freundcloud/microservices-demo \
  --workflow="🚀 Master CI/CD Pipeline" \
  --limit 5 --json databaseId,conclusion,createdAt
```

**Look for:**
- Recent successful runs
- Runs after migration commit `ea53f45b`

### Step 3: Check Traditional Change Requests

If `changeControl: true`, check traditional CRs:

```
https://<instance>.service-now.com/change_request_list.do?sysparm_query=u_source=GitHub%20Actions
```

### Step 4: Check DevOps Deployments Table

```
https://<instance>.service-now.com/sn_devops_deployment_list.do
```

This shows ALL deployments, regardless of `changeControl` setting.

## Expected Behavior

### When Master Pipeline Runs:

**1. DevOps Change Action Executes:**
```yaml
ServiceNow/servicenow-devops-change@v6.1.0
```

**2. Deployment Registered:**
- API call to `/api/sn_devops/v1/devops/orchestration/changeControl`
- Record created in `sn_devops_task_execution` table

**3. Traditional CR May Be Created:**
- If `changeControl: true` ➜ CR created in `change_request` table
- If `changeControl: false` ➜ NO CR, only DevOps registration

**4. Visible In:**
- ✅ DevOps Deployments table (always)
- ✅ DevOps Changes view (if `changeControl: true`)
- ✅ Traditional Change Requests table (if `changeControl: true`)

## Quick Resolution

**If you just migrated to DevOps Change action:**

1. **Trigger a deployment:**
   ```bash
   gh workflow run MASTER-PIPELINE.yaml --field environment=dev
   ```

2. **Wait for completion** (~5-10 minutes)

3. **Check DevOps Deployments:**
   ```
   https://<instance>.service-now.com/sn_devops_deployment_list.do
   ```

4. **Check DevOps Changes (if changeControl enabled):**
   ```
   https://<instance>.service-now.com/sn_devops_change_request_list.do
   ```

## Still No Changes?

### Contact ServiceNow Admin

If registrations exist in API but not visible in UI:

1. Check plugin installation:
   - Navigate to **System Applications > All Available Applications**
   - Search for "DevOps Change"
   - Verify version and activation status

2. Check permissions:
   - User may not have `sn_devops` role
   - Grant role: **DevOps > Administration > Users**

3. Check configuration:
   - **DevOps > Configuration**
   - Verify GitHub tool is configured
   - Check `changeControl` setting

### Alternative: Use API to View Registrations

Create a script to query and display registrations:

```bash
#!/bin/bash
source .envrc

curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID" \
  -H "Accept: application/json" | jq -r '.result[] |
    "Build: \(.buildNumber)\nPipeline: \(.pipelineName)\nStatus: \(.status)\nChange Control: \(.changeControl)\n---"'
```

This shows all registrations regardless of UI configuration.

## Related Documentation

- [ServiceNow DevOps Action Success](SERVICENOW-DEVOPS-ACTION-SUCCESS.md)
- [ServiceNow DevOps Action Troubleshooting](SERVICENOW-DEVOPS-ACTION-TROUBLESHOOTING.md)
- [Test ServiceNow DevOps Change Workflow](.github/workflows/test-servicenow-devops-change.yaml)

## Summary

**Most Common Issue:** Master pipeline hasn't run since migration

**Quick Fix:** Run deployment to dev environment

**Verification:** Check `/sn_devops_deployment_list.do` table
