#!/bin/bash

# ServiceNow Change Request Form Layout Configuration
# Adds custom work items fields to the change request form

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════"
echo "📋 ServiceNow Change Request Form Layout Configuration"
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

# Step 1: Find the default change request form view
echo "═══════════════════════════════════════════════════════════"
echo "Step 1: Finding Change Request Form Views"
echo "═══════════════════════════════════════════════════════════"
echo ""

FORM_VIEWS=$(curl -s \
  -H "Accept: application/json" \
  --user "$AUTH_HEADER" \
  "$INSTANCE_URL/api/now/table/sys_ui_form?sysparm_query=name=change_request&sysparm_fields=sys_id,name,view,sys_created_on&sysparm_limit=10")

FORM_COUNT=$(echo "$FORM_VIEWS" | jq -r '.result | length')
echo -e "${GREEN}Found $FORM_COUNT form views for change_request${NC}"
echo ""

if [ "$FORM_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No existing form views found. Will create form sections instead.${NC}"
else
    echo "$FORM_VIEWS" | jq -r '.result[] | "  📋 Form: \(.name) | View: \(.view // "default") | Sys ID: \(.sys_id)"'
    echo ""
fi

# Step 2: Find existing form sections for change_request
echo "═══════════════════════════════════════════════════════════"
echo "Step 2: Finding Existing Form Sections"
echo "═══════════════════════════════════════════════════════════"
echo ""

SECTIONS=$(curl -s \
  -H "Accept: application/json" \
  --user "$AUTH_HEADER" \
  "$INSTANCE_URL/api/now/table/sys_ui_section?sysparm_query=name=change_request&sysparm_fields=sys_id,name,caption,view,position&sysparm_limit=20")

SECTIONS_COUNT=$(echo "$SECTIONS" | jq -r '.result | length')
echo -e "${GREEN}Found $SECTIONS_COUNT form sections${NC}"
echo ""

if [ "$SECTIONS_COUNT" -gt 0 ]; then
    echo "$SECTIONS" | jq -r '.result[] | "  📦 Section: \(.caption // "Untitled") | View: \(.view // "default") | Position: \(.position) | Sys ID: \(.sys_id)"' | head -10
    echo ""
fi

# Step 3: Create or find "Work Items" section
echo "═══════════════════════════════════════════════════════════"
echo "Step 3: Creating Work Items Section"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if Work Items section already exists
EXISTING_SECTION=$(curl -s \
  -H "Accept: application/json" \
  --user "$AUTH_HEADER" \
  "$INSTANCE_URL/api/now/table/sys_ui_section?sysparm_query=name=change_request^caption=Work%20Items&sysparm_fields=sys_id,caption")

SECTION_EXISTS=$(echo "$EXISTING_SECTION" | jq -r '.result | length')

if [ "$SECTION_EXISTS" -gt 0 ]; then
    SECTION_SYS_ID=$(echo "$EXISTING_SECTION" | jq -r '.result[0].sys_id')
    echo -e "${YELLOW}⚠️  Work Items section already exists${NC}"
    echo -e "   Sys ID: $SECTION_SYS_ID"
    echo ""
else
    # Create new section
    echo "Creating new Work Items section..."
    
    SECTION_PAYLOAD=$(jq -n \
        --arg name "change_request" \
        --arg caption "Work Items" \
        --arg view "" \
        '{
            name: $name,
            caption: $caption,
            view: $view,
            position: 50
        }')
    
    SECTION_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        -d "$SECTION_PAYLOAD" \
        "$INSTANCE_URL/api/now/table/sys_ui_section")
    
    HTTP_CODE=$(echo "$SECTION_RESPONSE" | tail -1)
    BODY=$(echo "$SECTION_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "201" ]; then
        SECTION_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
        echo -e "${GREEN}✅ Work Items section created${NC}"
        echo -e "   Sys ID: $SECTION_SYS_ID"
        echo ""
    else
        echo -e "${RED}❌ Failed to create section (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
        echo ""
        
        # Try to find it anyway in case it was created
        EXISTING_SECTION=$(curl -s \
            -H "Accept: application/json" \
            --user "$AUTH_HEADER" \
            "$INSTANCE_URL/api/now/table/sys_ui_section?sysparm_query=name=change_request^caption=Work%20Items&sysparm_fields=sys_id")
        
        SECTION_SYS_ID=$(echo "$EXISTING_SECTION" | jq -r '.result[0].sys_id // empty')
        
        if [ -z "$SECTION_SYS_ID" ]; then
            echo -e "${RED}❌ Cannot proceed without section sys_id${NC}"
            exit 1
        else
            echo -e "${YELLOW}⚠️  Found existing section with sys_id: $SECTION_SYS_ID${NC}"
            echo ""
        fi
    fi
fi

# Step 4: Add fields to the section
echo "═══════════════════════════════════════════════════════════"
echo "Step 4: Adding Fields to Work Items Section"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Field details
declare -A FIELDS
FIELDS[u_work_items_count]="Work Items Count"
FIELDS[u_github_issues]="GitHub Issues"
FIELDS[u_work_items_summary]="Work Items Summary"

POSITION=0
FIELDS_ADDED=0

for FIELD_NAME in u_work_items_count u_github_issues u_work_items_summary; do
    FIELD_LABEL="${FIELDS[$FIELD_NAME]}"
    
    echo -e "${YELLOW}Adding field:${NC} $FIELD_NAME ($FIELD_LABEL)"
    
    # Check if field element already exists in this section
    EXISTING_ELEMENT=$(curl -s \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        "$INSTANCE_URL/api/now/table/sys_ui_element?sysparm_query=sys_ui_section=$SECTION_SYS_ID^element=$FIELD_NAME&sysparm_fields=sys_id")
    
    ELEMENT_EXISTS=$(echo "$EXISTING_ELEMENT" | jq -r '.result | length')
    
    if [ "$ELEMENT_EXISTS" -gt 0 ]; then
        echo -e "${YELLOW}   ⚠️  Field already exists in this section${NC}"
        echo ""
        continue
    fi
    
    # Create form element
    ELEMENT_PAYLOAD=$(jq -n \
        --arg section "$SECTION_SYS_ID" \
        --arg element "$FIELD_NAME" \
        --argjson position "$POSITION" \
        '{
            sys_ui_section: $section,
            element: $element,
            position: $position,
            type: "field"
        }')
    
    ELEMENT_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        --user "$AUTH_HEADER" \
        -d "$ELEMENT_PAYLOAD" \
        "$INSTANCE_URL/api/now/table/sys_ui_element")
    
    HTTP_CODE=$(echo "$ELEMENT_RESPONSE" | tail -1)
    BODY=$(echo "$ELEMENT_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" == "201" ]; then
        ELEMENT_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
        echo -e "${GREEN}   ✅ Field added (Position: $POSITION)${NC}"
        echo -e "      Sys ID: $ELEMENT_SYS_ID"
        FIELDS_ADDED=$((FIELDS_ADDED + 1))
    else
        echo -e "${RED}   ❌ Failed to add field (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    fi
    
    echo ""
    POSITION=$((POSITION + 1))
done

# Step 5: Verification
echo "═══════════════════════════════════════════════════════════"
echo "Step 5: Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Verifying fields in Work Items section..."
echo ""

ELEMENTS=$(curl -s \
    -H "Accept: application/json" \
    --user "$AUTH_HEADER" \
    "$INSTANCE_URL/api/now/table/sys_ui_element?sysparm_query=sys_ui_section=$SECTION_SYS_ID&sysparm_fields=element,position,type&sysparm_display_value=true")

ELEMENTS_COUNT=$(echo "$ELEMENTS" | jq -r '.result | length')
echo "$ELEMENTS" | jq -r '.result[] | "  ✅ Field: \(.element) | Position: \(.position) | Type: \(.type)"'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Work Items section:${NC} $SECTION_SYS_ID"
echo -e "${GREEN}Fields added:${NC} $FIELDS_ADDED"
echo -e "${BLUE}Total fields in section:${NC} $ELEMENTS_COUNT"
echo ""

if [ "$ELEMENTS_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✅ Work Items section configured successfully!${NC}"
    echo ""
    echo "The following fields are now available on the change request form:"
    echo "  1. Work Items Count - Shows total number of issues"
    echo "  2. GitHub Issues - Comma-separated issue numbers"
    echo "  3. Work Items Summary - Rich HTML summary with links"
    echo ""
    echo "Next steps:"
    echo "  1. Open ServiceNow change request form"
    echo "  2. Configure section (optional): Personalize > Configure > Form Layout"
    echo "  3. Test deployment to verify fields populate"
    echo ""
else
    echo -e "${YELLOW}⚠️  Expected 3 fields in section, found $ELEMENTS_COUNT${NC}"
    echo "Some fields may not have been added. Check errors above."
fi

echo "═══════════════════════════════════════════════════════════"

