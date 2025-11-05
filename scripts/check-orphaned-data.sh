#!/bin/bash
set -e

echo "🔍 Checking for Orphaned ServiceNow Data"
echo "========================================="
echo ""

# Required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: ServiceNow credentials not set"
  exit 1
fi

# Check if data exists but is NOT linked to our application
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"

echo "Checking for data created in the last 2 hours..."
echo ""

# Recent packages (last 2 hours)
echo "📦 Recent Packages (all, not just our app):"
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=sys_created_onONLast 2 hours@javascript:gs.hoursAgoStart(2)@javascript:gs.hoursAgoEnd(0)&sysparm_limit=5&sysparm_fields=name,app,tool,sys_created_on" \
  | jq -r '.result[] | "  - \(.name) (app: \(.app.display_value // "null"), tool: \(.tool.display_value // "null"), created: \(.sys_created_on))"'

echo ""

# Recent test results
echo "🧪 Recent Test Results:"
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result?sysparm_query=sys_created_onONLast 2 hours@javascript:gs.hoursAgoStart(2)@javascript:gs.hoursAgoEnd(0)&sysparm_limit=5&sysparm_fields=name,app,tool,sys_created_on" \
  | jq -r '.result[] | "  - \(.name) (app: \(.app.display_value // "null"), tool: \(.tool.display_value // "null"), created: \(.sys_created_on))"'

echo ""

# Recent change requests
echo "📝 Recent Change Requests:"
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=sys_created_onONLast 2 hours@javascript:gs.hoursAgoStart(2)@javascript:gs.hoursAgoEnd(0)&sysparm_limit=5&sysparm_fields=number,short_description,u_correlation_id,sys_created_on" \
  | jq -r '.result[] | "  - \(.number): \(.short_description) (correlation: \(.u_correlation_id // "null"), created: \(.sys_created_on))"'

echo ""

# Check if packages exist but tool doesn't match
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking Tool Linkage..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Recent packages by our tool
echo "📦 Recent Packages by our tool ($TOOL_SYS_ID):"
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=tool=$TOOL_SYS_ID^sys_created_onONLast 2 hours@javascript:gs.hoursAgoStart(2)@javascript:gs.hoursAgoEnd(0)&sysparm_limit=5&sysparm_fields=name,app,sys_created_on" \
  | jq -r '.result[] | "  - \(.name) (app: \(.app.display_value // "null"), created: \(.sys_created_on))"'

echo ""

# Get tool_id from recent packages to see if it's different
echo "🔧 Tools used by recent packages:"
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=sys_created_onONLast 2 hours@javascript:gs.hoursAgoStart(2)@javascript:gs.hoursAgoEnd(0)&sysparm_limit=10" \
  | jq -r '.result[] | .tool.value' | sort | uniq | while read tool_id; do
    if [ -n "$tool_id" ]; then
      TOOL_NAME=$(curl -s \
        -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Accept: application/json" \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$tool_id" | jq -r '.result.name')
      echo "  - $tool_id ($TOOL_NAME)"
    fi
  done

echo ""
echo "Expected tool_id: $TOOL_SYS_ID (GithHubARC)"
