#!/bin/bash
set -e

echo "🔍 Verifying Repository Linkage"
echo "================================"
echo ""

# Required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: ServiceNow credentials not set"
  exit 1
fi

REPO_SYS_ID="a27eca01c3303a14e1bbf0cb05013125"

echo "Querying repository record..."
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID?sysparm_display_value=all" \
  | jq '.result | {
      name,
      application,
      tool,
      url,
      active
    }'
