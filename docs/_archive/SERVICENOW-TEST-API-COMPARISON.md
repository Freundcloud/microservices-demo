# ServiceNow Test Integration: GitHub Actions vs Direct REST API

## Overview

ServiceNow provides **two methods** for integrating test results:

1. **GitHub Actions** (`ServiceNow/servicenow-devops-test-report@v6.0.0`) - What we currently use
2. **Direct REST API** - Native ServiceNow DevOps APIs

This document compares both approaches and shows when to use each.

**Date**: 2025-10-28

---

## Current Implementation (GitHub Actions)

### What We're Using Now

```yaml
# .github/workflows/build-images.yaml
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

### Advantages of GitHub Actions Approach

✅ **Simple Setup**:
- Pre-configured action from GitHub Marketplace
- No need to write custom HTTP requests
- Built-in error handling

✅ **Automatic Context Handling**:
- GitHub context automatically included
- Commit SHA, branch, actor, workflow all sent
- Less manual configuration

✅ **Maintained by ServiceNow**:
- Updates handled by ServiceNow team
- Bug fixes and security patches
- Version management via tags

✅ **Best for GitHub Actions**:
- Native integration
- Cleaner YAML syntax
- Less code to maintain

### Disadvantages of GitHub Actions Approach

❌ **Limited to GitHub Actions**:
- Can't use in other CI/CD platforms (Jenkins, GitLab CI, CircleCI)
- Locked into GitHub ecosystem

❌ **Less Control**:
- Can't customize API calls
- Can't add custom fields easily
- Limited to what action supports

❌ **Black Box**:
- Don't see actual API calls
- Harder to debug failures
- Can't inspect/modify payloads

❌ **Version Dependency**:
- Must trust action maintainers
- Breaking changes in new versions
- May lag behind API features

---

## Alternative Implementation (Direct REST API)

### ServiceNow DevOps Test Results API

**Endpoint**: `POST /api/sn_devops/devops/tool/test`

**Authentication**: Basic Auth / OAuth 2.0

**Base URL**: `https://your-instance.service-now.com`

### Example: Direct API Call

```yaml
# Alternative to GitHub Action
- name: Upload Test Results via REST API
  run: |
    # Read test results XML
    TEST_RESULTS=$(cat src/${{ matrix.service }}/test-results.xml)

    # Create JSON payload
    PAYLOAD=$(cat <<EOF
    {
      "toolId": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}",
      "testType": "Unit Test",
      "testSummary": {
        "testSuiteName": "${{ matrix.service }}",
        "duration": "30s",
        "totalTests": 15,
        "passedTests": 15,
        "failedTests": 0,
        "skippedTests": 0
      },
      "buildNumber": "${{ github.run_number }}",
      "commitId": "${{ github.sha }}",
      "branchName": "${{ github.ref_name }}",
      "testResults": "$TEST_RESULTS",
      "workflow": {
        "workflowName": "${{ github.workflow }}",
        "runId": "${{ github.run_id }}",
        "actor": "${{ github.actor }}"
      }
    }
    EOF
    )

    # Upload to ServiceNow
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/sn_devops/devops/tool/test"
```

### Advantages of Direct API Approach

✅ **Platform Agnostic**:
- Use in any CI/CD platform (GitHub Actions, Jenkins, GitLab CI, CircleCI, etc.)
- Not locked into GitHub
- Reusable scripts

✅ **Full Control**:
- Customize payload structure
- Add custom fields
- Modify data before sending
- Implement retry logic

✅ **Transparent**:
- See exact API calls
- Easy debugging
- Inspect request/response
- Modify on the fly

✅ **Flexible**:
- Call from anywhere (CLI, scripts, other tools)
- Combine multiple APIs
- Custom business logic

### Disadvantages of Direct API Approach

❌ **More Code to Write**:
- Manual JSON construction
- Error handling required
- More verbose YAML

❌ **Maintenance Burden**:
- Must track API changes
- Update when ServiceNow updates
- Handle breaking changes yourself

❌ **Security Considerations**:
- Manual credential handling
- Must secure API calls
- No built-in best practices

❌ **Learning Curve**:
- Must understand ServiceNow API structure
- Need to read API documentation
- More complex than GitHub Action

---

## Comparison Matrix

| Feature | GitHub Action | Direct REST API |
|---------|---------------|-----------------|
| **Setup Complexity** | ⭐⭐⭐⭐⭐ Easy | ⭐⭐⭐ Medium |
| **Flexibility** | ⭐⭐⭐ Limited | ⭐⭐⭐⭐⭐ High |
| **Platform Support** | ⭐⭐⭐ GitHub only | ⭐⭐⭐⭐⭐ Universal |
| **Control** | ⭐⭐⭐ Limited | ⭐⭐⭐⭐⭐ Full |
| **Debugging** | ⭐⭐ Hard | ⭐⭐⭐⭐⭐ Easy |
| **Maintenance** | ⭐⭐⭐⭐⭐ Low | ⭐⭐⭐ Medium |
| **Security** | ⭐⭐⭐⭐⭐ Built-in | ⭐⭐⭐⭐ Manual |
| **Custom Fields** | ⭐⭐ Hard | ⭐⭐⭐⭐⭐ Easy |

---

## When to Use Each Approach

### Use GitHub Actions When:

✅ You only use GitHub Actions (no other CI/CD)
✅ You want simple setup and maintenance
✅ Standard integration is sufficient
✅ Team prefers managed solutions
✅ Budget for potential troubleshooting

**Recommendation**: **Current approach is fine for pure GitHub Actions environments**

---

### Use Direct REST API When:

✅ Multi-platform CI/CD (GitHub + Jenkins + GitLab)
✅ Need custom fields or data
✅ Want full control over integration
✅ Need to debug API calls frequently
✅ Have complex business logic

**Recommendation**: **Consider migrating if you need flexibility**

---

## Hybrid Approach (Best of Both Worlds)

### Strategy: Use Both

**GitHub Actions for standard cases**:
```yaml
# Standard test upload (most services)
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

**Direct API for custom cases**:
```yaml
# Custom upload with additional metadata
- name: Upload Custom Test Results
  if: matrix.service == 'frontend'  # Only for specific services
  run: |
    ./scripts/upload-test-results-custom.sh \
      --service "${{ matrix.service }}" \
      --test-file "src/${{ matrix.service }}/test-results.xml" \
      --custom-field-1 "value1" \
      --custom-field-2 "value2"
```

**Benefits**:
- ✅ Simple for most cases (GitHub Action)
- ✅ Flexible for special cases (Direct API)
- ✅ Easy migration path (can switch gradually)

---

## Implementation Guide: Direct REST API

### Step 1: Create Upload Script

Create `scripts/upload-test-results-api.sh`:

```bash
#!/bin/bash
set -e

# ServiceNow DevOps Test Results API Upload Script
# Usage: ./upload-test-results-api.sh <service> <test-file>

SERVICE="$1"
TEST_FILE="$2"

# Required environment variables
: "${SERVICENOW_USERNAME:?Environment variable SERVICENOW_USERNAME is required}"
: "${SERVICENOW_PASSWORD:?Environment variable SERVICENOW_PASSWORD is required}"
: "${SERVICENOW_INSTANCE_URL:?Environment variable SERVICENOW_INSTANCE_URL is required}"
: "${SN_ORCHESTRATION_TOOL_ID:?Environment variable SN_ORCHESTRATION_TOOL_ID is required}"
: "${GITHUB_SHA:?Environment variable GITHUB_SHA is required}"
: "${GITHUB_RUN_ID:?Environment variable GITHUB_RUN_ID is required}"

# Read test results
if [ ! -f "$TEST_FILE" ]; then
    echo "Error: Test file not found: $TEST_FILE"
    exit 1
fi

# Parse test results from XML
TOTAL_TESTS=$(grep -oP 'tests="\K[0-9]+' "$TEST_FILE" | head -1 || echo "0")
FAILED_TESTS=$(grep -oP 'failures="\K[0-9]+' "$TEST_FILE" | head -1 || echo "0")
SKIPPED_TESTS=$(grep -oP 'skipped="\K[0-9]+' "$TEST_FILE" | head -1 || echo "0")
PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS - SKIPPED_TESTS))

# Encode test results XML as base64
TEST_RESULTS_BASE64=$(base64 -w 0 "$TEST_FILE")

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
  "toolId": "$SN_ORCHESTRATION_TOOL_ID",
  "testType": "Unit Test",
  "testSummary": {
    "testSuiteName": "$SERVICE",
    "totalTests": $TOTAL_TESTS,
    "passedTests": $PASSED_TESTS,
    "failedTests": $FAILED_TESTS,
    "skippedTests": $SKIPPED_TESTS
  },
  "buildNumber": "$GITHUB_RUN_NUMBER",
  "commitId": "$GITHUB_SHA",
  "branchName": "$GITHUB_REF_NAME",
  "testResultsEncoded": "$TEST_RESULTS_BASE64",
  "workflow": {
    "workflowName": "$GITHUB_WORKFLOW",
    "runId": "$GITHUB_RUN_ID",
    "actor": "$GITHUB_ACTOR"
  }
}
EOF
)

echo "Uploading test results for $SERVICE to ServiceNow..."

# Upload to ServiceNow DevOps API
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -d "$PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/sn_devops/devops/tool/test")

# Extract HTTP status code
HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "201" ]; then
    echo "✅ Test results uploaded successfully"
    echo "$RESPONSE_BODY" | jq '.'
    exit 0
else
    echo "❌ Failed to upload test results"
    echo "HTTP Status: $HTTP_STATUS"
    echo "$RESPONSE_BODY" | jq '.' || echo "$RESPONSE_BODY"
    exit 1
fi
```

---

### Step 2: Use in Workflow

Replace GitHub Action with script:

```yaml
- name: Upload Test Results via REST API
  if: steps.find-test-results.outputs.found == 'true'
  run: |
    chmod +x scripts/upload-test-results-api.sh
    ./scripts/upload-test-results-api.sh \
      "${{ matrix.service }}" \
      "${{ steps.find-test-results.outputs.path }}"
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    GITHUB_SHA: ${{ github.sha }}
    GITHUB_RUN_ID: ${{ github.run_id }}
    GITHUB_RUN_NUMBER: ${{ github.run_number }}
    GITHUB_REF_NAME: ${{ github.ref_name }}
    GITHUB_WORKFLOW: ${{ github.workflow }}
    GITHUB_ACTOR: ${{ github.actor }}
```

---

### Step 3: Add Custom Fields (API Only)

With direct API, you can add custom fields:

```bash
# Enhanced payload with custom fields
PAYLOAD=$(cat <<EOF
{
  "toolId": "$SN_ORCHESTRATION_TOOL_ID",
  "testType": "Unit Test",
  "testSummary": {
    "testSuiteName": "$SERVICE",
    "totalTests": $TOTAL_TESTS,
    "passedTests": $PASSED_TESTS,
    "failedTests": $FAILED_TESTS,
    "skippedTests": $SKIPPED_TESTS
  },
  "buildNumber": "$GITHUB_RUN_NUMBER",
  "commitId": "$GITHUB_SHA",
  "branchName": "$GITHUB_REF_NAME",
  "testResultsEncoded": "$TEST_RESULTS_BASE64",
  "workflow": {
    "workflowName": "$GITHUB_WORKFLOW",
    "runId": "$GITHUB_RUN_ID",
    "actor": "$GITHUB_ACTOR"
  },
  "customFields": {
    "environment": "dev",
    "testFramework": "jest",
    "codeCoverage": "85%",
    "testDuration": "30s",
    "flakyTestCount": 0
  }
}
EOF
)
```

**This is NOT possible with GitHub Actions** - you're limited to predefined fields.

---

## Recommendation for Your Project

### Current State: ✅ Excellent

Your current implementation using GitHub Actions is:
- ✅ Correct and compliant with ServiceNow requirements
- ✅ Simple to understand and maintain
- ✅ Working well for GitHub Actions environment
- ✅ Production-ready

### When to Consider Direct API

Consider migrating to direct REST API if:

1. ❓ You need to add custom fields (environment, test duration, etc.)
2. ❓ You want to use same integration from Jenkins or GitLab CI
3. ❓ You need full debugging visibility
4. ❓ You want to implement custom retry logic
5. ❓ You have complex business rules for test data

### Hybrid Approach (Recommended)

**Best Strategy for You**:

1. ✅ **Keep GitHub Actions for test results** (current implementation)
   - Simple, working, maintained
   - No reason to change

2. ✅ **Use Direct API for code coverage** (already implemented!)
   - You already use direct API for coverage upload
   - Gives you flexibility for custom fields

3. ✅ **Use Direct API for future custom integrations**
   - Flaky test tracking
   - Performance benchmarks
   - Custom quality metrics

**This gives you**:
- ✅ Best of both worlds
- ✅ Simple for standard cases
- ✅ Flexible for custom cases
- ✅ Easy to maintain

---

## API Reference (For Direct Approach)

### ServiceNow DevOps Test Results API

**Endpoint**: `/api/sn_devops/devops/tool/test`

**Method**: `POST`

**Authentication**: Basic Auth or OAuth 2.0

**Headers**:
```
Content-Type: application/json
Accept: application/json
Authorization: Basic base64(username:password)
```

**Request Body**:
```json
{
  "toolId": "sys_id_of_orchestration_tool",
  "testType": "Unit Test" | "Integration Test" | "E2E Test",
  "testSummary": {
    "testSuiteName": "string",
    "duration": "string (optional)",
    "totalTests": integer,
    "passedTests": integer,
    "failedTests": integer,
    "skippedTests": integer
  },
  "buildNumber": "string",
  "commitId": "string",
  "branchName": "string",
  "testResultsEncoded": "base64_encoded_xml",
  "workflow": {
    "workflowName": "string",
    "runId": "string",
    "actor": "string"
  }
}
```

**Response (Success)**:
```json
{
  "result": {
    "testResultId": "sys_id",
    "status": "created",
    "message": "Test results registered successfully"
  }
}
```

**Response (Error)**:
```json
{
  "error": {
    "message": "Error message",
    "detail": "Detailed error information"
  },
  "status": "failure"
}
```

---

## Conclusion

### Answer to Your Question

**Yes, you can absolutely use the direct ServiceNow DevOps REST API!**

**Should you switch?**

**For your current project**: No urgent need
- ✅ GitHub Actions approach is working perfectly
- ✅ Meets all requirements
- ✅ Production-ready

**Consider direct API when**:
- You need custom fields
- You use multiple CI/CD platforms
- You want full debugging control

**Best approach**:
- ✅ Keep GitHub Actions for test results (simple, works)
- ✅ Use direct API for code coverage (flexibility, custom fields)
- ✅ Use direct API for future custom integrations

This hybrid approach gives you:
- ✅ Simplicity where possible
- ✅ Flexibility where needed
- ✅ Easy migration path

---

**Document Version**: 1.0
**Last Updated**: 2025-10-28
**Related Documents**:
- [Test Integration Validation](SERVICENOW-TEST-INTEGRATION-VALIDATION.md)
- [Test Enhancements Summary](SERVICENOW-TEST-ENHANCEMENTS-SUMMARY.md)
- [Coverage Upload Script](../scripts/upload-coverage-to-servicenow.sh)
