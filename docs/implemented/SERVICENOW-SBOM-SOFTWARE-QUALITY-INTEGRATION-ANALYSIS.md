# ServiceNow SBOM Software Quality Integration Analysis

**Date**: 2025-11-06
**Status**: 📋 **ANALYSIS COMPLETE** - Ready for Implementation
**Related Issue**: TBD (to be created)

---

## Executive Summary

Implement SBOM (Software Bill of Materials) upload to ServiceNow software quality tables to provide complete visibility of application dependencies and enable vulnerability tracking in ServiceNow DevOps workspace.

**Current State**: SBOM generation exists but results not uploaded to ServiceNow
**Desired State**: SBOM data visible in ServiceNow software quality scan summary tables
**Benefit**: Complete dependency inventory in ServiceNow for compliance and vulnerability management

---

## ServiceNow Software Quality Tables

ServiceNow provides the following tables for software quality scan data:

| Table Name | Purpose | Status |
|------------|---------|--------|
| `sn_devops_software_quality_scan_summary` | High-level summary of quality scans | Empty |
| `sn_devops_software_quality_scan_detail` | Detailed scan findings (individual issues) | Empty |
| `sn_devops_software_quality_category_detail` | Category-level aggregation | Empty |
| `sn_devops_software_quality_sub_category` | Sub-category definitions | Empty |
| `sn_devops_software_quality_scan_summary_...` | Relations between summaries | Empty |

**All tables currently empty** - no data has been uploaded yet.

---

## Current SBOM Implementation

### Existing SBOM Generation

**File**: `.github/workflows/security-scan.yaml` (Lines 110-117)

```yaml
- name: Generate SBOM (Software Bill of Materials)
  uses: anchore/sbom-action@v0.17.2
  with:
    path: ./
    format: cyclonedx-json
    output-file: sbom.cyclonedx.json
    upload-artifact: true
    upload-artifact-retention: 90
```

**What's Already Working**:
- ✅ SBOM generated for entire codebase using Syft (Anchore)
- ✅ CycloneDX JSON format (industry standard)
- ✅ Uploaded as GitHub Actions artifact (90-day retention)
- ✅ Includes all dependencies (npm, pip, maven, go modules, nuget)

**What's Missing**:
- ❌ SBOM data not uploaded to ServiceNow
- ❌ Dependencies not visible in ServiceNow DevOps workspace
- ❌ No dependency-based vulnerability tracking in ServiceNow

---

## SBOM Data Structure

### CycloneDX Format Overview

The generated `sbom.cyclonedx.json` contains:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "2025-11-06T19:00:00Z",
    "tools": [{"vendor": "anchore", "name": "syft", "version": "1.16.0"}],
    "component": {
      "type": "application",
      "name": "microservices-demo",
      "version": "sha:49e77676"
    }
  },
  "components": [
    {
      "type": "library",
      "name": "express",
      "version": "4.18.2",
      "purl": "pkg:npm/express@4.18.2",
      "licenses": [{"license": {"id": "MIT"}}],
      "hashes": [{"alg": "SHA-256", "content": "..."}]
    },
    // ... hundreds of components
  ],
  "dependencies": [
    {"ref": "pkg:npm/express@4.18.2", "dependsOn": ["pkg:npm/body-parser@1.20.1", ...]}
  ]
}
```

**Key Fields**:
- `components`: Array of all dependencies (libraries, packages)
- `metadata.component`: The application being analyzed
- `dependencies`: Dependency graph relationships
- `purl`: Package URL (universal package identifier)

---

## Solution Design

### Option A: Upload SBOM Summary to Software Quality Scan Tables (RECOMMENDED)

**Approach**: Parse SBOM and upload aggregated summary + detailed findings to ServiceNow.

**Implementation**:

1. **Parse SBOM** after generation
2. **Create scan summary** in `sn_devops_software_quality_scan_summary`
3. **Upload component details** to `sn_devops_software_quality_scan_detail`
4. **Link to tool** (GithHubARC: f62c4e49c3fcf614e1bbf0cb050131ef)
5. **Link to pipeline execution** (for application association)

**Workflow Steps**:

```yaml
# After SBOM generation step in security-scan.yaml

- name: Parse SBOM and Extract Metrics
  id: parse-sbom
  run: |
    COMPONENT_COUNT=$(jq '.components | length' sbom.cyclonedx.json)
    LICENSE_COUNT=$(jq '[.components[].licenses[].license.id] | unique | length' sbom.cyclonedx.json)
    TOTAL_DEPENDENCIES=$(jq '.dependencies | length' sbom.cyclonedx.json)

    echo "component_count=$COMPONENT_COUNT" >> $GITHUB_OUTPUT
    echo "license_count=$LICENSE_COUNT" >> $GITHUB_OUTPUT
    echo "total_dependencies=$TOTAL_DEPENDENCIES" >> $GITHUB_OUTPUT

- name: Upload SBOM Summary to ServiceNow
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  run: |
    SCAN_SUMMARY=$(cat <<EOF
    {
      "name": "SBOM Scan - microservices-demo",
      "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
      "scan_type": "SBOM",
      "scan_date": "$(date -u +%Y-%m-%d %H:%M:%S)",
      "total_components": ${{ steps.parse-sbom.outputs.component_count }},
      "total_licenses": ${{ steps.parse-sbom.outputs.license_count }},
      "total_dependencies": ${{ steps.parse-sbom.outputs.total_dependencies }},
      "scan_status": "completed",
      "artifact_url": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
    }
    EOF
    )

    curl -X POST \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$SCAN_SUMMARY" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_summary"

- name: Upload SBOM Components to ServiceNow (Detail Records)
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  run: |
    # Extract top 100 components (most critical dependencies)
    jq -r '.components[0:100] | .[] |
      @json' sbom.cyclonedx.json | while read -r component; do

      NAME=$(echo "$component" | jq -r '.name')
      VERSION=$(echo "$component" | jq -r '.version')
      TYPE=$(echo "$component" | jq -r '.type')
      PURL=$(echo "$component" | jq -r '.purl // ""')
      LICENSE=$(echo "$component" | jq -r '.licenses[0].license.id // "Unknown"')

      DETAIL=$(cat <<EOF
      {
        "scan_summary": "$SCAN_SUMMARY_SYS_ID",
        "component_name": "$NAME",
        "component_version": "$VERSION",
        "component_type": "$TYPE",
        "package_url": "$PURL",
        "license": "$LICENSE"
      }
      EOF
      )

      curl -s -X POST \
        -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -d "$DETAIL" \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_detail"
    done
```

**Pros**:
- ✅ Complete SBOM visibility in ServiceNow
- ✅ Can query dependencies via ServiceNow
- ✅ Linked to application via tool + pipeline execution
- ✅ Enables dependency-based risk analysis
- ✅ Compliance audit trail in ServiceNow

**Cons**:
- ⚠️ Requires parsing SBOM JSON
- ⚠️ May create many detail records (100+ components per scan)
- ⚠️ Need to handle large component lists (pagination or filtering)

### Option B: Upload SBOM File as Attachment

**Approach**: Upload entire SBOM JSON file as ServiceNow attachment linked to scan summary.

**Implementation**:

```yaml
- name: Upload SBOM Summary with File Attachment
  run: |
    # Create scan summary
    SUMMARY_RESPONSE=$(curl -X POST \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -d '{"name": "SBOM Scan", "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"}' \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_summary")

    SUMMARY_SYS_ID=$(echo "$SUMMARY_RESPONSE" | jq -r '.result.sys_id')

    # Attach SBOM file
    curl -X POST \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: multipart/form-data" \
      -F "table_name=sn_devops_software_quality_scan_summary" \
      -F "table_sys_id=$SUMMARY_SYS_ID" \
      -F "file=@sbom.cyclonedx.json" \
      "$SERVICENOW_INSTANCE_URL/api/now/attachment/upload"
```

**Pros**:
- ✅ Simple implementation
- ✅ Preserves complete SBOM data
- ✅ No parsing required

**Cons**:
- ❌ Not queryable in ServiceNow (file attachment only)
- ❌ Less useful for risk analysis
- ❌ Requires manual download to analyze

### Option C: Hybrid Approach (BEST)

**Approach**: Upload summary metrics + attach full SBOM file for detailed analysis.

**Benefits**:
- ✅ Summary data queryable in ServiceNow
- ✅ Full SBOM available for deep-dive analysis
- ✅ Best of both worlds

---

## Recommended Implementation Plan

### Phase 1: Summary Upload (Option A - Quick Win)

**Scope**: Upload SBOM scan summary with key metrics

**Files to Modify**:
- `.github/workflows/security-scan.yaml` (add upload steps after SBOM generation)

**Implementation Checklist**:
- [ ] Add step to parse SBOM JSON and extract metrics
- [ ] Add step to upload scan summary to `sn_devops_software_quality_scan_summary`
- [ ] Ensure tool-id linkage (f62c4e49c3fcf614e1bbf0cb050131ef)
- [ ] Test with workflow run
- [ ] Verify summary appears in ServiceNow

**Estimated Effort**: 1-2 hours

### Phase 2: Component Detail Upload (Optional Enhancement)

**Scope**: Upload top 100 most critical components as detail records

**Implementation Checklist**:
- [ ] Add step to upload component details to `sn_devops_software_quality_scan_detail`
- [ ] Link details to summary via `scan_summary` reference field
- [ ] Filter to top 100 components (avoid overwhelming table)
- [ ] Test and verify

**Estimated Effort**: 2-3 hours

### Phase 3: SBOM File Attachment (Optional Enhancement)

**Scope**: Attach full SBOM JSON to scan summary for complete audit trail

**Implementation Checklist**:
- [ ] Add step to attach `sbom.cyclonedx.json` to scan summary record
- [ ] Test attachment upload
- [ ] Verify file downloadable from ServiceNow

**Estimated Effort**: 1 hour

---

## Expected Payload Examples

### Scan Summary Payload

```json
{
  "name": "SBOM Scan - microservices-demo-dev-49e7767",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "scan_type": "SBOM",
  "scan_date": "2025-11-06 19:00:00",
  "total_components": 487,
  "total_licenses": 23,
  "total_dependencies": 512,
  "scan_status": "completed",
  "artifact_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/19146477980",
  "description": "Software Bill of Materials (SBOM) generated by Syft (Anchore) in CycloneDX format"
}
```

### Component Detail Payload (Example)

```json
{
  "scan_summary": "abc123...",
  "component_name": "express",
  "component_version": "4.18.2",
  "component_type": "library",
  "package_url": "pkg:npm/express@4.18.2",
  "license": "MIT",
  "description": "Fast, unopinionated, minimalist web framework for Node.js"
}
```

---

## Testing Strategy

### Unit Testing

**Test 1: SBOM Parsing**
```bash
# Verify SBOM can be parsed correctly
COMPONENT_COUNT=$(jq '.components | length' sbom.cyclonedx.json)
echo "Found $COMPONENT_COUNT components"
```

**Test 2: ServiceNow API Connectivity**
```bash
# Verify can write to software quality scan summary table
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test SBOM Scan", "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"}' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_summary"
```

### Integration Testing

**Test 1: End-to-End Workflow**
1. Trigger security-scan.yaml workflow
2. Verify SBOM generated
3. Verify summary uploaded to ServiceNow
4. Check ServiceNow UI: DevOps > Software Quality > Scan Summary
5. Verify tool linkage (GithHubARC)

**Test 2: Data Validation**
1. Query ServiceNow API for uploaded scan
2. Verify component count matches SBOM
3. Verify scan date is current
4. Verify artifact URL is correct

---

## Benefits

### For DevOps Teams
- 📦 Complete dependency inventory in ServiceNow
- 🔗 Linked to deployments and change requests
- 📊 Dependency trends over time

### For Security Teams
- 🔍 Identify vulnerable dependencies
- 📋 License compliance tracking
- 🎯 Risk-based prioritization

### For Compliance
- ✅ SBOM evidence for audits (SOC 2, ISO 27001)
- 📜 Complete software supply chain visibility
- 🗂️ Centralized artifact repository

---

## Related Documentation

- [SBOM-AND-IMAGE-SIGNING-IMPLEMENTATION.md](implemented/SBOM-AND-IMAGE-SIGNING-IMPLEMENTATION.md) - Current SBOM implementation
- [SERVICENOW-TOOL-ID-FIX.md](SERVICENOW-TOOL-ID-FIX.md) - Tool ID consistency
- [SERVICENOW-SMOKE-TEST-INTEGRATION-ANALYSIS.md](SERVICENOW-SMOKE-TEST-INTEGRATION-ANALYSIS.md) - Similar integration pattern

---

## Schema Reference (Assumed)

Based on ServiceNow DevOps conventions, the tables likely have these fields:

### `sn_devops_software_quality_scan_summary`
- `sys_id` (string, auto-generated)
- `name` (string) - Scan name
- `tool` (reference to sn_devops_tool) - Tool that ran the scan
- `scan_type` (string) - Type of scan (SBOM, SAST, Dependency, etc.)
- `scan_date` (datetime) - When scan ran
- `scan_status` (string) - completed/failed/in_progress
- `total_components` (integer) - Total components found
- `artifact_url` (URL) - Link to artifact/results

### `sn_devops_software_quality_scan_detail`
- `sys_id` (string, auto-generated)
- `scan_summary` (reference to sn_devops_software_quality_scan_summary)
- `component_name` (string) - Library/package name
- `component_version` (string) - Version number
- `component_type` (string) - library/framework/application
- `package_url` (string) - PURL identifier
- `license` (string) - License type

**Note**: Actual schema should be verified via ServiceNow System Definition > Tables before implementation.

---

**Status**: 📋 **READY FOR IMPLEMENTATION**
**Recommended**: Start with Phase 1 (Summary Upload)
**Next Step**: Create GitHub issue with implementation checklist
