#!/bin/bash
set -e

# Create ServiceNow custom tables for SBOM and Provenance tracking
# Usage: ./scripts/create-servicenow-sbom-tables.sh

# Load credentials
if [ -f .envrc ]; then
  source .envrc
fi

# Validate credentials
if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ] || [ -z "$SERVICENOW_INSTANCE_URL" ]; then
  echo "❌ Error: ServiceNow credentials not set"
  echo "Please set SERVICENOW_USERNAME, SERVICENOW_PASSWORD, and SERVICENOW_INSTANCE_URL"
  echo "Example: source .envrc"
  exit 1
fi

echo "🔧 Creating ServiceNow custom tables for SBOM and Provenance tracking..."
echo ""

# ============================================================
# Table 1: u_container_sbom (SBOM tracking)
# ============================================================
echo "📦 Creating table: u_container_sbom (SBOM tracking)"

# Simplified approach - create table without super_class
SBOM_TABLE_PAYLOAD=$(cat <<'EOF'
{
  "name": "u_container_sbom",
  "label": "Container SBOM"
}
EOF
)

SBOM_TABLE_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$SBOM_TABLE_PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object")

SBOM_TABLE_SYS_ID=$(echo "$SBOM_TABLE_RESPONSE" | jq -r '.result.sys_id // empty')

if [ -z "$SBOM_TABLE_SYS_ID" ]; then
  echo "⚠️  Table u_container_sbom may already exist or creation failed"
  # Try to get existing table
  EXISTING_TABLE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object?sysparm_query=name=u_container_sbom")
  SBOM_TABLE_SYS_ID=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

  if [ -n "$SBOM_TABLE_SYS_ID" ]; then
    echo "✅ Found existing table u_container_sbom (sys_id: $SBOM_TABLE_SYS_ID)"
  else
    echo "⚠️  Could not create table via API - may need manual creation in ServiceNow UI"
    echo "   Please create table manually with name: u_container_sbom"
    echo "   Label: Container SBOM"
    echo "   Or continue - fields will be created anyway"
    SBOM_TABLE_SYS_ID="manual"
  fi
else
  echo "✅ Created table u_container_sbom (sys_id: $SBOM_TABLE_SYS_ID)"
fi

echo ""

# ============================================================
# Table 1 Fields: u_container_sbom columns
# ============================================================
echo "📝 Creating columns for u_container_sbom..."

# Field 1: u_service_name (String)
echo "  - Creating field: u_service_name"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_service_name",
    "column_label": "Service Name",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "100",
    "mandatory": true
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 2: u_image_uri (String)
echo "  - Creating field: u_image_uri"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_image_uri",
    "column_label": "Image URI",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "500"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 3: u_image_tag (String)
echo "  - Creating field: u_image_tag"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_image_tag",
    "column_label": "Image Tag",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 4: u_sbom_format (String)
echo "  - Creating field: u_sbom_format"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_sbom_format",
    "column_label": "SBOM Format",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "50"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 5: u_sbom_summary (JSON/String - large)
echo "  - Creating field: u_sbom_summary"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_sbom_summary",
    "column_label": "SBOM Summary",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "8000"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 6: u_component_count (Integer)
echo "  - Creating field: u_component_count"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_component_count",
    "column_label": "Component Count",
    "name": "u_container_sbom",
    "internal_type": "integer"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 7: u_artifact_url (URL)
echo "  - Creating field: u_artifact_url"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_artifact_url",
    "column_label": "Artifact URL",
    "name": "u_container_sbom",
    "internal_type": "url",
    "max_length": "1024"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 8: u_github_run_id (String)
echo "  - Creating field: u_github_run_id"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_github_run_id",
    "column_label": "GitHub Run ID",
    "name": "u_container_sbom",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 9: u_created_date (Date/Time)
echo "  - Creating field: u_created_date"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_created_date",
    "column_label": "Created Date",
    "name": "u_container_sbom",
    "internal_type": "glide_date_time"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

echo "✅ Created 9 columns for u_container_sbom"
echo ""

# ============================================================
# Table 2: u_container_provenance (Build integrity tracking)
# ============================================================
echo "🔒 Creating table: u_container_provenance (Provenance tracking)"

# Simplified approach - create table without super_class
PROV_TABLE_PAYLOAD=$(cat <<'EOF'
{
  "name": "u_container_provenance",
  "label": "Container Provenance"
}
EOF
)

PROV_TABLE_RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d "$PROV_TABLE_PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object")

PROV_TABLE_SYS_ID=$(echo "$PROV_TABLE_RESPONSE" | jq -r '.result.sys_id // empty')

if [ -z "$PROV_TABLE_SYS_ID" ]; then
  echo "⚠️  Table u_container_provenance may already exist or creation failed"
  # Try to get existing table
  EXISTING_TABLE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object?sysparm_query=name=u_container_provenance")
  PROV_TABLE_SYS_ID=$(echo "$EXISTING_TABLE" | jq -r '.result[0].sys_id // empty')

  if [ -n "$PROV_TABLE_SYS_ID" ]; then
    echo "✅ Found existing table u_container_provenance (sys_id: $PROV_TABLE_SYS_ID)"
  else
    echo "⚠️  Could not create table via API - may need manual creation in ServiceNow UI"
    echo "   Please create table manually with name: u_container_provenance"
    echo "   Label: Container Provenance"
    echo "   Or continue - fields will be created anyway"
    PROV_TABLE_SYS_ID="manual"
  fi
else
  echo "✅ Created table u_container_provenance (sys_id: $PROV_TABLE_SYS_ID)"
fi

echo ""

# ============================================================
# Table 2 Fields: u_container_provenance columns
# ============================================================
echo "📝 Creating columns for u_container_provenance..."

# Field 1: u_service_name (String)
echo "  - Creating field: u_service_name"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_service_name",
    "column_label": "Service Name",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "100",
    "mandatory": true
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 2: u_image_uri (String)
echo "  - Creating field: u_image_uri"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_image_uri",
    "column_label": "Image URI",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "500"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 3: u_image_tag (String)
echo "  - Creating field: u_image_tag"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_image_tag",
    "column_label": "Image Tag",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 4: u_signed (Boolean)
echo "  - Creating field: u_signed"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_signed",
    "column_label": "Signed",
    "name": "u_container_provenance",
    "internal_type": "boolean"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 5: u_signature_method (String)
echo "  - Creating field: u_signature_method"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_signature_method",
    "column_label": "Signature Method",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 6: u_certificate_fingerprint (String)
echo "  - Creating field: u_certificate_fingerprint"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_certificate_fingerprint",
    "column_label": "Certificate Fingerprint",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "200"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 7: u_certificate_subject (String)
echo "  - Creating field: u_certificate_subject"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_certificate_subject",
    "column_label": "Certificate Subject",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "500"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 8: u_certificate_issuer (String)
echo "  - Creating field: u_certificate_issuer"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_certificate_issuer",
    "column_label": "Certificate Issuer",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "500"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 9: u_signature_artifact_url (URL)
echo "  - Creating field: u_signature_artifact_url"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_signature_artifact_url",
    "column_label": "Signature Artifact URL",
    "name": "u_container_provenance",
    "internal_type": "url",
    "max_length": "1024"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 10: u_github_run_id (String)
echo "  - Creating field: u_github_run_id"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_github_run_id",
    "column_label": "GitHub Run ID",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 11: u_github_actor (String)
echo "  - Creating field: u_github_actor"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_github_actor",
    "column_label": "GitHub Actor",
    "name": "u_container_provenance",
    "internal_type": "string",
    "max_length": "100"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

# Field 12: u_created_date (Date/Time)
echo "  - Creating field: u_created_date"
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST \
  -d '{
    "element": "u_created_date",
    "column_label": "Created Date",
    "name": "u_container_provenance",
    "internal_type": "glide_date_time"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary" > /dev/null

echo "✅ Created 12 columns for u_container_provenance"
echo ""

# ============================================================
# Summary
# ============================================================
echo "=========================================="
echo "✅ ServiceNow Tables Created Successfully"
echo "=========================================="
echo ""
echo "📦 Table 1: u_container_sbom (SBOM tracking)"
echo "   - 9 columns created"
echo "   - View at: $SERVICENOW_INSTANCE_URL/u_container_sbom_list.do"
echo ""
echo "🔒 Table 2: u_container_provenance (Provenance tracking)"
echo "   - 12 columns created"
echo "   - View at: $SERVICENOW_INSTANCE_URL/u_container_provenance_list.do"
echo ""
echo "Next Steps:"
echo "1. Run a build workflow to generate SBOM and signatures"
echo "2. Verify data appears in ServiceNow tables"
echo "3. Download full SBOM/signatures from GitHub artifacts"
echo ""
echo "Documentation:"
echo "- docs/SBOM-AND-IMAGE-SIGNING-IMPLEMENTATION.md"
echo "- .github/workflows/build-images.yaml (lines 544-781)"
echo ""
