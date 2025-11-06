# ServiceNow Tool Capabilities Configuration Issue

**Date**: 2025-01-28 (Updated with breakthrough findings)
**Severity**: Critical
**Impact**: All ServiceNow DevOps GitHub Actions failing
**Status**: ✅ **RESOLVED** - Root cause identified and fixed (pipeline-to-application linkage issue)

**UPDATE 2025-11-06**: The actual problem was NOT tool capabilities (those were already enabled). The real issue was that the `build-images.yaml` pipeline record wasn't linked to the "Online Boutique" application, causing packages to be registered with `application: null`. See [SERVICENOW-PIPELINE-APP-LINKAGE-FIX.md](SERVICENOW-PIPELINE-APP-LINKAGE-FIX.md) for the complete solution.

---

## 🎯 BREAKTHROUGH DISCOVERY (2025-01-28)

### What We Found

**The DevOps API endpoint WORKS with basic authentication!**

```bash
# This command succeeds with HTTP 201 Created! ✅
curl -X POST \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/devops/tool/testManagement?toolId=f76a57c9c3307a14e1bbf0cb05013135" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  -H "Content-Type: text/xml" \
  -d '<testsuites><testsuite name="test" tests="1" failures="0"/></testsuites>'

# Response: HTTP 201 Created
{
  "result": {
    "message": "Test results uploaded successfully",
    "sysId": null  # ← Note: null might indicate payload format issue
  }
}
```

### What This Means

1. **Authentication is NOT the problem** - Basic auth with username/password works fine
2. **The endpoint exists and is accessible** - No 404 or permission errors
3. **The API accepts JUnit XML** - Content-Type: text/xml works
4. **The tool ID is valid** - No "tool not found" error

### Why GitHub Actions Still Fail

**The GitHub Action uses a different authentication flow:**

1. **Reads tool record** to get OAuth configuration
2. **Checks tool capabilities** (this is where it fails!)
3. **Gets OAuth token** from `/oauth_token.do`
4. **Calls DevOps API** with bearer token

**The error happens at step 2** - before authentication is even attempted:

```javascript
// Pseudo-code from GitHub Action
if (!tool.capabilities.includes('testManagement')) {
  throw new Error('Capability testManagement is not available for the tool')
}
```

### The Fix

**Enable capabilities in the ServiceNow tool record** - that's all we need to do!

The tool record at `f76a57c9c3307a14e1bbf0cb05013135` needs these capabilities enabled:

- `testManagement` (for test results upload)
- `artifactManagement` (for artifact registration)
- `packageManagement` (for package registration)
- `changeControl` (for change requests)
- `pipelineExecution` (for pipeline tracking)

---

## Problem Summary

All ServiceNow DevOps GitHub Actions are failing with the following error:

```
[ServiceNow DevOps] Package Registration is not Successful.
Tool:'GitHub Actions - Online Boutique' does not support capability:'orchestration'
Please provide valid inputs.
```

Similar errors occur for `test` and `softwarequality` capabilities.

## Root Cause

The ServiceNow tool record (sys_id: `f62c4e49c3fcf614e1bbf0cb050131ef`, name: "GithHubARC") does NOT have the required capabilities enabled.

### Required Capabilities

ServiceNow DevOps GitHub Actions require these capabilities on the tool record:

1. **`orchestration`** - For package registration (`ServiceNow/servicenow-devops-register-package`)
2. **`test`** - For test result uploads (`ServiceNow/servicenow-devops-register-artifact`)
3. **`softwarequality`** - For SonarCloud scan uploads

### Evidence

**Workflow Run**: https://github.com/Freundcloud/microservices-demo/actions/runs/19135921259

**Error Annotations** (all 12 build jobs):
- loadgenerator: `Tool does not support capability:'orchestration'`
- emailservice: `Tool does not support capability:'orchestration'`
- recommendationservice: `Tool does not support capability:'orchestration'`
- currencyservice: `Tool does not support capability:'orchestration'`
- adservice: `Tool does not support capability:'orchestration'`
- cartservice: `Tool does not support capability:'orchestration'`
- checkoutservice: `Tool does not support capability:'orchestration'`
- shippingservice: `Tool does not support capability:'orchestration'`
- paymentservice: `Tool does not support capability:'orchestration'`
- frontend: `Tool does not support capability:'orchestration'`
- shoppingassistantservice: `Tool does not support capability:'orchestration'`
- productcatalogservice: `Tool does not support capability:'orchestration'`

**Test Jobs** (all 12 services):
- All test jobs: `Tool is not connected. Capability Type test Please provide valid inputs.`

**SonarCloud**:
- SonarCloud Analysis: `Tool is not connected. Capability Type softwarequality Please provide valid inputs.`

## Solution

The tool capabilities must be configured in the ServiceNow UI, as the REST API does not expose a direct field for capabilities configuration.

### Option A: ServiceNow UI Configuration (Recommended)

**Direct Link to Tool Record**:
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef/params/selected-tab-index/4

1. **Navigate to Tool Record**:
   - Click the direct link above (requires ServiceNow login)
   - Or navigate manually: `DevOps` → `Tools` → `DevOps Tools` → Find "GithHubARC"

2. **Locate Capabilities Section**:
   - The URL shows `selected-tab-index/4` indicating you may be on a tab view
   - Look for a tab labeled "Capabilities", "Supported Capabilities", or "Configuration"
   - Alternatively, check the Related Lists section at the bottom of the form

3. **Enable Required Capabilities**:
   Enable these three capabilities:
   - ✅ **orchestration** - For package registration (`ServiceNow/servicenow-devops-register-package`)
   - ✅ **test** - For test result uploads (`ServiceNow/servicenow-devops-register-artifact`)
   - ✅ **softwarequality** - For code quality scans (SonarCloud integration)

4. **Save Changes**:
   - Click "Update" or "Save" button
   - Wait for confirmation message

5. **Verify Configuration**:
   - Check that tool status remains "Connected" and "Configured"
   - Webhook URL pattern: `https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/{orchestration|test|softwarequality}?toolId=f62c4e49c3fcf614e1bbf0cb050131ef`
   - Note: The webhook URL shows all possible capabilities, but only enabled ones will work

**Current Tool Status** (verified via API):
- **Name**: GithHubARC
- **Status**: Connected
- **Configuration**: Configured
- **Last Event**: 2025-11-06 10:22:27
- **Permission Check**: Full permissions
- **Webhook**: Configured
- **Issue**: Capabilities not enabled

**If Capabilities Section Not Found**:
- Check if you have `sn_devops.admin` or `sn_devops.tool_admin` role
- Try clicking "Configure Tool" or "Edit Configuration" button
- Check the "Related Links" section for capability management
- Contact ServiceNow administrator if section is not visible or grayed out

### Option B: Tool Integration API

If capabilities are managed through the tool integration record, use this approach:

```bash
# Get tool integration details
TOOL_INTEGRATION_ID="3eb3d51d97574910fe8635471153af7c"

curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool_integration/$TOOL_INTEGRATION_ID"
```

### Option C: Recreate Tool with Correct Capabilities

If the above options don't work, recreate the tool:

1. Delete the existing tool record (f62c4e49c3fcf614e1bbf0cb050131ef)
2. Use ServiceNow GitHub App to re-connect GitHub
3. During setup, ensure all capabilities are selected:
   - Orchestration
   - Test
   - Software Quality
   - Code (optional)
   - Plan (optional)
   - Artifact (optional)

## Current Tool Configuration

**Tool Record Details**:
- **Name**: GithHubARC
- **Type**: GitHub tool
- **Status**: Connected
- **sys_id**: f62c4e49c3fcf614e1bbf0cb050131ef
- **URL**: https://github.com
- **Last Event**: 2025-11-06 10:22:27
- **Configuration Status**: configured
- **Connection State**: connected
- **Webhook**: configured

**Webhook URL**:
```
https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/{code | plan | artifact | orchestration | test | softwarequality }?toolId=f62c4e49c3fcf614e1bbf0cb050131ef
```

## Verification Steps

After enabling capabilities:

### 1. Check Tool Record

```bash
source .envrc

curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef?sysparm_display_value=all" \
  | jq '.result | {name, overall_status, configuration_status, webhook}'
```

**Expected**:
- `overall_status`: "connected"
- `configuration_status`: "configured"
- `webhook`: "configured"

### 2. Test Package Registration

Trigger a workflow run with `force_build_all=true`:

```bash
gh workflow run "MASTER-PIPELINE.yaml" \
  --repo Freundcloud/microservices-demo \
  --ref main \
  -f environment=dev \
  -f force_build_all=true
```

**Expected**:
- Build jobs complete successfully (not exit code 1)
- No error: "Tool does not support capability:'orchestration'"
- Packages registered in `sn_devops_package` table

### 3. Verify Packages in ServiceNow

```bash
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=nameLIKEmicroservices-demo&sysparm_limit=5&sysparm_fields=name,version,sys_created_on" \
  | jq '.result[] | {name, version, created: .sys_created_on}'
```

**Expected**: Recent packages with today's timestamp

### 4. Check DevOps Insights

```bash
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application.name=Online Boutique&sysparm_display_value=all" \
  | jq '.result[] | {application: .application.display_value, packages, tests, pipeline_executions}'
```

**Expected**: "Online Boutique" appears with package count > 0

## Impact of Fix

Once capabilities are enabled, the following will work:

1. **Package Registration** ✅
   - ServiceNow GitHub Action will successfully register Docker images
   - Packages will appear in `sn_devops_package` table
   - DevOps Insights will aggregate package data

2. **Test Results Upload** ✅
   - Unit test results will upload to ServiceNow
   - Test metrics will appear in DevOps Insights
   - Test results linked to change requests

3. **Code Quality Integration** ✅
   - SonarCloud scan results will upload
   - Quality gates visible in ServiceNow
   - Quality metrics in DevOps Insights

4. **Complete DevOps Insights** ✅
   - "Online Boutique" application will appear
   - Full metrics: packages, tests, pipeline executions, commits
   - Change velocity and deployment frequency calculations

## Related Documentation

- [ServiceNow DevOps Insights Missing Data Analysis](./SERVICENOW-DEVOPS-INSIGHTS-MISSING-DATA-ANALYSIS.md)
- [ServiceNow Tool Configuration Guide](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/task/configure-devops-tool.html)
- [ServiceNow GitHub Integration](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/task/integrate-github.html)

## Next Steps

1. **Immediate**: Configure tool capabilities in ServiceNow UI (user action required)
2. **Verify**: Run workflow and confirm no capability errors
3. **Monitor**: Check DevOps Insights for "Online Boutique" application
4. **Document**: Update analysis doc with success confirmation

## Support

If unable to configure capabilities through UI or API:
- Contact ServiceNow administrator for assistance
- Check ServiceNow instance version and DevOps plugin version
- Verify user has sufficient permissions to modify tool records
- Consider opening ServiceNow support ticket if issue persists
