#!/bin/bash
set -e

# Comprehensive ServiceNow DevOps Tables Verification Script
# Verifies all DevOps table integrations and data uploads

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ServiceNow DevOps Tables Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load credentials
if [ -f .envrc ]; then
  echo "Loading credentials from .envrc..."
  source .envrc
fi

# Validate credentials
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${RED}❌ ERROR: ServiceNow credentials not set${NC}"
  echo "Please set the following environment variables:"
  echo "  - SERVICENOW_INSTANCE_URL"
  echo "  - SERVICENOW_USERNAME"
  echo "  - SERVICENOW_PASSWORD"
  exit 1
fi

echo -e "${GREEN}✅ Credentials loaded${NC}"
echo "   Instance: $SERVICENOW_INSTANCE_URL"
echo ""

# Function to check table access and count records
check_table() {
  local table_name=$1
  local friendly_name=$2
  local query=${3:-""}

  echo -e "${YELLOW}Checking: $friendly_name (${table_name})${NC}"

  local url="${SERVICENOW_INSTANCE_URL}/api/now/table/${table_name}?sysparm_limit=1&sysparm_fields=sys_id,number"
  if [ -n "$query" ]; then
    url="${url}&sysparm_query=${query}"
  fi

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$url")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" == "200" ]; then
    COUNT=$(echo "$BODY" | jq -r '.result | length')
    if [ "$COUNT" -gt 0 ]; then
      RECORD_NUM=$(echo "$BODY" | jq -r '.result[0].number // "N/A"')
      echo -e "  ${GREEN}✅ Accessible - Sample record: $RECORD_NUM${NC}"
    else
      echo -e "  ${YELLOW}⚠️  Table accessible but no records found${NC}"
    fi

    # Get total count
    COUNT_URL="${SERVICENOW_INSTANCE_URL}/api/now/stats/${table_name}?sysparm_count=true"
    if [ -n "$query" ]; then
      COUNT_URL="${COUNT_URL}&sysparm_query=${query}"
    fi

    COUNT_RESPONSE=$(curl -s \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Accept: application/json" \
      "$COUNT_URL")

    TOTAL=$(echo "$COUNT_RESPONSE" | jq -r '.result.stats.count // "0"')
    echo -e "  ${BLUE}📊 Total records: $TOTAL${NC}"

    # View URL
    VIEW_URL="${SERVICENOW_INSTANCE_URL}/now/nav/ui/classic/params/target/${table_name}_list.do"
    if [ -n "$query" ]; then
      VIEW_URL="${VIEW_URL}?sysparm_query=${query}"
    fi
    echo -e "  ${BLUE}🔗 View: $VIEW_URL${NC}"
    return 0
  else
    echo -e "  ${RED}❌ Failed to access (HTTP $HTTP_CODE)${NC}"
    echo "$BODY" | jq -r '.error.message // .error.detail // "Unknown error"' 2>/dev/null || echo "$BODY"
    return 1
  fi
  echo ""
}

# Check tool registration
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}1. Tool Registration (sn_devops_tool)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

check_table "sn_devops_tool" "DevOps Tool Registry" "name=GitHub"

TOOL_ID=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool?sysparm_query=name=GitHub&sysparm_fields=sys_id" \
  | jq -r '.result[0].sys_id // ""')

if [ -n "$TOOL_ID" ]; then
  echo -e "${GREEN}✅ GitHub tool ID: $TOOL_ID${NC}"

  # Check if it matches secret
  if [ -n "$SN_ORCHESTRATION_TOOL_ID" ]; then
    if [ "$TOOL_ID" == "$SN_ORCHESTRATION_TOOL_ID" ]; then
      echo -e "${GREEN}✅ Tool ID matches SN_ORCHESTRATION_TOOL_ID secret${NC}"
    else
      echo -e "${YELLOW}⚠️  Tool ID mismatch!${NC}"
      echo "   Found: $TOOL_ID"
      echo "   Secret: $SN_ORCHESTRATION_TOOL_ID"
    fi
  fi
else
  echo -e "${RED}❌ GitHub tool not found!${NC}"
  echo "Run scripts/find-servicenow-tool-id.sh --create to create it"
fi
echo ""

# Check DevOps tables
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}2. DevOps Tables${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

check_table "sn_devops_package" "Package/Artifact Registry" "tool=$TOOL_ID"
echo ""

check_table "sn_devops_pipeline_info" "Pipeline Execution Tracking" "tool=$TOOL_ID"
echo ""

check_table "sn_devops_test_result" "Test Results" "tool=$TOOL_ID"
echo ""

check_table "sn_devops_test_execution" "Test Executions"
echo ""

check_table "sn_devops_performance_test_summary" "Performance/Smoke Tests" "tool=$TOOL_ID"
echo ""

check_table "sn_devops_security_result" "Security Scan Results" "tool=$TOOL_ID"
echo ""

check_table "sn_devops_work_item" "Work Items (GitHub Issues)" "tool=$TOOL_ID"
echo ""

# Check change requests with custom fields
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}3. Change Requests (Table API)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

check_table "change_request" "Change Requests" "u_source=GitHub%20Actions"
echo ""

# Check recent change request with custom fields
echo -e "${YELLOW}Checking latest GitHub Actions change request...${NC}"
CR_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request?sysparm_query=u_source=GitHub%20Actions^ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_fields=number,short_description,u_source,u_correlation_id,u_repository,u_branch,u_commit_sha,u_actor,u_environment")

CR_NUMBER=$(echo "$CR_RESPONSE" | jq -r '.result[0].number // "N/A"')

if [ "$CR_NUMBER" != "N/A" ]; then
  echo -e "${GREEN}✅ Latest change request: $CR_NUMBER${NC}"
  echo "$CR_RESPONSE" | jq -r '.result[0] | to_entries[] | "   \(.key): \(.value)"' | grep "^   u_"
else
  echo -e "${YELLOW}⚠️  No GitHub Actions change requests found${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Verification Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}Next Steps:${NC}"
echo "1. Trigger a deployment workflow to populate tables"
echo "2. Check work items by creating a commit with 'Fixes #123'"
echo "3. View all tables in ServiceNow:"
echo "   ${SERVICENOW_INSTANCE_URL}/now/nav/ui/classic/params/target/sys_db_object_list.do?sysparm_query=nameLIKEsn_devops"
echo ""

echo -e "${YELLOW}Useful Commands:${NC}"
echo "  # View specific table"
echo "  ./scripts/verify-servicenow-devops-tables.sh"
echo ""
echo "  # Create tool if missing"
echo "  ./scripts/find-servicenow-tool-id.sh --create"
echo ""

exit 0
