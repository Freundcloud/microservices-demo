# ServiceNow Test Results Integration

> **Status**: Implemented
> **Workflow**: `.github/workflows/upload-test-results-servicenow.yaml`
> **Created**: 2025-10-22

## Overview

This document explains how to upload test execution results to ServiceNow DevOps Change workspace, making test data visible for change approval, compliance, and audit purposes.

## Problem Statement

**Before**: Test results from CI/CD workflows were not visible in ServiceNow:
- No structured test data in ServiceNow DevOps tables
- No link between test execution and change requests
- Missing test evidence in DevOps Change workspace
- No way to view test results for specific change requests

**After**: Comprehensive test results integration:
- ✅ Test results visible in ServiceNow DevOps Change workspace
- ✅ Structured test data in `sn_devops_test_result` and `sn_devops_test_execution` tables
- ✅ Complete audit trail linking tests to change requests
- ✅ Compliance evidence for deployments

## Architecture

### ServiceNow Tables Used

1. **sn_devops_test_execution**
   - Stores high-level test execution metadata
   - Fields:
     - `tool`: Reference to GitHub tool (SN_ORCHESTRATION_TOOL_ID)
     - `test_url`: Link to test execution (GitHub workflow run)
     - `test_execution_duration`: Total duration in seconds
     - `results_import_state`: State of import ("imported")

2. **sn_devops_test_result**
   - Stores individual test result records
   - Fields:
     - `test_execution`: Reference to test execution record
     - `label`: Test suite name (e.g., "Deployment Verification")
     - `result`: Test outcome ("passed" or "failed")
     - `value`: Duration in seconds
     - `units`: Unit of measurement ("seconds")

3. **change_request**
   - Work notes updated with test results summary
   - Links to test execution records

### Data Flow

```
GitHub Actions Workflow
         ↓
1. Create Test Execution (sn_devops_test_execution)
         ↓
2. Create Test Result (sn_devops_test_result)
         ↓
3. Update Change Request Work Notes
         ↓
ServiceNow DevOps Change Workspace
```

## Usage

### Basic Integration Example

Add this job to your workflow after deployment:

```yaml
jobs:
  create-change-request:
    # ... (existing change request creation)
    outputs:
      change_request_sys_id: ${{ steps.create-change.outputs.change_request_sys_id }}
      change_request_number: ${{ steps.create-change.outputs.change_request_number }}

  deploy:
    needs: create-change-request
    # ... (existing deployment steps)

  upload-test-results:
    needs: [create-change-request, deploy]
    uses: ./.github/workflows/upload-test-results-servicenow.yaml
    with:
      change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
      change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
      test_suite_name: "Deployment Verification"
      test_result: "passed"
      test_duration: "120"
    secrets: inherit
```

### Workflow Inputs

| Input | Required | Type | Description | Default |
|-------|----------|------|-------------|---------|
| `change_request_sys_id` | Yes | string | ServiceNow change request sys_id | - |
| `change_request_number` | Yes | string | Change request number (e.g., CHG0030054) | - |
| `test_suite_name` | Yes | string | Name of test suite being executed | - |
| `test_result` | Yes | string | Overall test result: "passed" or "failed" | - |
| `test_duration` | No | string | Test execution duration in seconds | "0" |
| `test_url` | No | string | URL to test results page | GitHub workflow run URL |

### Required Secrets

The workflow uses existing ServiceNow integration secrets:
- `SERVICENOW_USERNAME` - ServiceNow user (github_integration)
- `SERVICENOW_PASSWORD` - ServiceNow password
- `SERVICENOW_INSTANCE_URL` - ServiceNow instance URL
- `SN_ORCHESTRATION_TOOL_ID` - GitHub tool sys_id

## Integration Examples

### Example 1: Deployment Verification Tests

```yaml
upload-deployment-tests:
  needs: [create-change-request, deploy]
  uses: ./.github/workflows/upload-test-results-servicenow.yaml
  with:
    change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
    change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
    test_suite_name: "Deployment Verification - ${{ github.event.inputs.environment }}"
    test_result: ${{ needs.deploy.result == 'success' && 'passed' || 'failed' }}
    test_duration: "120"
    test_url: "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
  secrets: inherit
```

### Example 2: Security Scan Results

```yaml
upload-security-results:
  needs: [create-change-request, security-scan]
  uses: ./.github/workflows/upload-test-results-servicenow.yaml
  with:
    change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
    change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
    test_suite_name: "Security Scanning (CodeQL, Trivy, Semgrep)"
    test_result: ${{ needs.security-scan.result == 'success' && 'passed' || 'failed' }}
    test_duration: "${{ needs.security-scan.outputs.duration }}"
  secrets: inherit
```

### Example 3: Infrastructure Validation

```yaml
upload-terraform-validation:
  needs: [create-change-request, terraform-apply]
  uses: ./.github/workflows/upload-test-results-servicenow.yaml
  with:
    change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
    change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
    test_suite_name: "Terraform Infrastructure Validation"
    test_result: ${{ needs.terraform-apply.result == 'success' && 'passed' || 'failed' }}
    test_duration: "${{ needs.terraform-apply.outputs.duration }}"
  secrets: inherit
```

### Example 4: Multiple Test Suites

```yaml
upload-unit-tests:
  needs: [create-change-request, unit-tests]
  uses: ./.github/workflows/upload-test-results-servicenow.yaml
  with:
    change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
    change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
    test_suite_name: "Unit Tests"
    test_result: ${{ needs.unit-tests.result == 'success' && 'passed' || 'failed' }}
    test_duration: "${{ needs.unit-tests.outputs.duration }}"
  secrets: inherit

upload-integration-tests:
  needs: [create-change-request, integration-tests]
  uses: ./.github/workflows/upload-test-results-servicenow.yaml
  with:
    change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}
    change_request_number: ${{ needs.create-change-request.outputs.change_request_number }}
    test_suite_name: "Integration Tests"
    test_result: ${{ needs.integration-tests.result == 'success' && 'passed' || 'failed' }}
    test_duration: "${{ needs.integration-tests.outputs.duration }}"
  secrets: inherit
```

## Viewing Test Results in ServiceNow

### DevOps Change Workspace

1. Navigate to: `https://calitiiltddemo3.service-now.com/now/devops-change/changes/`
2. Find your change request (e.g., CHG0030054)
3. Click on the change request
4. View test results in:
   - **Work Notes** tab - Test execution summaries
   - **DevOps** section - Linked test execution records
   - **Test Results** tab - Detailed test result records

### Direct Table Access

**Test Executions**:
```
https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_test_execution_list.do
```

**Test Results**:
```
https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_test_result_list.do
```

### API Queries

**Get test executions for a change request**:
```bash
curl -s --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_test_execution?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=sys_id,number,test_url,test_execution_duration,results_import_state"
```

**Get test results for a test execution**:
```bash
curl -s --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_test_result?sysparm_query=test_execution=$TEST_EXEC_SYS_ID&sysparm_fields=label,result,value,units"
```

## Workflow Output

The workflow produces clear output in GitHub Actions logs:

**Success Example**:
```
📊 Creating Test Execution Record in ServiceNow
Change Request: CHG0030054
Test Suite: Deployment Verification
Result: passed

✅ Test Execution created: TEX0001234

📝 Creating Test Result Records
✅ Test Result created: TRS0001235

📋 Adding Test Results to Change Request
✅ Test results added to change request CHG0030054

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TEST RESULTS UPLOADED TO SERVICENOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Change Request: CHG0030054
Test Execution: TEX0001234
Status: passed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Failure Example**:
```
📊 Creating Test Execution Record in ServiceNow
Change Request: CHG0030054
Test Suite: Security Scanning
Result: failed

✅ Test Execution created: TEX0001236

📝 Creating Test Result Records
✅ Test Result created: TRS0001237

📋 Adding Test Results to Change Request
✅ Test results added to change request CHG0030054

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ TEST RESULTS UPLOADED TO SERVICENOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Change Request: CHG0030054
Test Execution: TEX0001236
Status: failed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Error Handling

The workflow is designed to be **non-blocking**:
- If test execution creation fails, continues without failing the workflow
- Logs HTTP status codes and error messages for troubleshooting
- Uses `continue-on-error: false` to ensure failures are visible but don't block pipeline

### Common Errors

**HTTP 400 - Missing Required Fields**:
```
⚠️  Failed to create test execution (HTTP 400)
{"error": {"message": "Missing required field: result"}}
```
**Fix**: Ensure `test_result` input is provided and valid ("passed" or "failed")

**HTTP 401 - Authentication Failed**:
```
⚠️  Failed to create test execution (HTTP 401)
{"error": {"message": "User is not authenticated"}}
```
**Fix**: Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD` secrets are correct

**HTTP 404 - Table Not Found**:
```
⚠️  Failed to create test execution (HTTP 404)
{"error": {"message": "Table sn_devops_test_execution not found"}}
```
**Fix**: Ensure ServiceNow DevOps plugin is installed

## Testing

### Manual Test via API

Create a test execution manually:

```bash
# Set credentials
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD="your-password"
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SN_ORCHESTRATION_TOOL_ID="4c5e482cc3383214e1bbf0cb05013196"

# Create test execution
PAYLOAD=$(jq -n \
  --arg tool_id "$SN_ORCHESTRATION_TOOL_ID" \
  --arg test_url "https://github.com/Freundcloud/microservices-demo/actions/runs/12345678" \
  --arg duration "120" \
  --arg state "imported" \
  '{
    tool: $tool_id,
    test_url: $test_url,
    test_execution_duration: ($duration | tonumber),
    results_import_state: $state
  }')

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_execution")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "201" ]; then
  TEST_EXEC_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
  TEST_EXEC_NUMBER=$(echo "$BODY" | jq -r '.result.number')
  echo "✅ Test Execution created: $TEST_EXEC_NUMBER"
  echo "Sys ID: $TEST_EXEC_SYS_ID"

  # Create test result
  RESULT_PAYLOAD=$(jq -n \
    --arg test_exec "$TEST_EXEC_SYS_ID" \
    --arg label "Manual Test" \
    --arg result "passed" \
    --arg value "120" \
    --arg units "seconds" \
    '{
      test_execution: $test_exec,
      label: $label,
      result: $result,
      value: ($value | tonumber),
      units: $units
    }')

  curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -d "$RESULT_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result"
else
  echo "❌ Failed: HTTP $HTTP_CODE"
  echo "$BODY" | jq .
fi
```

## Benefits

### For Development Teams
- ✅ Automated test evidence collection
- ✅ No manual ServiceNow data entry
- ✅ Complete test history per change
- ✅ Easy integration with existing workflows

### For Change Approvers
- ✅ Visibility into test execution status
- ✅ Test results linked to specific changes
- ✅ Clear pass/fail status for decision making
- ✅ Direct links to detailed test logs

### For Compliance/Audit
- ✅ Complete audit trail of all test executions
- ✅ Structured data for reporting and analytics
- ✅ Evidence that tests were run before deployment
- ✅ Historical test data retention

### For DevOps/SRE
- ✅ Centralized test result visibility
- ✅ Integration with ServiceNow dashboards
- ✅ Metrics on test success rates
- ✅ Identification of problematic deployments

## Roadmap

### Phase 1: Basic Integration ✅
- [x] Create reusable workflow
- [x] Support passed/failed test results
- [x] Link to change requests via work notes
- [x] Documentation and examples

### Phase 2: Enhanced Integration (Planned)
- [ ] Support for multiple test result records per execution
- [ ] Parse test output files (JUnit XML, TAP, etc.)
- [ ] Extract individual test case results
- [ ] Support for test attachments (screenshots, logs)

### Phase 3: Advanced Features (Future)
- [ ] Test result trends and analytics
- [ ] Automated test quality gates
- [ ] Integration with ServiceNow test management
- [ ] Custom test result dashboards

## Troubleshooting

### Test results not appearing in DevOps Change workspace

**Check**:
1. Change request has `category: "DevOps"` and `devops_change: true`
2. Change request is not in "Canceled" state
3. Test execution was created successfully (check HTTP 201 response)
4. Test result links to valid test execution sys_id

### Workflow fails with "Table not found"

**Solution**: Ensure ServiceNow DevOps plugin is installed and activated:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=v_plugin.do?sys_id=com.snc.devops.integration.main
```

### Permission errors when creating test records

**Solution**: Verify `github_integration` user has roles:
- `sn_devops.admin` or `sn_devops.user`
- `rest_service` (for API access)

## Related Documentation

- **Change Request Integration**: [servicenow-integration.yaml](.github/workflows/servicenow-integration.yaml)
- **DevOps Change Workspace Fix**: [SERVICENOW-DEVOPS-CHANGE-WORKSPACE-FIX.md](docs/SERVICENOW-DEVOPS-CHANGE-WORKSPACE-FIX.md)
- **Auto-Approval Setup**: [SERVICENOW-AUTO-APPROVAL-SETUP.md](docs/SERVICENOW-AUTO-APPROVAL-SETUP.md)

## Support

For issues or questions:
1. Check ServiceNow error logs: DevOps > Administration > Error Logs
2. Review GitHub Actions workflow logs
3. Test API access with curl commands above
4. Verify ServiceNow plugin installation

---

**Status**: Ready for production use
**Last Updated**: 2025-10-22
**Workflow File**: `.github/workflows/upload-test-results-servicenow.yaml`
