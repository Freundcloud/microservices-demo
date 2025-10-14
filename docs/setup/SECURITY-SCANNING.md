# Security Scanning Guide

This document explains the comprehensive security scanning setup for the Online Boutique microservices application.

## 🛡️ Overview

We implement **multiple layers of security scanning** throughout the CI/CD pipeline to ensure secure code, containers, and infrastructure.

### Security Scanning Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Source Code Layer                        │
│  • CodeQL (Multi-language SAST)                             │
│  • Semgrep (Pattern-based SAST)                             │
│  • Gitleaks (Secret detection)                              │
│  • OWASP Dependency Check                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Container Image Layer                     │
│  • Trivy (Vulnerability scanning)                           │
│  • SBOM Generation                                          │
│  • ECR Automatic Scanning                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  • Checkov (Terraform scanning)                             │
│  • tfsec (Terraform security)                               │
│  • Polaris (K8s best practices)                             │
│  • Kubesec (K8s security)                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Security Tools

### 1. CodeQL Analysis

**Purpose**: Semantic code analysis for vulnerabilities

**Languages Supported**:
- Python (emailservice, recommendationservice, loadgenerator)
- JavaScript/Node.js (currencyservice, paymentservice)
- Go (frontend, productcatalogservice, shippingservice, checkoutservice)
- Java (adservice)
- C# (cartservice)

**What it detects**:
- SQL injection
- Cross-site scripting (XSS)
- Command injection
- Path traversal
- Insecure deserialization
- And 200+ security patterns

**Configuration**: `.github/workflows/security-scan.yaml`

**View results**: GitHub Security tab → Code scanning alerts

---

### 2. Trivy Vulnerability Scanner

**Purpose**: Container and filesystem vulnerability scanning

**What it scans**:
- OS packages (Alpine, Debian, Ubuntu, etc.)
- Application dependencies (npm, pip, go modules, etc.)
- Known CVEs
- Misconfigurations

**Severity levels**:
- CRITICAL (blocks deployment)
- HIGH (blocks deployment)
- MEDIUM (warning)
- LOW (informational)

**Scan triggers**:
- Every Docker image build
- Pull requests
- Push to main branch
- ECR automatic scanning on push

---

### 3. Gitleaks Secret Scanning

**Purpose**: Detect accidentally committed secrets

**What it finds**:
- AWS keys
- API tokens
- Private keys
- Passwords
- Generic secrets patterns

**Scan scope**:
- Current code
- Git history
- Pull requests

---

### 4. Semgrep SAST

**Purpose**: Pattern-based static analysis

**What it detects**:
- Security anti-patterns
- Code quality issues
- Best practice violations
- Language-specific vulnerabilities

**Rules**: Uses `auto` config (community + security rules)

---

### 5. Infrastructure Scanning

#### Checkov (Terraform)
- Scans Terraform for misconfigurations
- Checks against CIS benchmarks
- Validates security best practices

#### tfsec (Terraform)
- Specialized Terraform security scanner
- Checks for AWS-specific issues
- Validates encryption, access controls

#### Polaris (Kubernetes)
- Kubernetes best practices
- Resource limits validation
- Security policies

#### Kubesec (Kubernetes)
- Security risk analysis
- Pod security standards
- RBAC validation

---

### 6. OWASP Dependency Check

**Purpose**: Identify known vulnerable dependencies

**What it checks**:
- CVE database
- NPM advisories
- PyPI advisories
- Maven Central

---

## 🚀 Usage

### Automatic Scanning

Security scans run automatically on:

#### Pull Requests
```bash
# When you create a PR, the following scans run:
✓ CodeQL analysis
✓ Dependency review
✓ Secret scanning
✓ Semgrep SAST
✓ Trivy filesystem
✓ IaC scanning
```

#### Push to Main
```bash
# When code is merged, additional scans run:
✓ All PR scans
✓ Container image scanning
✓ SBOM generation
✓ ECR vulnerability scanning
```

#### Scheduled Scans
```bash
# Daily at 2 AM UTC:
✓ Full security scan suite
✓ Dependency updates check
```

### Manual Scanning

Trigger security scans manually:

1. Go to **Actions** tab
2. Select **"Security Scanning"** workflow
3. Click **"Run workflow"**
4. Click **"Run workflow"** button

---

## 📊 Viewing Results

### GitHub Security Tab

All scan results are centralized in the **Security** tab:

```
Repository → Security Tab:
  ├── Code scanning alerts (CodeQL, Semgrep, Trivy)
  ├── Secret scanning alerts (Gitleaks)
  ├── Dependabot alerts (Dependencies)
  └── Security advisories
```

### Workflow Summaries

Each workflow run creates a summary:

1. Go to **Actions** tab
2. Click on workflow run
3. Scroll to **Summary** section
4. View security scan results

### ECR Scan Results

View container scan results in AWS:

```bash
# List scan findings for a repository
aws ecr describe-image-scan-findings \
  --repository-name frontend \
  --image-id imageTag=latest \
  --region eu-west-2
```

Or in AWS Console:
```
ECR → Repositories → Select service → Images → View scan results
```

---

## 🔧 Configuration

### Required GitHub Secrets

Add these to your repository secrets:

| Secret | Required | Description |
|--------|----------|-------------|
| `AWS_ACCESS_KEY_ID` | ✅ | AWS credentials for ECR |
| `AWS_SECRET_ACCESS_KEY` | ✅ | AWS credentials for ECR |
| `AWS_ACCOUNT_ID` | ✅ | Your AWS account ID |
| `GITLEAKS_LICENSE` | ❌ | Optional Pro license |

### Enable GitHub Features

1. **Enable Dependabot**:
   - Settings → Security → Dependabot
   - Enable "Dependabot alerts"
   - Enable "Dependabot security updates"

2. **Enable Code Scanning**:
   - Settings → Security → Code security and analysis
   - Enable "Code scanning"

3. **Enable Secret Scanning**:
   - Settings → Security → Code security and analysis
   - Enable "Secret scanning"

---

## 🚨 Handling Security Alerts

### Critical/High Vulnerabilities

When a CRITICAL or HIGH vulnerability is found:

1. **Review the alert** in GitHub Security tab
2. **Assess the impact**:
   - Is the vulnerable code/package used?
   - Is it exposed to user input?
   - What's the attack vector?
3. **Take action**:
   - Update dependencies
   - Apply patches
   - Implement workarounds
   - Add compensating controls
4. **Re-scan** to verify fix

### False Positives

If an alert is a false positive:

1. **Document the reason** (comment on alert)
2. **Dismiss the alert** in GitHub Security tab
3. **Add exception** to scanner config if needed

### Secrets Detection

If a secret is detected:

1. **Rotate the secret immediately**
2. **Remove from Git history**:
   ```bash
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch path/to/secret' \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** (if safe)
4. **Update in all environments**

---

## 📈 Security Metrics

### Key Metrics to Track

- **Vulnerability Count**: Track over time
- **Mean Time to Remediate** (MTTR): How fast you fix issues
- **Scan Coverage**: % of code scanned
- **False Positive Rate**: Quality of alerts

### Reporting

Generate security reports:

```bash
# Export CodeQL results
gh api repos/{owner}/{repo}/code-scanning/alerts \
  --jq '.[] | select(.state=="open")' > security-report.json

# Export dependency alerts
gh api repos/{owner}/{repo}/dependabot/alerts > dependabot-report.json
```

---

## 🎯 Best Practices

### 1. Fix Issues Quickly
- Address CRITICAL within 24 hours
- Address HIGH within 7 days
- Address MEDIUM within 30 days

### 2. Keep Dependencies Updated
- Enable Dependabot auto-updates
- Review and merge security PRs promptly
- Test updates in staging first

### 3. Regular Scanning
- Don't disable scheduled scans
- Run ad-hoc scans before releases
- Scan both code and containers

### 4. Security Training
- Review security alerts as a team
- Share learnings from vulnerabilities
- Stay updated on security trends

### 5. Defense in Depth
- Multiple scanning tools
- Different detection methods
- Scan at multiple stages

---

## 🛠️ Customization

### Adjust Severity Thresholds

Edit `.github/workflows/build-and-push-images.yaml`:

```yaml
# Change Trivy severity
severity: 'CRITICAL,HIGH'  # Add or remove levels
exit-code: '1'             # Fail build on vulnerabilities
```

### Add Custom Rules

Create `.semgrep.yml`:

```yaml
rules:
  - id: custom-security-rule
    pattern: dangerous_function(...)
    message: "Don't use dangerous_function"
    severity: ERROR
    languages: [python]
```

### Exclude Paths

Edit `.github/workflows/security-scan.yaml`:

```yaml
paths-ignore:
  - 'docs/**'
  - 'test/**'
  - '*.md'
```

---

## 🆘 Troubleshooting

### Scan Failures

**Problem**: CodeQL analysis fails

**Solution**:
- Check if language is supported
- Verify build succeeds
- Review CodeQL logs in workflow

**Problem**: Trivy scan times out

**Solution**:
- Increase timeout in workflow
- Check image size
- Verify network connectivity

### High False Positive Rate

**Solution**:
- Tune scanner configurations
- Add suppressions for known safe patterns
- Use more specific rules

### ECR Scan Not Running

**Solution**:
- Verify `scan_on_push = true` in Terraform
- Check ECR permissions
- Ensure images are pushed successfully

---

## 📚 Additional Resources

- [GitHub Code Scanning](https://docs.github.com/en/code-security/code-scanning)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS ECR Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)

---

## ✅ Security Checklist

- [ ] All GitHub security features enabled
- [ ] AWS secrets configured in GitHub
- [ ] Security workflow running successfully
- [ ] Code scanning alerts reviewed
- [ ] Dependabot enabled and configured
- [ ] ECR repositories created with scanning
- [ ] Team trained on alert handling
- [ ] Escalation process defined
- [ ] Regular security reviews scheduled

---

**🔐 Security is everyone's responsibility!**

Review the Security tab regularly and address alerts promptly.
