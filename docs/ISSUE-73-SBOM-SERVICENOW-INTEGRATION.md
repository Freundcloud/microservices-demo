# Issue #73: SBOM Upload to ServiceNow - Implementation Guide

**Issue**: https://github.com/Freundcloud/microservices-demo/issues/73
**Status**: Phase 1 ✅ COMPLETE | Phase 2 & 3 📋 DOCUMENTED
**Date**: 2025-11-07

---

## Executive Summary

This guide documents the complete implementation of SBOM (Software Bill of Materials) integration with ServiceNow DevOps software quality tables. The integration provides dependency visibility, license compliance tracking, and vulnerability context in ServiceNow.

**What's Implemented**:
- ✅ **Phase 1**: SBOM Summary Upload - Metrics visible in ServiceNow DevOps Insights
- 📋 **Phase 2**: Component Details Upload - Optional deep visibility (documented, not implemented)
- 📋 **Phase 3**: File Attachment - Optional audit trail (documented, not implemented)

---

## Problem Statement

**Current State**: SBOM is generated during security scans but not uploaded to ServiceNow.

**Impact**:
- ❌ No dependency visibility in ServiceNow DevOps workspace
- ❌ Missing license compliance data
- ❌ Incomplete software composition tracking
- ❌ Gaps in vulnerability context (which components are affected)

**Goal**: Upload SBOM data to ServiceNow to provide complete software composition visibility alongside other quality metrics (SonarCloud, smoke tests, security scans).

---

## Solution Architecture

### Data Flow

```
GitHub Actions Workflow (security-scan.yaml)
  │
  ├─► Generate SBOM (Anchore Syft)
  │     └─► sbom.cyclonedx.json (CycloneDX format)
  │
  ├─► Scan Vulnerabilities (Grype)
  │     └─► results.sarif (vulnerable packages)
  │
  ├─► Parse SBOM + Cross-Reference Grype
  │     └─► Extract metrics (components, licenses, dependencies, vulnerabilities)
  │
  └─► Upload to ServiceNow
        └─► POST /api/now/table/sn_devops_software_quality_scan_summary
              ├─► Tool: f62c4e49c3fcf614e1bbf0cb050131ef (GithHubARC)
              ├─► Metrics: total_components, license_count, dependency_count, vulnerable_components
              └─► Links to GitHub Actions run URL
```

### ServiceNow Tables

#### `sn_devops_software_quality_scan_summary` (Summary Table)

**Purpose**: High-level SBOM metrics for DevOps Insights dashboard.

**Key Fields**:
```json
{
  "name": "string (255)",              // "SBOM Scan - microservices-demo (abc123)"
  "tool": "reference",                 // f62c4e49c3fcf614e1bbf0cb050131ef (GithHubARC)
  "url": "string (1024)",              // GitHub Actions workflow run URL
  "scanner_name": "string (100)",      // "Syft" (from Anchore)
  "scanner_version": "string (40)",    // e.g., "0.99.0"
  "start_time": "glide_date_time",     // ISO 8601 from SBOM metadata.timestamp
  "finish_time": "glide_date_time",    // Workflow completion time
  "duration": "integer",               // Seconds (approximate)
  "total_components": "integer",       // Total packages in SBOM
  "vulnerable_components": "integer",  // Components with known CVEs (from Grype)
  "license_count": "integer",          // Unique SPDX licenses detected
  "dependency_count": "integer"        // Total dependency relationships
}
```

**Access in ServiceNow**:
```
https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_software_quality_scan_summary_list.do
```

#### `sn_devops_software_quality_scan_detail` (Component Details Table)

**Purpose**: Individual component records for drill-down visibility.

**Key Fields**:
```json
{
  "scan_summary": "reference",         // sys_id linking to summary record
  "component_name": "string (255)",    // Package name (e.g., "express")
  "component_version": "string (100)", // Package version (e.g., "4.18.2")
  "component_type": "string (40)",     // "library", "application", "operating-system"
  "license": "string (100)",           // SPDX license ID (e.g., "MIT")
  "vulnerability_count": "integer",    // Known CVEs for this component
  "cve_list": "string (4000)",         // Comma-separated CVE IDs
  "purl": "string (1024)"              // Package URL (e.g., "pkg:npm/express@4.18.2")
}
```

**Access in ServiceNow**:
```
https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_software_quality_scan_detail_list.do
```

---

## Phase 1: SBOM Summary Upload ✅ IMPLEMENTED

### Implementation Details

**File Modified**: `.github/workflows/security-scan.yaml`
**Location**: Lines 120-212 (after "Generate SBOM" step)

**What It Does**:
1. Checks if SBOM file exists and is valid JSON
2. Extracts metadata: scanner name, version, timestamp
3. Calculates metrics:
   - **Total Components**: Count of packages in SBOM
   - **License Count**: Count of unique SPDX licenses
   - **Dependency Count**: Count of dependency relationships
   - **Vulnerable Components**: Cross-references SBOM with Grype SARIF results
4. Uploads summary to ServiceNow `sn_devops_software_quality_scan_summary` table
5. Uses hardcoded GithHubARC tool-id for consistent linkage

**Key Features**:
- ✅ Cross-references Grype vulnerability scan for vulnerable component count
- ✅ Handles missing/invalid SBOM gracefully (continues workflow)
- ✅ Saves `sbom_summary_id` for potential Phase 2 component upload
- ✅ Non-blocking (continue-on-error: true)

### Example Payload

```json
{
  "name": "SBOM Scan - microservices-demo (abc123def456)",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "url": "https://github.com/Freundcloud/microservices-demo/actions/runs/123456789",
  "scanner_name": "syft",
  "scanner_version": "0.99.0",
  "start_time": "2025-11-07 10:30:00",
  "finish_time": "2025-11-07 10:30:10",
  "duration": 10,
  "total_components": 1247,
  "vulnerable_components": 23,
  "license_count": 45,
  "dependency_count": 3421
}
```

### Testing Phase 1

**Trigger Workflow**:
```bash
gh workflow run security-scan.yaml
```

**Verify in GitHub Actions Logs**:
```
📊 Uploading SBOM summary to ServiceNow...
   Vulnerable Components: 23 (from Grype scan)
✅ SBOM summary uploaded to ServiceNow (sys_id: abc123def456)
   Components: 1247, Licenses: 45, Dependencies: 3421
   Vulnerable: 23, Tool: syft v0.99.0
```

**Verify in ServiceNow**:
1. Navigate to: `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_software_quality_scan_summary_list.do`
2. Search for: "SBOM Scan - microservices-demo"
3. Confirm fields populated: total_components, license_count, dependency_count, vulnerable_components
4. Check tool field shows "GithHubARC"

**Success Criteria**:
- ✅ HTTP 201 response from ServiceNow API
- ✅ sys_id returned in response body
- ✅ Record visible in ServiceNow UI with all metrics
- ✅ Tool field correctly links to GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)

### Benefits of Phase 1

**For DevOps Teams**:
- ✅ Software composition metrics visible in ServiceNow DevOps Insights
- ✅ Track dependency count trends over time
- ✅ Identify license proliferation

**For Security Teams**:
- ✅ Vulnerable component count at a glance
- ✅ Cross-referenced with actual vulnerability scan (Grype)
- ✅ Link to detailed Grype SARIF results in GitHub Security tab

**For Compliance Teams**:
- ✅ License compliance tracking (unique license count)
- ✅ Audit trail (linked to GitHub Actions run)
- ✅ SOC 2 / NIST SSDF evidence

---

## Phase 2: Component Details Upload 📋 DOCUMENTED

### Overview

**Status**: Not implemented (optional enhancement)
**Effort**: 2-3 hours
**Value**: MEDIUM - Provides drill-down capability in ServiceNow

**What It Does**: Upload top 100 individual components to `sn_devops_software_quality_scan_detail` table for component-level visibility.

### When to Implement Phase 2

**Implement if**:
- ServiceNow users need component-level drill-down (e.g., "Show me all MIT-licensed packages")
- Compliance requires detailed dependency tracking
- Want to link CVEs to specific components in ServiceNow

**Don't implement if**:
- High-level metrics (Phase 1) are sufficient
- Performance impact (2-3 min for 100 API calls) is unacceptable
- ServiceNow users prefer GitHub Security tab for component details

### Implementation Code

**Add to `.github/workflows/security-scan.yaml`** after Phase 1 step:

```yaml
- name: Upload SBOM Component Details to ServiceNow
  if: steps.upload-sbom-summary.outputs.sbom_summary_id != ''
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  run: |
    echo "📦 Uploading SBOM component details to ServiceNow..."

    SBOM_FILE="sbom.cyclonedx.json"
    SUMMARY_ID="${{ steps.upload-sbom-summary.outputs.sbom_summary_id }}"

    # Extract top 100 components (sorted by name)
    # Limit to 100 to avoid overwhelming ServiceNow and long workflow run times
    COMPONENT_COUNT=0
    jq -r '.components[:100] | .[] | @json' "$SBOM_FILE" | while IFS= read -r component; do

      # Parse component fields
      COMPONENT_NAME=$(echo "$component" | jq -r '.name // "unknown"')
      COMPONENT_VERSION=$(echo "$component" | jq -r '.version // "unknown"')
      COMPONENT_TYPE=$(echo "$component" | jq -r '.type // "library"')
      LICENSE=$(echo "$component" | jq -r '.licenses[0].license.id // "Unknown"')
      PURL=$(echo "$component" | jq -r '.purl // ""')

      # Check if this component has vulnerabilities in Grype results
      VULNERABILITY_COUNT=0
      CVE_LIST=""
      if [ -f "results.sarif" ] && [ -n "$PURL" ]; then
        # Search SARIF for this package URL
        VULN_RESULTS=$(jq --arg purl "$PURL" '[.runs[].results[] | select(.locations[].physicalLocation.artifactLocation.uri | contains($purl))]' results.sarif 2>/dev/null || echo "[]")
        VULNERABILITY_COUNT=$(echo "$VULN_RESULTS" | jq 'length' || echo "0")

        # Extract CVE IDs
        CVE_LIST=$(echo "$VULN_RESULTS" | jq -r '[.[].ruleId] | join(", ")' 2>/dev/null || echo "")
      fi

      # Upload each component to ServiceNow
      RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{
          "scan_summary": "'"$SUMMARY_ID"'",
          "component_name": "'"$COMPONENT_NAME"'",
          "component_version": "'"$COMPONENT_VERSION"'",
          "component_type": "'"$COMPONENT_TYPE"'",
          "license": "'"$LICENSE"'",
          "purl": "'"$PURL"'",
          "vulnerability_count": '$VULNERABILITY_COUNT',
          "cve_list": "'"$CVE_LIST"'"
        }' \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_detail")

      HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

      if [ "$HTTP_CODE" = "201" ]; then
        COMPONENT_COUNT=$((COMPONENT_COUNT + 1))
        echo "   [$COMPONENT_COUNT/100] Uploaded: $COMPONENT_NAME@$COMPONENT_VERSION ($LICENSE)"
      else
        echo "   ⚠️  Failed to upload $COMPONENT_NAME@$COMPONENT_VERSION (HTTP $HTTP_CODE)"
      fi
    done

    echo "✅ Uploaded $COMPONENT_COUNT component details to ServiceNow"
  continue-on-error: true
```

### Performance Considerations

**Upload Time**: ~2-3 minutes for 100 components
- Each component = 1 API call
- 100 API calls @ ~1-2 seconds each
- Sequential execution (not parallel to avoid rate limits)

**Optimization Options**:
1. **Reduce component count**: Upload top 50 instead of 100
2. **Batch API**: Use ServiceNow Batch REST API (1 call for multiple records)
3. **Conditional upload**: Only upload vulnerable components

**Example Batch API Approach** (Advanced):

```yaml
# Upload components in batches of 10
BATCH_SIZE=10
BATCH_PAYLOAD="[]"
BATCH_COUNT=0

jq -r '.components[:100] | .[] | @json' "$SBOM_FILE" | while IFS= read -r component; do
  # Build batch payload
  BATCH_PAYLOAD=$(echo "$BATCH_PAYLOAD" | jq --argjson comp "$component" '. + [$comp]')
  BATCH_COUNT=$((BATCH_COUNT + 1))

  # Upload when batch size reached
  if [ $((BATCH_COUNT % BATCH_SIZE)) -eq 0 ]; then
    curl -X POST \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -d "$BATCH_PAYLOAD" \
      "$SERVICENOW_INSTANCE_URL/api/now/v1/batch"

    BATCH_PAYLOAD="[]"
  fi
done
```

### Testing Phase 2

**Trigger**: Run security-scan.yaml workflow
**Verify**: Check logs for "✅ Uploaded X component details to ServiceNow"
**ServiceNow**: Navigate to component details table, filter by scan_summary sys_id

---

## Phase 3: Attach Full SBOM JSON 📋 DOCUMENTED

### Overview

**Status**: Not implemented (optional enhancement)
**Effort**: 1 hour
**Value**: LOW - Complete audit trail (full SBOM already in GitHub artifacts)

**What It Does**: Attach the full `sbom.cyclonedx.json` file to the ServiceNow scan summary record for complete audit trail.

### When to Implement Phase 3

**Implement if**:
- Strict audit requirements mandate full SBOM in ServiceNow
- Need offline access to SBOM (without GitHub account)
- Regulatory compliance requires SBOM attached to change records

**Don't implement if**:
- GitHub artifact retention (90 days) is sufficient
- ServiceNow storage costs are a concern
- Full SBOM is too large for ServiceNow attachment limits

### Implementation Code

**Add to `.github/workflows/security-scan.yaml`** after Phase 1 or Phase 2 step:

```yaml
- name: Attach SBOM File to ServiceNow Record
  if: steps.upload-sbom-summary.outputs.sbom_summary_id != ''
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  run: |
    echo "📎 Attaching SBOM file to ServiceNow record..."

    SUMMARY_ID="${{ steps.upload-sbom-summary.outputs.sbom_summary_id }}"
    SBOM_FILE="sbom.cyclonedx.json"

    # ServiceNow Attachment API requires multipart/form-data
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -F "table_name=sn_devops_software_quality_scan_summary" \
      -F "table_sys_id=$SUMMARY_ID" \
      -F "file_name=sbom.cyclonedx.json" \
      -F "file=@$SBOM_FILE" \
      "$SERVICENOW_INSTANCE_URL/api/now/attachment/upload")

    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

    if [ "$HTTP_CODE" = "201" ]; then
      ATTACHMENT_ID=$(echo "$BODY" | jq -r '.result.sys_id')
      echo "✅ SBOM file attached to ServiceNow record (attachment sys_id: $ATTACHMENT_ID)"
    else
      echo "⚠️  Failed to attach SBOM file to ServiceNow (HTTP $HTTP_CODE)"
      echo "$BODY" | jq '.' || echo "$BODY"
    fi
  continue-on-error: true
```

### File Size Considerations

**Typical SBOM Size**:
- Small project: ~50 KB (50-100 components)
- Medium project: ~500 KB (500-1000 components)
- Large project: ~5 MB (5000+ components)

**ServiceNow Limits**:
- Default attachment limit: 5 MB
- Can be increased by ServiceNow admin
- Counts against ServiceNow instance storage quota

### Testing Phase 3

**Trigger**: Run security-scan.yaml workflow
**Verify**: Check logs for "✅ SBOM file attached to ServiceNow record"
**ServiceNow**: Open scan summary record, check "Attachments" related list

---

## Complete Integration Example

### Expected ServiceNow Records

After all 3 phases (if implemented):

**Summary Record** (`sn_devops_software_quality_scan_summary`):
```
Name: SBOM Scan - microservices-demo (abc123def456)
Tool: GithHubARC
Scanner: syft v0.99.0
Total Components: 1247
Vulnerable Components: 23
License Count: 45
Dependency Count: 3421
Duration: 10 seconds
URL: https://github.com/Freundcloud/microservices-demo/actions/runs/123456789
```

**Component Detail Records** (`sn_devops_software_quality_scan_detail`):
```
[1/100] express@4.18.2 (MIT) - 0 CVEs
[2/100] logrus@v1.9.0 (MIT) - 2 CVEs (CVE-2023-1234, CVE-2023-5678)
[3/100] react@18.2.0 (MIT) - 0 CVEs
...
```

**Attachment**:
- `sbom.cyclonedx.json` (full SBOM file)

---

## Related Documentation

- **Issue #72 Implementation**: [ISSUE-72-IMPLEMENTATION-SUMMARY.md](ISSUE-72-IMPLEMENTATION-SUMMARY.md) - Smoke test integration
- **Issue #76 Analysis**: [SERVICENOW-SOFTWARE-QUALITY-EMPTY-ANALYSIS.md](SERVICENOW-SOFTWARE-QUALITY-EMPTY-ANALYSIS.md) - SonarCloud integration
- **Tool-ID Consolidation**: [SERVICENOW-TOOL-ID-FIX.md](SERVICENOW-TOOL-ID-FIX.md) - GithHubARC tool-id standardization
- **ServiceNow Integration Overview**: [SERVICENOW-IMPLEMENTATION-COMPLETE.md](SERVICENOW-IMPLEMENTATION-COMPLETE.md)

---

## Troubleshooting

### SBOM File Not Found

**Error**: "⚠️  SBOM file not found, skipping upload"

**Cause**: anchore/sbom-action failed to generate SBOM

**Solution**:
1. Check sbom-action step logs in GitHub Actions
2. Verify repository is not empty (SBOM requires code to scan)
3. Check anchore/sbom-action version (use v0.17.2 or later)

### Invalid SBOM JSON

**Error**: "⚠️  SBOM file is not valid JSON, skipping upload"

**Cause**: Corrupted SBOM file or sbom-action failure

**Solution**:
1. Download SBOM artifact from GitHub Actions
2. Validate JSON with `jq empty sbom.cyclonedx.json`
3. Check sbom-action logs for errors
4. Try regenerating SBOM with manual syft command

### ServiceNow Upload Failed (HTTP 401)

**Error**: "⚠️  Failed to upload SBOM summary to ServiceNow (HTTP 401)"

**Cause**: Invalid ServiceNow credentials

**Solution**:
1. Verify `SERVICENOW_USERNAME` secret is correct
2. Verify `SERVICENOW_PASSWORD` secret is correct
3. Test credentials manually: `curl -u "$USER:$PASS" "$INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"`
4. Check ServiceNow user has write permissions to `sn_devops_software_quality_scan_summary` table

### ServiceNow Upload Failed (HTTP 403)

**Error**: "⚠️  Failed to upload SBOM summary to ServiceNow (HTTP 403)"

**Cause**: ServiceNow user lacks write permissions

**Solution**:
1. Log into ServiceNow with admin account
2. Navigate to User Administration > Users
3. Find the integration user
4. Assign role: `sn_devops.devops_user` (or equivalent write role)
5. Verify role grants write access to `sn_devops_software_quality_scan_summary`

### Vulnerable Components Count Always 0

**Error**: "Vulnerable Components: 0 (Grype results not available)"

**Cause**: Grype scan failed or SARIF file not found

**Solution**:
1. Verify Grype scan step completed successfully
2. Check if `results.sarif` exists in workflow workspace
3. Ensure SBOM upload step runs AFTER Grype scan step
4. Check step ordering in security-scan.yaml

### Tool Field Shows Empty in ServiceNow

**Error**: Tool field is null or empty in ServiceNow UI

**Cause**: Invalid tool-id or tool record doesn't exist

**Solution**:
1. Verify tool-id `f62c4e49c3fcf614e1bbf0cb050131ef` exists in `sn_devops_tool` table
2. Query ServiceNow: `https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef`
3. If tool doesn't exist, create GithHubARC tool record (see SERVICENOW-TOOL-ID-FIX.md)
4. Re-run workflow after tool is created

---

## Next Steps

### Immediate (Phase 1 Testing)

1. ✅ **Trigger security-scan.yaml workflow**
   ```bash
   gh workflow run security-scan.yaml
   ```

2. ✅ **Verify SBOM upload in GitHub Actions logs**
   - Look for "✅ SBOM summary uploaded to ServiceNow"
   - Confirm sys_id returned
   - Check metrics: components, licenses, dependencies, vulnerabilities

3. ✅ **Verify record in ServiceNow**
   - Navigate to `sn_devops_software_quality_scan_summary_list.do`
   - Search for "SBOM Scan - microservices-demo"
   - Confirm all fields populated correctly

### Future Enhancements (Optional)

**Phase 2 - Component Details** (if needed):
- Implement top 100 component upload
- Add vulnerability cross-referencing
- Test drill-down in ServiceNow UI

**Phase 3 - File Attachment** (if needed):
- Implement SBOM file attachment
- Verify attachment appears in ServiceNow
- Check file size limits

**Additional Metrics**:
- Language breakdown (Python, Go, Java, Node.js components)
- Top 10 most-used licenses
- Direct vs transitive dependency count
- Component age/freshness metrics

---

**Status**: ✅ Phase 1 IMPLEMENTED AND READY FOR TESTING
**Impact**: HIGH - Complete software composition visibility in ServiceNow DevOps Insights
**Closes**: #73 (partially - Phase 1 complete, Phase 2 & 3 optional)
