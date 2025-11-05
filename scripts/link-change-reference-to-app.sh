#!/bin/bash
set -e

# Link Change Reference to Application
# Run this after ServiceNow Change action to ensure change_reference is linked to app
# This script finds the most recent change_reference record and links it to the application

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔗 Linking Change Reference to Application"
echo "==========================================="
echo ""

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
  "GITHUB_RUN_ID"
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

echo "🎯 Target Application: $APP_NAME"
echo "   App Sys ID: $APP_SYS_ID"
echo "   GitHub Run: $GITHUB_RUN_ID"
echo ""

# Step 1: Find the most recent change_reference record (created in last 5 minutes)
echo "🔍 Step 1/2: Finding recent change reference..."

# Calculate timestamp from 5 minutes ago
FIVE_MIN_AGO=$(date -u -d '5 minutes ago' '+%Y-%m-%d %H:%M:%S')

RECENT_REFS=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=sys_created_on>${FIVE_MIN_AGO}^appISEMPTY&sysparm_limit=10&sysparm_fields=sys_id,change_request,sys_created_on&sysparm_query=ORDERBYDESCsys_created_on")

REF_COUNT=$(echo "$RECENT_REFS" | jq '.result | length')

if [ "$REF_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}   ⚠️  No recent unlinked change references found${NC}"
  echo "   This is expected if:"
  echo "   - Change was not created in this run"
  echo "   - Change reference was already linked"
  echo "   - ServiceNow Change action was not used"
  exit 0
fi

echo -e "${GREEN}   ✓ Found $REF_COUNT recent change references${NC}"
echo ""

# Step 2: Link each unlinked reference to the application
echo "🔗 Step 2/2: Linking to $APP_NAME..."
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

echo "$RECENT_REFS" | jq -c '.result[]' | while read -r ref; do
  REF_SYS_ID=$(echo "$ref" | jq -r '.sys_id')
  CHANGE_REF=$(echo "$ref" | jq -r '.change_request.value // "N/A"')
  CREATED=$(echo "$ref" | jq -r '.sys_created_on')

  echo "   Linking: $REF_SYS_ID"
  echo "     Change: $CHANGE_REF"
  echo "     Created: $CREATED"

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X PATCH \
    -d "{\"app\": \"$APP_SYS_ID\"}" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference/$REF_SYS_ID")

  HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')

  if [ "$HTTP_CODE" = "200" ]; then
    echo -e "     ${GREEN}✅ Linked successfully${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "     ${RED}❌ Failed (HTTP $HTTP_CODE)${NC}"
    BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Change Reference Linkage Complete${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Change references are now linked to: $APP_NAME"
echo "This ensures they appear in the App column and DevOps Insights dashboard."
echo ""
