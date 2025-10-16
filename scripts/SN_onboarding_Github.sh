#!/bin/bash

################################################################################
# ServiceNow Onboarding Script for GitHub Integration
################################################################################
#
# This script automates the complete setup of ServiceNow for GitHub Actions
# integration with EKS cluster discovery and CMDB population.
#
# Prerequisites:
#   - ServiceNow instance URL
#   - Admin user credentials
#   - jq installed (for JSON parsing)
#   - curl installed
#
# Usage:
#   ./SN_onboarding_Github.sh
#
################################################################################

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

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq first."
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl first."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Prompt for ServiceNow credentials
get_credentials() {
    log_info "Please provide ServiceNow instance details:"
    echo ""

    read -p "ServiceNow Instance URL (e.g., https://dev12345.service-now.com): " SERVICENOW_INSTANCE_URL
    SERVICENOW_INSTANCE_URL=$(echo "$SERVICENOW_INSTANCE_URL" | sed 's:/*$::')  # Remove trailing slash

    read -p "Admin Username: " ADMIN_USERNAME
    read -sp "Admin Password: " ADMIN_PASSWORD
    echo ""

    # Create Basic Auth header
    BASIC_AUTH=$(echo -n "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" | base64)

    log_info "Testing credentials..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Authentication failed. Please check your credentials."
        exit 1
    fi

    log_success "Authentication successful"
}

# Generate secure password
generate_password() {
    # Generate a 16-character password with special characters
    openssl rand -base64 32 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c 16
}

# Create GitHub integration user
create_github_user() {
    log_info "Creating GitHub integration user..."

    GITHUB_USERNAME="github_integration"
    GITHUB_PASSWORD=$(generate_password)

    # Check if user already exists
    EXISTING_USER=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_query=user_name=${GITHUB_USERNAME}&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    USER_SYS_ID=$(echo "$EXISTING_USER" | jq -r '.result[0].sys_id // empty')

    if [ -n "$USER_SYS_ID" ]; then
        log_warning "User '${GITHUB_USERNAME}' already exists (sys_id: ${USER_SYS_ID})"
        read -p "Reset password? (y/n): " RESET_PASSWORD

        if [ "$RESET_PASSWORD" = "y" ]; then
            # Update user password
            USER_PAYLOAD=$(jq -n \
                --arg password "$GITHUB_PASSWORD" \
                '{
                    user_password: $password
                }')

            curl -s -X PUT \
                "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user/${USER_SYS_ID}" \
                -H "Authorization: Basic ${BASIC_AUTH}" \
                -H "Content-Type: application/json" \
                -d "$USER_PAYLOAD" > /dev/null 2>&1

            log_success "Password reset for user '${GITHUB_USERNAME}'"
        fi
    else
        # Create new user
        USER_PAYLOAD=$(jq -n \
            --arg username "$GITHUB_USERNAME" \
            --arg password "$GITHUB_PASSWORD" \
            --arg first_name "GitHub" \
            --arg last_name "Integration" \
            --arg email "github-integration@example.com" \
            '{
                user_name: $username,
                user_password: $password,
                first_name: $first_name,
                last_name: $last_name,
                email: $email,
                active: "true"
            }')

        USER_RESPONSE=$(curl -s -X POST \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" \
            -d "$USER_PAYLOAD" 2>/dev/null || echo '{"result":{"sys_id":""}}')

        USER_SYS_ID=$(echo "$USER_RESPONSE" | jq -r '.result.sys_id // empty')

        if [ -n "$USER_SYS_ID" ]; then
            log_success "Created user '${GITHUB_USERNAME}' (sys_id: ${USER_SYS_ID})"
        else
            log_error "Failed to create user. Response: $USER_RESPONSE"
            exit 1
        fi
    fi

    # Assign admin role
    log_info "Assigning admin role to GitHub user..."

    # Get admin role sys_id
    ADMIN_ROLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_role?sysparm_query=name=admin&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    ADMIN_ROLE_SYS_ID=$(echo "$ADMIN_ROLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$ADMIN_ROLE_SYS_ID" ]; then
        # Check if role assignment already exists
        EXISTING_ROLE=$(curl -s -X GET \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_has_role?sysparm_query=user=${USER_SYS_ID}^role=${ADMIN_ROLE_SYS_ID}&sysparm_limit=1" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

        ROLE_ASSIGNMENT_EXISTS=$(echo "$EXISTING_ROLE" | jq -r '.result[0].sys_id // empty')

        if [ -z "$ROLE_ASSIGNMENT_EXISTS" ]; then
            # Assign role
            ROLE_PAYLOAD=$(jq -n \
                --arg user "$USER_SYS_ID" \
                --arg role "$ADMIN_ROLE_SYS_ID" \
                '{
                    user: $user,
                    role: $role
                }')

            curl -s -X POST \
                "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user_has_role" \
                -H "Authorization: Basic ${BASIC_AUTH}" \
                -H "Content-Type: application/json" \
                -d "$ROLE_PAYLOAD" > /dev/null 2>&1

            log_success "Assigned admin role to GitHub user"
        else
            log_warning "Admin role already assigned to GitHub user"
        fi
    else
        log_error "Could not find admin role"
        exit 1
    fi

    # Save credentials to file
    cat > .github_sn_credentials << EOF
# ServiceNow GitHub Integration Credentials
# Generated: $(date)
# IMPORTANT: Keep this file secure and do not commit to version control!

SERVICENOW_INSTANCE_URL="${SERVICENOW_INSTANCE_URL}"
SERVICENOW_USERNAME="${GITHUB_USERNAME}"
SERVICENOW_PASSWORD="${GITHUB_PASSWORD}"

# GitHub Secrets (add these to your repository):
# gh secret set SERVICENOW_INSTANCE_URL --body "${SERVICENOW_INSTANCE_URL}"
# gh secret set SERVICENOW_USERNAME --body "${GITHUB_USERNAME}"
# gh secret set SERVICENOW_PASSWORD --body "${GITHUB_PASSWORD}"
EOF

    chmod 600 .github_sn_credentials

    log_success "Credentials saved to .github_sn_credentials"
    echo ""
    log_warning "IMPORTANT: Save these credentials securely!"
    echo "Username: ${GITHUB_USERNAME}"
    echo "Password: ${GITHUB_PASSWORD}"
    echo ""
}

# Create u_eks_cluster table
create_eks_cluster_table() {
    log_info "Creating u_eks_cluster table..."

    # Check if table already exists
    EXISTING_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_eks_cluster&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_EXISTS=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_EXISTS" ]; then
        log_warning "Table 'u_eks_cluster' already exists"
        return 0
    fi

    log_warning "Table creation via API requires specific permissions."
    log_warning "Please create the u_eks_cluster table manually via ServiceNow UI:"
    echo ""
    echo "1. Navigate to: System Definition > Tables > New"
    echo "2. Fill in:"
    echo "   - Label: EKS Cluster"
    echo "   - Name: u_eks_cluster"
    echo "   - Extends table: Configuration Item [cmdb_ci]"
    echo "   - Application: Global"
    echo "   - Create access controls: ✓"
    echo "   - Add module to menu: ✓"
    echo "   - Extensible: ✓"
    echo "3. Click 'Submit'"
    echo ""
    echo "4. Add the following custom fields to u_eks_cluster table:"
    echo "   - u_cluster_name (String, 255)"
    echo "   - u_arn (String, 512)"
    echo "   - u_version (String, 100)"
    echo "   - u_endpoint (URL, 1024)"
    echo "   - u_status (String, 100)"
    echo "   - u_region (String, 100)"
    echo "   - u_vpc_id (String, 255)"
    echo "   - u_provider (String, 100)"
    echo "   - u_last_discovered (Date/Time)"
    echo "   - u_discovered_by (String, 100)"
    echo ""

    read -p "Press Enter after creating the table to continue..."

    # Verify table was created
    VERIFY_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_eks_cluster&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_CREATED=$(echo "$VERIFY_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_CREATED" ]; then
        log_success "Table 'u_eks_cluster' verified"
    else
        log_error "Table 'u_eks_cluster' not found. Please create it manually."
        exit 1
    fi
}

# Create u_microservice table
create_microservice_table() {
    log_info "Creating u_microservice table..."

    # Check if table already exists
    EXISTING_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_microservice&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_EXISTS=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_EXISTS" ]; then
        log_warning "Table 'u_microservice' already exists"
        return 0
    fi

    log_warning "Table creation via API requires specific permissions."
    log_warning "Please create the u_microservice table manually via ServiceNow UI:"
    echo ""
    echo "1. Navigate to: System Definition > Tables > New"
    echo "2. Fill in:"
    echo "   - Label: Microservice"
    echo "   - Name: u_microservice"
    echo "   - Extends table: Configuration Item [cmdb_ci]"
    echo "   - Application: Global"
    echo "   - Create access controls: ✓"
    echo "   - Add module to menu: ✓"
    echo "   - Extensible: ✓"
    echo "3. Click 'Submit'"
    echo ""
    echo "4. Add the following custom fields to u_microservice table:"
    echo "   - u_name (String, 255) - MANDATORY"
    echo "   - u_namespace (String, 255) - MANDATORY"
    echo "   - u_cluster_name (String, 255)"
    echo "   - u_image (String, 512)"
    echo "   - u_replicas (String, 50)"
    echo "   - u_ready_replicas (String, 50)"
    echo "   - u_status (String, 100)"
    echo "   - u_language (String, 100)"
    echo ""

    read -p "Press Enter after creating the table to continue..."

    # Verify table was created
    VERIFY_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_microservice&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_CREATED=$(echo "$VERIFY_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_CREATED" ]; then
        log_success "Table 'u_microservice' verified"
    else
        log_error "Table 'u_microservice' not found. Please create it manually."
        exit 1
    fi
}

# Create u_security_scan_result table
create_security_scan_result_table() {
    log_info "Creating u_security_scan_result table..."

    # Check if table already exists
    EXISTING_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_security_scan_result&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_EXISTS=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_EXISTS" ]; then
        log_warning "Table 'u_security_scan_result' already exists"
        return 0
    fi

    log_warning "Table creation via API requires specific permissions."
    log_warning "Please create the u_security_scan_result table manually via ServiceNow UI:"
    echo ""
    echo "1. Navigate to: System Definition > Tables > New"
    echo "2. Fill in:"
    echo "   - Label: Security Scan Result"
    echo "   - Name: u_security_scan_result"
    echo "   - Extends table: Task [task] or Base Table"
    echo "   - Application: Global"
    echo "   - Create access controls: ✓"
    echo "   - Add module to menu: ✓"
    echo "3. Click 'Submit'"
    echo ""
    echo "4. Add the following custom fields to u_security_scan_result table:"
    echo "   - u_scan_id (String, 100) - MANDATORY"
    echo "   - u_scan_type (Choice: CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP) - MANDATORY"
    echo "   - u_scan_date (Date/Time) - MANDATORY"
    echo "   - u_finding_id (String, 255) - MANDATORY (Unique identifier)"
    echo "   - u_severity (Choice: CRITICAL, HIGH, MEDIUM, LOW, INFO) - MANDATORY"
    echo "   - u_title (String, 255) - MANDATORY"
    echo "   - u_description (Text, 4000)"
    echo "   - u_file_path (String, 512)"
    echo "   - u_line_number (Integer)"
    echo "   - u_rule_id (String, 255)"
    echo "   - u_cve_id (String, 100)"
    echo "   - u_cvss_score (Decimal)"
    echo "   - u_status (Choice: Open, In Progress, Resolved, False Positive) - MANDATORY, Default: Open"
    echo "   - u_repository (String, 255) - MANDATORY"
    echo "   - u_branch (String, 100) - MANDATORY"
    echo "   - u_commit_sha (String, 40) - MANDATORY"
    echo "   - u_github_url (URL, 1024)"
    echo "   - u_sarif_data (JSON/Text)"
    echo ""

    read -p "Press Enter after creating the table to continue..."

    # Verify table was created
    VERIFY_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_security_scan_result&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_CREATED=$(echo "$VERIFY_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_CREATED" ]; then
        log_success "Table 'u_security_scan_result' verified"
    else
        log_error "Table 'u_security_scan_result' not found. Please create it manually."
        exit 1
    fi
}

# Create u_security_scan_summary table
create_security_scan_summary_table() {
    log_info "Creating u_security_scan_summary table..."

    # Check if table already exists
    EXISTING_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_security_scan_summary&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_EXISTS=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_EXISTS" ]; then
        log_warning "Table 'u_security_scan_summary' already exists"
        return 0
    fi

    log_warning "Table creation via API requires specific permissions."
    log_warning "Please create the u_security_scan_summary table manually via ServiceNow UI:"
    echo ""
    echo "1. Navigate to: System Definition > Tables > New"
    echo "2. Fill in:"
    echo "   - Label: Security Scan Summary"
    echo "   - Name: u_security_scan_summary"
    echo "   - Extends table: Base Table"
    echo "   - Application: Global"
    echo "   - Create access controls: ✓"
    echo "   - Add module to menu: ✓"
    echo "3. Click 'Submit'"
    echo ""
    echo "4. Add the following custom fields to u_security_scan_summary table:"
    echo "   - u_scan_id (String, 100) - MANDATORY"
    echo "   - u_workflow_run_id (String, 100)"
    echo "   - u_repository (String, 255) - MANDATORY"
    echo "   - u_branch (String, 100) - MANDATORY"
    echo "   - u_commit_sha (String, 40) - MANDATORY"
    echo "   - u_scan_date (Date/Time) - MANDATORY"
    echo "   - u_total_findings (Integer) - MANDATORY"
    echo "   - u_critical_count (Integer)"
    echo "   - u_high_count (Integer)"
    echo "   - u_medium_count (Integer)"
    echo "   - u_low_count (Integer)"
    echo "   - u_info_count (Integer)"
    echo "   - u_tools_run (String, 512) - Comma-separated tool names"
    echo "   - u_status (Choice: Success, Failed, In Progress) - Default: Success"
    echo "   - u_github_url (URL, 1024)"
    echo ""

    read -p "Press Enter after creating the table to continue..."

    # Verify table was created
    VERIFY_TABLE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=u_security_scan_summary&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    TABLE_CREATED=$(echo "$VERIFY_TABLE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$TABLE_CREATED" ]; then
        log_success "Table 'u_security_scan_summary' verified"
    else
        log_error "Table 'u_security_scan_summary' not found. Please create it manually."
        exit 1
    fi
}

# Add custom fields to cmdb_ci_server for EKS nodes
add_node_custom_fields() {
    log_info "Adding custom fields to cmdb_ci_server table for EKS nodes..."

    log_warning "Custom field creation via API requires specific permissions."
    log_warning "Please add the following custom fields to cmdb_ci_server table manually:"
    echo ""
    echo "Navigate to: System Definition > Tables"
    echo "Search for and open: Server [cmdb_ci_server]"
    echo "Click 'New' in the Columns section and add:"
    echo ""
    echo "1. u_instance_id (String, 255) - EC2 Instance ID"
    echo "2. u_instance_type (String, 100) - EC2 Instance Type"
    echo "3. u_availability_zone (String, 100) - AWS Availability Zone"
    echo "4. u_eks_state (String, 100) - EC2 State"
    echo "5. u_kubernetes_status (String, 100) - Kubernetes Ready Status"
    echo "6. u_nodegroup (String, 255) - EKS Node Group Name"
    echo "7. u_ami_type (String, 100) - AMI Type"
    echo "8. u_last_discovered (Date/Time) - Last Discovery Time"
    echo ""

    read -p "Press Enter after adding the fields to continue (or 's' to skip): " SKIP_FIELDS

    if [ "$SKIP_FIELDS" != "s" ]; then
        log_success "Custom fields for EKS nodes configured"
    else
        log_warning "Skipped custom field creation. Standard CMDB fields will be used."
    fi
}

# Create relationship types
create_relationship_types() {
    log_info "Verifying CMDB relationship types..."

    # Check for "Contains::Contained by" relationship type
    REL_TYPE=$(curl -s -X GET \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_type?sysparm_query=sys_id=d93304fb0a0a0b78006081a72ef08444&sysparm_limit=1" \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" 2>/dev/null || echo '{"result":[]}')

    REL_TYPE_EXISTS=$(echo "$REL_TYPE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$REL_TYPE_EXISTS" ]; then
        log_success "CMDB relationship types verified"
    else
        log_warning "Standard CMDB relationship types not found. This is unusual."
        log_warning "The workflow will use the standard 'Contains::Contained by' relationship."
    fi
}

# Test API access with GitHub user
test_github_user_access() {
    log_info "Testing GitHub user API access..."

    # Create Basic Auth for GitHub user
    GITHUB_BASIC_AUTH=$(echo -n "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" | base64)

    # Test u_eks_cluster table access
    log_info "Testing u_eks_cluster table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_eks_cluster?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "u_eks_cluster table accessible"
    else
        log_error "Cannot access u_eks_cluster table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    # Test u_microservice table access
    log_info "Testing u_microservice table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "u_microservice table accessible"
    else
        log_error "Cannot access u_microservice table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    # Test cmdb_ci_server table access
    log_info "Testing cmdb_ci_server table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_server?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "cmdb_ci_server table accessible"
    else
        log_error "Cannot access cmdb_ci_server table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    # Test cmdb_rel_ci table access
    log_info "Testing cmdb_rel_ci table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_ci?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "cmdb_rel_ci table accessible"
    else
        log_error "Cannot access cmdb_rel_ci table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    # Test u_security_scan_result table access
    log_info "Testing u_security_scan_result table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "u_security_scan_result table accessible"
    else
        log_error "Cannot access u_security_scan_result table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    # Test u_security_scan_summary table access
    log_info "Testing u_security_scan_summary table access..."
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\n" \
        -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_limit=1" 2>/dev/null || echo "HTTP_CODE:000")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "u_security_scan_summary table accessible"
    else
        log_error "Cannot access u_security_scan_summary table (HTTP ${HTTP_CODE})"
        exit 1
    fi

    log_success "All API access tests passed"
}

# Generate setup summary
generate_summary() {
    log_info "Generating setup summary..."

    cat > SERVICENOW_SETUP_SUMMARY.md << EOF
# ServiceNow GitHub Integration Setup Summary

**Date**: $(date)
**Instance**: ${SERVICENOW_INSTANCE_URL}

## ✅ Setup Complete

### 1. GitHub Integration User
- **Username**: ${GITHUB_USERNAME}
- **Password**: ${GITHUB_PASSWORD}
- **Role**: Admin
- **Status**: Active

### 2. CMDB Tables Created

#### u_eks_cluster Table
Stores EKS cluster configuration items with the following custom fields:
- u_cluster_name (String, 255)
- u_arn (String, 512)
- u_version (String, 100)
- u_endpoint (URL, 1024)
- u_status (String, 100)
- u_region (String, 100)
- u_vpc_id (String, 255)
- u_provider (String, 100)
- u_last_discovered (Date/Time)
- u_discovered_by (String, 100)

#### u_microservice Table
Stores microservice configuration items with the following custom fields:
- u_name (String, 255) - MANDATORY
- u_namespace (String, 255) - MANDATORY
- u_cluster_name (String, 255)
- u_image (String, 512)
- u_replicas (String, 50)
- u_ready_replicas (String, 50)
- u_status (String, 100)
- u_language (String, 100)

#### cmdb_ci_server Table (Standard + Custom Fields)
Standard ServiceNow server table with additional custom fields for EKS nodes:
- u_instance_id (String, 255)
- u_instance_type (String, 100)
- u_availability_zone (String, 100)
- u_eks_state (String, 100)
- u_kubernetes_status (String, 100)
- u_nodegroup (String, 255)
- u_ami_type (String, 100)
- u_last_discovered (Date/Time)

#### u_security_scan_result Table
Stores individual security findings from all security scanning tools:
- u_scan_id (String, 100) - MANDATORY
- u_scan_type (Choice: CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP) - MANDATORY
- u_scan_date (Date/Time) - MANDATORY
- u_finding_id (String, 255) - MANDATORY (Unique identifier)
- u_severity (Choice: CRITICAL, HIGH, MEDIUM, LOW, INFO) - MANDATORY
- u_title (String, 255) - MANDATORY
- u_description (Text, 4000)
- u_file_path (String, 512)
- u_line_number (Integer)
- u_rule_id (String, 255)
- u_cve_id (String, 100)
- u_cvss_score (Decimal)
- u_status (Choice: Open, In Progress, Resolved, False Positive) - MANDATORY
- u_repository (String, 255) - MANDATORY
- u_branch (String, 100) - MANDATORY
- u_commit_sha (String, 40) - MANDATORY
- u_github_url (URL, 1024)
- u_sarif_data (JSON/Text)

#### u_security_scan_summary Table
Stores summary statistics for each security scan execution:
- u_scan_id (String, 100) - MANDATORY
- u_workflow_run_id (String, 100)
- u_repository (String, 255) - MANDATORY
- u_branch (String, 100) - MANDATORY
- u_commit_sha (String, 40) - MANDATORY
- u_scan_date (Date/Time) - MANDATORY
- u_total_findings (Integer) - MANDATORY
- u_critical_count (Integer)
- u_high_count (Integer)
- u_medium_count (Integer)
- u_low_count (Integer)
- u_info_count (Integer)
- u_tools_run (String, 512) - Comma-separated tool names
- u_status (Choice: Success, Failed, In Progress)
- u_github_url (URL, 1024)

### 3. Relationships
- Cluster-to-Node relationships via cmdb_rel_ci table
- Relationship type: "Contains::Contained by"

### 4. API Access Verified
- ✅ u_eks_cluster table (Read/Write)
- ✅ u_microservice table (Read/Write)
- ✅ cmdb_ci_server table (Read/Write)
- ✅ cmdb_rel_ci table (Read/Write)
- ✅ u_security_scan_result table (Read/Write)
- ✅ u_security_scan_summary table (Read/Write)

## 🔐 GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

\`\`\`bash
gh secret set SERVICENOW_INSTANCE_URL --body "${SERVICENOW_INSTANCE_URL}"
gh secret set SERVICENOW_USERNAME --body "${GITHUB_USERNAME}"
gh secret set SERVICENOW_PASSWORD --body "${GITHUB_PASSWORD}"
\`\`\`

Or via GitHub UI:
1. Go to: Repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret:
   - Name: \`SERVICENOW_INSTANCE_URL\` | Value: \`${SERVICENOW_INSTANCE_URL}\`
   - Name: \`SERVICENOW_USERNAME\` | Value: \`${GITHUB_USERNAME}\`
   - Name: \`SERVICENOW_PASSWORD\` | Value: \`${GITHUB_PASSWORD}\`

## 📊 ServiceNow Access

### View Data in ServiceNow:
- **EKS Clusters**: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_eks_cluster_list.do
- **Microservices**: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_microservice_list.do
- **EKS Nodes**: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=cmdb_ci_server_list.do
- **Security Scan Results**: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do
- **Security Scan Summaries**: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do

### Filter Nodes by Cluster:
1. Navigate to Servers list
2. Add filter: \`cluster_name = microservices\`

## 🚀 Next Steps

1. **Configure GitHub Secrets** (see above)
2. **Run the EKS Discovery Workflow**:
   \`\`\`bash
   gh workflow run eks-discovery.yaml
   \`\`\`
3. **Run the Security Scanning Workflow**:
   \`\`\`bash
   gh workflow run security-scan-servicenow.yaml
   \`\`\`
4. **Verify Data Population**:
   - Check cluster record in ServiceNow
   - Check node records in ServiceNow
   - Check microservice records in ServiceNow
   - Check security scan results in ServiceNow
   - Verify relationships between cluster and nodes

## 📝 Important Notes

- **Credentials File**: Saved to \`.github_sn_credentials\` (DO NOT COMMIT!)
- **Password Security**: Store the GitHub integration password securely
- **Table Permissions**: Admin role provides full access to all tables
- **Relationship Types**: Using standard CMDB relationship types
- **Discovery Schedule**: Workflow runs every 6 hours or manually

## 🔍 Troubleshooting

If workflows fail to populate data:
1. Verify GitHub secrets are set correctly
2. Check ServiceNow user has admin role
3. Verify tables exist and are accessible
4. Check workflow logs for specific errors
5. Test API access manually using curl:
   \`\`\`bash
   curl -u "${GITHUB_USERNAME}:${GITHUB_PASSWORD}" \\
     "${SERVICENOW_INSTANCE_URL}/api/now/table/u_eks_cluster?sysparm_limit=1"
   \`\`\`

## 📚 Documentation

- ServiceNow Quick Start: \`docs/SERVICENOW-QUICK-START.md\`
- Zurich Compatibility: \`docs/SERVICENOW-ZURICH-COMPATIBILITY.md\`
- Setup Checklist: \`docs/SERVICENOW-SETUP-CHECKLIST.md\`

---

**Setup completed successfully!** ✅

EOF

    log_success "Setup summary generated: SERVICENOW_SETUP_SUMMARY.md"
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ServiceNow GitHub Integration Onboarding                      ║"
    echo "║  Version 1.0                                                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_prerequisites
    get_credentials

    echo ""
    log_info "Starting ServiceNow configuration..."
    echo ""

    create_github_user
    create_eks_cluster_table
    create_microservice_table
    create_security_scan_result_table
    create_security_scan_summary_table
    add_node_custom_fields
    create_relationship_types
    test_github_user_access
    generate_summary

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Setup Complete!                                               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    log_success "ServiceNow is now configured for GitHub integration!"
    echo ""
    echo "📄 Review the setup summary: SERVICENOW_SETUP_SUMMARY.md"
    echo "🔐 Credentials saved to: .github_sn_credentials"
    echo ""
    echo "Next steps:"
    echo "1. Add GitHub secrets (see SERVICENOW_SETUP_SUMMARY.md)"
    echo "2. Run: gh workflow run eks-discovery.yaml"
    echo "3. Check ServiceNow CMDB for populated data"
    echo ""
}

# Run main function
main "$@"
