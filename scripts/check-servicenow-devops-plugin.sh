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

# Comprehensive list of DevOps tables
# Based on actual availability in calitiiltddemo3.service-now.com
DEVOPS_TABLES=(
  "sn_devops_tool:Tool Registry"
  "sn_devops_package:Package/Artifact Registry"
  "sn_devops_test_result:Test Results"
  "sn_devops_test_execution:Test Executions"
  "sn_devops_performance_test_summary:Performance/Smoke Tests"
  "sn_devops_work_item:Work Items (GitHub Issues)"
  "sn_devops_artifact:Artifact Metadata"
  "sn_devops_change_reference:Change Request Linkages"
  "sn_devops_commit:Git Commit Tracking"
  "sn_devops_pull_request:Pull Request Tracking"
  "sn_devops_pipeline_info:Pipeline Info (legacy)"
  "sn_devops_pipeline_execution:Pipeline Execution Tracking"
  "sn_devops_security_result:Security Scan Results"
  "sn_devops_change:DevOps Change Records"
  "sn_devops_deployment:Deployment Tracking"
  "sn_devops_sonar_result:SonarQube Results"
  "sn_devops_sonar_scan:SonarQube Scan Metadata"
  "sn_devops_quality_result:Code Quality Results"
  "sn_devops_build:Build Execution Tracking"
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
TOTAL_TABLES=${#DEVOPS_TABLES[@]}
echo -e "Total Tables Checked: ${BLUE}$TOTAL_TABLES${NC}"
echo -e "Available: ${GREEN}$AVAILABLE_COUNT${NC}"
echo -e "Missing: ${RED}$MISSING_COUNT${NC}"
echo ""

if [ $MISSING_COUNT -eq 0 ]; then
  echo -e "${GREEN}✅ ALL DevOps tables are available!${NC}"
  echo ""
  echo "Your ServiceNow DevOps plugin is fully activated and all tables are accessible."
  echo ""
  echo "Available Tables:"
  for table in "${AVAILABLE_TABLES[@]}"; do
    echo -e "  ${GREEN}✅${NC} $table"
  done
else
  echo -e "${GREEN}✅ Available Tables ($AVAILABLE_COUNT):${NC}"
  for table in "${AVAILABLE_TABLES[@]}"; do
    echo "  - $table"
  done
  echo ""
  echo -e "${YELLOW}⚠️  Missing Tables ($MISSING_COUNT):${NC}"
  for table in "${MISSING_TABLES[@]}"; do
    echo "  - $table"
  done
  echo ""

  # Check if critical tables are available
  CRITICAL_AVAILABLE=0
  for table in "${AVAILABLE_TABLES[@]}"; do
    case "$table" in
      "sn_devops_tool"|"sn_devops_package"|"sn_devops_test_result"|"sn_devops_work_item")
        CRITICAL_AVAILABLE=$((CRITICAL_AVAILABLE + 1))
        ;;
    esac
  done

  if [ $CRITICAL_AVAILABLE -ge 4 ]; then
    echo -e "${GREEN}✅ Core integration tables are available${NC}"
    echo ""
    echo "Your workflows will function correctly. Missing tables are optional:"
    echo ""
    echo "Workarounds for missing tables:"
    echo "  • sn_devops_security_result → Security data in change request work notes"
    echo "  • sn_devops_sonar_result → SonarCloud data in custom fields"
    echo "  • sn_devops_pipeline_info → Use sn_devops_change_reference"
    echo "  • sn_devops_deployment → Track via sn_devops_package"
    echo ""
    echo "See docs/SERVICENOW-DEVOPS-TABLES-REFERENCE.md for complete details"
  else
    echo -e "${RED}⚠️  Critical tables are missing${NC}"
    echo ""
    echo "Please contact your ServiceNow administrator to:"
    echo "1. Verify DevOps plugin is fully activated"
    echo "2. Check plugin version and update if needed"
    echo "3. Review table permissions"
  fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📚 Complete table reference: docs/SERVICENOW-DEVOPS-TABLES-REFERENCE.md"
echo "🔍 View tables in ServiceNow: ${SERVICENOW_INSTANCE_URL}/sys_db_object_list.do?sysparm_query=nameLIKEsn_devops"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit 0
