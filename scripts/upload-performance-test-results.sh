#!/bin/bash
set -e

# Upload Performance Test Results to ServiceNow (FIXED VERSION)
# This script uploads Locust load test results to sn_devops_performance_test_summary table
# FIXED: Uses correct ServiceNow field names based on actual table schema

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📤 Upload Performance Test Results to ServiceNow (FIXED)"
echo "========================================================"
echo ""

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
  "SN_ORCHESTRATION_TOOL_ID"
  "GITHUB_RUN_ID"
  "GITHUB_REPOSITORY"
  "ENVIRONMENT"
  "VIRTUAL_USERS"
  "TOTAL_REQUESTS"
  "SUCCESS_RATE"
)

# Validate required environment variables
missing_vars=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  echo -e "${RED}❌ ERROR: Missing required environment variables:${NC}"
  printf '  - %s\n' "${missing_vars[@]}"
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo ""

# Configuration
TOOL_SYS_ID="$SN_ORCHESTRATION_TOOL_ID"

echo "🎯 Configuration:"
echo "   Tool Sys ID: $TOOL_SYS_ID"
echo "   Pipeline Run: $GITHUB_RUN_ID"
echo "   Repository: $GITHUB_REPOSITORY"
echo "   Environment: $ENVIRONMENT"
echo ""

# Use provided metrics or defaults
FAILURES=${FAILURES:-0}
AVG_RESPONSE_TIME=${AVG_RESPONSE_TIME:-0}
REQUESTS_PER_SEC=${REQUESTS_PER_SEC:-0}
P50=${P50:-0}
P95=${P95:-0}

# Calculate passed/failed requests
PASSED_REQUESTS=$((TOTAL_REQUESTS - FAILURES))

# Calculate duration in seconds (default 120 seconds = 2 minutes)
DURATION_SECONDS=${DURATION_SECONDS:-120}

# Calculate timestamps
START_TIME=${START_TIME:-$(date -u -d "$DURATION_SECONDS seconds ago" '+%Y-%m-%d %H:%M:%S')}
END_TIME=${END_TIME:-$(date -u '+%Y-%m-%d %H:%M:%S')}

echo "📊 Performance Test Summary:"
echo "   Virtual Users: $VIRTUAL_USERS"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Passed: $PASSED_REQUESTS"
echo "   Failed: $FAILURES"
echo "   Success Rate: $SUCCESS_RATE%"
echo "   Avg Response: ${AVG_RESPONSE_TIME}ms"
echo "   P50 Response: ${P50}ms"
echo "   P95 Response: ${P95}ms"
echo "   Requests/sec: $REQUESTS_PER_SEC"
echo "   Duration: ${DURATION_SECONDS}s"
echo ""

# Create payload using CORRECT ServiceNow field names
# Based on actual table schema analysis
PAYLOAD=$(cat <<EOF
{
  "name": "Locust Load Test - $ENVIRONMENT",
  "test_type": "Performance",
  "tool": "$TOOL_SYS_ID",
  "project": "$GITHUB_REPOSITORY",
  "url": "https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID",
  "total_tests": "$TOTAL_REQUESTS",
  "passed_tests": "$PASSED_REQUESTS",
  "failed_tests": "$FAILURES",
  "skipped_tests": "0",
  "blocked_tests": "0",
  "passing_percent": "$SUCCESS_RATE",
  "maximum_virtual_users": "$VIRTUAL_USERS",
  "duration": "$DURATION_SECONDS",
  "throughput": "$REQUESTS_PER_SEC",
  "start_time": "$START_TIME",
  "finish_time": "$END_TIME"
}
EOF
)

echo "📋 Payload:"
echo "$PAYLOAD" | jq .
echo ""

echo "📤 Uploading performance test results to ServiceNow..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Upload successful (HTTP $HTTP_CODE)${NC}"
  echo ""

  # Extract sys_id from response
  SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id // empty')

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✅ Performance Test Results Uploaded to ServiceNow${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Test Details:"
  echo "  Test Name: Locust Load Test - $ENVIRONMENT"
  echo "  Total Requests: $TOTAL_REQUESTS (✅ $PASSED_REQUESTS passed, ❌ $FAILURES failed)"
  echo "  Success Rate: $SUCCESS_RATE%"
  echo "  Virtual Users: $VIRTUAL_USERS"
  echo "  Throughput: $REQUESTS_PER_SEC req/s"
  echo "  Duration: ${DURATION_SECONDS}s"
  echo ""
  echo "View in ServiceNow:"
  if [ -n "$SYS_ID" ]; then
    echo "  Record: $SERVICENOW_INSTANCE_URL/sn_devops_performance_test_summary.do?sys_id=$SYS_ID"
  fi
  echo "  List: $SERVICENOW_INSTANCE_URL/sn_devops_performance_test_summary_list.do?sysparm_query=projectCONTAINS$GITHUB_REPOSITORY"
  echo ""
  echo "Query via API:"
  echo "  curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary?sysparm_query=name=Locust Load Test - $ENVIRONMENT\""
  echo ""
  echo "⚠️  Note: This table does NOT have 'application' field."
  echo "   Performance tests are linked via 'tool' field only."
  echo "   To filter: Use 'project' field or 'name' field patterns."
  echo ""
else
  echo -e "${RED}❌ Upload failed (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Error details:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  echo ""
  exit 1
fi
