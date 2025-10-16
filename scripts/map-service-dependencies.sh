#!/usr/bin/env bash

#===============================================================================
# ServiceNow Service Dependency Mapping Script
#===============================================================================
# Purpose: Create CMDB relationships for all microservices
# Usage:   bash scripts/map-service-dependencies.sh
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
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

BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# Service dependency map based on architecture
# Format: "parent:child1,child2,child3"
declare -a DEPENDENCIES=(
    "frontend:cartservice,productcatalogservice,currencyservice,recommendationservice,adservice,checkoutservice"
    "cartservice:redis-cart"
    "checkoutservice:paymentservice,shippingservice,emailservice,currencyservice"
)

# Get service sys_id by name
get_service_sys_id() {
    local service_name="$1"
    local namespace="${2:-}"

    local query="u_name=${service_name}"
    if [ -n "$namespace" ]; then
        query="${query}^u_namespace=${namespace}"
    fi

    local sys_id=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice?sysparm_query=${query}&sysparm_fields=sys_id&sysparm_limit=1" \
        | jq -r '.result[0].sys_id // empty')

    echo "$sys_id"
}

# Create relationship between two services
create_relationship() {
    local parent_sys_id="$1"
    local child_sys_id="$2"
    local parent_name="$3"
    local child_name="$4"

    # Check if relationship already exists
    local existing=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_ci?sysparm_query=parent=${parent_sys_id}^child=${child_sys_id}&sysparm_fields=sys_id" \
        | jq -r '.result[0].sys_id // empty')

    if [ -n "$existing" ]; then
        log_warning "Relationship already exists: ${parent_name} → ${child_name}"
        return 0
    fi

    # Create relationship (Uses::Used by)
    local response=$(curl -s -X POST \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" \
        -d "{
            \"parent\": \"${parent_sys_id}\",
            \"child\": \"${child_sys_id}\",
            \"type\": \"d93304fb0a0a0b78006081a72ef08444\"
        }" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_ci")

    local rel_sys_id=$(echo "$response" | jq -r '.result.sys_id // empty')

    if [ -n "$rel_sys_id" ]; then
        log_success "Created: ${parent_name} → ${child_name}"
    else
        log_error "Failed to create relationship: ${parent_name} → ${child_name}"
        echo "$response" | jq .
        return 1
    fi
}

# Map dependencies for a specific namespace
map_namespace_dependencies() {
    local namespace="$1"

    log_info "Mapping dependencies for namespace: ${namespace}"
    echo ""

    local created_count=0
    local skipped_count=0
    local error_count=0

    for dep in "${DEPENDENCIES[@]}"; do
        IFS=':' read -r parent children <<< "$dep"

        parent_sys_id=$(get_service_sys_id "$parent" "$namespace")

        if [ -z "$parent_sys_id" ]; then
            log_warning "Parent service not found: ${parent} in ${namespace}"
            ((error_count++))
            continue
        fi

        IFS=',' read -ra child_array <<< "$children"
        for child in "${child_array[@]}"; do
            child_sys_id=$(get_service_sys_id "$child" "$namespace")

            if [ -z "$child_sys_id" ]; then
                log_warning "Child service not found: ${child} in ${namespace}"
                ((error_count++))
                continue
            fi

            if create_relationship "$parent_sys_id" "$child_sys_id" "$parent" "$child"; then
                ((created_count++))
            else
                ((skipped_count++))
            fi
        done
    done

    echo ""
    log_success "Namespace ${namespace} complete: ${created_count} created, ${skipped_count} skipped, ${error_count} errors"
    echo ""
}

# Verify services exist in CMDB
verify_services() {
    log_info "Verifying services in CMDB..."
    echo ""

    local services=("frontend" "cartservice" "productcatalogservice" "currencyservice"
                   "paymentservice" "shippingservice" "emailservice" "checkoutservice"
                   "recommendationservice" "adservice" "redis-cart")

    local found_count=0
    local missing_count=0

    for service in "${services[@]}"; do
        local sys_id=$(get_service_sys_id "$service")

        if [ -n "$sys_id" ]; then
            log_success "✓ ${service}"
            ((found_count++))
        else
            log_error "✗ ${service} not found"
            ((missing_count++))
        fi
    done

    echo ""
    if [ $missing_count -eq 0 ]; then
        log_success "All ${found_count} services found in CMDB"
    else
        log_warning "${missing_count} services missing from CMDB"
        log_info "Run EKS discovery workflow to populate services"
        exit 1
    fi
    echo ""
}

# List all relationships
list_relationships() {
    log_info "Fetching existing relationships..."
    echo ""

    local response=$(curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_ci?sysparm_query=parent.sys_class_name=u_microservice^ORchild.sys_class_name=u_microservice&sysparm_fields=parent.u_name,child.u_name,type.name&sysparm_limit=100")

    echo "$response" | jq -r '.result[] | "\(.["parent.u_name"]) → \(.["child.u_name"]) (\(.["type.name"]))"' | sort

    local count=$(echo "$response" | jq '.result | length')
    echo ""
    log_info "Total relationships: ${count}"
}

# Main execution
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "       ServiceNow Service Dependency Mapping                   "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Step 1: Verify services
    verify_services

    # Step 2: Map dependencies for each namespace
    log_info "Mapping dependencies for all namespaces..."
    echo ""

    for namespace in microservices-dev microservices-qa microservices-prod; do
        map_namespace_dependencies "$namespace"
    done

    # Step 3: List all relationships
    list_relationships

    # Step 4: Print summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                     Mapping Complete                           "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    log_success "Service dependencies have been mapped in ServiceNow CMDB"
    echo ""
    echo "View in ServiceNow:"
    echo "-------------------"
    echo "1. Dependency View:"
    echo "   ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=cmdb_ci_list.do"
    echo "   - Search for 'frontend'"
    echo "   - Click 'Visualize' → 'Dependency View'"
    echo ""
    echo "2. Relationship List:"
    echo "   ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=cmdb_rel_ci_list.do"
    echo ""
    echo "3. Service Map (if available):"
    echo "   ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=service_map_list.do"
    echo ""
}

# Run main
main
