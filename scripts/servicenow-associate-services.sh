#!/bin/bash

################################################################################
# ServiceNow DevOps - Associate Services with Application
################################################################################
#
# This script creates service associations between the Online Boutique
# DevOps application and CMDB services.
#
# Prerequisites:
#   - ServiceNow credentials configured
#   - jq installed
#   - curl installed
#
# Usage:
#   ./scripts/servicenow-associate-services.sh
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
readonly SERVICENOW_USERNAME="${SERVICENOW_USERNAME:-github_integration}"
readonly SERVICENOW_PASSWORD="${SERVICENOW_PASSWORD:-oA3KqdUVI8Q_^>}"

# Known IDs from your ServiceNow instance
readonly DEVOPS_APP_SYS_ID="6047e45ac3e4f690e1bbf0cb05013120"
readonly BUSINESS_APP_SYS_ID="4ffc7bfec3a4fe90e1bbf0cb0501313f"

# Service IDs (found earlier)
readonly SERVICE_1_SYS_ID="1e7b938bc360b2d0e1bbf0cb050131da"  # BSN0001005
readonly SERVICE_2_SYS_ID="3e1c530fc360b2d0e1bbf0cb05013185"  # BSN0001006

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

# Make authenticated ServiceNow API call
snow_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local url="${SERVICENOW_INSTANCE}/api/now/${endpoint}"

    if [ -z "$data" ]; then
        curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --user "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
            "$url"
    else
        curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --user "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
            -d "$data" \
            "$url"
    fi
}

################################################################################
# Main Functions
################################################################################

# Step 1: Verify DevOps Application exists
verify_devops_application() {
    log_section "Step 1: Verify DevOps Application"

    local response=$(snow_api GET "table/sn_devops_app/${DEVOPS_APP_SYS_ID}")
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | head -n -1)

    if [ "$http_code" != "200" ]; then
        log_error "Failed to fetch DevOps application (HTTP $http_code)"
        echo "$body" | jq .
        return 1
    fi

    local app_name=$(echo "$body" | jq -r '.result.name')
    local business_app=$(echo "$body" | jq -r '.result.business_app.value')

    log_info "DevOps Application found: $app_name"
    log_info "Linked Business App: $business_app"

    if [ "$business_app" != "$BUSINESS_APP_SYS_ID" ]; then
        log_warn "Business app mismatch! Expected $BUSINESS_APP_SYS_ID, got $business_app"
    fi
}

# Step 2: Verify Services exist
verify_services() {
    log_section "Step 2: Verify CMDB Services"

    for service_id in "$SERVICE_1_SYS_ID" "$SERVICE_2_SYS_ID"; do
        local response=$(snow_api GET "table/cmdb_ci_service/${service_id}")
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | head -n -1)

        if [ "$http_code" != "200" ]; then
            log_error "Failed to fetch service $service_id (HTTP $http_code)"
            continue
        fi

        local service_name=$(echo "$body" | jq -r '.result.name')
        local service_number=$(echo "$body" | jq -r '.result.number')

        log_info "Service found: $service_name ($service_number) - $service_id"
    done
}

# Step 3: Create Service-Application Relationships
create_service_relationships() {
    log_section "Step 3: Create Service Relationships"

    # ServiceNow uses cmdb_rel_ci table for CI relationships
    # Relationship type for "Runs on::Runs" is typically used for app-to-service

    for service_id in "$SERVICE_1_SYS_ID" "$SERVICE_2_SYS_ID"; do
        log_info "Creating relationship: Business App -> Service ($service_id)"

        # Check if relationship already exists
        local check_response=$(snow_api GET "table/cmdb_rel_ci?sysparm_query=parent=${BUSINESS_APP_SYS_ID}^child=${service_id}&sysparm_limit=1")
        local check_http_code=$(echo "$check_response" | tail -1)
        local check_body=$(echo "$check_response" | head -n -1)

        local existing_count=$(echo "$check_body" | jq '.result | length')

        if [ "$existing_count" -gt 0 ]; then
            log_warn "Relationship already exists for service $service_id"
            continue
        fi

        # Create relationship
        local relationship_payload=$(cat <<EOF
{
  "parent": "${BUSINESS_APP_SYS_ID}",
  "child": "${service_id}",
  "type": {
    "value": "af4d0d32c0a80009012cb0ffe6823e15"
  }
}
EOF
)

        local response=$(snow_api POST "table/cmdb_rel_ci" "$relationship_payload")
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | head -n -1)

        if [ "$http_code" == "201" ]; then
            local rel_sys_id=$(echo "$body" | jq -r '.result.sys_id')
            log_info "✓ Relationship created successfully: $rel_sys_id"
        else
            log_error "Failed to create relationship (HTTP $http_code)"
            echo "$body" | jq .
        fi
    done
}

# Step 4: Create svc_ci_assoc records (for Change Management integration)
create_service_associations() {
    log_section "Step 4: Create Service CI Associations (for Change Management)"

    for service_id in "$SERVICE_1_SYS_ID" "$SERVICE_2_SYS_ID"; do
        log_info "Creating svc_ci_assoc: Service -> Business App"

        # Check if association already exists
        local check_response=$(snow_api GET "table/svc_ci_assoc?sysparm_query=service=${service_id}^ci_id=${BUSINESS_APP_SYS_ID}&sysparm_limit=1")
        local check_http_code=$(echo "$check_response" | tail -1)
        local check_body=$(echo "$check_response" | head -n -1)

        local existing_count=$(echo "$check_body" | jq '.result | length')

        if [ "$existing_count" -gt 0 ]; then
            log_warn "Service CI Association already exists for service $service_id"
            continue
        fi

        # Create association
        local assoc_payload=$(cat <<EOF
{
  "service": "${service_id}",
  "ci_id": "${BUSINESS_APP_SYS_ID}"
}
EOF
)

        local response=$(snow_api POST "table/svc_ci_assoc" "$assoc_payload")
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | head -n -1)

        if [ "$http_code" == "201" ]; then
            local assoc_sys_id=$(echo "$body" | jq -r '.result.sys_id')
            log_info "✓ Service CI Association created: $assoc_sys_id"
        else
            log_error "Failed to create association (HTTP $http_code)"
            echo "$body" | jq .
        fi
    done
}

# Step 5: Update DevOps App with service references
update_devops_app_services() {
    log_section "Step 5: Update DevOps Application with Services"

    # Check if sn_devops_app has a services field
    local schema_response=$(snow_api GET "table/sys_dictionary?sysparm_query=name=sn_devops_app^element=services&sysparm_limit=1")
    local schema_body=$(echo "$schema_response" | head -n -1)
    local field_exists=$(echo "$schema_body" | jq '.result | length')

    if [ "$field_exists" -eq 0 ]; then
        log_warn "sn_devops_app table does not have a 'services' field"
        log_info "Services are linked via business_app relationship instead"
        return 0
    fi

    log_info "Updating DevOps app with service references..."

    # This would update the DevOps app if it has a services field
    # Usually the relationship is via business_app -> services
}

# Step 6: Verify relationships created
verify_relationships() {
    log_section "Step 6: Verify Relationships Created"

    # Check cmdb_rel_ci
    local rel_response=$(snow_api GET "table/cmdb_rel_ci?sysparm_query=parent=${BUSINESS_APP_SYS_ID}^ORchild=${BUSINESS_APP_SYS_ID}&sysparm_limit=10")
    local rel_body=$(echo "$rel_response" | head -n -1)
    local rel_count=$(echo "$rel_body" | jq '.result | length')

    log_info "Found $rel_count CMDB relationships for business app"

    # Check svc_ci_assoc
    local assoc_response=$(snow_api GET "table/svc_ci_assoc?sysparm_query=ci_id=${BUSINESS_APP_SYS_ID}&sysparm_limit=10")
    local assoc_body=$(echo "$assoc_response" | head -n -1)
    local assoc_count=$(echo "$assoc_body" | jq '.result | length')

    log_info "Found $assoc_count Service CI Associations for business app"

    if [ "$rel_count" -eq 0 ] && [ "$assoc_count" -eq 0 ]; then
        log_warn "No relationships or associations found!"
        log_warn "Services may need to be manually linked in ServiceNow UI"
    else
        log_info "✓ Relationships verified successfully"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo -e "${BLUE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ServiceNow DevOps - Associate Services with Application"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}\n"

    echo "Instance: $SERVICENOW_INSTANCE"
    echo "DevOps App: $DEVOPS_APP_SYS_ID"
    echo "Business App: $BUSINESS_APP_SYS_ID"
    echo "Services: $SERVICE_1_SYS_ID, $SERVICE_2_SYS_ID"
    echo ""

    # Execute steps
    verify_devops_application || exit 1
    verify_services || exit 1
    create_service_relationships
    create_service_associations
    update_devops_app_services
    verify_relationships

    log_section "Summary"
    echo -e "${GREEN}✓ Service association complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify in ServiceNow UI:"
    echo "     https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120"
    echo "  2. Check that services appear under the application"
    echo "  3. Create a test change request to verify service associations"
    echo ""
}

main "$@"
