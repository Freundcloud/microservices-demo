#!/bin/bash
set -e

# Script to create custom fields in ServiceNow change_request table for test results
# These fields link unit tests and SonarCloud scans to change requests

echo "=========================================="
echo "ServiceNow Custom Test Fields Creator"
echo "=========================================="
echo ""

# Check required environment variables
if [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo "❌ ERROR: Required environment variables not set"
  echo ""
  echo "Please set the following variables:"
  echo "  export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'"
  echo "  export SERVICENOW_USERNAME='your-username'"
  echo "  export SERVICENOW_PASSWORD='your-password'"
  echo ""
  echo "Or source your .envrc file:"
  echo "  source .envrc"
  exit 1
fi

echo "✓ ServiceNow credentials loaded"
echo "  Instance: $SERVICENOW_INSTANCE_URL"
echo "  Username: $SERVICENOW_USERNAME"
echo ""

# Function to create a custom field
create_field() {
  local field_name=$1
  local field_label=$2
  local field_type=$3
  local max_length=$4
  local field_help=$5

  echo "Creating field: $field_name ($field_label)..."

  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" \
    -d "{
      \"name\": \"change_request\",
      \"element\": \"$field_name\",
      \"column_label\": \"$field_label\",
      \"internal_type\": \"$field_type\",
      \"max_length\": \"$max_length\",
      \"active\": \"true\",
      \"read_only\": \"false\",
      \"mandatory\": \"false\",
      \"display\": \"true\",
      \"comments\": \"$field_help\"
    }")

  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  if [ "$HTTP_CODE" = "201" ]; then
    echo "  ✓ Created successfully"
  elif [ "$HTTP_CODE" = "400" ] && echo "$BODY" | grep -q "already exists"; then
    echo "  ⚠ Field already exists (skipping)"
  else
    echo "  ❌ Failed (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  fi
  echo ""
}

echo "=========================================="
echo "Creating Unit Test Result Fields"
echo "=========================================="
echo ""

create_field \
  "u_unit_test_status" \
  "Unit Test Status" \
  "string" \
  "20" \
  "Overall status of unit tests (passed/failed/skipped)"

create_field \
  "u_unit_test_total" \
  "Unit Tests Total" \
  "integer" \
  "40" \
  "Total number of unit tests executed"

create_field \
  "u_unit_test_passed" \
  "Unit Tests Passed" \
  "integer" \
  "40" \
  "Number of unit tests that passed"

create_field \
  "u_unit_test_failed" \
  "Unit Tests Failed" \
  "integer" \
  "40" \
  "Number of unit tests that failed"

create_field \
  "u_unit_test_coverage" \
  "Unit Test Coverage" \
  "string" \
  "10" \
  "Code coverage percentage from unit tests"

create_field \
  "u_unit_test_url" \
  "Unit Test Results URL" \
  "url" \
  "1024" \
  "Link to detailed unit test results in GitHub Actions"

echo "=========================================="
echo "Creating SonarCloud Result Fields"
echo "=========================================="
echo ""

create_field \
  "u_sonarcloud_status" \
  "SonarCloud Quality Gate" \
  "string" \
  "20" \
  "SonarCloud quality gate status (passed/failed/warning)"

create_field \
  "u_sonarcloud_bugs" \
  "SonarCloud Bugs" \
  "integer" \
  "40" \
  "Number of bugs detected by SonarCloud"

create_field \
  "u_sonarcloud_vulnerabilities" \
  "SonarCloud Vulnerabilities" \
  "integer" \
  "40" \
  "Number of security vulnerabilities detected by SonarCloud"

create_field \
  "u_sonarcloud_code_smells" \
  "SonarCloud Code Smells" \
  "integer" \
  "40" \
  "Number of code smells (maintainability issues) detected"

create_field \
  "u_sonarcloud_coverage" \
  "SonarCloud Coverage" \
  "string" \
  "10" \
  "Code coverage percentage from SonarCloud analysis"

create_field \
  "u_sonarcloud_duplications" \
  "SonarCloud Duplications" \
  "string" \
  "10" \
  "Code duplication percentage from SonarCloud"

create_field \
  "u_sonarcloud_url" \
  "SonarCloud Dashboard URL" \
  "url" \
  "1024" \
  "Link to SonarCloud project dashboard"

echo "=========================================="
echo "Field Creation Complete"
echo "=========================================="
echo ""
echo "✓ All custom test result fields have been created"
echo ""
echo "Next Steps:"
echo "1. Verify fields in ServiceNow:"
echo "   $SERVICENOW_INSTANCE_URL/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
echo ""
echo "2. Update your GitHub Actions workflows to populate these fields"
echo ""
echo "3. Test the integration by running a deployment workflow"
echo ""
