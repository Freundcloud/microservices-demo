# ServiceNow Security Scan Integration

**Last Updated**: 2025-10-14

This document describes how to integrate security scan results from GitHub Actions into ServiceNow DevOps.

---

## Overview

The security scanning workflow automatically sends scan results from multiple security tools to ServiceNow DevOps for centralized security management and compliance tracking.

### Integrated Security Tools

| Scanner | Purpose | ServiceNow Job |
|---------|---------|----------------|
| **CodeQL** | Multi-language semantic code analysis | `servicenow-codeql-results` |
| **Semgrep** | Static application security testing (SAST) | `servicenow-semgrep-results` |
| **Trivy** | Vulnerability and misconfiguration scanning | `servicenow-trivy-results` |
| **Checkov** | Infrastructure as Code (IaC) security | `servicenow-iac-results` |
| **OWASP Dependency Check** | Dependency vulnerability scanning | `servicenow-owasp-results` |

---

## Prerequisites

### 1. ServiceNow Instance Setup

Before configuring GitHub Actions, you need:

1. **ServiceNow DevOps License** - Active subscription to ServiceNow DevOps
2. **ServiceNow Instance URL** - Your organization's ServiceNow instance (e.g., `https://your-org.service-now.com`)
3. **DevOps Integration User** - Service account with appropriate permissions
4. **Security Tools Onboarded** - Each security scanner must be registered in ServiceNow

### 2. ServiceNow DevOps Configuration

#### Create Integration User

1. Navigate to **User Administration** > **Users** in ServiceNow
2. Create a new user with:
   - **Username**: `devops-integration` (or your preferred name)
   - **Role**: `sn_devops.integration_user` (minimum required)
   - **Additional Roles** (recommended):
     - `security_admin` - For security scan management
     - `devops.user` - For DevOps operations
3. Set a strong password and note it for GitHub Secrets

#### Register GitHub as Orchestration Tool

1. Navigate to **DevOps** > **Orchestration Tools**
2. Click **New**
3. Fill in:
   - **Name**: GitHub Actions
   - **Type**: GitHub
   - **URL**: `https://github.com/Freundcloud/microservices-demo`
4. Note the **sys_id** (Tool ID) for GitHub Secrets

#### Onboard Security Scanners

For each security tool, create a security scanner record:

1. Navigate to **DevOps** > **Security** > **Scanners**
2. Click **New** for each scanner:

**CodeQL Scanner**:
- **Name**: CodeQL
- **Type**: SAST
- **Vendor**: GitHub
- **Version**: Latest
- Note the **sys_id** as `SN_CODEQL_TOOL_ID`

**Semgrep Scanner**:
- **Name**: Semgrep
- **Type**: SAST
- **Vendor**: r2c
- **Version**: Latest
- Note the **sys_id** as `SN_SEMGREP_TOOL_ID`

**Trivy Scanner**:
- **Name**: Trivy
- **Type**: Container Scanning
- **Vendor**: Aqua Security
- **Version**: Latest
- Note the **sys_id** as `SN_TRIVY_TOOL_ID`

**Checkov Scanner**:
- **Name**: Checkov
- **Type**: IaC Scanning
- **Vendor**: Bridgecrew
- **Version**: Latest
- Note the **sys_id** as `SN_CHECKOV_TOOL_ID`

**OWASP Dependency Check Scanner**:
- **Name**: OWASP Dependency Check
- **Type**: SCA (Software Composition Analysis)
- **Vendor**: OWASP
- **Version**: Latest
- Note the **sys_id** as `SN_OWASP_TOOL_ID`

---

## GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

### Navigate to GitHub Secrets

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**

### Required Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SN_DEVOPS_USER` | ServiceNow integration username | `devops-integration` |
| `SN_DEVOPS_PASSWORD` | ServiceNow integration password | `your-secure-password` |
| `SN_INSTANCE_URL` | ServiceNow instance URL | `https://your-org.service-now.com` |
| `SN_ORCHESTRATION_TOOL_ID` | GitHub orchestration tool sys_id | `abc123def456...` |
| `SN_CODEQL_TOOL_ID` | CodeQL scanner sys_id | `def456ghi789...` |
| `SN_SEMGREP_TOOL_ID` | Semgrep scanner sys_id | `ghi789jkl012...` |
| `SN_TRIVY_TOOL_ID` | Trivy scanner sys_id | `jkl012mno345...` |
| `SN_CHECKOV_TOOL_ID` | Checkov scanner sys_id | `mno345pqr678...` |
| `SN_OWASP_TOOL_ID` | OWASP Dependency Check sys_id | `pqr678stu901...` |

### Setting Secrets via GitHub CLI

```bash
# ServiceNow connection details
gh secret set SN_DEVOPS_USER --body "devops-integration"
gh secret set SN_DEVOPS_PASSWORD --body "your-secure-password"
gh secret set SN_INSTANCE_URL --body "https://your-org.service-now.com"

# Orchestration tool ID
gh secret set SN_ORCHESTRATION_TOOL_ID --body "abc123def456..."

# Security scanner tool IDs
gh secret set SN_CODEQL_TOOL_ID --body "def456ghi789..."
gh secret set SN_SEMGREP_TOOL_ID --body "ghi789jkl012..."
gh secret set SN_TRIVY_TOOL_ID --body "jkl012mno345..."
gh secret set SN_CHECKOV_TOOL_ID --body "mno345pqr678..."
gh secret set SN_OWASP_TOOL_ID --body "pqr678stu901..."
```

---

## Workflow Architecture

### Security Scan Flow

```
┌─────────────────┐
│ Security Scans  │
│ (5 jobs run in  │
│  parallel)      │
└────────┬────────┘
         │
         ├─── CodeQL Analysis ────────┐
         │                            │
         ├─── Semgrep SAST ───────────┤
         │                            │
         ├─── Trivy Filesystem ───────┤
         │                            │
         ├─── IaC Scanning ───────────┤
         │                            │
         └─── OWASP Dep Check ────────┤
                                      │
                                      ▼
         ┌─────────────────────────────────┐
         │ ServiceNow Integration Jobs     │
         │ (Send results to ServiceNow)    │
         └─────────────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────────────┐
         │ ServiceNow DevOps Platform      │
         │ - Centralized dashboard         │
         │ - Compliance tracking           │
         │ - Vulnerability management      │
         │ - Security gate policies        │
         └─────────────────────────────────┘
```

### Job Dependencies

Each ServiceNow integration job depends on its corresponding security scan:

```yaml
servicenow-codeql-results:
  needs: codeql-analysis
  if: always()  # Run even if security scan fails
```

The `if: always()` condition ensures results are sent to ServiceNow regardless of whether vulnerabilities are found.

---

## Implementation Details

### ServiceNow Action Configuration

Each security scanner has a dedicated ServiceNow integration job:

```yaml
servicenow-<scanner>-results:
  name: ServiceNow <Scanner> Results
  needs: <scanner-job>
  if: always()
  runs-on: ubuntu-latest

  steps:
    - name: ServiceNow DevOps Security Results - <Scanner>
      uses: ServiceNow/servicenow-devops-security-result@v3.0.0
      with:
        devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
        devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
        instance-url: ${{ secrets.SN_INSTANCE_URL }}
        tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
        context-github: ${{ toJSON(github) }}
        job-name: 'ServiceNow <Scanner> Results'
        security-result-attributes: '{"scanner": "<Scanner Name>", "securityToolId": "${{ secrets.SN_<SCANNER>_TOOL_ID }}"}'
```

### Key Parameters

- **`devops-integration-user-name`** - ServiceNow integration user
- **`devops-integration-user-password`** - Integration user password
- **`instance-url`** - ServiceNow instance URL
- **`tool-id`** - GitHub orchestration tool sys_id
- **`context-github`** - Full GitHub context (automatically populated)
- **`job-name`** - Display name in ServiceNow
- **`security-result-attributes`** - JSON with scanner name and tool ID

---

## Verification and Testing

### Test the Integration

1. **Trigger a Security Scan**:
   ```bash
   # Push a commit to main branch
   git commit --allow-empty -m "test: Trigger security scan"
   git push origin main
   ```

2. **Monitor GitHub Actions**:
   ```bash
   gh run watch
   ```

3. **Check ServiceNow**:
   - Navigate to **DevOps** > **Security Results**
   - Filter by **Source**: GitHub Actions
   - Verify results appear for each scanner

### Verify Each Scanner

| Scanner | GitHub Job | ServiceNow Location |
|---------|------------|---------------------|
| CodeQL | `servicenow-codeql-results` | Security Results > CodeQL |
| Semgrep | `servicenow-semgrep-results` | Security Results > Semgrep |
| Trivy | `servicenow-trivy-results` | Security Results > Trivy |
| Checkov | `servicenow-iac-results` | Security Results > Checkov |
| OWASP | `servicenow-owasp-results` | Security Results > OWASP |

---

## Troubleshooting

### Common Issues

#### 1. Authentication Failed

**Error**: `401 Unauthorized` or `Invalid credentials`

**Solution**:
- Verify `SN_DEVOPS_USER` and `SN_DEVOPS_PASSWORD` secrets
- Check user has `sn_devops.integration_user` role in ServiceNow
- Ensure password hasn't expired

#### 2. Tool ID Not Found

**Error**: `Tool ID not found` or `Invalid tool-id`

**Solution**:
- Verify `SN_ORCHESTRATION_TOOL_ID` matches the sys_id in ServiceNow
- Check orchestration tool is active in ServiceNow
- Navigate to **DevOps** > **Orchestration Tools** to confirm

#### 3. Scanner Not Recognized

**Error**: `Security tool not found` or `Invalid securityToolId`

**Solution**:
- Verify scanner is onboarded in ServiceNow
- Check `SN_<SCANNER>_TOOL_ID` secret matches scanner sys_id
- Ensure scanner record is active

#### 4. Results Not Appearing

**Symptoms**: Job succeeds but no results in ServiceNow

**Solution**:
- Check ServiceNow logs: **System Logs** > **Application Logs**
- Verify scanner name matches exactly in both GitHub and ServiceNow
- Ensure GitHub context is being passed correctly
- Check ServiceNow integration user permissions

### Debug Mode

Enable debug logging in GitHub Actions:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add repository secret:
   - Name: `ACTIONS_STEP_DEBUG`
   - Value: `true`

This will show detailed logs for ServiceNow API calls.

---

## Security Best Practices

### Credential Management

1. **Rotate Passwords Regularly**: Change ServiceNow integration password every 90 days
2. **Use Service Accounts**: Never use personal ServiceNow accounts for integration
3. **Minimum Permissions**: Grant only required roles to integration user
4. **Audit Access**: Review integration user access logs monthly

### Network Security

1. **IP Allowlisting** (Optional): Restrict ServiceNow API access to GitHub Actions IP ranges
2. **TLS/SSL**: Always use HTTPS for `SN_INSTANCE_URL`
3. **Certificate Validation**: Ensure valid SSL certificates on ServiceNow instance

### Data Privacy

1. **Sensitive Data**: Security scan results may contain sensitive information
2. **Access Control**: Restrict access to ServiceNow security results
3. **Retention Policy**: Configure data retention in ServiceNow

---

## Advanced Configuration

### Custom Security Gates

Configure security gates in ServiceNow to automatically block deployments based on scan results:

1. Navigate to **DevOps** > **Security Gates**
2. Create new gate:
   - **Name**: High Severity Vulnerability Block
   - **Condition**: Critical vulnerabilities > 0
   - **Action**: Block deployment
   - **Notification**: Email security team

### Compliance Reporting

Generate compliance reports in ServiceNow:

1. Navigate to **DevOps** > **Reports**
2. Create custom report:
   - **Type**: Security Scan Summary
   - **Time Range**: Last 30 days
   - **Scanners**: All
   - **Export**: PDF, CSV

### Webhook Integration

For real-time notifications, configure webhooks:

1. Navigate to **System Web Services** > **Outbound** > **REST Message**
2. Create webhook for critical vulnerabilities
3. Configure notification endpoint (Slack, PagerDuty, etc.)

---

## Workflow File Reference

The ServiceNow integration is implemented in [`.github/workflows/security-scan.yaml`](.github/workflows/security-scan.yaml).

### Jobs Added

- `servicenow-codeql-results` - Line 288
- `servicenow-semgrep-results` - Line 306
- `servicenow-trivy-results` - Line 324
- `servicenow-iac-results` - Line 342
- `servicenow-owasp-results` - Line 360

---

## Support and Resources

### Documentation

- [ServiceNow DevOps Documentation](https://docs.servicenow.com/bundle/tokyo-devops/page/product/enterprise-dev-ops/reference/devops-landing-page.html)
- [ServiceNow GitHub Action](https://github.com/ServiceNow/servicenow-devops-security-result)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### Contact

- **ServiceNow Support**: support@servicenow.com
- **GitHub Issues**: File issues in this repository
- **Security Team**: security@your-org.com

---

**Integration Status**: ✅ Configured and ready to use after secrets are set

**Next Steps**:
1. ✅ Configure ServiceNow instance (see Prerequisites)
2. ✅ Add GitHub Secrets (see Configuration)
3. ✅ Test integration (see Verification)
4. ⚠️ Monitor results in ServiceNow dashboard
