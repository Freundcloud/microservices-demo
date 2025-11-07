#!/bin/bash
# ServiceNow Project Completeness Check and Auto-Fix
# This script ensures the ServiceNow project has all required components:
# - Correct project_url
# - Repository record
# - Plan record
# - (Future: Orchestration tasks, packages, work items)
#
# Usage: ./scripts/ensure-servicenow-project-complete.sh
# Environment variables required:
#   SERVICENOW_USERNAME
#   SERVICENOW_PASSWORD
#   SERVICENOW_INSTANCE_URL

set -e

echo "=========================================="
echo "ServiceNow Project Completeness Check"
echo "=========================================="
echo ""

# Configuration
PROJECT_ID="${SERVICENOW_PROJECT_ID:-c6c9eb71c34d7a50b71ef44c05013194}"
TOOL_ID="${SERVICENOW_TOOL_ID:-f62c4e49c3fcf614e1bbf0cb050131ef}"
REPO_NAME="${GITHUB_REPOSITORY:-Freundcloud/microservices-demo}"
REPO_URL="https://github.com/${REPO_NAME}"

# Validation
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
  echo "❌ Missing required environment variables"
  echo "   Required: SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL"
  exit 1
fi

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Tool ID: $TOOL_ID"
echo "  Repository: $REPO_NAME"
echo "  URL: $REPO_URL"
echo ""

# Function to check and create/update repository
ensure_repository() {
  echo "1. Checking DevOps Repository..."

  REPO_CHECK=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=project=$PROJECT_ID&sysparm_limit=1")

  REPO_EXISTS=$(echo "$REPO_CHECK" | jq '.result | length')

  if [ "$REPO_EXISTS" -gt 0 ]; then
    REPO_ID=$(echo "$REPO_CHECK" | jq -r '.result[0].sys_id')
    REPO_NUMBER=$(echo "$REPO_CHECK" | jq -r '.result[0].number // "N/A"')
    echo "   ✅ Repository exists: $REPO_NUMBER (sys_id: $REPO_ID)"

    # Update to ensure URL and other fields are current
    curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "{
        \"name\": \"$REPO_NAME\",
        \"url\": \"$REPO_URL\",
        \"default_branch\": \"main\"
      }" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository/$REPO_ID" > /dev/null

    echo "   ✅ Repository updated with current URL"
  else
    echo "   ⚠️  Repository doesn't exist, creating..."

    REPO_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "{
        \"name\": \"$REPO_NAME\",
        \"url\": \"$REPO_URL\",
        \"project\": \"$PROJECT_ID\",
        \"tool\": \"$TOOL_ID\",
        \"description\": \"Microservices demo application on AWS EKS\",
        \"default_branch\": \"main\"
      }" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository")

    if echo "$REPO_RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
      REPO_SYS_ID=$(echo "$REPO_RESPONSE" | jq -r '.result.sys_id')
      REPO_NUMBER=$(echo "$REPO_RESPONSE" | jq -r '.result.number // "N/A"')
      echo "   ✅ Repository created: $REPO_NUMBER (sys_id: $REPO_SYS_ID)"
    else
      echo "   ❌ Failed to create repository:"
      echo "$REPO_RESPONSE" | jq -r '.error.message // "Unknown error"'
      return 1
    fi
  fi
}

# Function to check and create/update plan
ensure_plan() {
  echo "2. Checking DevOps Plan..."

  PLAN_CHECK=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_plan?sysparm_query=project=$PROJECT_ID&sysparm_limit=1")

  PLAN_EXISTS=$(echo "$PLAN_CHECK" | jq '.result | length')

  if [ "$PLAN_EXISTS" -gt 0 ]; then
    PLAN_ID=$(echo "$PLAN_CHECK" | jq -r '.result[0].sys_id')
    PLAN_NUMBER=$(echo "$PLAN_CHECK" | jq -r '.result[0].number // "N/A"')
    echo "   ✅ Plan exists: $PLAN_NUMBER (sys_id: $PLAN_ID)"

    # Update to ensure it's active
    curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "{\"state\": \"active\"}" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_plan/$PLAN_ID" > /dev/null
  else
    echo "   ⚠️  Plan doesn't exist, creating..."

    PLAN_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "{
        \"name\": \"$REPO_NAME - Deployment Plan\",
        \"project\": \"$PROJECT_ID\",
        \"tool\": \"$TOOL_ID\",
        \"description\": \"Automated deployment plan for microservices-demo (dev/qa/prod environments)\",
        \"state\": \"active\"
      }" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_plan")

    if echo "$PLAN_RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
      PLAN_SYS_ID=$(echo "$PLAN_RESPONSE" | jq -r '.result.sys_id')
      PLAN_NUMBER=$(echo "$PLAN_RESPONSE" | jq -r '.result.number // "N/A"')
      echo "   ✅ Plan created: $PLAN_NUMBER (sys_id: $PLAN_SYS_ID)"
    else
      echo "   ❌ Failed to create plan:"
      echo "$PLAN_RESPONSE" | jq -r '.error.message // "Unknown error"'
      return 1
    fi
  fi
}

# Function to ensure project_url is correct
ensure_project_url() {
  echo "3. Checking Project URL..."

  CURRENT_URL=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project/$PROJECT_ID?sysparm_fields=project_url" \
    | jq -r '.result.project_url // "null"')

  if [ "$CURRENT_URL" = "$REPO_URL" ]; then
    echo "   ✅ Project URL is correct: $CURRENT_URL"
  else
    echo "   ⚠️  Project URL needs update"
    echo "      Current: $CURRENT_URL"
    echo "      Expected: $REPO_URL"

    curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "{\"project_url\": \"$REPO_URL\"}" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project/$PROJECT_ID" > /dev/null

    echo "   ✅ Project URL updated"
  fi
}

# Main execution
ensure_repository
echo ""
ensure_plan
echo ""
ensure_project_url
echo ""

# Verify final state
echo "4. Verifying project counts..."
sleep 2  # Give ServiceNow time to update counts

curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project/$PROJECT_ID?sysparm_fields=name,plan_count,repository_count,pipeline_count" \
  | jq -r '.result | "   Project: \(.name)
   Plans: \(.plan_count)
   Repositories: \(.repository_count)
   Pipelines: \(.pipeline_count)"'

echo ""
echo "=========================================="
echo "✅ ServiceNow Project Completeness Check Complete"
echo "=========================================="
echo ""
echo "View project in ServiceNow:"
echo "https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_project.do?sys_id=$PROJECT_ID"
