# ServiceNow Change Request Missing Data Analysis

**Date**: 2025-11-07
**Change Request**: CHG0030504 (sys_id: b6d26379c3c97a50b71ef44c0501315d)
**Issue**: Missing Software Quality Summaries and Test Summaries in change request
**Status**: 🔴 **INVESTIGATION REQUIRED**

---

## Problem Statement

When viewing change request CHG0030504 in ServiceNow:
- **URL**: https://calitiiltddemo3.service-now.com/now/devops-change/record/change_request/b6d26379c3c97a50b71ef44c0501315d/params/selected-tab-index/15

**Missing Data**:
1. ❌ **Software Quality Summaries** - No SBOM scans or SonarCloud results linked
2. ❌ **Test Summaries** - No unit test results linked
3. ❌ **Performance Test Summaries** - No smoke test results linked

---

## Current State Analysis

### Change Request Details

**Record**: CHG0030504 (sys_id: b6d26379c3c97a50b71ef44c0501315d)

```json
{
  "number": "CHG0030504",
  "short_description": "Deploy microservices to dev [dev]",
  "state": "Assess",
  "u_source": "GitHub Actions",
  "u_correlation_id": "",           // ❌ Empty
  "u_repository": "",               // ❌ Empty
  "u_branch": "",                   // ❌ Empty
  "u_commit_sha": "",               // ❌ Empty
  "u_environment": "dev",
  "sys_created_on": "2025-11-07 13:04:26"
}
```

### Linked Records Check

**Query Results**:
```bash
# Software Quality Scan Summaries
curl .../sn_devops_software_quality_scan_summary?change_request=b6d26379c3c97a50b71ef44c0501315d
→ Result: 0 records ❌

# Test Summaries
curl .../sn_devops_test_summary?change_request=b6d26379c3c97a50b71ef44c0501315d
→ Result: 0 records ❌

# Performance Test Summaries
curl .../sn_devops_performance_test_summary?change_request=b6d26379c3c97a50b71ef44c0501315d
→ Result: 0 records ❌
```

---

## Root Cause Analysis

### Issue #1: Software Quality Summaries Not Linked

**SBOM Summary Record Created**:
- **Record**: SQS0001004 (sys_id: 9c62a3b5c3c97a50b71ef44c0501315d)
- **Created**: 2025-11-07 13:02:21
- **Scanner**: syft v1.37.0
- **Status**: ✅ Record exists and populated correctly

**Problem**:
```json
{
  "number": "SQS0001004",
  "short_description": "SBOM Scan - microservices-demo (syft v1.37.0)",
  "tool": "GithHubARC",
  "change_request": null,    // ❌ Not linked to CHG0030504
  "project": null,           // ❌ Empty
  "initiated_by": null       // ❌ Empty
}
```

**Root Cause**:
- Manual SBOM upload via REST API doesn't include linking fields
- Missing: `project`, `initiated_by`, and indirect link via `tool` + GitHub context
- ServiceNow DevOps actions use `context-github` parameter to auto-link records

**How ServiceNow Actions Link Records**:
```yaml
# Example from servicenow-devops-sonar action
- uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    tool-id: f62c4e49c3fcf614e1bbf0cb050131ef
    context-github: ${{ toJSON(github) }}  # ← This creates the link!
    job-name: 'SonarCloud Analysis'
```

The `context-github` parameter provides:
- Repository name
- Workflow run ID
- Commit SHA
- Branch name
- Actor/initiator

ServiceNow uses this context to:
1. Find or create a `sn_devops_project` record
2. Link records via `project` reference field
3. Associate with change requests via workflow run ID

---

### Issue #2: Test Summaries Not Linked

**Test Results Created By**:
- Unit tests run in `build-images.yaml` workflow
- Uses `ServiceNow/servicenow-devops-test-report@v6.0.0` action
- Should create records in `sn_devops_test_summary` table

**Current Implementation** (.github/workflows/build-images.yaml:353-365):
```yaml
- name: Upload Test Results to ServiceNow
  if: always()
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}  # ← Has context
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: 'src/${{ matrix.service }}/test-results.xml'
```

**Expected Behavior**: Should create test summary records linked to project

**Actual Behavior**: ❓ Need to verify if test results are being uploaded

**Possible Causes**:
1. Test report action might be failing silently (has `continue-on-error: true`)
2. XML test results might not be in correct format
3. Project linkage might be broken
4. Tool-id might not match change request's tool

---

### Issue #3: Performance Test Summaries Not Linked

**Smoke Test Results**:
- Smoke tests run in `servicenow-update-change.yaml` workflow
- Currently uploaded to `sn_devops_performance_test_summary` via REST API
- **Issue #72** implementation (completed)

**Current Implementation** (.github/workflows/servicenow-update-change.yaml):
```yaml
- name: Upload Smoke Test Performance Summary
  if: inputs.smoke_test_status != ''
  run: |
    curl -X POST -d '{
      "name": "Smoke Tests - Post-Deployment (${{ inputs.environment }})",
      "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
      "url": "${{ inputs.smoke_test_url }}",
      "duration": ${{ inputs.smoke_test_duration }},
      "total_tests": 1,
      "passed_tests": $PASSED,
      "failed_tests": $FAILED,
      ...
    }' .../sn_devops_performance_test_summary
```

**Problem**: Same as SBOM - manual REST API upload doesn't link to change request

**Missing**:
- No `project` field
- No `context-github` parameter (not using ServiceNow action)
- No automatic linkage to change request

---

## Comparison: ServiceNow Actions vs Manual REST API

### ServiceNow DevOps Actions (Auto-Linking) ✅

**Example**: `servicenow-devops-test-report@v6.0.0`

```yaml
- uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: f62c4e49c3fcf614e1bbf0cb050131ef
    context-github: ${{ toJSON(github) }}  # ← Magic happens here
    job-name: 'Unit Tests'
    xml-report-filename: 'test-results.xml'
```

**What it does**:
1. ✅ Creates/finds project based on repository name
2. ✅ Links test summary to project via `project` reference field
3. ✅ Associates with change request via workflow run ID correlation
4. ✅ Populates `initiated_by` from GitHub actor
5. ✅ Records all GitHub context (commit SHA, branch, etc.)

**Result**: Test summary appears in change request's "Test Summaries" tab

---

### Manual REST API Upload (No Linking) ❌

**Example**: Our SBOM and smoke test uploads

```yaml
- run: |
    curl -X POST -d '{
      "short_description": "SBOM Scan",
      "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
      "scan_url": "${{ github.server_url }}/...",
      ...
    }' .../sn_devops_software_quality_scan_summary
```

**What it does**:
1. ✅ Creates record successfully
2. ❌ No `project` field populated
3. ❌ No `initiated_by` field populated
4. ❌ No automatic link to change request
5. ❌ Record exists in isolation

**Result**: Record created but NOT visible in change request

---

## How ServiceNow Links Records to Change Requests

### Linkage Mechanism

**Step 1: Project Creation/Association**
```
GitHub Repository → sn_devops_project record
  - Uses context-github to match repository
  - Creates project if doesn't exist
  - Returns project sys_id
```

**Step 2: Record Linkage**
```
Test Summary/Quality Scan → Links to Project
  - project field = sn_devops_project.sys_id
  - tool field = sn_devops_tool.sys_id (GithHubARC)
  - initiated_by = GitHub actor
```

**Step 3: Change Request Association**
```
Project + Workflow Run ID → Change Request
  - Change request has correlation_id = workflow_run_id
  - Records with matching project show in change request
  - Visible in "Test Summaries", "Software Quality", etc. tabs
```

### Required Fields for Linkage

**For Test Summaries** (`sn_devops_test_summary`):
| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `project` | Reference | ✅ Yes | Links to sn_devops_project |
| `tool` | Reference | ✅ Yes | Links to sn_devops_tool (GithHubARC) |
| `name` | String | ✅ Yes | Test description |
| `test_result` | String | ✅ Yes | "passed" or "failed" |

**For Software Quality Summaries** (`sn_devops_software_quality_scan_summary`):
| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `project` | Reference | ⚠️  Optional | Links to sn_devops_project |
| `tool` | Reference | ✅ Yes | Links to sn_devops_tool (GithHubARC) |
| `short_description` | String | ✅ Yes | Scan description |
| `scanner_name` | String | ✅ Yes | Scanner name (e.g., "syft") |

**For Performance Test Summaries** (`sn_devops_performance_test_summary`):
| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `project` | Reference | ⚠️  Optional | Links to sn_devops_project |
| `tool` | Reference | ✅ Yes | Links to sn_devops_tool (GithHubARC) |
| `name` | String | ✅ Yes | Test description |
| `test_result` | String | ✅ Yes | "passed" or "failed" |

---

## Solution Options

### Option A: Use ServiceNow DevOps Actions (Recommended) ✅

**For Test Reports**:
- ✅ Already using `servicenow-devops-test-report@v6.0.0` in build-images.yaml
- ✅ Has `context-github` parameter
- ⚠️  Need to verify it's working correctly

**For Software Quality (SonarCloud)**:
- ✅ Already using `servicenow-devops-sonar@v3.1.0` in sonarcloud-scan.yaml
- ✅ Has `context-github` parameter
- ✅ Should auto-link to change request

**For SBOM and Smoke Tests**:
- ❌ No official ServiceNow action exists
- ⚠️  Need to use REST API with manual linkage (Option B)

---

### Option B: Manual REST API with Project Linkage

**Step 1**: Query for project sys_id
```bash
# Find project by repository name
PROJECT_ID=$(curl -s \
  .../sn_devops_project?sysparm_query=name=Freundcloud/microservices-demo \
  | jq -r '.result[0].sys_id')
```

**Step 2**: Include project in upload
```json
{
  "short_description": "SBOM Scan - microservices-demo",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "project": "$PROJECT_ID",  // ← Add this!
  "scan_url": "...",
  "scanner_name": "syft",
  ...
}
```

**Step 3**: Verify linkage
```bash
# Records should now appear in change request
curl .../sn_devops_software_quality_scan_summary?project=$PROJECT_ID
```

**Pros**:
- ✅ Works for custom uploads (SBOM, smoke tests)
- ✅ Records appear in change request
- ✅ Maintains GitHub context

**Cons**:
- ⚠️  Requires additional API call to get project sys_id
- ⚠️  Need to handle project creation if doesn't exist
- ⚠️  More complex workflow

---

### Option C: Create Custom Project and Link Manually

**Step 1**: Create dedicated project for microservices-demo
```bash
curl -X POST -d '{
  "name": "Freundcloud/microservices-demo",
  "description": "Online Boutique Microservices Demo",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"
}' .../sn_devops_project
```

**Step 2**: Store project sys_id as GitHub secret
```bash
gh secret set SN_PROJECT_ID --body "abc123..."
```

**Step 3**: Use in all uploads
```yaml
- run: |
    curl -X POST -d '{
      "project": "${{ secrets.SN_PROJECT_ID }}",
      ...
    }' .../sn_devops_software_quality_scan_summary
```

**Pros**:
- ✅ Simpler - no need to query for project every time
- ✅ Guaranteed consistency
- ✅ Works for all custom uploads

**Cons**:
- ⚠️  Requires manual project creation
- ⚠️  Need to manage secret
- ⚠️  Doesn't scale to multiple repositories

---

## Recommended Implementation

### Phase 1: Verify Existing ServiceNow Actions

**1. Check Test Report Upload**:
```bash
# Query for test summaries from workflow run 19169165717
curl .../sn_devops_test_summary?sysparm_query=tool=f62c4e49c3fcf614e1bbf0cb050131ef
```

**2. Check SonarCloud Upload**:
```bash
# Query for SonarCloud quality scans
curl .../sn_devops_software_quality_scan_summary?scanner_name=SonarQube
```

**3. Investigate Failures**:
- Review workflow logs for ServiceNow action errors
- Check if `continue-on-error: true` is hiding failures
- Verify credentials and permissions

---

### Phase 2: Add Project Linkage to Custom Uploads

**For SBOM Summary Upload** (.github/workflows/security-scan.yaml):

```yaml
- name: Upload SBOM Summary to ServiceNow
  run: |
    # Query for project sys_id
    PROJECT_ID=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project?sysparm_query=name=${{ github.repository }}&sysparm_fields=sys_id" \
      | jq -r '.result[0].sys_id // "null"')

    # Create project if doesn't exist
    if [ "$PROJECT_ID" = "null" ]; then
      PROJECT_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{
          "name": "${{ github.repository }}",
          "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"
        }' \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project")
      PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.result.sys_id')
    fi

    # Upload SBOM summary WITH project linkage
    curl -X POST -d '{
      "short_description": "SBOM Scan - microservices-demo (syft v1.37.0)",
      "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
      "project": "'"$PROJECT_ID"'",  // ← Add this!
      "scan_url": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}",
      ...
    }' .../sn_devops_software_quality_scan_summary
```

**For Smoke Test Performance Summary** (.github/workflows/servicenow-update-change.yaml):

Same approach - query for project, include in payload.

---

### Phase 3: Verify Change Request Linkage

**After implementing project linkage**:

```bash
# 1. Check if records now appear in project
curl .../sn_devops_software_quality_scan_summary?project=$PROJECT_ID

# 2. Check if change request shows linked records
curl .../change_request/b6d26379c3c97a50b71ef44c0501315d

# 3. View in ServiceNow UI
# Navigate to: Change Request → Software Quality Summaries tab
# Should now show SBOM scan, SonarCloud scan
```

---

## Testing Plan

### Test 1: Verify Test Report Upload Works

**Action**:
1. Trigger build-images workflow
2. Check for test summary records
3. Verify linkage to project

**Expected**:
```bash
# Test summaries exist
curl .../sn_devops_test_summary?tool=f62c4e49c3fcf614e1bbf0cb050131ef
→ Should return test results for each service

# Linked to project
curl .../sn_devops_test_summary?project=$PROJECT_ID
→ Should return same records
```

---

### Test 2: Verify SonarCloud Upload Works

**Action**:
1. Trigger sonarcloud-scan workflow
2. Check for software quality summary
3. Verify metrics in detail records

**Expected**:
```bash
# SonarCloud summary exists
curl .../sn_devops_software_quality_scan_summary?scanner_name=SonarQube
→ Should return SonarCloud scan record

# Detail records exist
curl .../sn_devops_software_quality_scan_detail?software_quality_summary=$SUMMARY_ID
→ Should return bugs, vulnerabilities, code_smells, etc.
```

---

### Test 3: Verify SBOM Upload with Project Linkage

**Action**:
1. Implement project linkage in security-scan.yaml
2. Trigger workflow
3. Check if SBOM summary appears in change request

**Expected**:
```bash
# SBOM summary exists with project
curl .../sn_devops_software_quality_scan_summary/9c62a3b5c3c97a50b71ef44c0501315d
→ Should show project field populated

# Visible in change request
# Navigate to: CHG0030504 → Software Quality Summaries tab
→ Should show SBOM scan record
```

---

## Impact Analysis

### Current Impact

**Change Approvers**:
- ❌ Cannot see SBOM scan results when reviewing change request
- ❌ Cannot see unit test results
- ❌ Cannot see smoke test results
- ⚠️  Missing critical evidence for approval decisions

**Compliance/Audit**:
- ❌ Incomplete audit trail (test results exist but not linked)
- ❌ Missing SBOM evidence in change records
- ⚠️  SOC 2 / ISO 27001 compliance gaps

**DevOps Insights Dashboard**:
- ⚠️  Data exists but not aggregated by project
- ⚠️  Cannot track quality trends per project
- ⚠️  Metrics visible individually but not in context

---

### Post-Fix Impact

**Change Approvers**:
- ✅ Complete visibility: SBOM, unit tests, smoke tests, SonarCloud
- ✅ Evidence-based approval decisions
- ✅ Risk assessment with complete data

**Compliance/Audit**:
- ✅ Complete audit trail with all test evidence
- ✅ SBOM tracking per change request
- ✅ SOC 2 / ISO 27001 compliance support

**DevOps Insights Dashboard**:
- ✅ Aggregated metrics by project
- ✅ Quality trends over time
- ✅ Complete DevOps visibility

---

## Files to Modify

### Priority 1: Add Project Linkage

1. **[.github/workflows/security-scan.yaml](../.github/workflows/security-scan.yaml)** (lines 134-228):
   - Add project query/creation before SBOM upload
   - Include `project` field in SBOM summary payload

2. **[.github/workflows/servicenow-update-change.yaml](../.github/workflows/servicenow-update-change.yaml)** (smoke tests):
   - Add project query/creation before smoke test upload
   - Include `project` field in performance test summary payload

### Priority 2: Verify Existing Actions

3. **[.github/workflows/build-images.yaml](../.github/workflows/build-images.yaml)** (lines 353-365):
   - Verify test report upload is working
   - Check logs for errors
   - Remove `continue-on-error: true` to surface failures

4. **[.github/workflows/sonarcloud-scan.yaml](../.github/workflows/sonarcloud-scan.yaml)** (lines 190-205):
   - Verify SonarCloud upload is working
   - Check if records are being created

---

## Next Steps

1. ✅ **Document the problem** (this document)
2. 🔲 **Create GitHub issue** to track implementation
3. 🔲 **Verify existing ServiceNow actions are working**
4. 🔲 **Implement project linkage for SBOM uploads**
5. 🔲 **Implement project linkage for smoke test uploads**
6. 🔲 **Test complete workflow end-to-end**
7. 🔲 **Verify all data appears in change request**

---

## References

- **ServiceNow DevOps Actions**: https://github.com/ServiceNow/servicenow-devops-actions
- **Test Report Action**: https://github.com/ServiceNow/servicenow-devops-test-report
- **SonarCloud Action**: https://github.com/ServiceNow/servicenow-devops-sonar
- **Change Request**: https://calitiiltddemo3.service-now.com/now/devops-change/record/change_request/b6d26379c3c97a50b71ef44c0501315d
- **SBOM Summary**: https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_software_quality_scan_summary/9c62a3b5c3c97a50b71ef44c0501315d

---

**Status**: 🔴 **AWAITING IMPLEMENTATION**
**Priority**: **HIGH** - Critical for change approval evidence and compliance
