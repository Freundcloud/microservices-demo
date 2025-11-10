# ServiceNow Insights - The REAL Issue

> **Date**: 2025-11-05
> **Status**: 🔴 CRITICAL - No data being uploaded to ServiceNow
> **Issue**: #68
> **Priority**: HIGH

---

## Executive Summary

**The `sn_devops_insights_st_summary` table is empty NOT because of repository linkage, but because NO DATA IS BEING UPLOADED TO SERVICENOW AT ALL.**

Workflow jobs report "success" but zero records are created in any ServiceNow DevOps tables.

---

## What We Discovered

### ❌ Previous Hypothesis (INCORRECT)

We thought the problem was that the repository wasn't linked to the application in ServiceNow.

**We were wrong.** The repository IS correctly linked:
- Field name: `app` (not `application`)
- Value: `e489efd1c3383e14e1bbf0cb050131d5` (Online Boutique)
- Tool: `f62c4e49c3fcf614e1bbf0cb050131ef` (GithHubARC)
- Stats: 394 commits, 15 merges tracked

### ✅ Actual Problem (CONFIRMED)

**ServiceNow jobs succeed but upload ZERO data:**

| Job | Status | Data in ServiceNow |
|-----|--------|-------------------|
| Create Change Request | ✅ Success | ❌ 0 change requests |
| Upload Security Scans | ✅ Success | ❌ 0 security results |
| Upload Test Results | ✅ Success | ❌ 0 test results |
| Register Packages | ✅ Success | ❌ 0 packages |
| Update Change | ✅ Success | ❌ 0 updates |

**Evidence**:
```bash
# Checked ServiceNow tables for data created in last 2 hours
sn_devops_package: 0 records ❌
sn_devops_test_result: 0 records ❌
change_request (last 2h): 0 records ❌
sn_devops_pipeline_execution: 0 records ❌
```

---

## Diagnostic Timeline

### Step 1: Initial Report
User reported: `sn_devops_insights_st_summary` table is empty

### Step 2: Research
Found documentation explaining:
- Insights table is populated by scheduled jobs (NOT directly by GitHub Actions)
- Scheduled jobs aggregate data from other DevOps tables
- Jobs use Platform Analytics to calculate metrics

### Step 3: Hypothesis #1 (Repository Linkage)
Thought: Repository not linked to application → Scheduled jobs can't aggregate data

**Investigation**:
- Discovered field name is `app` not `application`
- Linked repository to application via API
- Re-ran workflows

**Result**: Still no data ❌

### Step 4: Deeper Investigation
Checked if data was being created at all (orphaned or linked):
```bash
./scripts/check-orphaned-data.sh
```

**Finding**: **ZERO data in any ServiceNow tables from last 2 hours** ❌

### Step 5: Root Cause Identified
**Workflow jobs report success but don't actually upload data to ServiceNow.**

---

## Why This Was Missed

### False Positive Success
GitHub Actions jobs show ✅ green checkmarks, giving false confidence that integration is working.

### No Error Visibility
Possible causes of hidden errors:
1. `continue-on-error: true` in workflow steps
2. API errors caught and logged but not failed
3. HTTP 403/401 responses treated as "soft failures"
4. Missing `set -e` in bash scripts (errors ignored)

### Complex Data Flow
Data flows through multiple layers:
```
GitHub Actions → ServiceNow DevOps Actions → ServiceNow API → Database
```

A failure at any layer could be hidden from the user.

---

## Possible Root Causes

### 1. Silent API Failures (Most Likely)
ServiceNow API calls are failing (403, 401, 404) but errors are suppressed:
```yaml
- name: Upload to ServiceNow
  continue-on-error: true  # ← Hides failures
  run: ./upload.sh
```

### 2. Authentication Issues
The `github_integration` ServiceNow user may lack permissions to write to DevOps tables:
- `sn_devops_package` (write)
- `sn_devops_test_result` (write)
- `change_request` (write)

### 3. Wrong Table Names
Workflows may be trying to write to tables that don't exist or have been renamed.

### 4. Missing ServiceNow Plugin
DevOps Change Velocity plugin may not be fully activated in ServiceNow instance.

### 5. Tool ID Mismatch
`SN_ORCHESTRATION_TOOL_ID` secret may not match the tool sys_id in ServiceNow.

**Expected**: `f62c4e49c3fcf614e1bbf0cb050131ef`
**Need to verify**: What's actually set in GitHub Secrets?

### 6. ServiceNow Instance Issues
The demo instance (`calitiiltddemo3.service-now.com`) may have restrictions or rate limits.

---

## What We Need to Investigate

### Priority 1: Check Workflow Logs
Need to see **actual HTTP responses** from ServiceNow API:
- What status codes are returned? (200, 403, 401, 404?)
- Are error messages being logged and ignored?
- Is data being sent at all?

**Action**: Add verbose logging to ServiceNow API calls

### Priority 2: Test API Manually
Verify we can write to ServiceNow tables directly:
```bash
# Test package creation
curl -v -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-package",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "app": "e489efd1c3383e14e1bbf0cb050131d5"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package"
```

**Expected**: HTTP 201, record created
**If fails**: Check error message for permission or table issues

### Priority 3: Check ServiceNow User Permissions
Verify `github_integration` user has:
- `sn_devops.devops_user` role
- Write access to all `sn_devops_*` tables
- Write access to `change_request` table

**Action**: Log into ServiceNow and check user roles

### Priority 4: Verify Secrets
Check GitHub Secrets match ServiceNow configuration:
```bash
gh secret list --repo Freundcloud/microservices-demo

# Should see:
SN_ORCHESTRATION_TOOL_ID (set, not visible)
SERVICENOW_INSTANCE_URL (set, not visible)
SERVICENOW_USERNAME (set, not visible)
SERVICENOW_PASSWORD (set, not visible)
```

Verify tool ID matches:
```bash
# In ServiceNow:
# Expected: f62c4e49c3fcf614e1bbf0cb050131ef (GithHubARC)
```

### Priority 5: Check Plugin Activation
In ServiceNow:
1. Navigate to: **System Applications → Studio**
2. Search for: "DevOps Change Velocity"
3. Verify: Status = "Active"

---

## How to Fix

### Step 1: Enable Verbose Logging
Update workflows to show HTTP responses:
```yaml
- name: Register Package
  run: |
    RESPONSE=$(curl -v -X POST \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_package")

    HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP/\d\.\d \K\d+')

    if [ "$HTTP_CODE" != "201" ]; then
      echo "❌ ERROR: HTTP $HTTP_CODE"
      echo "$RESPONSE"
      exit 1
    fi

    echo "✅ Package created: $RESPONSE"
```

### Step 2: Remove Silent Failures
Find and remove all `continue-on-error: true` from ServiceNow jobs:
```bash
grep -r "continue-on-error: true" .github/workflows/
```

### Step 3: Test API Access
Run manual API tests to verify connectivity and permissions:
```bash
./scripts/test-servicenow-api-access.sh
```

### Step 4: Fix Root Cause
Once we identify the root cause (likely permission or authentication issue):
- Grant correct permissions in ServiceNow
- Fix authentication credentials
- Activate required plugins

---

## Scripts for Debugging

### Test ServiceNow API Access
```bash
#!/bin/bash
# scripts/test-servicenow-api-access.sh

echo "Testing ServiceNow API access..."

# Test 1: Can we authenticate?
echo "1. Testing authentication..."
curl -I -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"

# Test 2: Can we read from sn_devops_package?
echo "2. Testing read access to sn_devops_package..."
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=1" | jq '.'

# Test 3: Can we write to sn_devops_package?
echo "3. Testing write access to sn_devops_package..."
curl -s -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-package-'$(date +%s)'",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "app": "e489efd1c3383e14e1bbf0cb050131d5"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package" | jq '.'

echo ""
echo "If test 3 succeeds, the issue is in the workflow, not ServiceNow access."
```

---

## Related Issues

- **GitHub Issue**: #68 - ServiceNow DevOps data not being uploaded
- **Previous Analysis**: `docs/SERVICENOW-INSIGHTS-MISSING-APPLICATION-DATA.md` (repository linkage - incorrect)

---

## Key Takeaways

### 1. Don't Trust Green Checkmarks
Just because GitHub Actions shows ✅ doesn't mean the integration worked.

Always verify:
- Data was actually created in the target system
- HTTP responses indicate success (not just lack of error)
- End-to-end data flow is complete

### 2. Avoid Silent Failures
Never use `continue-on-error: true` on critical integration steps.

Better:
```yaml
- name: Critical Upload
  run: ./upload.sh
  # If this fails, the entire job should fail
```

### 3. Add Verbose Logging
Always log HTTP responses from external API calls:
```bash
echo "Response: $RESPONSE"
echo "HTTP Code: $HTTP_CODE"
```

### 4. Test End-to-End
After fixing integration issues, always verify data appears in the target system:
```bash
# Don't just check workflow success
# Check actual data in ServiceNow
./scripts/verify-data-uploaded.sh
```

---

## Timeline

| Time | Event |
|------|-------|
| 2025-11-05 14:00 | User reports: `sn_devops_insights_st_summary` empty |
| 2025-11-05 15:00 | Investigation: Research ServiceNow Insights architecture |
| 2025-11-05 16:00 | Hypothesis #1: Repository linkage issue |
| 2025-11-05 17:00 | Fixed repository linkage (field name `app`) |
| 2025-11-05 18:00 | Re-ran workflow - Still no data |
| 2025-11-05 19:00 | Deep investigation: Discovered NO data being uploaded |
| 2025-11-05 20:00 | Root cause: Workflows succeeding but not uploading data |
| 2025-11-05 20:30 | Created GitHub Issue #68 to track investigation |
| 2025-11-05 21:00 | Next: Debug workflow logs and test API access |

---

## Next Steps

1. ✅ **Created GitHub Issue #68** to track investigation
2. ⏳ **Review workflow logs** to find actual errors
3. ⏳ **Test ServiceNow API manually** to verify access
4. ⏳ **Check user permissions** in ServiceNow
5. ⏳ **Add verbose logging** to workflows
6. ⏳ **Remove silent failures** (`continue-on-error`)
7. ⏳ **Fix root cause** and verify data appears

---

**Document Status**: 🔴 ACTIVE INVESTIGATION
**Priority**: HIGH - Blocks DevOps Insights, DORA metrics, compliance evidence
**Owner**: DevOps Team
**Last Updated**: 2025-11-05 21:00 UTC
