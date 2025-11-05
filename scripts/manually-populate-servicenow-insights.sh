#!/bin/bash
set -e

# Manually Populate ServiceNow DevOps Insights Summary
# This script creates a test record in sn_devops_insights_st_summary to verify connectivity

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📊 Manually Populate ServiceNow Insights Data"
echo "============================================="
echo ""

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
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

echo "🎯 Target Application:"
echo "   Name: $APP_NAME"
echo "   Sys ID: $APP_SYS_ID"
echo ""

# Step 1: Check if record already exists
echo "🔍 Checking for existing Insights summary record..."
EXISTING=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=$APP_SYS_ID")

COUNT=$(echo "$EXISTING" | jq -r '.result | length')

if [ "$COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Found $COUNT existing record(s)${NC}"
  echo ""
  echo "Existing data:"
  echo "$EXISTING" | jq '.result[] | {application, pipeline_executions, tests, commits, pass_percentage}'
  echo ""
  read -p "Do you want to UPDATE the existing record? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi

  # Get existing sys_id
  EXISTING_SYS_ID=$(echo "$EXISTING" | jq -r '.result[0].sys_id')
  echo "Will update record: $EXISTING_SYS_ID"
else
  echo -e "${GREEN}✓ No existing records found - will create new${NC}"
  EXISTING_SYS_ID=""
fi

echo ""

# Step 2: Prepare test data
echo "📝 Preparing test data..."
PAYLOAD=$(cat <<EOF
{
  "application": "$APP_SYS_ID",
  "pipeline_executions": "5",
  "tests": "48",
  "commits": "127",
  "pass_percentage": "95.83",
  "deployment_frequency": "Daily",
  "lead_time_for_changes": "2 hours",
  "mean_time_to_restore": "30 minutes",
  "change_failure_rate": "4.2"
}
EOF
)

echo "$PAYLOAD" | jq '.'
echo ""

# Step 3: Create or Update record
if [ -z "$EXISTING_SYS_ID" ]; then
  echo "📤 Creating new Insights summary record..."
  METHOD="POST"
  URL="$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary"
else
  echo "📤 Updating existing Insights summary record..."
  METHOD="PATCH"
  URL="$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary/$EXISTING_SYS_ID"
fi

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X $METHOD \
  -d "$PAYLOAD" \
  "$URL")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo -e "${GREEN}✅ SUCCESS!${NC}"
  echo ""
  echo "Created/Updated record:"
  echo "$BODY" | jq '.'

  # Get the sys_id
  RECORD_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✅ Insights Data Successfully Populated!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "View in ServiceNow UI:"
  echo "  $SERVICENOW_INSTANCE_URL/sn_devops_insights_st_summary.do?sys_id=$RECORD_SYS_ID"
  echo ""
  echo "View Insights Dashboard:"
  echo "  $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
  echo ""
  echo "Query via API:"
  echo "  curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=$APP_SYS_ID\""
  echo ""
else
  echo -e "${RED}❌ FAILED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Error details:"
  echo "$BODY" | jq '.'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${YELLOW}⚠️  Possible Issues:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. Table doesn't exist or isn't accessible"
  echo "   → Check if sn_devops_insights_st_summary table exists"
  echo ""
  echo "2. User lacks write permissions"
  echo "   → User 'github_integration' needs write access to the table"
  echo ""
  echo "3. Required fields missing"
  echo "   → Check table schema for mandatory fields"
  echo ""
  echo "4. Invalid field names"
  echo "   → Field names may differ in your ServiceNow instance"
  echo ""
  exit 1
fi
