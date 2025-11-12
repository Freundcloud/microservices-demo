#!/bin/bash

###############################################################################
# ServiceNow Change Request Approval Script
###############################################################################
#
# This script approves a ServiceNow Change Request and transitions it through
# the proper states to make it ready for deployment.
#
# Usage:
#   ./scripts/approve-servicenow-cr.sh CHG0030123
#
# Prerequisites:
#   - ServiceNow credentials in .envrc (source .envrc first)
#   - jq installed
#   - curl installed
#
###############################################################################

set -e

# Check for CR number argument
if [ -z "$1" ]; then
  echo "Usage: $0 <CHANGE_REQUEST_NUMBER>"
  echo "Example: $0 CHG0030568"
  exit 1
fi

CHANGE_NUMBER="$1"

# Check for required environment variables
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
  echo "❌ Error: ServiceNow credentials not found"
  echo ""
  echo "Please source .envrc first:"
  echo "  source .envrc"
  exit 1
fi

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq is not installed"
  echo "Please install jq: sudo apt-get install jq"
  exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         ServiceNow Change Request Approval Script              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Get Change Request sys_id
echo "📋 Looking up Change Request: $CHANGE_NUMBER..."
CR_LOOKUP=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=number=$CHANGE_NUMBER&sysparm_fields=sys_id,number,state,approval")

CR_SYSID=$(echo "$CR_LOOKUP" | jq -r '.result[0].sys_id // "none"')

if [ "$CR_SYSID" = "none" ] || [ -z "$CR_SYSID" ]; then
  echo "❌ Error: Change Request not found: $CHANGE_NUMBER"
  exit 1
fi

CURRENT_STATE=$(echo "$CR_LOOKUP" | jq -r '.result[0].state')
CURRENT_APPROVAL=$(echo "$CR_LOOKUP" | jq -r '.result[0].approval')

echo "   ✅ Found: $CHANGE_NUMBER (sys_id: $CR_SYSID)"
echo "   Current State: $CURRENT_STATE"
echo "   Current Approval: $CURRENT_APPROVAL"
echo ""

# Step 2: Approve the Change Request
if [ "$CURRENT_APPROVAL" != "approved" ]; then
  echo "✅ Approving Change Request..."
  APPROVE_RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X PATCH \
    -d '{"approval": "approved"}' \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID")
  
  APPROVAL=$(echo "$APPROVE_RESPONSE" | jq -r '.result.approval')
  echo "   Approval status: $APPROVAL"
else
  echo "✅ Already approved"
fi

sleep 1
echo ""

# Step 3: Transition through states
echo "🔄 Transitioning Change Request states..."

# Get current state again
CURRENT_STATE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID?sysparm_fields=state" | \
  jq -r '.result.state')

echo "   Current state: $CURRENT_STATE"

# State transitions: Assess (-4) → Authorize (-3) → Scheduled (-2)
if [ "$CURRENT_STATE" = "-4" ]; then
  echo "   Transitioning: Assess → Authorize..."
  curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X PATCH \
    -d '{"state": "-3"}' \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID" > /dev/null
  sleep 1
  CURRENT_STATE="-3"
fi

if [ "$CURRENT_STATE" = "-3" ]; then
  echo "   Transitioning: Authorize → Scheduled..."
  curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X PATCH \
    -d '{"state": "-2"}' \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID" > /dev/null
  CURRENT_STATE="-2"
fi

echo "   Final state: $CURRENT_STATE (Scheduled)"
echo ""

# Step 4: Verify final state
echo "📊 Verifying final state..."
FINAL_CHECK=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID?sysparm_fields=number,state,approval")

FINAL_STATE=$(echo "$FINAL_CHECK" | jq -r '.result.state')
FINAL_APPROVAL=$(echo "$FINAL_CHECK" | jq -r '.result.approval')

echo "   State: $FINAL_STATE"
echo "   Approval: $FINAL_APPROVAL"
echo ""

if [ "$FINAL_STATE" = "-2" ] && [ "$FINAL_APPROVAL" = "approved" ]; then
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                       ✅ SUCCESS!                               ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Change Request $CHANGE_NUMBER is now:"
  echo "  • Approved"
  echo "  • Scheduled (ready for deployment)"
  echo ""
  echo "The GitHub Actions workflow can now proceed with deployment."
  echo ""
  echo "🔗 View in ServiceNow:"
  echo "   $SERVICENOW_INSTANCE_URL/change_request.do?sys_id=$CR_SYSID"
else
  echo "⚠️  Warning: Unexpected final state"
  echo "   Expected: state=-2, approval=approved"
  echo "   Got: state=$FINAL_STATE, approval=$FINAL_APPROVAL"
  exit 1
fi

