#!/usr/bin/env bash

#===============================================================================
# Create ServiceNow Business Application with Required Fields
#===============================================================================
# Purpose: Create "Online Boutique" Business Application with all required fields
# Usage:   bash scripts/create-servicenow-application.sh
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

# Application details
APP_NAME="Online Boutique"
APP_CATEGORY_SYS_ID="18d3b632210e3b00964f98b7f95cf808"  # Service Delivery
OPERATIONAL_STATUS="1"  # Operational

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "       ServiceNow Business Application Creation                "
echo "═══════════════════════════════════════════════════════════════"
echo ""

log_info "Application Name: ${APP_NAME}"
log_info "Application Category: Service Delivery"
log_info "Operational Status: Operational"
echo ""

# Check if application already exists
log_info "Checking if application already exists..."
EXISTING_APP=$(curl -s \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app?sysparm_query=name=${APP_NAME// /%20}&sysparm_fields=sys_id,name,operational_status,application_category")

APP_COUNT=$(echo "$EXISTING_APP" | jq -r '.result | length')

if [ "$APP_COUNT" -gt 0 ]; then
    APP_SYS_ID=$(echo "$EXISTING_APP" | jq -r '.result[0].sys_id')
    APP_STATUS=$(echo "$EXISTING_APP" | jq -r '.result[0].operational_status')
    APP_CATEGORY=$(echo "$EXISTING_APP" | jq -r '.result[0].application_category.value // empty')

    log_warning "Application '${APP_NAME}' already exists!"
    echo ""
    echo "Existing Application:"
    echo "  sys_id: ${APP_SYS_ID}"
    echo "  Status: ${APP_STATUS}"
    echo "  Category: ${APP_CATEGORY:-Not set}"
    echo ""

    # Check if Application Category is missing
    if [ -z "$APP_CATEGORY" ] || [ "$APP_CATEGORY" = "null" ]; then
        log_warning "Application Category is not set. Updating..."

        UPDATE_RESPONSE=$(curl -s -X PATCH \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" \
            -d "{
                \"application_category\": \"${APP_CATEGORY_SYS_ID}\"
            }" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app/${APP_SYS_ID}")

        UPDATE_ERROR=$(echo "$UPDATE_RESPONSE" | jq -r '.error.message // empty')
        if [ -n "$UPDATE_ERROR" ]; then
            log_error "Failed to update Application Category: ${UPDATE_ERROR}"
            exit 1
        fi

        log_success "Application Category updated to 'Service Delivery'"
    fi

    echo ""
    log_success "Application is ready!"
    echo ""
    echo "Application sys_id: ${APP_SYS_ID}"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure GitHub secret:"
    echo "     gh secret set SERVICENOW_APP_SYS_ID --body \"${APP_SYS_ID}\""
    echo ""
    echo "  2. Map service dependencies:"
    echo "     bash scripts/map-service-dependencies.sh"
    echo ""
    exit 0
fi

# Create new application
log_info "Creating Business Application..."
echo ""

CREATE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"${APP_NAME}\",
        \"operational_status\": \"${OPERATIONAL_STATUS}\",
        \"application_category\": \"${APP_CATEGORY_SYS_ID}\",
        \"short_description\": \"Cloud-native microservices demo application on AWS EKS\",
        \"description\": \"Microservices-based e-commerce demo featuring 11 services (Go, Python, Java, Node.js, C#) running on AWS EKS with Istio service mesh\"
    }" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_ci_business_app")

# Check for errors
CREATE_ERROR=$(echo "$CREATE_RESPONSE" | jq -r '.error.message // empty')
if [ -n "$CREATE_ERROR" ]; then
    log_error "Failed to create Business Application"
    echo ""
    echo "Error Details:"
    echo "$CREATE_RESPONSE" | jq .
    echo ""
    log_info "Common issues:"
    echo "  1. Application Category is required (this script includes it)"
    echo "  2. User permissions - github_integration needs admin role"
    echo "  3. Business Rules may require additional fields"
    echo ""
    log_info "Manual creation via UI:"
    echo "  1. Navigate to: Configuration → CMDB → Applications → Business Applications"
    echo "  2. Click: New"
    echo "  3. Fill in:"
    echo "     - Name: Online Boutique"
    echo "     - Operational Status: Operational"
    echo "     - Application Category: Service Delivery"
    echo "     - Short Description: Cloud-native microservices demo application on AWS EKS"
    echo "  4. Click: Submit"
    echo ""
    exit 1
fi

APP_SYS_ID=$(echo "$CREATE_RESPONSE" | jq -r '.result.sys_id')

if [ -z "$APP_SYS_ID" ] || [ "$APP_SYS_ID" = "null" ]; then
    log_error "Failed to extract sys_id from response"
    echo ""
    echo "Response:"
    echo "$CREATE_RESPONSE" | jq .
    echo ""
    exit 1
fi

log_success "Business Application created successfully!"
echo ""
echo "Application Details:"
echo "-------------------"
echo "Name: ${APP_NAME}"
echo "sys_id: ${APP_SYS_ID}"
echo "Status: Operational"
echo "Category: Service Delivery"
echo ""

log_info "Next steps:"
echo ""
echo "1. Configure GitHub secret:"
echo "   gh secret set SERVICENOW_APP_SYS_ID --body \"${APP_SYS_ID}\""
echo ""
echo "   Or via one-liner:"
echo "   echo '${APP_SYS_ID}' | gh secret set SERVICENOW_APP_SYS_ID"
echo ""
echo "2. Map service dependencies:"
echo "   bash scripts/map-service-dependencies.sh"
echo ""
echo "3. Test deployment with application association:"
echo "   gh workflow run deploy-with-servicenow-basic.yaml --field environment=dev"
echo ""
echo "4. Verify in ServiceNow DevOps Change workspace:"
echo "   https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/devops_change_v2_list.do"
echo ""

log_success "Application creation complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                     Creation Complete                          "
echo "═══════════════════════════════════════════════════════════════"
echo ""
