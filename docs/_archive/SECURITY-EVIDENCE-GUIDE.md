# Security Scan Evidence Generation Guide

## Overview

This guide explains how the automated security scanning pipeline generates comprehensive evidence for ServiceNow change request approvals. The system **always generates evidence**, whether scans pass or fail, providing auditable proof of security validation.

## Problem Solved

**Before:** No proof when scans were clean → Reviewers couldn't verify scans ran → Approval delays

**After:** Always-on evidence generation → Clear compliance certificates → Faster approvals with full audit trail

## Architecture

### Evidence Generation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Deploy with ServiceNow Workflow (Triggered by user)         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Run Security Scans (Reusable workflow)                       │
│     ├── CodeQL (5 languages)                                     │
│     ├── Semgrep SAST                                             │
│     ├── Trivy Filesystem                                         │
│     ├── Checkov + tfsec (IaC)                                    │
│     ├── Kubesec + Polaris (K8s)                                  │
│     └── OWASP Dependency Check                                   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Generate Evidence Report (ALWAYS, pass or fail)              │
│     ├── Analyze SARIF results                                    │
│     ├── Count HIGH/CRITICAL findings                             │
│     ├── Generate compliance certificate (Markdown)               │
│     ├── Determine PASSED/FAILED status                           │
│     └── Upload as workflow artifact                              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Create ServiceNow Change Request                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Upload Evidence to ServiceNow (ALWAYS)                       │
│     ├── Download security-scan-evidence artifact                 │
│     ├── Upload evidence report (Markdown)                        │
│     ├── Upload all SARIF files                                   │
│     ├── Upload K8s audit results                                 │
│     └── Add comprehensive work note                              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. Wait for Approval (QA/Prod only)                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  7. Deploy Application                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Evidence Documents Generated

### 1. Security Scan Evidence Report (Markdown)

**Filename:** `security-scan-evidence-{run_number}.md`

**Contents:**
- **Executive Summary**: PASSED/FAILED status, total findings count
- **Compliance Statement**: Proof that all required scans executed
- **Scan Details**: Tool versions, severity filters, results per scan
- **Approval Recommendation**: Clear guidance for reviewers
- **Links**: Direct links to GitHub Security tab, full logs

**Example (Clean Scan):**
```markdown
# 🔒 Security Scan Evidence Report

**Scan Date**: 2025-10-20 14:30:00 UTC
**Repository**: Calitti/ARC/microservices-demo
**Branch**: main
**Commit**: 639a4ae7

---

## 📊 Overall Status

**Result**: PASSED
**Total Findings**: 0 (HIGH/CRITICAL severity)

✅ **COMPLIANCE STATUS**: All security scans passed - No high/critical vulnerabilities detected

---

## 🛡️ Security Scans Executed

### 1. CodeQL Analysis (Multi-Language SAST)
- **Status**: success
- **Result**: ✅ PASSED - No high-severity code vulnerabilities

### 2. Semgrep SAST
- **Findings**: 0 issues
- **Result**: ✅ CLEAN - No security issues detected

### 3. Trivy Filesystem Scan
- **Findings**: 0 vulnerabilities
- **Result**: ✅ CLEAN - No vulnerabilities detected

...

---

## 📋 Compliance Statement

**Deployment Recommendation**: ✅ **APPROVED** - All security scans passed, safe to proceed with deployment
```

### 2. SARIF Result Files

**Files:**
- `semgrep-results.sarif` - SAST findings
- `trivy-fs-results.sarif` - Vulnerability scan
- `checkov-results.sarif` - IaC security
- `tfsec-results.sarif` - Terraform security
- `dependency-check-report.sarif` - Dependency vulnerabilities

**Purpose:** Machine-readable scan results for detailed analysis

### 3. Kubernetes Audit Results

**Filename:** `polaris-results.json`

**Contents:** Security and best practices audit of Kubernetes manifests

## ServiceNow Integration

### Work Note Added

Every deployment triggers a work note with:

```
🔒 Security Scan Evidence Uploaded

Overall Status: PASSED
Findings (HIGH/CRITICAL): 0

Security Scans Executed:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ CodeQL Analysis (Python, JavaScript, Go, Java, C#)
✓ Semgrep SAST (Static Application Security Testing)
✓ Trivy Filesystem Scan (Vulnerability & misconfiguration)
✓ Checkov + tfsec (Infrastructure as Code security)
✓ Kubesec + Polaris (Kubernetes manifest security)
✓ OWASP Dependency Check (Known CVEs in dependencies)

✅ APPROVAL RECOMMENDATION: All security scans passed
   Safe to proceed with deployment to prod

Evidence Documents Attached:
- security-scan-evidence-123.md (Executive Summary)
- *.sarif files (Detailed scan results in SARIF format)
- polaris-results.json (Kubernetes security audit)

Links:
- Full Scan Logs: https://github.com/.../actions/runs/...
- Security Alerts: https://github.com/.../security
- Code Scanning: https://github.com/.../security/code-scanning

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Evidence Uploaded: 2025-10-20 14:30:15 UTC
Pipeline Version: v1.0.0 - GitHub Actions Automated Security
```

### Attachments in ServiceNow

All evidence files are attached to the change request:

1. **Security Scan Evidence Report** (Markdown) - Primary compliance document
2. **SARIF Files** (5+ files) - Detailed technical results
3. **Polaris Results** (JSON) - Kubernetes audit data

## Usage

### Trigger a Deployment with Evidence

```bash
# Via GitHub Actions UI
Actions → Deploy with ServiceNow (Basic API) → Run workflow → Select environment

# Via GitHub CLI
gh workflow run deploy-with-servicenow-basic.yaml \
  -f environment=prod
```

### View Evidence in ServiceNow

1. Navigate to change request (e.g., CHG0123456)
2. Scroll to **Attachments** section
3. Download `security-scan-evidence-{run_number}.md`
4. Review compliance statement and approval recommendation
5. (Optional) Review SARIF files for detailed findings

### View Evidence in GitHub

1. Go to Actions tab → Select workflow run
2. Scroll to **Artifacts** section
3. Download `security-scan-evidence` artifact
4. Extract and review Markdown report

## Benefits

### For Approvers

✅ **Proof of Execution**: Timestamped evidence that scans ran
✅ **Clear Status**: PASSED/FAILED with finding counts
✅ **Compliance Certificate**: Documented proof for audits
✅ **Fast Decision**: Approval recommendation at top of report
✅ **Drill-Down**: Links to detailed results if needed

### For Developers

✅ **No Manual Work**: Evidence generated automatically
✅ **Faster Approvals**: No delays waiting for proof
✅ **Transparency**: Always know what was scanned
✅ **Audit Trail**: Historical record of all scans

### For Security Teams

✅ **Regulatory Compliance**: Meets evidence requirements
✅ **Trend Analysis**: Track findings over time
✅ **Tool Verification**: Proof that security gates are active
✅ **Incident Response**: Historical scan data for investigations

## Compliance Features

### Evidence Retention

- **GitHub Artifacts**: 90 days retention
- **ServiceNow Attachments**: Permanent (attached to change request)

### Audit Trail

Every evidence report includes:
- Exact commit SHA
- Timestamp (UTC)
- Triggered by (user)
- GitHub Actions run ID
- Link to full logs

### Regulatory Alignment

Meets requirements for:
- **SOC 2**: Automated security testing documentation
- **ISO 27001**: Security control evidence
- **PCI DSS**: Vulnerability scanning proof
- **NIST CSF**: Security assessment records

## Troubleshooting

### Evidence Not Uploaded

**Symptom:** No attachments in ServiceNow change request

**Causes & Solutions:**

1. **Security scans failed to run**
   - Check: GitHub Actions → Security Scanning workflow
   - Fix: Review scan errors, ensure all tools installed

2. **Artifact not created**
   - Check: GitHub Actions → Deploy workflow → Artifacts section
   - Fix: Ensure `security-summary` job completed successfully

3. **ServiceNow API error**
   - Check: Deploy workflow logs → "Upload Security Evidence" job
   - Fix: Verify ServiceNow credentials, check API permissions

### Work Note Missing

**Symptom:** Attachments present but no work note

**Possible Causes:**
- ServiceNow API timeout (rare)
- Invalid work_notes field permissions

**Resolution:**
- Work note step has retry logic (3 attempts)
- Evidence files still uploaded even if work note fails
- Manually add note if needed (rare)

### Wrong Status in Report

**Symptom:** Report shows PASSED but findings exist

**Cause:** Evidence analyzes SARIF results for HIGH/CRITICAL only

**Expected Behavior:**
- LOW/MEDIUM findings don't affect PASSED status
- Only HIGH/CRITICAL findings trigger FAILED

### Missing SARIF Files

**Symptom:** Evidence report exists but no SARIF attachments

**Causes:**
- Some scans may have been skipped (e.g., language-specific)
- Scan produced no SARIF output (unusual)

**Normal Scenarios:**
- Not all services use all languages → Some CodeQL scans skip
- Polaris only runs if K8s manifests exist

## Advanced Configuration

### Customize Evidence Report

Edit [`.github/workflows/security-scan.yaml`](../.github/workflows/security-scan.yaml):

```yaml
# Line ~338: Evidence report template
cat > security-scan-evidence.md <<EOF
# 🔒 Security Scan Evidence Report
...
EOF
```

### Change Retention Period

Edit artifact retention:

```yaml
# security-scan.yaml, line ~482
retention-days: 90  # Change to desired days (1-90)
```

### Add Custom Scans

1. Add new scan job to `security-scan.yaml`
2. Output SARIF format
3. Evidence generator will automatically include it

### Disable Evidence Upload

To run scans without ServiceNow integration:

```yaml
# deploy-with-servicenow-basic.yaml
# Comment out the upload-security-evidence job
```

## Examples

### Clean Scan (Production Deployment)

**Evidence Summary:**
```
Status: PASSED
Findings: 0
Recommendation: ✅ APPROVED
```

**ServiceNow Action:** Approve immediately

---

### Vulnerabilities Detected (Staging Deployment)

**Evidence Summary:**
```
Status: FAILED
Findings: 3 HIGH, 1 CRITICAL
Recommendation: ⚠️ REVIEW REQUIRED
```

**ServiceNow Action:** Review SARIF files → Fix vulnerabilities → Re-run deployment

---

### Mixed Results (Dev Deployment)

**Evidence Summary:**
```
Status: PASSED (HIGH/CRITICAL only)
Findings: 0 HIGH/CRITICAL, 12 MEDIUM
Recommendation: ✅ APPROVED (with caution)
```

**ServiceNow Action:** Approve for dev, create backlog items for MEDIUM findings

## Related Documentation

- [ServiceNow Integration Guide](./GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [Security Scanning Workflow](../.github/workflows/security-scan.yaml)
- [Deployment Workflow](../.github/workflows/deploy-with-servicenow-basic.yaml)
- [GitHub Security Tab](https://github.com/Calitti/ARC/microservices-demo/security)

## Support

### Questions

- Check [GitHub Discussions](https://github.com/Calitti/ARC/microservices-demo/discussions)
- Review workflow run logs
- Contact security team

### Issues

- [Report workflow issues](https://github.com/Calitti/ARC/microservices-demo/issues)
- Include: Run ID, Change Request number, Screenshots

---

**Last Updated:** 2025-10-20
**Version:** 1.0.0
**Maintainer:** DevSecOps Team
