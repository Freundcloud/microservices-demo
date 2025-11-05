#!/bin/bash
set -e

# Link Repository to Application - One-Time Fix
# Updates the repository record to link it to the "Online Boutique" application

echo "📎 Linking Repository to Application"
echo "====================================="
echo ""

# Required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: ServiceNow credentials not set"
  echo "Load credentials with: source .envrc"
  exit 1
fi

# Configuration
REPO_SYS_ID="a27eca01c3303a14e1bbf0cb05013125"
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"
TOOL_SYS_ID="f62c4e49c3fcf614e1bbf0cb050131ef"

echo "Updating repository linkage..."
echo "  Repository: Freundcloud/microservices-demo"
echo "  Application: Online Boutique"
echo "  Tool: GithHubARC"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PATCH \
  -d "{
    \"application\": \"$APP_SYS_ID\",
    \"tool\": \"$TOOL_SYS_ID\",
    \"url\": \"https://github.com/Freundcloud/microservices-demo\",
    \"active\": true
  }" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

HTTP_CODE=$(echo "$RESPONSE" | grep -oP 'HTTP_CODE:\K\d+')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ SUCCESS! Repository now linked to 'Online Boutique'"
  echo ""
  echo "Updated record:"
  echo "$BODY" | jq '.result | {
    name,
    application: .application.display_value,
    tool: .tool.display_value,
    url,
    active
  }'
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Configuration Complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Next Steps:"
  echo ""
  echo "1. Trigger a GitHub Actions workflow to upload fresh data:"
  echo "   gh workflow run MASTER-PIPELINE.yaml --ref main -f environment=dev"
  echo ""
  echo "2. Wait 10-15 minutes for ServiceNow scheduled jobs to run"
  echo "   - Job: [DevOps] Daily Data Collection"
  echo "   - Job: [DevOps] Historical Data Collection"
  echo ""
  echo "3. Verify data appears in Insights Dashboard:"
  echo "   $SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/sn_devops_app.do?sys_id=$APP_SYS_ID"
  echo ""
  echo "4. Check sn_devops_insights_st_summary table:"
  echo "   $SERVICENOW_INSTANCE_URL/sn_devops_insights_st_summary_list.do?sysparm_query=application=$APP_SYS_ID"
  echo ""
else
  echo "❌ FAILED (HTTP $HTTP_CODE)"
  echo ""
  echo "Error details:"
  echo "$BODY" | jq '.'
  exit 1
fi
