#!/usr/bin/env bash
#
# ServiceNow Security Tools Registration Script
#
# This script registers all security scanning tools used in the GitHub Actions
# MASTER-PIPELINE workflow with ServiceNow DevOps.
#
# Prerequisites:
# - .envrc file with ServiceNow credentials loaded
# - jq installed for JSON processing
#
# Usage:
#   source .envrc
#   ./scripts/register-servicenow-security-tools.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install jq first.${NC}"
    exit 1
fi

if [[ -z "${SERVICENOW_USERNAME:-}" ]] || [[ -z "${SERVICENOW_PASSWORD:-}" ]] || [[ -z "${SERVICENOW_INSTANCE_URL:-}" ]]; then
    echo -e "${RED}Error: ServiceNow credentials not found in environment.${NC}"
    echo "Please run: source .envrc"
    exit 1
fi

# ServiceNow configuration
BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)
TOOL_ID="2fe9c38bc36c72d0e1bbf0cb050131cc"  # GitHub Demo tool ID
REPO="Freundcloud/microservices-demo"
BRANCH="main"
API_URL="${SERVICENOW_INSTANCE_URL}/api/sn_devops/v2/devops/tool/softwarequality?toolId=${TOOL_ID}"

# Security tools to register
declare -A TOOLS=(
    ["CodeQL"]="SAST"
    ["Trivy"]="Container Security"
    ["Semgrep"]="SAST"
    ["Checkov"]="IaC Security"
    ["tfsec"]="IaC Security"
    ["OWASP Dependency Check"]="SCA"
    ["Polaris"]="Kubernetes Security"
)

echo -e "${GREEN}=== ServiceNow Security Tools Registration ===${NC}"
echo ""
echo "Instance: ${SERVICENOW_INSTANCE_URL}"
echo "Repository: ${REPO}"
echo "Branch: ${BRANCH}"
echo "Tool ID: ${TOOL_ID}"
echo ""

# Register each tool
counter=1
success_count=0
failed_tools=()

for tool_name in "${!TOOLS[@]}"; do
    tool_type="${TOOLS[$tool_name]}"

    echo -ne "${YELLOW}[$counter/${#TOOLS[@]}]${NC} Registering ${tool_name} (${tool_type})... "

    response=$(curl -s -X POST \
        -H "Authorization: Basic ${BASIC_AUTH}" \
        -H "Content-Type: application/json" \
        "${API_URL}" \
        -d "{
            \"scannerName\": \"${tool_name}\",
            \"scanType\": \"${tool_type}\",
            \"projectName\": \"${REPO}\",
            \"branchName\": \"${BRANCH}\",
            \"scanStatus\": \"success\"
        }")

    status=$(echo "${response}" | jq -r '.result.status // .error.message // "Unknown"')

    if [[ "${status}" == "Success" ]]; then
        echo -e "${GREEN}✓ Success${NC}"
        ((success_count++))
    else
        echo -e "${RED}✗ Failed: ${status}${NC}"
        failed_tools+=("${tool_name}")
    fi

    ((counter++))
done

echo ""
echo -e "${GREEN}=== Registration Summary ===${NC}"
echo "Total tools: ${#TOOLS[@]}"
echo -e "Successful: ${GREEN}${success_count}${NC}"
echo -e "Failed: ${RED}$((${#TOOLS[@]} - success_count))${NC}"

if [[ ${#failed_tools[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed tools:${NC}"
    for tool in "${failed_tools[@]}"; do
        echo "  - ${tool}"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}✅ All security tools registered successfully!${NC}"
echo ""
echo "Security scan results will now be sent to ServiceNow via:"
echo "  ${API_URL}"
echo ""
echo "To view results in ServiceNow:"
echo "  ServiceNow DevOps → Security → Scan Results"
echo "  Filter by: ${REPO}"

exit 0
