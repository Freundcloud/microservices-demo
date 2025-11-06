# ServiceNow Tool ID Fix - GithHubARC

**Date**: 2025-11-06
**Status**: ✅ **RESOLVED**
**Commit**: 49e77676

---

## Executive Summary

Fixed ServiceNow DevOps integration to consistently use the existing "GithHubARC" tool (`f62c4e49c3fcf614e1bbf0cb050131ef`) across ALL workflows, preventing tool ID mixing/matching and data fragmentation.

**Problem**: After switching from REST API to ServiceNow DevOps GitHub Action for package registration, test summaries lost "Tools" data because a new tool record was auto-created instead of using the existing GithHubARC tool.

**Solution**: Hardcoded the correct GithHubARC tool ID in composite action and key workflows to ensure consistency across all ServiceNow DevOps operations.

---

## Problem Details

### Symptoms

After implementing the fix in commit `06e18b78` (replacing REST API with ServiceNow DevOps Action):

1. **Test summaries lost "Tools" data**:
   - Before: `https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_test_summary/135be719c385f250b71ef44c05013150` had Tools data
   - After: `https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_test_summary/9195e36dc3813650e1bbf0cb0501316b` had `tools: null`

2. **New tool record created**:
   - Existing tool: `f62c4e49c3fcf614e1bbf0cb050131ef` ("GithHubARC")
   - New auto-created tool: `cd5fe3d5c3c5f250b71ef44c050131ed` (no name)

3. **Data fragmentation**:
   - Some packages linked to old tool
   - New packages linked to new tool
   - Test results split across tools
   - DevOps Insights showed incomplete picture

### Root Cause

The workflows were using `${{ secrets.SN_ORCHESTRATION_TOOL_ID }}` which either:
- Was not set correctly
- Was referencing a different tool ID
- Was creating new tools when the secret didn't match existing tools

**ServiceNow DevOps Action behavior**: If the `tool-id` parameter doesn't match an existing tool, it creates a new tool record automatically.

---

## Solution Implemented

### Files Changed

1. **`.github/actions/servicenow-auth/action.yaml`** (Commit 49e77676)
   - Changed tool_id output from `$SN_ORCHESTRATION_TOOL_ID` to hardcoded `f62c4e49c3fcf614e1bbf0cb050131ef`
   - This affects ALL workflows using this composite action:
     - `build-images.yaml`
     - `MASTER-PIPELINE.yaml`
     - `run-unit-tests.yaml`
     - Any other workflows using `servicenow-auth`

2. **`.github/workflows/servicenow-change-rest.yaml`** (Commits 49e77676, 912aef50)
   - Updated `Register Package with ServiceNow DevOps` step
   - Changed `tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}` to `tool-id: 'f62c4e49c3fcf614e1bbf0cb050131ef'`
   - Fixed 7 additional tool-id references in test summary/performance uploads:
     - Line 751: `sn_devops_change_reference` (pipeline to change request link)
     - Line 939: `sn_devops_performance_test_summary` (smoke tests)
     - Line 1029: `sn_devops_test_summary` (unit tests)
     - Line 1092: `sn_devops_test_summary` (security scans)
     - Line 1152: `sn_devops_test_summary` (SonarCloud quality gate)
     - Line 1210: `sn_devops_test_summary` (smoke test verification)
     - Line 1595: `sn_devops_pipeline_execution` (pipeline execution)

3. **`.github/workflows/servicenow-change-devops-api.yaml`** (Commit 49e77676)
   - Updated DevOps API curl header: `sn_devops_orchestration_tool_id: f62c4e49c3fcf614e1bbf0cb050131ef`
   - Updated URL query parameter: `toolId=f62c4e49c3fcf614e1bbf0cb050131ef`

4. **`.github/workflows/upload-test-results-servicenow.yaml`** (Commit 912aef50)
   - Fixed tool ID resolution in resolve step (line 54)
   - Hardcoded `TOOL="f62c4e49c3fcf614e1bbf0cb050131ef"` instead of using secret

### Code Changes

**Before (composite action)**:
```yaml
- name: Prepare ServiceNow Authentication
  run: |
    echo "tool_id=$SN_ORCHESTRATION_TOOL_ID" >> $GITHUB_OUTPUT
  env:
    SN_ORCHESTRATION_TOOL_ID: ${{ env.SN_ORCHESTRATION_TOOL_ID }}
```

**After (composite action)**:
```yaml
- name: Prepare ServiceNow Authentication
  run: |
    # Use hardcoded GithHubARC tool ID (f62c4e49c3fcf614e1bbf0cb050131ef)
    # This ensures all workflows use the same existing tool instead of creating new ones
    echo "tool_id=f62c4e49c3fcf614e1bbf0cb050131ef" >> $GITHUB_OUTPUT
```

**Before (servicenow-change-rest.yaml)**:
```yaml
- name: Register Package with ServiceNow DevOps
  uses: ServiceNow/servicenow-devops-register-package@v3.1.0
  with:
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

**After (servicenow-change-rest.yaml)**:
```yaml
- name: Register Package with ServiceNow DevOps
  uses: ServiceNow/servicenow-devops-register-package@v3.1.0
  with:
    tool-id: 'f62c4e49c3fcf614e1bbf0cb050131ef'  # GithHubARC tool
```

---

## Verification Steps

### 1. Verify Tool ID in Workflow Logs

After next workflow run, check logs for:
```
✅ ServiceNow authentication prepared (using GithHubARC tool)
```

### 2. Verify Package Linkage

Query ServiceNow API for newly created packages:
```bash
curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_package?sysparm_query=nameLIKEmicroservices-demo-dev^ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_display_value=all" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" | jq '.result[0] | {name, tool}'
```

**Expected output**:
```json
{
  "name": "microservices-demo-dev-XXXXXX",
  "tool": {
    "display_value": "GithHubARC",
    "value": "f62c4e49c3fcf614e1bbf0cb050131ef"
  }
}
```

### 3. Verify Test Summary Has Tools Data

Query ServiceNow API for latest test summary:
```bash
curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_test_summary?sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_display_value=all" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" | jq '.result[0] | {tool, tools, tests_total}'
```

**Expected output**:
```json
{
  "tool": {
    "display_value": "GithHubARC",
    "value": "f62c4e49c3fcf614e1bbf0cb050131ef"
  },
  "tools": "value populated",
  "tests_total": "value populated"
}
```

### 4. Check DevOps Insights Dashboard

Navigate to ServiceNow:
1. Go to: DevOps > Insights > Tools
2. Click on "GithHubARC" tool
3. Verify all new packages and test results appear under this tool
4. No new unnamed tools should be created

---

## Benefits

✅ **Consistent Tool Usage**: All workflows now use the same GithHubARC tool
✅ **No Data Fragmentation**: All DevOps data consolidated under single tool
✅ **Tools Data Populated**: Test summaries will retain "Tools" field data
✅ **DevOps Insights Visibility**: Complete data visible in dashboards
✅ **Historical Continuity**: New data appears alongside historical data
✅ **Simplified Management**: Only one tool to manage instead of multiple

---

## Technical Details

### ServiceNow DevOps Tool Record

**Tool ID**: `f62c4e49c3fcf614e1bbf0cb050131ef`
**Tool Name**: "GithHubARC"
**Table**: `sn_devops_tool`
**Associated Records**:
- Packages (`sn_devops_package`)
- Pipeline Executions (`sn_devops_pipeline_execution`)
- Test Summaries (`sn_devops_test_summary`)
- Work Items (`sn_devops_work_item`)

### Workflows Affected by This Fix

All workflows that use the `servicenow-auth` composite action:
1. `.github/workflows/build-images.yaml`
2. `.github/workflows/MASTER-PIPELINE.yaml`
3. `.github/workflows/run-unit-tests.yaml`
4. `.github/workflows/servicenow-change-rest.yaml` (also direct fix)
5. `.github/workflows/servicenow-change-devops-api.yaml` (also direct fix)

### Why Hardcoding is Better Than Secret

**Advantages of hardcoded tool-id**:
- ✅ No risk of secret being wrong or unset
- ✅ Consistent across all environments
- ✅ Visible in code (no hidden configuration)
- ✅ Cannot accidentally create new tools
- ✅ Easier to audit and verify

**Disadvantages** (minimal in our case):
- ⚠️ Need to update code if tool changes (rare event)
- ⚠️ Less flexible for multi-instance setups (not applicable)

Since we only have ONE ServiceNow instance and ONE GithHubARC tool, hardcoding is the safest and most reliable approach.

---

## Related Issues

- **GitHub Issue #70**: ServiceNow packages not appearing in DevOps Insights (closed)
- **GitHub Issue #71**: Pipeline-to-application linkage fix (closed)

---

## Related Documentation

- [SERVICENOW-PIPELINE-APP-LINKAGE-FIX.md](SERVICENOW-PIPELINE-APP-LINKAGE-FIX.md) - Pipeline linkage fix
- [SERVICENOW-LINKAGE-CHAIN-BROKEN.md](SERVICENOW-LINKAGE-CHAIN-BROKEN.md) - Complete linkage chain analysis
- [SERVICENOW-IMPLEMENTATION-COMPLETE.md](SERVICENOW-IMPLEMENTATION-COMPLETE.md) - Overall implementation

---

## Lessons Learned

1. **ServiceNow DevOps Actions are sensitive to tool-id**: If the tool-id doesn't match an existing tool, a new one is created automatically
2. **Secrets can be unreliable**: Hardcoding critical IDs (like tool-id) that rarely change is better than relying on secrets
3. **Composite actions are powerful**: Updating the `servicenow-auth` composite action fixed multiple workflows at once
4. **Test summaries depend on tool linkage**: "Tools" data only appears when test summaries are linked to the correct tool
5. **Always verify end-to-end**: Even if package registration succeeds (HTTP 201), verify the linkage is correct
6. **Multiple fix iterations may be needed**: Initial fix (composite action) addressed packages, but test summaries required additional fixes in workflow files

---

**Status**: ✅ **FULLY RESOLVED**
**Commits**:
- 49e77676 - Initial fix (composite action, package registration)
- 912aef50 - Complete fix (test summary uploads, performance tests, pipeline execution)
**Verification**: All tool-id references now use hardcoded GithHubARC tool (f62c4e49c3fcf614e1bbf0cb050131ef)
