#!/bin/bash

source /home/olafkfreund/Source/Calitti/ARC/microservices-demo/.envrc

echo "=========================================="
echo "Create Custom Fields for Artifact Links"
echo "=========================================="
echo ""

# Array of fields to create
declare -A FIELDS=(
  ["u_sbom_url"]="URL to SBOM (Software Bill of Materials) artifact"
  ["u_signatures_url"]="URL to Cosign signatures artifacts"
  ["u_sarif_results_url"]="URL to SARIF security scan results"
  ["u_infrastructure_report_url"]="URL to infrastructure discovery report"
  ["u_github_artifacts_url"]="URL to all GitHub Actions artifacts"
)

for field_name in "${!FIELDS[@]}"; do
  description="${FIELDS[$field_name]}"
  
  echo "Creating field: $field_name"
  echo "Description: $description"
  
  PAYLOAD=$(jq -n \
    --arg name "$field_name" \
    --arg label "${field_name/u_/}" \
    --arg desc "$description" \
    '{
      name: "change_request",
      element: $name,
      column_label: $label,
      internal_type: {
        link: "https://calitiiltddemo3.service-now.com/api/now/table/sys_glide_object/url",
        value: "url"
      },
      max_length: "1024",
      comments: $desc
    }')
  
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary")
  
  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')
  
  if [ "$HTTP_CODE" = "201" ]; then
    SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')
    echo "✅ Created: $field_name (sys_id: $SYS_ID)"
  elif echo "$BODY" | grep -q "unique"; then
    echo "⚠️  Field already exists: $field_name"
  else
    echo "❌ Failed to create $field_name (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  fi
  echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Created/verified 5 custom URL fields on change_request table:"
echo ""
echo "1. u_sbom_url - SBOM artifact link"
echo "2. u_signatures_url - Cosign signatures link"
echo "3. u_sarif_results_url - SARIF results link"
echo "4. u_infrastructure_report_url - Infrastructure report link"
echo "5. u_github_artifacts_url - All artifacts link"
echo ""
echo "View fields in ServiceNow:"
echo "  $SERVICENOW_INSTANCE_URL/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_"
echo ""
echo "These fields will be populated by the workflow with GitHub URLs."
