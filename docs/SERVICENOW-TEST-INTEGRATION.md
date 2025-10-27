# ServiceNow Test Results Integration

## Overview

This document describes how unit test results from all 12 microservices are automatically uploaded to ServiceNow DevOps for tracking, compliance, and change management approval.

## Architecture

### Test Execution and Upload Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ GitHub Actions: Build and Push Docker Images Workflow              │
│                                                                      │
│  For Each Microservice:                                             │
│  1. Setup language runtime (Go/Java/Python/C#/Node.js)              │
│  2. Run unit tests with JUnit XML output                            │
│  3. ✅ Upload test results to ServiceNow ← NEW                      │
│  4. Publish test results to GitHub Checks                           │
│  5. Build Docker image                                              │
│  6. Run security scans                                              │
│  7. Push to ECR                                                     │
│  8. Register package with ServiceNow                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ ServiceNow DevOps Test Report Action
                                    │ (Basic Authentication)
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ServiceNow DevOps Test Results                                      │
│                                                                      │
│  Test Results Table (sn_devops_test_result)                         │
│  ├── Test Suite: frontend                                           │
│  │   Tests: 15 | Passed: 15 | Failed: 0 | Skipped: 0               │
│  │   Framework: Go Test (gotestsum)                                 │
│  │   Commit: abc123                                                 │
│  ├── Test Suite: cartservice                                        │
│  │   Tests: 8 | Passed: 7 | Failed: 1 | Skipped: 0                 │
│  │   Framework: xUnit                                               │
│  │   Commit: abc123                                                 │
│  ├── Test Suite: adservice                                          │
│  │   Tests: 12 | Passed: 12 | Failed: 0 | Skipped: 0               │
│  │   Framework: JUnit (Gradle)                                      │
│  │   Commit: abc123                                                 │
│  └── ...                                                             │
│                                                                      │
│  Linked to Change Requests for approval evidence                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Test Frameworks by Service

### Services with Unit Tests

| Service | Language | Test Framework | Output Format |
|---------|----------|----------------|---------------|
| **frontend** | Go | Go Test (gotestsum) | JUnit XML |
| **checkoutservice** | Go | Go Test (gotestsum) | JUnit XML |
| **productcatalogservice** | Go | Go Test (gotestsum) | JUnit XML |
| **shippingservice** | Go | Go Test (gotestsum) | JUnit XML |
| **cartservice** | C# | xUnit | JUnit XML |
| **adservice** | Java | JUnit (via Gradle) | JUnit XML |
| **emailservice** | Python | pytest | JUnit XML |
| **recommendationservice** | Python | pytest | JUnit XML |
| **shoppingassistantservice** | Python | pytest | JUnit XML |

### Services without Unit Tests

| Service | Language | Status |
|---------|----------|--------|
| **currencyservice** | Node.js | No tests configured (placeholder XML created) |
| **paymentservice** | Node.js | No tests configured (placeholder XML created) |
| **loadgenerator** | Python | Load testing tool (no unit tests needed) |

## Implementation Details

### Workflow Integration

Tests are run **before** Docker image build in [`.github/workflows/build-images.yaml`](../.github/workflows/build-images.yaml).

#### Test Execution Steps

**1. Setup Language Runtime**:
```yaml
- name: Setup Go (for Go services)
  if: matrix.service == 'frontend' || matrix.service == 'checkoutservice' ...
  uses: actions/setup-go@v5
  with:
    go-version: '1.21'
```

**2. Run Tests**:
```yaml
- name: Run Go Tests
  working-directory: src/${{ matrix.service }}
  run: |
    go install gotest.tools/gotestsum@latest
    gotestsum --junitfile test-results.xml --format testname -- -v ./...
```

**3. Upload to ServiceNow**:
```yaml
- name: Upload Test Results to ServiceNow
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: ${{ steps.find-test-results.outputs.path }}
```

**4. Publish to GitHub**:
```yaml
- name: Publish Test Results to GitHub
  uses: EnricoMi/publish-unit-test-result-action@v2
  with:
    files: ${{ steps.find-test-results.outputs.path }}/**/*.xml
    check_name: "${{ matrix.service }} Tests"
```

## Test Result File Locations

### Go Services
- **Location**: `src/{service}/test-results.xml`
- **Generated by**: `gotestsum --junitfile test-results.xml`
- **Format**: JUnit XML

### C# Services (cartservice)
- **Location**: `src/cartservice/tests/TestResults/test-results.xml`
- **Generated by**: `dotnet test --logger "junit;LogFilePath=test-results.xml"`
- **Format**: JUnit XML

### Java Services (adservice)
- **Location**: `src/adservice/build/test-results/test/*.xml`
- **Generated by**: `./gradlew test`
- **Format**: JUnit XML

### Python Services
- **Location**: `src/{service}/test-results.xml`
- **Generated by**: `pytest --junitxml=test-results.xml`
- **Format**: JUnit XML

### Services without Tests
- **Location**: `src/{service}/test-results.xml`
- **Generated by**: Workflow (placeholder)
- **Content**: Empty test suite with status annotation

## ServiceNow Integration

### Authentication Method

Uses **Basic Authentication** with:
- `SERVICENOW_USERNAME` - ServiceNow integration user
- `SERVICENOW_PASSWORD` - User password
- `SERVICENOW_INSTANCE_URL` - ServiceNow instance URL
- `SN_ORCHESTRATION_TOOL_ID` - GitHub tool sys_id

### Test Results in ServiceNow

Navigate to: **DevOps** → **Testing** → **Test Results**

#### Fields Populated

| Field | Description | Example |
|-------|-------------|---------|
| **Test Suite Name** | Service being tested | `frontend`, `cartservice` |
| **Total Tests** | Number of tests executed | `15` |
| **Tests Passed** | Successful tests | `15` |
| **Tests Failed** | Failed tests | `0` |
| **Tests Skipped** | Skipped tests | `0` |
| **Test Framework** | Framework used | `Go Test`, `xUnit`, `JUnit`, `pytest` |
| **Commit SHA** | Git commit | `abc123def456` |
| **Branch** | Git branch | `main` |
| **Triggered By** | GitHub actor | `github-actions[bot]` |
| **Workflow Run** | GitHub run ID | `12345678` |

## Required GitHub Secrets

Same secrets as package registration:

| Secret | Description |
|--------|-------------|
| `SERVICENOW_USERNAME` | ServiceNow user with DevOps integration role |
| `SERVICENOW_PASSWORD` | User password |
| `SERVICENOW_INSTANCE_URL` | Full URL (https://yourinstance.service-now.com) |
| `SN_ORCHESTRATION_TOOL_ID` | GitHub tool sys_id from ServiceNow |

## ServiceNow Configuration

### Prerequisites

1. **ServiceNow DevOps Plugin** - Installed and activated
2. **GitHub Integration** - Configured with orchestration tool
3. **Service Account** with permissions:
   - `sn_devops.devops_integration_user` role
   - Read/Write access to `sn_devops_test_result` table
   - API access enabled

## Verification

### Check Test Results in ServiceNow

**1. Navigate to Test Results**:
```
DevOps → Testing → Test Results
```

**2. Filter by Recent**:
- Sort by "Created" descending
- Filter by repository: `Freundcloud/microservices-demo`

**3. Verify Test Details**:
- Click on test result record
- Check test counts (passed/failed/skipped)
- View XML content if needed
- Verify linked to correct commit

### Check Test Results in GitHub

**1. GitHub Checks Tab**:
- Go to commit or PR
- Click "Checks" tab
- See individual service test results
- View detailed test output

**2. GitHub Actions Logs**:
- Go to Actions tab
- Click on workflow run
- Expand service job (e.g., "Build frontend")
- Check "Upload Test Results to ServiceNow" step
- Verify success status

## Troubleshooting

### Test Upload Fails

**Symptom**: "Upload Test Results to ServiceNow" step fails

**Common Causes**:

1. **Authentication Error**
   ```
   Error: 401 Unauthorized
   ```
   - Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD`
   - Test credentials by logging into ServiceNow UI

2. **Invalid Tool ID**
   ```
   Error: Tool not found
   ```
   - Verify `SN_ORCHESTRATION_TOOL_ID` matches GitHub tool in ServiceNow
   - Navigate to: DevOps → Orchestration → Tools

3. **Malformed XML**
   ```
   Error: Invalid XML format
   ```
   - Check test result file exists and is valid XML
   - View workflow logs for test execution errors

4. **File Not Found**
   ```
   Error: xml-report-filename not found
   ```
   - Test execution may have failed
   - Check "Locate Test Results" step output
   - Verify test framework installed correctly

### Tests Don't Run

**Symptom**: Tests skipped or not executed

**Solutions**:

1. **Check Service Match**: Ensure service name matches in `if` conditions
2. **Verify Language Runtime**: Check setup step ran successfully
3. **Check Test Command**: Review test execution step logs
4. **Missing Dependencies**: Some tests may need additional setup

### Tests Pass but Not Visible in ServiceNow

**Symptom**: GitHub shows success but ServiceNow has no record

**Solutions**:

1. **Check Upload Step**: Verify "Upload Test Results to ServiceNow" ran
2. **API Timeout**: Large test results may timeout - check workflow logs
3. **Table Permissions**: Verify user can write to `sn_devops_test_result`
4. **Cache Issue**: Clear ServiceNow browser cache

## Integration with Change Management

### How Test Results Support Approvals

**1. Automated Evidence Collection**:
- All test results automatically linked to change requests
- Approvers see test status before approving deployments

**2. Quality Gates**:
- ServiceNow can enforce policies requiring test success
- Failed tests can block change approval
- Test coverage metrics available for decision-making

**3. Audit Trail**:
- Complete history of test results per deployment
- Traceability from test failure to code changes
- Compliance evidence for regulations

**Example Change Request with Test Data**:
```
Change Request: CHG0012345
Title: Deploy Frontend v1.2.3 to Production
Status: Pending Approval

Test Results:
✅ frontend: 15/15 tests passed
✅ cartservice: 7/8 tests passed (1 known issue)
✅ checkoutservice: 20/20 tests passed
⚠️ adservice: 10/12 tests passed (2 failures)

Decision: Investigate adservice failures before approving
```

## Benefits

### For Development Teams
- ✅ Automated test result tracking
- ✅ No manual test reporting
- ✅ Test results visible in both GitHub and ServiceNow
- ✅ Early feedback on test failures

### For QA Teams
- ✅ Centralized test result dashboard in ServiceNow
- ✅ Trend analysis across deployments
- ✅ Test failure tracking and resolution
- ✅ Integration with defect management

### For Change Approvers
- ✅ Test evidence available for every deployment
- ✅ Risk assessment based on test results
- ✅ Data-driven approval decisions
- ✅ Historical test trends

### For Compliance & Audit
- ✅ Complete test execution history
- ✅ Proof of quality gates
- ✅ Traceability: Test → Code → Deployment
- ✅ Meets SOC 2 / ISO 27001 requirements

## Test Result Examples

### Successful Test Run

**Service**: `frontend` (Go)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="frontend" tests="15" failures="0" errors="0" skipped="0" time="2.345">
    <testcase name="TestValidateEmail" time="0.001"/>
    <testcase name="TestFormatPrice" time="0.002"/>
    ...
  </testsuite>
</testsuites>
```

**ServiceNow Record**:
- Test Suite: frontend
- Total: 15 | Passed: 15 | Failed: 0 | Skipped: 0
- Status: ✅ Success

### Failed Test Run

**Service**: `cartservice` (C#)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="cartservice" tests="8" failures="1" errors="0" skipped="0">
    <testcase name="AddItemToCart" time="0.05"/>
    <testcase name="RemoveItemFromCart" time="0.03">
      <failure message="Expected 0 items, but was 1"/>
    </testcase>
    ...
  </testsuite>
</testsuites>
```

**ServiceNow Record**:
- Test Suite: cartservice
- Total: 8 | Passed: 7 | Failed: 1 | Skipped: 0
- Status: ⚠️ Failure
- Failure Details: Available in XML attachment

## Related Documentation

- **[Package Registration](SERVICENOW-PACKAGE-REGISTRATION.md)** - Docker image registration
- **[Build Workflow](../.github/workflows/build-images.yaml)** - Complete CI/CD pipeline
- **[ServiceNow DevOps Integration](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)** - Overall integration guide
- **[ServiceNow Test Report Action](https://github.com/ServiceNow/servicenow-devops-test-report)** - Official documentation

## Future Enhancements

Potential improvements:

1. **Test Coverage Reporting**: Upload code coverage metrics to ServiceNow
2. **Performance Benchmarks**: Track test execution time trends
3. **Flaky Test Detection**: Identify unreliable tests
4. **Test Impact Analysis**: Link test failures to code changes
5. **Automated Triage**: Auto-assign test failures to developers
6. **Integration Tests**: Add integration test results alongside unit tests

---

**Last Updated**: 2025-10-27
**Maintained By**: DevOps Team
