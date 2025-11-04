#!/bin/bash

# Configure ServiceNow DevOps Change Velocity
# This script enables the Change Velocity dashboard to show data

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ServiceNow Change Velocity Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${RED}❌ Missing ServiceNow credentials${NC}"
  echo "Please set: SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD"
  exit 1
fi

if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo -e "${RED}❌ Missing SN_ORCHESTRATION_TOOL_ID${NC}"
  echo "Run: ./scripts/find-servicenow-tool-id.sh"
  exit 1
fi

echo -e "${GREEN}✓ Environment variables loaded${NC}"
echo "  Instance: $SERVICENOW_INSTANCE_URL"
echo "  Tool ID: $SN_ORCHESTRATION_TOOL_ID"
echo ""

# Step 1: Verify tool exists
echo "1️⃣  Verifying orchestration tool registration..."
TOOL_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$SN_ORCHESTRATION_TOOL_ID?sysparm_fields=name,type,url")

TOOL_NAME=$(echo "$TOOL_RESPONSE" | jq -r '.result.name // ""')

if [ -z "$TOOL_NAME" ]; then
  echo -e "${RED}❌ Tool not found with ID: $SN_ORCHESTRATION_TOOL_ID${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Tool found: $TOOL_NAME${NC}"
echo ""

# Step 2: Check if Change Velocity plugin is installed
echo "2️⃣  Checking DevOps Change Velocity plugin..."
PLUGIN_CHECK=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=source=com.snc.devops.change.velocity&sysparm_fields=active,name,version" \
  2>/dev/null || echo '{"result":[]}')

PLUGIN_ACTIVE=$(echo "$PLUGIN_CHECK" | jq -r '.result[0].active // "false"')
PLUGIN_NAME=$(echo "$PLUGIN_CHECK" | jq -r '.result[0].name // ""')

if [ "$PLUGIN_ACTIVE" = "true" ]; then
  echo -e "${GREEN}✓ DevOps Change Velocity plugin is active${NC}"
  echo "  Plugin: $PLUGIN_NAME"
else
  echo -e "${YELLOW}⚠️  DevOps Change Velocity plugin not found or inactive${NC}"
  echo ""
  echo "To install:"
  echo "  1. Go to: System Applications → All Available Applications"
  echo "  2. Search: 'DevOps Change Velocity'"
  echo "  3. Click Install"
  echo ""
  echo "Note: Personal Developer Instances may not have this plugin available"
fi
echo ""

# Step 3: Check change control configuration
echo "3️⃣  Checking change control configuration..."
CONFIG_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config?sysparm_query=tool_id=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=sys_id,change_control_enabled,create_change_request,change_type,tool_id" \
  2>/dev/null || echo '{"result":[]}')

CONFIG_ERROR=$(echo "$CONFIG_RESPONSE" | jq -r '.error.message // ""')

if [ -n "$CONFIG_ERROR" ]; then
  echo -e "${YELLOW}⚠️  sn_devops_change_control_config table not accessible${NC}"
  echo "  Error: $CONFIG_ERROR"
  echo ""
  echo "This is normal for:"
  echo "  - Personal Developer Instances"
  echo "  - Instances without DevOps Change Velocity plugin"
  echo ""
  echo -e "${BLUE}Alternative: Use direct table navigation${NC}"
  echo "  URL: $SERVICENOW_INSTANCE_URL/sn_devops_change_control_config_list.do"
else
  CONFIG_COUNT=$(echo "$CONFIG_RESPONSE" | jq -r '.result | length')

  if [ "$CONFIG_COUNT" -gt 0 ]; then
    CONFIG_SYS_ID=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].sys_id')
    CHANGE_CONTROL_ENABLED=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].change_control_enabled // "false"')
    CREATE_CR=$(echo "$CONFIG_RESPONSE" | jq -r '.result[0].create_change_request // "false"')

    echo -e "${GREEN}✓ Configuration found${NC}"
    echo "  Change Control Enabled: $CHANGE_CONTROL_ENABLED"
    echo "  Create Change Request: $CREATE_CR"
    echo ""

    if [ "$CHANGE_CONTROL_ENABLED" = "true" ] && [ "$CREATE_CR" = "true" ]; then
      echo -e "${GREEN}✓ Configuration is correct for Change Velocity${NC}"
    else
      echo -e "${YELLOW}⚠️  Configuration needs update${NC}"
      echo ""
      read -p "Update configuration now? (y/n): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating configuration..."
        UPDATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
          -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
          -H "Content-Type: application/json" \
          -H "Accept: application/json" \
          -X PATCH \
          -d '{
            "change_control_enabled": "true",
            "create_change_request": "true",
            "change_type": "standard"
          }' \
          "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config/$CONFIG_SYS_ID")

        HTTP_CODE=$(echo "$UPDATE_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

        if [ "$HTTP_CODE" = "200" ]; then
          echo -e "${GREEN}✓ Configuration updated successfully${NC}"
        else
          echo -e "${RED}❌ Failed to update configuration${NC}"
        fi
      fi
    fi
  else
    echo -e "${YELLOW}⚠️  No configuration found for this tool${NC}"
    echo ""
    read -p "Create configuration now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Creating configuration..."
      CREATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -X POST \
        -d '{
          "tool_id": "'"$SN_ORCHESTRATION_TOOL_ID"'",
          "change_control_enabled": "true",
          "create_change_request": "true",
          "change_type": "standard"
        }' \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config")

      HTTP_CODE=$(echo "$CREATE_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

      if [ "$HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}✓ Configuration created successfully${NC}"
      else
        echo -e "${RED}❌ Failed to create configuration${NC}"
        BODY=$(echo "$CREATE_RESPONSE" | sed 's/HTTP_CODE:.*//')
        echo "$BODY" | jq '.'
      fi
    fi
  fi
fi
echo ""

# Step 4: Check if we have any change references
echo "4️⃣  Checking existing change references..."
REFS_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID&sysparm_limit=5&sysparm_fields=change_request.number,pipeline_name,sys_created_on" \
  2>/dev/null || echo '{"result":[]}')

REF_COUNT=$(echo "$REFS_RESPONSE" | jq -r '.result | length')

if [ "$REF_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✓ Found $REF_COUNT change reference(s)${NC}"
  echo "$REFS_RESPONSE" | jq -r '.result[] | "  - CR: \(.["change_request.number"]) | Pipeline: \(.pipeline_name) | Created: \(.sys_created_on)"'
else
  echo -e "${YELLOW}⚠️  No change references found yet${NC}"
  echo "  Run a deployment to create the first change request"
fi
echo ""

# Step 5: Show dashboard URLs
echo "5️⃣  Dashboard URLs"
echo ""
echo -e "${BLUE}DevOps Change Velocity (Insights):${NC}"
echo "  $SERVICENOW_INSTANCE_URL/now/devops-change/insights-home"
echo ""
echo -e "${BLUE}Change Requests:${NC}"
echo "  $SERVICENOW_INSTANCE_URL/change_request_list.do"
echo ""
echo -e "${BLUE}Change References (linking):${NC}"
echo "  $SERVICENOW_INSTANCE_URL/sn_devops_change_reference_list.do"
echo ""
echo -e "${BLUE}Tool Configuration:${NC}"
echo "  $SERVICENOW_INSTANCE_URL/sn_devops_tool.do?sys_id=$SN_ORCHESTRATION_TOOL_ID"
echo ""

# Step 6: Provide next steps
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$REF_COUNT" -eq 0 ]; then
  echo "1. Run a deployment workflow to create first change request"
  echo "2. Wait for deployment to complete"
  echo "3. Check Change Velocity dashboard for data"
  echo ""
  echo "Note: The dashboard shows trends over time, so you'll need multiple"
  echo "deployments before seeing meaningful insights."
else
  echo -e "${GREEN}✓ You have change data!${NC}"
  echo ""
  echo "The Change Velocity dashboard should show:"
  echo "  - Deployment frequency"
  echo "  - Change lead time"
  echo "  - Change failure rate"
  echo "  - Mean time to recovery"
  echo ""
  echo "If dashboard is still empty:"
  echo "  1. Wait a few minutes for ServiceNow to process data"
  echo "  2. Refresh the dashboard"
  echo "  3. Run more deployments to build historical data"
fi
echo ""
