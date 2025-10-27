#!/usr/bin/env bash
# Test ServiceNow Change Request API
# This script tests creating a change request using ServiceNow REST API

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=================================="
echo "ServiceNow Change Request API Test"
echo "=================================="
echo ""

# Load environment variables from .envrc if not already set
if [ -f .envrc ]; then
    echo -e "${BLUE}ℹ️  Loading credentials from .envrc...${NC}"
    source .envrc
else
    echo -e "${YELLOW}⚠️  .envrc file not found. Using environment variables.${NC}"
fi

# Check required environment variables
echo ""
echo -e "${BLUE}1️⃣  Checking required environment variables...${NC}"
REQUIRED_VARS=("SERVICENOW_INSTANCE_URL" "SERVICENOW_USERNAME" "SERVICENOW_PASSWORD")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
        echo -e "${RED}   ✗ $var is not set${NC}"
    else
        # Mask password in output
        if [ "$var" = "SERVICENOW_PASSWORD" ]; then
            echo -e "${GREEN}   ✓ $var is set (hidden)${NC}"
        else
            echo -e "${GREEN}   ✓ $var = ${!var}${NC}"
        fi
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "${RED}   - $var${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 Set them in .envrc file or export them manually:${NC}"
    echo "   export SERVICENOW_INSTANCE_URL=\"https://your-instance.service-now.com\""
    echo "   export SERVICENOW_USERNAME=\"your_username\""
    echo "   export SERVICENOW_PASSWORD=\"your_password\""
    exit 1
fi

echo ""
echo -e "${BLUE}2️⃣  Testing ServiceNow instance connectivity...${NC}"

# Test basic connectivity
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}   ✓ Connection successful (HTTP $HTTP_CODE)${NC}"
elif [ "$HTTP_CODE" = "401" ]; then
    echo -e "${RED}   ✗ Authentication failed (HTTP $HTTP_CODE)${NC}"
    echo -e "${YELLOW}   💡 Check your username and password${NC}"
    exit 1
elif [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}   ✗ Connection failed (network error)${NC}"
    echo -e "${YELLOW}   💡 Check your instance URL: ${SERVICENOW_INSTANCE_URL}${NC}"
    exit 1
else
    echo -e "${YELLOW}   ⚠️  Unexpected response (HTTP $HTTP_CODE)${NC}"
fi

echo ""
echo -e "${BLUE}3️⃣  Retrieving current user information...${NC}"

USER_INFO=$(curl -s \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_query=user_name=${SERVICENOW_USERNAME}&sysparm_limit=1" \
    2>/dev/null)

USER_NAME=$(echo "$USER_INFO" | jq -r '.result[0].name // "Unknown"')
USER_EMAIL=$(echo "$USER_INFO" | jq -r '.result[0].email // "Unknown"')
USER_SYSID=$(echo "$USER_INFO" | jq -r '.result[0].sys_id // "Unknown"')

echo -e "${GREEN}   ✓ Name: $USER_NAME${NC}"
echo -e "${GREEN}   ✓ Email: $USER_EMAIL${NC}"
echo -e "${GREEN}   ✓ Sys ID: $USER_SYSID${NC}"

echo ""
echo -e "${BLUE}4️⃣  Creating test change request...${NC}"

# Create a simple change request
CHANGE_REQUEST_DATA=$(cat <<EOF
{
  "short_description": "Test Change Request from API",
  "description": "This is a test change request created via REST API to validate ServiceNow integration.\n\nEnvironment: dev\nTriggered by: ${SERVICENOW_USERNAME}\nTimestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "type": "standard",
  "state": "assess",
  "priority": "3",
  "assignment_group": "DevOps Engineering",
  "implementation_plan": "1. Apply changes\n2. Monitor rollout\n3. Verify health",
  "backout_plan": "1. Rollback deployment\n2. Verify previous version\n3. Monitor stability",
  "test_plan": "1. Run tests\n2. Verify functionality\n3. Monitor metrics",
  "u_source": "GitHub Actions API Test",
  "u_environment": "dev",
  "u_change_type": "kubernetes"
}
EOF
)

echo -e "${YELLOW}   📝 Change Request Data:${NC}"
echo "$CHANGE_REQUEST_DATA" | jq '.'

echo ""
echo -e "${BLUE}   🚀 Sending request to ServiceNow...${NC}"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$CHANGE_REQUEST_DATA" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request" 2>/dev/null)

# Extract HTTP code and body
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo ""
if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✅ Change Request Created Successfully!${NC}"
    echo ""

    CR_NUMBER=$(echo "$BODY" | jq -r '.result.number')
    CR_SYSID=$(echo "$BODY" | jq -r '.result.sys_id')
    CR_STATE=$(echo "$BODY" | jq -r '.result.state')

    echo -e "${GREEN}   Change Number: $CR_NUMBER${NC}"
    echo -e "${GREEN}   Sys ID: $CR_SYSID${NC}"
    echo -e "${GREEN}   State: $CR_STATE${NC}"
    echo ""
    echo -e "${BLUE}   🔗 View in ServiceNow:${NC}"
    echo "   ${SERVICENOW_INSTANCE_URL}/change_request.do?sys_id=${CR_SYSID}"
    echo ""
    echo -e "${GREEN}✅ ServiceNow API is working correctly!${NC}"

else
    echo -e "${RED}❌ Change Request Creation Failed (HTTP $HTTP_CODE)${NC}"
    echo ""
    echo -e "${YELLOW}Response:${NC}"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo ""

    # Check for common errors
    if echo "$BODY" | grep -q "ACL"; then
        echo -e "${YELLOW}💡 This might be an ACL (Access Control List) issue.${NC}"
        echo "   Your user might not have permission to create change requests."
    elif echo "$BODY" | grep -q "Insert"; then
        echo -e "${YELLOW}💡 This might be a required field issue.${NC}"
        echo "   Check if all required fields are provided."
    fi

    exit 1
fi

echo ""
echo "=================================="
echo "✅ All Tests Passed!"
echo "=================================="
