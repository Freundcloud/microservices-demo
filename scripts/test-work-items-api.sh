#!/bin/bash
# Test ServiceNow DevOps Work Items API

set -e

USERNAME="${SERVICENOW_USERNAME}"
PASSWORD="${SERVICENOW_PASSWORD}"
INSTANCE_URL="https://calitiiltddemo3.service-now.com"

echo "Testing ServiceNow DevOps Work Items API"
echo "=========================================="
echo ""

# Get existing work items
echo "Fetching existing work items..."
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
  -H "Accept: application/json" \
  "${INSTANCE_URL}/api/now/table/sn_devops_work_item?sysparm_limit=5")

echo "$RESPONSE" | jq -r '.result[] | "- \(.number): \(.name) (\(.type)) - \(.state)"'
echo ""

# Show field structure
echo "Work item field structure:"
echo "$RESPONSE" | jq -r '.result[0] | keys[]' | sort
echo ""

# Check for GitHub work items
echo "Checking for GitHub work items..."
GITHUB_WI=$(curl -s -u "$USERNAME:$PASSWORD" \
  -H "Accept: application/json" \
  "${INSTANCE_URL}/api/now/table/sn_devops_work_item?sysparm_query=urlLIKEgithub&sysparm_limit=10")

COUNT=$(echo "$GITHUB_WI" | jq -r '.result | length')
echo "GitHub work items found: $COUNT"
echo ""

if [ "$COUNT" -gt 0 ]; then
  echo "$GITHUB_WI" | jq -r '.result[] | "- \(.number): \(.name) - \(.url)"'
else
  echo "No GitHub work items found yet."
  echo ""
  echo "To create GitHub work items, you need to:"
  echo "1. POST to /api/now/table/sn_devops_work_item"
  echo "2. Include: name, type, url, tool_id, plan"
fi
