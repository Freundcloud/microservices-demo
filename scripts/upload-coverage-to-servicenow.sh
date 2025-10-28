#!/bin/bash
set -e

###############################################################################
# Upload Code Coverage Metrics to ServiceNow
#
# This script uploads code coverage metrics to ServiceNow DevOps for tracking
# test quality over time.
#
# Usage:
#   ./scripts/upload-coverage-to-servicenow.sh <service> <coverage-file>
#
# Environment Variables (required):
#   SERVICENOW_USERNAME       - ServiceNow integration user
#   SERVICENOW_PASSWORD       - ServiceNow password
#   SERVICENOW_INSTANCE_URL   - ServiceNow instance URL
#   GITHUB_SHA                - Git commit SHA
#   GITHUB_RUN_ID            - GitHub workflow run ID
#   GITHUB_REPOSITORY        - GitHub repository name
#
# Example:
#   export SERVICENOW_USERNAME="devops.integration"
#   export SERVICENOW_PASSWORD="your-password"
#   export SERVICENOW_INSTANCE_URL="https://yourinstance.service-now.com"
#   ./scripts/upload-coverage-to-servicenow.sh frontend coverage.xml
#
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Usage: $0 <service> <coverage-file>"
    echo "Example: $0 frontend coverage.xml"
    exit 1
fi

SERVICE="$1"
COVERAGE_FILE="$2"

# Check required environment variables
REQUIRED_VARS=("SERVICENOW_USERNAME" "SERVICENOW_PASSWORD" "SERVICENOW_INSTANCE_URL" "GITHUB_SHA" "GITHUB_RUN_ID" "GITHUB_REPOSITORY")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: Required environment variable $var is not set${NC}"
        exit 1
    fi
done

# Check if coverage file exists
if [ ! -f "$COVERAGE_FILE" ]; then
    echo -e "${YELLOW}Warning: Coverage file not found: $COVERAGE_FILE${NC}"
    echo "Skipping coverage upload for $SERVICE"
    exit 0
fi

echo "========================================="
echo "Upload Code Coverage to ServiceNow"
echo "========================================="
echo "Service: $SERVICE"
echo "Coverage File: $COVERAGE_FILE"
echo "Commit: ${GITHUB_SHA:0:8}"
echo "Workflow Run: $GITHUB_RUN_ID"
echo ""

# Extract coverage percentage from coverage.xml
# Supports Cobertura XML format (Go, Python, C#)
COVERAGE_PERCENT=$(grep -oP 'line-rate="\K[0-9.]+' "$COVERAGE_FILE" | head -1 || echo "0")

# Convert line-rate (0.0-1.0) to percentage (0-100)
COVERAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", $COVERAGE_PERCENT * 100}")

if [ -z "$COVERAGE_PERCENT" ] || [ "$COVERAGE_PERCENT" == "0.00" ]; then
    echo -e "${YELLOW}Warning: Could not extract coverage percentage from $COVERAGE_FILE${NC}"
    echo "File format may not be Cobertura XML"
    COVERAGE_PERCENT="0.00"
fi

echo "Coverage: ${COVERAGE_PERCENT}%"

# Extract line counts (covered, total)
LINES_COVERED=$(grep -oP 'lines-covered="\K[0-9]+' "$COVERAGE_FILE" | head -1 || echo "0")
LINES_VALID=$(grep -oP 'lines-valid="\K[0-9]+' "$COVERAGE_FILE" | head -1 || echo "0")

echo "Lines Covered: $LINES_COVERED / $LINES_VALID"
echo ""

# Create JSON payload for ServiceNow
# Table: u_code_coverage (custom table - create if needed)
JSON_PAYLOAD=$(cat <<EOF
{
  "u_service": "$SERVICE",
  "u_coverage_percent": "$COVERAGE_PERCENT",
  "u_lines_covered": "$LINES_COVERED",
  "u_lines_total": "$LINES_VALID",
  "u_commit_sha": "$GITHUB_SHA",
  "u_workflow_run_id": "$GITHUB_RUN_ID",
  "u_repository": "$GITHUB_REPOSITORY",
  "u_coverage_file": "$COVERAGE_FILE"
}
EOF
)

echo "Uploading to ServiceNow..."
echo ""

# Upload to ServiceNow via REST API
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -d "$JSON_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/u_code_coverage")

# Extract HTTP status code (last line)
HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)

# Extract response body (all but last line)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✅ Coverage uploaded successfully${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE_BODY" | jq -r '.result.sys_id // .result' 2>/dev/null || echo "$RESPONSE_BODY"
    echo ""
    echo "View in ServiceNow:"
    echo "$SERVICENOW_INSTANCE_URL/now/nav/ui/classic/params/target/u_code_coverage_list.do"
    exit 0
else
    echo -e "${RED}❌ Failed to upload coverage${NC}"
    echo "HTTP Status: $HTTP_STATUS"
    echo ""
    echo "Response:"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
    echo ""

    if [ "$HTTP_STATUS" == "404" ]; then
        echo -e "${YELLOW}Note: Table 'u_code_coverage' may not exist yet.${NC}"
        echo "Create it in ServiceNow with these fields:"
        echo "  - u_service (String, 100)"
        echo "  - u_coverage_percent (Decimal)"
        echo "  - u_lines_covered (Integer)"
        echo "  - u_lines_total (Integer)"
        echo "  - u_commit_sha (String, 50)"
        echo "  - u_workflow_run_id (String, 100)"
        echo "  - u_repository (String, 200)"
        echo "  - u_coverage_file (String, 500)"
    fi

    # Don't fail the workflow, just warn
    exit 0
fi
