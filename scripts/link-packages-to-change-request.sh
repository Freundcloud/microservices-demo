#!/bin/bash
set -e

# Link ServiceNow DevOps Packages to Change Request
# This script finds packages registered in the current pipeline run and links them to the change request

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
  "CHANGE_REQUEST_SYS_ID"
  "CHANGE_REQUEST_NUMBER"
  "GITHUB_RUN_ID"
  "GITHUB_REPOSITORY"
)

echo "🔗 Linking Packages to Change Request"
echo "======================================"

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

echo -e "${GREEN}✓ All required environment variables present${NC}"
echo ""

echo "Change Request: $CHANGE_REQUEST_NUMBER"
echo "Sys ID: $CHANGE_REQUEST_SYS_ID"
echo "Pipeline Run: $GITHUB_RUN_ID"
echo ""

# Find packages registered in this pipeline run
# Strategy: Query by pipeline_id field for exact match (reliable and fast)
echo "🔍 Finding packages from this pipeline run..."
echo "   Pipeline ID: $GITHUB_RUN_ID"
echo ""

# Query packages by pipeline_id (exact match, no URL encoding issues)
PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=pipeline_id=$GITHUB_RUN_ID&sysparm_fields=sys_id,name,version,change_request")

# Extract HTTP status code
HTTP_CODE=$(echo "$PACKAGES_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$PACKAGES_RESPONSE" | sed '/HTTP_CODE:/d')

# Validate HTTP response
if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${RED}❌ ERROR: ServiceNow API returned HTTP $HTTP_CODE${NC}"
  echo ""
  echo "Response body:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Verify ServiceNow credentials are correct"
  echo "  2. Check if sn_devops_package table exists and is accessible"
  echo "  3. Verify API access permissions for the github_integration user"
  echo "  4. Check ServiceNow instance URL: $SERVICENOW_INSTANCE_URL"
  exit 1
fi

# Validate JSON and extract package count with error handling
if ! PACKAGE_COUNT=$(echo "$BODY" | jq -e '.result | length' 2>/dev/null); then
  echo -e "${RED}❌ ERROR: Failed to parse ServiceNow response${NC}"
  echo ""
  echo "Response was not valid JSON or missing .result field"
  echo "Raw response:"
  echo "$BODY"
  exit 1
fi

echo -e "${GREEN}✓ Found $PACKAGE_COUNT package(s) from this run${NC}"
echo ""

if [ "$PACKAGE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No packages found for pipeline run $GITHUB_RUN_ID${NC}"
  echo ""
  echo "This could mean:"
  echo "  1. Packages haven't been registered yet (register-packages job may still be running)"
  echo "  2. No services were built in this run"
  echo "  3. Package registration failed"
  echo "  4. The pipeline_id field was not set during package registration"
  echo ""
  echo "To verify, check ServiceNow:"
  echo "  $SERVICENOW_INSTANCE_URL/sn_devops_package_list.do?sysparm_query=pipeline_id=$GITHUB_RUN_ID"
  echo ""
  echo "Skipping package linkage..."
  exit 0
fi

# Link each package to the change request
echo "📦 Linking packages to change request $CHANGE_REQUEST_NUMBER..."
echo ""

LINKED_COUNT=0
ALREADY_LINKED=0
FAILED_COUNT=0

while IFS= read -r pkg; do
  PKG_SYS_ID=$(echo "$pkg" | jq -r '.sys_id')
  PKG_NAME=$(echo "$pkg" | jq -r '.name')
  PKG_VERSION=$(echo "$pkg" | jq -r '.version')
  EXISTING_CR=$(echo "$pkg" | jq -r '.change_request.value // "none"')

  # Skip if already linked to this change request
  if [ "$EXISTING_CR" = "$CHANGE_REQUEST_SYS_ID" ]; then
    echo -e "${BLUE}  ✓ $PKG_NAME (already linked)${NC}"
    ALREADY_LINKED=$((ALREADY_LINKED + 1))
    continue
  fi

  # Link package to change request
  LINK_PAYLOAD=$(jq -n \
    --arg cr_sys_id "$CHANGE_REQUEST_SYS_ID" \
    '{
      change_request: $cr_sys_id
    }')

  LINK_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X PATCH \
    -d "$LINK_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package/$PKG_SYS_ID")

  HTTP_CODE=$(echo "$LINK_RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')

  if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ $PKG_NAME${NC}"
    LINKED_COUNT=$((LINKED_COUNT + 1))
  else
    echo -e "${RED}  ✗ $PKG_NAME (HTTP $HTTP_CODE)${NC}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done < <(echo "$BODY" | jq -c '.result[]')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ PACKAGE LINKAGE COMPLETE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Packages linked: $LINKED_COUNT"
echo "Already linked: $ALREADY_LINKED"
echo "Failed: $FAILED_COUNT"
echo "Total packages: $PACKAGE_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $LINKED_COUNT -gt 0 ]; then
  echo "View in ServiceNow:"
  echo "  Change Request: $SERVICENOW_INSTANCE_URL/change_request.do?sys_id=$CHANGE_REQUEST_SYS_ID"
  echo "  Packages: $SERVICENOW_INSTANCE_URL/sn_devops_package_list.do?sysparm_query=change_request=$CHANGE_REQUEST_SYS_ID"
fi

if [ $FAILED_COUNT -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}⚠️  Some packages failed to link - check permissions and field access${NC}"
  exit 1
fi

exit 0
