# ServiceNow Smoke Test Integration Analysis

**Date**: 2025-11-06
**Status**: 📋 **ANALYSIS COMPLETE** - Awaiting Implementation
**Component**: ServiceNow DevOps Integration
**Table**: `sn_devops_performance_test_summary`

---

## Executive Summary

**Problem**: Smoke test results from the MASTER-PIPELINE are not being registered in ServiceNow's `sn_devops_performance_test_summary` table, despite smoke tests running successfully after every deployment.

**Impact**:
- ❌ Missing smoke test visibility in ServiceNow DevOps Insights
- ❌ Incomplete deployment validation data for change approvals
- ❌ No post-deployment health check evidence in ServiceNow
- ❌ Gaps in compliance audit trail

**Root Cause**: The smoke tests job (`smoke-tests`) in MASTER-PIPELINE.yaml outputs test data (status, duration, URL), but this data is **not passed** to the ServiceNow integration workflows.

**Recommended Solution**: Pass smoke test data from MASTER-PIPELINE → `servicenow-change-rest.yaml` → upload to `sn_devops_performance_test_summary` table (infrastructure already exists, just needs data flow).

---

## Problem Statement

### Current State

**What Works**:
✅ Smoke tests run successfully after deployment (lines 706-830 in MASTER-PIPELINE.yaml)
✅ Smoke test outputs captured: `status`, `url`, `duration`
✅ ServiceNow workflow (`servicenow-change-rest.yaml`) already has infrastructure to upload performance test data (lines 914-978)
✅ Smoke test input parameters already defined in `servicenow-change-rest.yaml` (lines 178-192)

**What's Missing**:
❌ Smoke test data is NOT passed from MASTER-PIPELINE to `servicenow-change-rest.yaml`
❌ Performance test summary is only uploaded if `inputs.smoke_test_duration != ''` (line 916)
❌ Since no smoke test data is passed, this condition is always false
❌ Result: `sn_devops_performance_test_summary` table never gets populated

### Evidence

#### 1. Smoke Tests Job (MASTER-PIPELINE.yaml, lines 706-830)

**Outputs defined**:
```yaml
smoke-tests:
  name: "✅ Smoke Tests"
  outputs:
    status: ${{ steps.test-frontend.outputs.status }}   # "success" or "failure"
    url: ${{ steps.test-frontend.outputs.url }}          # ALB URL
    duration: ${{ steps.calculate-duration.outputs.duration }}  # Seconds
```

**Test execution**:
- Verifies all pods are ready (10/10 pods in dev, 30/30 in prod)
- Tests frontend endpoint accessibility via ALB
- Calculates duration of smoke tests
- Creates GitHub step summary with results

#### 2. ServiceNow Change Workflow Input (servicenow-change-rest.yaml, lines 178-192)

**Input parameters already defined**:
```yaml
inputs:
  smoke_test_status:
    description: "Smoke test status (passed/failed)"
    required: false
    type: string
    default: ""
  smoke_test_duration:
    description: "Smoke test duration in seconds"
    required: false
    type: string
    default: ""
  smoke_test_url:
    description: "URL to view smoke test results"
    required: false
    type: string
    default: ""
```

#### 3. Performance Test Upload Logic (servicenow-change-rest.yaml, lines 914-978)

**Upload conditional** (line 916):
```yaml
if: |
  steps.create-cr.outputs.change_sys_id != '' &&
  inputs.smoke_test_duration != ''  # ← This is NEVER true!
```

**Upload implementation**:
```bash
curl -X POST \
  -d '{
    "name": "Smoke Tests - Post-Deployment (${{ inputs.environment }})",
    "tool": "'$SN_ORCHESTRATION_TOOL_ID'",  # f62c4e49c3fcf614e1bbf0cb050131ef
    "url": "${{ inputs.smoke_test_url }}",
    "test_type": "functional",
    "start_time": "...",
    "finish_time": "...",
    "duration": ${{ inputs.smoke_test_duration }},
    "total_tests": 1,
    "passed_tests": ...,
    "failed_tests": ...,
    ...
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary"
```

#### 4. MASTER-PIPELINE ServiceNow Call (lines 580-598)

**Current call to `servicenow-change-rest.yaml`**:
```yaml
uses: ./.github/workflows/servicenow-change-rest.yaml
with:
  environment: ${{ needs.pipeline-init.outputs.environment }}
  short_description: 'Deploy microservices to ...'
  services_deployed: ${{ needs.detect-service-changes.outputs.changed_services_json }}
  security_scan_status: ${{ needs.security-scans.outputs.overall_status }}
  unit_test_status: ${{ needs.unit-test-summary.outputs.status }}
  # ❌ NO smoke_test_status, smoke_test_duration, smoke_test_url!
```

**Problem**: None of the smoke test outputs are being passed!

---

## Root Cause Analysis

### Why Smoke Tests Aren't Registered

1. **MASTER-PIPELINE creates change request BEFORE smoke tests run**:
   ```
   Timeline:
   1. servicenow-change (needs: security-scans, unit-test-summary)
   2. deploy-to-environment (needs: servicenow-change)
   3. smoke-tests (needs: deploy-to-environment)  ← Runs AFTER CR creation
   ```

2. **No mechanism to update CR with smoke test data**:
   - `servicenow-update-change.yaml` exists but only updates deployment status (lines 958-966)
   - It does NOT include smoke test parameters
   - It does NOT upload performance test data

3. **Performance test upload conditional is never satisfied**:
   ```yaml
   if: inputs.smoke_test_duration != ''  # Always false because no data passed
   ```

### Architecture Issue

**Current flow**:
```
┌─────────────────┐
│ MASTER-PIPELINE │
└────────┬────────┘
         │
         ├─ servicenow-change (Create CR) ──► No smoke test data available yet
         │
         ├─ deploy-to-environment
         │
         ├─ smoke-tests (outputs: status, duration, url) ──► Data not sent anywhere!
         │
         └─ update-servicenow-change (Update CR) ──► Only deployment status, no smoke tests
```

**What's needed**:
```
┌─────────────────┐
│ MASTER-PIPELINE │
└────────┬────────┘
         │
         ├─ servicenow-change (Create CR)
         │
         ├─ deploy-to-environment
         │
         ├─ smoke-tests (outputs: status, duration, url)
         │              │
         │              ▼
         └─ update-servicenow-change (Update CR + Upload Performance Test)
                         │
                         ▼
                sn_devops_performance_test_summary ✅
```

---

## Proposed Solutions

### Option A: Add Smoke Test Upload to `update-servicenow-change.yaml` (RECOMMENDED)

**Approach**: Extend the existing update workflow to accept smoke test parameters and upload to performance test summary table.

**Implementation**:

1. **Update `servicenow-update-change.yaml` inputs** (add lines after line 38):
   ```yaml
   inputs:
     # ... existing inputs ...
     smoke_test_status:
       description: "Smoke test result (success/failure)"
       required: false
       type: string
       default: ""
     smoke_test_duration:
       description: "Smoke test duration in seconds"
       required: false
       type: string
       default: ""
     smoke_test_url:
       description: "URL to smoke test run"
       required: false
       type: string
       default: ""
   ```

2. **Add performance test upload step** to `servicenow-update-change.yaml`:
   ```yaml
   - name: Upload Smoke Test Performance Summary
     if: inputs.smoke_test_duration != ''
     env:
       SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
       SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
       SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
     run: |
       # Use same logic as servicenow-change-rest.yaml lines 914-978
       # Upload to sn_devops_performance_test_summary
   ```

3. **Update MASTER-PIPELINE call** to `update-servicenow-change.yaml` (add after line 966):
   ```yaml
   uses: ./.github/workflows/servicenow-update-change.yaml
   with:
     # ... existing parameters ...
     smoke_test_status: ${{ needs.smoke-tests.outputs.status }}
     smoke_test_duration: ${{ needs.smoke-tests.outputs.duration }}
     smoke_test_url: ${{ needs.smoke-tests.outputs.url }}
   ```

**Pros**:
- ✅ Minimal changes (3 files)
- ✅ Reuses existing upload logic
- ✅ Smoke tests run after deployment (correct sequence)
- ✅ Change request already exists when updating
- ✅ Uses hardcoded tool-id (f62c4e49c3fcf614e1bbf0cb050131ef)

**Cons**:
- ⚠️ Performance test data separated from initial CR creation
- ⚠️ Requires smoke-tests to succeed for data to be uploaded

**Effort**: 1-2 hours

---

### Option B: Create Dedicated Smoke Test Upload Workflow

**Approach**: Create a new reusable workflow specifically for uploading smoke test data.

**Implementation**:

1. **Create `.github/workflows/upload-smoke-tests-servicenow.yaml`**
2. **Call from MASTER-PIPELINE** after smoke-tests job
3. **Upload directly** to `sn_devops_performance_test_summary`

**Pros**:
- ✅ Single responsibility (one workflow = one purpose)
- ✅ Easier to test in isolation
- ✅ Can be reused by other workflows

**Cons**:
- ⚠️ More files to maintain
- ⚠️ Duplicates upload logic from servicenow-change-rest.yaml
- ⚠️ Additional workflow job (more execution time)

**Effort**: 2-3 hours

---

### Option C: Pass Smoke Test Data via Outputs and Update CR Creation

**Approach**: Modify workflow order so smoke tests run before CR creation.

**Implementation**:

1. **Move `smoke-tests` job earlier** in pipeline
2. **Pass outputs** to `servicenow-change` creation
3. **Upload performance test** during CR creation

**Pros**:
- ✅ All test data available at CR creation time
- ✅ Single upload operation

**Cons**:
- ❌ Smoke tests run BEFORE deployment (incorrect sequence!)
- ❌ Cannot test deployment if deployment hasn't happened yet
- ❌ Breaks logical flow of pipeline
- ❌ Major refactoring required

**Effort**: 4-6 hours

**Verdict**: ❌ **NOT RECOMMENDED** - Breaks deployment validation logic

---

## Recommended Implementation: Option A

### Why Option A is Best

1. **Correct sequence**: Smoke tests run AFTER deployment (validates deployment)
2. **Minimal changes**: Extends existing `update-servicenow-change.yaml`
3. **Reuses infrastructure**: Upload logic already exists in `servicenow-change-rest.yaml`
4. **Uses correct tool-id**: Already updated to use f62c4e49c3fcf614e1bbf0cb050131ef
5. **Complete audit trail**: Performance test data linked to change request

### Implementation Checklist

- [ ] **File 1**: Update `.github/workflows/servicenow-update-change.yaml`
  - [ ] Add `smoke_test_status` input parameter
  - [ ] Add `smoke_test_duration` input parameter
  - [ ] Add `smoke_test_url` input parameter
  - [ ] Add step to upload performance test summary (copy from servicenow-change-rest.yaml lines 914-978)
  - [ ] Update tool-id to use hardcoded `f62c4e49c3fcf614e1bbf0cb050131ef`

- [ ] **File 2**: Update `.github/workflows/MASTER-PIPELINE.yaml`
  - [ ] Update `update-servicenow-change` job call (line 958)
  - [ ] Add `smoke_test_status: ${{ needs.smoke-tests.outputs.status }}`
  - [ ] Add `smoke_test_duration: ${{ needs.smoke-tests.outputs.duration }}`
  - [ ] Add `smoke_test_url: ${{ needs.smoke-tests.outputs.url }}`

- [ ] **Testing**:
  - [ ] Trigger MASTER-PIPELINE workflow
  - [ ] Verify smoke tests run successfully
  - [ ] Verify performance test summary created in ServiceNow
  - [ ] Verify tool-id is f62c4e49c3fcf614e1bbf0cb050131ef
  - [ ] Verify data appears in DevOps Insights

### Expected Payload

```json
{
  "name": "Smoke Tests - Post-Deployment (dev)",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "url": "https://github.com/Freundcloud/microservices-demo/actions/runs/19146477980",
  "test_type": "functional",
  "start_time": "2025-11-06 18:52:00",
  "finish_time": "2025-11-06 18:52:15",
  "duration": 15,
  "total_tests": 1,
  "passed_tests": 1,
  "failed_tests": 0,
  "skipped_tests": 0,
  "blocked_tests": 0,
  "passing_percent": 100,
  "status": "passed",
  "minimum": 15000,
  "average": 15000,
  "maximum": 15000,
  "ninety_percent": 15000,
  "standard_deviation": 0.0,
  "throughput": "1",
  "maximum_virtual_users": 1
}
```

---

## Testing Strategy

### Unit Testing (Local Validation)

1. **Validate YAML syntax**:
   ```bash
   yamllint .github/workflows/servicenow-update-change.yaml
   yamllint .github/workflows/MASTER-PIPELINE.yaml
   ```

2. **Validate input/output mapping**:
   ```bash
   # Ensure smoke-tests job outputs match update-servicenow-change inputs
   grep -A5 "smoke-tests:" .github/workflows/MASTER-PIPELINE.yaml
   grep -A10 "inputs:" .github/workflows/servicenow-update-change.yaml
   ```

### Integration Testing (Workflow Run)

1. **Trigger workflow**:
   ```bash
   git commit --allow-empty -m "test: Verify smoke test ServiceNow integration"
   git push origin main
   ```

2. **Monitor execution**:
   ```bash
   gh run watch --repo Freundcloud/microservices-demo
   ```

3. **Verify ServiceNow upload**:
   ```bash
   # Query performance test summary table
   curl -s \
     "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_performance_test_summary?sysparm_query=nameLIKESmoke Tests^ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_display_value=all" \
     -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     | jq '.result[0] | {name, tool, duration, status, total_tests}'
   ```

   **Expected output**:
   ```json
   {
     "name": "Smoke Tests - Post-Deployment (dev)",
     "tool": {
       "display_value": "GithHubARC",
       "value": "f62c4e49c3fcf614e1bbf0cb050131ef"
     },
     "duration": 15,
     "status": "passed",
     "total_tests": 1
   }
   ```

### Acceptance Criteria

- [x] Smoke tests run successfully after deployment
- [ ] Smoke test data (status, duration, URL) passed to ServiceNow update workflow
- [ ] Performance test summary uploaded to `sn_devops_performance_test_summary` table
- [ ] Tool field correctly set to f62c4e49c3fcf614e1bbf0cb050131ef (GithHubARC)
- [ ] Data visible in ServiceNow DevOps Insights dashboard
- [ ] No workflow failures or errors
- [ ] Complete audit trail from deployment → smoke tests → ServiceNow

---

## Benefits

### For DevOps Teams
- ✅ Complete deployment validation evidence
- ✅ Post-deployment health checks tracked
- ✅ Single source of truth for deployment success

### For Approvers
- ✅ Smoke test results available for risk assessment
- ✅ Deployment validation before production promotion
- ✅ Evidence of successful deployment

### For Compliance/Audit
- ✅ Complete test coverage (unit, security, smoke)
- ✅ Deployment validation documented
- ✅ Traceable evidence chain

### For Monitoring
- ✅ Performance test trends over time
- ✅ Deployment duration tracking
- ✅ Success rate metrics

---

## Related Documentation

- [SERVICENOW-TOOL-ID-FIX.md](SERVICENOW-TOOL-ID-FIX.md) - Tool-id consolidation fix
- [SERVICENOW-PERFORMANCE-TEST-IMPLEMENTATION.md](SERVICENOW-PERFORMANCE-TEST-IMPLEMENTATION.md) - Existing performance test upload implementation
- [SERVICENOW-IMPLEMENTATION-COMPLETE.md](SERVICENOW-IMPLEMENTATION-COMPLETE.md) - Complete ServiceNow integration overview

---

## Related Files

- `.github/workflows/MASTER-PIPELINE.yaml` (lines 706-830: smoke-tests job)
- `.github/workflows/servicenow-change-rest.yaml` (lines 178-192: smoke test inputs, lines 914-978: performance test upload)
- `.github/workflows/servicenow-update-change.yaml` (needs: smoke test parameters)

---

**Status**: 📋 **ANALYSIS COMPLETE** - Ready for implementation
**Recommended Solution**: Option A (Extend update-servicenow-change.yaml)
**Estimated Effort**: 1-2 hours
**Risk**: Low (extends existing infrastructure)
