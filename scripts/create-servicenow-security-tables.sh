#!/bin/bash

################################################################################
# ServiceNow Security Tables Creation Script
################################################################################
#
# This script automatically creates the security scanning tables in ServiceNow
# via REST API calls.
#
# Usage:
#   SERVICENOW_USERNAME="user" SERVICENOW_PASSWORD="pass" ./create-servicenow-security-tables.sh
#
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
log_info "Creating ServiceNow Security Tables..."
log_info "Instance: ${SERVICENOW_INSTANCE_URL}"
echo ""

# Test connectivity first
log_info "Testing connectivity..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" != "200" ]; then
    log_error "Authentication failed (HTTP ${HTTP_CODE})"
    exit 1
fi

log_success "Connectivity verified"
echo ""

# Since ServiceNow REST API doesn't allow table creation directly,
# we need to provide clear manual instructions
log_warning "ServiceNow requires manual table creation via the UI"
log_warning "REST API does not support creating tables directly"
echo ""

log_info "Please follow these steps in ServiceNow UI:"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "STEP 1: Create u_security_scan_result Table"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. Navigate to: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sys_db_object.do"
echo ""
echo "2. Click 'New' to create a new table"
echo ""
echo "3. Fill in the form:"
echo "   Label: Security Scan Result"
echo "   Name: u_security_scan_result"
echo "   Extends table: Base Table (or leave empty)"
echo "   Create module: ✓ (checked)"
echo "   Add module to menu: ✓ (checked)"
echo ""
echo "4. Click 'Submit'"
echo ""
echo "5. The table will be created. Now add fields:"
echo "   - Navigate to the new table: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sys_db_object.do?sys_id=<table_sys_id>"
echo "   - Go to 'Columns' tab"
echo "   - Click 'New' for each field below:"
echo ""
echo "   FIELD 1: u_scan_id"
echo "     Type: String"
echo "     Max length: 100"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 2: u_scan_type"
echo "     Type: Choice"
echo "     Choices: CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 3: u_scan_date"
echo "     Type: Date/Time"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 4: u_finding_id"
echo "     Type: String"
echo "     Max length: 255"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 5: u_severity"
echo "     Type: Choice"
echo "     Choices: CRITICAL, HIGH, MEDIUM, LOW, INFO"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 6: u_title"
echo "     Type: String"
echo "     Max length: 255"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 7: u_description"
echo "     Type: String (large text)"
echo "     Max length: 4000"
echo ""
echo "   FIELD 8: u_file_path"
echo "     Type: String"
echo "     Max length: 512"
echo ""
echo "   FIELD 9: u_line_number"
echo "     Type: Integer"
echo ""
echo "   FIELD 10: u_rule_id"
echo "     Type: String"
echo "     Max length: 255"
echo ""
echo "   FIELD 11: u_cve_id"
echo "     Type: String"
echo "     Max length: 100"
echo ""
echo "   FIELD 12: u_cvss_score"
echo "     Type: Decimal"
echo ""
echo "   FIELD 13: u_status"
echo "     Type: Choice"
echo "     Choices: Open, In Progress, Resolved, False Positive"
echo "     Mandatory: ✓"
echo "     Default: Open"
echo ""
echo "   FIELD 14: u_repository"
echo "     Type: String"
echo "     Max length: 255"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 15: u_branch"
echo "     Type: String"
echo "     Max length: 100"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 16: u_commit_sha"
echo "     Type: String"
echo "     Max length: 40"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 17: u_github_url"
echo "     Type: URL"
echo "     Max length: 1024"
echo ""
echo "   FIELD 18: u_sarif_data"
echo "     Type: String (large text)"
echo "     Max length: 65000"
echo ""
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "STEP 2: Create u_security_scan_summary Table"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. Navigate to: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sys_db_object.do"
echo ""
echo "2. Click 'New' to create a new table"
echo ""
echo "3. Fill in the form:"
echo "   Label: Security Scan Summary"
echo "   Name: u_security_scan_summary"
echo "   Extends table: Base Table (or leave empty)"
echo "   Create module: ✓ (checked)"
echo "   Add module to menu: ✓ (checked)"
echo ""
echo "4. Click 'Submit'"
echo ""
echo "5. Add fields (same process as above):"
echo ""
echo "   FIELD 1: u_scan_id"
echo "     Type: String"
echo "     Max length: 100"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 2: u_workflow_run_id"
echo "     Type: String"
echo "     Max length: 100"
echo ""
echo "   FIELD 3: u_repository"
echo "     Type: String"
echo "     Max length: 255"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 4: u_branch"
echo "     Type: String"
echo "     Max length: 100"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 5: u_commit_sha"
echo "     Type: String"
echo "     Max length: 40"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 6: u_scan_date"
echo "     Type: Date/Time"
echo "     Mandatory: ✓"
echo ""
echo "   FIELD 7: u_total_findings"
echo "     Type: Integer"
echo "     Mandatory: ✓"
echo "     Default: 0"
echo ""
echo "   FIELD 8: u_critical_count"
echo "     Type: Integer"
echo "     Default: 0"
echo ""
echo "   FIELD 9: u_high_count"
echo "     Type: Integer"
echo "     Default: 0"
echo ""
echo "   FIELD 10: u_medium_count"
echo "     Type: Integer"
echo "     Default: 0"
echo ""
echo "   FIELD 11: u_low_count"
echo "     Type: Integer"
echo "     Default: 0"
echo ""
echo "   FIELD 12: u_info_count"
echo "     Type: Integer"
echo "     Default: 0"
echo ""
echo "   FIELD 13: u_tools_run"
echo "     Type: String"
echo "     Max length: 512"
echo ""
echo "   FIELD 14: u_status"
echo "     Type: Choice"
echo "     Choices: Success, Failed, In Progress"
echo "     Mandatory: ✓"
echo "     Default: Success"
echo ""
echo "   FIELD 15: u_github_url"
echo "     Type: URL"
echo "     Max length: 1024"
echo ""
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "STEP 3: Verify Tables Were Created"
echo "════════════════════════════════════════════════════════════════"
echo ""

read -p "Press Enter after you've created both tables to verify..."

echo ""
log_info "Verifying table creation..."

# Check u_security_scan_result
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_security_scan_result table exists"
else
    log_error "✗ u_security_scan_result table NOT FOUND (HTTP ${HTTP_CODE})"
    exit 1
fi

# Check u_security_scan_summary
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
    -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "✓ u_security_scan_summary table exists"
else
    log_error "✗ u_security_scan_summary table NOT FOUND (HTTP ${HTTP_CODE})"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    SETUP COMPLETE!"
echo "════════════════════════════════════════════════════════════════"
echo ""
log_success "Both security tables have been created successfully!"
echo ""
log_info "Next steps:"
echo "1. Re-trigger the security scan workflow:"
echo "   gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo"
echo ""
echo "2. Monitor the workflow:"
echo "   gh run watch \$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo) --repo Freundcloud/microservices-demo"
echo ""
echo "3. View results in ServiceNow:"
echo "   Summary: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do"
echo "   Findings: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do"
echo ""
