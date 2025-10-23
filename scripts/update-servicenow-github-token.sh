#!/bin/bash
#
# Update ServiceNow GitHub Tool with Token
#
# This script updates the ServiceNow GitHub tool with your GitHub Personal Access Token
# that has admin:repo_hook permission.
#
# Usage: ./scripts/update-servicenow-github-token.sh
#

set -euo pipefail

# Configuration (require environment variables to avoid hardcoding secrets)
# Required: SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD, TOOL_ID
if [ -z "${SERVICENOW_INSTANCE_URL:-}" ] || [ -z "${SERVICENOW_USERNAME:-}" ] || [ -z "${SERVICENOW_PASSWORD:-}" ] || [ -z "${TOOL_ID:-}" ]; then
  echo "ERROR: Please set SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD, and TOOL_ID in your environment." >&2
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Update ServiceNow GitHub Tool with Token"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Prompt for GitHub token
echo "Please enter your GitHub Personal Access Token"
echo "(the one with admin:repo_hook permission):"
read -sp "GitHub Token: " GITHUB_TOKEN
echo ""
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ ERROR: Token cannot be empty"
  exit 1
fi

# Verify token has correct permissions
echo "🔍 Verifying token permissions..."
TOKEN_SCOPES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user 2>/dev/null | grep -i "x-oauth-scopes" | cut -d: -f2 | tr -d ' \r')

echo "Token scopes: $TOKEN_SCOPES"

if [[ "$TOKEN_SCOPES" =~ "admin:repo_hook" ]] || [[ "$TOKEN_SCOPES" =~ "repo" ]]; then
  echo "✅ Token has correct permissions"
else
  echo "⚠️  Warning: Token might not have admin:repo_hook permission"
  echo "Token scopes: $TOKEN_SCOPES"
  read -p "Continue anyway? (y/N): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo ""
echo "📤 Updating ServiceNow tool configuration..."

# Update ServiceNow tool with new token
UPDATE_PAYLOAD=$(jq -n --arg token "$GITHUB_TOKEN" '{token: $token}')

UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$UPDATE_PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$TOOL_ID")

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -n1)
BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Successfully updated ServiceNow tool with new token!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Next steps:"
  echo "1. Navigate to: $SERVICENOW_INSTANCE_URL/sn_devops_tool.do?sys_id=$TOOL_ID"
  echo "2. Verify no webhook warnings"
  echo "3. Click 'Test Connection' to verify"
  echo ""
  echo "The webhook permissions warning should now be resolved!"
else
  echo ""
  echo "❌ Failed to update ServiceNow tool (HTTP $HTTP_CODE)"
  echo "Response: $BODY"
  exit 1
fi
