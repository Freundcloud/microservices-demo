#!/bin/bash

source /home/olafkfreund/Source/Calitti/ARC/microservices-demo/.envrc

echo "=========================================="
echo "Update Custom Fields for Artifact Links"
echo "=========================================="
echo ""

# Array of fields to update with better labels and descriptions
declare -A FIELD_LABELS=(
  ["u_sbom_url"]="SBOM Artifact"
  ["u_signatures_url"]="Image Signatures"
  ["u_sarif_results_url"]="Security Scan Results"
  ["u_infrastructure_report_url"]="Infrastructure Report"
  ["u_github_artifacts_url"]="All GitHub Artifacts"
)

declare -A FIELD_DESCRIPTIONS=(
  ["u_sbom_url"]="Software Bill of Materials (CycloneDX format) - Complete list of dependencies and components"
  ["u_signatures_url"]="Cosign cryptographic signatures and certificates for all Docker images"
  ["u_sarif_results_url"]="Security scan results from CodeQL, Trivy, Semgrep, Checkov, and other SAST tools"
  ["u_infrastructure_report_url"]="Infrastructure discovery report showing EKS clusters, namespaces, and deployments"
  ["u_github_artifacts_url"]="View all deployment artifacts (SBOM, signatures, reports) in one place"
)

# First, get the sys_id for each field
for field_name in "${!FIELD_LABELS[@]}"; do
  echo "Looking up field: $field_name"

  RESPONSE=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request^element=$field_name&sysparm_limit=1")

  SYS_ID=$(echo "$RESPONSE" | jq -r '.result[0].sys_id // empty')

  if [ -n "$SYS_ID" ]; then
    echo "Found field with sys_id: $SYS_ID"

    # Update the field with better label and description
    LABEL="${FIELD_LABELS[$field_name]}"
    DESC="${FIELD_DESCRIPTIONS[$field_name]}"

    echo "Updating to:"
    echo "  Label: $LABEL"
    echo "  Description: $DESC"

    UPDATE_PAYLOAD=$(jq -n \
      --arg label "$LABEL" \
      --arg desc "$DESC" \
      '{
        column_label: $label,
        comments: $desc,
        internal_type: "url",
        display: true
      }')

    UPDATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "$UPDATE_PAYLOAD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary/$SYS_ID")

    HTTP_CODE=$(echo "$UPDATE_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

    if [ "$HTTP_CODE" = "200" ]; then
      echo "✅ Updated: $field_name"
    else
      echo "❌ Failed to update $field_name (HTTP $HTTP_CODE)"
      echo "$UPDATE_RESPONSE" | sed '/HTTP_CODE:/d' | jq '.' 2>/dev/null
    fi
  else
    echo "❌ Field not found: $field_name"
  fi
  echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Updated field labels:"
echo ""
echo "1. SBOM Artifact - Software Bill of Materials link"
echo "2. Image Signatures - Cosign signatures and certificates"
echo "3. Security Scan Results - SAST/DAST scan results"
echo "4. Infrastructure Report - Infrastructure discovery data"
echo "5. All GitHub Artifacts - One-click access to all files"
echo ""
echo "View updated fields in ServiceNow:"
echo "  $SERVICENOW_INSTANCE_URL/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
echo ""
echo "These fields will now display as clickable hyperlinks in ServiceNow UI."
