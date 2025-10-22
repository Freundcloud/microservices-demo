#!/bin/bash

# ServiceNow Custom Fields Creation Script
# Creates custom fields for work items tracking in change_request table

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════"
echo "🔧 ServiceNow Work Items Custom Fields Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Load credentials from environment
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
    echo -e "${RED}❌ Error: ServiceNow credentials not set${NC}"
    echo "Please set SERVICENOW_USERNAME and SERVICENOW_PASSWORD environment variables"
    echo "Or source .envrc file: source .envrc"
    exit 1
fi

INSTANCE_URL="https://calitiiltddemo3.service-now.com"
AUTH_HEADER="$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD"

echo -e "${BLUE}Instance:${NC} $INSTANCE_URL"
echo -e "${BLUE}User:${NC} $SERVICENOW_USERNAME"
echo ""

# Function to create a custom field
create_field() {
    local field_name="$1"
    local field_label="$2"
    local field_type="$3"
    local max_length="$4"
    local description="$5"
    
    echo -e "${YELLOW}Creating field:${NC} $field_name ($field_label)"
    
    # Build payload based on field type
    if [ "$field_type" == "string" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg type "$field_type" \
            --arg length "$max_length" \
            --arg desc "$description" \
            --arg table "change_request" \
            '{
                name: $name,
                column_label: $label,
                internal_type: $type,
                max_length: $length,
                element: $table,
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    elif [ "$field_type" == "integer" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg type "$field_type" \
            --arg desc "$description" \
            --arg table "change_request" \
            '{
                name: $name,
                column_label: $label,
                internal_type: $type,
                element: $table,
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    elif [ "$field_type" == "html" ]; then
        PAYLOAD=$(jq -n \
            --arg name "$field_name" \
            --arg label "$field_label" \
            --arg desc "$description" \
            --arg table "change_request" \
            '{
                name: $name,
                column_label: $label,
                internal_type: "html",
                element: $table,
                comments: $desc,
                read_only: false,
                mandatory: false,
                display: true
            }')
    fi
    
    # Create the field
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
        echo -e "${GREEN}✅ Field created successfully${NC}"
        echo -e "   Sys ID: $FIELD_SYS_ID"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Failed to create field (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
        echo ""
        return 1
    fi
}

# Check if fields already exist
check_field_exists() {
    local field_name="$1"
    
    RESPONSE=$(curl -s \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        "$INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request^element=$field_name&sysparm_fields=sys_id,element,column_label")
    
    COUNT=$(echo "$RESPONSE" | jq -r '.result | length')
    
    if [ "$COUNT" -gt "0" ]; then
        echo -e "${YELLOW}⚠️  Field $field_name already exists${NC}"
        echo "$RESPONSE" | jq -r '.result[0] | "   Sys ID: \(.sys_id)\n   Label: \(.column_label)"'
        echo ""
        return 0
    else
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo "Step 1: Checking for existing fields"
echo "═══════════════════════════════════════════════════════════"
echo ""

FIELD1_EXISTS=false
FIELD2_EXISTS=false
FIELD3_EXISTS=false

if check_field_exists "u_github_issues"; then
    FIELD1_EXISTS=true
fi

if check_field_exists "u_work_items_count"; then
    FIELD2_EXISTS=true
fi

if check_field_exists "u_work_items_summary"; then
    FIELD3_EXISTS=true
fi

echo "═══════════════════════════════════════════════════════════"
echo "Step 2: Creating missing fields"
echo "═══════════════════════════════════════════════════════════"
echo ""

FIELDS_CREATED=0
FIELDS_SKIPPED=0

# Field 1: u_github_issues (String 1000)
if [ "$FIELD1_EXISTS" = false ]; then
    if create_field \
        "u_github_issues" \
        "GitHub Issues" \
        "string" \
        "1000" \
        "Comma-separated list of GitHub issue numbers included in this change (e.g., 123,456,789)"; then
        FIELDS_CREATED=$((FIELDS_CREATED + 1))
    fi
else
    FIELDS_SKIPPED=$((FIELDS_SKIPPED + 1))
fi

# Field 2: u_work_items_count (Integer)
if [ "$FIELD2_EXISTS" = false ]; then
    if create_field \
        "u_work_items_count" \
        "Work Items Count" \
        "integer" \
        "" \
        "Total number of work items (GitHub issues) included in this deployment"; then
        FIELDS_CREATED=$((FIELDS_CREATED + 1))
    fi
else
    FIELDS_SKIPPED=$((FIELDS_SKIPPED + 1))
fi

# Field 3: u_work_items_summary (HTML)
if [ "$FIELD3_EXISTS" = false ]; then
    if create_field \
        "u_work_items_summary" \
        "Work Items Summary" \
        "html" \
        "" \
        "HTML-formatted summary of work items with links to GitHub issues and pull requests"; then
        FIELDS_CREATED=$((FIELDS_CREATED + 1))
    fi
else
    FIELDS_SKIPPED=$((FIELDS_SKIPPED + 1))
fi

echo "═══════════════════════════════════════════════════════════"
echo "Step 3: Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verify all fields exist
echo "Verifying all fields in change_request table..."
echo ""

VERIFICATION_RESPONSE=$(curl -s \
    -H "Accept: application/json" \
    --user "$AUTH_HEADER" \
    "$INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request^elementSTARTSWITHu_github^ORelementSTARTSWITHu_work&sysparm_fields=element,column_label,internal_type,max_length,sys_id")

echo "$VERIFICATION_RESPONSE" | jq -r '.result[] | "✅ \(.column_label) (\(.element))\n   Type: \(.internal_type)\n   Sys ID: \(.sys_id)\n"'

VERIFIED_COUNT=$(echo "$VERIFICATION_RESPONSE" | jq -r '.result | length')

echo "═══════════════════════════════════════════════════════════"
echo "Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Fields created:${NC} $FIELDS_CREATED"
echo -e "${YELLOW}Fields skipped (already exist):${NC} $FIELDS_SKIPPED"
echo -e "${BLUE}Total fields verified:${NC} $VERIFIED_COUNT"
echo ""

if [ "$VERIFIED_COUNT" -eq 3 ]; then
    echo -e "${GREEN}✅ All required custom fields are configured!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Add fields to change request form layout (if needed)"
    echo "2. Test deployment to verify work items appear"
    echo "3. Check ServiceNow DevOps Change workspace"
    echo ""
    echo "GitHub Actions workflow is ready to populate these fields automatically!"
else
    echo -e "${RED}⚠️  Expected 3 fields, found $VERIFIED_COUNT${NC}"
    echo "Please review the errors above and try again"
fi

echo "═══════════════════════════════════════════════════════════"

