# ServiceNow Configuration Files

This directory contains ServiceNow configuration files for importing tables and settings.

## Files

### sbom-provenance-tables-update-set.xml

**Purpose**: ServiceNow Update Set containing custom table definitions for Container SBOM and Provenance tracking.

**Contains**:
- **u_container_sbom** table (9 fields) - Tracks Software Bill of Materials for container images
- **u_container_provenance** table (12 fields) - Tracks build integrity and signatures

**How to Import**:

1. **Navigate to Update Sets**:
   - Go to your ServiceNow instance
   - Navigate to: **System Update Sets > Retrieved Update Sets**

2. **Import XML File**:
   - Click **Import Update Set from XML**
   - Choose file: `sbom-provenance-tables-update-set.xml`
   - Click **Upload**

3. **Preview Update Set**:
   - Find the imported update set: "Container SBOM and Provenance Tables"
   - Click on the update set name
   - Click **Preview Update Set**
   - Review the changes (2 tables, 21 fields)
   - Resolve any conflicts if prompted

4. **Commit Update Set**:
   - After successful preview, click **Commit Update Set**
   - Wait for completion (usually 30-60 seconds)

5. **Verify Tables Created**:
   - Navigate to: **System Definition > Tables**
   - Search for: `u_container_sbom` and `u_container_provenance`
   - Or visit directly:
     - https://YOUR-INSTANCE.service-now.com/u_container_sbom_list.do
     - https://YOUR-INSTANCE.service-now.com/u_container_provenance_list.do

## Table Schemas

### u_container_sbom (SBOM Tracking)

| Field Name | Type | Length | Description |
|------------|------|--------|-------------|
| u_service_name | String | 100 | Service identifier (required) |
| u_image_uri | String | 500 | Full container image URI |
| u_image_tag | String | 100 | Image tag (dev/qa/prod/v1.2.3) |
| u_sbom_format | String | 50 | SBOM format (cyclonedx/spdx) |
| u_sbom_summary | String | 8000 | Compact JSON summary of SBOM |
| u_component_count | Integer | - | Total number of components |
| u_artifact_url | URL | 1024 | Link to download full SBOM from GitHub |
| u_github_run_id | String | 100 | GitHub Actions workflow run ID |
| u_created_date | DateTime | - | Record creation timestamp |

**Purpose**: Stores Software Bill of Materials data for each container image build. Full SBOMs are stored in GitHub artifacts with 90-day retention.

**Populated By**: `.github/workflows/build-images.yaml` (lines 629-703)

### u_container_provenance (Build Integrity Tracking)

| Field Name | Type | Length | Description |
|------------|------|--------|-------------|
| u_service_name | String | 100 | Service identifier (required) |
| u_image_uri | String | 500 | Full container image URI |
| u_image_tag | String | 100 | Image tag (dev/qa/prod/v1.2.3) |
| u_signed | Boolean | - | Whether image is cryptographically signed |
| u_signature_method | String | 100 | Signing method (cosign-keyless) |
| u_certificate_fingerprint | String | 200 | SHA256 fingerprint of signing certificate |
| u_certificate_subject | String | 500 | X.509 certificate subject DN |
| u_certificate_issuer | String | 500 | X.509 certificate issuer DN |
| u_signature_artifact_url | URL | 1024 | Link to download signatures from GitHub |
| u_github_run_id | String | 100 | GitHub Actions workflow run ID |
| u_github_actor | String | 100 | GitHub user who triggered the build |
| u_created_date | DateTime | - | Record creation timestamp |

**Purpose**: Stores cryptographic provenance and signatures for container images. Provides proof of build origin and integrity.

**Populated By**: `.github/workflows/build-images.yaml` (lines 705-781)

## Alternative: API-Based Table Creation

If you prefer to create tables via REST API instead of importing XML, use the script:

```bash
./scripts/create-servicenow-sbom-tables.sh
```

**Prerequisites**:
- ServiceNow credentials in `.envrc`
- `jq` installed
- `curl` installed

**What it does**:
1. Creates both tables via sys_db_object API
2. Creates all 21 fields via sys_dictionary API
3. Verifies table creation
4. Displays table URLs

## Integration

These tables are automatically populated by GitHub Actions workflows when container images are built:

**Workflow**: `.github/workflows/build-images.yaml`

**Steps**:
1. Build container image
2. Generate SBOM with Syft (CycloneDX + SPDX formats)
3. Sign image with Cosign (keyless)
4. Upload SBOM summary to `u_container_sbom`
5. Upload provenance to `u_container_provenance`
6. Store full SBOM and signatures in GitHub artifacts

**Artifacts Location**: GitHub Actions > Workflow Run > Artifacts
- `sbom-{service}-cyclonedx` - CycloneDX SBOM
- `sbom-{service}-spdx` - SPDX SBOM
- `signatures-{service}` - Signature and certificate files

## Compliance Benefits

**NIST SSDF**:
- Practice PW.1.3: Create and maintain SBOM
- Practice PS.3.1: Archive provenance data

**Executive Order 14028**:
- Section 4(e): SBOM requirement
- Section 4(f): Provenance attestation

**EU Cyber Resilience Act**:
- Article 15: Transparency obligations (SBOM)

## Viewing Data

**List View**:
- SBOM: https://YOUR-INSTANCE.service-now.com/u_container_sbom_list.do
- Provenance: https://YOUR-INSTANCE.service-now.com/u_container_provenance_list.do

**Filter Examples**:
- Show all signed images: `u_signed = true`
- Show dev builds: `u_image_tag CONTAINS dev`
- Show specific service: `u_service_name = frontend`
- Show recent builds: `u_created_date > javascript:gs.daysAgo(7)`

**REST API Access**:
```bash
# Get all SBOMs
curl -u "$USERNAME:$PASSWORD" \
  "$INSTANCE_URL/api/now/table/u_container_sbom"

# Get provenance for specific service
curl -u "$USERNAME:$PASSWORD" \
  "$INSTANCE_URL/api/now/table/u_container_provenance?sysparm_query=u_service_name=frontend"
```

## Troubleshooting

**Import Failed**:
- Check ServiceNow version (requires Rome or later for Update Sets)
- Verify you have `admin` role or `update_set_manager` role
- Check for existing tables with same names

**Tables Not Appearing**:
- Clear ServiceNow cache: System Administration > System Diagnostics > Cache Management
- Restart ServiceNow session (logout/login)
- Check Application Navigator filter settings

**Data Not Populating**:
- Verify GitHub secrets are set: `SERVICENOW_USERNAME`, `SERVICENOW_PASSWORD`, `SERVICENOW_INSTANCE_URL`
- Check workflow logs for API errors
- Verify tables exist: Navigate to System Definition > Tables
- Check ServiceNow credentials have write access to custom tables

## Documentation

- **SBOM Implementation Guide**: `docs/SBOM-AND-IMAGE-SIGNING-IMPLEMENTATION.md`
- **ServiceNow DevOps Analysis**: `docs/SERVICENOW-DEVOPS-CHANGE-VELOCITY-ANALYSIS.md`
- **Workflow Implementation**: `.github/workflows/build-images.yaml` (lines 544-781)

## Support

For issues with:
- **Table creation**: Check ServiceNow system logs (System Logs > System Log > All)
- **Data upload**: Check GitHub Actions workflow logs
- **API access**: Verify credentials and table permissions

---

*Last Updated: 2025-01-29*
*Version: 1.0*
