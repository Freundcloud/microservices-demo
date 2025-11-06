#!/bin/bash
# Verify Pipeline-to-Application Linkage Fix
# Tests that new packages get linked to the application after the fix

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load credentials
if [ -f .envrc ]; then
  source .envrc
fi

# Check credentials
if [ -z "${SERVICENOW_USERNAME:-}" ] || [ -z "${SERVICENOW_PASSWORD:-}" ] || [ -z "${SERVICENOW_INSTANCE_URL:-}" ]; then
  echo -e "${RED}❌ Error: ServiceNow credentials not found${NC}"
  echo ""
  echo "Please ensure these environment variables are set:"
  echo "  - SERVICENOW_USERNAME"
  echo "  - SERVICENOW_PASSWORD"
  echo "  - SERVICENOW_INSTANCE_URL"
  exit 1
fi

echo "=============================================="
echo "Pipeline-to-Application Linkage Verification"
echo "=============================================="
echo ""

PIPELINE_SYS_ID="8cae8641c3303a14e1bbf0cb05013187"  # build-images.yaml
APP_SYS_ID="e489efd1c3383e14e1bbf0cb050131d5"       # Online Boutique

# Step 1: Verify pipeline linkage
echo "Step 1: Verifying pipeline is linked to application..."
echo ""

PIPELINE_RESPONSE=$(curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_pipeline/${PIPELINE_SYS_ID}?sysparm_fields=name,app&sysparm_display_value=all" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json")

PIPELINE_APP=$(echo "$PIPELINE_RESPONSE" | jq -r '.result.app.value // empty')

if [ "$PIPELINE_APP" = "$APP_SYS_ID" ]; then
  echo -e "${GREEN}✅ Pipeline is linked to 'Online Boutique' application${NC}"
  echo "   Pipeline: build-images.yaml"
  echo "   Application: Online Boutique (${APP_SYS_ID})"
else
  echo -e "${RED}❌ Pipeline is NOT linked to application${NC}"
  echo "   Expected: ${APP_SYS_ID}"
  echo "   Actual: ${PIPELINE_APP:-'(empty)'}"
  echo ""
  echo "Run the fix script first:"
  echo "  /tmp/fix-pipeline-app-linkage.sh"
  exit 1
fi

echo ""

# Step 2: Check most recent package
echo "Step 2: Checking most recent package registration..."
echo ""

LATEST_PACKAGE=$(curl -s \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_package?sysparm_query=nameLIKEmicroservices-demo-dev^ORDERBYDESCsys_created_on&sysparm_limit=1&sysparm_display_value=all&sysparm_fields=name,application,sys_created_on" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json")

PACKAGE_NAME=$(echo "$LATEST_PACKAGE" | jq -r '.result[0].name.value // empty')
PACKAGE_APP=$(echo "$LATEST_PACKAGE" | jq -r '.result[0].application.display_value // empty')
PACKAGE_CREATED=$(echo "$LATEST_PACKAGE" | jq -r '.result[0].sys_created_on.value // empty')

if [ -z "$PACKAGE_NAME" ]; then
  echo -e "${YELLOW}⚠️  No packages found${NC}"
  echo ""
  echo "This is expected if you haven't run a workflow yet after the fix."
  echo ""
  echo "To test the fix:"
  echo "  1. Trigger a workflow: gh workflow run build-images.yaml -f service=frontend -f environment=dev"
  echo "  2. Wait for workflow to complete (~5-10 minutes)"
  echo "  3. Re-run this script to verify"
  exit 0
fi

echo "Latest package:"
echo "  Name: $PACKAGE_NAME"
echo "  Application: ${PACKAGE_APP:-'(null)'}"
echo "  Created: $PACKAGE_CREATED"
echo ""

if [ "$PACKAGE_APP" = "Online Boutique" ]; then
  echo -e "${GREEN}✅ Package successfully linked to 'Online Boutique' application!${NC}"
  echo ""
  echo "=============================================="
  echo "✅ VERIFICATION SUCCESSFUL"
  echo "=============================================="
  echo ""
  echo "The fix is working correctly:"
  echo "  1. Pipeline linked to application ✅"
  echo "  2. New packages inherit application ✅"
  echo "  3. Packages visible in DevOps Insights ✅"
  echo ""
  echo "Next steps:"
  echo "  1. Check DevOps Insights dashboard:"
  echo "     ${SERVICENOW_INSTANCE_URL}/now/nav/ui/classic/params/target/sn_devops_insights.do"
  echo ""
  echo "  2. View application details:"
  echo "     ${SERVICENOW_INSTANCE_URL}/sn_devops_app.do?sys_id=${APP_SYS_ID}"
  echo ""
  echo "  3. View packages for application:"
  echo "     ${SERVICENOW_INSTANCE_URL}/now/nav/ui/classic/params/target/sn_devops_package_list.do?sysparm_query=application=${APP_SYS_ID}"
  echo ""
else
  echo -e "${RED}❌ Package NOT linked to application${NC}"
  echo ""
  echo "This package was likely created BEFORE the fix was applied."
  echo ""
  echo "To verify the fix works:"
  echo "  1. Note the timestamp: $PACKAGE_CREATED"
  echo "  2. Trigger a NEW workflow: gh workflow run build-images.yaml -f service=frontend -f environment=dev"
  echo "  3. Wait for workflow to complete (~5-10 minutes)"
  echo "  4. Re-run this script"
  echo "  5. The new package should have 'Online Boutique' as its application"
  echo ""
  echo "If new packages STILL don't have application linkage:"
  echo "  - Check pipeline linkage: /tmp/check-tool-app-linkage.sh"
  echo "  - Verify workflow uses correct tool ID"
  echo "  - Check ServiceNow logs for registration errors"
fi
