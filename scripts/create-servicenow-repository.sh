#!/bin/bash
set -e

# Create ServiceNow Repository Record
# This script creates the repository-to-application linkage needed for Insights

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📁 Create ServiceNow Repository Record"
echo "======================================"
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
  echo ""
  echo "Load credentials with:"
  echo "  source .envrc"
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo ""

# Configuration
APP_NAME="Online Boutique"
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"
TOOL_NAME="GithHubARC"
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"
REPO_NAME="Freundcloud/microservices-demo"
REPO_URL="https://github.com/Freundcloud/microservices-demo"

echo "🎯 Configuration:"
echo "   Repository: $REPO_NAME"
echo "   Application: $APP_NAME"
echo "   Tool: $TOOL_NAME"
echo ""

# Step 1: Check if repository already exists
echo "🔍 Checking if repository already exists..."
EXISTING=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=name=$REPO_NAME")

COUNT=$(echo "$EXISTING" | jq -r '.result | length')

if [ "$COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Repository already exists!${NC}"
  echo ""
  echo "Current details:"
  echo "$EXISTING" | jq '.result[] | {
    sys_id,
    name,
    url,
    application: .application.display_value,
    tool: .tool.display_value,
    active
  }'
  echo ""

  EXISTING_SYS_ID=$(echo "$EXISTING" | jq -r '.result[0].sys_id')
  EXISTING_APP=$(echo "$EXISTING" | jq -r '.result[0].application.value // empty')

  if [ "$EXISTING_APP" = "$APP_SYS_ID" ]; then
    echo -e "${GREEN}✅ Repository is already correctly linked to '$APP_NAME'${NC}"
    echo ""
    echo "No changes needed. Repository configuration is correct."
    exit 0
  else
    echo -e "${YELLOW}⚠️  Repository exists but linked to wrong application${NC}"
    echo ""
    read -p "Do you want to UPDATE the repository to link to '$APP_NAME'? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi

    # Update existing repository
    echo ""
    echo "📤 Updating repository linkage..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -X PATCH \
      -d "{\"application\": \"$APP_SYS_ID\"}" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$EXISTING_SYS_ID")

    HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
    BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

    if [ "$HTTP_CODE" = "200" ]; then
      echo -e "${GREEN}✅ SUCCESS! Repository updated${NC}"
      echo ""
      echo "Updated record:"
      echo "$BODY" | jq '.result | {
        sys_id,
        name,
        application: .application.display_value,
        tool: .tool.display_value
      }'
    else
      echo -e "${RED}❌ FAILED (HTTP $HTTP_CODE)${NC}"
      echo "$BODY" | jq '.'
      exit 1
    fi
  fi
else
  echo -e "${GREEN}✓ No existing repository found - will create new${NC}"
  echo ""

  # Create new repository
  echo "📤 Creating repository record..."
  PAYLOAD=$(cat <<EOF
{
  "name": "$REPO_NAME",
  "url": "$REPO_URL",
  "tool": "$TOOL_SYS_ID",
  "application": "$APP_SYS_ID",
  "active": true
}
EOF
)

  echo "Payload:"
  echo "$PAYLOAD" | jq '.'
  echo ""

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository")

  HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  echo "HTTP Status: $HTTP_CODE"

  if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✅ SUCCESS! Repository created${NC}"
    echo ""
    echo "Created record:"
    echo "$BODY" | jq '.result | {
      sys_id,
      name,
      url,
      application: .application.display_value,
      tool: .tool.display_value,
      active
    }'

    RECORD_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
  else
    echo -e "${RED}❌ FAILED (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo "Error details:"
    echo "$BODY" | jq '.'
    exit 1
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Repository Configuration Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "View in ServiceNow:"
echo "  $SERVICENOW_INSTANCE_URL/sn_devops_repository_list.do"
echo ""
echo "Next Steps:"
echo ""
echo "1. Trigger a GitHub Actions workflow to upload fresh data:"
echo "     gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev"
echo ""
echo "2. Wait 10-15 minutes for ServiceNow scheduled jobs to process data"
echo ""
echo "3. Check the Insights Dashboard:"
echo "     $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
echo ""
echo "4. Run diagnostic to verify data appears:"
echo "     ./scripts/diagnose-servicenow-insights.sh"
echo ""
