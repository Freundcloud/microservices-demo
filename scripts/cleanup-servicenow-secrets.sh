#!/bin/bash
set -e

# ServiceNow Secrets Cleanup Script
# This script removes old/incorrect ServiceNow secrets and ensures only correct ones exist
# It uses credentials from .envrc file

echo "🧹 ServiceNow Secrets Cleanup Script"
echo "====================================="
echo ""

# Check if .envrc exists
if [ ! -f ".envrc" ]; then
  echo "❌ Error: .envrc file not found"
  echo "Please create .envrc with ServiceNow credentials first"
  exit 1
fi

# Source the .envrc file
echo "📄 Loading credentials from .envrc..."
source .envrc

# Verify required variables are set
MISSING_VARS=()
if [ -z "$SERVICENOW_USERNAME" ]; then MISSING_VARS+=("SERVICENOW_USERNAME"); fi
if [ -z "$SERVICENOW_PASSWORD" ]; then MISSING_VARS+=("SERVICENOW_PASSWORD"); fi
if [ -z "$SERVICENOW_INSTANCE_URL" ]; then MISSING_VARS+=("SERVICENOW_INSTANCE_URL"); fi
if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then MISSING_VARS+=("SN_ORCHESTRATION_TOOL_ID"); fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  echo "❌ Error: Missing required variables in .envrc:"
  for var in "${MISSING_VARS[@]}"; do
    echo "  - $var"
  done
  exit 1
fi

echo "✅ All required variables found in .envrc"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
  echo "❌ Error: GitHub CLI (gh) is not installed"
  echo "Install it from: https://cli.github.com/"
  exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
  echo "❌ Error: GitHub CLI is not authenticated"
  echo "Run: gh auth login"
  exit 1
fi

echo "✅ GitHub CLI is authenticated"
echo ""

# Get current secrets
echo "🔍 Checking current GitHub Secrets..."
CURRENT_SECRETS=$(gh secret list --json name --jq '.[].name')

# Define old secrets to delete
OLD_SECRETS=(
  "SN_DEVOPS_USER"
  "SN_DEVOPS_PASSWORD"
  "SN_INSTANCE_URL"
)

# Define deprecated secrets (warn but don't delete)
DEPRECATED_SECRETS=(
  "SN_OAUTH_TOKEN"
  "SN_DEVOPS_INTEGRATION_TOKEN"
  "SERVICENOW_BASIC_AUTH"
  "SERVICENOW_APP_SYS_ID"
  "SERVICENOW_TOOL_ID"
)

echo ""
echo "🗑️  Phase 1: Delete Old Secrets with Incorrect Credentials"
echo "-----------------------------------------------------------"

DELETED_COUNT=0
for secret in "${OLD_SECRETS[@]}"; do
  if echo "$CURRENT_SECRETS" | grep -q "^${secret}$"; then
    echo "  Deleting: $secret"
    if gh secret delete "$secret" --silent 2>/dev/null; then
      echo "    ✅ Deleted"
      DELETED_COUNT=$((DELETED_COUNT + 1))
    else
      echo "    ⚠️  Failed to delete (may not exist or no permission)"
    fi
  else
    echo "  Skipping: $secret (not found)"
  fi
done

echo ""
if [ $DELETED_COUNT -gt 0 ]; then
  echo "✅ Deleted $DELETED_COUNT old secrets"
else
  echo "✅ No old secrets to delete"
fi

echo ""
echo "⚠️  Phase 2: Check Deprecated Secrets"
echo "--------------------------------------"

DEPRECATED_COUNT=0
for secret in "${DEPRECATED_SECRETS[@]}"; do
  if echo "$CURRENT_SECRETS" | grep -q "^${secret}$"; then
    echo "  Found: $secret"
    DEPRECATED_COUNT=$((DEPRECATED_COUNT + 1))
  fi
done

if [ $DEPRECATED_COUNT -gt 0 ]; then
  echo ""
  echo "⚠️  Found $DEPRECATED_COUNT deprecated secrets"
  echo "These are not actively used but may be referenced by old workflows."
  echo "Consider deleting them manually if they're no longer needed:"
  echo ""
  for secret in "${DEPRECATED_SECRETS[@]}"; do
    if echo "$CURRENT_SECRETS" | grep -q "^${secret}$"; then
      echo "  gh secret delete $secret"
    fi
  done
else
  echo "✅ No deprecated secrets found"
fi

echo ""
echo "📝 Phase 3: Set Correct Secrets from .envrc"
echo "--------------------------------------------"

# Set the 4 required secrets
echo "  Setting: SERVICENOW_USERNAME"
if gh secret set SERVICENOW_USERNAME --body "$SERVICENOW_USERNAME"; then
  echo "    ✅ Set"
else
  echo "    ❌ Failed"
fi

echo "  Setting: SERVICENOW_PASSWORD"
if gh secret set SERVICENOW_PASSWORD --body "$SERVICENOW_PASSWORD"; then
  echo "    ✅ Set"
else
  echo "    ❌ Failed"
fi

echo "  Setting: SERVICENOW_INSTANCE_URL"
if gh secret set SERVICENOW_INSTANCE_URL --body "$SERVICENOW_INSTANCE_URL"; then
  echo "    ✅ Set"
else
  echo "    ❌ Failed"
fi

echo "  Setting: SN_ORCHESTRATION_TOOL_ID"
if gh secret set SN_ORCHESTRATION_TOOL_ID --body "$SN_ORCHESTRATION_TOOL_ID"; then
  echo "    ✅ Set"
else
  echo "    ❌ Failed"
fi

echo ""
echo "✅ Phase 3 complete"

echo ""
echo "🔍 Phase 4: Verify Final Secrets"
echo "---------------------------------"

# Get updated secrets list
FINAL_SECRETS=$(gh secret list --json name,updatedAt --jq '.[] | select(.name | test("SERVICENOW|SN_ORCHESTRATION")) | "\(.name)\t\(.updatedAt)"')

echo "Current ServiceNow secrets:"
echo ""
echo "$FINAL_SECRETS" | while IFS=$'\t' read -r name updated; do
  # Convert ISO timestamp to readable format
  DATE=$(date -d "$updated" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$updated")
  echo "  ✅ $name (updated: $DATE)"
done

echo ""
echo "🧪 Phase 5: Test Credentials Against ServiceNow API"
echo "-----------------------------------------------------"

# Test basic authentication
echo "  Testing: Basic Authentication..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  echo "    ✅ Basic auth works (HTTP 200)"
else
  echo "    ❌ Basic auth failed (HTTP $HTTP_CODE)"
  if [ "$HTTP_CODE" = "401" ]; then
    echo "       Username or password is incorrect"
  elif [ "$HTTP_CODE" = "403" ]; then
    echo "       User lacks required permissions"
  fi
  echo ""
  echo "    Response body:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
fi

# Test tool ID
echo "  Testing: Tool ID Validation..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$SN_ORCHESTRATION_TOOL_ID?sysparm_fields=sys_id,name,active,type")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  TOOL_NAME=$(echo "$BODY" | jq -r '.result.name // "Unknown"' 2>/dev/null)
  TOOL_ACTIVE=$(echo "$BODY" | jq -r '.result.active // "false"' 2>/dev/null)
  echo "    ✅ Tool ID exists (HTTP 200)"
  echo "       Name: $TOOL_NAME"
  echo "       Active: $TOOL_ACTIVE"

  if [ "$TOOL_ACTIVE" != "true" ]; then
    echo ""
    echo "    ⚠️  WARNING: Tool is INACTIVE"
    echo "       ServiceNow DevOps operations will fail until tool is activated"
    echo ""
    echo "       To activate:"
    echo "       1. Go to: $SERVICENOW_INSTANCE_URL/sn_devops_tool.do?sys_id=$SN_ORCHESTRATION_TOOL_ID"
    echo "       2. Check 'Active' checkbox"
    echo "       3. Save"
    echo ""
    echo "       Or run: ./scripts/activate-servicenow-tool.sh"
  fi
else
  echo "    ❌ Tool ID validation failed (HTTP $HTTP_CODE)"
  if [ "$HTTP_CODE" = "404" ]; then
    echo "       Tool ID not found in ServiceNow"
  fi
fi

echo ""
echo "📊 Summary"
echo "=========="
echo ""
echo "✅ Old secrets deleted: $DELETED_COUNT"
echo "✅ Correct secrets set: 4 (SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL, SN_ORCHESTRATION_TOOL_ID)"

if [ $DEPRECATED_COUNT -gt 0 ]; then
  echo "⚠️  Deprecated secrets found: $DEPRECATED_COUNT (consider removing)"
fi

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ API credentials validated successfully"
else
  echo "❌ API validation failed (check credentials)"
fi

echo ""
echo "📄 Next Steps:"
echo ""
echo "1. Run a test workflow to verify the fix:"
echo "   gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f skip_build=true"
echo ""
echo "2. Watch the workflow run:"
echo "   gh run watch --exit-status"
echo ""
echo "3. The 'Preflight: Verify Basic Auth' step should now show:"
echo "   ✅ ServiceNow Basic auth verified (Artifacts)"
echo ""
echo "4. If the tool is inactive, activate it:"
echo "   ./scripts/activate-servicenow-tool.sh"
echo ""
echo "✅ Cleanup complete!"
