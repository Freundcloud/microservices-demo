#!/usr/bin/env bash
#
# Register Security Tools in ServiceNow DevOps
# This script creates security tool records and links them to pipelines
#
# Usage:
#   export SERVICENOW_INSTANCE_URL="https://instance.service-now.com"
#   export SERVICENOW_USERNAME="admin"
#   export SERVICENOW_PASSWORD="password"
#   export PIPELINE_SYS_ID="sys_id_of_pipeline"  # Optional
#   ./scripts/register-security-tools-servicenow.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check required environment variables
if [ -z "${SERVICENOW_INSTANCE_URL:-}" ] || [ -z "${SERVICENOW_USERNAME:-}" ] || [ -z "${SERVICENOW_PASSWORD:-}" ]; then
  echo -e "${RED}❌ Missing required environment variables${NC}"
  echo "Required: SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD"
  echo "Optional: PIPELINE_SYS_ID"
  exit 1
fi

echo -e "${BLUE}🔐 Registering Security Tools in ServiceNow DevOps${NC}"
echo ""

# Array of security tools: "name:type:description:url"
declare -a TOOLS=(
  "CodeQL:Static Analysis:Semantic code analysis engine for discovering vulnerabilities across 5 languages (Python, JavaScript, Go, Java, C#):https://codeql.github.com"
  "Trivy:Container Scanner:Comprehensive vulnerability scanner for containers and filesystems. Detects OS packages, language-specific dependencies, IaC misconfigurations:https://trivy.dev"
  "OWASP Dependency Check:Dependency Scanner:Software Composition Analysis (SCA) tool that detects publicly disclosed vulnerabilities in project dependencies:https://owasp.org/www-project-dependency-check"
  "Semgrep:Static Analysis:Lightweight static analysis tool for finding bugs and enforcing code standards. Fast pattern matching:https://semgrep.dev"
  "Gitleaks:Secret Scanner:SAST tool for detecting hardcoded secrets like passwords, API keys, and tokens in git repositories:https://gitleaks.io"
  "Checkov:IaC Scanner:Static code analysis tool for Infrastructure as Code. Scans cloud infrastructure for security and compliance misconfigurations:https://checkov.io"
  "tfsec:Terraform Scanner:Security scanner for Terraform code. Detects potential security issues in Terraform configurations:https://tfsec.dev"
  "Grype:Vulnerability Scanner:Vulnerability scanner for container images and filesystems. Matches against CVE databases:https://github.com/anchore/grype"
  "Bandit:Python Security:Python-specific security linter. Finds common security issues in Python code:https://bandit.readthedocs.io"
  "ESLint Security:JavaScript Security:JavaScript security plugin for ESLint. Identifies potential security hotspots in Node.js applications:https://github.com/nodesecurity/eslint-plugin-security"
)

CREATED_COUNT=0
EXISTING_COUNT=0
LINKED_COUNT=0
ALREADY_LINKED_COUNT=0

for tool_info in "${TOOLS[@]}"; do
  IFS=':' read -r NAME TYPE DESC URL <<< "$tool_info"

  echo -e "${YELLOW}Processing: ${NAME}${NC}"

  # Check if tool exists
  QUERY_URL="${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool?sysparm_query=name=${NAME}&sysparm_limit=1"

  EXISTING_TOOL=$(curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "$QUERY_URL" \
    -H "Accept: application/json" \
    2>/dev/null | jq -r '.result[0].sys_id // empty')

  if [ -z "$EXISTING_TOOL" ]; then
    # Create new tool
    echo "  → Creating new tool record..."

    TOOL_PAYLOAD=$(jq -n \
      --arg name "$NAME" \
      --arg type "$TYPE" \
      --arg desc "$DESC" \
      --arg url "$URL" \
      '{
        name: $name,
        type: $type,
        description: $desc,
        url: $url
      }')

    TOOL_RESPONSE=$(curl -s -X POST \
      "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_tool" \
      -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$TOOL_PAYLOAD" \
      2>/dev/null)

    TOOL_SYS_ID=$(echo "$TOOL_RESPONSE" | jq -r '.result.sys_id // empty')

    if [ -n "$TOOL_SYS_ID" ]; then
      echo -e "  ${GREEN}✅ Created tool: ${NAME}${NC}"
      echo "     sys_id: ${TOOL_SYS_ID}"
      CREATED_COUNT=$((CREATED_COUNT + 1))
    else
      echo -e "  ${RED}❌ Failed to create tool: ${NAME}${NC}"
      echo "     Response: $(echo "$TOOL_RESPONSE" | jq -c '.')"
      continue
    fi
  else
    TOOL_SYS_ID="$EXISTING_TOOL"
    echo -e "  ${GREEN}✓ Tool already exists${NC}"
    echo "     sys_id: ${TOOL_SYS_ID}"
    EXISTING_COUNT=$((EXISTING_COUNT + 1))
  fi

  # Link tool to pipeline (if pipeline sys_id is provided)
  if [ -n "${PIPELINE_SYS_ID:-}" ] && [ -n "$TOOL_SYS_ID" ]; then
    echo "  → Checking pipeline linkage..."

    # Check if relationship exists
    LINK_QUERY_URL="${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_pipeline_tool?sysparm_query=pipeline=${PIPELINE_SYS_ID}^tool=${TOOL_SYS_ID}&sysparm_limit=1"

    EXISTING_LINK=$(curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
      "$LINK_QUERY_URL" \
      -H "Accept: application/json" \
      2>/dev/null | jq -r '.result[0].sys_id // empty')

    if [ -z "$EXISTING_LINK" ]; then
      # Create link
      LINK_PAYLOAD=$(jq -n \
        --arg pipeline "${PIPELINE_SYS_ID}" \
        --arg tool "$TOOL_SYS_ID" \
        '{
          pipeline: $pipeline,
          tool: $tool,
          status: "active"
        }')

      LINK_RESPONSE=$(curl -s -X POST \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_pipeline_tool" \
        -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$LINK_PAYLOAD" \
        2>/dev/null)

      LINK_SYS_ID=$(echo "$LINK_RESPONSE" | jq -r '.result.sys_id // empty')

      if [ -n "$LINK_SYS_ID" ]; then
        echo -e "  ${GREEN}✅ Linked to pipeline${NC}"
        LINKED_COUNT=$((LINKED_COUNT + 1))
      else
        echo -e "  ${YELLOW}⚠️  Failed to link to pipeline${NC}"
        echo "     Response: $(echo "$LINK_RESPONSE" | jq -c '.')"
      fi
    else
      echo -e "  ${GREEN}✓ Already linked to pipeline${NC}"
      ALREADY_LINKED_COUNT=$((ALREADY_LINKED_COUNT + 1))
    fi
  fi

  echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Security Tools Registration Complete${NC}"
echo ""
echo "Summary:"
echo "  • Tools created: ${CREATED_COUNT}"
echo "  • Tools already existed: ${EXISTING_COUNT}"
echo "  • Total tools: $((CREATED_COUNT + EXISTING_COUNT))"

if [ -n "${PIPELINE_SYS_ID:-}" ]; then
  echo ""
  echo "Pipeline Linkage:"
  echo "  • New links created: ${LINKED_COUNT}"
  echo "  • Already linked: ${ALREADY_LINKED_COUNT}"
  echo "  • Total linked tools: $((LINKED_COUNT + ALREADY_LINKED_COUNT))"
  echo ""
  echo "View pipeline security tools at:"
  echo "  ${SERVICENOW_INSTANCE_URL}/now/devops-change/record/sn_devops_pipeline/${PIPELINE_SYS_ID}/params/selected-tab-index/3"
else
  echo ""
  echo -e "${YELLOW}ℹ️  No PIPELINE_SYS_ID provided - tools created but not linked to pipeline${NC}"
  echo "   To link tools to a pipeline, set PIPELINE_SYS_ID environment variable"
fi

echo ""
echo "View all security tools at:"
echo "  ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=sn_devops_tool_list.do"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
