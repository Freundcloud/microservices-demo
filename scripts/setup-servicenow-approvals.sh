#!/usr/bin/env bash

#===============================================================================
# ServiceNow Approval Groups Setup Script
#===============================================================================
# Purpose: Automate creation of approval groups and basic configuration
# Usage:   bash scripts/setup-servicenow-approvals.sh
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for required environment variables
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

    # Check for required tools
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create Basic Auth header
BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# Test ServiceNow connectivity
test_connectivity() {
    log_info "Testing ServiceNow connectivity..."

    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1")

    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Failed to connect to ServiceNow (HTTP ${HTTP_CODE})"
        exit 1
    fi

    log_success "ServiceNow connectivity verified"
}

# Get current user sys_id (for setting as manager)
get_current_user() {
    log_info "Getting current user information..."

    USER_INFO=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_query=user_name=${SERVICENOW_USERNAME}&sysparm_fields=sys_id,name,email" \
        | jq -r '.result[0]')

    CURRENT_USER_SYS_ID=$(echo "$USER_INFO" | jq -r '.sys_id')
    CURRENT_USER_NAME=$(echo "$USER_INFO" | jq -r '.name')

    if [ "$CURRENT_USER_SYS_ID" == "null" ]; then
        log_error "Could not find current user"
        exit 1
    fi

    log_success "Current user: $CURRENT_USER_NAME (${CURRENT_USER_SYS_ID})"
}

# Create or update a user group
create_group() {
    local group_name="$1"
    local group_description="$2"
    local manager_sys_id="$3"

    log_info "Creating/updating group: $group_name..."

    # Check if group exists
    EXISTING_GROUP=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_group?sysparm_query=name=${group_name}&sysparm_fields=sys_id,name" \
        | jq -r '.result[0]')

    GROUP_SYS_ID=$(echo "$EXISTING_GROUP" | jq -r '.sys_id')

    if [ "$GROUP_SYS_ID" != "null" ] && [ -n "$GROUP_SYS_ID" ]; then
        log_warning "Group '$group_name' already exists (${GROUP_SYS_ID})"
        log_info "Updating existing group..."

        # Update existing group
        curl -s -X PUT \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" \
            -d "{\"description\":\"${group_description}\",\"manager\":\"${manager_sys_id}\"}" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_group/${GROUP_SYS_ID}" \
            > /dev/null

        log_success "Group '$group_name' updated"
    else
        # Create new group
        CREATE_RESPONSE=$(curl -s -X POST \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${group_name}\",\"description\":\"${group_description}\",\"manager\":\"${manager_sys_id}\",\"active\":\"true\"}" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_group")

        GROUP_SYS_ID=$(echo "$CREATE_RESPONSE" | jq -r '.result.sys_id')

        if [ "$GROUP_SYS_ID" == "null" ]; then
            log_error "Failed to create group '$group_name'"
            echo "$CREATE_RESPONSE" | jq .
            return 1
        fi

        log_success "Group '$group_name' created (${GROUP_SYS_ID})"
    fi

    echo "$GROUP_SYS_ID"
}

# Add member to group
add_group_member() {
    local group_sys_id="$1"
    local user_sys_id="$2"

    # Check if already a member
    EXISTING_MEMBER=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_grmember?sysparm_query=group=${group_sys_id}^user=${user_sys_id}&sysparm_fields=sys_id" \
        | jq -r '.result[0].sys_id')

    if [ "$EXISTING_MEMBER" != "null" ] && [ -n "$EXISTING_MEMBER" ]; then
        log_info "User already a member of group"
        return 0
    fi

    # Add member
    curl -s -X POST \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" \
        -d "{\"group\":\"${group_sys_id}\",\"user\":\"${user_sys_id}\"}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_grmember" \
        > /dev/null

    log_success "User added to group"
}

# Create approval groups
create_approval_groups() {
    log_info "Creating approval groups..."

    # 1. QA Team
    log_info ""
    log_info "=== QA Team Group ==="
    QA_TEAM_SYS_ID=$(create_group \
        "QA Team" \
        "Quality Assurance team responsible for QA environment approvals" \
        "${CURRENT_USER_SYS_ID}")

    # Add current user as member
    add_group_member "$QA_TEAM_SYS_ID" "$CURRENT_USER_SYS_ID"

    # 2. DevOps Team
    log_info ""
    log_info "=== DevOps Team Group ==="
    DEVOPS_TEAM_SYS_ID=$(create_group \
        "DevOps Team" \
        "DevOps engineers responsible for infrastructure and deployments" \
        "${CURRENT_USER_SYS_ID}")

    # Add current user as member
    add_group_member "$DEVOPS_TEAM_SYS_ID" "$CURRENT_USER_SYS_ID"

    # 3. Change Advisory Board
    log_info ""
    log_info "=== Change Advisory Board Group ==="
    CAB_SYS_ID=$(create_group \
        "Change Advisory Board" \
        "Executive board for production change approvals" \
        "${CURRENT_USER_SYS_ID}")

    # Add current user as member
    add_group_member "$CAB_SYS_ID" "$CURRENT_USER_SYS_ID"

    log_info ""
    log_success "All approval groups created/updated"

    # Export group IDs for reference
    echo ""
    echo "Group IDs (save these for configuration):"
    echo "==========================================="
    echo "QA Team:                  $QA_TEAM_SYS_ID"
    echo "DevOps Team:              $DEVOPS_TEAM_SYS_ID"
    echo "Change Advisory Board:    $CAB_SYS_ID"
    echo ""
}

# Verify groups
verify_groups() {
    log_info "Verifying groups..."

    GROUPS=("QA Team" "DevOps Team" "Change Advisory Board")

    for group_name in "${GROUPS[@]}"; do
        GROUP_DATA=$(curl -s \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_group?sysparm_query=name=${group_name}&sysparm_fields=sys_id,name,manager.name,active" \
            | jq -r '.result[0]')

        GROUP_SYS_ID=$(echo "$GROUP_DATA" | jq -r '.sys_id')
        MANAGER_NAME=$(echo "$GROUP_DATA" | jq -r '.["manager.name"]')
        ACTIVE=$(echo "$GROUP_DATA" | jq -r '.active')

        if [ "$GROUP_SYS_ID" != "null" ]; then
            log_success "✓ $group_name (Manager: $MANAGER_NAME, Active: $ACTIVE)"
        else
            log_error "✗ $group_name not found"
        fi
    done
}

# Print summary and next steps
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "           ServiceNow Approval Groups Setup Complete           "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    log_success "✓ QA Team group configured"
    log_success "✓ DevOps Team group configured"
    log_success "✓ Change Advisory Board group configured"
    echo ""
    echo "Next Steps:"
    echo "───────────"
    echo ""
    echo "1. Add additional members to groups:"
    echo "   https://${SERVICENOW_INSTANCE_URL#https://}/sys_user_group_list.do"
    echo ""
    echo "2. Configure approval rules (must be done via UI):"
    echo "   https://${SERVICENOW_INSTANCE_URL#https://}/change_approval_rule_list.do"
    echo ""
    echo "3. Test approval workflow:"
    echo "   gh workflow run deploy-with-servicenow.yaml --field environment=qa"
    echo ""
    echo "4. View complete setup guide:"
    echo "   docs/SERVICENOW-APPROVALS.md"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "       ServiceNow Approval Groups Setup Script                 "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    check_prerequisites
    test_connectivity
    get_current_user
    create_approval_groups
    verify_groups
    print_summary
}

# Run main function
main
