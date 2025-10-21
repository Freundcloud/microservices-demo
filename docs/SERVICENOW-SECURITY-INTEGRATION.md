# ServiceNow Security Integration Guide

**Last Updated**: 2025-10-21
**Status**: ✅ Configured and Active

## Overview

This guide explains how security scan results from GitHub Actions flow to ServiceNow Velocity DevOps and appear in the Security tab of the GitHub tool.

## Architecture

```
GitHub Actions (MASTER-PIPELINE)
    ↓ (runs security scans)
    ├─ CodeQL (SAST - 5 languages)
    ├─ Trivy (Container Security)
    ├─ Semgrep (SAST)
    ├─ Checkov (IaC Security)
    ├─ tfsec (IaC Security)
    ├─ OWASP Dependency Check (SCA)
    └─ Polaris (Kubernetes Security)
    ↓ (generates SARIF files)
GitHub Security Tab (Code Scanning Alerts)
    ↓ (webhook trigger)
ServiceNow DevOps (/softwarequality endpoint)
    ↓ (processes security data)
Security Tab in GitHub Tool
```

## Configuration Details

### GitHub Webhook

**Webhook ID**: `576481667`
**URL**: `https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/softwarequality?toolId=2fe9c38bc36c72d0e1bbf0cb050131cc`
**Events Subscribed**:
- ✅ `code_scanning_alert` - CodeQL, Semgrep, and other SAST tools
- ✅ `dependabot_alert` - Dependency vulnerability alerts
- ✅ `secret_scanning_alert` - Secret detection alerts
- ✅ `secret_scanning_alert_location` - Location of detected secrets

**Status**: Active ✅

### ServiceNow Configuration

**Instance**: `calitiiltddemo3.service-now.com`
**Tool**: GitHub Demo
**Tool ID**: `2fe9c38bc36c72d0e1bbf0cb050131cc`
**Endpoint**: `/api/sn_devops/v2/devops/tool/softwarequality`

## Viewing Security Results in ServiceNow

### Navigation Path

**Method 1: Via DevOps UI**
1. Log into ServiceNow instance
2. Navigate to **DevOps** → **Change** → **Tools**
3. Find and click on **GitHub Demo**
4. Select the **Security** tab (6th tab)
5. View security scan summaries and findings

**Method 2: Direct URL**
```
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/2fe9c38bc36c72d0e1bbf0cb050131cc/params/selected-tab-index/6
```

### What You'll See

**Security Tab Contents**:
- Security scan summaries from each tool
- Finding counts (Critical, High, Medium, Low, Info)
- Scan status and timestamps
- Links to detailed GitHub Security results
- Historical trend data

## Security Scan Tools

| Tool | Type | Languages/Targets | Triggered By |
|------|------|------------------|--------------|
| **CodeQL** | SAST | Python, Java, JavaScript, C#, Go | Every push, PR |
| **Trivy** | Container Security | Docker images, filesystems | Image builds |
| **Semgrep** | SAST | Multi-language | Every push, PR |
| **Checkov** | IaC Security | Terraform, Kubernetes manifests | Terraform changes |
| **tfsec** | IaC Security | Terraform-specific | Terraform changes |
| **OWASP Dependency Check** | SCA | Dependencies (all languages) | Every push, PR |
| **Polaris** | Kubernetes Security | K8s manifests | Manifest changes |

## Integration Flow

### Step 1: GitHub Actions Runs Security Scans

When MASTER-PIPELINE workflow runs:
```yaml
jobs:
  security-scanning:
    uses: ./.github/workflows/security-scan.yaml
    # Runs all 7 security tools in parallel
```

### Step 2: SARIF Results Uploaded

Each tool uploads SARIF results to GitHub Security:
```yaml
- name: Upload CodeQL Results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: codeql-results.sarif
```

### Step 3: GitHub Triggers Webhook

When SARIF is uploaded, GitHub:
1. Creates/updates code scanning alerts
2. Triggers `code_scanning_alert` webhook event
3. Sends event data to ServiceNow endpoint

### Step 4: ServiceNow Processes Data

ServiceNow DevOps:
1. Receives webhook payload
2. Extracts security findings
3. Populates Security tab
4. Links findings to change requests

## Verification Steps

### Verify Webhook is Active

```bash
# Check webhook configuration
gh api repos/Freundcloud/microservices-demo/hooks/576481667 \
  --jq '{id: .id, active: .active, events: .events, url: .config.url}'
```

Expected output:
```json
{
  "id": 576481667,
  "active": true,
  "events": [
    "code_scanning_alert",
    "dependabot_alert",
    "secret_scanning_alert",
    "secret_scanning_alert_location"
  ],
  "url": "https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/softwarequality?toolId=2fe9c38bc36c72d0e1bbf0cb050131cc"
}
```

### Verify Security Scans Run

```bash
# Check latest workflow run
gh run list --workflow=MASTER-PIPELINE.yaml --limit 1

# View security scan job status
gh run view <RUN_ID> --log --job=security-scanning
```

### Verify SARIF Upload

1. Navigate to GitHub → **Security** → **Code scanning**
2. Check for recent alerts from each tool:
   - CodeQL alerts
   - Semgrep alerts
   - Trivy alerts
3. Verify timestamps match workflow run time

### Verify ServiceNow Received Data

**Check Webhook Deliveries**:
```bash
# View recent webhook deliveries
gh api repos/Freundcloud/microservices-demo/hooks/576481667/deliveries \
  --jq '.[] | {id: .id, event: .event, status: .status_code, delivered_at: .delivered_at}'
```

Expected: Recent deliveries with `status_code: 200`

## Troubleshooting

### Security Tab Empty

**Possible Causes**:
1. ❌ Security scans haven't run yet
2. ❌ SARIF files not uploaded to GitHub Security
3. ❌ Webhook not triggered
4. ❌ ServiceNow not processing webhook data

**Solutions**:
```bash
# 1. Trigger security scans manually
gh workflow run MASTER-PIPELINE.yaml

# 2. Check GitHub Security tab has alerts
# Navigate to: https://github.com/Freundcloud/microservices-demo/security/code-scanning

# 3. Check webhook deliveries
gh api repos/Freundcloud/microservices-demo/hooks/576481667/deliveries

# 4. Check ServiceNow logs
# Navigate to: DevOps → Change → Tools → GitHub Demo → Activity
```

### Webhook Delivery Failures

**Check webhook status**:
```bash
gh api repos/Freundcloud/microservices-demo/hooks/576481667/deliveries/LATEST_ID \
  --jq '{status: .status_code, response: .response}'
```

**Common Issues**:
- **403 Forbidden**: ServiceNow credentials invalid
- **404 Not Found**: Tool ID incorrect
- **500 Error**: ServiceNow processing error

**Fix**: Verify ServiceNow tool configuration and credentials

### No Security Alerts Generated

**Possible Causes**:
1. Code has no vulnerabilities (unlikely with 7 tools)
2. Scans failing silently
3. SARIF upload failing

**Check scan results**:
```bash
# View security scan logs
gh run view <RUN_ID> --log | grep -A 50 "Security Scanning"
```

## Manual Security Tool Registration

If you need to re-register security tools manually:

```bash
# Load credentials
source .envrc

# Run registration script
./scripts/register-servicenow-security-tools.sh
```

This is idempotent and safe to run multiple times.

## Integration with Change Management

Security findings automatically integrate with change requests:

1. **Change Request Created** (via servicenow-integration.yaml)
2. **Security Tab Checked** - ServiceNow verifies no critical/high findings
3. **Approval Required** - If critical findings exist, additional approval needed
4. **Change Deployed** - Only after security review

### Security Gates

**Automatic Gates**:
- ❌ **Block**: Critical severity findings
- ⚠️ **Warn**: High severity findings (requires approval)
- ✅ **Pass**: Medium/Low/Info findings

## Maintenance

### Regular Tasks

**Weekly**:
- Review security findings in ServiceNow
- Verify webhook deliveries are successful
- Check for new vulnerability types

**Monthly**:
- Audit security tool versions
- Review security scan coverage
- Update security policies if needed

### Updating Security Tools

When adding/removing security tools:

1. **Update MASTER-PIPELINE** workflow
2. **Re-run registration script**:
   ```bash
   ./scripts/register-servicenow-security-tools.sh
   ```
3. **Verify new tool appears** in ServiceNow Security tab

## References

- **Workflow**: `.github/workflows/MASTER-PIPELINE.yaml`
- **Security Scan**: `.github/workflows/security-scan.yaml`
- **Registration Script**: `scripts/register-servicenow-security-tools.sh`
- **ServiceNow API Docs**: [DevOps API Documentation](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/r-devops-api.html)

## Support

**Issues with security integration**:
1. Check this guide's troubleshooting section
2. Review `scripts/README.md` for registration details
3. Verify webhook deliveries in GitHub
4. Check ServiceNow DevOps logs

**Contact**:
- GitHub Repository: https://github.com/Freundcloud/microservices-demo
- ServiceNow Instance: https://calitiiltddemo3.service-now.com
