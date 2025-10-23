#!/bin/bash
#
# Complete ServiceNow Integration Setup Script
# This script automates the entire setup process
#
# Usage:
#   source .envrc
#   ./scripts/setup-servicenow-integration.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ServiceNow Integration - Complete Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Verify environment variables
echo -e "${YELLOW}Step 1/4: Verifying environment variables...${NC}"
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ] || [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
    echo -e "${RED}❌ Environment variables not loaded${NC}"
    echo "Please run: source .envrc"
    exit 1
fi
echo -e "${GREEN}✅ Environment variables loaded${NC}"
echo ""

# Step 2: Test ServiceNow API connectivity
echo -e "${YELLOW}Step 2/4: Testing ServiceNow API connectivity...${NC}"
./scripts/verify-servicenow-api.sh > /tmp/sn-verify.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All ServiceNow API tests passed${NC}"
else
    echo -e "${RED}❌ ServiceNow API tests failed${NC}"
    echo "Check the log: /tmp/sn-verify.log"
    exit 1
fi
echo ""

# Step 3: Set GitHub Secrets
echo -e "${YELLOW}Step 3/4: Setting GitHub Secrets...${NC}"

echo "  Setting SERVICENOW_USERNAME..."
gh secret set SERVICENOW_USERNAME --body "$SERVICENOW_USERNAME" 2>/dev/null
echo -e "  ${GREEN}✅ SERVICENOW_USERNAME${NC}"

echo "  Setting SERVICENOW_PASSWORD..."
gh secret set SERVICENOW_PASSWORD --body "$SERVICENOW_PASSWORD" 2>/dev/null
echo -e "  ${GREEN}✅ SERVICENOW_PASSWORD${NC}"

echo "  Setting SERVICENOW_INSTANCE_URL..."
gh secret set SERVICENOW_INSTANCE_URL --body "$SERVICENOW_INSTANCE_URL" 2>/dev/null
echo -e "  ${GREEN}✅ SERVICENOW_INSTANCE_URL${NC}"

echo "  Setting SN_ORCHESTRATION_TOOL_ID..."
gh secret set SN_ORCHESTRATION_TOOL_ID --body "$SN_ORCHESTRATION_TOOL_ID" 2>/dev/null
echo -e "  ${GREEN}✅ SN_ORCHESTRATION_TOOL_ID${NC}"

echo ""

# Step 4: Verify GitHub Secrets
echo -e "${YELLOW}Step 4/4: Verifying GitHub Secrets...${NC}"
SECRETS=$(gh secret list 2>/dev/null | grep -E "SERVICENOW_USERNAME|SERVICENOW_PASSWORD|SERVICENOW_INSTANCE_URL|SN_ORCHESTRATION_TOOL_ID")
if echo "$SECRETS" | grep -q "SERVICENOW_USERNAME" && \
   echo "$SECRETS" | grep -q "SERVICENOW_PASSWORD" && \
   echo "$SECRETS" | grep -q "SERVICENOW_INSTANCE_URL" && \
   echo "$SECRETS" | grep -q "SN_ORCHESTRATION_TOOL_ID"; then
    echo -e "${GREEN}✅ All GitHub Secrets verified${NC}"
else
    echo -e "${RED}❌ Some GitHub Secrets are missing${NC}"
    exit 1
fi
echo ""

# Bonus: Try to activate tool
echo -e "${YELLOW}Bonus: Attempting to activate ServiceNow tool...${NC}"
./scripts/activate-servicenow-tool.sh > /tmp/sn-activate.log 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ServiceNow tool activated${NC}"
else
    echo -e "${YELLOW}⚠️  Tool activation via API failed${NC}"
    echo "Please activate manually in ServiceNow UI"
    echo "URL: $SERVICENOW_INSTANCE_URL/sn_devops_tool.do?sys_id=$SN_ORCHESTRATION_TOOL_ID"
fi
echo ""

# Final summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Your ServiceNow integration is now configured with:"
echo "  ✅ API connectivity verified"
echo "  ✅ GitHub Secrets configured"
echo "  ✅ Enhanced error diagnostics enabled"
echo "  ✅ GitHub context in change requests"
echo ""
echo "Next steps:"
echo "  1. Verify tool is active in ServiceNow (if not done automatically)"
echo "  2. Trigger a workflow: git push"
echo "  3. Monitor in ServiceNow: $SERVICENOW_INSTANCE_URL/now/devops-change/home"
echo ""
echo "Documentation:"
echo "  - API troubleshooting: docs/SERVICENOW-AUTHENTICATION-TROUBLESHOOTING.md"
echo "  - Integration guide: docs/GITHUB-SERVICENOW-INTEGRATION-GUIDE.md"
echo ""
