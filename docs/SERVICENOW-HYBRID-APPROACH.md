# ServiceNow Hybrid Approach - Best of Both Worlds

> **Date**: 2025-11-04
> **Status**: Recommended Solution
> **Strategy**: Table API + DevOps Tables Integration

---

## Executive Summary

Instead of choosing between Table API and DevOps API, we can use **BOTH** by:

1. **Create change requests via Table API** (traditional CRs with custom fields)
2. **Populate DevOps tables via REST API** (DevOps workspace visibility)

This gives us:
- ✅ Traditional change requests (CHG0030XXX)
- ✅ All 40+ custom fields for compliance
- ✅ Visibility in DevOps workspace
- ✅ Test results, work items, and artifact tracking
- ✅ No ServiceNow plugin configuration required

---

## Available DevOps Tables

Based on your instance diagnostics, these DevOps tables are **available and working**:

| Table | Purpose | REST API Endpoint |
|-------|---------|------------------|
| `sn_devops_change_reference` | Link pipeline runs to change requests | `/api/now/table/sn_devops_change_reference` |
| `sn_devops_callback` | Deployment gate data (if needed) | `/api/now/table/sn_devops_callback` |
| `sn_devops_tool` | Tool registration (already done) | `/api/now/table/sn_devops_tool` |
| `sn_devops_test_result` | Individual test execution results | `/api/now/table/sn_devops_test_result` |
| `sn_devops_test_summary` | Aggregated test summaries | `/api/now/table/sn_devops_test_summary` |
| `sn_devops_work_item` | GitHub Issues tracking | `/api/now/table/sn_devops_work_item` |
| `sn_devops_artifact` | Deployment artifacts | `/api/now/table/sn_devops_artifact` |

**All accessible via standard REST API** - No DevOps Change Control API needed!

---

## Implementation Strategy

### Step 1: Create Change Request (Table API) - Keep Current Implementation

**What we already do**:
```bash
# Create traditional CR with custom fields
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "short_description": "Deploy to prod",
    "description": "...",
    "u_github_repo": "Freundcloud/microservices-demo",
    "u_github_commit": "abc123",
    "u_environment": "prod",
    "u_security_scan_status": "passed",
    ... (40+ custom fields)
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request"
```

**Returns**:
```json
{
  "result": {
    "number": "CHG0030123",
    "sys_id": "abc123def456..."
  }
}
```

### Step 2: Link to DevOps (sn_devops_change_reference) - NEW

**Create link between CR and pipeline run**:
```bash
# After CR created, link it to DevOps
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "change_request": "abc123def456...",  # sys_id from Step 1
    "pipeline_name": "Deploy to prod",
    "pipeline_id": "18728290166",  # GitHub run_id
    "pipeline_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/18728290166",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"  # Your GithHubARC tool sys_id
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference"
```

**Benefits**:
- ✅ CR now visible in ServiceNow DevOps workspace
- ✅ Linked to GitHub Actions pipeline run
- ✅ Complete traceability

### Step 3: Register Test Results (sn_devops_test_result) - NEW

**Upload individual test results**:
```bash
# For each test execution (unit tests, security scans, SonarCloud)
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "change_request": "abc123def456...",  # sys_id from Step 1
    "test_suite_name": "Unit Tests - Frontend",
    "test_result": "success",  # success/failure/skipped
    "test_start_time": "2025-11-04 10:00:00",
    "test_end_time": "2025-11-04 10:05:00",
    "total_tests": 150,
    "passed_tests": 148,
    "failed_tests": 2,
    "skipped_tests": 0,
    "pipeline_name": "Deploy to prod",
    "pipeline_id": "18728290166",
    "pipeline_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/18728290166"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result"
```

**Test Types to Upload**:
- Unit tests (per service: frontend, cartservice, etc.)
- Security scans (Trivy, CodeQL, Semgrep)
- SonarCloud quality gate results
- Integration tests
- End-to-end tests

### Step 4: Create Test Summary (sn_devops_test_summary) - NEW

**Aggregated summary for all tests**:
```bash
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "change_request": "abc123def456...",
    "total_test_suites": 10,
    "passed_test_suites": 9,
    "failed_test_suites": 1,
    "total_tests": 500,
    "passed_tests": 485,
    "failed_tests": 15,
    "test_execution_time": "300",  # seconds
    "overall_result": "passed_with_failures",
    "pipeline_id": "18728290166"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary"
```

### Step 5: Link Work Items (sn_devops_work_item) - NEW

**Link GitHub Issues to CR**:
```bash
# Already implemented in your workflows!
# Extract from commit messages: "Fixes #7"
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "change_request": "abc123def456...",
    "work_item_id": "7",
    "work_item_type": "GitHub Issue",
    "work_item_url": "https://github.com/Freundcloud/microservices-demo/issues/7",
    "work_item_title": "Add ServiceNow custom fields and work items integration",
    "work_item_state": "closed"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item"
```

**Note**: You already have this partially implemented in `.github/workflows/servicenow-integration.yaml`.

### Step 6: Register Artifacts (sn_devops_artifact) - NEW

**Track deployed container images**:
```bash
# For each service deployed (frontend, cartservice, etc.)
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "change_request": "abc123def456...",
    "artifact_name": "frontend",
    "artifact_version": "1.2.3",
    "artifact_type": "container_image",
    "artifact_url": "533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.2.3",
    "artifact_repository": "ECR",
    "deployment_environment": "prod",
    "deployment_time": "2025-11-04 10:30:00"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_artifact"
```

---

## Workflow Integration

### Enhanced servicenow-change-rest.yaml

Update `.github/workflows/servicenow-change-rest.yaml` to add DevOps table population:

**New Steps to Add**:

```yaml
- name: Link Change Request to DevOps Pipeline
  if: steps.create-change.outputs.change_sys_id != ''
  env:
    CHANGE_SYSID: ${{ steps.create-change.outputs.change_sys_id }}
  run: |
    echo "Linking CR to DevOps workspace..."

    curl -s -X POST \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -d '{
        "change_request": "'"$CHANGE_SYSID"'",
        "pipeline_name": "Deploy to ${{ inputs.environment }}",
        "pipeline_id": "${{ github.run_id }}",
        "pipeline_url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}",
        "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
      }' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_change_reference"

- name: Register Test Results Summary
  if: steps.create-change.outputs.change_sys_id != ''
  env:
    CHANGE_SYSID: ${{ steps.create-change.outputs.change_sys_id }}
    UNIT_TEST_TOTAL: ${{ inputs.unit_test_total }}
    UNIT_TEST_PASSED: ${{ inputs.unit_test_passed }}
    UNIT_TEST_FAILED: ${{ inputs.unit_test_failed }}
  run: |
    echo "Registering test results in DevOps workspace..."

    curl -s -X POST \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -d '{
        "change_request": "'"$CHANGE_SYSID"'",
        "test_suite_name": "CI/CD Pipeline Tests",
        "total_tests": '"${UNIT_TEST_TOTAL:-0}"',
        "passed_tests": '"${UNIT_TEST_PASSED:-0}"',
        "failed_tests": '"${UNIT_TEST_FAILED:-0}"',
        "test_result": "'"$([ "${UNIT_TEST_FAILED:-0}" -eq 0 ] && echo "success" || echo "failure")"'",
        "pipeline_id": "${{ github.run_id }}",
        "pipeline_url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
      }' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_test_result"

- name: Register Deployed Artifacts
  if: steps.create-change.outputs.change_sys_id != '' && inputs.services_deployed != ''
  env:
    CHANGE_SYSID: ${{ steps.create-change.outputs.change_sys_id }}
    SERVICES: ${{ inputs.services_deployed }}
    VERSION: ${{ inputs.deployed_version }}
  run: |
    echo "Registering deployed artifacts..."

    # Parse services JSON array and register each artifact
    echo "$SERVICES" | jq -r '.[]' | while read -r service; do
      curl -s -X POST \
        -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
        -H "Content-Type: application/json" \
        -d '{
          "change_request": "'"$CHANGE_SYSID"'",
          "artifact_name": "'"$service"'",
          "artifact_version": "'"$VERSION"'",
          "artifact_type": "container_image",
          "deployment_environment": "${{ inputs.environment }}",
          "pipeline_id": "${{ github.run_id }}"
        }' \
        "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_artifact"
    done
```

---

## Benefits of Hybrid Approach

### ✅ Compliance (Table API)
- Traditional change requests with CR numbers
- 40+ custom fields for audit trail
- Complete GitHub context (repo, commit, branch, actor)
- Security scan status and vulnerability counts
- Unit test results and SonarCloud metrics
- Correlation IDs for traceability

### ✅ DevOps Visibility (DevOps Tables)
- Changes visible in ServiceNow DevOps workspace
- Test results tracked and displayed
- Work items (GitHub Issues) linked to CRs
- Deployment artifacts registered
- Pipeline runs linked to changes
- Complete DevOps workflow traceability

### ✅ No Configuration Required
- Uses REST API for all tables (no DevOps API needed)
- No ServiceNow plugin configuration
- No missing `sn_devops_change_control_config` table required
- Works on all ServiceNow instances (including PDIs)

### ✅ Best Practices
- Single source of truth (change_request table)
- Additional DevOps metadata in specialized tables
- Bi-directional traceability (GitHub ↔ ServiceNow)
- Complete audit trail for compliance

---

## Comparison: Pure Table API vs Hybrid Approach

| Feature | Pure Table API (Current) | Hybrid Approach (Recommended) |
|---------|-------------------------|------------------------------|
| **Traditional CRs** | ✅ Yes | ✅ Yes |
| **Custom Fields** | ✅ 40+ fields | ✅ 40+ fields |
| **DevOps Workspace** | ❌ Not visible | ✅ Visible |
| **Test Results Tracking** | ⚠️ In custom fields only | ✅ Custom fields + dedicated table |
| **Work Items** | ⚠️ Separate workflow | ✅ Integrated |
| **Artifacts** | ❌ Not tracked | ✅ Tracked per service |
| **Pipeline Linking** | ⚠️ URL in custom field | ✅ Proper reference table |
| **Compliance Data** | ✅ Complete | ✅ Complete |
| **Configuration Needed** | ✅ None | ✅ None |
| **API Calls** | 1 (CR creation) | 4-6 (CR + DevOps tables) |

---

## Implementation Plan

### Phase 1: Add Change Reference Link (Immediate)
- Add `sn_devops_change_reference` creation after CR
- Link pipeline run to change request
- Verify visibility in DevOps workspace

### Phase 2: Add Test Results (High Value)
- Create `sn_devops_test_result` entries for each test suite
- Create `sn_devops_test_summary` for overall results
- Populate with data from existing custom fields

### Phase 3: Enhance Work Items (Already Partially Done)
- Ensure `sn_devops_work_item` entries created for GitHub Issues
- Link to change requests properly

### Phase 4: Add Artifact Tracking (Nice to Have)
- Register deployed container images in `sn_devops_artifact`
- Track versions and deployment environments

---

## Sample Enhanced Workflow

```yaml
jobs:
  servicenow-change:
    name: "📝 ServiceNow Change Request + DevOps Integration"
    runs-on: ubuntu-latest
    outputs:
      change_number: ${{ steps.create-cr.outputs.change_number }}
      change_sys_id: ${{ steps.create-cr.outputs.change_sys_id }}

    steps:
      - name: Create Change Request (Table API)
        id: create-cr
        run: |
          # Create CR with 40+ custom fields (existing implementation)
          # Returns: change_number, change_sys_id

      - name: Link to DevOps Pipeline
        if: steps.create-cr.outputs.change_sys_id != ''
        run: |
          # Create sn_devops_change_reference entry

      - name: Register Test Results
        if: steps.create-cr.outputs.change_sys_id != ''
        run: |
          # Create sn_devops_test_result entries
          # Create sn_devops_test_summary entry

      - name: Register Work Items
        if: steps.create-cr.outputs.change_sys_id != ''
        run: |
          # Create sn_devops_work_item entries for GitHub Issues

      - name: Register Artifacts
        if: steps.create-cr.outputs.change_sys_id != ''
        run: |
          # Create sn_devops_artifact entries for deployed services
```

---

## Field Mapping

### sn_devops_change_reference Fields

| Field | Source | Example |
|-------|--------|---------|
| `change_request` | CR sys_id from Step 1 | abc123def456... |
| `pipeline_name` | Workflow name | Deploy to prod |
| `pipeline_id` | github.run_id | 18728290166 |
| `pipeline_url` | GitHub Actions URL | https://github.com/.../runs/... |
| `tool` | SN_ORCHESTRATION_TOOL_ID | f62c4e49... |

### sn_devops_test_result Fields

| Field | Source | Example |
|-------|--------|---------|
| `change_request` | CR sys_id | abc123def456... |
| `test_suite_name` | Service + test type | Frontend Unit Tests |
| `test_result` | Pass/Fail/Skip | success |
| `total_tests` | Test count | 150 |
| `passed_tests` | Passed count | 148 |
| `failed_tests` | Failed count | 2 |
| `pipeline_id` | github.run_id | 18728290166 |

### sn_devops_artifact Fields

| Field | Source | Example |
|-------|--------|---------|
| `change_request` | CR sys_id | abc123def456... |
| `artifact_name` | Service name | frontend |
| `artifact_version` | Image tag | 1.2.3 |
| `artifact_type` | Type | container_image |
| `artifact_url` | ECR URL | 533267307120.dkr.ecr...amazonaws.com/frontend:1.2.3 |
| `deployment_environment` | Environment | prod |

---

## Testing the Hybrid Approach

### Step 1: Test Change Reference Link

```bash
# After CR created, test DevOps link
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=change_request=<CR_SYS_ID>" \
  | jq '.result'
```

**Expected**: Record linking CR to GitHub Actions run

### Step 2: Verify DevOps Workspace Visibility

1. Log into ServiceNow
2. Navigate to: **DevOps → Change Velocity** (or search "DevOps" in All menu)
3. Look for your change request
4. Verify pipeline link, test results, artifacts visible

### Step 3: Test Test Results Query

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result?sysparm_query=change_request=<CR_SYS_ID>" \
  | jq '.result'
```

**Expected**: Test execution records for the change

---

## Recommendation

**✅ IMPLEMENT HYBRID APPROACH**

This gives you the best of both worlds:
- Keep Table API for compliance (traditional CRs + custom fields)
- Add DevOps table population for visibility and workflow integration
- No ServiceNow configuration required
- Works on your current instance

**Next Steps**:
1. Implement Phase 1 (change reference link)
2. Test DevOps workspace visibility
3. Add test results (Phase 2)
4. Enhance work items (Phase 3)
5. Add artifact tracking (Phase 4)

---

## References

- **Current Table API Workflow**: `.github/workflows/servicenow-change-rest.yaml`
- **Work Items Implementation**: `.github/workflows/servicenow-integration.yaml`
- **ServiceNow REST API Documentation**: https://developer.servicenow.com/dev.do#!/reference/api/vancouver/rest/
- **Diagnostic Results**: `scripts/discover-servicenow-devops-tables.sh` output

---

**Document Version**: 1.0
**Status**: Recommended Approach
**Implementation**: Phased (4 phases)
**Configuration Required**: None
