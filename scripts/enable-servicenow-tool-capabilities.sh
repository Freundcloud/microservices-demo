#!/bin/bash
# Enable ServiceNow Tool Capabilities
# This script enables the required capabilities for the ServiceNow DevOps tool record

set -euo pipefail

# Load credentials
if [ -f .envrc ]; then
  source .envrc
fi

# Check credentials
if [ -z "${SERVICENOW_USERNAME:-}" ] || [ -z "${SERVICENOW_PASSWORD:-}" ] || [ -z "${SERVICENOW_INSTANCE_URL:-}" ]; then
  echo "❌ Error: ServiceNow credentials not found"
  echo ""
  echo "Please ensure these environment variables are set:"
  echo "  - SERVICENOW_USERNAME"
  echo "  - SERVICENOW_PASSWORD"
  echo "  - SERVICENOW_INSTANCE_URL"
  echo ""
  echo "You can set them by creating a .envrc file with:"
  echo "  export SERVICENOW_USERNAME='your_username'"
  echo "  export SERVICENOW_PASSWORD='your_password'"
  echo "  export SERVICENOW_INSTANCE_URL='https://your_instance.service-now.com'"
  exit 1
fi

# Tool ID from secrets
TOOL_ID="${SN_ORCHESTRATION_TOOL_ID:-f76a57c9c3307a14e1bbf0cb05013135}"

echo "=============================================="
echo "ServiceNow Tool Capabilities Enablement"
echo "=============================================="
echo ""
echo "Instance: $SERVICENOW_INSTANCE_URL"
echo "Tool ID: $TOOL_ID"
echo ""

# Step 1: Get current tool configuration
echo "📋 Step 1: Fetching current tool configuration..."
echo ""

CURRENT_CONFIG=$(curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool/${TOOL_ID}?sysparm_fields=name,type,url,capabilities" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json")

echo "Current configuration:"
echo "$CURRENT_CONFIG" | jq
echo ""

TOOL_NAME=$(echo "$CURRENT_CONFIG" | jq -r '.result.name // "Unknown"')
CURRENT_CAPABILITIES=$(echo "$CURRENT_CONFIG" | jq -r '.result.capabilities // ""')

echo "Tool Name: $TOOL_NAME"
echo "Current Capabilities: ${CURRENT_CAPABILITIES:-'(none)'}"
echo ""

# Step 2: Prepare capabilities list
echo "📝 Step 2: Preparing capabilities to enable..."
echo ""

CAPABILITIES_TO_ENABLE=(
  "testManagement"
  "artifactManagement"
  "packageManagement"
  "changeControl"
  "pipelineExecution"
)

echo "Capabilities to enable:"
for cap in "${CAPABILITIES_TO_ENABLE[@]}"; do
  echo "  - $cap"
done
echo ""

# Join capabilities with comma
CAPABILITIES_STRING=$(IFS=,; echo "${CAPABILITIES_TO_ENABLE[*]}")

# Step 3: Update tool record with capabilities
echo "🔧 Step 3: Updating tool record with capabilities..."
echo ""

UPDATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X PATCH \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool/${TOOL_ID}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"capabilities\": \"$CAPABILITIES_STRING\"}")

# Extract HTTP status
HTTP_STATUS=$(echo "$UPDATE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$UPDATE_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $HTTP_STATUS"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ Tool capabilities updated successfully!"
  echo ""
  echo "Updated configuration:"
  echo "$RESPONSE_BODY" | jq
  echo ""
else
  echo "❌ Failed to update tool capabilities"
  echo ""
  echo "Response:"
  echo "$RESPONSE_BODY" | jq || echo "$RESPONSE_BODY"
  echo ""
  exit 1
fi

# Step 4: Verify capabilities were enabled
echo "🔍 Step 4: Verifying capabilities were enabled..."
echo ""

VERIFY_CONFIG=$(curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool/${TOOL_ID}?sysparm_fields=name,capabilities" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json")

VERIFIED_CAPABILITIES=$(echo "$VERIFY_CONFIG" | jq -r '.result.capabilities // ""')

echo "Verified Capabilities: $VERIFIED_CAPABILITIES"
echo ""

# Check if all capabilities are present
ALL_ENABLED=true
for cap in "${CAPABILITIES_TO_ENABLE[@]}"; do
  if echo "$VERIFIED_CAPABILITIES" | grep -q "$cap"; then
    echo "  ✅ $cap - enabled"
  else
    echo "  ❌ $cap - NOT enabled"
    ALL_ENABLED=false
  fi
done
echo ""

if [ "$ALL_ENABLED" = true ]; then
  echo "=============================================="
  echo "✅ SUCCESS! All capabilities enabled"
  echo "=============================================="
  echo ""
  echo "Next steps:"
  echo "1. Re-run your GitHub Actions workflow"
  echo "2. Verify test results upload successfully"
  echo "3. Check ServiceNow DevOps dashboard for data"
  echo ""
  echo "Test with:"
  echo "  gh workflow run run-unit-tests.yaml -f service=frontend -f environment=dev"
  echo ""
  echo "Verify in ServiceNow:"
  echo "  ${SERVICENOW_INSTANCE_URL}/now/nav/ui/classic/params/target/sn_devops_test_result_list.do"
  echo ""
else
  echo "=============================================="
  echo "⚠️  WARNING: Some capabilities not enabled"
  echo "=============================================="
  echo ""
  echo "The API might not support direct capability updates."
  echo ""
  echo "Manual configuration required:"
  echo "1. Log into ServiceNow: $SERVICENOW_INSTANCE_URL"
  echo "2. Navigate to: DevOps > Tools > DevOps Tools"
  echo "3. Find tool: $TOOL_NAME (sys_id: $TOOL_ID)"
  echo "4. Enable capabilities in the UI"
  echo ""
  echo "Direct link:"
  echo "  ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sn_devops_tool.do?sys_id=${TOOL_ID}"
  echo ""
fi
