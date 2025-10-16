#!/bin/bash

################################################################################
# Upload Security Scan Results to ServiceNow
################################################################################
#
# This script uploads aggregated security scan results to ServiceNow CMDB.
#
# Usage:
#   ./upload-security-to-servicenow.sh
#
# Environment Variables (Required):
#   SERVICENOW_INSTANCE_URL - ServiceNow instance URL
#   SERVICENOW_USERNAME - ServiceNow username
#   SERVICENOW_PASSWORD - ServiceNow password
#   GITHUB_REPOSITORY - GitHub repository name
#   GITHUB_RUN_ID - GitHub Actions run ID
#
################################################################################

set -euo pipefail

# Configuration
RESULTS_FILE="${RESULTS_FILE:-aggregated-security-results.json}"
SUMMARY_FILE="${SUMMARY_FILE:-security-scan-summary.json}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if [ -z "${SERVICENOW_INSTANCE_URL:-}" ]; then
        log_error "SERVICENOW_INSTANCE_URL not set"
        exit 1
    fi

    if [ -z "${SERVICENOW_USERNAME:-}" ]; then
        log_error "SERVICENOW_USERNAME not set"
        exit 1
    fi

    if [ -z "${SERVICENOW_PASSWORD:-}" ]; then
        log_error "SERVICENOW_PASSWORD not set"
        exit 1
    fi

    if [ ! -f "$RESULTS_FILE" ]; then
        log_error "Results file not found: $RESULTS_FILE"
        exit 1
    fi

    if [ ! -f "$SUMMARY_FILE" ]; then
        log_error "Summary file not found: $SUMMARY_FILE"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Test ServiceNow connectivity
test_connectivity() {
    log_info "Testing ServiceNow connectivity..."

    BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" != "200" ]; then
        log_error "ServiceNow connectivity test failed (HTTP $HTTP_CODE)"
        exit 1
    fi

    log_success "ServiceNow connectivity verified"
}

# Check if tables exist
check_tables() {
    log_info "Checking required ServiceNow tables..."

    BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    # Check u_security_scan_result table
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Table 'u_security_scan_result' not accessible (HTTP $HTTP_CODE)"
        log_error "Please create the table first. See: docs/SERVICENOW-SECURITY-SCANNING.md"
        exit 1
    fi

    log_success "Table 'u_security_scan_result' verified"

    # Check u_security_scan_summary table
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" != "200" ]; then
        log_warning "Table 'u_security_scan_summary' not accessible (HTTP $HTTP_CODE)"
        log_warning "Summary will not be uploaded. Create table to enable summary tracking."
        SKIP_SUMMARY=true
    else
        log_success "Table 'u_security_scan_summary' verified"
        SKIP_SUMMARY=false
    fi
}

# Upload scan summary
upload_summary() {
    if [ "$SKIP_SUMMARY" = true ]; then
        log_warning "Skipping summary upload (table not available)"
        return
    fi

    log_info "Uploading scan summary..."

    BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)
    SUMMARY_DATA=$(cat "$SUMMARY_FILE")

    # Convert tools_run array to comma-separated string
    TOOLS_RUN=$(echo "$SUMMARY_DATA" | jq -r '.tools_run | join(", ")')
    SUMMARY_PAYLOAD=$(echo "$SUMMARY_DATA" | jq --arg tools "$TOOLS_RUN" \
        'del(.tools_run) | .u_tools_run = $tools |
         .u_workflow_run_id = .scan_id |
         .u_scan_id = .scan_id |
         .u_repository = .repository |
         .u_branch = .branch |
         .u_commit_sha = .commit_sha |
         .u_scan_date = .scan_date |
         .u_total_findings = .total_findings |
         .u_critical_count = .critical_count |
         .u_high_count = .high_count |
         .u_medium_count = .medium_count |
         .u_low_count = .low_count |
         .u_info_count = .info_count |
         .u_github_url = .github_url |
         .u_status = "Success" |
         del(.scan_id, .repository, .branch, .commit_sha, .scan_date, .total_findings, .critical_count, .high_count, .medium_count, .low_count, .info_count, .github_url)')

    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -X POST \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" \
        -d "$SUMMARY_PAYLOAD" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "201" ]; then
        SUMMARY_SYS_ID=$(echo "$RESPONSE" | grep -v "HTTP_CODE" | jq -r '.result.sys_id')
        log_success "Summary uploaded successfully (sys_id: $SUMMARY_SYS_ID)"
    else
        log_error "Summary upload failed (HTTP $HTTP_CODE)"
        echo "$RESPONSE" | grep -v "HTTP_CODE"
    fi
}

# Upload findings
upload_findings() {
    log_info "Uploading security findings..."

    BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    TOTAL_FINDINGS=$(jq '.findings | length' "$RESULTS_FILE")
    log_info "Total findings to upload: $TOTAL_FINDINGS"

    if [ "$TOTAL_FINDINGS" -eq 0 ]; then
        log_info "No findings to upload"
        return
    fi

    UPLOADED_COUNT=0
    UPDATED_COUNT=0
    FAILED_COUNT=0

    # Upload each finding
    jq -c '.findings[]' "$RESULTS_FILE" | while read -r finding; do
        FINDING_ID=$(echo "$finding" | jq -r '.u_finding_id')

        # Check if finding already exists
        EXISTING=$(curl -s -X GET \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_query=u_finding_id=${FINDING_ID}&sysparm_limit=1" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

        EXISTING_SYS_ID=$(echo "$EXISTING" | jq -r '.result[0].sys_id // empty')

        if [ -n "$EXISTING_SYS_ID" ]; then
            # Update existing finding (only scan_id and scan_date)
            UPDATE_PAYLOAD=$(echo "$finding" | jq '{u_scan_id, u_scan_date}')

            RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
                -X PUT \
                "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result/${EXISTING_SYS_ID}" \
                -H "Authorization: Basic ${BASIC_AUTH}" \
                -H "Content-Type: application/json" \
                -d "$UPDATE_PAYLOAD" 2>/dev/null || echo "HTTP_CODE:000")

            HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

            if [ "$HTTP_CODE" = "200" ]; then
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
            else
                FAILED_COUNT=$((FAILED_COUNT + 1))
                log_warning "Failed to update finding $FINDING_ID (HTTP $HTTP_CODE)"
            fi
        else
            # Create new finding
            RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
                -X POST \
                "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result" \
                -H "Authorization: Basic ${BASIC_AUTH}" \
                -H "Content-Type: application/json" \
                -d "$finding" 2>/dev/null || echo "HTTP_CODE:000")

            HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

            if [ "$HTTP_CODE" = "201" ]; then
                UPLOADED_COUNT=$((UPLOADED_COUNT + 1))
            else
                FAILED_COUNT=$((FAILED_COUNT + 1))
                log_warning "Failed to create finding $FINDING_ID (HTTP $HTTP_CODE)"
            fi
        fi

        # Progress indicator
        CURRENT=$((UPLOADED_COUNT + UPDATED_COUNT + FAILED_COUNT))
        if [ $((CURRENT % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done

    echo ""  # New line after progress dots

    log_info "Upload complete:"
    log_success "  - Created: $UPLOADED_COUNT"
    log_success "  - Updated: $UPDATED_COUNT"
    if [ $FAILED_COUNT -gt 0 ]; then
        log_warning "  - Failed: $FAILED_COUNT"
    fi
}

# Generate summary report
generate_report() {
    log_info "Generating upload report..."

    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║               Security Scan Upload Complete                   ║
╚═══════════════════════════════════════════════════════════════╝

Repository: ${GITHUB_REPOSITORY:-N/A}
Scan Run:   ${GITHUB_RUN_ID:-N/A}

Findings Summary:
  Total:    $(jq '.total_findings' "$SUMMARY_FILE")
  Critical: $(jq '.critical_count' "$SUMMARY_FILE")
  High:     $(jq '.high_count' "$SUMMARY_FILE")
  Medium:   $(jq '.medium_count' "$SUMMARY_FILE")
  Low:      $(jq '.low_count' "$SUMMARY_FILE")

View Results in ServiceNow:
  Security Scan Results:
    ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do

  Scan Summaries:
    ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do

EOF
}

# Main execution
main() {
    log_info "Starting ServiceNow security upload..."

    check_prerequisites
    test_connectivity
    check_tables
    upload_summary
    upload_findings
    generate_report

    log_success "Upload completed successfully!"
}

main "$@"
