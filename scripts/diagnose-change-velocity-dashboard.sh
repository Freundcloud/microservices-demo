#!/bin/bash

# Diagnose why Change Velocity dashboard shows GitLab data but not GitHub data

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Change Velocity Dashboard Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${RED}❌ Missing ServiceNow credentials${NC}"
  echo "Please set: SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD"
  exit 1
fi

if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo -e "${YELLOW}⚠️  SN_ORCHESTRATION_TOOL_ID not set${NC}"
  echo "Will search for GitHub tool..."
  echo ""
fi

# Step 1: List ALL tools
echo "1️⃣  Listing ALL orchestration tools..."
TOOLS_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_fields=sys_id,name,type,url")

echo "$TOOLS_RESPONSE" | jq -r '.result[] | "  - \(.name) (\(.type)) | ID: \(.sys_id)"'
echo ""

# Step 2: List ALL change control configurations
echo "2️⃣  Listing ALL change control configurations..."
CONFIGS_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config?sysparm_display_value=true&sysparm_fields=sys_id,tool,change_control_enabled,create_change_request,change_type")

CONFIG_COUNT=$(echo "$CONFIGS_RESPONSE" | jq -r '.result | length')

if [ "$CONFIG_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No change control configurations found${NC}"
else
  echo -e "${GREEN}Found $CONFIG_COUNT configuration(s):${NC}"
  echo "$CONFIGS_RESPONSE" | jq -r '.result[] | "  - Tool: \(.tool.display_value) | Enabled: \(.change_control_enabled) | Create CR: \(.create_change_request) | Type: \(.change_type)"'
fi
echo ""

# Step 3: Find GitHub tool ID if not set
if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo "3️⃣  Searching for GitHub tool..."
  GITHUB_TOOL=$(echo "$TOOLS_RESPONSE" | jq -r '.result[] | select(.name | contains("GitHub") or contains("GithHub")) | .sys_id' | head -1)

  if [ -n "$GITHUB_TOOL" ]; then
    SN_ORCHESTRATION_TOOL_ID="$GITHUB_TOOL"
    echo -e "${GREEN}✓ Found GitHub tool: $SN_ORCHESTRATION_TOOL_ID${NC}"
  else
    echo -e "${RED}❌ GitHub tool not found${NC}"
    echo "Available tools:"
    echo "$TOOLS_RESPONSE" | jq -r '.result[] | "  - \(.name)"'
    exit 1
  fi
  echo ""
fi

# Step 4: Check if GitHub tool has change control config
echo "4️⃣  Checking change control configuration for GitHub tool..."
GITHUB_CONFIG=$(echo "$CONFIGS_RESPONSE" | jq -r --arg tool_id "$SN_ORCHESTRATION_TOOL_ID" '.result[] | select(.tool.value == $tool_id)')

if [ -z "$GITHUB_CONFIG" ] || [ "$GITHUB_CONFIG" = "null" ]; then
  echo -e "${RED}❌ No change control configuration found for GitHub tool${NC}"
  echo ""
  echo -e "${YELLOW}This is why the dashboard doesn't show GitHub data!${NC}"
  echo ""
  read -p "Create configuration now? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating change control configuration..."
    CREATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -X POST \
      -d '{
        "tool": "'"$SN_ORCHESTRATION_TOOL_ID"'",
        "change_control_enabled": "true",
        "create_change_request": "true",
        "change_type": "standard",
        "enable_version_control": "false"
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
else
  echo -e "${GREEN}✓ Configuration found:${NC}"
  echo "$GITHUB_CONFIG" | jq '{tool: .tool.display_value, enabled: .change_control_enabled, create_cr: .create_change_request, type: .change_type}'
fi
echo ""

# Step 5: Compare data volumes between tools
echo "5️⃣  Comparing data volumes..."

# GitHub change references
GITHUB_REFS=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=sys_id")

GITHUB_REF_COUNT=$(echo "$GITHUB_REFS" | jq -r '.result | length')

# GitLab change references (HelloWorkd4)
GITLAB_TOOL_ID=$(echo "$TOOLS_RESPONSE" | jq -r '.result[] | select(.name == "HelloWorkd4") | .sys_id')

if [ -n "$GITLAB_TOOL_ID" ]; then
  GITLAB_REFS=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=tool=$GITLAB_TOOL_ID&sysparm_fields=sys_id")

  GITLAB_REF_COUNT=$(echo "$GITLAB_REFS" | jq -r '.result | length')

  echo "  GitLab (HelloWorkd4): $GITLAB_REF_COUNT change references"
  echo "  GitHub (GithHubARC): $GITHUB_REF_COUNT change references"
  echo ""

  if [ "$GITHUB_REF_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No GitHub change references found${NC}"
    echo "  This means no deployments have run yet, or data isn't being sent"
  elif [ "$GITHUB_REF_COUNT" -lt "$GITLAB_REF_COUNT" ]; then
    echo -e "${YELLOW}⚠️  GitHub has fewer change references than GitLab${NC}"
    echo "  Run more deployments to build historical data"
  fi
else
  echo "  GitHub (GithHubARC): $GITHUB_REF_COUNT change references"
  echo "  GitLab (HelloWorkd4): Tool not found"
fi
echo ""

# Step 6: Check recent change references for GitHub
if [ "$GITHUB_REF_COUNT" -gt 0 ]; then
  echo "6️⃣  Recent GitHub change references..."
  curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID&sysparm_limit=5&sysparm_display_value=true&sysparm_fields=change_request,pipeline_name,sys_created_on" \
    | jq -r '.result[] | "  - CR: \(.change_request) | Pipeline: \(.pipeline_name) | Created: \(.sys_created_on)"'
  echo ""
fi

# Step 7: Summary and recommendations
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary & Recommendations${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -z "$GITHUB_CONFIG" ] || [ "$GITHUB_CONFIG" = "null" ]; then
  echo -e "${RED}Issue: GitHub tool not configured for Change Velocity${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run this script again and choose 'y' to create configuration"
  echo "  2. Run a deployment: gh workflow run MASTER-PIPELINE.yaml -f environment=dev"
  echo "  3. Wait 10 minutes for data to appear in dashboard"
  echo "  4. Refresh dashboard and select 'GithHubARC' tool filter"
elif [ "$GITHUB_REF_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}Issue: Configuration exists but no data yet${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Run a deployment: gh workflow run MASTER-PIPELINE.yaml -f environment=dev"
  echo "  2. Wait 10 minutes"
  echo "  3. Check dashboard: $SERVICENOW_INSTANCE_URL/now/devops-change/insights-home"
  echo "  4. Ensure tool filter is set to 'GithHubARC' or 'All tools'"
else
  echo -e "${GREEN}✓ Configuration exists and data is present${NC}"
  echo ""
  echo "GitHub change references: $GITHUB_REF_COUNT"
  echo ""
  echo "If dashboard still shows no data:"
  echo "  1. Check dashboard tool filter - ensure 'GithHubARC' is selected"
  echo "  2. Try different date ranges (last 7 days, 30 days, etc.)"
  echo "  3. Clear browser cache and reload dashboard"
  echo "  4. Check if change requests have proper state (not all in 'New' state)"
fi
echo ""

echo "Dashboard URL:"
echo "  $SERVICENOW_INSTANCE_URL/now/devops-change/insights-home"
echo ""
