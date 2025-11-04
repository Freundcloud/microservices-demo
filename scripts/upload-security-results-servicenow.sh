#!/bin/bash
set -e

# Upload Security Scan Results to ServiceNow sn_devops_security_result table
# This script uploads vulnerability scan results from GitHub Actions security scans
# to the ServiceNow DevOps Security Result table for tracking and compliance.

# Required environment variables
required_vars=(
  "SERVICENOW_INSTANCE_URL"
  "SERVICENOW_USERNAME"
  "SERVICENOW_PASSWORD"
  "SN_ORCHESTRATION_TOOL_ID"
  "CHANGE_REQUEST_SYS_ID"
  "CHANGE_REQUEST_NUMBER"
  "CRITICAL_COUNT"
  "HIGH_COUNT"
  "MEDIUM_COUNT"
  "LOW_COUNT"
  "TOTAL_COUNT"
  "SCAN_RESULT"
)

echo "🔒 Uploading Security Scan Results to ServiceNow"
echo "================================================="

# Validate required environment variables
missing_vars=()
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    missing_vars+=("$var")
  fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
  echo "❌ ERROR: Missing required environment variables:"
  printf '  - %s\n' "${missing_vars[@]}"
  exit 1
fi

echo "✓ All required environment variables present"
echo ""

# Prepare API endpoint
API_ENDPOINT="${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_security_result"

# Create security result payload
PAYLOAD=$(jq -n \
  --arg tool_id "$SN_ORCHESTRATION_TOOL_ID" \
  --arg change_id "$CHANGE_REQUEST_SYS_ID" \
  --arg scan_name "GitHub Actions Security Scan" \
  --arg scan_type "SAST" \
  --arg result "$SCAN_RESULT" \
  --arg critical "$CRITICAL_COUNT" \
  --arg high "$HIGH_COUNT" \
  --arg medium "$MEDIUM_COUNT" \
  --arg low "$LOW_COUNT" \
  --arg total "$TOTAL_COUNT" \
  --arg scan_url "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/security/code-scanning" \
  '{
    tool: $tool_id,
    change_request: $change_id,
    scan_name: $scan_name,
    scan_type: $scan_type,
    scan_result: $result,
    critical_count: ($critical | tonumber),
    high_count: ($high | tonumber),
    medium_count: ($medium | tonumber),
    low_count: ($low | tonumber),
    total_count: ($total | tonumber),
    scan_url: $scan_url,
    scan_date: (now | strftime("%Y-%m-%d %H:%M:%S"))
  }')

echo "📊 Security Scan Summary:"
echo "  Critical: $CRITICAL_COUNT"
echo "  High: $HIGH_COUNT"
echo "  Medium: $MEDIUM_COUNT"
echo "  Low: $LOW_COUNT"
echo "  Total: $TOTAL_COUNT"
echo "  Result: $SCAN_RESULT"
echo ""

# Upload to ServiceNow
echo "📤 Uploading to ServiceNow..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  -d "$PAYLOAD" \
  "$API_ENDPOINT")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "201" ]; then
  RESULT_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
  RESULT_NUMBER=$(echo "$BODY" | jq -r '.result.number')
  echo "✅ Security result uploaded successfully!"
  echo "   Record Number: $RESULT_NUMBER"
  echo "   Sys ID: $RESULT_SYS_ID"
  echo ""
  echo "View in ServiceNow:"
  echo "  ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sn_devops_security_result.do?sys_id=${RESULT_SYS_ID}"
else
  echo "❌ Failed to upload security result (HTTP $HTTP_CODE)"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi

# Add work note to change request
echo ""
echo "📝 Adding security scan summary to change request..."

# Determine status icon
if [ "$SCAN_RESULT" == "passed" ]; then
  STATUS_ICON="✅"
  STATUS_MSG="NO CRITICAL/HIGH VULNERABILITIES"
else
  STATUS_ICON="⚠️"
  STATUS_MSG="VULNERABILITIES DETECTED - REVIEW REQUIRED"
fi

WORK_NOTE="🔒 SECURITY SCAN RESULTS\\n\\n"
WORK_NOTE="${WORK_NOTE}Status: $STATUS_ICON $STATUS_MSG\\n"
WORK_NOTE="${WORK_NOTE}Scan Type: SAST (Static Application Security Testing)\\n"
WORK_NOTE="${WORK_NOTE}\\n"
WORK_NOTE="${WORK_NOTE}Vulnerability Summary:\\n"
WORK_NOTE="${WORK_NOTE}- Critical: $CRITICAL_COUNT\\n"
WORK_NOTE="${WORK_NOTE}- High: $HIGH_COUNT\\n"
WORK_NOTE="${WORK_NOTE}- Medium: $MEDIUM_COUNT\\n"
WORK_NOTE="${WORK_NOTE}- Low: $LOW_COUNT\\n"
WORK_NOTE="${WORK_NOTE}- Total: $TOTAL_COUNT\\n"
WORK_NOTE="${WORK_NOTE}\\n"
WORK_NOTE="${WORK_NOTE}Security result record: $RESULT_NUMBER\\n"
WORK_NOTE="${WORK_NOTE}Scan details: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/security/code-scanning"

WORK_NOTE_PAYLOAD=$(jq -n --arg note "$WORK_NOTE" '{work_notes: $note}')

curl -s -X PATCH \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  -d "$WORK_NOTE_PAYLOAD" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request/${CHANGE_REQUEST_SYS_ID}" > /dev/null

echo "✅ Work note added to change request $CHANGE_REQUEST_NUMBER"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SECURITY RESULTS UPLOADED TO SERVICENOW"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Change Request: $CHANGE_REQUEST_NUMBER"
echo "Security Result: $RESULT_NUMBER"
echo "Status: $SCAN_RESULT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
