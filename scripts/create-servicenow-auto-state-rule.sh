#!/bin/bash

# Create ServiceNow business rule to auto-set state for GitHub Actions deployments

source .envrc >/dev/null 2>&1

echo "=========================================="
echo "Create Auto-State Business Rule"
echo "=========================================="
echo ""

# Business rule script
SCRIPT='(function executeRule(current, previous) {
    // Auto-set state for GitHub Actions deployments
    var env = current.u_environment + "";
    var source = current.u_source + "";
    
    // Only process if this is from GitHub Actions and state is New (-5)
    if (source.indexOf("GitHub") >= 0 && current.state == -5) {
        gs.info("Auto-setting state for GitHub Actions deployment: " + current.number + " (env=" + env + ")");
        
        if (env.toLowerCase() == "dev") {
            // Dev: Auto-approve and set to Scheduled (-2)
            current.state = -2;  // Scheduled
            current.approval = "approved";
            current.work_notes = "Auto-approved and scheduled for dev environment";
            gs.info("Set state to Scheduled (-2) for dev environment");
        } else if (env.toLowerCase() == "qa" || env.toLowerCase() == "prod") {
            // QA/Prod: Set to Assess (-4) for approval
            current.state = -4;  // Assess
            current.work_notes = "Pending approval for " + env + " environment deployment";
            gs.info("Set state to Assess (-4) for " + env + " environment");
        }
        
        current.update();
    }
})(current, previous);'

# Create the business rule
PAYLOAD=$(jq -n \
  --arg name "GitHub Actions Auto-State" \
  --arg script "$SCRIPT" \
  '{
    name: $name,
    collection: "change_request",
    when: "after",
    active: "true",
    order: "100",
    script: $script,
    description: "Auto-set state for GitHub Actions deployments based on environment"
  }')

echo "Creating business rule: GitHub Actions Auto-State"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_script")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "201" ]; then
  RULE_ID=$(echo "$BODY" | jq -r '.result.sys_id')
  echo "✅ Business rule created successfully!"
  echo "   Sys ID: $RULE_ID"
  echo "   Name: GitHub Actions Auto-State"
  echo ""
  echo "The rule will:"
  echo "  1. Run AFTER change request creation"
  echo "  2. Check if source contains 'GitHub Actions'"
  echo "  3. If dev: Set state to -2 (Scheduled) and auto-approve"
  echo "  4. If qa/prod: Set state to -4 (Assess) for approval"
  echo ""
  echo "View rule in ServiceNow:"
  echo "  $SERVICENOW_INSTANCE_URL/sys_script.do?sys_id=$RULE_ID"
else
  echo "❌ Failed to create business rule (HTTP $HTTP_CODE)"
  echo "$BODY" | jq '.' || echo "$BODY"
  exit 1
fi

echo "=========================================="
