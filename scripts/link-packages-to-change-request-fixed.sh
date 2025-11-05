#!/bin/bash
set -e

# Link ServiceNow DevOps Packages to Change Request (FIXED VERSION)
# This script finds packages registered in the current pipeline run and links them to the change request
# FIX: Uses correlation_id and name-based queries instead of non-existent pipeline_id field

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
echo "Repository: $GITHUB_REPOSITORY"
echo ""

# Find packages registered in this pipeline run
# STRATEGY: Query by correlation_id (most reliable) or fallback to name + time-based query
echo "🔍 Finding packages from this pipeline run..."
echo ""

# Try Method 1: Query by correlation_id (if ServiceNow DevOps action sets it)
echo "Method 1: Searching by correlation_id=$GITHUB_RUN_ID..."

PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=correlation_id=$GITHUB_RUN_ID&sysparm_fields=sys_id,name,short_description")

HTTP_CODE=$(echo "$PACKAGES_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$PACKAGES_RESPONSE" | sed '/HTTP_CODE:/d')

# Validate HTTP response
if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${YELLOW}⚠️  Method 1 failed (HTTP $HTTP_CODE), trying fallback method...${NC}"
  echo ""

  # Method 2: Query by name pattern + recent creation time
  echo "Method 2: Searching by name pattern + time range..."

  # Search for packages created in last 15 minutes containing repository name
  SEARCH_TIME=$(date -u -d '15 minutes ago' '+%Y-%m-%d %H:%M:%S')
  # URL encode the date (replace spaces with %20)
  SEARCH_TIME_ENCODED=$(echo "$SEARCH_TIME" | sed 's/ /%20/g')

  # Extract repo name from full path (e.g., "Freundcloud/microservices-demo" -> "microservices-demo")
  REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

  PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=sys_created_on>=$SEARCH_TIME_ENCODED^nameLIKE$REPO_NAME&sysparm_fields=sys_id,name,short_description")

  HTTP_CODE=$(echo "$PACKAGES_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$PACKAGES_RESPONSE" | sed '/HTTP_CODE:/d')

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
    echo ""
    echo "Available fields in sn_devops_package:"
    echo "  - correlation_id (preferred)"
    echo "  - name"
    echo "  - sys_created_on"
    echo "  - short_description"
    exit 1
  fi
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
  echo "  4. The correlation_id field was not set during package registration"
  echo "  5. Package names don't match repository: $GITHUB_REPOSITORY"
  echo ""
  echo "To verify, check ServiceNow:"
  echo "  Query: correlation_id=$GITHUB_RUN_ID OR nameLIKE$REPO_NAME^sys_created_on>=Last 15 minutes"
  echo "  URL: $SERVICENOW_INSTANCE_URL/sn_devops_package_list.do"
  echo ""
  echo "Skipping package linkage..."
  exit 0
fi

# Display found packages
echo "Found packages:"
echo "$BODY" | jq -r '.result[] | "  - \(.name) (sys_id: \(.sys_id))"'
echo ""

# Link each package to the change request
echo "📦 Linking packages to change request $CHANGE_REQUEST_NUMBER..."
echo ""

LINKED_COUNT=0
ALREADY_LINKED=0
FAILED_COUNT=0

while IFS= read -r pkg; do
  PKG_SYS_ID=$(echo "$pkg" | jq -r '.sys_id')
  PKG_NAME=$(echo "$pkg" | jq -r '.name')

  # First, check if already linked (fetch current change_request value)
  # Note: change_request field might not exist, so we'll try to link anyway

  # Link package to change request via PATCH
  # We'll use the assignment_group field instead of change_request if that doesn't exist
  LINK_PAYLOAD=$(jq -n \
    --arg cr_sys_id "$CHANGE_REQUEST_SYS_ID" \
    '{
      correlation_id: $ARGS.named.run_id,
      comments: ("Linked to change request " + $ARGS.named.cr_number + " by GitHub Actions pipeline run " + $ARGS.named.run_id)
    }' \
    --arg run_id "$GITHUB_RUN_ID" \
    --arg cr_number "$CHANGE_REQUEST_NUMBER")

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

    # Store package sys_id and change request sys_id relationship in comments
    echo "    Updated correlation_id and comments"
  else
    echo -e "${RED}  ✗ $PKG_NAME (HTTP $HTTP_CODE)${NC}"
    FAILED_COUNT=$((FAILED_COUNT + 1))

    # Show error details
    ERROR_BODY=$(echo "$LINK_RESPONSE" | sed '/HTTP_CODE:/d')
    echo "    Error: $(echo "$ERROR_BODY" | jq -r '.error.message // .error.detail // "Unknown error"' 2>/dev/null || echo "$ERROR_BODY")"
  fi
done < <(echo "$BODY" | jq -c '.result[]')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ PACKAGE LINKAGE COMPLETE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Packages updated: $LINKED_COUNT"
echo "Failed: $FAILED_COUNT"
echo "Total packages: $PACKAGE_COUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $LINKED_COUNT -gt 0 ]; then
  echo "View in ServiceNow:"
  echo "  Change Request: $SERVICENOW_INSTANCE_URL/change_request.do?sys_id=$CHANGE_REQUEST_SYS_ID"
  echo "  Packages: $SERVICENOW_INSTANCE_URL/sn_devops_package_list.do?sysparm_query=correlation_id=$GITHUB_RUN_ID"
  echo ""
  echo "NOTE: Since 'change_request' field may not exist in sn_devops_package,"
  echo "      packages are linked via correlation_id and comments fields."
  echo "      This provides an audit trail in ServiceNow."
fi

if [ $FAILED_COUNT -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}⚠️  Some packages failed to link - check permissions and field access${NC}"
  exit 1
fi

exit 0
