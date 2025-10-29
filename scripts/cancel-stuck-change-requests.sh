#!/bin/bash
#
# Cancel stuck change requests created with incorrect state values
# before the workflow fix (commit 89af4315)
#

set -e

# Load credentials
if [ -f .envrc ]; then
  source .envrc 2>/dev/null || true
fi

# Verify credentials
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ServiceNow credentials not found"
  echo ""
  echo "Please set in .envrc:"
  echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
  echo "  export SERVICENOW_USERNAME='your-username'"
  echo "  export SERVICENOW_PASSWORD='your-password'"
  exit 1
fi

echo "=================================================="
echo "Cancel Stuck Change Requests"
echo "=================================================="
echo ""
echo "This script will cancel change requests created before"
echo "the workflow fix (2025-10-29 20:15:00 UTC) that are stuck"
echo "in Authorize state (-3) due to incorrect state values."
echo ""

# List of stuck CRs created before fix
STUCK_CRS=(
  "CHG0030350"
  "CHG0030351"
  "CHG0030352"
  "CHG0030354"
  "CHG0030355"
  "CHG0030356"
  "CHG0030357"
  "CHG0030359"
)

# Cancellation reason
CLOSE_NOTES="Canceled - created with incorrect state value before workflow fix (commit 89af4315 at 20:15 UTC). Change requests created after the fix use correct state values: Dev=-2 (Scheduled), QA/Prod=-4 (Assess)."

COMMENTS="This CR was stuck in Authorize state (-3) due to a workflow bug where text state values were sent instead of numeric values. The bug has been fixed. New deployments will create CRs with correct states and proper approval workflows."

echo "Change Requests to Cancel:"
for CR_NUMBER in "${STUCK_CRS[@]}"; do
  echo "  - $CR_NUMBER"
done
echo ""
read -p "Proceed with cancellation? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Cancellation aborted"
  exit 0
fi

echo ""
echo "Canceling change requests..."
echo ""

CANCELED_COUNT=0
FAILED_COUNT=0

for CR_NUMBER in "${STUCK_CRS[@]}"; do
  echo "Processing $CR_NUMBER..."

  # Get CR sys_id
  RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=number=$CR_NUMBER&sysparm_fields=sys_id,state,number")

  SYS_ID=$(echo "$RESPONSE" | jq -r '.result[0].sys_id // empty')
  CURRENT_STATE=$(echo "$RESPONSE" | jq -r '.result[0].state // empty')

  if [ -z "$SYS_ID" ]; then
    echo "  ⚠️  Not found - may already be deleted"
    continue
  fi

  if [ "$CURRENT_STATE" = "4" ]; then
    echo "  ℹ️  Already canceled"
    CANCELED_COUNT=$((CANCELED_COUNT + 1))
    continue
  fi

  # Cancel the change request
  CANCEL_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X PATCH \
    "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$SYS_ID" \
    -d "{
      \"state\": \"4\",
      \"close_notes\": \"$CLOSE_NOTES\",
      \"comments\": \"$COMMENTS\"
    }")

  HTTP_CODE=$(echo "$CANCEL_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ Canceled successfully"
    CANCELED_COUNT=$((CANCELED_COUNT + 1))
  else
    echo "  ❌ Failed (HTTP $HTTP_CODE)"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""
echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""
echo "✅ Canceled: $CANCELED_COUNT"
echo "❌ Failed: $FAILED_COUNT"
echo ""
echo "All stuck change requests have been cleaned up."
echo "New deployments will create CRs with correct states."
echo ""
