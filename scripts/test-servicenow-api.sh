#!/bin/bash
# Simple ServiceNow API Test
# Tests if we can connect to ServiceNow and if data from GitHub exists

set -e

# ServiceNow credentials
INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"
USERNAME="${SERVICENOW_USERNAME}"
PASSWORD="${SERVICENOW_PASSWORD}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "ERROR: Set SERVICENOW_USERNAME and SERVICENOW_PASSWORD"
    exit 1
fi

echo "==================================="
echo "ServiceNow API Connectivity Test"
echo "==================================="
echo "Instance: $INSTANCE_URL"
echo "User: $USERNAME"
echo ""

# Test 1: Can we connect?
echo "[Test 1] Testing API connectivity..."
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1")

if echo "$RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
    echo "✅ API connection successful"
else
    echo "❌ API connection failed"
    echo "Response: $RESPONSE"
    exit 1
fi

# Test 2: Check for ANY change requests
echo ""
echo "[Test 2] Checking for change requests..."
CHANGES=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/change_request?sysparm_limit=5&sysparm_fields=number,short_description,sys_created_on")

COUNT=$(echo "$CHANGES" | jq -r '.result | length')
echo "Total change requests found (last 5): $COUNT"

if [ "$COUNT" -gt "0" ]; then
    echo "$CHANGES" | jq -r '.result[] | "  - \(.number): \(.short_description) (\(.sys_created_on))"'
else
    echo "  No change requests found at all"
fi

# Test 3: Check for GitHub-sourced change requests (with custom field)
echo ""
echo "[Test 3] Checking for GitHub-sourced change requests (u_source field)..."
GITHUB_CHANGES=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/change_request?sysparm_query=u_source=GitHub%20Actions&sysparm_limit=10&sysparm_fields=number,short_description,u_source,u_correlation_id,u_repository,u_branch,u_commit_sha,u_actor,u_environment,sys_created_on")

GITHUB_COUNT=$(echo "$GITHUB_CHANGES" | jq -r '.result | length' 2>/dev/null || echo "0")
echo "GitHub change requests found: $GITHUB_COUNT"

if [ "$GITHUB_COUNT" -gt "0" ]; then
    echo "$GITHUB_CHANGES" | jq -r '.result[] | "  - \(.number): \(.short_description)\n    Source: \(.u_source // "N/A")\n    Correlation: \(.u_correlation_id // "N/A")\n    Repository: \(.u_repository // "N/A")\n    Branch: \(.u_branch // "N/A")\n    Commit: \(.u_commit_sha // "N/A")\n    Actor: \(.u_actor // "N/A")\n    Environment: \(.u_environment // "N/A")\n    Created: \(.sys_created_on)"'
    echo ""
    echo "✅ GitHub data IS being sent to ServiceNow!"
    echo "View in ServiceNow: ${INSTANCE_URL}/now/nav/ui/classic/params/target/change_request_list.do?sysparm_query=u_sourceSTARTSWITHGitHub"
elif [ "$GITHUB_COUNT" -eq "0" ] && echo "$GITHUB_CHANGES" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$GITHUB_CHANGES" | jq -r '.error.message')
    echo "⚠️  API Error: $ERROR_MSG"
    echo "This likely means the u_source field doesn't exist on change_request table"
    echo ""
    echo "To fix:"
    echo "1. Run the custom fields creation script:"
    echo "   ./scripts/create-servicenow-custom-fields.sh"
    echo "2. Or manually create fields in ServiceNow:"
    echo "   System Definition > Tables > change_request > New"
else
    echo "⚠️  No GitHub change requests found"
    echo "Possible reasons:"
    echo "1. Workflows haven't run yet (custom fields were just created)"
    echo "2. Run a deployment to populate fields"
    echo "3. Check existing change requests were created before fields existed"
fi

# Test 4: Check correlation ID from most recent workflow
echo ""
echo "[Test 4] Checking for specific workflow run..."
CORRELATION_ID="18715374406"  # Most recent successful run
echo "Looking for correlation_id: $CORRELATION_ID"

CORR_CHANGE=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/change_request?sysparm_query=u_correlation_id=${CORRELATION_ID}&sysparm_fields=number,short_description,u_correlation_id,state")

CORR_COUNT=$(echo "$CORR_CHANGE" | jq -r '.result | length' 2>/dev/null || echo "0")

if [ "$CORR_COUNT" -gt "0" ]; then
    echo "✅ Found change request for workflow $CORRELATION_ID!"
    echo "$CORR_CHANGE" | jq -r '.result[] | "  Number: \(.number)\n  Description: \(.short_description)\n  State: \(.state)"'
else
    echo "⚠️  No change request found for workflow $CORRELATION_ID"
    echo "Check workflow logs to see if creation succeeded"
fi

# Test 5: Check test results table
echo ""
echo "[Test 5] Checking test results table..."
TEST_RESULTS=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/sn_devops_test_result?sysparm_limit=5")

TEST_COUNT=$(echo "$TEST_RESULTS" | jq -r '.result | length' 2>/dev/null || echo "0")
echo "Test results found: $TEST_COUNT"

if [ "$TEST_COUNT" -gt "0" ]; then
    echo "$TEST_RESULTS" | jq -r '.result[] | "  - \(.test_suite_name): \(.test_result)"'
else
    if echo "$TEST_RESULTS" | jq -e '.error' > /dev/null 2>&1; then
        echo "⚠️  Table might not exist or no access"
    else
        echo "⚠️  No test results found"
    fi
fi

echo ""
echo "==================================="
echo "Test Complete"
echo "==================================="
