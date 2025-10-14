#!/usr/bin/env bash
# Setup ServiceNow GitHub Secrets
# This script helps configure GitHub Secrets for ServiceNow integration

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ServiceNow GitHub Secrets Setup ===${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}ERROR: GitHub CLI (gh) is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}ERROR: Not authenticated with GitHub CLI${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✓ GitHub CLI is installed and authenticated${NC}"
echo ""

# Function to prompt for secret value
prompt_secret() {
    local secret_name=$1
    local description=$2
    local example=$3

    echo -e "${YELLOW}Setting up: ${secret_name}${NC}"
    echo -e "${BLUE}Description: ${description}${NC}"
    echo -e "${BLUE}Example: ${example}${NC}"

    read -rsp "Enter value (input hidden): " secret_value
    echo ""

    if [ -z "$secret_value" ]; then
        echo -e "${RED}ERROR: Value cannot be empty${NC}"
        return 1
    fi

    echo "$secret_value"
}

# Function to set GitHub secret
set_github_secret() {
    local secret_name=$1
    local secret_value=$2

    if gh secret set "$secret_name" --body "$secret_value" &> /dev/null; then
        echo -e "${GREEN}✓ ${secret_name} set successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to set ${secret_name}${NC}"
        return 1
    fi
}

echo -e "${BLUE}This script will guide you through setting up ServiceNow integration secrets.${NC}"
echo -e "${BLUE}You'll need the following information from your ServiceNow instance:${NC}"
echo ""
echo "  1. ServiceNow instance URL"
echo "  2. DevOps integration user credentials"
echo "  3. Orchestration tool ID (sys_id)"
echo "  4. Security scanner tool IDs (sys_id for each scanner)"
echo ""
read -rp "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Array to track success
declare -A secrets_status

# ServiceNow connection details
echo -e "${GREEN}=== ServiceNow Connection Details ===${NC}"
echo ""

# SN_INSTANCE_URL
secret_value=$(prompt_secret \
    "SN_INSTANCE_URL" \
    "ServiceNow instance URL" \
    "https://your-org.service-now.com")
set_github_secret "SN_INSTANCE_URL" "$secret_value" && secrets_status[SN_INSTANCE_URL]=1 || secrets_status[SN_INSTANCE_URL]=0
echo ""

# SN_DEVOPS_USER
secret_value=$(prompt_secret \
    "SN_DEVOPS_USER" \
    "ServiceNow DevOps integration username" \
    "devops-integration")
set_github_secret "SN_DEVOPS_USER" "$secret_value" && secrets_status[SN_DEVOPS_USER]=1 || secrets_status[SN_DEVOPS_USER]=0
echo ""

# SN_DEVOPS_PASSWORD
secret_value=$(prompt_secret \
    "SN_DEVOPS_PASSWORD" \
    "ServiceNow DevOps integration password" \
    "(your secure password)")
set_github_secret "SN_DEVOPS_PASSWORD" "$secret_value" && secrets_status[SN_DEVOPS_PASSWORD]=1 || secrets_status[SN_DEVOPS_PASSWORD]=0
echo ""

# Orchestration tool ID
echo -e "${GREEN}=== Orchestration Tool Configuration ===${NC}"
echo ""

secret_value=$(prompt_secret \
    "SN_ORCHESTRATION_TOOL_ID" \
    "GitHub orchestration tool sys_id from ServiceNow" \
    "abc123def456ghi789...")
set_github_secret "SN_ORCHESTRATION_TOOL_ID" "$secret_value" && secrets_status[SN_ORCHESTRATION_TOOL_ID]=1 || secrets_status[SN_ORCHESTRATION_TOOL_ID]=0
echo ""

# Security scanner tool IDs
echo -e "${GREEN}=== Security Scanner Tool IDs ===${NC}"
echo ""

# CodeQL
secret_value=$(prompt_secret \
    "SN_CODEQL_TOOL_ID" \
    "CodeQL scanner sys_id from ServiceNow" \
    "def456ghi789jkl012...")
set_github_secret "SN_CODEQL_TOOL_ID" "$secret_value" && secrets_status[SN_CODEQL_TOOL_ID]=1 || secrets_status[SN_CODEQL_TOOL_ID]=0
echo ""

# Semgrep
secret_value=$(prompt_secret \
    "SN_SEMGREP_TOOL_ID" \
    "Semgrep scanner sys_id from ServiceNow" \
    "ghi789jkl012mno345...")
set_github_secret "SN_SEMGREP_TOOL_ID" "$secret_value" && secrets_status[SN_SEMGREP_TOOL_ID]=1 || secrets_status[SN_SEMGREP_TOOL_ID]=0
echo ""

# Trivy
secret_value=$(prompt_secret \
    "SN_TRIVY_TOOL_ID" \
    "Trivy scanner sys_id from ServiceNow" \
    "jkl012mno345pqr678...")
set_github_secret "SN_TRIVY_TOOL_ID" "$secret_value" && secrets_status[SN_TRIVY_TOOL_ID]=1 || secrets_status[SN_TRIVY_TOOL_ID]=0
echo ""

# Checkov
secret_value=$(prompt_secret \
    "SN_CHECKOV_TOOL_ID" \
    "Checkov scanner sys_id from ServiceNow" \
    "mno345pqr678stu901...")
set_github_secret "SN_CHECKOV_TOOL_ID" "$secret_value" && secrets_status[SN_CHECKOV_TOOL_ID]=1 || secrets_status[SN_CHECKOV_TOOL_ID]=0
echo ""

# OWASP
secret_value=$(prompt_secret \
    "SN_OWASP_TOOL_ID" \
    "OWASP Dependency Check scanner sys_id from ServiceNow" \
    "pqr678stu901vwx234...")
set_github_secret "SN_OWASP_TOOL_ID" "$secret_value" && secrets_status[SN_OWASP_TOOL_ID]=1 || secrets_status[SN_OWASP_TOOL_ID]=0
echo ""

# Summary
echo ""
echo -e "${BLUE}=== Setup Summary ===${NC}"
echo ""

success_count=0
fail_count=0

for secret in "${!secrets_status[@]}"; do
    if [ "${secrets_status[$secret]}" -eq 1 ]; then
        echo -e "${GREEN}✓ ${secret}${NC}"
        ((success_count++))
    else
        echo -e "${RED}✗ ${secret}${NC}"
        ((fail_count++))
    fi
done

echo ""
echo -e "${BLUE}Total: ${success_count} succeeded, ${fail_count} failed${NC}"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}=== All secrets configured successfully! ===${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Verify secrets in GitHub: Settings > Secrets and variables > Actions"
    echo "  2. Trigger a security scan workflow to test integration"
    echo "  3. Check ServiceNow DevOps dashboard for scan results"
    echo ""
    echo "For detailed documentation, see: docs/SERVICENOW-INTEGRATION.md"
else
    echo -e "${RED}=== Some secrets failed to configure ===${NC}"
    echo ""
    echo "Please review the errors above and retry for failed secrets using:"
    echo "  gh secret set SECRET_NAME --body 'value'"
fi

echo ""
echo -e "${BLUE}Done!${NC}"
