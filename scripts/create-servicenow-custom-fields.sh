#!/bin/bash
# Create Custom Fields on ServiceNow change_request Table
# This script creates the custom fields needed for GitHub Actions integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ServiceNow instance details
INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"
USERNAME="${SERVICENOW_USERNAME}"
PASSWORD="${SERVICENOW_PASSWORD}"

# Check required environment variables
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}ERROR: SERVICENOW_USERNAME and SERVICENOW_PASSWORD environment variables must be set${NC}"
    echo "Example:"
    echo "  export SERVICENOW_USERNAME='your-username'"
    echo "  export SERVICENOW_PASSWORD='your-password'"
    exit 1
fi

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}ServiceNow Custom Field Creation${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}Instance:${NC} $INSTANCE_URL"
echo -e "${GREEN}User:${NC} $USERNAME"
echo ""
echo "Creating custom fields on change_request table..."
echo ""

# Get change_request table sys_id
echo "Step 1: Finding change_request table..."
TABLE_RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
    -H "Accept: application/json" \
    "${INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=change_request&sysparm_fields=sys_id,name")

TABLE_SYS_ID=$(echo "$TABLE_RESPONSE" | jq -r '.result[0].sys_id // empty')

if [ -z "$TABLE_SYS_ID" ]; then
    echo -e "${RED}❌ ERROR: Could not find change_request table${NC}"
    echo "Response: $TABLE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Found change_request table: $TABLE_SYS_ID${NC}"
echo ""

# Define custom fields to create
declare -A FIELDS=(
    ["u_source"]="String|100|Source|Source system (e.g. GitHub Actions)"
    ["u_correlation_id"]="String|100|Correlation ID|Unique identifier for tracking across systems"
    ["u_repository"]="String|200|Repository|Source code repository name"
    ["u_branch"]="String|100|Branch|Git branch name"
    ["u_commit_sha"]="String|50|Commit SHA|Git commit SHA hash"
    ["u_actor"]="String|100|Actor|User who triggered the action"
    ["u_environment"]="String|20|Environment|Deployment environment (dev/qa/prod)"
)

CREATED_COUNT=0
EXISTING_COUNT=0
FAILED_COUNT=0

# Create each field
for field_name in "${!FIELDS[@]}"; do
    IFS='|' read -r field_type max_length label description <<< "${FIELDS[$field_name]}"

    echo "Creating field: $field_name ($label)..."

    # Check if field already exists
    CHECK_RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
        -H "Accept: application/json" \
        "${INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=change_request^element=$field_name&sysparm_fields=sys_id,element")

    EXISTING_SYS_ID=$(echo "$CHECK_RESPONSE" | jq -r '.result[0].sys_id // empty')

    if [ -n "$EXISTING_SYS_ID" ]; then
        echo -e "${YELLOW}  ⚠️  Field already exists (sys_id: $EXISTING_SYS_ID)${NC}"
        EXISTING_COUNT=$((EXISTING_COUNT + 1))
        continue
    fi

    # Determine internal type based on field type
    case "$field_type" in
        "String")
            internal_type="string"
            ;;
        "Integer")
            internal_type="integer"
            ;;
        "Boolean")
            internal_type="boolean"
            ;;
        *)
            internal_type="string"
            ;;
    esac

    # Create field
    PAYLOAD=$(jq -n \
        --arg name "change_request" \
        --arg element "$field_name" \
        --arg column_label "$label" \
        --arg max_length "$max_length" \
        --arg internal_type "$internal_type" \
        --arg comments "$description" \
        '{
            name: $name,
            element: $element,
            column_label: $column_label,
            max_length: $max_length,
            internal_type: $internal_type,
            comments: $comments,
            active: "true",
            read_only: "false",
            mandatory: "false"
        }')

    CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -u "$USERNAME:$PASSWORD" \
        -d "$PAYLOAD" \
        "${INSTANCE_URL}/api/now/table/sys_dictionary")

    HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
    BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "201" ]; then
        FIELD_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id // empty')
        echo -e "${GREEN}  ✅ Created successfully (sys_id: $FIELD_SYS_ID)${NC}"
        CREATED_COUNT=$((CREATED_COUNT + 1))
    else
        echo -e "${RED}  ❌ Failed to create (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi

    echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ Created:${NC} $CREATED_COUNT fields"
echo -e "${YELLOW}⚠️  Already existed:${NC} $EXISTING_COUNT fields"

if [ "$FAILED_COUNT" -gt "0" ]; then
    echo -e "${RED}❌ Failed:${NC} $FAILED_COUNT fields"
fi

echo ""

if [ "$CREATED_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✅ Custom fields created successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Verify fields in ServiceNow: ${INSTANCE_URL}/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
    echo "2. Update GitHub Actions workflows to use these field names"
    echo "3. Test by creating a change request with populated custom fields"
elif [ "$EXISTING_COUNT" -eq "${#FIELDS[@]}" ]; then
    echo -e "${GREEN}✅ All custom fields already exist!${NC}"
    echo ""
    echo "Fields are ready to use. You can verify at:"
    echo "${INSTANCE_URL}/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Field Creation Complete${NC}"
echo -e "${BLUE}======================================${NC}"
