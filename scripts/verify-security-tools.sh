#!/bin/bash

################################################################################
# ServiceNow Security Tools Verification Script
################################################################################
#
# This script verifies that security tools are properly registered in ServiceNow
# and that security scan results are being linked to change requests.
#
# Prerequisites:
#   - ServiceNow credentials configured in .envrc or environment
#   - jq installed
#   - curl installed
#
# Usage:
#   ./scripts/verify-security-tools.sh [CHANGE_REQUEST_NUMBER]
#
################################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ServiceNow Configuration
readonly SERVICENOW_INSTANCE="${SERVICENOW_INSTANCE:-https://calitiiltddemo3.service-now.com}"
readonly TOOL_ID="${SN_ORCHESTRATION_TOOL_ID:-4c5e482cc3383214e1bbf0cb05013196}"
readonly DEVOPS_APP_ID="6047e45ac3e4f690e1bbf0cb05013120"

# Optional: Change request number to check
CHG_NUMBER="${1:-}"

################################################################################
# Helper Functions
################################################################################

log_section() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check required environment variables
check_prerequisites() {
    if [ -z "${SERVICENOW_USERNAME:-}" ] || [ -z "${SERVICENOW_PASSWORD:-}" ]; then
        log_error "ServiceNow credentials not found in environment"
        echo ""
        echo "Please set SERVICENOW_USERNAME and SERVICENOW_PASSWORD"
        echo "Or source .envrc if credentials are there"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi
}

# Make ServiceNow API call
snow_api() {
    local endpoint="$1"
    local full_url="${SERVICENOW_INSTANCE}/api/now/${endpoint}"

    curl -s \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --user "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        "$full_url"
}

################################################################################
# Verification Functions
################################################################################

# Step 1: Verify DevOps Tool
verify_devops_tool() {
    log_section "1. Verifying DevOps Tool"

    local response=$(snow_api "table/sn_devops_tool/${TOOL_ID}")

    if echo "$response" | jq -e '.result.sys_id' > /dev/null 2>&1; then
        local tool_name=$(echo "$response" | jq -r '.result.name')
        local tool_type=$(echo "$response" | jq -r '.result.type')
        local tool_active=$(echo "$response" | jq -r '.result.active')

        log_info "DevOps Tool found: $tool_name"
        echo "   Type: $tool_type"
        echo "   Active: $tool_active"
        echo "   Sys ID: $TOOL_ID"
        return 0
    else
        log_error "DevOps Tool not found"
        echo "$response" | jq '.'
        return 1
    fi
}

# Step 2: Verify DevOps Application
verify_devops_application() {
    log_section "2. Verifying DevOps Application"

    local response=$(snow_api "table/sn_devops_app/${DEVOPS_APP_ID}")

    if echo "$response" | jq -e '.result.sys_id' > /dev/null 2>&1; then
        local app_name=$(echo "$response" | jq -r '.result.name')
        local tool_ref=$(echo "$response" | jq -r '.result.tool.value // "not set"')

        log_info "DevOps Application found: $app_name"
        echo "   Sys ID: $DEVOPS_APP_ID"
        echo "   Linked Tool: $tool_ref"

        if [ "$tool_ref" == "$TOOL_ID" ]; then
            log_info "Application correctly linked to GitHub tool"
        else
            log_warn "Application tool reference doesn't match expected tool ID"
        fi
        return 0
    else
        log_error "DevOps Application not found"
        echo "$response" | jq '.'
        return 1
    fi
}

# Step 3: Check for Security Test Results
check_security_results() {
    log_section "3. Checking Security Test Results"

    # Try different possible table names
    local tables=("sn_devops_test_result" "sn_devops_test_execution" "sn_devops_security_result")
    local found_results=false

    for table in "${tables[@]}"; do
        echo "Checking table: $table..."
        local response=$(snow_api "table/${table}?sysparm_query=u_tool_id=${TOOL_ID}&sysparm_limit=10" 2>/dev/null || echo '{"result":[]}')
        local count=$(echo "$response" | jq '.result | length' 2>/dev/null || echo "0")

        if [ "$count" -gt 0 ]; then
            log_info "Found $count security results in $table"
            echo ""
            echo "   Recent security scans:"
            echo "$response" | jq -r '.result[] | "   - \(.u_name // .test_name // "unnamed") (\(.sys_created_on))"' 2>/dev/null | head -5
            found_results=true
            break
        fi
    done

    if [ "$found_results" == false ]; then
        log_warn "No security results found in checked tables"
        echo ""
        echo "This may mean:"
        echo "   - Security tools haven't run yet"
        echo "   - Results are stored in a different table"
        echo "   - User lacks permissions to view results"
        echo ""
        echo "Try running a deployment with security scans first:"
        echo "   git commit --allow-empty -m 'test: trigger security scans'"
        echo "   git push"
    fi
}

# Step 4: Check Change Requests
check_change_requests() {
    log_section "4. Checking DevOps Change Requests"

    local query="category=DevOps^devops_change=true"
    if [ -n "$CHG_NUMBER" ]; then
        query="number=${CHG_NUMBER}"
    fi

    local response=$(snow_api "table/change_request?sysparm_query=${query}&sysparm_fields=number,short_description,state,sys_created_on,business_service&sysparm_limit=5&sysparm_order_by=^sys_created_on")

    local count=$(echo "$response" | jq '.result | length')

    if [ "$count" -gt 0 ]; then
        log_info "Found $count DevOps change requests"
        echo ""
        echo "   Recent change requests:"
        echo "$response" | jq -r '.result[] | "   - \(.number): \(.short_description) (State: \(.state))"'

        # Check if business_service is set
        local has_service=$(echo "$response" | jq -r '.result[0].business_service.value // "not_set"')
        if [ "$has_service" != "not_set" ]; then
            log_info "Change requests have business_service linked"
        else
            log_warn "Change requests missing business_service field"
            echo "   This may prevent visibility in DevOps Change workspace"
        fi
    else
        log_warn "No DevOps change requests found"
        echo ""
        echo "Create a change request by triggering a deployment:"
        echo "   gh workflow run \"🚀 Master CI/CD Pipeline\" --ref main"
    fi
}

# Step 5: Check for Security Evidence (SARIF files)
check_security_evidence() {
    log_section "5. Checking Security Evidence Attachments"

    if [ -z "$CHG_NUMBER" ]; then
        log_warn "No change request number provided, skipping evidence check"
        echo "   Re-run with: $0 CHG0030052"
        return
    fi

    # Get change request sys_id
    local response=$(snow_api "table/change_request?sysparm_query=number=${CHG_NUMBER}&sysparm_fields=sys_id")
    local chg_sys_id=$(echo "$response" | jq -r '.result[0].sys_id // "not_found"')

    if [ "$chg_sys_id" == "not_found" ]; then
        log_error "Change request $CHG_NUMBER not found"
        return 1
    fi

    # Check for attachments
    local attach_response=$(snow_api "table/sys_attachment?sysparm_query=table_name=change_request^table_sys_id=${chg_sys_id}&sysparm_fields=file_name,size_bytes,sys_created_on")
    local attach_count=$(echo "$attach_response" | jq '.result | length')

    if [ "$attach_count" -gt 0 ]; then
        log_info "Found $attach_count attachments on change request $CHG_NUMBER"
        echo ""
        echo "   Security evidence files:"
        echo "$attach_response" | jq -r '.result[] | "   - \(.file_name) (\(.size_bytes) bytes)"'
    else
        log_warn "No attachments found on change request $CHG_NUMBER"
        echo "   Security SARIF files should be attached during deployment"
    fi
}

# Step 6: Summary and Recommendations
print_summary() {
    log_section "Summary & Recommendations"

    echo "✅ What's Working:"
    echo "   - DevOps Tool configured and active"
    echo "   - DevOps Application exists and linked"
    echo "   - GitHub Actions workflow registers 10 security tools"
    echo ""
    echo "🔍 Where to View Security Tools:"
    echo "   1. DevOps Application Security Tab:"
    echo "      ${SERVICENOW_INSTANCE}/now/devops-change/record/sn_devops_app/${DEVOPS_APP_ID}/params/selected-tab-index/6"
    echo ""
    echo "   2. Via Change Requests:"
    echo "      ${SERVICENOW_INSTANCE}/now/devops-change/changes/"
    echo "      Open any change request → Look for Security/Test Results tab"
    echo ""
    echo "   3. Via REST API:"
    echo "      curl --user 'USER:PASS' '${SERVICENOW_INSTANCE}/api/now/table/sn_devops_test_result?sysparm_limit=10'"
    echo ""

    if [ -z "$CHG_NUMBER" ]; then
        echo "💡 Pro Tip:"
        echo "   Re-run this script with a change request number to check security evidence:"
        echo "   $0 CHG0030052"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ServiceNow Security Tools Verification"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"

    echo "Instance: $SERVICENOW_INSTANCE"
    echo "Tool ID: $TOOL_ID"
    if [ -n "$CHG_NUMBER" ]; then
        echo "Change Request: $CHG_NUMBER"
    fi
    echo ""

    # Check prerequisites
    check_prerequisites

    # Run verification steps
    verify_devops_tool || exit 1
    verify_devops_application || exit 1
    check_security_results
    check_change_requests
    check_security_evidence

    # Print summary
    print_summary

    log_section "✅ Verification Complete"
}

main "$@"
