#!/bin/bash
# Test ServiceNow Change Request Creation via REST API
# This script helps isolate ServiceNow integration issues by testing directly with curl

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ServiceNow Change Request Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check credentials
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
  echo -e "${RED}❌ Missing ServiceNow credentials${NC}"
  echo ""
  echo "Set environment variables:"
  echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
  echo "  export SERVICENOW_USERNAME='your-username'"
  echo "  export SERVICENOW_PASSWORD='your-password'"
  echo ""
  echo "Or source .envrc:"
  echo "  source .envrc"
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo "  Instance: $SERVICENOW_INSTANCE_URL"
echo "  Username: $SERVICENOW_USERNAME"
echo ""

# Test 1: Minimal change request (only required fields)
echo "=========================================="
echo "Test 1: Minimal Change Request"
echo "=========================================="
echo ""

MINIMAL_JSON=$(jq -n '{
  short_description: "Test change request from GitHub - Minimal",
  description: "This is a test change request created via REST API with only required fields."
}')

echo "Payload:"
echo "$MINIMAL_JSON" | jq .
echo ""

echo "Sending request..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$MINIMAL_JSON" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
  CHANGE_NUMBER=$(echo "$BODY" | jq -r '.result.number // "unknown"')
  CHANGE_SYSID=$(echo "$BODY" | jq -r '.result.sys_id // "unknown"')
  echo -e "${GREEN}✅ Test 1 PASSED${NC}"
  echo "  Change Number: $CHANGE_NUMBER"
  echo "  Sys ID: $CHANGE_SYSID"
  echo ""
else
  echo -e "${RED}❌ Test 1 FAILED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Response Body:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  echo ""
fi

# Test 2: Change request with custom fields
echo "=========================================="
echo "Test 2: With Custom GitHub Fields"
echo "=========================================="
echo ""

CUSTOM_JSON=$(jq -n '{
  short_description: "Test change request from GitHub - With Custom Fields",
  description: "This is a test change request with custom GitHub fields (u_github_*).",
  u_github_actor: "olafkfreund",
  u_github_branch: "main",
  u_github_pr: "",
  u_github_commit: "abc1234"
}')

echo "Payload:"
echo "$CUSTOM_JSON" | jq .
echo ""

echo "Sending request..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$CUSTOM_JSON" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
  CHANGE_NUMBER=$(echo "$BODY" | jq -r '.result.number // "unknown"')
  CHANGE_SYSID=$(echo "$BODY" | jq -r '.result.sys_id // "unknown"')
  echo -e "${GREEN}✅ Test 2 PASSED${NC}"
  echo "  Change Number: $CHANGE_NUMBER"
  echo "  Sys ID: $CHANGE_SYSID"
  echo ""

  # Verify custom fields were set
  echo "Verifying custom fields..."
  VERIFY_RESP=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CHANGE_SYSID?sysparm_fields=u_github_actor,u_github_branch,u_github_commit")

  echo "$VERIFY_RESP" | jq '.result' 2>/dev/null
  echo ""
else
  echo -e "${RED}❌ Test 2 FAILED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Response Body:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  echo ""

  # Check if error mentions custom fields
  if echo "$BODY" | grep -q "u_github"; then
    echo -e "${YELLOW}⚠️  Error mentions custom fields (u_github_*)${NC}"
    echo "These fields may not exist in your ServiceNow instance."
    echo ""
    echo "To create them, run:"
    echo "  ./scripts/create-servicenow-custom-fields.sh"
    echo ""
  fi
fi

# Test 3: Change request with multi-line description
echo "=========================================="
echo "Test 3: With Multi-line Description"
echo "=========================================="
echo ""

MULTILINE_DESC=$(printf "Automated deployment to dev environment via GitHub Actions\n\nGitHub Context:\n- Actor: olafkfreund\n- Branch: main\n- Commit: abc1234\n- Direct Push\n\nWorkflow Run: https://github.com/Freundcloud/microservices-demo/actions/runs/12345\nRepository: Freundcloud/microservices-demo\nEvent: push")

MULTILINE_JSON=$(jq -n \
  --arg desc "$MULTILINE_DESC" \
  '{
    short_description: "Test change request from GitHub - Multi-line Description",
    description: $desc
  }')

echo "Payload:"
echo "$MULTILINE_JSON" | jq .
echo ""

echo "Sending request..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$MULTILINE_JSON" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
  CHANGE_NUMBER=$(echo "$BODY" | jq -r '.result.number // "unknown"')
  CHANGE_SYSID=$(echo "$BODY" | jq -r '.result.sys_id // "unknown"')
  echo -e "${GREEN}✅ Test 3 PASSED${NC}"
  echo "  Change Number: $CHANGE_NUMBER"
  echo "  Sys ID: $CHANGE_SYSID"
  echo ""
else
  echo -e "${RED}❌ Test 3 FAILED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Response Body:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  echo ""
fi

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "This script tested three scenarios:"
echo "  1. Minimal change request (only required fields)"
echo "  2. Change request with custom GitHub fields (u_github_*)"
echo "  3. Change request with multi-line description"
echo ""
echo "If Test 1 passed but Test 2 failed:"
echo "  → Custom fields (u_github_*) don't exist in ServiceNow"
echo "  → Run: ./scripts/create-servicenow-custom-fields.sh"
echo ""
echo "If all tests passed:"
echo "  → ServiceNow REST API works correctly"
echo "  → Issue is with ServiceNow DevOps Change action configuration"
echo ""
echo "View created change requests in ServiceNow:"
echo "  $SERVICENOW_INSTANCE_URL/change_request_list.do"
echo ""
