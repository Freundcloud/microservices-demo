#!/bin/bash
#
# Activate ServiceNow DevOps Tool via API
# This script sets the tool to active status
#
# Usage:
#   source .envrc
#   ./scripts/activate-servicenow-tool.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔧 ServiceNow Tool Activation Script"
echo "===================================="
echo ""

# Check environment variables
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
    echo -e "${RED}ERROR: Missing required environment variables${NC}"
    echo "Please source .envrc first: source .envrc"
    exit 1
fi

echo "Configuration:"
echo "  URL: $SERVICENOW_INSTANCE_URL"
echo "  Tool ID: $SN_ORCHESTRATION_TOOL_ID"
echo ""

# First, get the current tool status
echo "Step 1: Fetching current tool status..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
    --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$SN_ORCHESTRATION_TOOL_ID?sysparm_fields=sys_id,name,active,type")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}❌ Failed to fetch tool (HTTP $HTTP_CODE)${NC}"
    exit 1
fi

TOOL_NAME=$(echo "$BODY" | jq -r '.result.name // "Unknown"')
TOOL_ACTIVE=$(echo "$BODY" | jq -r '.result.active // "false"')

echo -e "${GREEN}✅ Tool found: $TOOL_NAME${NC}"
echo "   Current Active Status: $TOOL_ACTIVE"
echo ""

if [ "$TOOL_ACTIVE" = "true" ]; then
    echo -e "${GREEN}✅ Tool is already active!${NC}"
    echo "No action needed."
    exit 0
fi

# Activate the tool
echo "Step 2: Activating tool..."
ACTIVATE_PAYLOAD=$(jq -n '{active: "true"}')

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -d "$ACTIVATE_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$SN_ORCHESTRATION_TOOL_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    NEW_ACTIVE=$(echo "$BODY" | jq -r '.result.active // "unknown"')
    echo -e "${GREEN}✅ Tool activated successfully!${NC}"
    echo "   New Active Status: $NEW_ACTIVE"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ SUCCESS! Tool is now active.${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your GitHub Actions workflows should now work correctly."
    echo ""
    echo "Next steps:"
    echo "  1. Trigger a workflow: git push"
    echo "  2. Monitor in ServiceNow: $SERVICENOW_INSTANCE_URL/now/devops-change/home"
    exit 0
else
    echo -e "${RED}❌ Failed to activate tool (HTTP $HTTP_CODE)${NC}"
    echo ""
    ERROR_MSG=$(echo "$BODY" | jq -r '.error.message // "Unknown error"')
    echo "ServiceNow Error: $ERROR_MSG"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check user has write access to sn_devops_tool table"
    echo "  2. Verify user has 'sn_devops.admin' or equivalent role"
    echo "  3. Try activating manually in ServiceNow UI:"
    echo "     URL: $SERVICENOW_INSTANCE_URL/sn_devops_tool.do?sys_id=$SN_ORCHESTRATION_TOOL_ID"
    exit 1
fi
