#!/bin/bash
set -e

# Diagnose which field in sn_devops_package is causing HTTP 403
# Tests each field individually to isolate permission issue

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ServiceNow Package Field Permission Diagnostic${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo "   Instance: $SERVICENOW_INSTANCE_URL"
echo "   User: $SERVICENOW_USERNAME"
echo ""

# Test function
test_field() {
  local field_name=$1
  local query_param=$2

  echo -e "${YELLOW}Testing field: $field_name${NC}"

  if [ -n "$query_param" ]; then
    # Test in query parameter
    echo "  Testing in sysparm_query..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Accept: application/json" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=$query_param&sysparm_limit=1")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
      echo -e "  ${GREEN}✅ Query: OK (HTTP 200)${NC}"
    else
      echo -e "  ${RED}❌ Query: BLOCKED (HTTP $HTTP_CODE)${NC}"
      BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')
      echo "$BODY" | jq -r '.error.message // .error.detail // "Unknown error"' 2>/dev/null || echo "$BODY"
      return 1
    fi
  fi

  # Test in field list
  echo "  Testing in sysparm_fields..."
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=1&sysparm_fields=$field_name")

  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  if [ "$HTTP_CODE" = "200" ]; then
    # Check if field is in response
    if echo "$BODY" | jq -e ".result[0].$field_name" >/dev/null 2>&1; then
      echo -e "  ${GREEN}✅ Fields: OK (HTTP 200, field present)${NC}"
    else
      echo -e "  ${YELLOW}⚠️  Fields: OK (HTTP 200, but field not in response - may not exist)${NC}"
    fi
  else
    echo -e "  ${RED}❌ Fields: BLOCKED (HTTP $HTTP_CODE)${NC}"
    echo "$BODY" | jq -r '.error.message // .error.detail // "Unknown error"' 2>/dev/null || echo "$BODY"
    return 1
  fi

  echo ""
  return 0
}

# Test baseline access to table
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1: Test Basic Table Access${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=1")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Table access: OK (HTTP 200)${NC}"
  COUNT=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d' | jq -r '.result | length')
  echo "   Found $COUNT record(s)"
else
  echo -e "${RED}❌ Table access: BLOCKED (HTTP $HTTP_CODE)${NC}"
  echo "$RESPONSE" | sed '/HTTP_CODE:/d' | jq '.' 2>/dev/null
  exit 1
fi
echo ""

# Test individual fields
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2: Test Individual Fields${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Standard fields
test_field "sys_id" ""
test_field "name" ""
test_field "version" ""

# Potentially restricted fields
test_field "tool" ""
test_field "pipeline_id" "pipeline_id=123456789"
test_field "change_request" ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3: Test Combined Query (Original Failing Query)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Testing: pipeline_id in query + multiple fields${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=pipeline_id=123456789&sysparm_fields=sys_id,name,version,change_request")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Combined query: OK (HTTP 200)${NC}"
else
  echo -e "${RED}❌ Combined query: BLOCKED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Response:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 4: Test Alternative Query (tool ID)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get tool ID if available
if [ -n "$SN_ORCHESTRATION_TOOL_ID" ]; then
  TOOL_ID="$SN_ORCHESTRATION_TOOL_ID"
else
  TOOL_ID="f62c4e49c3fcf614e1bbf0cb050131ef"  # Default from docs
fi

echo -e "${YELLOW}Testing: Query by tool=$TOOL_ID${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=tool=$TOOL_ID&sysparm_limit=3&sysparm_fields=sys_id,name,version,change_request")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
  echo -e "${GREEN}✅ Tool query: OK (HTTP 200)${NC}"
  COUNT=$(echo "$BODY" | jq -r '.result | length')
  echo "   Found $COUNT package(s)"

  if [ "$COUNT" -gt 0 ]; then
    echo ""
    echo "Sample package:"
    echo "$BODY" | jq '.result[0]'
  fi
else
  echo -e "${RED}❌ Tool query: BLOCKED (HTTP $HTTP_CODE)${NC}"
  echo ""
  echo "Response:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
fi
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Diagnostic Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Based on the results above:"
echo ""
echo "1. If 'pipeline_id' test FAILED:"
echo "   → The pipeline_id field lacks read permission or doesn't exist"
echo "   → Recommended: Use 'tool' field query instead (Option C)"
echo ""
echo "2. If 'change_request' test FAILED:"
echo "   → The change_request reference field is restricted"
echo "   → Recommended: Fetch it separately after initial query"
echo ""
echo "3. If 'Combined query' FAILED but individual fields passed:"
echo "   → Issue with query syntax or combination of fields"
echo "   → Recommended: Review ServiceNow query encoding"
echo ""
echo "4. If 'Tool query' PASSED:"
echo "   → Use tool-based query as workaround"
echo "   → Implement script modification to use tool ID instead"
echo ""

exit 0
