#!/bin/bash

# ServiceNow Enhanced Custom Fields Creation Script
# Creates additional fields for comprehensive deployment tracking

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════════"
echo "🚀 ServiceNow Enhanced Fields Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Load credentials
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
    echo -e "${RED}❌ Error: ServiceNow credentials not set${NC}"
    echo "Please run: source .envrc"
    exit 1
fi

INSTANCE_URL="https://calitiiltddemo3.service-now.com"
AUTH_HEADER="$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD"

echo -e "${BLUE}Instance:${NC} $INSTANCE_URL"
echo -e "${BLUE}User:${NC} $SERVICENOW_USERNAME"
echo ""

# Function to create a field
create_field() {
    local field_name="$1"
    local field_label="$2"
    local field_type="$3"
    local max_length="$4"
    local description="$5"
    
    echo -e "${YELLOW}Creating:${NC} $field_name ($field_label)"
    
    # Check if exists
    EXISTING=$(curl -s \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        "$INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request^element=$field_name&sysparm_fields=sys_id")
    
    COUNT=$(echo "$EXISTING" | jq -r '.result | length')
    
    if [ "$COUNT" -gt "0" ]; then
        echo -e "${YELLOW}  ⚠️  Already exists${NC}"
        return 0
    fi
    
    # Build payload
    if [ "$field_type" == "string" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg type "$field_type" \
            --arg length "$max_length" \
            --arg desc "$description" \
            '{
                name: "change_request",
                element: $name,
                column_label: $label,
                internal_type: $type,
                max_length: $length,
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    elif [ "$field_type" == "integer" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg desc "$description" \
            '{
                name: "change_request",
                element: $name,
                column_label: $label,
                internal_type: "integer",
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    elif [ "$field_type" == "boolean" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg desc "$description" \
            '{
                name: "change_request",
                element: $name,
                column_label: $label,
                internal_type: "boolean",
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    elif [ "$field_type" == "glide_date_time" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg desc "$description" \
            '{
                name: "change_request",
                element: $name,
                column_label: $label,
                internal_type: "glide_date_time",
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    fi
    
    # Create field
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        -d "$PAYLOAD" \
        "$INSTANCE_URL/api/now/table/sys_dictionary")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "201" ]; then
        FIELD_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
        echo -e "${GREEN}  ✅ Created (Sys ID: $FIELD_SYS_ID)${NC}"
        return 0
    else
        echo -e "${RED}  ❌ Failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo "Creating Enhanced Deployment Tracking Fields"
echo "═══════════════════════════════════════════════════════════"
echo ""

FIELDS_CREATED=0

# Field 1: GitHub Actor
if create_field \
    "u_github_actor" \
    "GitHub Actor" \
    "string" \
    "100" \
    "GitHub user who triggered the deployment workflow"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 2: GitHub Branch
if create_field \
    "u_github_branch" \
    "GitHub Branch" \
    "string" \
    "255" \
    "Source branch that was deployed (e.g., main, develop, feature/new-feature)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 3: GitHub PR Number
if create_field \
    "u_github_pr_number" \
    "GitHub PR Number" \
    "string" \
    "50" \
    "Pull request number(s) associated with this deployment (comma-separated)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 4: Deployment Duration
if create_field \
    "u_deployment_duration" \
    "Deployment Duration (seconds)" \
    "integer" \
    "" \
    "Total time taken for deployment workflow to complete in seconds"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 5: Services Deployed
if create_field \
    "u_services_deployed" \
    "Services Deployed" \
    "string" \
    "4000" \
    "Comma-separated list of microservices deployed (e.g., frontend, cartservice, productcatalogservice)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 6: Security Scanners
if create_field \
    "u_security_scanners" \
    "Security Scanners" \
    "string" \
    "1000" \
    "Security scanning tools that were executed (e.g., CodeQL, Semgrep, Trivy, Checkov, tfsec)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 7: Infrastructure Changes
if create_field \
    "u_infrastructure_changes" \
    "Infrastructure Changes" \
    "string" \
    "500" \
    "Indicates if infrastructure was modified (Yes - Terraform applied, No - Application only)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 8: Rollback Available
if create_field \
    "u_rollback_available" \
    "Rollback Available" \
    "boolean" \
    "" \
    "Indicates if this deployment can be rolled back automatically"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 9: Previous Version
if create_field \
    "u_previous_version" \
    "Previous Version" \
    "string" \
    "255" \
    "Version/commit SHA being replaced by this deployment (for rollback reference)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

# Field 10: Approval Required By
if create_field \
    "u_approval_required_by" \
    "Approval Required By" \
    "glide_date_time" \
    "" \
    "Deadline for approving this change request (based on environment risk level)"; then
    FIELDS_CREATED=$((FIELDS_CREATED + 1))
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verify all enhanced fields
VERIFY=$(curl -s \
    -H "Accept: application/json" \
    --user "$AUTH_HEADER" \
    "$INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request^elementSTARTSWITHu_github_actor^ORelementSTARTSWITHu_github_branch^ORelementSTARTSWITHu_github_pr^ORelementSTARTSWITHu_deployment^ORelementSTARTSWITHu_services^ORelementSTARTSWITHu_security_scan^ORelementSTARTSWITHu_infrastructure^ORelementSTARTSWITHu_rollback^ORelementSTARTSWITHu_previous^ORelementSTARTSWITHu_approval&sysparm_fields=element,column_label,internal_type")

VERIFIED_COUNT=$(echo "$VERIFY" | jq -r '.result | length')

echo "$VERIFY" | jq -r '.result[] | "✅ \(.column_label) (\(.element)) - \(.internal_type)"'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Enhanced fields created:${NC} $FIELDS_CREATED"
echo -e "${BLUE}Total fields verified:${NC} $VERIFIED_COUNT"
echo ""

if [ "$VERIFIED_COUNT" -ge 10 ]; then
    echo -e "${GREEN}✅ All enhanced deployment tracking fields configured!${NC}"
    echo ""
    echo "Fields now available for change requests:"
    echo "  1. GitHub Actor - Who triggered deployment"
    echo "  2. GitHub Branch - Source branch"
    echo "  3. GitHub PR Number - Associated pull requests"
    echo "  4. Deployment Duration - Time taken (seconds)"
    echo "  5. Services Deployed - List of microservices"
    echo "  6. Security Scanners - Tools executed"
    echo "  7. Infrastructure Changes - Terraform modifications"
    echo "  8. Rollback Available - Can be rolled back"
    echo "  9. Previous Version - Version being replaced"
    echo " 10. Approval Required By - Approval deadline"
    echo ""
    echo "Next: Update GitHub Actions workflow to populate these fields"
else
    echo -e "${YELLOW}⚠️  Expected 10+ enhanced fields, found $VERIFIED_COUNT${NC}"
    echo "Some fields may not have been created. Check errors above."
fi

echo "═══════════════════════════════════════════════════════════"

