#!/usr/bin/env bash
#
# Diagnose ServiceNow test_type field issue
#
# This script queries ServiceNow to understand why the test_type field
# in sn_devops_performance_test_summary is empty despite sending "functional"
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}ServiceNow test_type Field Diagnostic${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Check credentials
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
    echo -e "${RED}✗ ServiceNow credentials not loaded${NC}"
    echo ""
    echo "Please set the following environment variables:"
    echo "  export SERVICENOW_USERNAME='your-username'"
    echo "  export SERVICENOW_PASSWORD='your-password'"
    echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
    echo ""
    echo "Or source your .envrc file:"
    echo "  source .envrc"
    exit 1
fi

echo -e "${GREEN}✓ ServiceNow credentials loaded${NC}"
echo ""

# Step 1: Check field definition
echo -e "${BLUE}Step 1: Checking test_type field definition...${NC}"
FIELD_DEF=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_performance_test_summary^element=test_type&sysparm_fields=element,internal_type,reference,mandatory,max_length")

FIELD_TYPE=$(echo "$FIELD_DEF" | jq -r '.result[0].internal_type // "not_found"')
REFERENCE_TABLE=$(echo "$FIELD_DEF" | jq -r '.result[0].reference // "null"')
IS_MANDATORY=$(echo "$FIELD_DEF" | jq -r '.result[0].mandatory // "false"')

if [ "$FIELD_TYPE" = "not_found" ]; then
    echo -e "${YELLOW}⚠  test_type field not found in sys_dictionary${NC}"
    echo -e "${YELLOW}   The field might be inherited from parent table sn_devops_test_summary${NC}"
    echo ""

    # Check parent table
    echo -e "${BLUE}Checking parent table (sn_devops_test_summary)...${NC}"
    PARENT_FIELD_DEF=$(curl -s \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Accept: application/json" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_test_summary^element=test_type&sysparm_fields=element,internal_type,reference,mandatory")

    FIELD_TYPE=$(echo "$PARENT_FIELD_DEF" | jq -r '.result[0].internal_type // "not_found"')
    REFERENCE_TABLE=$(echo "$PARENT_FIELD_DEF" | jq -r '.result[0].reference // "null"')
    IS_MANDATORY=$(echo "$PARENT_FIELD_DEF" | jq -r '.result[0].mandatory // "false"')
fi

echo -e "${GREEN}✓ Field definition found${NC}"
echo "  Field Type: $FIELD_TYPE"
echo "  Reference Table: $REFERENCE_TABLE"
echo "  Mandatory: $IS_MANDATORY"
echo ""

# Step 2: Query test types if reference field
if [ "$FIELD_TYPE" = "reference" ] && [ "$REFERENCE_TABLE" != "null" ]; then
    echo -e "${BLUE}Step 2: Field is a REFERENCE - Querying test type records...${NC}"
    echo "  Reference Table: $REFERENCE_TABLE"
    echo ""

    TEST_TYPES=$(curl -s \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Accept: application/json" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/$REFERENCE_TABLE?sysparm_fields=sys_id,name,label,value&sysparm_limit=20")

    COUNT=$(echo "$TEST_TYPES" | jq '.result | length')

    if [ "$COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠  No test type records found in $REFERENCE_TABLE table${NC}"
        echo ""
        echo -e "${YELLOW}ACTION REQUIRED:${NC} Create test type records in ServiceNow"
        echo ""
        echo "Example:"
        echo "  curl -X POST \\"
        echo "    -u \"\$SERVICENOW_USERNAME:\$SERVICENOW_PASSWORD\" \\"
        echo "    -H \"Content-Type: application/json\" \\"
        echo "    -d '{\"name\": \"functional\", \"label\": \"Functional Test\"}' \\"
        echo "    \"\$SERVICENOW_INSTANCE_URL/api/now/table/$REFERENCE_TABLE\""
    else
        echo -e "${GREEN}✓ Found $COUNT test type(s)${NC}"
        echo ""
        echo "$TEST_TYPES" | jq -r '.result[] | "  - \(.name // .value) (\(.label)) [sys_id: \(.sys_id)]"'
        echo ""

        # Check if "functional" exists
        FUNCTIONAL_SYS_ID=$(echo "$TEST_TYPES" | jq -r '.result[] | select(.name == "functional" or .value == "functional") | .sys_id // empty')

        if [ -n "$FUNCTIONAL_SYS_ID" ]; then
            echo -e "${GREEN}✓ Found 'functional' test type (sys_id: $FUNCTIONAL_SYS_ID)${NC}"
            echo ""
            echo -e "${BLUE}SOLUTION:${NC} Update workflow to use sys_id instead of string:"
            echo ""
            echo "  Change from:"
            echo "    \"test_type\": \"functional\""
            echo ""
            echo "  To:"
            echo "    \"test_type\": \"$FUNCTIONAL_SYS_ID\""
        else
            echo -e "${YELLOW}⚠  'functional' test type not found${NC}"
            echo ""
            echo -e "${YELLOW}OPTIONS:${NC}"
            echo "  1. Create 'functional' test type record"
            echo "  2. Use existing test type (see list above)"
            echo "  3. Use different test type name"
        fi
    fi
elif [ "$FIELD_TYPE" = "string" ]; then
    echo -e "${BLUE}Step 2: Field is a STRING - Value should work as-is${NC}"
    echo ""
    echo -e "${YELLOW}⚠  String value 'functional' was sent but field is empty${NC}"
    echo ""
    echo "Possible causes:"
    echo "  1. Field validation rules rejecting the value"
    echo "  2. Business rules clearing the field"
    echo "  3. ACL (Access Control List) preventing write"
    echo "  4. Client script modifying the value"
    echo ""
    echo -e "${BLUE}ACTION:${NC} Check ServiceNow logs and business rules"
elif [ "$FIELD_TYPE" = "choice" ]; then
    echo -e "${BLUE}Step 2: Field is a CHOICE - Need valid choice value${NC}"
    echo ""
    echo "Query valid choices:"
    echo "  ServiceNow UI: Configuration > Tables & Columns > Dictionary"
    echo "  Search for: sn_devops_performance_test_summary.test_type"
    echo "  Check 'Choices' related list"
else
    echo -e "${YELLOW}⚠  Unknown field type: $FIELD_TYPE${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Checking created record...${NC}"
RECORD_SYS_ID="fe6c4775c3057a50b71ef44c050131b6"
RECORD=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary/$RECORD_SYS_ID?sysparm_display_value=all&sysparm_fields=name,test_type,tool,duration,sys_created_on")

TEST_TYPE_VALUE=$(echo "$RECORD" | jq -r '.result.test_type.value // .result.test_type // "null"')
TEST_TYPE_DISPLAY=$(echo "$RECORD" | jq -r '.result.test_type.display_value // "null"')

echo "Record Details:"
echo "  Name: $(echo "$RECORD" | jq -r '.result.name')"
echo "  Created: $(echo "$RECORD" | jq -r '.result.sys_created_on')"
echo "  Test Type (value): $TEST_TYPE_VALUE"
echo "  Test Type (display): $TEST_TYPE_DISPLAY"
echo ""

if [ "$TEST_TYPE_VALUE" = "null" ] || [ "$TEST_TYPE_VALUE" = "" ]; then
    echo -e "${RED}✗ test_type field is NULL/empty${NC}"
    echo ""
    echo -e "${BLUE}DIAGNOSIS COMPLETE${NC}"
    echo ""
    echo "The test_type field is empty. Based on the field type:"
    if [ "$FIELD_TYPE" = "reference" ]; then
        echo "  - Field Type: REFERENCE to $REFERENCE_TABLE"
        echo "  - Current Payload: \"test_type\": \"functional\" (string)"
        echo "  - Required: sys_id from $REFERENCE_TABLE table"
        echo ""
        echo -e "${GREEN}RECOMMENDED FIX:${NC} Use Solution A in docs/SERVICENOW-SMOKE-TEST-TEST-TYPE-FIX.md"
        echo "  Query test type sys_id and use in payload"
    elif [ "$FIELD_TYPE" = "string" ]; then
        echo "  - Field Type: STRING"
        echo "  - Value sent but not saved (check business rules/ACLs)"
    elif [ "$FIELD_TYPE" = "choice" ]; then
        echo "  - Field Type: CHOICE"
        echo "  - Need valid choice value from sys_choice table"
    fi
else
    echo -e "${GREEN}✓ test_type field has value: $TEST_TYPE_VALUE${NC}"
    echo ""
    echo "If the value is not displaying in the ServiceNow UI:"
    echo "  1. Check if test type record exists (if reference field)"
    echo "  2. Refresh the ServiceNow UI"
    echo "  3. Check UI field configuration/permissions"
fi

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}Diagnostic Complete${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo "For detailed solutions, see:"
echo "  docs/SERVICENOW-SMOKE-TEST-TEST-TYPE-FIX.md"
