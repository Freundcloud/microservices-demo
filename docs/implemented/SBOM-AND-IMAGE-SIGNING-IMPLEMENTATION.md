# SBOM and Container Image Signing Implementation Guide

**Last Updated:** 2025-10-28
**Purpose:** Implement SBOM generation and container image signing/provenance for supply chain security

## Overview

This guide implements two critical supply chain security features:

1. **SBOM (Software Bill of Materials)** - Complete inventory of all software components in container images
2. **Image Signing & Provenance** - Cryptographic signatures and build provenance attestations

**Benefits:**
- ✅ Compliance (NIST, CISA, EU Cyber Resilience Act require SBOMs)
- ✅ Supply chain security (detect malicious dependencies)
- ✅ Vulnerability tracking (know what's in your containers)
- ✅ Provenance verification (prove images built by trusted CI/CD)
- ✅ Tamper detection (signatures prevent image modification)

---

## Architecture

### SBOM Generation Flow

```
Container Image Build
    ↓
Generate SBOM (Syft/Trivy)
    ↓
SBOM Formats: CycloneDX + SPDX
    ↓
Upload to:
  - GitHub Artifacts (storage)
  - ServiceNow (compliance evidence)
  - Dependency Graph (GitHub Security)
```

### Image Signing Flow

```
Container Image Build
    ↓
Sign with Cosign (keyless)
    ↓
Generate Provenance Attestation
    ↓
Store Signature + Attestation in OCI Registry
    ↓
Upload Provenance to ServiceNow
```

---

## Part 1: SBOM Generation

### Option 1: Anchore Syft (Recommended)

**Pros:**
- ✅ Most accurate SBOM generation
- ✅ Supports multiple formats (CycloneDX, SPDX, Syft JSON)
- ✅ Wide language/package manager support
- ✅ Official GitHub Action available

**Implementation:**

```yaml
# Add to .github/workflows/build-images.yaml

jobs:
  build-and-push:
    steps:
      # ... existing build steps ...

      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0.17.2
        with:
          image: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
          artifact-name: sbom-${{ matrix.service }}.json
          output-file: sbom-${{ matrix.service }}.cyclonedx.json
          format: cyclonedx-json
          upload-artifact: true
          upload-artifact-retention: 90

      - name: Generate SPDX SBOM
        uses: anchore/sbom-action@v0.17.2
        with:
          image: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
          artifact-name: sbom-${{ matrix.service }}-spdx.json
          output-file: sbom-${{ matrix.service }}.spdx.json
          format: spdx-json
          upload-artifact: true
          upload-artifact-retention: 90

      - name: Generate SBOM Summary
        run: |
          echo "## 📦 Software Bill of Materials" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Service:** ${{ matrix.service }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          # Count packages by type
          PKG_COUNT=$(jq '.components | length' sbom-${{ matrix.service }}.cyclonedx.json)
          echo "**Total Components:** $PKG_COUNT" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          # Count by package type
          echo "**Component Types:**" >> $GITHUB_STEP_SUMMARY
          jq -r '.components | group_by(.type) | .[] | "\(.| length) \(.[0].type)s"' sbom-${{ matrix.service }}.cyclonedx.json | while read line; do
            echo "- $line" >> $GITHUB_STEP_SUMMARY
          done
```

### Option 2: Trivy SBOM

**Pros:**
- ✅ Already using Trivy for vulnerability scanning
- ✅ Single tool for scanning + SBOM
- ✅ Can submit to GitHub Dependency Graph

**Implementation:**

```yaml
- name: Generate SBOM with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
    scan-type: 'image'
    format: 'cyclonedx'
    output: 'sbom-${{ matrix.service }}.cyclonedx.json'

- name: Submit SBOM to GitHub Dependency Graph
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
    scan-type: 'image'
    format: 'github'
    github-pat: ${{ secrets.GITHUB_TOKEN }}
```

### Multi-Format SBOM Generation (Best Practice)

Generate both CycloneDX and SPDX for maximum compatibility:

```yaml
- name: Generate Multi-Format SBOM
  run: |
    # CycloneDX (preferred for vulnerability scanning)
    syft ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }} \
      -o cyclonedx-json=sbom-${{ matrix.service }}.cyclonedx.json

    # SPDX (preferred for compliance/legal)
    syft ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }} \
      -o spdx-json=sbom-${{ matrix.service }}.spdx.json

    # Syft JSON (detailed analysis)
    syft ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }} \
      -o json=sbom-${{ matrix.service }}.syft.json
```

---

## Part 2: Container Image Signing

### Option 1: GitHub Artifact Attestation (Recommended - Native)

**Pros:**
- ✅ Native GitHub feature (no additional tools)
- ✅ Automatic keyless signing
- ✅ Stores attestations in GitHub
- ✅ Verifiable with `gh attestation verify`

**Implementation:**

```yaml
# Add to .github/workflows/build-images.yaml

jobs:
  build-and-push:
    permissions:
      contents: read
      packages: write
      id-token: write  # Required for attestation signing
      attestations: write  # Required for storing attestations

    steps:
      # ... existing build and push steps ...

      - name: Generate Build Provenance Attestation
        uses: actions/attest-build-provenance@v1
        with:
          subject-name: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}
          subject-digest: ${{ steps.docker-build.outputs.digest }}
          push-to-registry: true

      - name: Generate SBOM Attestation
        uses: actions/attest-sbom@v1
        with:
          subject-name: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}
          subject-digest: ${{ steps.docker-build.outputs.digest }}
          sbom-path: sbom-${{ matrix.service }}.cyclonedx.json
          push-to-registry: true
```

**Verification:**

```bash
# Verify attestations
gh attestation verify oci://$ECR_REGISTRY/$SERVICE:$TAG \
  --owner Freundcloud

# Download attestations
gh attestation download oci://$ECR_REGISTRY/$SERVICE:$TAG \
  --owner Freundcloud
```

### Option 2: Cosign (Sigstore - Industry Standard)

**Pros:**
- ✅ Industry standard (CNCF project)
- ✅ Keyless signing with OIDC
- ✅ Kubernetes integration (Policy Controller)
- ✅ Wide ecosystem support

**Implementation:**

```yaml
# Add to .github/workflows/build-images.yaml

jobs:
  build-and-push:
    permissions:
      contents: read
      packages: write
      id-token: write  # Required for keyless signing

    steps:
      # ... existing build and push steps ...

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.7.0

      - name: Sign Container Image
        run: |
          # Keyless signing using GitHub OIDC
          cosign sign --yes \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}

      - name: Generate and Attach Provenance
        run: |
          # Generate SLSA provenance
          cosign attest --yes \
            --predicate <(echo '{}' | jq \
              --arg repo "${{ github.repository }}" \
              --arg sha "${{ github.sha }}" \
              --arg workflow "${{ github.workflow }}" \
              --arg run_id "${{ github.run_id }}" \
              '{
                buildType: "https://github.com/Attestations/GitHubActionsWorkflow@v1",
                builder: { id: "https://github.com/\($repo)/actions/runs/\($run_id)" },
                invocation: {
                  configSource: {
                    uri: "git+https://github.com/\($repo)@\($sha)",
                    digest: { sha1: $sha },
                    entryPoint: $workflow
                  }
                },
                metadata: {
                  buildStartedOn: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                  completeness: { parameters: true, environment: false, materials: false }
                }
              }') \
            --type slsaprovenance \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}

      - name: Attach SBOM to Image
        run: |
          cosign attach sbom --sbom sbom-${{ matrix.service }}.cyclonedx.json \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}

      - name: Sign SBOM
        run: |
          cosign sign --yes \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}.sbom
```

**Verification:**

```bash
# Verify signature
cosign verify \
  --certificate-identity-regexp="https://github.com/Freundcloud/microservices-demo" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  $ECR_REGISTRY/$SERVICE:$TAG

# Verify SBOM
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp="https://github.com/Freundcloud/microservices-demo" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  $ECR_REGISTRY/$SERVICE:$TAG

# Download SBOM
cosign download sbom $ECR_REGISTRY/$SERVICE:$TAG > sbom.json
```

---

## Part 3: Upload to ServiceNow

### Upload SBOM to ServiceNow

```yaml
- name: Upload SBOM to ServiceNow
  if: inputs.push_images
  run: |
    # Read SBOM
    SBOM=$(cat sbom-${{ matrix.service }}.cyclonedx.json | jq -c '.')

    # Create ServiceNow record
    PAYLOAD=$(jq -n \
      --arg service "${{ matrix.service }}" \
      --arg version "${{ inputs.environment }}-${{ github.sha }}" \
      --arg image "${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}" \
      --arg sbom "$SBOM" \
      --arg format "CycloneDX 1.5 JSON" \
      --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg repository "${{ github.repository }}" \
      --arg commit "${{ github.sha }}" \
      --arg workflow_run "${{ github.run_id }}" \
      '{
        u_service_name: $service,
        u_image_version: $version,
        u_image_uri: $image,
        u_sbom_data: $sbom,
        u_sbom_format: $format,
        u_generated_at: $generated_at,
        u_repository: $repository,
        u_commit_sha: $commit,
        u_workflow_run: $workflow_run
      }')

    # Upload to ServiceNow custom table (u_container_sbom)
    curl -s -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/u_container_sbom"
  continue-on-error: true
```

### Upload Provenance to ServiceNow

```yaml
- name: Upload Image Provenance to ServiceNow
  if: inputs.push_images
  run: |
    # Get image digest
    DIGEST="${{ steps.docker-build.outputs.digest }}"

    # Create provenance record
    PAYLOAD=$(jq -n \
      --arg service "${{ matrix.service }}" \
      --arg version "${{ inputs.environment }}-${{ github.sha }}" \
      --arg image "${{ env.ECR_REGISTRY }}/${{ matrix.service }}@$DIGEST" \
      --arg digest "$DIGEST" \
      --arg signed "true" \
      --arg signature_method "cosign-keyless" \
      --arg oidc_issuer "https://token.actions.githubusercontent.com" \
      --arg certificate_identity "${{ github.repository }}" \
      --arg workflow_run "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
      --arg built_by "${{ github.actor }}" \
      --arg built_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{
        u_service_name: $service,
        u_image_version: $version,
        u_image_uri: $image,
        u_image_digest: $digest,
        u_signed: $signed,
        u_signature_method: $signature_method,
        u_oidc_issuer: $oidc_issuer,
        u_certificate_identity: $certificate_identity,
        u_workflow_run_url: $workflow_run,
        u_built_by: $built_by,
        u_built_at: $built_at
      }')

    # Upload to ServiceNow custom table (u_container_provenance)
    curl -s -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/u_container_provenance"
  continue-on-error: true
```

---

## ServiceNow Table Setup

### Create SBOM Table

**Table:** `u_container_sbom`

**Columns:**

| Column Label | Column Name | Type | Max Length |
|--------------|-------------|------|------------|
| Service Name | u_service_name | String | 100 |
| Image Version | u_image_version | String | 100 |
| Image URI | u_image_uri | String | 500 |
| SBOM Data | u_sbom_data | JSON | - |
| SBOM Format | u_sbom_format | String | 50 |
| Generated At | u_generated_at | Date/Time | - |
| Repository | u_repository | String | 200 |
| Commit SHA | u_commit_sha | String | 50 |
| Workflow Run | u_workflow_run | String | 50 |

### Create Provenance Table

**Table:** `u_container_provenance`

**Columns:**

| Column Label | Column Name | Type | Max Length |
|--------------|-------------|------|------------|
| Service Name | u_service_name | String | 100 |
| Image Version | u_image_version | String | 100 |
| Image URI | u_image_uri | String | 500 |
| Image Digest | u_image_digest | String | 100 |
| Signed | u_signed | True/False | - |
| Signature Method | u_signature_method | String | 100 |
| OIDC Issuer | u_oidc_issuer | String | 200 |
| Certificate Identity | u_certificate_identity | String | 200 |
| Workflow Run URL | u_workflow_run_url | URL | 500 |
| Built By | u_built_by | String | 100 |
| Built At | u_built_at | Date/Time | - |

---

## Complete Workflow Integration

Here's the complete addition to `build-images.yaml`:

```yaml
jobs:
  build-and-push:
    permissions:
      contents: read
      packages: write
      id-token: write  # Required for keyless signing and attestation
      attestations: write  # Required for GitHub attestations

    steps:
      # ... existing checkout, setup, build steps ...

      - name: Build and Push Docker Image
        id: docker-build
        uses: docker/build-push-action@v6
        with:
          context: src/${{ matrix.service }}
          push: ${{ inputs.push_images }}
          tags: |
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-latest
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: type=gha,mode=max,scope=${{ matrix.service }}
          platforms: linux/amd64,linux/arm64
          outputs: type=image,name=target,annotation-index.org.opencontainers.image.description=${{ matrix.service }}

      # ============================================================
      # NEW: SBOM GENERATION
      # ============================================================

      - name: Generate CycloneDX SBOM
        if: inputs.push_images
        uses: anchore/sbom-action@v0.17.2
        with:
          image: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
          artifact-name: sbom-${{ matrix.service }}-cyclonedx
          output-file: sbom-${{ matrix.service }}.cyclonedx.json
          format: cyclonedx-json
          upload-artifact: true
          upload-artifact-retention: 90

      - name: Generate SPDX SBOM
        if: inputs.push_images
        uses: anchore/sbom-action@v0.17.2
        with:
          image: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
          artifact-name: sbom-${{ matrix.service }}-spdx
          output-file: sbom-${{ matrix.service }}.spdx.json
          format: spdx-json
          upload-artifact: true
          upload-artifact-retention: 90

      # ============================================================
      # NEW: IMAGE SIGNING & PROVENANCE
      # ============================================================

      - name: Install Cosign
        if: inputs.push_images
        uses: sigstore/cosign-installer@v3.7.0

      - name: Sign Container Image (Keyless)
        if: inputs.push_images
        run: |
          cosign sign --yes \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}@${{ steps.docker-build.outputs.digest }}

      - name: Attach SBOM to Image
        if: inputs.push_images
        run: |
          cosign attach sbom --sbom sbom-${{ matrix.service }}.cyclonedx.json \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}@${{ steps.docker-build.outputs.digest }}

      - name: Sign SBOM Attachment
        if: inputs.push_images
        run: |
          # Get SBOM digest
          SBOM_DIGEST=$(cosign triangulate ${{ env.ECR_REGISTRY }}/${{ matrix.service }}@${{ steps.docker-build.outputs.digest }} | awk -F@ '{print $2}')

          # Sign SBOM
          cosign sign --yes \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:sha256-$SBOM_DIGEST.sbom

      # ============================================================
      # NEW: GITHUB NATIVE ATTESTATION (Alternative/Additional)
      # ============================================================

      - name: Generate Build Provenance Attestation
        if: inputs.push_images
        uses: actions/attest-build-provenance@v1
        with:
          subject-name: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}
          subject-digest: ${{ steps.docker-build.outputs.digest }}
          push-to-registry: true

      - name: Generate SBOM Attestation
        if: inputs.push_images
        uses: actions/attest-sbom@v1
        with:
          subject-name: ${{ env.ECR_REGISTRY }}/${{ matrix.service }}
          subject-digest: ${{ steps.docker-build.outputs.digest }}
          sbom-path: sbom-${{ matrix.service }}.cyclonedx.json
          push-to-registry: true

      # ============================================================
      # NEW: SERVICENOW INTEGRATION
      # ============================================================

      - name: Upload SBOM to ServiceNow
        if: inputs.push_images
        run: |
          # ... (see script above) ...
        env:
          SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
          SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
          SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        continue-on-error: true

      - name: Upload Provenance to ServiceNow
        if: inputs.push_images
        run: |
          # ... (see script above) ...
        env:
          SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
          SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
          SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        continue-on-error: true

      # ============================================================
      # UPDATE: Package Registration (now includes SBOM reference)
      # ============================================================

      - name: Register Package with ServiceNow (Enhanced)
        if: inputs.push_images
        uses: ServiceNow/servicenow-devops-register-package@v3.1.0
        with:
          devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
          devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
          instance-url: ${{ steps.sn-auth.outputs.instance-url }}
          tool-id: ${{ steps.sn-auth.outputs.tool-id }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Build ${{ matrix.service }}'
          artifacts: |
            [{
              "name": "${{ env.ECR_REGISTRY }}/${{ matrix.service }}",
              "version": "${{ inputs.environment }}-${{ github.sha }}",
              "semanticVersion": "${{ inputs.environment }}-${{ github.run_number }}",
              "repositoryName": "${{ github.repository }}",
              "digest": "${{ steps.docker-build.outputs.digest }}",
              "signed": true,
              "sbom_format": "CycloneDX 1.5 JSON"
            }]
          package-name: '${{ matrix.service }}-${{ inputs.environment }}-${{ github.run_number }}.package'
        continue-on-error: true
```

---

## Verification & Testing

### Test SBOM Generation

```bash
# Run workflow
gh workflow run build-images.yaml \
  --ref main \
  -f environment=dev \
  -f push_images=true \
  -f services='["frontend"]'

# Download SBOM artifact
gh run download <run-id> --name sbom-frontend-cyclonedx

# Verify SBOM content
jq '.components | length' sbom-frontend.cyclonedx.json
jq '.components[] | select(.type == "library") | .name' sbom-frontend.cyclonedx.json
```

### Test Image Signature

```bash
# Verify with Cosign
cosign verify \
  --certificate-identity-regexp="https://github.com/Freundcloud/microservices-demo" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev-abc123

# Verify with GitHub CLI
gh attestation verify \
  oci://533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev-abc123 \
  --owner Freundcloud
```

### Test SBOM Attachment

```bash
# Download SBOM from image
cosign download sbom \
  533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev-abc123 \
  > downloaded-sbom.json

# Verify it matches original
diff sbom-frontend.cyclonedx.json downloaded-sbom.json
```

### Test ServiceNow Upload

```bash
# Query ServiceNow SBOM table
curl -s -u "$SN_USER:$SN_PASS" \
  "$SN_INSTANCE_URL/api/now/table/u_container_sbom?sysparm_query=u_service_name=frontend" \
  | jq '.result[] | {service: .u_service_name, version: .u_image_version, components: (.u_sbom_data | fromjson | .components | length)}'

# Query ServiceNow provenance table
curl -s -u "$SN_USER:$SN_PASS" \
  "$SN_INSTANCE_URL/api/now/table/u_container_provenance?sysparm_query=u_service_name=frontend" \
  | jq '.result[] | {service: .u_service_name, signed: .u_signed, method: .u_signature_method}'
```

---

## Compliance Benefits

### NIST SSDF (Secure Software Development Framework)

**Practice PW.1.3:** Obtain and maintain well-secured, up-to-date components
- ✅ SBOM tracks all components
- ✅ Vulnerability scanning on SBOM
- ✅ Evidence of component inventory

**Practice PS.3.1:** Use automated tools to verify signatures
- ✅ Cosign signatures verify image integrity
- ✅ Provenance proves build origin

### Executive Order 14028 (Cybersecurity)

**Section 4(e):** Maintain accurate and up-to-date data on software products
- ✅ SBOMs provide complete software inventory
- ✅ Stored in ServiceNow for compliance reporting

**Section 4(f):** Employ automated tools for identity validation
- ✅ Keyless signing with OIDC
- ✅ Provenance attestations

### EU Cyber Resilience Act

**Article 15:** Provide SBOM for software products
- ✅ CycloneDX and SPDX formats
- ✅ Available for download from registry
- ✅ Stored in compliance system (ServiceNow)

---

## Cost Considerations

**Free:**
- ✅ Syft SBOM generation (open source)
- ✅ Cosign signing (open source, keyless)
- ✅ GitHub artifact storage (included)
- ✅ GitHub Dependency Graph (included)

**Paid:**
- ⚠️ OCI registry storage (signatures ~10MB per image)
- ⚠️ ServiceNow API calls (minimal)

**Estimate:**
- SBOM files: ~1-5MB per image × 12 services = 12-60MB
- Signatures: ~10KB per image × 12 services = 120KB
- **Total storage:** ~60MB per deployment
- **Monthly (90-day retention):** ~5.4GB (negligible cost)

---

## Best Practices

### 1. Generate SBOM for Every Build

Always generate SBOM, even for dev/qa:

```yaml
if: inputs.push_images  # Always when pushing
```

### 2. Use Multiple SBOM Formats

- CycloneDX for vulnerability scanning
- SPDX for compliance/legal review

### 3. Sign Every Image

Never deploy unsigned images to production:

```yaml
if: inputs.environment == 'prod'
  run: |
    # Verify signature exists
    cosign verify ... || exit 1
```

### 4. Attach SBOM to Image

Store SBOM with image, not separately:

```bash
cosign attach sbom --sbom sbom.json $IMAGE
```

### 5. Automate Verification

Add verification to deployment workflow:

```yaml
- name: Verify Image Signature Before Deploy
  run: |
    cosign verify \
      --certificate-identity-regexp="..." \
      --certificate-oidc-issuer="..." \
      $IMAGE
```

---

## Troubleshooting

### Issue: Cosign "no signatures found"

**Solution:** Ensure `id-token: write` permission is set.

### Issue: SBOM attachment fails

**Solution:** Check OCI registry supports referrers (AWS ECR does since 2023).

### Issue: ServiceNow SBOM upload fails (413 Request Entity Too Large)

**Solution:** Compress SBOM or store URL reference instead of full SBOM.

### Issue: GitHub attestation not found

**Solution:** Ensure `attestations: write` permission and `push-to-registry: true`.

---

## Next Steps

1. ✅ Add SBOM generation to build workflow
2. ✅ Add Cosign signing to build workflow
3. ✅ Create ServiceNow tables (u_container_sbom, u_container_provenance)
4. ✅ Add upload scripts to workflow
5. ✅ Test with sample build
6. ✅ Add verification to deployment workflow
7. ✅ Document verification procedures
8. ✅ Train team on SBOM/signing benefits

---

## References

- **Syft SBOM Action**: https://github.com/anchore/sbom-action
- **Cosign Documentation**: https://docs.sigstore.dev/cosign/overview/
- **GitHub Attestations**: https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds
- **CycloneDX Specification**: https://cyclonedx.org/specification/overview/
- **SPDX Specification**: https://spdx.dev/specifications/
- **NIST SSDF**: https://csrc.nist.gov/Projects/ssdf
- **EO 14028**: https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/

---

**Document Owner:** DevOps Team
**Last Review:** 2025-10-28
**Next Review:** 2025-11-28
