#!/bin/bash

################################################################################
# Create u_security_scan_summary Table via ServiceNow API
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ServiceNow instance
SERVICENOW_INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"

# Prompt for credentials if not set
if [ -z "${SERVICENOW_USERNAME:-}" ]; then
    read -p "ServiceNow Username: " SERVICENOW_USERNAME
fi

if [ -z "${SERVICENOW_PASSWORD:-}" ]; then
    read -sp "ServiceNow Password: " SERVICENOW_PASSWORD
    echo ""
fi

echo ""
log_info "Attempting to create u_security_scan_summary table via API..."
echo ""

# Unfortunately, ServiceNow REST API doesn't support table creation
# But we can try to create a test record which might auto-create the table

log_info "Creating test record to initialize table..."

# Create a test record
TEST_RECORD=$(cat <<EOF
{
    "u_scan_id": "test-initialization",
    "u_repository": "test",
    "u_branch": "test",
    "u_commit_sha": "0000000000000000000000000000000000000000",
    "u_scan_date": "$(date -u +"%Y-%m-%d %H:%M:%S")",
    "u_total_findings": 0,
    "u_critical_count": 0,
    "u_high_count": 0,
    "u_medium_count": 0,
    "u_low_count": 0,
    "u_info_count": 0,
    "u_status": "Success"
}
EOF
)

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "$TEST_RECORD" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary" 2>/dev/null || echo "HTTP_CODE:000")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "201" ]; then
    log_success "Table appears to exist and record was created!"

    # Delete test record
    SYS_ID=$(echo "$RESPONSE" | grep -v "HTTP_CODE" | jq -r '.result.sys_id')
    curl -s -X DELETE \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary/${SYS_ID}" > /dev/null 2>&1

    log_info "Test record deleted"
    echo ""
    log_success "Table is ready!"
elif [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "404" ]; then
    log_error "Table does not exist (HTTP ${HTTP_CODE})"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "MANUAL CREATION REQUIRED"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    log_info "The table MUST be created via ServiceNow UI:"
    echo ""
    echo "1. Open this URL:"
    echo "   ${SERVICENOW_INSTANCE_URL}/sys_db_object.do?sys_id=-1"
    echo ""
    echo "2. Fill in EXACTLY:"
    echo "   Label: Security Scan Summary"
    echo "   Name: u_security_scan_summary"
    echo "   (Leave other fields default)"
    echo ""
    echo "3. Click Submit"
    echo ""
    echo "4. After table is created, you'll need to add 15 fields."
    echo "   See: CREATE-SUMMARY-TABLE.md for complete field list"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Show detailed error
    log_error "API Response:"
    echo "$RESPONSE" | grep -v "HTTP_CODE" | jq '.' 2>/dev/null || echo "$RESPONSE" | grep -v "HTTP_CODE"

    exit 1
else
    log_error "Unexpected response (HTTP ${HTTP_CODE})"
    echo "$RESPONSE"
    exit 1
fi
