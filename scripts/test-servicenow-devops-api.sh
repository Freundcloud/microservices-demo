#!/bin/bash
#
# Test ServiceNow DevOps API endpoints and plugin installation
#

set -e

# Load credentials
if [ -f .envrc ]; then
  source .envrc 2>/dev/null || true
fi

# Verify credentials
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ServiceNow credentials not found"
  echo ""
  echo "Please set in .envrc:"
  echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
  echo "  export SERVICENOW_USERNAME='your-username'"
  echo "  export SERVICENOW_PASSWORD='your-password'"
  exit 1
fi

echo "=================================================="
echo "ServiceNow DevOps API Test"
echo "=================================================="
echo ""
echo "Instance: $SERVICENOW_INSTANCE_URL"
echo "Username: $SERVICENOW_USERNAME"
echo ""

# Test 1: Check DevOps plugins installation
echo "=== Test 1: Check DevOps Plugins ==="
echo ""
RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=sourceSTARTSWITHcom.snc.devops&sysparm_fields=name,source,state,version")

PLUGIN_COUNT=$(echo "$RESPONSE" | jq -r '.result | length' 2>/dev/null || echo "0")

if [ "$PLUGIN_COUNT" -gt 0 ]; then
  echo "✅ Found $PLUGIN_COUNT DevOps plugin(s):"
  echo "$RESPONSE" | jq -r '.result[] | "  - \(.name) (\(.source))\n    State: \(.state)\n    Version: \(.version)"' 2>/dev/null
else
  echo "❌ No DevOps plugins found"
  echo ""
  echo "The ServiceNow DevOps plugin is NOT installed on this instance."
  echo ""
  echo "To install:"
  echo "  1. Login to ServiceNow"
  echo "  2. Navigate to: System Applications → All Available Applications"
  echo "  3. Search: 'DevOps Change'"
  echo "  4. Click Install"
fi
echo ""

# Test 2: Check DevOps API endpoint availability
echo "=== Test 2: Test DevOps Change API Endpoint ==="
echo ""
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/x_snc_devops/v1/devops/change/validate")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "Endpoint: /api/x_snc_devops/v1/devops/change/validate"
echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "404" ]; then
  echo "❌ DevOps Change API endpoint NOT FOUND (404)"
  echo ""
  echo "This confirms the DevOps plugin is not installed or not activated."
  DEVOPS_API_AVAILABLE=false
elif [ "$HTTP_CODE" = "401" ]; then
  echo "⚠️  DevOps Change API endpoint EXISTS but returned 401 Unauthorized"
  echo ""
  echo "This means:"
  echo "  - Plugin IS installed"
  echo "  - Endpoint requires DevOps Integration Token (not Basic Auth)"
  echo "  - Need to generate token via ServiceNow UI or API"
  DEVOPS_API_AVAILABLE=true
elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "✅ DevOps Change API endpoint is AVAILABLE"
  echo ""
  echo "Response:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  DEVOPS_API_AVAILABLE=true
else
  echo "⚠️  Unexpected HTTP status: $HTTP_CODE"
  echo ""
  echo "Response:"
  echo "$BODY"
  DEVOPS_API_AVAILABLE=false
fi
echo ""

# Test 3: Check for existing DevOps integration tokens
echo "=== Test 3: Check for DevOps Integration Tokens ==="
echo ""
RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/x_snc_devops_integration_token?sysparm_fields=name,description,created_on,expires_at")

TOKEN_COUNT=$(echo "$RESPONSE" | jq -r '.result | length' 2>/dev/null || echo "0")

if [ "$TOKEN_COUNT" -gt 0 ]; then
  echo "✅ Found $TOKEN_COUNT DevOps integration token(s):"
  echo "$RESPONSE" | jq -r '.result[] | "  - \(.name)\n    Created: \(.created_on)\n    Expires: \(.expires_at)"' 2>/dev/null
else
  echo "⚠️  No DevOps integration tokens found"
  echo ""
  echo "If DevOps plugin is installed, you need to generate a token:"
  echo "  1. Navigate to: DevOps → Integration Settings"
  echo "  2. Click 'Generate Token'"
  echo "  3. Copy token (shown only once!)"
  echo "  4. Save as GitHub secret: SN_DEVOPS_INTEGRATION_TOKEN"
fi
echo ""

# Test 4: Try to generate a DevOps integration token (if API available)
if [ "$DEVOPS_API_AVAILABLE" = true ]; then
  echo "=== Test 4: Attempt to Generate DevOps Integration Token ==="
  echo ""

  TOKEN_NAME="GitHub Actions Integration - $(date +%Y%m%d-%H%M%S)"

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    "$SERVICENOW_INSTANCE_URL/api/x_snc_devops/v1/integration/token" \
    -d "{
      \"name\": \"$TOKEN_NAME\",
      \"description\": \"Token for GitHub Actions DevOps Change integration\",
      \"expires_at\": \"2026-12-31 23:59:59\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  echo "HTTP Status: $HTTP_CODE"
  echo ""

  if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Successfully generated DevOps integration token!"
    echo ""
    TOKEN_VALUE=$(echo "$BODY" | jq -r '.result.token' 2>/dev/null)

    if [ -n "$TOKEN_VALUE" ] && [ "$TOKEN_VALUE" != "null" ]; then
      echo "🔑 TOKEN (save this immediately - won't be shown again!):"
      echo ""
      echo "  $TOKEN_VALUE"
      echo ""
      echo "To use this token:"
      echo "  gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body \"$TOKEN_VALUE\""
      echo ""
    else
      echo "Response:"
      echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    fi
  else
    echo "❌ Failed to generate token (HTTP $HTTP_CODE)"
    echo ""
    echo "Response:"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    echo ""
    echo "This might mean:"
    echo "  - Endpoint doesn't exist (plugin not installed)"
    echo "  - User lacks permissions (need x_snc_devops.admin role)"
    echo "  - Token generation disabled"
  fi
  echo ""
fi

# Test 5: Baseline test - Standard API (should always work)
echo "=== Test 5: Baseline Test - Standard Change Request API ==="
echo ""
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_limit=1")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

echo "Endpoint: /api/now/table/change_request"
echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Standard Change Request API works (Basic Auth)"
  echo ""
  echo "This confirms:"
  echo "  - Credentials are valid"
  echo "  - User has access to change_request table"
  echo "  - REST API integration works"
else
  echo "❌ Standard Change Request API failed (HTTP $HTTP_CODE)"
fi
echo ""

# Summary
echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""
if [ "$PLUGIN_COUNT" -gt 0 ]; then
  echo "✅ DevOps plugins: INSTALLED ($PLUGIN_COUNT found)"
else
  echo "❌ DevOps plugins: NOT INSTALLED"
fi

if [ "$DEVOPS_API_AVAILABLE" = true ]; then
  echo "✅ DevOps API: AVAILABLE"
else
  echo "❌ DevOps API: NOT AVAILABLE"
fi

if [ "$TOKEN_COUNT" -gt 0 ]; then
  echo "✅ Integration tokens: FOUND ($TOKEN_COUNT)"
else
  echo "⚠️  Integration tokens: NONE FOUND"
fi

echo ""
echo "Recommendation:"
if [ "$PLUGIN_COUNT" -eq 0 ]; then
  echo "  → Install ServiceNow DevOps plugin to use v6.1.0 action"
  echo "  → OR continue using REST API integration (already working)"
elif [ "$TOKEN_COUNT" -eq 0 ] && [ "$DEVOPS_API_AVAILABLE" = true ]; then
  echo "  → Generate DevOps integration token (see Test 4 above)"
  echo "  → Update GitHub secret: SN_DEVOPS_INTEGRATION_TOKEN"
else
  echo "  → DevOps integration ready to use!"
  echo "  → Retrieve token from ServiceNow and update GitHub secret"
fi
echo ""
