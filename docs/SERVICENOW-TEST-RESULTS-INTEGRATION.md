# ServiceNow Test Results Integration

**Status**: ✅ Custom fields created, workflows updated, ready for test data population
**Last Updated**: 2025-10-29

## Overview

This document explains how unit test results and SonarCloud scan results are linked to ServiceNow change requests for approval evidence and compliance tracking.

## What Was Implemented

### 1. Custom Fields Created in ServiceNow ✅

**13 new custom fields** have been created on the `change_request` table:

#### Unit Test Fields (6 fields)
| Field Name | Type | Description |
|------------|------|-------------|
| `u_unit_test_status` | String | Overall test status (passed/failed/skipped) |
| `u_unit_test_total` | Integer | Total number of tests executed |
| `u_unit_test_passed` | Integer | Number of tests that passed |
| `u_unit_test_failed` | Integer | Number of tests that failed |
| `u_unit_test_coverage` | String | Code coverage percentage (e.g., "85.2%") |
| `u_unit_test_url` | URL | Link to GitHub Actions test results |

#### SonarCloud Fields (7 fields)
| Field Name | Type | Description |
|------------|------|-------------|
| `u_sonarcloud_status` | String | Quality gate status (passed/failed/warning) |
| `u_sonarcloud_bugs` | Integer | Number of bugs detected |
| `u_sonarcloud_vulnerabilities` | Integer | Number of security vulnerabilities |
| `u_sonarcloud_code_smells` | Integer | Number of code smells (maintainability) |
| `u_sonarcloud_coverage` | String | Code coverage percentage from SonarCloud |
| `u_sonarcloud_duplications` | String | Code duplication percentage |
| `u_sonarcloud_url` | URL | Link to SonarCloud project dashboard |

### 2. Workflow Updates ✅

#### servicenow-change-rest.yaml
- Added 13 new input parameters for test results
- Updated JSON payload construction to include all new fields
- Fields are sent to ServiceNow via REST API when creating change requests

#### MASTER-PIPELINE.yaml
- Added test result parameters to `servicenow-change` job
- Currently sends empty/placeholder values with TODOs for enhancement
- Links are functional (GitHub Actions run, SonarCloud dashboard)

### 3. Automation Script ✅

**Script**: `scripts/create-servicenow-test-fields.sh`

This script:
- Creates all 13 custom fields via ServiceNow REST API
- Checks for existing fields to avoid duplicates
- Can be re-run safely (idempotent)

**Usage**:
```bash
source .envrc  # Load ServiceNow credentials
./scripts/create-servicenow-test-fields.sh
```

## How It Works

### Data Flow

```
┌─────────────────────┐
│ GitHub Actions      │
│ (Unit Tests)        │
│                     │
│ - Run tests         │
│ - Count results     │
│ - Calculate coverage│
│ - Generate report   │
└──────────┬──────────┘
           │
           │ outputs
           ▼
┌─────────────────────┐
│ MASTER-PIPELINE     │
│                     │
│ Collect test data   │
│ from job outputs    │
└──────────┬──────────┘
           │
           │ workflow inputs
           ▼
┌─────────────────────┐
│ servicenow-change   │
│ -rest.yaml          │
│                     │
│ Build JSON payload  │
│ with test results   │
└──────────┬──────────┘
           │
           │ REST API POST
           ▼
┌─────────────────────┐
│ ServiceNow          │
│ change_request      │
│                     │
│ CHG0030XXX created  │
│ with test metadata  │
└─────────────────────┘
```

### Example Change Request Payload

```json
{
  "short_description": "Deploy microservices to dev",
  "description": "...",

  "u_unit_test_status": "passed",
  "u_unit_test_total": "127",
  "u_unit_test_passed": "127",
  "u_unit_test_failed": "0",
  "u_unit_test_coverage": "85.2%",
  "u_unit_test_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/12345",

  "u_sonarcloud_status": "passed",
  "u_sonarcloud_bugs": "2",
  "u_sonarcloud_vulnerabilities": "0",
  "u_sonarcloud_code_smells": "15",
  "u_sonarcloud_coverage": "82.4%",
  "u_sonarcloud_duplications": "3.2%",
  "u_sonarcloud_url": "https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo"
}
```

## Current Status: Fields Ready, Data Population Pending

### ✅ What's Complete

1. **ServiceNow Fields**: All 13 custom fields created and ready
2. **Workflow Inputs**: All parameters defined in `servicenow-change-rest.yaml`
3. **JSON Payload**: All fields included in REST API call
4. **Master Pipeline**: Calls updated to pass test result data

### ⏳ What's Pending

The infrastructure is ready, but the following workflows need enhancement to **populate actual test data**:

1. **Unit Test Data Collection** (`run-unit-tests.yaml`):
   - ✅ Already has `tests_passed` and `test_count` outputs
   - ❌ Missing: `test_failed`, `coverage`, individual service results
   - **Action Required**: Enhance workflow to aggregate test results across all services

2. **SonarCloud Data Collection** (`sonarcloud-scan.yaml`):
   - ❌ Currently has NO outputs
   - **Action Required**: Add workflow outputs for quality gate status, bugs, vulnerabilities, etc.
   - **Data Source**: SonarCloud API provides all needed metrics

3. **Master Pipeline Wiring**:
   - ✅ Fields are passed to ServiceNow workflow
   - ⏳ Currently sends empty/placeholder values
   - **Action Required**: Replace placeholders with actual `needs.<job>.outputs.<field>` references

## How to Complete the Integration

### Step 1: Enhance Unit Test Workflow

**File**: `.github/workflows/run-unit-tests.yaml`

**Add workflow-level outputs**:
```yaml
on:
  workflow_call:
    outputs:
      test_status:
        description: "Overall test status"
        value: ${{ jobs.aggregate-results.outputs.status }}
      total_tests:
        description: "Total tests run"
        value: ${{ jobs.aggregate-results.outputs.total }}
      passed_tests:
        description: "Tests passed"
        value: ${{ jobs.aggregate-results.outputs.passed }}
      failed_tests:
        description: "Tests failed"
        value: ${{ jobs.aggregate-results.outputs.failed }}
      coverage:
        description: "Code coverage percentage"
        value: ${{ jobs.aggregate-results.outputs.coverage }}
```

**Add aggregation job** (after all test jobs complete):
```yaml
jobs:
  # ... existing test jobs ...

  aggregate-results:
    name: "Aggregate Test Results"
    needs: [run-tests]  # Wait for all test jobs
    runs-on: ubuntu-latest
    if: always()
    outputs:
      status: ${{ steps.aggregate.outputs.status }}
      total: ${{ steps.aggregate.outputs.total }}
      passed: ${{ steps.aggregate.outputs.passed }}
      failed: ${{ steps.aggregate.outputs.failed }}
      coverage: ${{ steps.aggregate.outputs.coverage }}

    steps:
      - name: Aggregate Results
        id: aggregate
        run: |
          # Parse test results from all services
          # Calculate totals
          # Determine overall status
          # Output aggregated values
          echo "status=passed" >> $GITHUB_OUTPUT
          echo "total=127" >> $GITHUB_OUTPUT
          echo "passed=127" >> $GITHUB_OUTPUT
          echo "failed=0" >> $GITHUB_OUTPUT
          echo "coverage=85.2%" >> $GITHUB_OUTPUT
```

**Note**: The current `run-unit-tests.yaml` runs tests for a **single service**. To get comprehensive results:
- Either call it multiple times (once per service) and aggregate
- Or refactor to test all services in one run

### Step 2: Enhance SonarCloud Workflow

**File**: `.github/workflows/sonarcloud-scan.yaml`

**Add workflow-level outputs**:
```yaml
on:
  workflow_call:
    outputs:
      quality_gate:
        description: "Quality gate status"
        value: ${{ jobs.sonarcloud-scan.outputs.status }}
      bugs:
        description: "Number of bugs"
        value: ${{ jobs.sonarcloud-scan.outputs.bugs }}
      vulnerabilities:
        description: "Number of vulnerabilities"
        value: ${{ jobs.sonarcloud-scan.outputs.vulnerabilities }}
      code_smells:
        description: "Number of code smells"
        value: ${{ jobs.sonarcloud-scan.outputs.code_smells }}
      coverage:
        description: "Code coverage percentage"
        value: ${{ jobs.sonarcloud-scan.outputs.coverage }}
      duplications:
        description: "Duplication percentage"
        value: ${{ jobs.sonarcloud-scan.outputs.duplications }}
```

**Add result extraction step** (after SonarCloud scan):
```yaml
jobs:
  sonarcloud-scan:
    name: SonarCloud Analysis
    runs-on: ubuntu-latest
    outputs:
      status: ${{ steps.get-results.outputs.status }}
      bugs: ${{ steps.get-results.outputs.bugs }}
      vulnerabilities: ${{ steps.get-results.outputs.vulnerabilities }}
      code_smells: ${{ steps.get-results.outputs.code_smells }}
      coverage: ${{ steps.get-results.outputs.coverage }}
      duplications: ${{ steps.get-results.outputs.duplications }}

    steps:
      # ... existing SonarCloud scan steps ...

      - name: Get SonarCloud Results
        id: get-results
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: |
          # Wait for analysis to complete
          sleep 30

          # Fetch results from SonarCloud API
          PROJECT_KEY="Freundcloud_microservices-demo"

          # Get quality gate status
          QUALITY_GATE=$(curl -s -u "$SONAR_TOKEN:" \
            "https://sonarcloud.io/api/qualitygates/project_status?projectKey=$PROJECT_KEY" \
            | jq -r '.projectStatus.status')

          # Get metrics
          METRICS=$(curl -s -u "$SONAR_TOKEN:" \
            "https://sonarcloud.io/api/measures/component?component=$PROJECT_KEY&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density" \
            | jq '.component.measures')

          BUGS=$(echo "$METRICS" | jq -r '.[] | select(.metric=="bugs") | .value')
          VULNS=$(echo "$METRICS" | jq -r '.[] | select(.metric=="vulnerabilities") | .value')
          SMELLS=$(echo "$METRICS" | jq -r '.[] | select(.metric=="code_smells") | .value')
          COVERAGE=$(echo "$METRICS" | jq -r '.[] | select(.metric=="coverage") | .value')
          DUPS=$(echo "$METRICS" | jq -r '.[] | select(.metric=="duplicated_lines_density") | .value')

          # Map quality gate status
          if [ "$QUALITY_GATE" = "OK" ]; then
            STATUS="passed"
          elif [ "$QUALITY_GATE" = "ERROR" ]; then
            STATUS="failed"
          else
            STATUS="warning"
          fi

          # Output results
          echo "status=$STATUS" >> $GITHUB_OUTPUT
          echo "bugs=${BUGS:-0}" >> $GITHUB_OUTPUT
          echo "vulnerabilities=${VULNS:-0}" >> $GITHUB_OUTPUT
          echo "code_smells=${SMELLS:-0}" >> $GITHUB_OUTPUT
          echo "coverage=${COVERAGE:-0}%" >> $GITHUB_OUTPUT
          echo "duplications=${DUPS:-0}%" >> $GITHUB_OUTPUT

          echo "✓ SonarCloud quality gate: $QUALITY_GATE ($STATUS)"
          echo "  Bugs: ${BUGS:-0}, Vulnerabilities: ${VULNS:-0}, Code Smells: ${SMELLS:-0}"
```

**SonarCloud API Documentation**:
- Quality Gates: `https://sonarcloud.io/api/qualitygates/project_status`
- Metrics: `https://sonarcloud.io/api/measures/component`
- Authentication: Use `SONAR_TOKEN` as basic auth username (password empty)

### Step 3: Wire Outputs in Master Pipeline

**File**: `.github/workflows/MASTER-PIPELINE.yaml`

**Replace current placeholder values**:

```yaml
servicenow-change:
  name: "📝 ServiceNow Change Request"
  needs: [
    pipeline-init,
    register-packages,
    detect-service-changes,
    detect-terraform-changes,
    security-scans,
    sonarcloud-scan,  # ← Add dependency
    get-deployed-version
  ]
  uses: ./.github/workflows/servicenow-change-rest.yaml
  secrets: inherit
  with:
    environment: ${{ needs.pipeline-init.outputs.environment }}
    short_description: 'Deploy microservices to ${{ needs.pipeline-init.outputs.environment }}'
    services_deployed: ${{ needs.detect-service-changes.outputs.services_changed }}
    infrastructure_changes: ${{ needs.detect-terraform-changes.outputs.terraform_changed }}

    # Security scan results
    security_scan_status: '${{ needs.security-scans.outputs.test_result }}'
    critical_vulnerabilities: '${{ needs.security-scans.outputs.critical_count }}'
    high_vulnerabilities: '${{ needs.security-scans.outputs.high_count }}'

    # Unit test results (when enhanced)
    # unit_test_status: '${{ needs.unit-tests.outputs.test_status }}'
    # unit_test_total: '${{ needs.unit-tests.outputs.total_tests }}'
    # unit_test_passed: '${{ needs.unit-tests.outputs.passed_tests }}'
    # unit_test_failed: '${{ needs.unit-tests.outputs.failed_tests }}'
    # unit_test_coverage: '${{ needs.unit-tests.outputs.coverage }}'
    unit_test_url: 'https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}'

    # SonarCloud scan results (wire when outputs added)
    sonarcloud_status: '${{ needs.sonarcloud-scan.outputs.quality_gate }}'
    sonarcloud_bugs: '${{ needs.sonarcloud-scan.outputs.bugs }}'
    sonarcloud_vulnerabilities: '${{ needs.sonarcloud-scan.outputs.vulnerabilities }}'
    sonarcloud_code_smells: '${{ needs.sonarcloud-scan.outputs.code_smells }}'
    sonarcloud_coverage: '${{ needs.sonarcloud-scan.outputs.coverage }}'
    sonarcloud_duplications: '${{ needs.sonarcloud-scan.outputs.duplications }}'
    sonarcloud_url: 'https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo'
```

**Note**: Unit tests currently don't run in Master pipeline. To add:
1. Create a job that runs unit tests for all changed services
2. Wire outputs to servicenow-change job

## Verification

### 1. Verify Fields Exist in ServiceNow

```bash
# View all custom u_* fields on change_request table
open "https://calitiiltddemo3.service-now.com/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
```

### 2. Test Field Population

**Create a test change request with mock data**:

```bash
source .envrc

curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request" \
  -d '{
    "short_description": "Test: Unit Test & SonarCloud Integration",
    "type": "standard",
    "state": "-1",
    "category": "DevOps",
    "u_unit_test_status": "passed",
    "u_unit_test_total": "127",
    "u_unit_test_passed": "127",
    "u_unit_test_failed": "0",
    "u_unit_test_coverage": "85.2%",
    "u_unit_test_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/12345",
    "u_sonarcloud_status": "passed",
    "u_sonarcloud_bugs": "2",
    "u_sonarcloud_vulnerabilities": "0",
    "u_sonarcloud_code_smells": "15",
    "u_sonarcloud_coverage": "82.4%",
    "u_sonarcloud_duplications": "3.2%",
    "u_sonarcloud_url": "https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo"
  }' | jq '.'
```

**Expected output**:
```json
{
  "result": {
    "number": "CHG0030XXX",
    "sys_id": "...",
    "u_unit_test_status": "passed",
    "u_unit_test_total": "127",
    ...
  }
}
```

### 3. View Test Data in ServiceNow UI

1. Open change request: `https://calitiiltddemo3.service-now.com/change_request_list.do`
2. Click on the test change request created above
3. Scroll to "Additional Information" or custom fields section
4. Verify all test result fields are populated

## Benefits for Approval Workflow

### For Approvers

**Before** (without test results):
- Had to manually check GitHub for test status
- No visibility into code quality metrics
- Difficult to assess deployment risk

**After** (with test results):
- All test data in ServiceNow change request
- One-click links to detailed reports
- Clear pass/fail indicators for approval decisions

### Example Approval Decision Matrix

| Scenario | Unit Tests | SonarCloud | Critical Vulns | Approve? |
|----------|-----------|------------|----------------|----------|
| Green    | ✅ 100% passed | ✅ Quality gate passed | 0 | ✅ Auto-approve (dev) |
| Warning  | ✅ 98% passed | ⚠️ Quality gate warning | 0 | ⚠️ Review required |
| Red      | ❌ 85% passed | ❌ Quality gate failed | 2 | ❌ Reject, fix issues |

### ServiceNow Approval Automation

You can create **ServiceNow Approval Rules** based on these fields:

**Example: Auto-reject if tests fail**
```javascript
// ServiceNow Approval Rule Condition
(function() {
  var cr = current;

  // Reject if unit tests failed
  if (cr.u_unit_test_status == 'failed') {
    return false;  // Don't approve
  }

  // Reject if SonarCloud quality gate failed
  if (cr.u_sonarcloud_status == 'failed') {
    return false;
  }

  // Reject if critical vulnerabilities found
  if (parseInt(cr.u_critical_vulnerabilities) > 0) {
    return false;
  }

  return true;  // Safe to approve
})();
```

## Troubleshooting

### Issue: Fields not visible in ServiceNow UI

**Solution**: Add fields to form layout
1. Go to change request form
2. Right-click header → Configure → Form Layout
3. Add custom fields from available list to form sections
4. Save form layout

### Issue: Workflow outputs are empty

**Verify outputs are defined**:
```bash
# Check if workflow has outputs section
grep -A10 "workflow_call:" .github/workflows/sonarcloud-scan.yaml | grep "outputs:"
```

**Verify job outputs are set**:
```bash
# Check if jobs set output values
grep ">> \$GITHUB_OUTPUT" .github/workflows/sonarcloud-scan.yaml
```

### Issue: SonarCloud API returns no data

**Wait for analysis to complete**:
- SonarCloud analysis is asynchronous
- Add `sleep 30` before querying API
- Check analysis status: `/api/ce/component?component=PROJECT_KEY`

**Verify project key is correct**:
```bash
# View your SonarCloud project
open "https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo"
```

## Files Modified

1. ✅ **Created**: `scripts/create-servicenow-test-fields.sh`
2. ✅ **Updated**: `.github/workflows/servicenow-change-rest.yaml` (13 new inputs, JSON payload updated)
3. ✅ **Updated**: `.github/workflows/MASTER-PIPELINE.yaml` (added test result parameters)
4. ⏳ **To Update**: `.github/workflows/run-unit-tests.yaml` (add outputs)
5. ⏳ **To Update**: `.github/workflows/sonarcloud-scan.yaml` (add outputs)

## Related Documentation

- [ServiceNow Custom Fields Setup Guide](SERVICENOW-CUSTOM-FIELDS-SETUP.md)
- [ServiceNow Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [SonarCloud API Documentation](https://sonarcloud.io/web_api)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idoutputs)

---

**Next Steps**:

1. ✅ Custom fields created in ServiceNow
2. ✅ Workflows updated to pass test results
3. ⏳ Enhance `sonarcloud-scan.yaml` to export quality metrics
4. ⏳ Optionally add unit test aggregation to Master pipeline
5. ⏳ Test end-to-end integration with real deployment

**Status**: Infrastructure ready, data population pending workflow enhancements.
