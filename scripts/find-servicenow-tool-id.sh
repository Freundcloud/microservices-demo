#!/bin/bash
# Find ServiceNow DevOps Tool ID for GitHub Integration
# This script helps you find or create the correct tool ID for SN_ORCHESTRATION_TOOL_ID secret

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ServiceNow instance details
INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"
USERNAME="${SERVICENOW_USERNAME}"
PASSWORD="${SERVICENOW_PASSWORD}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ServiceNow DevOps Tool ID Finder${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check credentials
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo -e "${RED}❌ ServiceNow credentials not set${NC}"
  echo ""
  echo "Set environment variables:"
  echo "  export SERVICENOW_USERNAME='your-username'"
  echo "  export SERVICENOW_PASSWORD='your-password'"
  echo ""
  exit 1
fi

echo -e "${GREEN}✓ Credentials found${NC}"
echo ""

# Test API access
echo "Testing ServiceNow API access..."
TEST_RESP=$(curl -s -w "\n%{http_code}" -u "$USERNAME:$PASSWORD" "$INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1")
TEST_HTTP_CODE=$(echo "$TEST_RESP" | tail -n1)

if [ "$TEST_HTTP_CODE" != "200" ]; then
  echo -e "${RED}❌ API access failed (HTTP $TEST_HTTP_CODE)${NC}"
  echo "Check your credentials and instance URL"
  exit 1
fi

echo -e "${GREEN}✓ API access successful${NC}"
echo ""

# List all DevOps tools
echo "=========================================="
echo "Searching for GitHub tools..."
echo "=========================================="
echo ""

TOOLS_RESP=$(curl -s -w "\n%{http_code}" -u "$USERNAME:$PASSWORD" \
  "$INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=nameLIKEgithub^ORnameLIKEGitHub&sysparm_fields=sys_id,name,type,active,tool_type&sysparm_limit=100")

TOOLS_HTTP_CODE=$(echo "$TOOLS_RESP" | tail -n1)
TOOLS_BODY=$(echo "$TOOLS_RESP" | sed '$d')

if [ "$TOOLS_HTTP_CODE" != "200" ]; then
  echo -e "${RED}❌ Failed to query tools table (HTTP $TOOLS_HTTP_CODE)${NC}"

  # Try without filter
  echo ""
  echo "Trying to list all tools..."
  TOOLS_RESP=$(curl -s -w "\n%{http_code}" -u "$USERNAME:$PASSWORD" \
    "$INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_fields=sys_id,name,type,active,tool_type&sysparm_limit=100")

  TOOLS_HTTP_CODE=$(echo "$TOOLS_RESP" | tail -n1)
  TOOLS_BODY=$(echo "$TOOLS_RESP" | sed '$d')

  if [ "$TOOLS_HTTP_CODE" != "200" ]; then
    echo -e "${RED}❌ Cannot access sn_devops_tool table${NC}"
    echo ""
    echo "Possible causes:"
    echo "  1. User lacks 'sn_devops.devops_user' role"
    echo "  2. ServiceNow DevOps plugin not installed"
    echo "  3. Table doesn't exist in this instance"
    exit 1
  fi
fi

# Parse and display tools
TOOL_COUNT=$(echo "$TOOLS_BODY" | jq -r '.result | length')

if [ "$TOOL_COUNT" = "0" ]; then
  echo -e "${YELLOW}⚠️  No GitHub tools found in sn_devops_tool table${NC}"
  echo ""

  # Check if --create flag was passed
  if [ "$1" != "--create" ]; then
    echo "You need to create a GitHub tool in ServiceNow:"
    echo ""
    echo "Option A: Via ServiceNow UI"
    echo "  1. Navigate to: All > DevOps > Tools"
    echo "  2. Click: New"
    echo "  3. Fill in:"
    echo "     - Name: GitHub"
    echo "     - Type: Source Control"
    echo "     - Tool Type: Git"
    echo "     - Active: true"
    echo "  4. Save and copy the sys_id"
    echo ""
    echo "Option B: Via REST API (auto-create)"
    echo "  Run this script with --create flag:"
    echo "  $0 --create"
    echo ""
    exit 0
  fi
  # If --create flag is set, continue to creation section below
fi

if [ "$TOOL_COUNT" != "0" ]; then
  echo -e "${GREEN}Found $TOOL_COUNT tool(s):${NC}"
  echo ""

  # Display each tool
  echo "$TOOLS_BODY" | jq -r '.result[] | "\(.sys_id)|\(.name)|\(.type // "N/A")|\(.tool_type // "N/A")|\(.active)"' | while IFS='|' read -r sys_id name type tool_type active; do
  if [ "$active" = "true" ]; then
    ACTIVE_LABEL="${GREEN}✓ Active${NC}"
  else
    ACTIVE_LABEL="${RED}✗ Inactive${NC}"
  fi

  echo -e "Tool ID: ${BLUE}$sys_id${NC}"
  echo "  Name: $name"
  echo "  Type: $type"
  echo "  Tool Type: $tool_type"
  echo -e "  Status: $ACTIVE_LABEL"
  echo ""
  done

  # Get first active tool
  ACTIVE_TOOL=$(echo "$TOOLS_BODY" | jq -r '.result[] | select(.active == "true") | .sys_id' | head -n1)

  if [ -n "$ACTIVE_TOOL" ]; then
  echo "=========================================="
  echo -e "${GREEN}✓ Recommended Tool ID:${NC} ${BLUE}$ACTIVE_TOOL${NC}"
  echo "=========================================="
  echo ""
  echo "Update your GitHub secret:"
  echo ""
  echo "  gh secret set SN_ORCHESTRATION_TOOL_ID --body \"$ACTIVE_TOOL\" --repo YOUR_REPO"
  echo ""
  echo "Or via GitHub UI:"
  echo "  1. Go to: Settings > Secrets and variables > Actions"
  echo "  2. Find: SN_ORCHESTRATION_TOOL_ID"
  echo "  3. Update value to: $ACTIVE_TOOL"
  echo ""
  else
    echo -e "${YELLOW}⚠️  No active tools found${NC}"
    echo ""
    echo "Activate a tool in ServiceNow or create a new one"
  fi
fi

# Option to create tool
if [ "$1" = "--create" ]; then
  echo ""
  echo "=========================================="
  echo "Creating GitHub tool..."
  echo "=========================================="
  echo ""

  PAYLOAD=$(jq -n '{
    name: "GitHub",
    type: "Source Control",
    tool_type: "Git",
    active: "true"
  }')

  CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -u "$USERNAME:$PASSWORD" \
    -d "$PAYLOAD" \
    "$INSTANCE_URL/api/now/table/sn_devops_tool")

  CREATE_HTTP_CODE=$(echo "$CREATE_RESP" | tail -n1)
  CREATE_BODY=$(echo "$CREATE_RESP" | sed '$d')

  if [ "$CREATE_HTTP_CODE" = "201" ]; then
    NEW_TOOL_ID=$(echo "$CREATE_BODY" | jq -r '.result.sys_id')
    echo -e "${GREEN}✓ Tool created successfully!${NC}"
    echo ""
    echo -e "New Tool ID: ${BLUE}$NEW_TOOL_ID${NC}"
    echo ""
    echo "Update your GitHub secret:"
    echo "  gh secret set SN_ORCHESTRATION_TOOL_ID --body \"$NEW_TOOL_ID\" --repo YOUR_REPO"
  else
    echo -e "${RED}❌ Failed to create tool (HTTP $CREATE_HTTP_CODE)${NC}"
    echo "$CREATE_BODY" | jq .
  fi
fi

echo ""
echo "Done!"
