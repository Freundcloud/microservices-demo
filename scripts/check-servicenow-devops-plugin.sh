#!/bin/bash
set -e

# Check ServiceNow DevOps Plugin Status
# Verifies if the DevOps plugin is activated and which tables are available

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   ServiceNow DevOps Plugin Status Check${NC}"
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

# List of DevOps tables to check
DEVOPS_TABLES=(
  "sn_devops_tool:DevOps Tool Registry"
  "sn_devops_package:Package/Artifact Registry"
  "sn_devops_pipeline_info:Pipeline Execution Tracking"
  "sn_devops_test_result:Test Results"
  "sn_devops_test_execution:Test Executions"
  "sn_devops_performance_test_summary:Performance/Smoke Tests"
  "sn_devops_security_result:Security Scan Results"
  "sn_devops_work_item:Work Items (GitHub Issues)"
)

echo -e "${YELLOW}Checking DevOps Tables:${NC}"
echo ""

AVAILABLE_COUNT=0
MISSING_COUNT=0
MISSING_TABLES=()

for table_entry in "${DEVOPS_TABLES[@]}"; do
  IFS=':' read -r table_name friendly_name <<< "$table_entry"

  printf "  %-40s" "$friendly_name ($table_name)"

  # Try to access the table
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/${table_name}?sysparm_limit=1")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

  if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Available${NC}"
    AVAILABLE_COUNT=$((AVAILABLE_COUNT + 1))
  else
    echo -e "${RED}❌ Not Available${NC}"
    MISSING_COUNT=$((MISSING_COUNT + 1))
    MISSING_TABLES+=("$table_name")
  fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Tables: ${BLUE}8${NC}"
echo -e "Available: ${GREEN}$AVAILABLE_COUNT${NC}"
echo -e "Missing: ${RED}$MISSING_COUNT${NC}"
echo ""

if [ $MISSING_COUNT -eq 0 ]; then
  echo -e "${GREEN}✅ All DevOps tables are available!${NC}"
  echo ""
  echo "Your ServiceNow DevOps plugin is fully activated."
else
  echo -e "${YELLOW}⚠️  Some DevOps tables are missing${NC}"
  echo ""
  echo "Missing tables:"
  for table in "${MISSING_TABLES[@]}"; do
    echo "  - $table"
  done
  echo ""
  echo -e "${YELLOW}To activate the ServiceNow DevOps plugin:${NC}"
  echo ""
  echo "1. Log into ServiceNow as administrator"
  echo "   ${SERVICENOW_INSTANCE_URL}"
  echo ""
  echo "2. Navigate to: System Applications > All Available Applications > All"
  echo "   ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sys_app.list"
  echo ""
  echo "3. Search for: 'DevOps' or 'sn_devops'"
  echo ""
  echo "4. Find the 'DevOps' application and click 'Activate/Upgrade'"
  echo ""
  echo "5. Wait for activation to complete (typically 5-10 minutes)"
  echo ""
  echo "6. Re-run this script to verify: ./scripts/check-servicenow-devops-plugin.sh"
  echo ""
  echo -e "${YELLOW}Alternative - Graceful Degradation:${NC}"
  echo ""
  echo "Our workflows are designed to gracefully handle missing DevOps tables:"
  echo "- Security results will be added to change request work notes"
  echo "- Test results workflow can be disabled if not needed"
  echo "- Work items and packages should work with basic DevOps activation"
  echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit 0
