#!/usr/bin/env bash
# Test ServiceNow DevOps Change API
# This tests the DevOps-specific change API that the GitHub Action uses

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "ServiceNow DevOps Change API Test"
echo "=========================================="
echo ""

# Load environment variables from .envrc if not already set
if [ -f .envrc ]; then
    echo -e "${BLUE}ℹ️  Loading credentials from .envrc...${NC}"
    source .envrc
fi

# Check required environment variables
REQUIRED_VARS=("SERVICENOW_INSTANCE_URL" "SERVICENOW_USERNAME" "SERVICENOW_PASSWORD")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo -e "${RED}❌ $var is not set${NC}"
        exit 1
    fi
done

# GitHub tool ID from ServiceNow
TOOL_ID="f62c4e49c3fcf614e1bbf0cb050131ef"

echo -e "${GREEN}✓ Using GitHub DevOps Tool ID: $TOOL_ID${NC}"
echo ""

echo -e "${BLUE}Testing DevOps Change API endpoint...${NC}"

# Test the DevOps Change API endpoint
CHANGE_DATA=$(cat <<'EOF'
{
  "setCloseCode": "true",
  "autoCloseChange": true,
  "attributes": {
    "short_description": "Test DevOps Change from API",
    "description": "Testing ServiceNow DevOps Change API integration",
    "type": "standard",
    "state": "implement",
    "priority": "3",
    "assignment_group": "DevOps Engineering",
    "implementation_plan": "Automated deployment",
    "backout_plan": "Rollback deployment",
    "test_plan": "Verify functionality",
    "u_source": "GitHub Actions Test",
    "u_environment": "dev",
    "u_change_type": "kubernetes"
  }
}
EOF
)

echo -e "${YELLOW}Change Request Data:${NC}"
echo "$CHANGE_DATA" | jq '.'
echo ""

# Try the DevOps API endpoint
echo -e "${BLUE}Testing DevOps API: /api/sn_devops/v2/devops/tool/orchestration${NC}"
DEVOPS_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$CHANGE_DATA" \
    "${SERVICENOW_INSTANCE_URL}/api/sn_devops/v2/devops/tool/orchestration?toolId=${TOOL_ID}" 2>/dev/null)

HTTP_CODE=$(echo "$DEVOPS_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$DEVOPS_RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✅ DevOps API is working!${NC}"
    echo "$BODY" | jq '.'
else
    echo -e "${RED}❌ DevOps API Failed (HTTP $HTTP_CODE)${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo ""
    echo -e "${YELLOW}Trying standard REST API as fallback...${NC}"

    # Try standard API
    STANDARD_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -X POST \
        -d "$(echo "$CHANGE_DATA" | jq '.attributes')" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request" 2>/dev/null)

    STD_HTTP_CODE=$(echo "$STANDARD_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
    STD_BODY=$(echo "$STANDARD_RESPONSE" | sed '/HTTP_CODE:/d')

    if [ "$STD_HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}✅ Standard REST API works (HTTP $STD_HTTP_CODE)${NC}"
        CR_NUMBER=$(echo "$STD_BODY" | jq -r '.result.number')
        echo "Created Change Request: $CR_NUMBER"
    else
        echo -e "${RED}❌ Standard REST API also failed (HTTP $STD_HTTP_CODE)${NC}"
        echo "$STD_BODY" | jq '.' 2>/dev/null || echo "$STD_BODY"
    fi
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
