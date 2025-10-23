#!/bin/bash
#
# Display GitHub Secrets Setup Instructions
# This script shows the exact values to copy into GitHub Secrets
#
# Usage:
#   source .envrc
#   ./scripts/show-github-secrets.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}         GitHub Secrets Setup for ServiceNow Integration        ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if .envrc is sourced
if [ -z "$SERVICENOW_USERNAME" ]; then
    echo -e "${YELLOW}⚠️  ERROR: Environment variables not loaded${NC}"
    echo ""
    echo "Please run: source .envrc"
    echo "Then run this script again."
    exit 1
fi

# Get repository info
if git remote get-url origin >/dev/null 2>&1; then
    REPO_URL=$(git remote get-url origin)
    REPO_URL=${REPO_URL%.git}
    REPO_URL=${REPO_URL#git@github.com:}
    REPO_URL=${REPO_URL#https://github.com/}
    GITHUB_REPO="$REPO_URL"
else
    GITHUB_REPO="<your-username>/<your-repo>"
fi

GITHUB_SECRETS_URL="https://github.com/${GITHUB_REPO}/settings/secrets/actions"

echo -e "${CYAN}📍 Repository:${NC} $GITHUB_REPO"
echo -e "${CYAN}🔗 GitHub Secrets URL:${NC}"
echo "   $GITHUB_SECRETS_URL"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  INSTRUCTIONS: Copy these values to GitHub Secrets${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Open this URL in your browser:"
echo "   $GITHUB_SECRETS_URL"
echo ""
echo "2. Click 'New repository secret' for each secret below"
echo ""
echo "3. Copy the Name and Value EXACTLY as shown:"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Secret #1${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Name:"
echo "SERVICENOW_USERNAME"
echo ""
echo "Value:"
echo "$SERVICENOW_USERNAME"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Secret #2${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Name:"
echo "SERVICENOW_PASSWORD"
echo ""
echo "Value:"
echo "$SERVICENOW_PASSWORD"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Copy the password exactly, including special characters (^ and >)${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Secret #3${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Name:"
echo "SERVICENOW_INSTANCE_URL"
echo ""
echo "Value:"
echo "$SERVICENOW_INSTANCE_URL"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Secret #4${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Name:"
echo "SN_ORCHESTRATION_TOOL_ID"
echo ""
echo "Value:"
echo "$SN_ORCHESTRATION_TOOL_ID"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Optional: Alternative Secret Names (for compatibility)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The workflow also supports these alternative names:"
echo ""
echo "SN_INSTANCE_URL = $SN_INSTANCE_URL"
echo "SN_DEVOPS_USER = (optional, defaults to SERVICENOW_USERNAME)"
echo "SN_DEVOPS_PASSWORD = (optional, defaults to SERVICENOW_PASSWORD)"
echo ""
echo -e "${YELLOW}Note: You only need ONE set. Use SERVICENOW_* names for consistency.${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ VERIFICATION${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "After setting all secrets in GitHub:"
echo ""
echo "1. Go to: https://github.com/${GITHUB_REPO}/actions"
echo "2. Select any workflow that uses ServiceNow"
echo "3. Click 'Run workflow' → Select branch → Run"
echo "4. Check the 'Validate ServiceNow Inputs' step shows:"
echo "   - URL: present"
echo "   - Username: present"
echo "   - Password: present"
echo "   - Tool ID: present"
echo ""
echo "5. Check the 'Preflight: Verify Basic Auth' step shows:"
echo "   ✅ ServiceNow Basic auth verified"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  📋 QUICK COPY FORMAT (for easy pasting)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "SERVICENOW_USERNAME"
echo "$SERVICENOW_USERNAME"
echo ""
echo "SERVICENOW_PASSWORD"
echo "$SERVICENOW_PASSWORD"
echo ""
echo "SERVICENOW_INSTANCE_URL"
echo "$SERVICENOW_INSTANCE_URL"
echo ""
echo "SN_ORCHESTRATION_TOOL_ID"
echo "$SN_ORCHESTRATION_TOOL_ID"
echo ""

# Create a summary file
SUMMARY_FILE="/tmp/github-secrets-summary.txt"
cat > "$SUMMARY_FILE" <<EOF
GitHub Secrets for ServiceNow Integration
Repository: $GITHUB_REPO
Settings URL: $GITHUB_SECRETS_URL

Required Secrets (copy Name and Value exactly):

1. SERVICENOW_USERNAME
   $SERVICENOW_USERNAME

2. SERVICENOW_PASSWORD
   $SERVICENOW_PASSWORD

3. SERVICENOW_INSTANCE_URL
   $SERVICENOW_INSTANCE_URL

4. SN_ORCHESTRATION_TOOL_ID
   $SN_ORCHESTRATION_TOOL_ID

Instructions:
1. Open: $GITHUB_SECRETS_URL
2. Click "New repository secret" for each secret
3. Copy Name and Value exactly as shown above
4. Click "Add secret"
5. Repeat for all 4 secrets

Verification:
- Run any workflow with ServiceNow integration
- Check "Validate ServiceNow Inputs" step shows all "present"
- Check "Preflight" step shows authentication success
EOF

echo -e "${GREEN}✅ Summary saved to: $SUMMARY_FILE${NC}"
echo ""
echo "You can view this file anytime with: cat $SUMMARY_FILE"
echo ""
