#!/bin/bash
set -e

# Upload Performance Test Results to ServiceNow
# This script uploads Locust load test results to sn_devops_performance_test_summary table

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📤 Upload Performance Test Results to ServiceNow"
echo "==============================================="
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
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"  # Online Boutique
APP_NAME="Online Boutique"
TOOL_SYS_ID="$SN_ORCHESTRATION_TOOL_ID"

echo "🎯 Target Application: $APP_NAME"
echo "   App Sys ID: $APP_SYS_ID"
echo "   Tool Sys ID: $TOOL_SYS_ID"
echo "   Pipeline Run: $GITHUB_RUN_ID"
echo "   Repository: $GITHUB_REPOSITORY"
echo "   Environment: $ENVIRONMENT"
echo ""

# Use provided metrics or defaults
AVG_RESPONSE_TIME=${AVG_RESPONSE_TIME:-0}
P50=${P50:-0}
P95=${P95:-0}

# Calculate test duration from environment or use default
DURATION="120"  # Default 2 minutes

echo "📊 Performance Test Summary:"
echo "   Virtual Users: $VIRTUAL_USERS"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Failures: ${FAILURES:-0}"
echo "   Success Rate: $SUCCESS_RATE%"
echo "   Avg Response: ${AVG_RESPONSE_TIME}ms"
echo "   P50 Response: ${P50}ms"
echo "   P95 Response: ${P95}ms"
echo "   Requests/sec: ${REQUESTS_PER_SEC:-0}"
echo ""

# Create payload for performance test results
PAYLOAD=$(cat <<EOF
{
  "application": "$APP_SYS_ID",
  "tool": "$TOOL_SYS_ID",
  "test_name": "Locust Load Test - $ENVIRONMENT",
  "test_type": "Performance",
  "pipeline_id": "$GITHUB_RUN_ID",
  "repository": "$GITHUB_REPOSITORY",
  "virtual_users": "$VIRTUAL_USERS",
  "total_requests": "$TOTAL_REQUESTS",
  "duration_avg": "$DURATION",
  "response_time_p50": "$P50",
  "response_time_p95": "$P95",
  "success_rate": "$SUCCESS_RATE",
  "timestamp": "$(date -u +%Y-%m-%d\ %H:%M:%S)",
  "status": "Completed"
}
EOF
)

echo "📤 Uploading performance test results to ServiceNow..."

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
  echo "View in ServiceNow:"
  if [ -n "$SYS_ID" ]; then
    echo "  Record: $SERVICENOW_INSTANCE_URL/sn_devops_performance_test_summary.do?sys_id=$SYS_ID"
  fi
  echo "  Query: $SERVICENOW_INSTANCE_URL/sn_devops_performance_test_summary_list.do?sysparm_query=pipeline_id=$GITHUB_RUN_ID"
  echo ""
  echo "Query via API:"
  echo "  curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary?sysparm_query=pipeline_id=$GITHUB_RUN_ID\""
  echo ""
else
  echo -e "${RED}❌ Upload failed (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Error details:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  echo ""
  exit 1
fi
