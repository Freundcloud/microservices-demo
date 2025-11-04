#!/bin/bash
set -e

# Discover ServiceNow DevOps tables and their purposes
# This helps understand which tables are used for configuration vs data

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "ServiceNow DevOps Tables Discovery"
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

# List of DevOps-related tables to check
TABLES=(
  "sn_devops_change_reference"
  "sn_devops_change_control_config"
  "sn_devops_callback"
  "sn_devops_tool"
  "sn_devops_test_result"
  "sn_devops_test_summary"
  "sn_devops_security_result"
  "sn_devops_work_item"
  "sn_devops_artifact"
  "change_request"
)

echo "🔍 Checking which DevOps tables exist in your instance..."
echo ""

for TABLE in "${TABLES[@]}"; do
  echo -n "Checking $TABLE... "

  # Try to query the table (limit 1 to keep it fast)
  RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/$TABLE?sysparm_limit=1" \
    2>/dev/null || echo '{"error":{"message":"failed"}}')

  # Check for errors
  ERROR=$(echo "$RESPONSE" | jq -r '.error.message // ""')

  if [ -n "$ERROR" ]; then
    echo -e "${RED}❌ NOT FOUND${NC}"
    echo "   Error: $ERROR"
  else
    # Table exists - get record count
    COUNT=$(echo "$RESPONSE" | jq -r '.result | length')
    echo -e "${GREEN}✅ EXISTS${NC} ($COUNT records shown, may have more)"

    # Show sample record structure if available
    if [ "$COUNT" -gt 0 ]; then
      echo "   Sample fields:"
      echo "$RESPONSE" | jq -r '.result[0] | keys[]' | head -10 | sed 's/^/      - /'
    fi
  fi
  echo ""
done

echo "=========================================="
echo "📋 Table Purposes (Based on Naming)"
echo "=========================================="
echo ""

echo -e "${BLUE}Configuration Tables:${NC}"
echo "  • sn_devops_change_control_config"
echo "    Purpose: Stores configuration for which tools/pipelines require change control"
echo "    Used for: Enabling/disabling changeControl: true/false behavior"
echo ""

echo -e "${BLUE}Data/Reference Tables:${NC}"
echo "  • sn_devops_change_reference"
echo "    Purpose: Links DevOps pipeline runs to change requests"
echo "    Used for: Tracking which deployment created which CR"
echo ""
echo "  • sn_devops_callback"
echo "    Purpose: Stores callback/orchestration data from DevOps tools"
echo "    Used for: Deployment gate workflows, status tracking"
echo ""
echo "  • sn_devops_tool"
echo "    Purpose: Registered CI/CD tools (Jenkins, GitHub Actions, Azure DevOps)"
echo "    Used for: Tool authentication and identification"
echo ""

echo -e "${BLUE}Results/Evidence Tables:${NC}"
echo "  • sn_devops_test_result"
echo "    Purpose: Individual test execution results"
echo "    Used for: Linking test data to change requests"
echo ""
echo "  • sn_devops_test_summary"
echo "    Purpose: Aggregated test results summary"
echo "    Used for: High-level test metrics"
echo ""
echo "  • sn_devops_security_result"
echo "    Purpose: Security scan results"
echo "    Used for: Vulnerability tracking and compliance"
echo ""
echo "  • sn_devops_work_item"
echo "    Purpose: Links to work items (GitHub Issues, Jira tickets)"
echo "    Used for: Traceability from requirements to deployment"
echo ""
echo "  • sn_devops_artifact"
echo "    Purpose: Deployed artifacts (containers, packages)"
echo "    Used for: Artifact versioning and tracking"
echo ""

echo "=========================================="
echo "🔑 Key Findings"
echo "=========================================="
echo ""

# Check if sn_devops_change_reference exists
REF_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=1" \
  2>/dev/null || echo '{"error":{"message":"failed"}}')

REF_ERROR=$(echo "$REF_RESPONSE" | jq -r '.error.message // ""')

# Check if sn_devops_change_control_config exists
CONFIG_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config?sysparm_limit=1" \
  2>/dev/null || echo '{"error":{"message":"failed"}}')

CONFIG_ERROR=$(echo "$CONFIG_RESPONSE" | jq -r '.error.message // ""')

if [ -z "$REF_ERROR" ] && [ -n "$CONFIG_ERROR" ]; then
  echo -e "${YELLOW}⚠️  IMPORTANT DISCOVERY:${NC}"
  echo ""
  echo "  • sn_devops_change_reference EXISTS ✅"
  echo "  • sn_devops_change_control_config DOES NOT EXIST ❌"
  echo ""
  echo -e "${YELLOW}This suggests:${NC}"
  echo "  1. Your instance HAS DevOps Change Velocity plugin installed"
  echo "  2. But the CONFIGURATION table may be named differently"
  echo "  3. Configuration might be done through a different interface"
  echo ""
  echo -e "${GREEN}Recommendations:${NC}"
  echo "  1. Check ServiceNow UI: DevOps → Change Velocity"
  echo "  2. Look for 'Project Configuration' or 'Pipeline Configuration'"
  echo "  3. Configuration might be stored in sn_devops_tool table instead"
  echo "  4. Or use Table API which doesn't need this configuration"
elif [ -n "$REF_ERROR" ] && [ -n "$CONFIG_ERROR" ]; then
  echo -e "${RED}⚠️  IMPORTANT DISCOVERY:${NC}"
  echo ""
  echo "  • sn_devops_change_reference DOES NOT EXIST ❌"
  echo "  • sn_devops_change_control_config DOES NOT EXIST ❌"
  echo ""
  echo -e "${RED}This suggests:${NC}"
  echo "  1. DevOps Change Velocity plugin is NOT installed, or"
  echo "  2. Your ServiceNow edition doesn't support these features, or"
  echo "  3. Plugin is installed but tables have different names"
  echo ""
  echo -e "${GREEN}Recommendations:${NC}"
  echo "  1. Install DevOps Change Velocity plugin from ServiceNow Store"
  echo "  2. Or stick with Table API (always works, no plugin needed)"
  echo "  3. Table API supports 40+ custom fields for compliance"
elif [ -z "$REF_ERROR" ] && [ -z "$CONFIG_ERROR" ]; then
  echo -e "${GREEN}✅ FULL DevOps CHANGE VELOCITY SUPPORT:${NC}"
  echo ""
  echo "  • sn_devops_change_reference EXISTS ✅"
  echo "  • sn_devops_change_control_config EXISTS ✅"
  echo ""
  echo -e "${GREEN}This means:${NC}"
  echo "  1. You can configure changeControl: true/false behavior"
  echo "  2. Navigate to configuration via methods in documentation"
  echo "  3. Both DevOps API and Table API are available"
else
  echo -e "${YELLOW}⚠️  PARTIAL SUPPORT:${NC}"
  echo ""
  echo "  • sn_devops_change_reference: $([ -z "$REF_ERROR" ] && echo '✅ EXISTS' || echo '❌ NOT FOUND')"
  echo "  • sn_devops_change_control_config: $([ -z "$CONFIG_ERROR" ] && echo '✅ EXISTS' || echo '❌ NOT FOUND')"
fi

echo ""
echo "=========================================="
echo "📖 For More Information"
echo "=========================================="
echo ""
echo "  • API Comparison: docs/SERVICENOW-API-COMPARISON.md"
echo "  • DevOps API Testing: docs/SERVICENOW-DEVOPS-API-TESTING.md"
echo "  • Enable Traditional CRs: docs/SERVICENOW-ENABLE-TRADITIONAL-CRS.md"
echo ""
