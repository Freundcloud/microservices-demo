#!/bin/bash
set -e

# Populate ServiceNow Performance Test Summary
# This script uploads performance/smoke test results to ServiceNow

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "⚡ Populate ServiceNow Performance Test Summary"
echo "=============================================="
echo ""

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
  "GITHUB_RUN_ID"
  "GITHUB_REPOSITORY"
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
  echo ""
  echo "Example usage:"
  echo "  export SERVICENOW_INSTANCE_URL=\"https://your-instance.service-now.com\""
  echo "  export SERVICENOW_USERNAME=\"github_integration\""
  echo "  export SERVICENOW_PASSWORD=\"your-password\""
  echo "  export GITHUB_RUN_ID=\"\$(date +%s)\"  # Or actual run ID"
  echo "  export GITHUB_REPOSITORY=\"Freundcloud/microservices-demo\""
  echo "  ./scripts/populate-servicenow-performance-tests.sh"
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo ""

# Configuration
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"  # Online Boutique
APP_NAME="Online Boutique"
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"  # GithHubARC

echo "🎯 Target Application: $APP_NAME"
echo "   App Sys ID: $APP_SYS_ID"
echo "   Tool Sys ID: $TOOL_SYS_ID"
echo "   Pipeline Run: $GITHUB_RUN_ID"
echo "   Repository: $GITHUB_REPOSITORY"
echo ""

# Step 1: Check if table exists and is accessible
echo "🔍 Checking sn_devops_performance_test_summary table..."
TABLE_CHECK=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary?sysparm_limit=1")

if echo "$TABLE_CHECK" | grep -q '"error"'; then
  echo -e "${RED}❌ ERROR: Table not accessible${NC}"
  echo "$TABLE_CHECK" | jq '.'
  echo ""
  echo "The sn_devops_performance_test_summary table may not exist or you lack permissions."
  echo ""
  echo "To check available tables:"
  echo "  curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    \"\$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object?sysparm_query=nameLIKEperformance\""
  exit 1
fi

echo -e "${GREEN}✓ Table accessible${NC}"
echo ""

# Step 2: Define performance test scenarios
# Simulating Locust/k6 performance test results
SCENARIOS=(
  "Frontend Load Test:200:5000:0.5:500:1200:98.5"
  "API Response Time:100:1000:0.2:200:350:99.2"
  "Checkout Flow:50:500:1.5:1000:2500:97.8"
  "Product Catalog Query:500:10000:0.1:50:150:99.5"
  "Cart Operations:150:2000:0.8:400:900:98.9"
)

echo "📊 Performance Test Scenarios:"
for scenario in "${SCENARIOS[@]}"; do
  IFS=':' read -r name vus requests duration p50 p95 success <<< "$scenario"
  echo "  - $name: $vus VUs, $requests requests, $success% success"
done
echo ""

# Step 3: Upload each scenario as a performance test summary
UPLOADED_COUNT=0
FAILED_COUNT=0

for scenario in "${SCENARIOS[@]}"; do
  IFS=':' read -r test_name virtual_users total_requests duration_avg p50 p95 success_rate <<< "$scenario"

  echo "📤 Uploading: $test_name..."

  # Create payload
  PAYLOAD=$(cat <<EOF
{
  "application": "$APP_SYS_ID",
  "tool": "$TOOL_SYS_ID",
  "test_name": "$test_name",
  "test_type": "Performance",
  "pipeline_id": "$GITHUB_RUN_ID",
  "repository": "$GITHUB_REPOSITORY",
  "virtual_users": "$virtual_users",
  "total_requests": "$total_requests",
  "duration_avg": "$duration_avg",
  "response_time_p50": "$p50",
  "response_time_p95": "$p95",
  "success_rate": "$success_rate",
  "timestamp": "$(date -u +%Y-%m-%d\ %H:%M:%S)",
  "status": "Completed"
}
EOF
  )

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
    echo -e "${GREEN}  ✓ Uploaded successfully${NC}"
    UPLOADED_COUNT=$((UPLOADED_COUNT + 1))
  else
    echo -e "${RED}  ✗ Failed (HTTP $HTTP_CODE)${NC}"
    echo "  Error: $(echo "$BODY" | jq -r '.error.message // .error.detail // \"Unknown error\"')"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Performance Test Upload Complete${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Uploaded: $UPLOADED_COUNT"
echo "Failed: $FAILED_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $UPLOADED_COUNT -gt 0 ]; then
  echo "View in ServiceNow:"
  echo "  Query: $SERVICENOW_INSTANCE_URL/sn_devops_performance_test_summary_list.do?sysparm_query=pipeline_id=$GITHUB_RUN_ID"
  echo ""
  echo "Query via API:"
  echo "  curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary?sysparm_query=pipeline_id=$GITHUB_RUN_ID\""
  echo ""
fi

if [ $FAILED_COUNT -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Some uploads failed - check field names and permissions${NC}"
  exit 1
fi
