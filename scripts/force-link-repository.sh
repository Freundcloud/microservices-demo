#!/bin/bash
set -e

echo "🔧 Force Linking Repository to Application"
echo "==========================================="
echo ""

# Required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: ServiceNow credentials not set"
  exit 1
fi

REPO_SYS_ID="a27eca01c3303a14e1bbf0cb05013125"
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"

echo "Attempting multiple update methods..."
echo ""

# Method 1: Try with PUT (full update)
echo "Method 1: PUT request..."
RESPONSE1=$(curl -s -w "\nHTTP:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PUT \
  -d "{\"application\":\"$APP_SYS_ID\"}" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

HTTP1=$(echo "$RESPONSE1" | grep -oP 'HTTP:\K\d+')
echo "  HTTP Status: $HTTP1"

# Method 2: Check if 'app_id' field exists
echo "Method 2: PATCH with app_id field..."
RESPONSE2=$(curl -s -w "\nHTTP:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d "{\"app_id\":\"$APP_SYS_ID\"}" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

HTTP2=$(echo "$RESPONSE2" | grep -oP 'HTTP:\K\d+')
echo "  HTTP Status: $HTTP2"

# Method 3: Check if 'devops_application' field exists
echo "Method 3: PATCH with devops_application field..."
RESPONSE3=$(curl -s -w "\nHTTP:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d "{\"devops_application\":\"$APP_SYS_ID\"}" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID")

HTTP3=$(echo "$RESPONSE3" | grep -oP 'HTTP:\K\d+')
echo "  HTTP Status: $HTTP3"

echo ""
echo "Fetching current record state..."
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_SYS_ID" \
  | jq '.result | to_entries | map(select(.value != null and .value != "")) | from_entries'

echo ""
echo "Checking table dictionary for correct field name..."
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_repository^elementCONTAINSapp^ORelementCONTAINSapplication&sysparm_fields=element,column_label,internal_type" \
  | jq '.result[] | {field: .element, label: .column_label, type: .internal_type.display_value}'
