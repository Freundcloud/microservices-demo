#!/usr/bin/env bash

#===============================================================================
# Get ServiceNow Application sys_id
#===============================================================================
# Purpose: Retrieve the sys_id for "Online Boutique" application
# Usage:   bash scripts/get-servicenow-app-sys-id.sh
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

# Application name (can be passed as argument)
APP_NAME="${1:-Online Boutique}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "       ServiceNow Application sys_id Retrieval                 "
echo "═══════════════════════════════════════════════════════════════"
echo ""

log_info "Searching for application: ${APP_NAME}"
echo ""

# Search for application
RESPONSE=$(curl -s \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app?sysparm_query=name=${APP_NAME// /%20}&sysparm_fields=sys_id,name,operational_status,u_cluster_name")

# Check if application exists
APP_COUNT=$(echo "$RESPONSE" | jq -r '.result | length')

if [ "$APP_COUNT" -eq 0 ]; then
    log_error "Application '${APP_NAME}' not found in ServiceNow"
    echo ""
    log_info "Available applications:"
    curl -s \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app?sysparm_fields=name&sysparm_limit=20" \
        | jq -r '.result[] | .name'
    echo ""
    log_info "Create the application first:"
    echo "  1. Navigate to: Configuration → CMDB → Applications → Business Applications"
    echo "  2. Click 'New'"
    echo "  3. Fill in:"
    echo "     - Name: Online Boutique"
    echo "     - Operational Status: Operational"
    echo "     - Description: Microservices demo application on AWS EKS"
    echo "  4. Click 'Submit'"
    echo ""
    exit 1
fi

# Extract sys_id
APP_SYS_ID=$(echo "$RESPONSE" | jq -r '.result[0].sys_id')
APP_NAME_FOUND=$(echo "$RESPONSE" | jq -r '.result[0].name')
APP_STATUS=$(echo "$RESPONSE" | jq -r '.result[0].operational_status')

log_success "Application found!"
echo ""
echo "Application Details:"
echo "-------------------"
echo "Name: ${APP_NAME_FOUND}"
echo "Status: ${APP_STATUS}"
echo "sys_id: ${APP_SYS_ID}"
echo ""

# Show GitHub secret command
log_info "Next steps:"
echo ""
echo "1. Copy the sys_id above"
echo ""
echo "2. Configure GitHub secret (choose one method):"
echo ""
echo "   Via GitHub UI:"
echo "   -------------"
echo "   • Go to: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions"
echo "   • Click: 'New repository secret'"
echo "   • Name: SERVICENOW_APP_SYS_ID"
echo "   • Value: ${APP_SYS_ID}"
echo "   • Click: 'Add secret'"
echo ""
echo "   Via GitHub CLI:"
echo "   --------------"
echo "   gh secret set SERVICENOW_APP_SYS_ID --body \"${APP_SYS_ID}\""
echo ""
echo "   Via one-liner (requires gh CLI):"
echo "   --------------------------------"
echo "   echo '${APP_SYS_ID}' | gh secret set SERVICENOW_APP_SYS_ID"
echo ""

log_info "After configuring the secret, run dependency mapping:"
echo "   bash scripts/map-service-dependencies.sh"
echo ""

# Verify application has required fields
log_info "Verifying application configuration..."
FULL_RESPONSE=$(curl -s \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app/${APP_SYS_ID}?sysparm_display_value=true")

echo ""
echo "Full Application Details:"
echo "------------------------"
echo "$FULL_RESPONSE" | jq -r '.result | {
    name: .name,
    description: .short_description,
    operational_status: .operational_status,
    managed_by: .managed_by,
    owned_by: .owned_by,
    support_group: .support_group
}' | sed 's/^/  /'
echo ""

log_success "Application is ready for integration!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                     Retrieval Complete                         "
echo "═══════════════════════════════════════════════════════════════"
echo ""
