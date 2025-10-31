#!/bin/bash
# Script to check ServiceNow table population for DevOps integration
# Usage: ./scripts/check-servicenow-tables.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .envrc ]; then
    source .envrc
else
    echo -e "${RED}❌ .envrc file not found${NC}"
    echo "Please create .envrc with ServiceNow credentials"
    exit 1
fi

# Check required environment variables
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
    echo -e "${RED}❌ Missing required environment variables${NC}"
    echo "Required: SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ServiceNow DevOps Integration Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Instance: $SERVICENOW_INSTANCE_URL"
echo "Username: $SERVICENOW_USERNAME"
echo ""

# Function to check table and display count
check_table() {
    local table_name=$1
    local table_description=$2
    local query=$3

    echo -e "${YELLOW}Checking: ${table_description}${NC}"

    if [ -z "$query" ]; then
        RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
            "$SERVICENOW_INSTANCE_URL/api/now/table/$table_name?sysparm_limit=10&sysparm_fields=sys_id,sys_created_on")
    else
        RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
            "$SERVICENOW_INSTANCE_URL/api/now/table/$table_name?sysparm_query=$query&sysparm_limit=10&sysparm_fields=sys_id,sys_created_on")
    fi

    # Check for error
    if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message')
        echo -e "${RED}  ❌ Error: $ERROR_MSG${NC}"
        return 1
    fi

    # Count records
    COUNT=$(echo "$RESPONSE" | jq '.result | length')

    if [ "$COUNT" -gt 0 ]; then
        echo -e "${GREEN}  ✅ Found $COUNT records${NC}"

        # Show most recent record
        LATEST=$(echo "$RESPONSE" | jq -r '.result[0].sys_created_on // "N/A"')
        echo -e "     Latest: $LATEST"

        # Show URL to view records
        if [ -z "$query" ]; then
            echo -e "     View: $SERVICENOW_INSTANCE_URL/${table_name}_list.do"
        else
            ENCODED_QUERY=$(echo "$query" | jq -sRr @uri)
            echo -e "     View: $SERVICENOW_INSTANCE_URL/${table_name}_list.do?sysparm_query=$ENCODED_QUERY"
        fi
    else
        echo -e "${RED}  ❌ No records found${NC}"
        echo -e "     View: $SERVICENOW_INSTANCE_URL/${table_name}_list.do"
    fi
    echo ""
}

# Check standard change_request table (should have data if using REST API)
echo -e "${BLUE}1. Standard ITSM Tables${NC}"
echo -e "${BLUE}========================${NC}"
echo ""
check_table "change_request" "Change Requests (from GitHub Actions)" "u_source=GitHub Actions"
check_table "change_request" "All Change Requests (last 10)" ""

# Check ServiceNow DevOps tables
echo -e "${BLUE}2. ServiceNow DevOps Tables${NC}"
echo -e "${BLUE}============================${NC}"
echo ""
check_table "sn_devops_change_reference" "DevOps Change References" ""
check_table "sn_devops_test_summary" "DevOps Test Summaries" ""
check_table "sn_devops_test_result" "DevOps Test Results" ""
check_table "sn_devops_work_item" "DevOps Work Items" ""
check_table "sn_devops_artifact" "DevOps Artifacts/Packages" ""
check_table "sn_devops_security_result" "DevOps Security Results" ""

# Check if DevOps plugin is installed
echo -e "${BLUE}3. ServiceNow DevOps Plugin Status${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo -e "${YELLOW}Checking plugin installation...${NC}"

PLUGIN_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=source=com.snc.devops&sysparm_fields=name,active,version")

if echo "$PLUGIN_RESPONSE" | jq -e '.result | length > 0' > /dev/null 2>&1; then
    PLUGIN_NAME=$(echo "$PLUGIN_RESPONSE" | jq -r '.result[0].name')
    PLUGIN_ACTIVE=$(echo "$PLUGIN_RESPONSE" | jq -r '.result[0].active')
    PLUGIN_VERSION=$(echo "$PLUGIN_RESPONSE" | jq -r '.result[0].version')

    if [ "$PLUGIN_ACTIVE" = "true" ]; then
        echo -e "${GREEN}  ✅ ServiceNow DevOps plugin installed and active${NC}"
        echo -e "     Name: $PLUGIN_NAME"
        echo -e "     Version: $PLUGIN_VERSION"
    else
        echo -e "${YELLOW}  ⚠️  ServiceNow DevOps plugin installed but NOT active${NC}"
        echo -e "     Name: $PLUGIN_NAME"
        echo -e "     Version: $PLUGIN_VERSION"
    fi
else
    echo -e "${RED}  ❌ ServiceNow DevOps plugin NOT installed${NC}"
    echo -e "     This explains why DevOps tables are empty"
    echo -e "     Install: System Applications → All → Search 'DevOps'"
fi
echo ""

# Check tool registration
echo -e "${BLUE}4. Tool Registration Status${NC}"
echo -e "${BLUE}===========================${NC}"
echo ""

if [ -n "$SN_ORCHESTRATION_TOOL_ID" ]; then
    echo -e "${YELLOW}Checking tool registration (ID: $SN_ORCHESTRATION_TOOL_ID)...${NC}"

    TOOL_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=sys_id=$SN_ORCHESTRATION_TOOL_ID")

    if echo "$TOOL_RESPONSE" | jq -e '.result | length > 0' > /dev/null 2>&1; then
        TOOL_NAME=$(echo "$TOOL_RESPONSE" | jq -r '.result[0].name // "N/A"')
        TOOL_TYPE=$(echo "$TOOL_RESPONSE" | jq -r '.result[0].type // "N/A"')
        echo -e "${GREEN}  ✅ Tool registered in ServiceNow${NC}"
        echo -e "     Name: $TOOL_NAME"
        echo -e "     Type: $TOOL_TYPE"
    else
        echo -e "${RED}  ❌ Tool ID not found in ServiceNow${NC}"
        echo -e "     This may cause DevOps actions to fail"
        echo -e "     Register tool: DevOps → Orchestration → Tool Configuration"
    fi
else
    echo -e "${YELLOW}  ⚠️  SN_ORCHESTRATION_TOOL_ID not set in environment${NC}"
    echo -e "     Set in GitHub Secrets: SN_ORCHESTRATION_TOOL_ID"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Count tables with data
STANDARD_CR=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=u_source=GitHub Actions&sysparm_limit=1" \
    | jq '.result | length')

DEVOPS_CHANGES=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=1" \
    | jq '.result | length')

DEVOPS_TESTS=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary?sysparm_limit=1" \
    | jq '.result | length')

echo "Data Status:"
if [ "$STANDARD_CR" -gt 0 ]; then
    echo -e "${GREEN}  ✅ Standard Change Requests: Present${NC}"
else
    echo -e "${RED}  ❌ Standard Change Requests: Empty${NC}"
fi

if [ "$DEVOPS_CHANGES" -gt 0 ]; then
    echo -e "${GREEN}  ✅ DevOps Change References: Present${NC}"
else
    echo -e "${RED}  ❌ DevOps Change References: Empty${NC}"
fi

if [ "$DEVOPS_TESTS" -gt 0 ]; then
    echo -e "${GREEN}  ✅ DevOps Test Results: Present${NC}"
else
    echo -e "${RED}  ❌ DevOps Test Results: Empty${NC}"
fi

echo ""

# Recommendations
echo -e "${BLUE}Recommendations:${NC}"
if [ "$STANDARD_CR" -gt 0 ] && [ "$DEVOPS_CHANGES" -eq 0 ]; then
    echo -e "${YELLOW}  ⚠️  You are using REST API approach (standard change_request table)${NC}"
    echo -e "     - Change requests are being created successfully"
    echo -e "     - But NOT appearing in DevOps tables"
    echo -e "     - This is expected behavior for REST API integration"
    echo ""
    echo -e "     To populate DevOps tables, you need to:"
    echo -e "     1. Use ServiceNow DevOps GitHub Actions instead of REST API"
    echo -e "     2. Or accept current behavior (REST API is valid approach)"
elif [ "$STANDARD_CR" -eq 0 ] && [ "$DEVOPS_CHANGES" -eq 0 ]; then
    echo -e "${RED}  ❌ No change requests found in ANY table${NC}"
    echo -e "     - Check if workflows are running"
    echo -e "     - Check if ServiceNow jobs are being skipped"
    echo -e "     - Verify GitHub Actions workflow conditions"
    echo -e "     - Run: gh run list --repo <repo> --limit 5"
elif [ "$DEVOPS_CHANGES" -gt 0 ]; then
    echo -e "${GREEN}  ✅ DevOps integration working correctly!${NC}"
    echo -e "     - Change requests in DevOps tables"
    echo -e "     - Using ServiceNow DevOps actions"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo "Check complete!"
