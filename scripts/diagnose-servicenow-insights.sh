#!/bin/bash
set -e

# Diagnose ServiceNow DevOps Insights Data Population
# This script checks what's missing for sn_devops_insights_st_summary population

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "🔍 ServiceNow DevOps Insights Diagnostic Tool"
echo "=============================================="
echo ""

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
)

# Validate required environment variables
missing_vars=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  echo -e "${RED}❌ ERROR: Missing required environment variables:${NC}"
  printf '  - %s\n' "${missing_vars[@]}"
  echo ""
  echo "Load credentials with:"
  echo "  source .envrc"
  exit 1
fi

echo -e "${GREEN}✓ Credentials loaded${NC}"
echo ""

# Configuration
APP_NAME="Online Boutique"
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"
TOOL_NAME="GithHubARC"
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"
REPO_NAME="Freundcloud/microservices-demo"
REPO_URL="https://github.com/Freundcloud/microservices-demo"

# Helper functions
function api_get() {
  curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$1"
}

function count_results() {
  echo "$1" | jq -r '.result | length'
}

function check_exists() {
  local count=$(count_results "$1")
  if [ "$count" -gt 0 ]; then
    echo -e "${GREEN}✅ EXISTS${NC} ($count record(s))"
    return 0
  else
    echo -e "${RED}❌ NOT FOUND${NC}"
    return 1
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 1: Checking Application${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 Application: $APP_NAME"
echo "   Sys ID: $APP_SYS_ID"
echo ""

APP_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_app/$APP_SYS_ID")
APP_EXISTS=$(echo "$APP_DATA" | jq -r '.result.sys_id // empty')

if [ -n "$APP_EXISTS" ]; then
  echo -e "${GREEN}✅ Application exists in ServiceNow${NC}"
  echo ""
  echo "Details:"
  echo "$APP_DATA" | jq '.result | {name, sys_id, tool: .tool.display_value}'

  # Check if tool is linked
  TOOL_LINKED=$(echo "$APP_DATA" | jq -r '.result.tool.value // empty')
  if [ -z "$TOOL_LINKED" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: No tool linked to application${NC}"
  fi
else
  echo -e "${RED}❌ Application NOT FOUND${NC}"
  echo ""
  echo "The application '$APP_NAME' doesn't exist in ServiceNow."
  echo "Create it at: $SERVICENOW_INSTANCE_URL/sn_devops_app_list.do"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 2: Checking GitHub Tool${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔧 Tool: $TOOL_NAME"
echo "   Sys ID: $TOOL_SYS_ID"
echo ""

TOOL_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$TOOL_SYS_ID")
TOOL_EXISTS=$(echo "$TOOL_DATA" | jq -r '.result.sys_id // empty')

if [ -n "$TOOL_EXISTS" ]; then
  echo -e "${GREEN}✅ Tool exists in ServiceNow${NC}"
  echo ""
  echo "Details:"
  echo "$TOOL_DATA" | jq '.result | {name, sys_id, type, url}'
else
  echo -e "${RED}❌ Tool NOT FOUND${NC}"
  echo ""
  echo "The GitHub tool '$TOOL_NAME' doesn't exist in ServiceNow."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 3: Checking Repository Linkage${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📁 Repository: $REPO_NAME"
echo ""

REPO_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=name=$REPO_NAME")
REPO_COUNT=$(count_results "$REPO_DATA")

if [ "$REPO_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Repository exists in ServiceNow${NC}"
  echo ""
  echo "Details:"
  echo "$REPO_DATA" | jq '.result[] | {name, application: .application.display_value, tool: .tool.display_value, active}'

  # Check if linked to application
  REPO_APP=$(echo "$REPO_DATA" | jq -r '.result[0].application.value // empty')
  if [ "$REPO_APP" = "$APP_SYS_ID" ]; then
    echo ""
    echo -e "${GREEN}✅ Repository is linked to '$APP_NAME'${NC}"
  else
    echo ""
    echo -e "${RED}❌ CRITICAL: Repository is NOT linked to '$APP_NAME'${NC}"
    if [ -n "$REPO_APP" ]; then
      LINKED_APP_NAME=$(echo "$REPO_DATA" | jq -r '.result[0].application.display_value')
      echo "   Currently linked to: $LINKED_APP_NAME"
    else
      echo "   Not linked to any application"
    fi
    echo ""
    echo -e "${YELLOW}🔧 FIX REQUIRED: Update repository to link to '$APP_NAME'${NC}"
  fi
else
  echo -e "${RED}❌ CRITICAL: Repository NOT FOUND in ServiceNow${NC}"
  echo ""
  echo "This is the ROOT CAUSE of missing insights data!"
  echo ""
  echo -e "${YELLOW}🔧 FIX REQUIRED: Create repository record${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 4: Checking Data in DevOps Tables${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check pipeline executions
echo -n "🔄 Pipeline Executions: "
PIPELINE_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_info?sysparm_query=application=$APP_SYS_ID&sysparm_limit=1")
check_exists "$PIPELINE_DATA"

# Check test results
echo -n "🧪 Test Results: "
TEST_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result?sysparm_query=application=$APP_SYS_ID&sysparm_limit=1")
check_exists "$TEST_DATA"

# Check packages
echo -n "📦 Packages: "
PACKAGE_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=application=$APP_SYS_ID&sysparm_limit=1")
check_exists "$PACKAGE_DATA"

# Check commits
echo -n "💾 Commits: "
COMMIT_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_commit?sysparm_query=application=$APP_SYS_ID&sysparm_limit=1")
check_exists "$COMMIT_DATA"

# Check work items
echo -n "📋 Work Items: "
WORKITEM_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item?sysparm_query=application=$APP_SYS_ID&sysparm_limit=1")
check_exists "$WORKITEM_DATA"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 5: Checking Insights Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -n "📊 Insights Summary: "
INSIGHTS_DATA=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=$APP_SYS_ID")
INSIGHTS_COUNT=$(count_results "$INSIGHTS_DATA")

if [ "$INSIGHTS_COUNT" -gt 0 ]; then
  echo ""
  echo ""
  echo "Summary data:"
  echo "$INSIGHTS_DATA" | jq '.result[] | {
    application: .application.display_value,
    pipeline_executions,
    tests,
    commits,
    pass_percentage
  }'
else
  echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Step 6: Checking Scheduled Jobs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check daily collection job
DAILY_JOB=$(api_get "$SERVICENOW_INSTANCE_URL/api/now/table/sysauto_script?sysparm_query=name=*DevOps*Daily*")
DAILY_COUNT=$(count_results "$DAILY_JOB")

if [ "$DAILY_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Found DevOps scheduled jobs${NC}"
  echo ""
  echo "Jobs:"
  echo "$DAILY_JOB" | jq -r '.result[] | "  - \(.name) (Active: \(.active))"'
else
  echo -e "${YELLOW}⚠️  DevOps scheduled jobs not found${NC}"
  echo "   Jobs may be named differently or not accessible via API"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Diagnosis Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine the issue
ISSUES_FOUND=0

if [ "$REPO_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ ISSUE 1: Repository not created in ServiceNow${NC}"
  echo "   Impact: Data cannot be linked to application"
  echo "   Priority: CRITICAL"
  echo ""
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
elif [ "$REPO_APP" != "$APP_SYS_ID" ]; then
  echo -e "${RED}❌ ISSUE 2: Repository not linked to application${NC}"
  echo "   Impact: Data is orphaned, not associated with '$APP_NAME'"
  echo "   Priority: CRITICAL"
  echo ""
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

PIPELINE_COUNT=$(count_results "$PIPELINE_DATA")
TEST_COUNT=$(count_results "$TEST_DATA")
PACKAGE_COUNT=$(count_results "$PACKAGE_DATA")

if [ "$PIPELINE_COUNT" -eq 0 ] && [ "$TEST_COUNT" -eq 0 ] && [ "$PACKAGE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  ISSUE 3: No data uploaded yet${NC}"
  echo "   Impact: Even if repository is linked, no data to aggregate"
  echo "   Priority: MEDIUM"
  echo "   Action: Trigger GitHub Actions workflow"
  echo ""
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ "$INSIGHTS_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  ISSUE 4: Insights summary empty${NC}"
  echo "   Impact: Dashboard has no data"
  echo "   Priority: HIGH"
  echo ""
  if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo "   Possible causes:"
    echo "   - Scheduled jobs haven't run yet"
    echo "   - Data is too recent (jobs run daily/hourly)"
    echo "   - Platform Analytics configuration issue"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Recommended Solutions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$REPO_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}📝 Solution 1: Create Repository Record${NC}"
  echo ""
  echo "Option A - Manual (Recommended):"
  echo "  1. Navigate to: $SERVICENOW_INSTANCE_URL/sn_devops_repository_list.do"
  echo "  2. Click 'New'"
  echo "  3. Fill in:"
  echo "     - Name: $REPO_NAME"
  echo "     - URL: $REPO_URL"
  echo "     - Tool: $TOOL_NAME"
  echo "     - Application: $APP_NAME"
  echo "     - Active: true"
  echo "  4. Click 'Submit'"
  echo ""
  echo "Option B - Programmatic (if UI access restricted):"
  echo "  Run: ./scripts/create-servicenow-repository.sh"
  echo ""
  echo "  Or use curl:"
  echo "  curl -X POST \\"
  echo "    -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    -H \"Content-Type: application/json\" \\"
  echo "    -d '{"
  echo "      \"name\": \"$REPO_NAME\","
  echo "      \"url\": \"$REPO_URL\","
  echo "      \"tool\": \"$TOOL_SYS_ID\","
  echo "      \"application\": \"$APP_SYS_ID\","
  echo "      \"active\": true"
  echo "    }' \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository\""
  echo ""
elif [ "$REPO_APP" != "$APP_SYS_ID" ]; then
  REPO_SYS_ID=$(echo "$REPO_DATA" | jq -r '.result[0].sys_id')
  echo -e "${YELLOW}📝 Solution 1: Update Repository Linkage${NC}"
  echo ""
  echo "Option A - Manual:"
  echo "  1. Navigate to: $SERVICENOW_INSTANCE_URL/sn_devops_repository.do?sys_id=$REPO_SYS_ID"
  echo "  2. Change 'Application' field to: $APP_NAME"
  echo "  3. Click 'Update'"
  echo ""
  echo "Option B - Programmatic:"
  echo "  curl -X PATCH \\"
  echo "    -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
  echo "    -H \"Content-Type: application/json\" \\"
  echo "    -d '{\"application\": \"$APP_SYS_ID\"}' \\"
  echo "    \"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID\""
  echo ""
fi

if [ "$PIPELINE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}📝 Solution 2: Trigger GitHub Actions Workflow${NC}"
  echo ""
  echo "After creating/updating repository, trigger a workflow run:"
  echo ""
  echo "  gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev"
  echo ""
  echo "This will upload fresh data to ServiceNow."
  echo ""
fi

if [ "$INSIGHTS_COUNT" -eq 0 ] && [ "$ISSUES_FOUND" -eq 0 ]; then
  echo -e "${YELLOW}📝 Solution 3: Trigger Scheduled Jobs${NC}"
  echo ""
  echo "The scheduled jobs may need to be triggered manually:"
  echo ""
  echo "  1. Navigate to: $SERVICENOW_INSTANCE_URL/sys_trigger_list.do"
  echo "  2. Search for: 'DevOps Daily Data Collection'"
  echo "  3. Click 'Execute Now'"
  echo ""
  echo "Or wait for the next scheduled run (check job schedule in ServiceNow)."
  echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Next Steps${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1. ${YELLOW}Implement the recommended solutions above${NC}"
echo ""
if [ "$REPO_COUNT" -eq 0 ] || [ "$REPO_APP" != "$APP_SYS_ID" ]; then
  echo "2. ${YELLOW}Run this diagnostic script again to verify the fix${NC}"
  echo "     ./scripts/diagnose-servicenow-insights.sh"
  echo ""
  echo "3. ${YELLOW}Trigger a GitHub Actions workflow${NC}"
  echo "     gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev"
  echo ""
  echo "4. ${YELLOW}Wait 10-15 minutes for scheduled jobs to run${NC}"
  echo ""
  echo "5. ${YELLOW}Check the Insights Dashboard${NC}"
  echo "     $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
  echo ""
else
  echo "2. ${YELLOW}Wait 10-15 minutes for scheduled jobs to process new data${NC}"
  echo ""
  echo "3. ${YELLOW}Check the Insights Dashboard${NC}"
  echo "     $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
  echo ""
  echo "4. ${YELLOW}If still empty, manually trigger scheduled job${NC}"
  echo "     Navigate to: $SERVICENOW_INSTANCE_URL/sys_trigger_list.do"
  echo "     Search: 'DevOps Daily Data Collection'"
  echo "     Click: 'Execute Now'"
  echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 For more information, see:"
echo "   docs/SERVICENOW-INSIGHTS-MISSING-APPLICATION-DATA.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ISSUES_FOUND" -gt 0 ]; then
  exit 1
else
  exit 0
fi
