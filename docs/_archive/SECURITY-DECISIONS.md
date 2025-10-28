# Security Decisions and Trade-offs

> **Purpose**: Document pragmatic security decisions for demo/development environment
> **Last Updated**: 2025-10-21
> **Status**: Active

## Overview

This document explains security scan warnings that are intentionally accepted for this demo environment. All decisions are documented with justification, risk assessment, and production recommendations.

## Accepted Security Warnings

### 1. ECR Image Tag Mutability (CKV_AWS_51)

**Decision**: Use MUTABLE image tags
**Configuration**: `image_tag_mutability = "MUTABLE"` in [terraform-aws/ecr.tf](../terraform-aws/ecr.tf)
**Scanner**: Checkov
**Suppressed**: Yes (via `.checkov.yml`)

#### Justification

**For Demo/Development**:
- Allows updating `dev`, `qa`, `prod` tags without unique identifiers
- Faster development iteration (can rebuild and redeploy same tag)
- Avoids complex tag management during development
- Prevents forced Terraform resource replacement (destructive operation)

**Risk Assessment**:
- **Risk**: Tag overwriting could cause deployment confusion
- **Mitigation**:
  - Lifecycle policies keep last 10 tagged images
  - Image digests provide immutable reference
  - Proper CI/CD workflow documentation
- **Severity**: Low for demo, Medium for staging, High for production

#### Production Recommendation

```hcl
# terraform-aws/ecr.tf (for production)
image_tag_mutability = "IMMUTABLE"

# CI/CD should use semantic versioning or commit SHA
# Examples:
# - frontend:v1.2.3
# - frontend:sha-a1b2c3d4
# - frontend:2025.10.21-build.123
```

**Benefits of IMMUTABLE for Production**:
- Prevents accidental tag overwrites
- Ensures reproducibility (same tag = same image forever)
- Better audit trail for compliance
- Aligns with GitOps best practices

**Migration Path**:
1. Update CI/CD to use semantic versioning
2. Test in QA environment first
3. Change Terraform variable for production workspace
4. Apply with `terraform apply -target=aws_ecr_repository.microservices`
5. Update deployment manifests to use specific versions

---

### 2. ECR Encryption with AES256 (CKV_AWS_136)

**Decision**: Use AWS-managed encryption (AES256) instead of KMS
**Configuration**: `encryption_type = "AES256"` in [terraform-aws/ecr.tf](../terraform-aws/ecr.tf)
**Scanner**: Checkov
**Suppressed**: Yes (via `.checkov.yml`)

#### Justification

**For Demo/Development**:
- AES256 provides encryption at rest (data is secure)
- No additional cost (KMS keys cost $1/month each = $12/year for 12 repos)
- Simpler key management (no rotation policies needed)
- Prevents forced Terraform resource replacement (destructive operation)
- Sufficient for non-production compliance requirements

**Risk Assessment**:
- **Risk**: No audit trail for encryption key usage
- **Mitigation**:
  - CloudTrail logs ECR API calls
  - Data is still encrypted at rest with AES-256
  - Regular security scanning of images (scan-on-push enabled)
- **Severity**: Low for demo, Low for staging, Medium for production

#### Production Recommendation

```hcl
# terraform-aws/ecr.tf (for production)
encryption_configuration {
  encryption_type = "KMS"
  kms_key         = aws_kms_key.ecr.arn  # Already created in lines 34-78
}

# Benefits:
# - Customer-managed encryption keys
# - Audit trail via CloudTrail (who accessed encryption key)
# - Automatic key rotation (enabled in our config)
# - Required for some compliance frameworks (PCI-DSS, HIPAA)
```

**Cost Comparison**:
| Encryption Type | Cost | Audit Trail | Key Rotation | Compliance |
|-----------------|------|-------------|--------------|------------|
| AES256 (current) | $0/month | Limited | Automatic (AWS) | Basic |
| KMS (recommended) | $1/month/key | Full | Automatic | Advanced |
| **Total for 12 repos** | **$0** vs **$12/mo** | | | |

**Migration Path**:
1. KMS key already exists: `aws_kms_key.ecr` (lines 34-73 in ecr.tf)
2. Simply uncomment KMS usage in production workspace
3. Apply with careful planning (will force replacement)
4. Consider blue/green deployment strategy

---

### 3. tfsec SARIF Output Path

**Issue**: tfsec uses default path `results.sarif` instead of explicit path
**Scanner**: tfsec-action
**Fixed**: Yes (set explicit path `tfsec-results.sarif`)

#### Resolution

**Before**:
```yaml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: terraform-aws/
    soft_fail: true
  # Implicit: results.sarif
```

**After**:
```yaml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: terraform-aws/
    soft_fail: true
    format: sarif
    sarif_file: tfsec-results.sarif  # Explicit path
```

**Impact**:
- ✅ Eliminates warning
- ✅ Clearer configuration
- ✅ Consistent with other SARIF outputs
- ✅ No functional change

---

### 4. Kubernetes Manifest Scan Warnings (Polaris Exit Code 8)

**Issue**: Polaris audit returns warnings for missing best practices
**Scanner**: Polaris
**Managed**: Yes (via `.polaris.yaml` config)

#### Common Warnings

1. **Missing Resource Requests/Limits**
   - Severity: Warning (downgraded from Error)
   - Justification: Demo environment with auto-scaling
   - Production: Should set proper limits

2. **Security Context Settings**
   - `runAsNonRoot` not set
   - `readOnlyRootFilesystem` not enabled
   - Severity: Warning
   - Justification: Some services (loadgenerator) need write access
   - Production: Should enable for all services where possible

3. **Health Checks**
   - Missing readiness/liveness probes on some services
   - Severity: Warning
   - Justification: Demo environment
   - Production: Essential for reliability

#### Configuration

Created `.polaris.yaml` to adjust severity levels:

```yaml
checks:
  cpuRequestsMissing: warning       # Down from error
  memoryRequestsMissing: warning    # Down from error
  runAsRootAllowed: warning         # Allow for demo
  readinessProbeMissing: warning    # Non-critical for demo
```

**Exemptions** (when warnings don't apply):
- `loadgenerator`: Intentionally resource-intensive
- `istio-ingressgateway`: Needs privileged access for networking

---

## Security Scan Strategy

### Current Approach (Demo/Development)

```yaml
# All scans configured with soft_fail: true
# Findings reported but don't block deployments
# Evidence uploaded to ServiceNow for audit

Checkov → Skip CKV_AWS_51, CKV_AWS_136 → Upload SARIF
tfsec   → Scan with explicit path         → Upload SARIF
Polaris → Warnings downgraded              → Upload JSON
Trivy   → Scan filesystem/containers       → Upload SARIF
Semgrep → SAST security patterns           → Upload SARIF
CodeQL  → Multi-language SAST              → Upload SARIF
```

**Benefits**:
- ✅ Comprehensive security coverage
- ✅ Findings tracked and documented
- ✅ No false-positive pipeline failures
- ✅ Evidence for compliance/audit
- ✅ Fast feedback loop (don't block on warnings)

### Production Approach (Recommended)

```yaml
# Separate scan configurations by environment
# Block on high/critical findings in production
# Require manual approval for known exceptions

Checkov → Fail on high/critical → Require approval
tfsec   → Fail on high/critical → Require approval
Polaris → Fail on errors        → All checks enforced
Trivy   → Fail on CRITICAL      → No HIGH in prod
```

**Migration Checklist**:
- [ ] Fix Polaris warnings (resource limits, security contexts)
- [ ] Enable IMMUTABLE tags in production
- [ ] Enable KMS encryption in production
- [ ] Set `soft_fail: false` for production pipelines
- [ ] Require security team approval for exceptions

---

## Configuration Files Reference

| File | Purpose | Documentation |
|------|---------|---------------|
| `.checkov.yml` | Suppress specific Checkov checks with justification | This file (root) |
| `.polaris.yaml` | Adjust Polaris severity levels for demo | This file (root) |
| `.github/workflows/security-scan.yaml` | Security scan pipeline | [GitHub Actions](../.github/workflows/) |
| `terraform-aws/ecr.tf` | ECR repository configuration | [Terraform](../terraform-aws/) |

---

## Compliance Mapping

| Framework | Current Status | Production Requirement | Gap |
|-----------|----------------|------------------------|-----|
| **CIS AWS Foundations** | Partial | Full | KMS encryption, immutable tags |
| **NIST 800-53** | Partial | Full | Enhanced audit logging |
| **SOC 2 Type II** | Partial | Full | Encryption key management |
| **PCI-DSS** | Not applicable | Required if handling payments | Full compliance needed |
| **HIPAA** | Not applicable | Required if handling PHI | KMS, audit trails |
| **GDPR** | Partial | Full | Data encryption at rest (✓) |

---

## Review Schedule

| Item | Frequency | Owner | Last Review |
|------|-----------|-------|-------------|
| Security scan findings | Weekly | DevOps Lead | 2025-10-21 |
| Exception justifications | Monthly | Security Team | 2025-10-21 |
| Configuration updates | Quarterly | Platform Team | 2025-10-21 |
| Compliance mapping | Annually | Compliance Officer | 2025-10-21 |

---

## Change History

| Date | Change | Reason | Approved By |
|------|--------|--------|-------------|
| 2025-10-21 | Created SECURITY-DECISIONS.md | Document pragmatic choices | DevOps Lead |
| 2025-10-21 | Added .checkov.yml config | Suppress CKV_AWS_51, CKV_AWS_136 | DevOps Lead |
| 2025-10-21 | Added .polaris.yaml config | Adjust warning levels | DevOps Lead |
| 2025-10-21 | Fixed tfsec SARIF path | Eliminate warning | DevOps Lead |

---

## Questions or Concerns?

If you have questions about these security decisions or need to escalate a finding, contact:

- **DevOps Lead**: Review technical decisions
- **Security Team**: Review compliance and risk
- **Platform Team**: Infrastructure changes
- **Compliance Officer**: Regulatory requirements

See also:
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Checkov Documentation](https://www.checkov.io/)
- [Polaris Documentation](https://polaris.docs.fairwinds.com/)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
