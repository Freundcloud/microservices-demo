#!/bin/bash

################################################################################
# ServiceNow Connectivity Test Script
################################################################################
#
# Tests ServiceNow API connectivity and verifies security tables exist
#
# Usage:
#   ./test-servicenow-connectivity.sh
#
# Or with credentials:
#   SERVICENOW_USERNAME="user" SERVICENOW_PASSWORD="pass" ./test-servicenow-connectivity.sh
#
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ServiceNow instance URL
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
log_info "Testing ServiceNow connectivity..."
log_info "Instance: ${SERVICENOW_INSTANCE_URL}"
log_info "Username: ${SERVICENOW_USERNAME}"
echo ""

# Test 1: Basic connectivity
log_info "Test 1: Testing basic API connectivity..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ Basic connectivity working (HTTP 200)"
else
    log_error "✗ Basic connectivity failed (HTTP ${HTTP_CODE})"
    echo "Response:"
    echo "$RESPONSE" | grep -v "HTTP_CODE"
    exit 1
fi

echo ""

# Test 2: Check existing tables
log_info "Test 2: Checking existing ServiceNow tables..."

# Check u_eks_cluster
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_eks_cluster?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_eks_cluster table exists"
else
    log_warning "⚠ u_eks_cluster table not found (HTTP ${HTTP_CODE})"
fi

# Check u_microservice
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_microservice table exists"
else
    log_warning "⚠ u_microservice table not found (HTTP ${HTTP_CODE})"
fi

echo ""

# Test 3: Check security tables
log_info "Test 3: Checking security scan tables..."

# Check u_security_scan_result
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_security_scan_result table exists"
    SECURITY_RESULT_EXISTS=true

    # Count records
    RECORD_COUNT=$(echo "$RESPONSE" | grep -v "HTTP_CODE" | jq -r '.result | length')
    log_info "  Records: ${RECORD_COUNT}"
else
    log_error "✗ u_security_scan_result table NOT FOUND (HTTP ${HTTP_CODE})"
    log_warning "  This table needs to be created before running security scans"
    SECURITY_RESULT_EXISTS=false
fi

# Check u_security_scan_summary
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_security_scan_summary table exists"
    SECURITY_SUMMARY_EXISTS=true

    # Count records
    RECORD_COUNT=$(echo "$RESPONSE" | grep -v "HTTP_CODE" | jq -r '.result | length')
    log_info "  Records: ${RECORD_COUNT}"
else
    log_error "✗ u_security_scan_summary table NOT FOUND (HTTP ${HTTP_CODE})"
    log_warning "  This table needs to be created before running security scans"
    SECURITY_SUMMARY_EXISTS=false
fi

echo ""

# Test 4: Test write permissions
log_info "Test 4: Testing write permissions..."

TEST_PAYLOAD=$(jq -n \
    --arg name "connectivity-test-$(date +%s)" \
    '{
        u_name: $name,
        u_namespace: "test",
        u_cluster_name: "test-cluster"
    }')

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -X POST \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "$TEST_PAYLOAD" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice" 2>/dev/null || echo "HTTP_CODE:000")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "201" ]; then
    log_success "✓ Write permissions working (HTTP 201)"

    # Get sys_id and delete test record
    SYS_ID=$(echo "$RESPONSE" | grep -v "HTTP_CODE" | jq -r '.result.sys_id')

    # Delete test record
    curl -s -X DELETE \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice/${SYS_ID}" > /dev/null 2>&1

    log_info "  Test record created and deleted successfully"
else
    log_error "✗ Write permissions failed (HTTP ${HTTP_CODE})"
    echo "Response:"
    echo "$RESPONSE" | grep -v "HTTP_CODE"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    CONNECTIVITY TEST SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$SECURITY_RESULT_EXISTS" = true ] && [ "$SECURITY_SUMMARY_EXISTS" = true ]; then
    log_success "✓ All security tables exist - READY FOR TESTING!"
    echo ""
    log_info "Next steps:"
    echo "  1. Trigger security scan workflow:"
    echo "     gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo"
    echo ""
    echo "  2. Monitor workflow:"
    echo "     gh run watch \$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo) --repo Freundcloud/microservices-demo"
    echo ""
    echo "  3. View results in ServiceNow:"
    echo "     - Summary: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do"
    echo "     - Findings: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do"
    echo ""
    exit 0
else
    log_error "✗ Security tables NOT FOUND - Setup required"
    echo ""
    log_info "Required actions:"
    echo "  1. Create security tables in ServiceNow"
    echo ""
    echo "  Option A: Run onboarding script (recommended)"
    echo "     bash scripts/SN_onboarding_Github.sh"
    echo ""
    echo "  Option B: Manual creation via ServiceNow UI"
    echo "     Follow instructions in: docs/SERVICENOW-SECURITY-VERIFICATION.md#step-1"
    echo ""
    echo "  2. Re-run this test script to verify"
    echo "     bash scripts/test-servicenow-connectivity.sh"
    echo ""
    exit 1
fi
