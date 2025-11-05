#!/bin/bash
set -e

echo "🔍 Checking DevOps Insights Data for Online Boutique"
echo "====================================================="
echo ""

# Required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: ServiceNow credentials not set"
  exit 1
fi

APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"
APP_NAME="Online Boutique"

echo "Application: $APP_NAME"
echo "Sys ID: $APP_SYS_ID"
echo ""

# Helper function
check_table() {
  local table=$1
  local label=$2
  echo -n "📊 $label: "

  RESULT=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/$table?sysparm_query=app=$APP_SYS_ID&sysparm_limit=5")

  COUNT=$(echo "$RESULT" | jq -r '.result | length')

  if [ "$COUNT" -gt 0 ]; then
    echo "✅ $COUNT record(s) found"
    return 0
  else
    echo "❌ No data found"
    return 1
  fi
}

# Check repository linkage
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Repository Linkage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REPO_DATA=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=app=$APP_SYS_ID")

REPO_COUNT=$(echo "$REPO_DATA" | jq -r '.result | length')

if [ "$REPO_COUNT" -gt 0 ]; then
  echo "✅ Repository linked to application"
  echo ""
  echo "Details:"
  echo "$REPO_DATA" | jq '.result[] | {
    name,
    repository_url,
    total_commits,
    total_merges,
    avg_no_committers
  }'
else
  echo "❌ No repository linked (this is the problem!)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Checking DevOps Data Tables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check each table
check_table "sn_devops_pipeline_execution" "Pipeline Executions" && PIPELINES_FOUND=1 || PIPELINES_FOUND=0
check_table "sn_devops_test_result" "Test Results" && TESTS_FOUND=1 || TESTS_FOUND=0
check_table "sn_devops_package" "Packages" && PACKAGES_FOUND=1 || PACKAGES_FOUND=0
check_table "sn_devops_commit" "Commits" && COMMITS_FOUND=1 || COMMITS_FOUND=0
check_table "sn_devops_work_item" "Work Items" && WORKITEMS_FOUND=1 || WORKITEMS_FOUND=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Checking Insights Summary Table"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

INSIGHTS_DATA=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=$APP_SYS_ID")

INSIGHTS_COUNT=$(echo "$INSIGHTS_DATA" | jq -r '.result | length')

if [ "$INSIGHTS_COUNT" -gt 0 ]; then
  echo "✅ Insights summary exists!"
  echo ""
  echo "Summary data:"
  echo "$INSIGHTS_DATA" | jq '.result[] | {
    application: .application.display_value,
    pipeline_executions,
    tests,
    commits,
    pass_percentage,
    sys_created_on
  }'
else
  echo "❌ Insights summary is EMPTY"
  echo ""
  echo "This means the scheduled jobs haven't run yet or there's no data to aggregate."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnosis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$REPO_COUNT" -eq 0 ]; then
  echo "❌ CRITICAL: Repository not linked to application"
  echo "   Run: ./scripts/link-repository-to-application.sh"
  echo ""
elif [ "$PIPELINES_FOUND" -eq 0 ] && [ "$TESTS_FOUND" -eq 0 ] && [ "$PACKAGES_FOUND" -eq 0 ]; then
  echo "⚠️  WARNING: No DevOps data found for this application"
  echo ""
  echo "Possible causes:"
  echo "1. GitHub Actions workflows haven't run yet"
  echo "2. Data is being uploaded but not linked to the application"
  echo "3. Tool ID in workflows doesn't match the repository's tool"
  echo ""
  echo "Next steps:"
  echo "1. Trigger a workflow: gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev"
  echo "2. Check workflow logs to verify data upload"
  echo "3. Verify SN_ORCHESTRATION_TOOL_ID matches: $TOOL_SYS_ID"
  echo ""
elif [ "$INSIGHTS_COUNT" -eq 0 ]; then
  echo "✅ Repository is linked"
  echo "✅ DevOps data exists"
  echo "⚠️  Insights summary is empty"
  echo ""
  echo "This is expected behavior. The insights summary is populated by scheduled jobs:"
  echo "  - [DevOps] Daily Data Collection"
  echo "  - [DevOps] Historical Data Collection"
  echo ""
  echo "These jobs aggregate data from the DevOps tables into sn_devops_insights_st_summary."
  echo ""
  echo "Next steps:"
  echo "1. Wait for the scheduled jobs to run (check job schedule in ServiceNow)"
  echo "2. Or manually trigger the jobs:"
  echo "   Navigate to: $SERVICENOW_INSTANCE_URL/sys_trigger_list.do"
  echo "   Search: 'DevOps Daily Data Collection'"
  echo "   Click: 'Execute Now'"
  echo ""
  echo "3. Check back in 10-15 minutes"
  echo ""
else
  echo "✅ Everything looks good!"
  echo "   - Repository linked"
  echo "   - DevOps data present"
  echo "   - Insights summary populated"
  echo ""
  echo "View dashboard:"
  echo "  $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quick Links"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Repository Record:"
echo "  $SERVICENOW_INSTANCE_URL/sn_devops_repository_list.do?sysparm_query=app=$APP_SYS_ID"
echo ""
echo "Insights Summary Table:"
echo "  $SERVICENOW_INSTANCE_URL/sn_devops_insights_st_summary_list.do?sysparm_query=application=$APP_SYS_ID"
echo ""
echo "DevOps Application:"
echo "  $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
echo ""
echo "Scheduled Jobs:"
echo "  $SERVICENOW_INSTANCE_URL/sys_trigger_list.do?sysparm_query=nameSTARTSWITHDevOps"
echo ""
