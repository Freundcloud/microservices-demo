#!/bin/bash

# ServiceNow Vulnerability Upload Script
# Purpose: Parse Trivy scan results and upload to ServiceNow Vulnerability Response
# Usage: ./upload-vulnerabilities-to-servicenow.sh <trivy-json-file> <image-name> <environment>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
TRIVY_FILE="$1"
IMAGE_NAME="$2"
ENVIRONMENT="$3"

# Validate arguments
if [ -z "$TRIVY_FILE" ] || [ -z "$IMAGE_NAME" ] || [ -z "$ENVIRONMENT" ]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo "Usage: $0 <trivy-json-file> <image-name> <environment>"
  echo ""
  echo "Example:"
  echo "  $0 trivy-results.json 533267307120.dkr.ecr.../frontend:dev-abc123 dev"
  exit 1
fi

# Validate file exists
if [ ! -f "$TRIVY_FILE" ]; then
  echo -e "${RED}Error: Trivy results file not found: $TRIVY_FILE${NC}"
  exit 1
fi

# Validate credentials
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
  echo -e "${RED}Error: ServiceNow credentials not set${NC}"
  echo "Required environment variables:"
  echo "  - SERVICENOW_USERNAME"
  echo "  - SERVICENOW_PASSWORD"
  echo "  - SERVICENOW_INSTANCE_URL"
  exit 1
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}ServiceNow Vulnerability Upload${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Image: $IMAGE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Trivy file: $TRIVY_FILE"
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is not installed${NC}"
  echo "Install jq: brew install jq (macOS) or apt install jq (Ubuntu)"
  exit 1
fi

# Parse Trivy results
echo -e "${BLUE}Parsing Trivy scan results...${NC}"

# Count total vulnerabilities
TOTAL_VULNS=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$TRIVY_FILE")
echo "  Total vulnerabilities found: $TOTAL_VULNS"

if [ "$TOTAL_VULNS" -eq 0 ]; then
  echo -e "${GREEN}✓ No vulnerabilities found - nothing to upload${NC}"
  exit 0
fi

# Count by severity
CRITICAL_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$TRIVY_FILE")
HIGH_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$TRIVY_FILE")
MEDIUM_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$TRIVY_FILE")
LOW_COUNT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "$TRIVY_FILE")

echo "  Severity breakdown:"
echo "    Critical: $CRITICAL_COUNT"
echo "    High: $HIGH_COUNT"
echo "    Medium: $MEDIUM_COUNT"
echo "    Low: $LOW_COUNT"
echo ""

# Step 1: Create or find Configuration Item (CI) for the Docker image
echo -e "${BLUE}Step 1: Checking Configuration Item...${NC}"

# Search for existing CI
CI_SEARCH=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/cmdb_ci?sysparm_query=name=$IMAGE_NAME&sysparm_limit=1")

CI_COUNT=$(echo "$CI_SEARCH" | jq -r '.result | length')

if [ "$CI_COUNT" -gt 0 ]; then
  CI_SYS_ID=$(echo "$CI_SEARCH" | jq -r '.result[0].sys_id')
  echo -e "  ${GREEN}✓ Configuration Item exists${NC}"
  echo "    sys_id: $CI_SYS_ID"
else
  echo "  Creating new Configuration Item..."

  # Extract short name from image
  SHORT_NAME=$(echo "$IMAGE_NAME" | sed 's|.*/||' | cut -d: -f1)

  # Create CI payload
  CI_PAYLOAD=$(jq -n \
    --arg name "$IMAGE_NAME" \
    --arg short_name "$SHORT_NAME" \
    --arg env "$ENVIRONMENT" \
    '{
      "name": $name,
      "short_description": ($short_name + " - Docker Image (" + $env + ")"),
      "asset_tag": $name,
      "category": "Software"
    }')

  # Create CI
  CI_CREATE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$CI_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/cmdb_ci")

  CI_SYS_ID=$(echo "$CI_CREATE" | jq -r '.result.sys_id')

  if [ -n "$CI_SYS_ID" ] && [ "$CI_SYS_ID" != "null" ]; then
    echo -e "  ${GREEN}✓ Configuration Item created${NC}"
    echo "    sys_id: $CI_SYS_ID"
  else
    echo -e "  ${RED}✗ Failed to create Configuration Item${NC}"
    echo "$CI_CREATE" | jq '.'
    exit 1
  fi
fi
echo ""

# Step 2: Process vulnerabilities and upload
echo -e "${BLUE}Step 2: Uploading vulnerabilities...${NC}"

UPLOAD_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

# Extract all vulnerabilities into array
VULNERABILITIES=$(jq -c '[.Results[]?.Vulnerabilities[]?]' "$TRIVY_FILE")
VUL_ARRAY_LENGTH=$(echo "$VULNERABILITIES" | jq 'length')

# Process each vulnerability
for i in $(seq 0 $((VUL_ARRAY_LENGTH - 1))); do
  # Extract vulnerability details
  VUL=$(echo "$VULNERABILITIES" | jq -c ".[$i]")

  CVE_ID=$(echo "$VUL" | jq -r '.VulnerabilityID')
  PKG_NAME=$(echo "$VUL" | jq -r '.PkgName')
  INSTALLED_VERSION=$(echo "$VUL" | jq -r '.InstalledVersion')
  FIXED_VERSION=$(echo "$VUL" | jq -r '.FixedVersion // "N/A"')
  SEVERITY=$(echo "$VUL" | jq -r '.Severity')
  TITLE=$(echo "$VUL" | jq -r '.Title // "No title"')
  DESCRIPTION=$(echo "$VUL" | jq -r '.Description // "No description"')

  # Skip if CVE_ID is empty
  if [ -z "$CVE_ID" ] || [ "$CVE_ID" = "null" ]; then
    ((SKIP_COUNT++))
    continue
  fi

  # Map Trivy severity to ServiceNow severity (1-5 scale)
  case $SEVERITY in
    "CRITICAL") SN_SEVERITY="1" ;;
    "HIGH") SN_SEVERITY="2" ;;
    "MEDIUM") SN_SEVERITY="3" ;;
    "LOW") SN_SEVERITY="4" ;;
    *) SN_SEVERITY="5" ;;
  esac

  # Check if vulnerability entry exists
  VUL_ENTRY_SEARCH=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_vul_entry?sysparm_query=vulnerability_id=$CVE_ID&sysparm_limit=1")

  VUL_ENTRY_COUNT=$(echo "$VUL_ENTRY_SEARCH" | jq -r '.result | length')

  if [ "$VUL_ENTRY_COUNT" -gt 0 ]; then
    VUL_ENTRY_SYS_ID=$(echo "$VUL_ENTRY_SEARCH" | jq -r '.result[0].sys_id')
  else
    # Create vulnerability entry
    VUL_ENTRY_PAYLOAD=$(jq -n \
      --arg cve "$CVE_ID" \
      --arg title "$TITLE" \
      --arg desc "$DESCRIPTION" \
      --arg severity "$SN_SEVERITY" \
      '{
        "vulnerability_id": $cve,
        "short_description": $title,
        "description": $desc,
        "severity": $severity,
        "source": "Trivy"
      }')

    VUL_ENTRY_CREATE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -X POST \
      -d "$VUL_ENTRY_PAYLOAD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_vul_entry")

    VUL_ENTRY_SYS_ID=$(echo "$VUL_ENTRY_CREATE" | jq -r '.result.sys_id')
  fi

  # Check if vulnerability item already exists for this CI and vulnerability
  VUL_ITEM_SEARCH=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_vul_vulnerable_item?sysparm_query=cmdb_ci=$CI_SYS_ID^vulnerability=$VUL_ENTRY_SYS_ID&sysparm_limit=1")

  VUL_ITEM_COUNT=$(echo "$VUL_ITEM_SEARCH" | jq -r '.result | length')

  if [ "$VUL_ITEM_COUNT" -gt 0 ]; then
    # Already exists, skip
    ((SKIP_COUNT++))
    continue
  fi

  # Create vulnerable item
  VUL_ITEM_PAYLOAD=$(jq -n \
    --arg ci "$CI_SYS_ID" \
    --arg vul "$VUL_ENTRY_SYS_ID" \
    --arg severity "$SN_SEVERITY" \
    --arg pkg "$PKG_NAME" \
    --arg installed "$INSTALLED_VERSION" \
    --arg fixed "$FIXED_VERSION" \
    '{
      "cmdb_ci": $ci,
      "vulnerability": $vul,
      "severity": $severity,
      "source": "Trivy",
      "state": "open",
      "short_description": ("Vulnerability in " + $pkg + " " + $installed),
      "description": ("Package: " + $pkg + "\nInstalled: " + $installed + "\nFixed: " + $fixed)
    }')

  VUL_ITEM_CREATE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$VUL_ITEM_PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_vul_vulnerable_item")

  VUL_ITEM_SYS_ID=$(echo "$VUL_ITEM_CREATE" | jq -r '.result.sys_id')

  if [ -n "$VUL_ITEM_SYS_ID" ] && [ "$VUL_ITEM_SYS_ID" != "null" ]; then
    ((UPLOAD_COUNT++))
    echo -e "  ${GREEN}✓${NC} $CVE_ID ($SEVERITY) - $PKG_NAME"
  else
    ((ERROR_COUNT++))
    echo -e "  ${RED}✗${NC} $CVE_ID - Upload failed"
  fi
done

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}Upload completed${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Summary:"
echo "  Total vulnerabilities: $TOTAL_VULNS"
echo "  Uploaded: $UPLOAD_COUNT"
echo "  Skipped (duplicates): $SKIP_COUNT"
echo "  Errors: $ERROR_COUNT"
echo ""

if [ "$UPLOAD_COUNT" -gt 0 ]; then
  echo "View in ServiceNow:"
  echo "  $SERVICENOW_INSTANCE_URL/sn_vul_vulnerable_item_list.do?sysparm_query=cmdb_ci=$CI_SYS_ID"
fi
echo ""

# Exit with error if any uploads failed
if [ "$ERROR_COUNT" -gt 0 ]; then
  exit 1
fi
