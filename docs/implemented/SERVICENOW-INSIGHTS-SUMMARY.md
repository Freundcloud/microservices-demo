# ServiceNow Insights - Complete Analysis & Action Plan

> **Date**: 2025-11-05
> **Status**: 🎯 ROOT CAUSE IDENTIFIED
> **Issue**: #68
> **Priority**: HIGH

---

## TL;DR

**Problem**: `sn_devops_insights_st_summary` table is empty

**Root Cause**: Change requests ARE being created, but:
1. **App field is empty** - not linked to "Online Boutique" application
2. **Pipeline executions not created** - no linkage data
3. **Packages not created** - registration jobs may be failing silently

**Fix**: Add `application` field to change request API payloads

---

## What We Discovered

### ❌ Initial Hypothesis (INCORRECT)
"Repository not linked to application" → We fixed repository linkage but problem persisted

### ✅ Actual Problem
**Change requests are created but App field is empty because application sys_id is not passed in API call**

### Evidence from ServiceNow UI

User provided screenshot showing recent change requests:

| Created | State | Short Description | **App** | Pipeline | Package |
|---------|-------|-------------------|---------|----------|---------|
| 2025-11-05 22:24:29 | Assess | Deploy microservices to dev (Kubernetes) [dev] | **(empty)** | | (empty) |
| 2025-11-05 22:24:09 | Assess | Deploy microservices to dev [dev] | **(empty)** | | (empty) |
| 2025-11-05 22:04:51 | Assess | Deploy microservices to dev (Kubernetes) [dev] | **(empty)** | | (empty) |
| 2025-11-05 22:04:39 | Assess | Deploy microservices to dev [dev] | **(empty)** | | (empty) |

**Key Finding**: Change requests exist but are NOT linked to the "Online Boutique" application.

---

## Technical Analysis

### Code Location
`.github/workflows/servicenow-change-devops-api.yaml` (Lines 179-196)

### Current Payload (Missing Application)
```json
{
  "autoCloseChange": true,
  "setCloseCode": true,
  "callbackURL": "https://github.com/.../actions/runs/...",
  "orchestrationTaskURL": "https://github.com/.../actions/runs/...",
  "attributes": {
    "short_description": "Deploy microservices to dev [dev]",
    "description": "Automated deployment to dev environment via GitHub Actions",
    "assignment_group": "GitHubARC DevOps Admin",
    "assigned_to": "Olaf Krasicki-Freund",
    "implementation_plan": "...",
    "backout_plan": "...",
    "test_plan": "...",
    "category": "DevOps",
    "subcategory": "Deployment",
    "justification": "Automated deployment via CI/CD pipeline"
    // ❌ MISSING: "application" field
  }
}
```

### Required Fix
```json
{
  "attributes": {
    // ... existing fields ...
    "application": "e489efd1c3383e14e1bbf0cb050131d5"  // ✅ ADD THIS
  }
}
```

---

## Why Insights Table is Empty

### Data Flow Explanation

```
GitHub Actions Workflow
    ↓
Creates Change Request via DevOps API
    ↓
Change Request Created ✅
    ├─ BUT: App field = null ❌
    ├─ Pipeline executions = null ❌
    └─ Packages = null ❌
    ↓
ServiceNow Scheduled Jobs
"[DevOps] Daily Data Collection"
"[DevOps] Historical Data Collection"
    ↓
Aggregate data for Application:
    ↓
Query: SELECT * FROM sn_devops_*
       WHERE app = 'e489efd1c3383e14e1bbf0cb050131d5'
    ↓
Result: 0 records ❌
(because app field is null on all records)
    ↓
sn_devops_insights_st_summary: EMPTY ❌
```

### The Chain Reaction

1. ❌ Change request created without `app` field
2. ❌ Pipeline execution not created (or not linked)
3. ❌ Packages not registered (or not linked)
4. ❌ Test results not uploaded (or not linked)
5. ❌ Work items not created (or not linked)
6. ❌ Scheduled jobs can't aggregate data (no app linkage)
7. ❌ `sn_devops_insights_st_summary` remains empty

---

## Action Plan

### Phase 1: Fix Change Request App Linkage (HIGH PRIORITY)

**File**: `.github/workflows/servicenow-change-devops-api.yaml`

**Change** (line ~195):
```yaml
# Before:
"justification": "Automated deployment via CI/CD pipeline. Changes have been tested and approved via pull request workflow."

# After:
"justification": "Automated deployment via CI/CD pipeline. Changes have been tested and approved via pull request workflow.",
"application": "e489efd1c3383e14e1bbf0cb050131d5"
```

**Benefit**: All future change requests will be linked to "Online Boutique" application.

### Phase 2: Investigate Package Registration (HIGH PRIORITY)

**Issue**: Even with correct app linkage, packages, pipeline executions, and test results are not appearing.

**Investigation Needed**:
1. Check if `📦 Register Packages in ServiceNow` job is actually calling ServiceNow API
2. Check HTTP responses (are they 201 Created or errors?)
3. Check if `sn_devops_package` table is writable
4. Check if package payload includes `app` field

**Action**:
```bash
# Review package registration workflow
cat .github/workflows/MASTER-PIPELINE.yaml | grep -A 50 "Register Packages"
```

### Phase 3: Add Verbose Logging (MEDIUM PRIORITY)

**Problem**: Jobs report success but no data in ServiceNow.

**Solution**: Add HTTP response logging to all ServiceNow API calls.

**Example**:
```yaml
- name: Register Package
  run: |
    RESPONSE=$(curl -v -X POST ... "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package")

    HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP/\d\.\d \K\d+')

    echo "HTTP Status: $HTTP_CODE"
    echo "Response: $RESPONSE"

    if [ "$HTTP_CODE" != "201" ]; then
      echo "❌ FAILED to register package"
      exit 1
    fi
```

### Phase 4: Remove Silent Failures (MEDIUM PRIORITY)

**Problem**: `continue-on-error: true` hides failures.

**Action**: Search and remove:
```bash
grep -rn "continue-on-error: true" .github/workflows/ | grep -i servicenow
```

**Fix**: Remove `continue-on-error` from all ServiceNow integration jobs.

### Phase 5: Verify Data Appears (VERIFICATION)

After implementing fixes:

```bash
# 1. Trigger workflow
gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev

# 2. Wait for completion
gh run watch

# 3. Check if change request has app field
./scripts/check-insights-data.sh

# 4. Verify insights summary populated
curl -s -u "$USER:$PASS" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5" \
  | jq '.result[] | {pipeline_executions, tests, commits, pass_percentage}'
```

---

## Quick Wins

### Win #1: Add Application to Change Request (5 minutes)

**File**: `.github/workflows/servicenow-change-devops-api.yaml`
**Line**: ~195
**Change**: Add `"application": "e489efd1c3383e14e1bbf0cb050131d5"` to attributes

**Impact**: Immediate - all future change requests will be linked to app

### Win #2: Check if Tool Can Be Linked to App (10 minutes)

Alternative approach: Link the GithHubARC tool to the Online Boutique application in ServiceNow UI.

**Steps**:
1. Navigate to: ServiceNow → DevOps → Tools
2. Find: GithHubARC
3. Edit: Add "Default Application" = "Online Boutique"
4. Save

**If this works**: All data from this tool will automatically link to the app without code changes.

---

## Diagnostic Scripts

### Check Current State
```bash
# Check repository linkage
./scripts/verify-repository-linkage.sh

# Check DevOps data
./scripts/check-insights-data.sh

# Check for orphaned data
./scripts/check-orphaned-data.sh

# Full diagnostic
./scripts/diagnose-servicenow-insights.sh
```

### Expected Output After Fix
```
✅ Repository linked to application
✅ Change requests: 5+ records (with App field populated)
✅ Pipeline executions: 3+ records
✅ Packages: 12+ records (one per service)
✅ Test results: 50+ records
✅ Insights summary: 1 record with metrics
```

---

## Related Issues & Documentation

- **GitHub Issue**: #68 - ServiceNow DevOps data not being uploaded
- **Analysis**: `docs/SERVICENOW-INSIGHTS-REAL-ISSUE.md`
- **Original (Incorrect) Analysis**: `docs/SERVICENOW-INSIGHTS-MISSING-APPLICATION-DATA.md`
- **Test Summary Fix**: `docs/SERVICENOW-TEST-SUMMARY-ANALYSIS.md`

---

## Key Takeaways

### 1. Always Verify End-to-End
Don't trust green checkmarks. Always verify data actually appears in the target system.

### 2. Repository Linkage Was a Red Herring
Repository IS linked correctly, but that's not enough. Every record (change request, package, test result) needs the `app` field.

### 3. Missing Application Field is the Culprit
ServiceNow scheduled jobs aggregate data by application. If `app` field is null, data can't be aggregated.

### 4. Silent Failures Hide Problems
`continue-on-error: true` and lack of HTTP response logging make debugging extremely difficult.

---

## Timeline

| Time | Event |
|------|-------|
| 2025-11-05 14:00 | User reports: `sn_devops_insights_st_summary` empty |
| 2025-11-05 16:00 | Hypothesis: Repository linkage issue |
| 2025-11-05 17:00 | Fixed repository linkage (field name `app`) |
| 2025-11-05 19:00 | Still no data - hypothesis incorrect |
| 2025-11-05 20:00 | Discovered: NO data being uploaded at all |
| 2025-11-05 21:00 | User shows: Change requests ARE created |
| 2025-11-05 21:30 | **ROOT CAUSE**: App field is empty on change requests |
| 2025-11-05 22:00 | Found code: DevOps API payload missing `application` field |
| 2025-11-05 22:30 | Created action plan and fix recommendations |

---

## Next Steps

1. ✅ Root cause identified - App field missing from API payload
2. ⏳ **IMMEDIATE**: Add `application` field to change request API call
3. ⏳ **NEXT**: Investigate why packages/pipelines not being created
4. ⏳ Add verbose logging to all ServiceNow API calls
5. ⏳ Remove `continue-on-error` from ServiceNow jobs
6. ⏳ Test end-to-end and verify insights summary populates

---

**Priority**: 🔥 HIGH - Implement Phase 1 immediately (5 minute fix)
**Impact**: Unblocks DevOps Insights, DORA metrics, compliance tracking
**Owner**: DevOps Team
**Last Updated**: 2025-11-05 22:30 UTC
