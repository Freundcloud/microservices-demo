#!/bin/bash

# Create missing test_type records in ServiceNow for Issue #56
# This script creates "Security Scan" and "Quality Gate" test types

set -e

# ServiceNow credentials
USERNAME="${SERVICENOW_USERNAME:-github_integration}"
PASSWORD="${SERVICENOW_PASSWORD:-oA3KqdUVI8Q_^>}"
INSTANCE="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"

echo "🔧 Creating Custom Test Types in ServiceNow"
echo "==========================================="
echo ""

# Check credentials
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$INSTANCE" ]; then
  echo "❌ Error: ServiceNow credentials not configured"
  echo "Please set: SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL"
  exit 1
fi

# Function to create test type
create_test_type() {
  local CATEGORY=$1
  local TYPE_NAME=$2

  echo "📝 Creating test type: $TYPE_NAME (category: $CATEGORY)"

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d '{
      "test_category": "'"$CATEGORY"'",
      "test_type": "'"$TYPE_NAME"'"
    }' \
    "$INSTANCE/api/now/table/sn_devops_test_type")

  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  if [ "$HTTP_CODE" = "201" ]; then
    SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
    echo "  ✅ Created successfully"
    echo "     sys_id: $SYS_ID"
    echo "     category: $CATEGORY"
    echo "     type: $TYPE_NAME"
    echo ""
    return 0
  elif [ "$HTTP_CODE" = "400" ]; then
    # Check if it already exists
    ERROR_MSG=$(echo "$BODY" | jq -r '.error.message // "Unknown error"')
    if [[ "$ERROR_MSG" == *"duplicate"* ]] || [[ "$ERROR_MSG" == *"already exists"* ]]; then
      echo "  ℹ️  Already exists (finding existing record...)"

      # Query for existing record
      EXISTING=$(curl -s \
        -u "$USERNAME:$PASSWORD" \
        -H "Accept: application/json" \
        "$INSTANCE/api/now/table/sn_devops_test_type?sysparm_query=test_category=$CATEGORY^test_type=$TYPE_NAME&sysparm_fields=sys_id,test_category,test_type")

      SYS_ID=$(echo "$EXISTING" | jq -r '.result[0].sys_id // "not found"')
      if [ "$SYS_ID" != "not found" ]; then
        echo "     sys_id: $SYS_ID"
        echo "     category: $CATEGORY"
        echo "     type: $TYPE_NAME"
        echo ""
        return 0
      fi
    else
      echo "  ❌ Failed to create: $ERROR_MSG"
      echo "$BODY" | jq '.'
      return 1
    fi
  else
    echo "  ❌ Failed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.'
    return 1
  fi
}

# Create Security Scan test type
echo "1️⃣  Security Scan Test Type"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
create_test_type "security" "Security Scan"

# Create Quality Gate test type
echo "2️⃣  Quality Gate Test Type"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
create_test_type "quality" "Quality Gate"

# Query all test types to show current state
echo "📋 Current Test Types in ServiceNow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for CATEGORY in unit security quality functional; do
  echo "Category: $CATEGORY"
  curl -s \
    -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "$INSTANCE/api/now/table/sn_devops_test_type?sysparm_query=test_category=$CATEGORY&sysparm_fields=sys_id,test_category,test_type&sysparm_limit=10" | \
    jq -r '.result[] | "  - \(.test_type): \(.sys_id)"'
  echo ""
done

echo "✅ Test type setup complete!"
echo ""
echo "Next steps:"
echo "1. Update workflow to use sys_id references"
echo "2. Test with dev deployment"
echo "3. Verify test summaries display correctly in ServiceNow"
