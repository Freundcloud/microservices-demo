#!/bin/bash
#
# ServiceNow Webhook Permissions Fix Script
#
# This script helps fix the "Existing webhooks cannot be retrieved" error
# by guiding you through updating GitHub credentials in ServiceNow.
#
# Usage: ./scripts/fix-servicenow-webhook-permissions.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ServiceNow configuration
SERVICENOW_INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"
TOOL_ID="${SN_ORCHESTRATION_TOOL_ID:-4c5e482cc3383214e1bbf0cb05013196}"
REPO="Freundcloud/microservices-demo"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ServiceNow Webhook Permissions Fix${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Verify current webhook status
echo -e "${YELLOW}Step 1: Verifying GitHub webhook status...${NC}"
echo ""

WEBHOOKS=$(gh api /repos/$REPO/hooks 2>/dev/null | jq -r '.[] | select(.config.url | contains("calitiiltddemo3")) | {id, url: .config.url, active, last_response}')

if [ -z "$WEBHOOKS" ]; then
  echo -e "${RED}❌ ERROR: Could not retrieve webhooks from GitHub${NC}"
  echo "Make sure you have GitHub CLI (gh) configured and authenticated."
  exit 1
fi

WEBHOOK_COUNT=$(echo "$WEBHOOKS" | jq -s 'length')
echo -e "${GREEN}✅ Found $WEBHOOK_COUNT active ServiceNow webhooks in GitHub${NC}"
echo ""
echo "$WEBHOOKS" | jq -r '. | "  - \(.url) (active: \(.active), last response: \(.last_response.code))"'
echo ""

# Step 2: Check current ServiceNow tool configuration
echo -e "${YELLOW}Step 2: Checking ServiceNow tool configuration...${NC}"
echo ""

if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
  echo -e "${YELLOW}⚠️  ServiceNow credentials not found in environment${NC}"
  echo "Please enter ServiceNow credentials:"
  read -p "Username: " SERVICENOW_USERNAME
  read -sp "Password: " SERVICENOW_PASSWORD
  echo ""
fi

TOOL_INFO=$(curl -s -H "Accept: application/json" \
  --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_tool/$TOOL_ID?sysparm_fields=name,type,auth_type,url" 2>/dev/null)

if echo "$TOOL_INFO" | jq -e '.error' > /dev/null 2>&1; then
  echo -e "${RED}❌ ERROR: Could not retrieve ServiceNow tool configuration${NC}"
  echo "Response: $TOOL_INFO"
  exit 1
fi

echo -e "${GREEN}✅ Successfully retrieved ServiceNow tool configuration${NC}"
echo ""
echo "$TOOL_INFO" | jq -r '.result | "  Tool Name: \(.name)\n  Tool Type: \(.type)\n  Auth Type: \(.auth_type // "Not set")\n  Repository URL: \(.url)"'
echo ""

# Step 3: Guide user through GitHub token/app creation
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 3: Update GitHub Credentials${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "The webhook permissions error occurs because the GitHub credentials"
echo "in ServiceNow don't have the 'admin:repo_hook' (read) permission."
echo ""
echo "You have two options:"
echo ""
echo -e "${GREEN}Option A: Update Personal Access Token (PAT)${NC}"
echo "  1. Go to: https://github.com/settings/tokens"
echo "  2. Find your ServiceNow integration token"
echo "  3. Click 'Edit' or 'Regenerate token'"
echo "  4. Ensure these scopes are checked:"
echo "     ✅ repo (Full control of private repositories)"
echo "     ✅ admin:repo_hook (Full control of repository hooks)"
echo "        ✅ write:repo_hook"
echo "        ✅ read:repo_hook  ← REQUIRED TO FIX THIS ISSUE"
echo "  5. Click 'Update token' or 'Regenerate token'"
echo "  6. Copy the new token (shown only once!)"
echo ""
echo -e "${GREEN}Option B: Use GitHub App (Recommended)${NC}"
echo "  1. Go to: https://github.com/organizations/Freundcloud/settings/apps"
echo "  2. Click 'New GitHub App'"
echo "  3. Configure app with these repository permissions:"
echo "     - Webhooks: Read & write  ← REQUIRED"
echo "     - Actions: Read & write"
echo "     - Contents: Read & write"
echo "     - Pull requests: Read & write"
echo "  4. Create app and note:"
echo "     - App ID"
echo "     - Installation ID"
echo "     - Generate and download private key"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Which option do you want to use? (A for PAT / B for GitHub App): " OPTION

case "$OPTION" in
  [Aa]*)
    # Option A: Personal Access Token
    echo ""
    echo -e "${YELLOW}Option A: Personal Access Token${NC}"
    echo ""
    read -sp "Enter your new GitHub Personal Access Token (with admin:repo_hook): " GITHUB_PAT
    echo ""

    if [ -z "$GITHUB_PAT" ]; then
      echo -e "${RED}❌ ERROR: Token cannot be empty${NC}"
      exit 1
    fi

    # Verify token has correct permissions
    echo ""
    echo -e "${YELLOW}Verifying token permissions...${NC}"

    TOKEN_SCOPES=$(curl -s -H "Authorization: token $GITHUB_PAT" \
      -I https://api.github.com/user | grep -i "x-oauth-scopes" | cut -d: -f2 | tr -d ' ')

    if [[ ! "$TOKEN_SCOPES" =~ "admin:repo_hook" ]] && [[ ! "$TOKEN_SCOPES" =~ "repo" ]]; then
      echo -e "${RED}❌ ERROR: Token does not have admin:repo_hook or repo scope${NC}"
      echo "Token scopes: $TOKEN_SCOPES"
      echo "Please regenerate token with correct permissions."
      exit 1
    fi

    echo -e "${GREEN}✅ Token has correct permissions${NC}"
    echo "Token scopes: $TOKEN_SCOPES"
    echo ""

    # Update ServiceNow tool configuration
    echo -e "${YELLOW}Updating ServiceNow tool configuration...${NC}"

    UPDATE_PAYLOAD=$(jq -n --arg token "$GITHUB_PAT" '{token: $token}')

    UPDATE_RESPONSE=$(curl -s -X PATCH \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -d "$UPDATE_PAYLOAD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_tool/$TOOL_ID")

    if echo "$UPDATE_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
      echo -e "${RED}❌ ERROR: Failed to update ServiceNow tool configuration${NC}"
      echo "Response: $UPDATE_RESPONSE"
      exit 1
    fi

    echo -e "${GREEN}✅ Successfully updated ServiceNow tool with new token${NC}"
    ;;

  [Bb]*)
    # Option B: GitHub App
    echo ""
    echo -e "${YELLOW}Option B: GitHub App${NC}"
    echo ""
    read -p "Enter GitHub App ID: " APP_ID
    read -p "Enter GitHub App Installation ID: " INSTALLATION_ID
    echo "Enter GitHub App Private Key (paste entire key, then press Ctrl+D):"
    PRIVATE_KEY=$(cat)

    if [ -z "$APP_ID" ] || [ -z "$INSTALLATION_ID" ] || [ -z "$PRIVATE_KEY" ]; then
      echo -e "${RED}❌ ERROR: App ID, Installation ID, and Private Key are required${NC}"
      exit 1
    fi

    # Update ServiceNow tool configuration
    echo ""
    echo -e "${YELLOW}Updating ServiceNow tool configuration...${NC}"

    UPDATE_PAYLOAD=$(jq -n \
      --arg app_id "$APP_ID" \
      --arg installation_id "$INSTALLATION_ID" \
      --arg private_key "$PRIVATE_KEY" \
      '{
        auth_type: "github_app",
        app_id: $app_id,
        installation_id: $installation_id,
        private_key: $private_key
      }')

    UPDATE_RESPONSE=$(curl -s -X PATCH \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -d "$UPDATE_PAYLOAD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_tool/$TOOL_ID")

    if echo "$UPDATE_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
      echo -e "${RED}❌ ERROR: Failed to update ServiceNow tool configuration${NC}"
      echo "Response: $UPDATE_RESPONSE"
      exit 1
    fi

    echo -e "${GREEN}✅ Successfully updated ServiceNow tool with GitHub App${NC}"
    ;;

  *)
    echo -e "${RED}❌ Invalid option. Please run the script again and choose A or B.${NC}"
    exit 1
    ;;
esac

# Step 4: Verify the fix
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 4: Verifying the fix...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Please verify the following in ServiceNow:"
echo ""
echo "1. Navigate to:"
echo "   $SERVICENOW_INSTANCE_URL/sn_devops_orchestration_tool.do?sys_id=$TOOL_ID"
echo ""
echo "2. Check that:"
echo "   ✅ No warning about webhook configuration"
echo "   ✅ 'Test Connection' button succeeds"
echo "   ✅ Webhooks section shows all $WEBHOOK_COUNT webhooks"
echo ""
echo "3. Check error logs:"
echo "   $SERVICENOW_INSTANCE_URL/nav_to.do?uri=syslog_list.do"
echo "   Should see no errors about webhook permissions"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ ServiceNow tool configuration updated successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "1. Verify in ServiceNow UI (URLs above)"
echo "2. Test webhook delivery by triggering a GitHub Actions workflow"
echo "3. Check ServiceNow event logs for incoming webhooks"
echo ""
echo "Documentation: docs/SERVICENOW-WEBHOOK-PERMISSIONS-FIX.md"
echo ""
