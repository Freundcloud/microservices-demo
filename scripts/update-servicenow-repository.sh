#!/bin/bash
set -e

# Update ServiceNow Repository Record to Link Application
# Fixes missing data in DevOps Insights by linking repository to application

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 ServiceNow Repository Update Script"
echo "======================================="
echo ""

# Configuration
REPO_SYS_ID="a27eca01c3303a14e1bbf0cb05013125"
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"   # Online Boutique
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"  # GithHubARC

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

# Function to check current state
check_current_state() {
  echo "📊 Current Repository State:"
  echo "----------------------------"

  CURRENT=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

  echo "$CURRENT" | jq -r '.result | {
    name,
    url,
    tool: .tool.display_value,
    tool_sys_id: .tool.value,
    application: .application.display_value,
    app_sys_id: .application.value,
    active
  }'
  echo ""
}

# Check initial state
check_current_state

# Method 1: PATCH with sysparm_display_value=true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Method 1: PATCH with display values"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PATCH \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID?sysparm_display_value=true&sysparm_input_display_value=true" \
  -d "{
    \"url\": \"https://github.com/Freundcloud/microservices-demo\",
    \"tool\": \"$TOOL_SYS_ID\",
    \"application\": \"$APP_SYS_ID\",
    \"active\": \"true\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Request succeeded${NC}"
  echo "$BODY" | jq '.'
else
  echo -e "${YELLOW}⚠️  Method 1 returned non-200 status${NC}"
  echo "$BODY" | jq '.'
fi
echo ""

# Check if it worked
sleep 2
check_current_state

# Method 2: PUT (replace entire record)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Method 2: PUT (full update)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PUT \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID" \
  -d "{
    \"name\": \"Freundcloud/microservices-demo\",
    \"url\": \"https://github.com/Freundcloud/microservices-demo\",
    \"tool\": \"$TOOL_SYS_ID\",
    \"application\": \"$APP_SYS_ID\",
    \"active\": true
  }")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Request succeeded${NC}"
  echo "$BODY" | jq '.'
else
  echo -e "${YELLOW}⚠️  Method 2 returned non-200 status${NC}"
  echo "$BODY" | jq '.'
fi
echo ""

# Check if it worked
sleep 2
check_current_state

# Method 3: PATCH with reference link format
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Method 3: PATCH with reference link format"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PATCH \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID" \
  -d "{
    \"url\": \"https://github.com/Freundcloud/microservices-demo\",
    \"tool\": {
      \"link\": \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$TOOL_SYS_ID\",
      \"value\": \"$TOOL_SYS_ID\"
    },
    \"application\": {
      \"link\": \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_app/$APP_SYS_ID\",
      \"value\": \"$APP_SYS_ID\"
    },
    \"active\": true
  }")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Request succeeded${NC}"
  echo "$BODY" | jq '.'
else
  echo -e "${YELLOW}⚠️  Method 3 returned non-200 status${NC}"
  echo "$BODY" | jq '.'
fi
echo ""

# Final check
sleep 2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Final State Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

FINAL=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

APP_VALUE=$(echo "$FINAL" | jq -r '.result.application.value')

if [ -n "$APP_VALUE" ] && [ "$APP_VALUE" != "null" ]; then
  echo -e "${GREEN}✅ SUCCESS! Repository is now linked to application!${NC}"
  echo ""
  echo "$FINAL" | jq -r '.result | {
    name,
    url,
    tool: .tool.display_value,
    application: .application.display_value,
    active
  }'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✅ Next Steps:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. Trigger a workflow run:"
  echo "   gh workflow run MASTER-PIPELINE.yaml --ref main"
  echo ""
  echo "2. Wait 10-15 minutes for data to process"
  echo ""
  echo "3. Check DevOps Insights:"
  echo "   $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
  echo ""
  echo "4. Verify insights summary:"
  echo "   curl -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "     \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=$APP_SYS_ID\""
  echo ""
  exit 0
else
  echo -e "${RED}❌ FAILED: Application field is still NULL${NC}"
  echo ""
  echo "$FINAL" | jq -r '.result | {
    name,
    url,
    tool: .tool.display_value,
    application: .application.display_value,
    active
  }'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${YELLOW}⚠️  Possible Causes:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. Field-level ACL restriction on 'application' field"
  echo "   → User 'github_integration' lacks WRITE permission"
  echo ""
  echo "2. Business rule blocking the update"
  echo "   → Check ServiceNow business rules for sn_devops_repository"
  echo ""
  echo "3. Required field validation"
  echo "   → Check if other mandatory fields are missing"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${YELLOW}Recommended Actions:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Option A: Grant Write Permissions (ServiceNow Admin)"
  echo "  1. Navigate to: System Security → Access Control (ACL)"
  echo "  2. Filter by: Table=sn_devops_repository, Field=application"
  echo "  3. Add role to ACL or add github_integration to required role"
  echo ""
  echo "Option B: Use ServiceNow UI"
  echo "  1. Open: $SERVICENOW_INSTANCE_URL/sn_devops_repository.do?sys_id=$REPO_SYS_ID"
  echo "  2. Click Edit"
  echo "  3. Set Application: Online Boutique"
  echo "  4. Set Active: true"
  echo "  5. Click Update"
  echo ""
  echo "Option C: Use Admin User via API"
  echo "  1. Export SERVICENOW_USERNAME=<admin-user>"
  echo "  2. Export SERVICENOW_PASSWORD=<admin-password>"
  echo "  3. Re-run this script"
  echo ""
  exit 1
fi
