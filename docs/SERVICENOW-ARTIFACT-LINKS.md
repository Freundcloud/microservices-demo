# ServiceNow Artifact Links for Approvers

This guide explains how approvers can access GitHub artifacts (SBOM, signatures, SARIF results, etc.) directly from ServiceNow change requests.

## Overview

Every change request created by GitHub Actions now includes **direct links** to compliance artifacts stored in GitHub. Approvers can access these files with a single click without manually navigating GitHub.

## Where to Find Artifact Links in ServiceNow

### 1. Open the Change Request

1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to **Change** → **All** or **Change** → **Normal**
3. Find your change request (e.g., `CHG0030XXX`)
4. Click to open it

### 2. Scroll to Custom Fields Section

The artifact links are located in custom URL fields near the bottom of the change request form. They display as **clickable hyperlinks**:

| Field Label in ServiceNow | Field Name | What It Links To | When Available |
|---------------------------|-----------|------------------|----------------|
| **SBOM Artifact** | `u_sbom_url` | Software Bill of Materials in CycloneDX JSON format | Every deployment |
| **Image Signatures** | `u_signatures_url` | Cosign signatures and certificates for all Docker images | When images are built |
| **Security Scan Results** | `u_sarif_results_url` | Security scan results in GitHub Security Tab (CodeQL, Trivy, etc.) | Every deployment |
| **Infrastructure Report** | `u_infrastructure_report_url` | Infrastructure discovery report (Markdown + JSON) | When discovery runs |
| **All GitHub Artifacts** | `u_github_artifacts_url` | All artifacts in one page (SBOM, signatures, reports) | Every deployment |

### 3. Click the Links

Each URL field is clickable and takes you directly to the artifact in GitHub:

- **SBOM Artifact** → Opens GitHub Actions run, scrolls to SBOM artifact
- **Image Signatures** → Opens GitHub Actions run, scrolls to signature artifacts
- **Security Scan Results** → Opens GitHub Security → Code Scanning tab with results
- **Infrastructure Report** → Opens GitHub Actions run, scrolls to discovery report
- **All GitHub Artifacts** → Opens GitHub Actions run artifacts section (all files)

## What You Can Download

### SBOM (Software Bill of Materials)
**File**: `sbom.cyclonedx.json`  
**Size**: ~100-300 KB  
**Format**: CycloneDX JSON  
**Retention**: 90 days

**Contains**:
- Complete list of all dependencies
- Package names and versions
- License information
- CVE identifiers for known vulnerabilities

**Use For**:
- Compliance audits (SOC 2, ISO 27001)
- License verification
- Dependency tracking
- Vulnerability assessment

---

### Signatures
**Files**: `signature-{service}.sig`, `certificate-{service}.pem`  
**Size**: ~1-5 KB per service  
**Format**: Cosign signature + X.509 certificate  
**Retention**: 90 days

**Contains**:
- Cryptographic signature for each Docker image
- X.509 certificate proving authenticity
- One artifact per service (frontend, cartservice, etc.)

**Use For**:
- Verify images haven't been tampered with
- Prove provenance (built by GitHub Actions)
- Compliance with supply chain security requirements

---

### SARIF Results
**Location**: GitHub Security → Code Scanning  
**Format**: Interactive web view + downloadable SARIF JSON  
**Retention**: Permanent (in GitHub)

**Contains**:
- CodeQL static analysis results (5 languages)
- Trivy filesystem vulnerabilities
- Semgrep SAST findings
- Checkov IaC security issues
- tfsec Terraform security
- OWASP Dependency Check results
- Grype dependency vulnerabilities

**Use For**:
- Security review before approval
- Risk assessment
- Compliance evidence
- Trend analysis

---

### Infrastructure Discovery Report
**Files**: `discovery-report.md`, `terraform-state.json`  
**Size**: ~10-50 KB  
**Format**: Markdown report + JSON  
**Retention**: 90 days

**Contains**:
- Complete EKS cluster configuration
- Node groups, instance types, capacity
- VPC, subnets, security groups
- Kubernetes namespaces and workloads
- Terraform state snapshot

**Use For**:
- Infrastructure review
- Capacity planning
- Security assessment
- Change validation

## Example: Approving a Change Request

### Scenario
Change request **CHG0030320** needs approval for deploying to production.

### Approval Checklist

1. ✅ **Review Change Details**
   - Short description: What's being deployed?
   - Environment: dev/qa/prod?
   - Who triggered it?

2. ✅ **Check Security Scan Status**
   - Custom field: `u_security_scan_status` = `passed` or `warning`?
   - Custom field: `u_critical_vulnerabilities` = 0?
   - Custom field: `u_high_vulnerabilities` = <5?

3. ✅ **Review SARIF Results** (Click `u_sarif_results_url`)
   - Any new critical/high findings?
   - Are findings addressed or accepted risk?

4. ✅ **Verify SBOM** (Click `u_sbom_url`)
   - Download and review dependencies
   - Check for known CVEs
   - Verify licenses comply with policy

5. ✅ **Check Signatures** (Optional - Click `u_signatures_url`)
   - Download signatures to verify authenticity
   - Confirm all services have signatures

6. ✅ **Review Infrastructure Changes** (If applicable - Click `u_infrastructure_report_url`)
   - Review EKS cluster configuration
   - Verify capacity is adequate
   - Check security group rules

7. ✅ **Make Decision**
   - Approve: Click "Approve" in ServiceNow
   - Reject: Click "Reject" and add comments
   - Request Changes: Add comments and set to "On Hold"

## Artifact Retention Policy

| Artifact Type | Retention | Location |
|--------------|-----------|----------|
| SBOM | 90 days | GitHub Actions artifacts |
| Signatures | 90 days | GitHub Actions artifacts |
| SARIF Results | Permanent | GitHub Security tab |
| Infrastructure Report | 90 days | GitHub Actions artifacts |
| Links in ServiceNow | Permanent | ServiceNow change_request table |

**Note**: After 90 days, artifacts are automatically deleted by GitHub. The **links remain in ServiceNow** but will show "Artifact expired". For audit purposes, download critical artifacts within 90 days if long-term retention is required.

## Troubleshooting

### Link Doesn't Work
**Problem**: Clicking URL shows "Page not found" or "Artifact expired"

**Solutions**:
1. **Check if artifact is expired** (>90 days old)
   - Download artifact immediately if needed for audit
   - Contact DevOps team if critical evidence is needed

2. **Verify GitHub permissions**
   - You need **read access** to the repository
   - Ask DevOps admin to grant access: Freundcloud/microservices-demo

3. **Check if workflow completed**
   - If workflow failed, artifacts may not have been uploaded
   - Check GitHub Actions status in change request fields

### Artifact Not Available
**Problem**: Link opens GitHub but shows "No artifacts"

**Possible Causes**:
1. **Workflow skipped artifact upload** (e.g., no code changes detected)
2. **Workflow failed before uploading artifacts**
3. **Security scan was skipped** (check `skip_security` input)

**Solution**: Check workflow run logs:
- Click `u_github_artifacts_url`
- Click "Summary" to see workflow status
- Review failed jobs

### Can't Download Artifact
**Problem**: Click download but file doesn't download

**Solutions**:
1. **Pop-up blocker**: Allow pop-ups from github.com
2. **Browser issue**: Try different browser (Chrome, Firefox, Edge)
3. **Network restriction**: Check corporate firewall/proxy settings
4. **File size**: Large SBOM files may take time to prepare for download

## Benefits for Approvers

### Before (Manual Process)
1. Open ServiceNow change request
2. Copy GitHub run ID from description
3. Open GitHub in new tab
4. Navigate to repository
5. Click "Actions"
6. Find the specific workflow run
7. Scroll to artifacts section
8. Download each artifact individually
9. **Total time: ~5 minutes per change request**

### After (One-Click Access)
1. Open ServiceNow change request
2. Click artifact URL field
3. Download artifact
4. **Total time: ~30 seconds per change request**

**Time Savings**: **90% reduction** in time to access compliance evidence!

## Related Documentation

- [ServiceNow Custom Fields Setup](SERVICENOW-CUSTOM-FIELDS-SETUP.md) - How custom fields are created
- [GitHub Actions Artifacts Guide](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts) - GitHub's official docs
- [ServiceNow Change Management](https://docs.servicenow.com/bundle/tokyo-it-service-management/page/product/change-management/concept/c_ITILChangeManagement.html) - ServiceNow official docs

## Support

If you encounter issues accessing artifacts:

1. **Technical Issues**: Contact DevOps team via Slack #devops-support
2. **ServiceNow Issues**: Contact ServiceNow admin
3. **GitHub Access**: Request repository access via GitHub team settings

---

**Last Updated**: 2025-10-29  
**Created By**: GitHub Actions Integration  
**Maintained By**: DevOps Team
