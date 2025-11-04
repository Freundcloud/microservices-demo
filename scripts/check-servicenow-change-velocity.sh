#!/bin/bash
set -e

# Check ServiceNow DevOps Change Velocity configuration
# This script checks if your tool is configured to create traditional change requests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "ServiceNow Change Velocity Configuration"
echo "=========================================="
echo ""

# Check for required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${RED}❌ Missing ServiceNow credentials${NC}"
  echo "Please set:"
  echo "  export SERVICENOW_INSTANCE_URL=https://your-instance.service-now.com"
  echo "  export SERVICENOW_USERNAME=your-username"
  echo "  export SERVICENOW_PASSWORD=your-password"
  exit 1
fi

if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo -e "${YELLOW}⚠️  SN_ORCHESTRATION_TOOL_ID not set${NC}"
  echo "Will attempt to find tool registration..."
  echo ""
fi

# 1. Check if DevOps Change Velocity plugin is active
echo "1️⃣  Checking DevOps Change Velocity plugin..."
PLUGIN_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=name=DevOps%20Change%20Velocity&sysparm_fields=active,name,version" \
  2>/dev/null || echo '{"result":[]}')

PLUGIN_ACTIVE=$(echo "$PLUGIN_RESPONSE" | jq -r '.result[0].active // "false"')
PLUGIN_VERSION=$(echo "$PLUGIN_RESPONSE" | jq -r '.result[0].version // "N/A"')

if [ "$PLUGIN_ACTIVE" = "true" ]; then
  echo -e "${GREEN}✅ DevOps Change Velocity plugin is active${NC}"
  echo "   Version: $PLUGIN_VERSION"
else
  echo -e "${RED}❌ DevOps Change Velocity plugin is NOT active${NC}"
  echo -e "${YELLOW}   You need to install/activate the plugin to use changeControl: true${NC}"
fi
echo ""

# 2. Find tool registration
echo "2️⃣  Finding tool registration..."
if [ -n "$SN_ORCHESTRATION_TOOL_ID" ]; then
  TOOL_RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=sys_id=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=name,type,sys_id" \
    2>/dev/null || echo '{"result":[]}')

  TOOL_NAME=$(echo "$TOOL_RESPONSE" | jq -r '.result[0].name // "NOT_FOUND"')

  if [ "$TOOL_NAME" != "NOT_FOUND" ]; then
    echo -e "${GREEN}✅ Tool found: $TOOL_NAME${NC}"
    echo "   Sys ID: $SN_ORCHESTRATION_TOOL_ID"
  else
    echo -e "${RED}❌ Tool not found with sys_id: $SN_ORCHESTRATION_TOOL_ID${NC}"
  fi
else
  # Try to find GitHub tools
  TOOLS_RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=type=GitHub&sysparm_fields=name,sys_id" \
    2>/dev/null || echo '{"result":[]}')

  TOOL_COUNT=$(echo "$TOOLS_RESPONSE" | jq -r '.result | length')

  if [ "$TOOL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $TOOL_COUNT GitHub tool(s):${NC}"
    echo "$TOOLS_RESPONSE" | jq -r '.result[] | "   - \(.name) (sys_id: \(.sys_id))"'

    # Get first tool ID for further checks
    SN_ORCHESTRATION_TOOL_ID=$(echo "$TOOLS_RESPONSE" | jq -r '.result[0].sys_id')
  else
    echo -e "${RED}❌ No GitHub tools registered${NC}"
    echo -e "${YELLOW}   You need to register GitHub as a tool in ServiceNow DevOps${NC}"
  fi
fi
echo ""

# 3. Check change control configuration
if [ -n "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo "3️⃣  Checking change control configuration..."

  # Check sn_devops_change_control_config table
  CONFIG_RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config?sysparm_query=tool_id=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=change_control_enabled,create_change_request,change_type,sys_id" \
    2>/dev/null || echo '{"result":[]}')

  CONFIG_COUNT=$(echo "$CONFIG_RESPONSE" | jq -r '.result | length')

  # Also check if table exists by looking for error
  TABLE_ERROR=$(echo "$CONFIG_RESPONSE" | jq -r '.error.message // ""')

  if [ -n "$TABLE_ERROR" ]; then
    echo -e "${YELLOW}⚠️  sn_devops_change_control_config table not found or not accessible${NC}"
    echo "   Error: $TABLE_ERROR"
    echo ""
    echo -e "${YELLOW}This likely means:${NC}"
    echo "   - DevOps Change Velocity plugin not installed, or"
    echo "   - Your ServiceNow edition doesn't support this feature, or"
    echo "   - Table name is different in your instance"
    echo ""
    echo -e "${GREEN}Alternative Navigation Paths:${NC}"
    echo "   Try these in ServiceNow Application Navigator (All menu):"
    echo "   1. Search: 'change velocity'"
    echo "   2. Search: 'devops config'"
    echo "   3. Search: 'tool configuration'"
    echo ""
    echo "   Direct URLs to try:"
    echo "   - $SERVICENOW_INSTANCE_URL/sn_devops_change_control_config_list.do"
    echo "   - $SERVICENOW_INSTANCE_URL/\$devops.do"
    echo "   - $SERVICENOW_INSTANCE_URL/nav_to.do?uri=sn_devops_change_control_config_list.do"
  elif [ "$CONFIG_COUNT" -gt 0 ]; then
    CHANGE_CONTROL_ENABLED=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].change_control_enabled // "false"')
    CREATE_CR=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].create_change_request // "false"')
    CHANGE_TYPE=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].change_type // "N/A"')
    CONFIG_SYS_ID=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].sys_id // ""')

    echo "   Change Control Enabled: $CHANGE_CONTROL_ENABLED"
    echo "   Create Change Request: $CREATE_CR"
    echo "   Change Type: $CHANGE_TYPE"
    echo ""

    if [ "$CHANGE_CONTROL_ENABLED" = "true" ] && [ "$CREATE_CR" = "true" ]; then
      echo -e "${GREEN}✅ Change control is configured to create traditional CRs${NC}"
      echo -e "${GREEN}   API should return changeControl: true${NC}"
    else
      echo -e "${YELLOW}⚠️  Change control is configured for deployment gates${NC}"
      echo -e "${YELLOW}   API returns changeControl: false${NC}"
      echo ""
      echo -e "${YELLOW}To enable traditional change requests:${NC}"
      echo "   1. Search 'All' menu for: 'change velocity' or 'devops config'"
      echo "   2. Find your tool: $TOOL_NAME"
      echo "   3. Enable 'Create Change Request'"
      echo "   4. Set 'Change Control Enabled' to true"
      echo ""
      if [ -n "$CONFIG_SYS_ID" ]; then
        echo "   Direct edit URL:"
        echo "   $SERVICENOW_INSTANCE_URL/sn_devops_change_control_config.do?sys_id=$CONFIG_SYS_ID"
      fi
    fi
  else
    echo -e "${YELLOW}⚠️  No change control configuration found for this tool${NC}"
    echo -e "${YELLOW}   Tool may be using default deployment gate behavior${NC}"
    echo ""
    echo "   To create configuration:"
    echo "   1. Search 'All' menu for: 'change control config'"
    echo "   2. Click 'New' to create configuration"
    echo "   3. Select tool: $TOOL_NAME"
    echo "   4. Enable 'Create Change Request' and 'Change Control Enabled'"
  fi
else
  echo "3️⃣  Skipping configuration check (no tool ID available)"
fi
echo ""

# 4. Show recent DevOps API calls
echo "4️⃣  Recent DevOps API calls (last 5)..."
CALLBACK_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_callback?sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=5&sysparm_fields=state,change_control,callback_url,sys_created_on" \
  2>/dev/null || echo '{"result":[]}')

CALLBACK_COUNT=$(echo "$CALLBACK_RESPONSE" | jq -r '.result | length')

if [ "$CALLBACK_COUNT" -gt 0 ]; then
  echo "$CALLBACK_RESPONSE" | jq -r '.result[] | "   \(.sys_created_on): changeControl=\(.change_control // "N/A"), state=\(.state)"'
else
  echo -e "${YELLOW}   No DevOps API callbacks found${NC}"
fi
echo ""

# 5. Recommendations
echo "=========================================="
echo "📋 Recommendations"
echo "=========================================="
echo ""

if [ "$PLUGIN_ACTIVE" != "true" ]; then
  echo -e "${RED}❌ Install DevOps Change Velocity plugin:${NC}"
  echo "   1. Go to: System Applications → All Available Applications"
  echo "   2. Search: 'DevOps Change Velocity'"
  echo "   3. Click 'Install'"
  echo ""
fi

if [ "$CHANGE_CONTROL_ENABLED" != "true" ] || [ "$CREATE_CR" != "true" ]; then
  echo -e "${YELLOW}⚠️  Enable traditional change requests:${NC}"
  echo "   1. Navigate: DevOps → Change Velocity → Configuration"
  echo "   2. Find tool: GitHub Actions"
  echo "   3. Enable: 'Create Change Request' = true"
  echo "   4. Enable: 'Change Control Enabled' = true"
  echo "   5. Set: 'Change Type' = Normal or Standard"
  echo ""
  echo -e "${GREEN}✅ Alternative: Use Table API instead${NC}"
  echo "   Edit .github/workflows/MASTER-PIPELINE.yaml line 572:"
  echo "   uses: ./.github/workflows/servicenow-change-rest.yaml"
  echo ""
  echo "   Table API always creates traditional CRs with custom fields"
  echo ""
fi

echo "=========================================="
echo ""
echo "For more details, see:"
echo "  docs/SERVICENOW-DEVOPS-API-VALIDATION.md"
echo "  docs/SERVICENOW-API-COMPARISON.md"
