#!/usr/bin/env bash
set -euo pipefail

# diagnose-servicenow.sh - Diagnose ServiceNow DevOps Change Workspace integration
# Usage: ./scripts/diagnose-servicenow.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check for required environment variables
if [ -z "${SERVICENOW_INSTANCE_URL:-}" ]; then
    log_error "SERVICENOW_INSTANCE_URL not set"
    echo "Please set your ServiceNow credentials:"
    echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
    exit 1
fi

# Get credentials from environment (required)
USERNAME="${SERVICENOW_USERNAME:-github_integration}"
if [ -z "${SERVICENOW_PASSWORD:-}" ]; then
    log_error "SERVICENOW_PASSWORD not set"
    echo "Please export SERVICENOW_PASSWORD before running this script."
    exit 1
fi
PASSWORD="${SERVICENOW_PASSWORD}"

log_info "Starting ServiceNow DevOps diagnostic..."
echo ""
echo "Target Instance: $SERVICENOW_INSTANCE_URL"
echo "Username: $USERNAME"
echo ""

# Function to make API call with basic auth
servicenow_api() {
    local endpoint="$1"
    local url="${SERVICENOW_INSTANCE_URL}/api/now/table/${endpoint}"

    curl -s -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url"
}

# Test 1: Check required IntegrationHub plugins
log_info "Test 1: Checking IntegrationHub plugins..."
echo ""

PLUGINS_QUERY="sysparm_query=idINcom.glide.hub.integrations,com.glide.hub.action_step.rest,com.glide.hub.action_template.datastream,com.glide.hub.legacy_usage^ORidLIKEsn_devops&sysparm_fields=id,name,active,version"

PLUGINS_RESULT=$(servicenow_api "sys_plugins?${PLUGINS_QUERY}")

echo "$PLUGINS_RESULT" | jq -r '.result[] | "  Plugin: \(.name)\n    ID: \(.id)\n    Active: \(.active)\n    Version: \(.version)\n"' || {
    log_error "Failed to parse plugins result"
    echo "Raw response:"
    echo "$PLUGINS_RESULT" | jq .
}

# Count active IntegrationHub plugins
ACTIVE_HUB_PLUGINS=$(echo "$PLUGINS_RESULT" | jq -r '[.result[] | select(.id | startswith("com.glide.hub")) | select(.active == "true")] | length')

if [ "$ACTIVE_HUB_PLUGINS" -lt 4 ]; then
    log_error "Missing IntegrationHub plugins detected!"
    echo ""
    echo "Required plugins for DevOps Change API:"
    echo "  1. ServiceNow IntegrationHub Runtime (com.glide.hub.integrations)"
    echo "  2. IntegrationHub Action Step - REST (com.glide.hub.action_step.rest)"
    echo "  3. IntegrationHub Action Template - Data Stream (com.glide.hub.action_template.datastream)"
    echo "  4. Legacy IntegrationHub Usage Dashboard (com.glide.hub.legacy_usage)"
    echo ""
    log_warning "This is the ROOT CAUSE of DevOps workspace visibility issues!"
else
    log_success "All required IntegrationHub plugins detected"
fi

echo ""

# Test 2: Check DevOps Change plugins
log_info "Test 2: Checking DevOps Change plugins..."
echo ""

DEVOPS_PLUGINS=$(echo "$PLUGINS_RESULT" | jq -r '[.result[] | select(.id | contains("sn_devops"))] | length')

if [ "$DEVOPS_PLUGINS" -gt 0 ]; then
    log_success "DevOps Change plugins detected: $DEVOPS_PLUGINS"
    echo "$PLUGINS_RESULT" | jq -r '.result[] | select(.id | contains("sn_devops")) | "  - \(.name) (\(.id)) - Active: \(.active)"'
else
    log_error "No DevOps Change plugins found!"
fi

echo ""

# Test 3: Check GitHubARC tool configuration
log_info "Test 3: Checking GitHub tool configuration..."
echo ""

TOOL_QUERY="sysparm_query=name=GitHubARC&sysparm_fields=sys_id,name,type,tool_id"
TOOL_RESULT=$(servicenow_api "sn_devops_tool?${TOOL_QUERY}")

TOOL_COUNT=$(echo "$TOOL_RESULT" | jq -r '.result | length')

if [ "$TOOL_COUNT" -gt 0 ]; then
    log_success "GitHub tool found"
    echo "$TOOL_RESULT" | jq -r '.result[] | "  Tool: \(.name)\n    Sys ID: \(.sys_id)\n    Type: \(.type)\n    Tool ID: \(.tool_id)\n"'
else
    log_error "GitHub tool (GitHubARC) not found in sn_devops_tool table"
fi

echo ""

# Test 4: Check DevOps Change records
log_info "Test 4: Checking recent DevOps Change records..."
echo ""

CHANGE_QUERY="sysparm_limit=10&sysparm_fields=number,change_request,pipeline,pipeline_run,application"
CHANGE_RESULT=$(servicenow_api "sn_devops_change?${CHANGE_QUERY}")

CHANGE_COUNT=$(echo "$CHANGE_RESULT" | jq -r '.result | length')

if [ "$CHANGE_COUNT" -gt 0 ]; then
    log_success "Found $CHANGE_COUNT DevOps Change records"
    echo "$CHANGE_RESULT" | jq -r '.result[] | "  Number: \(.number)\n    Change Request: \(.change_request)\n    Pipeline: \(.pipeline)\n    Pipeline Run: \(.pipeline_run)\n"' | head -20
else
    log_warning "No DevOps Change records found"
fi

echo ""

# Test 5: Check Change Request correlation
log_info "Test 5: Checking recent Change Requests with correlation..."
echo ""

CR_QUERY="sysparm_query=correlation_idISNOTEMPTY^ORDERBYDESCsys_created_on&sysparm_limit=5&sysparm_display_value=true&sysparm_fields=number,short_description,correlation_id,correlation_display,u_source,sys_created_by,sys_updated_by"
CR_RESULT=$(servicenow_api "change_request?${CR_QUERY}")

CR_COUNT=$(echo "$CR_RESULT" | jq -r '.result | length')

if [ "$CR_COUNT" -gt 0 ]; then
    log_success "Found $CR_COUNT Change Requests with correlation"
    echo "$CR_RESULT" | jq -r '.result[] | "  Number: \(.number)\n    Description: \(.short_description)\n    Correlation ID: \(.correlation_id)\n    Source: \(.u_source // "N/A")\n"'
else
    log_warning "No Change Requests with correlation_id found"
fi

echo ""

# Test 6: Check DevOps properties
log_info "Test 6: Checking DevOps system properties..."
echo ""

PROPS_QUERY="sysparm_query=name=sn_devops.change.callback.enabled^ORname=sn_devops.change.enabled&sysparm_fields=name,value"
PROPS_RESULT=$(servicenow_api "sys_properties?${PROPS_QUERY}")

echo "$PROPS_RESULT" | jq -r '.result[] | "  Property: \(.name)\n    Value: \(.value)\n"' || {
    log_warning "Could not retrieve DevOps properties"
}

echo ""

# Summary and Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "DIAGNOSTIC SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ACTIVE_HUB_PLUGINS" -lt 4 ]; then
    log_error "ROOT CAUSE IDENTIFIED: Missing IntegrationHub plugins"
    echo ""
    echo "The DevOps Change Workspace requires IntegrationHub plugins to function."
    echo "Without these plugins, the DevOps Change API will fail with 'Internal server error'."
    echo ""
    echo "RECOMMENDED ACTIONS:"
    echo "  1. Contact your ServiceNow administrator"
    echo "  2. Request installation of IntegrationHub plugins"
    echo "  3. Or continue using the hybrid REST API workflow as workaround"
    echo ""
    echo "WORKAROUND (Current):"
    echo "  - Using hybrid REST API workflow (deploy-with-servicenow-hybrid.yaml)"
    echo "  - Change requests created successfully via REST API"
    echo "  - Limited DevOps workspace visibility"
    echo ""
else
    log_success "IntegrationHub plugins are installed"

    if [ "$CHANGE_COUNT" -eq 0 ]; then
        log_warning "No DevOps Change records found - integration may need configuration"
        echo ""
        echo "RECOMMENDED ACTIONS:"
        echo "  1. Verify GitHub Actions are using correct ServiceNow DevOps actions"
        echo "  2. Check workflow correlation IDs are being set correctly"
        echo "  3. Review ServiceNow logs for API errors"
    else
        log_success "DevOps Change integration appears to be working"
    fi
fi

echo ""
echo "For detailed troubleshooting, see:"
echo "  - docs/SERVICENOW-DEVOPS-API-PREREQUISITES.md"
echo "  - docs/SERVICENOW-DEVOPS-GITHUB-ACTIONS-ANALYSIS.md"
echo ""
