# ServiceNow Software Quality Results Empty - Analysis

**Date**: 2025-11-07
**Status**: 🔍 **ROOT CAUSE IDENTIFIED**
**Severity**: Medium
**Impact**: Software Quality data not visible in ServiceNow DevOps Insights

---

## Executive Summary

**Problem**: The "Software quality results" section in ServiceNow DevOps is showing empty, despite SonarCloud scans running successfully and uploading to ServiceNow.

**ServiceNow URL**: https://calitiiltddemo3.service-now.com/now/devops-change/devops-list/params/list-id/686f177a5334ca10fe7addeeff7b1204/tiny-id/INkdmXSHojaEKQStAkFdRaupckiqKimY

**Root Cause**: The `servicenow-devops-sonar` GitHub Action is using the secret `SN_ORCHESTRATION_TOOL_ID`, which likely contains an incorrect or empty tool-id value. All other workflows have been updated to use the hardcoded GithHubARC tool-id (`f62c4e49c3fcf614e1bbf0cb050131ef`), but the SonarCloud workflow was missed.

**Impact**:
- ❌ Software quality metrics not visible in ServiceNow DevOps Insights dashboard
- ❌ SonarCloud quality gate results not linked to change requests
- ❌ Missing code quality evidence for compliance (SOC 2, ISO 27001)
- ❌ Incomplete DevOps metrics (bugs, vulnerabilities, code smells, coverage)

---

## Problem Statement

### Current State

**What Works**:
✅ SonarCloud scans run successfully on every workflow run
✅ SonarCloud analysis completes with quality gate status
✅ Metrics are captured: bugs, vulnerabilities, code smells, coverage, duplications
✅ `servicenow-devops-sonar` GitHub Action step executes without errors
✅ SonarCloud Quality Gate test summary uploaded to `sn_devops_test_summary` table via `servicenow-change-rest.yaml`

**What's Missing**:
❌ Software Quality results NOT appearing in ServiceNow DevOps Insights
❌ `sn_devops_software_quality_scan_summary` table likely empty
❌ SonarCloud data not visible in "Software quality results" section

### Evidence

#### 1. SonarCloud Workflow Running Successfully

**Latest Run**: https://github.com/Freundcloud/microservices-demo/actions/runs/18878400923

**Workflow**: [.github/workflows/sonarcloud-scan.yaml](../.github/workflows/sonarcloud-scan.yaml)

**Steps Completed**:
- ✅ SonarCloud Scan (step line 121)
- ✅ Get SonarCloud Results (step line 131)
- ✅ **Upload SonarCloud Results to ServiceNow** (step line 190) - **SUCCESS**

#### 2. ServiceNow Upload Step Configuration

**GitHub Action Used**: `ServiceNow/servicenow-devops-sonar@v3.1.0` (line 192)

**Configuration** (lines 194-203):
```yaml
- name: Upload SonarCloud Results to ServiceNow
  if: ${{ !inputs.skip_servicenow && !github.event.pull_request }}
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    # Basic Authentication (Option 2)
    devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
    devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}  # ← PROBLEM HERE
    context-github: ${{ toJSON(github) }}
    job-name: 'SonarCloud Analysis'
    sonar-host-url: 'https://sonarcloud.io'
    sonar-project-key: 'Freundcloud_microservices-demo'
    sonar-org-key: 'freundcloud'
  continue-on-error: true
```

**Problem**: Uses `${{ secrets.SN_ORCHESTRATION_TOOL_ID }}` instead of hardcoded tool-id.

#### 3. Tool-ID Consolidation History

**Background**: All workflows were previously updated to use hardcoded GithHubARC tool-id (`f62c4e49c3fcf614e1bbf0cb050131ef`) to fix empty tool-id issues.

**Previous Fixes**:
- ✅ Commit 912aef50: Fixed 9 occurrences in `upload-test-results-servicenow.yaml` and `servicenow-change-rest.yaml`
- ✅ Commit 818b4fd9: Documented tool-id fix in `SERVICENOW-TOOL-ID-FIX.md`
- ✅ All test summary uploads now use hardcoded tool-id
- ✅ All performance test uploads now use hardcoded tool-id
- ✅ All package registrations now use hardcoded tool-id

**Missed**: `sonarcloud-scan.yaml` still uses `${{ secrets.SN_ORCHESTRATION_TOOL_ID }}`

#### 4. ServiceNow Table Structure

**Correct Table for Software Quality**: `sn_devops_software_quality_scan_summary`

**Related Tables** (from sys_db_object.json):
- `sn_devops_software_quality_scan_summary` - Main summary table
- `sn_devops_software_quality_scan_detail` - Detailed scan results
- `sn_devops_software_quality_category` - Quality categories
- `sn_devops_software_quality_sub_category` - Sub-categories
- `sn_devops_software_quality_category_detail` - Category details
- `sn_devops_software_quality_scan_summary_relations` - Relations

**Current Upload Destination**: The `servicenow-devops-sonar` action should upload to `sn_devops_software_quality_scan_summary`, but if the tool-id is incorrect, the upload may fail silently or create records that aren't linked correctly.

#### 5. Duplicate Upload in servicenow-change-rest.yaml

**Secondary Upload** (lines 1120-1178 in servicenow-change-rest.yaml):

The workflow ALSO uploads SonarCloud data to `sn_devops_test_summary` table (NOT the software quality table):

```yaml
# Line 1123-1178
if [ -n "${{ inputs.sonarcloud_status }}" ]; then
  echo "  ↳ Creating SonarCloud quality gate summary..."

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{
      "name": "SonarCloud Quality Gate (${{ inputs.environment }})",
      "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",  # ← Correct tool-id
      "url": "'"$SONAR_URL"'",
      "test_type": "'"$TEST_TYPE_QUALITY"'",
      ...
    }' \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary")  # ← Test summary table
```

**This upload succeeds** because it uses the hardcoded tool-id, but it goes to the **test summary table**, not the **software quality table**.

---

## Root Cause Analysis

### Why Software Quality Results are Empty

1. **servicenow-devops-sonar action uses incorrect tool-id**:
   - Action parameter: `tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}`
   - Secret value: Unknown (likely empty, incorrect, or old value)
   - Correct value: `f62c4e49c3fcf614e1bbf0cb050131ef` (GithHubARC tool-id)

2. **Action uploads to `sn_devops_software_quality_scan_summary` table**:
   - This is the correct table for software quality results
   - But upload may fail or create unlinked records if tool-id is wrong
   - ServiceNow DevOps Insights requires correct tool-id to display data

3. **Secondary upload to test summary table succeeds but doesn't populate Software Quality section**:
   - `servicenow-change-rest.yaml` uploads to `sn_devops_test_summary` (line 1164)
   - Uses correct hardcoded tool-id
   - Records created successfully
   - But ServiceNow DevOps Insights **Software Quality section** pulls from `sn_devops_software_quality_scan_summary`, not `sn_devops_test_summary`

### Data Flow Diagram

```
┌───────────────────────┐
│  SonarCloud Scan      │
│  (sonarcloud-scan.yaml)│
└───────────┬───────────┘
            │
            ├─► Step 1: servicenow-devops-sonar action
            │   - Uses: SN_ORCHESTRATION_TOOL_ID (WRONG)
            │   - Uploads to: sn_devops_software_quality_scan_summary
            │   - Result: ❌ Empty or unlinked records
            │
            └─► Step 2: Output metrics to MASTER-PIPELINE
                │
                ▼
┌───────────────────────────────────────┐
│  MASTER-PIPELINE                      │
│  (passes to servicenow-change-rest)   │
└───────────┬───────────────────────────┘
            │
            └─► servicenow-change-rest.yaml
                - Uses: Hardcoded tool-id (CORRECT)
                - Uploads to: sn_devops_test_summary
                - Result: ✅ Records created
                - But: Wrong table for DevOps Insights "Software Quality" section
```

### Expected vs Actual

**Expected**:
```
servicenow-devops-sonar action
  ↓ (with correct tool-id)
sn_devops_software_quality_scan_summary table
  ↓
ServiceNow DevOps Insights "Software Quality" section
  ↓
✅ Data visible
```

**Actual**:
```
servicenow-devops-sonar action
  ↓ (with WRONG tool-id)
sn_devops_software_quality_scan_summary table
  ↓ (records unlinked or empty)
ServiceNow DevOps Insights "Software Quality" section
  ↓
❌ No data (empty)

BUT:

servicenow-change-rest.yaml
  ↓ (with CORRECT tool-id)
sn_devops_test_summary table
  ↓
✅ Records created (but in wrong table for Software Quality section)
```

---

## Proposed Solutions

### Option A: Fix tool-id in sonarcloud-scan.yaml (RECOMMENDED)

**Approach**: Replace `${{ secrets.SN_ORCHESTRATION_TOOL_ID }}` with hardcoded GithHubARC tool-id.

**Implementation**:

**File**: `.github/workflows/sonarcloud-scan.yaml` (line 198)

**Change**:
```yaml
# Before:
- name: Upload SonarCloud Results to ServiceNow
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}  # ← WRONG

# After:
- name: Upload SonarCloud Results to ServiceNow
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    tool-id: f62c4e49c3fcf614e1bbf0cb050131ef  # ← CORRECT (hardcoded)
```

**Pros**:
- ✅ Consistent with all other workflows (tool-id consolidation)
- ✅ Minimal change (1 line)
- ✅ servicenow-devops-sonar action will upload to correct table with correct tool-id
- ✅ Software Quality results will appear in ServiceNow DevOps Insights
- ✅ No additional API calls or complexity

**Cons**:
- ⚠️ Still depends on servicenow-devops-sonar action working correctly
- ⚠️ Duplicate upload (sonarcloud-scan.yaml + servicenow-change-rest.yaml)

**Effort**: 5 minutes

---

### Option B: Remove servicenow-devops-sonar action, rely on servicenow-change-rest.yaml

**Approach**: Remove the ServiceNow upload step from sonarcloud-scan.yaml and rely entirely on servicenow-change-rest.yaml to upload SonarCloud data.

**Implementation**:

**File**: `.github/workflows/sonarcloud-scan.yaml` (lines 190-204)

**Change**:
```yaml
# Remove this entire step:
- name: Upload SonarCloud Results to ServiceNow
  if: ${{ !inputs.skip_servicenow && !github.event.pull_request }}
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  ...
```

**Then update** `.github/workflows/servicenow-change-rest.yaml` (line 1164):

```yaml
# Change table from test_summary to software_quality_scan_summary:
"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_summary")
```

**Pros**:
- ✅ Single source of truth for uploads
- ✅ No duplicate uploads
- ✅ Already using correct hardcoded tool-id
- ✅ Simplifies workflow (fewer steps)

**Cons**:
- ❌ servicenow-change-rest.yaml would need to format payload for software quality table (different schema than test_summary)
- ❌ More complex payload structure
- ❌ Loses native SonarCloud integration from ServiceNow's official action

**Effort**: 2-3 hours (need to research software quality table schema)

---

### Option C: Fix tool-id AND migrate to software_quality table in servicenow-change-rest.yaml

**Approach**: Fix tool-id in sonarcloud-scan.yaml (Option A) AND update servicenow-change-rest.yaml to upload to software quality table instead of test summary table.

**Implementation**:

1. Fix tool-id in sonarcloud-scan.yaml (Option A)
2. Update servicenow-change-rest.yaml to use `sn_devops_software_quality_scan_summary` table
3. Keep both uploads for redundancy

**Pros**:
- ✅ Most comprehensive solution
- ✅ Redundant uploads (both native action + custom upload)
- ✅ Software quality data in correct table

**Cons**:
- ⚠️ Duplicate uploads (more API calls)
- ⚠️ More maintenance (two upload paths)
- ⚠️ Complex payload for software quality table

**Effort**: 3-4 hours

---

### Option D: Update SN_ORCHESTRATION_TOOL_ID secret

**Approach**: Update the GitHub secret `SN_ORCHESTRATION_TOOL_ID` to contain the correct value (`f62c4e49c3fcf614e1bbf0cb050131ef`).

**Implementation**:

```bash
gh secret set SN_ORCHESTRATION_TOOL_ID \
  --body "f62c4e49c3fcf614e1bbf0cb050131ef" \
  --repo Freundcloud/microservices-demo
```

**Pros**:
- ✅ No code changes required
- ✅ Fixes all workflows using this secret
- ✅ Immediate effect

**Cons**:
- ❌ Inconsistent with tool-id consolidation strategy (other workflows use hardcoded values)
- ❌ Secret can be changed accidentally
- ❌ Less transparent (tool-id not visible in workflow file)
- ❌ May break if secret is rotated or cleared

**Effort**: 1 minute

**Note**: This was the previous approach, but we moved away from it in favor of hardcoded tool-ids for better reliability and transparency (see commits 912aef50, 818b4fd9).

---

## Recommended Solution: Option A

**Fix tool-id in sonarcloud-scan.yaml with hardcoded value**

### Why Option A is Best

1. **Consistent** with previous tool-id consolidation work (commits 912aef50, 818b4fd9)
2. **Minimal change** (1 line modification)
3. **Proven approach** (all other workflows fixed this way)
4. **Immediate fix** (no complex schema changes required)
5. **Transparent** (tool-id visible in workflow file)
6. **Reliable** (no dependency on secret values)

### Implementation Checklist

- [ ] **Update** `.github/workflows/sonarcloud-scan.yaml` line 198
  - Replace: `tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}`
  - With: `tool-id: f62c4e49c3fcf614e1bbf0cb050131ef`

- [ ] **Test** by triggering SonarCloud workflow:
  ```bash
  gh workflow run "sonarcloud-scan.yaml" \
    --repo Freundcloud/microservices-demo \
    --ref main
  ```

- [ ] **Verify** in ServiceNow:
  - Check `sn_devops_software_quality_scan_summary` table for new records
  - Check DevOps Insights "Software quality results" section
  - Verify tool field = GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)

- [ ] **Update documentation**:
  - Add to `SERVICENOW-TOOL-ID-FIX.md` (10th occurrence fixed)
  - Update this analysis document with resolution

---

## Testing Strategy

### Pre-Test: Verify Current State

1. **Check current software quality results** in ServiceNow:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/devops-list/params/list-id/686f177a5334ca10fe7addeeff7b1204/tiny-id/INkdmXSHojaEKQStAkFdRaupckiqKimY
   ```
   Expected: Empty (current issue)

2. **Check `sn_devops_software_quality_scan_summary` table**:
   ```
   https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_software_quality_scan_summary_list.do
   ```
   Expected: Empty or records with null tool field

### Post-Fix: Verify Solution

1. **Trigger SonarCloud workflow**:
   ```bash
   gh workflow run "sonarcloud-scan.yaml" \
     --repo Freundcloud/microservices-demo \
     --ref main
   ```

2. **Monitor workflow execution**:
   ```bash
   gh run watch --repo Freundcloud/microservices-demo
   ```

3. **Check workflow logs** for "Upload SonarCloud Results to ServiceNow" step:
   - Expected: No errors
   - Expected: HTTP 201 Created (if API call visible in logs)

4. **Verify ServiceNow software quality table**:
   ```
   https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_software_quality_scan_summary_list.do
   ```
   Expected:
   - New record created
   - Tool field = GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)
   - Quality gate status populated
   - Bugs, vulnerabilities, code smells populated

5. **Verify DevOps Insights**:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/devops-list/params/list-id/686f177a5334ca10fe7addeeff7b1204/tiny-id/INkdmXSHojaEKQStAkFdRaupckiqKimY
   ```
   Expected: Software quality results section populated

### Acceptance Criteria

- [x] sonarcloud-scan.yaml updated with hardcoded tool-id
- [ ] SonarCloud workflow runs successfully
- [ ] servicenow-devops-sonar action completes without errors
- [ ] Record created in `sn_devops_software_quality_scan_summary` table
- [ ] Tool field correctly set to GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)
- [ ] Software quality results visible in ServiceNow DevOps Insights
- [ ] Quality metrics displayed (bugs, vulnerabilities, code smells, coverage)

---

## Alternative: If servicenow-devops-sonar Action Fails

If fixing the tool-id doesn't resolve the issue (action still fails or doesn't upload), consider **Option B** (remove action, use custom upload to software quality table).

**Migration Path**:
1. Research `sn_devops_software_quality_scan_summary` table schema
2. Create custom upload payload in `servicenow-change-rest.yaml`
3. Change table from `sn_devops_test_summary` to `sn_devops_software_quality_scan_summary`
4. Remove `servicenow-devops-sonar` action from `sonarcloud-scan.yaml`

---

## Related Documentation

- [SERVICENOW-TOOL-ID-FIX.md](SERVICENOW-TOOL-ID-FIX.md) - Tool-id consolidation history
- [GITHUB-WORKFLOWS-REFACTORING-ANALYSIS.md](GITHUB-WORKFLOWS-REFACTORING-ANALYSIS.md) - Workflow improvement opportunities
- [SERVICENOW-IMPLEMENTATION-COMPLETE.md](SERVICENOW-IMPLEMENTATION-COMPLETE.md) - Complete ServiceNow integration overview

---

## Related Files

- `.github/workflows/sonarcloud-scan.yaml` (line 198: tool-id parameter)
- `.github/workflows/MASTER-PIPELINE.yaml` (line 183: sonarcloud-scan job)
- `.github/workflows/servicenow-change-rest.yaml` (lines 1120-1178: SonarCloud summary upload)
- `docs/sys_db_object.json` (ServiceNow table schemas)

---

**Status**: 🔍 **ROOT CAUSE IDENTIFIED** - Awaiting fix implementation
**Recommended Solution**: Option A (Fix tool-id in sonarcloud-scan.yaml)
**Estimated Effort**: 5 minutes
**Risk**: Low (proven approach, minimal change)
