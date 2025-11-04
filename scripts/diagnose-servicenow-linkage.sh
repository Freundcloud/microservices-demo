#!/bin/bash
set -e

# Diagnose ServiceNow Change Request Linkage Issues
# Investigates why App and Package fields are empty in change requests

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ServiceNow Change Request Linkage Diagnostic${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Load credentials
if [ -f .envrc ]; then
  source .envrc
fi

# Validate credentials
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${RED}❌ ERROR: ServiceNow credentials not set${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Credentials loaded${NC}"
echo "   Instance: $SERVICENOW_INSTANCE_URL"
echo ""

# Get the most recent change request
echo -e "${YELLOW}Step 1: Finding most recent change request...${NC}"
CR_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=short_descriptionLIKEDeploy%20microservices^ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_fields=sys_id,number,short_description,sys_created_on")

CR_SYS_ID=$(echo "$CR_RESPONSE" | jq -r '.result[0].sys_id')
CR_NUMBER=$(echo "$CR_RESPONSE" | jq -r '.result[0].number')
CR_DESC=$(echo "$CR_RESPONSE" | jq -r '.result[0].short_description')
CR_DATE=$(echo "$CR_RESPONSE" | jq -r '.result[0].sys_created_on')

if [ -z "$CR_SYS_ID" ] || [ "$CR_SYS_ID" = "null" ]; then
  echo -e "${RED}❌ No change requests found${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Found change request${NC}"
echo "   Number: $CR_NUMBER"
echo "   Description: $CR_DESC"
echo "   Created: $CR_DATE"
echo "   Sys ID: $CR_SYS_ID"
echo ""

# Check what fields are available on change_request table
echo -e "${YELLOW}Step 2: Checking change_request table schema...${NC}"

# Get all fields from the change request
FULL_CR=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYS_ID")

echo "$FULL_CR" | jq -r '.result | to_entries[] | select(.key | test("app|package|pipeline|artifact|tool")) | "\(.key): \(.value)"'

echo ""

# Check sn_devops_package table for packages
echo -e "${YELLOW}Step 3: Checking sn_devops_package table for packages...${NC}"
PKG_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=5&sysparm_fields=sys_id,name,version,artifact_name,sys_created_on,change_request")

PKG_COUNT=$(echo "$PKG_RESPONSE" | jq '.result | length')
echo -e "${GREEN}Found $PKG_COUNT packages${NC}"

if [ "$PKG_COUNT" -gt 0 ]; then
  echo ""
  echo "Recent packages:"
  echo "$PKG_RESPONSE" | jq -r '.result[] | "  • \(.name) v\(.version) (Created: \(.sys_created_on), CR: \(.change_request.value // "none"))"'
fi

echo ""

# Check sn_devops_change_reference table
echo -e "${YELLOW}Step 4: Checking sn_devops_change_reference table...${NC}"
REF_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_query=change_request=$CR_SYS_ID&sysparm_fields=sys_id,change_request,pipeline_name,run_id,sys_created_on")

REF_COUNT=$(echo "$REF_RESPONSE" | jq '.result | length')
echo -e "${GREEN}Found $REF_COUNT change references for CR $CR_NUMBER${NC}"

if [ "$REF_COUNT" -gt 0 ]; then
  echo ""
  echo "Change references:"
  echo "$REF_RESPONSE" | jq -r '.result[] | "  • Pipeline: \(.pipeline_name), Run: \(.run_id), Created: \(.sys_created_on)"'
fi

echo ""

# Check for pipeline execution table (might be sn_devops_pipeline_info or sn_devops_pipeline_execution)
echo -e "${YELLOW}Step 5: Checking for pipeline execution tables...${NC}"

# Try sn_devops_pipeline_info
PIPE_INFO_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_info?sysparm_limit=1")

PIPE_INFO_CODE=$(echo "$PIPE_INFO_TEST" | grep -oP 'HTTP_CODE:\K\d+')

if [ "$PIPE_INFO_CODE" = "200" ]; then
  echo -e "${GREEN}✅ sn_devops_pipeline_info exists${NC}"
  PIPE_COUNT=$(echo "$PIPE_INFO_TEST" | sed 's/HTTP_CODE:.*//' | jq '.result | length')
  echo "   Records: $PIPE_COUNT"
else
  echo -e "${RED}❌ sn_devops_pipeline_info not available${NC}"
fi

# Try sn_devops_pipeline_execution
PIPE_EXEC_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_execution?sysparm_limit=1")

PIPE_EXEC_CODE=$(echo "$PIPE_EXEC_TEST" | grep -oP 'HTTP_CODE:\K\d+')

if [ "$PIPE_EXEC_CODE" = "200" ]; then
  echo -e "${GREEN}✅ sn_devops_pipeline_execution exists${NC}"
  PIPE_EXEC_COUNT=$(echo "$PIPE_EXEC_TEST" | sed 's/HTTP_CODE:.*//' | jq '.result | length')
  echo "   Records: $PIPE_EXEC_COUNT"
else
  echo -e "${RED}❌ sn_devops_pipeline_execution not available${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Analysis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "🔍 **Issue**: Change request has empty App and Package fields"
echo ""
echo "**Findings**:"
echo "1. Packages registered: $PKG_COUNT"
echo "2. Change references: $REF_COUNT"
echo "3. Pipeline info table: $([ "$PIPE_INFO_CODE" = "200" ] && echo "Available" || echo "Not Available")"
echo "4. Pipeline execution table: $([ "$PIPE_EXEC_CODE" = "200" ] && echo "Available" || echo "Not Available")"
echo ""

if [ "$PKG_COUNT" -gt 0 ] && [ "$REF_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Problem: Packages exist but not linked to change request${NC}"
  echo ""
  echo "**Root Cause**: Packages are registered BEFORE change request is created"
  echo ""
  echo "**Solution Options**:"
  echo "1. Reorder jobs: Create change request before registering packages"
  echo "2. Link packages to change request after both exist (requires custom script)"
  echo "3. Use package registration that includes change_request field"
fi

if [ "$PKG_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Problem: No packages registered in sn_devops_package table${NC}"
  echo ""
  echo "**Check**: Verify register-packages job in MASTER-PIPELINE.yaml is running"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "🔗 View in ServiceNow:"
echo "   Change Request: $SERVICENOW_INSTANCE_URL/change_request.do?sys_id=$CR_SYS_ID"
echo "   Packages: $SERVICENOW_INSTANCE_URL/sn_devops_package_list.do"
echo "   Change References: $SERVICENOW_INSTANCE_URL/sn_devops_change_reference_list.do"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit 0
