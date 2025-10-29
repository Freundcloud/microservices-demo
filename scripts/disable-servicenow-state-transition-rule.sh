#!/bin/bash

# Script to disable ServiceNow business rule that blocks state transitions via API
# Business Rule: "Change Model: Check State Transition"

set -e

# Load credentials
if [ -f .envrc ]; then
  source .envrc
fi

# Check required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ Error: ServiceNow credentials not found"
  echo "Please set SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, and SERVICENOW_PASSWORD"
  exit 1
fi

echo "=========================================="
echo "ServiceNow Business Rule Modification"
echo "=========================================="
echo ""

# Step 1: Find the business rule
echo "🔍 Step 1: Finding 'Change Model: Check State Transition' business rule..."
SEARCH_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_script?sysparm_query=nameLIKEChange^ORnameLIKEState^ORnameLIKETransition&sysparm_fields=sys_id,name,active,description&sysparm_limit=20")

echo "$SEARCH_RESPONSE" | jq -r '.result[] | "  \(.sys_id) | Active: \(.active) | \(.name)"'
echo ""

# Find the specific rule
RULE_SYS_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.result[] | select(.name | contains("Check State Transition") or contains("State Transition")) | .sys_id' | head -1)

if [ -z "$RULE_SYS_ID" ] || [ "$RULE_SYS_ID" = "null" ]; then
  echo "⚠️  Could not find 'Check State Transition' business rule by name"
  echo "   Listing all business rules on change_request table..."
  
  ALL_RULES=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_script?sysparm_query=collection=change_request&sysparm_fields=sys_id,name,active,when&sysparm_limit=50")
  
  echo "$ALL_RULES" | jq -r '.result[] | "  \(.sys_id) | Active: \(.active) | When: \(.when) | \(.name)"'
  echo ""
  echo "Please identify the business rule sys_id manually and run:"
  echo "  curl -X PATCH -u \$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"active\":\"false\"}' \\"
  echo "    \$SERVICENOW_INSTANCE_URL/api/now/table/sys_script/SYS_ID"
  exit 1
fi

echo "✅ Found business rule: $RULE_SYS_ID"
echo ""

# Step 2: Get current state
echo "🔍 Step 2: Getting current state of the business rule..."
CURRENT_STATE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_script/$RULE_SYS_ID?sysparm_fields=name,active,description,script")

echo "Current state:"
echo "$CURRENT_STATE" | jq '{name: .result.name, active: .result.active, description: .result.description}'
echo ""

# Step 3: Confirm action
read -p "Do you want to DISABLE this business rule? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Operation cancelled"
  exit 0
fi

# Step 4: Disable the business rule
echo ""
echo "🔧 Step 3: Disabling the business rule..."
UPDATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PATCH \
  -d '{"active":"false"}' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_script/$RULE_SYS_ID")

HTTP_CODE=$(echo "$UPDATE_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$UPDATE_RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Business rule disabled successfully!"
  echo ""
  echo "Updated state:"
  echo "$BODY" | jq '{name: .result.name, active: .result.active}'
  echo ""
  echo "⚠️  IMPORTANT: This change affects the entire ServiceNow instance."
  echo "   State transitions via API are now allowed for all change requests."
  echo ""
  echo "To re-enable the business rule later, run:"
  echo "  curl -X PATCH -u \$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"active\":\"true\"}' \\"
  echo "    $SERVICENOW_INSTANCE_URL/api/now/table/sys_script/$RULE_SYS_ID"
else
  echo "❌ Failed to disable business rule (HTTP $HTTP_CODE)"
  echo "$BODY" | jq '.' || echo "$BODY"
  exit 1
fi

echo ""
echo "=========================================="
echo "✅ Operation Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test creating a change request with state='scheduled'"
echo "2. Verify it creates with state -2 (Scheduled)"
echo "3. Monitor for any unintended side effects"
