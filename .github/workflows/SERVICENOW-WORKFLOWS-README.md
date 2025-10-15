# ServiceNow Integration Workflows

This directory contains GitHub Actions workflows that integrate with ServiceNow for automated change management, security vulnerability tracking, and infrastructure discovery.

## Overview

Three new workflows have been added to enable full ServiceNow DevOps integration:

1. **`security-scan-servicenow.yaml`** - Security scanning with ServiceNow vulnerability tracking
2. **`deploy-with-servicenow.yaml`** - Deployment automation with change management
3. **`eks-discovery.yaml`** - EKS cluster and microservices discovery for CMDB

## Prerequisites

### Required GitHub Secrets

Before using these workflows, configure the following secrets in your GitHub repository:

| Secret Name | Description | How to Obtain |
|------------|-------------|---------------|
| `SN_DEVOPS_INTEGRATION_TOKEN` | ServiceNow DevOps integration token | Generated in ServiceNow: DevOps > Configuration > Integration Tokens |
| `SN_INSTANCE_URL` | Your ServiceNow instance URL | Your ServiceNow URL (e.g., `https://yourcompany.service-now.com`) |
| `SN_ORCHESTRATION_TOOL_ID` | GitHub tool ID from ServiceNow | From ServiceNow: DevOps > Configuration > Tool Configuration (GitHub entry) |
| `SN_OAUTH_TOKEN` | OAuth token for CMDB API access | Generated in ServiceNow: System OAuth > Application Registry |
| `AWS_ACCESS_KEY_ID` | AWS access key (existing) | AWS IAM Console |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key (existing) | AWS IAM Console |

### ServiceNow Configuration Required

1. **DevOps Plugin** installed and activated
2. **AWS Service Management Connector** installed (for CMDB)
3. **CMDB CI Classes** created:
   - `u_eks_cluster` - For EKS cluster information
   - `u_microservice` - For microservice deployments
4. **Security Tool Mappings** configured for:
   - Trivy (container scanning)
   - CodeQL (SAST)
   - Checkov (IaC security)
   - Semgrep (pattern analysis)
5. **Approval Workflows** configured for dev/qa/prod environments

## Workflows

### 1. Security Scan with ServiceNow (`security-scan-servicenow.yaml`)

**Purpose**: Runs comprehensive security scans and uploads results to ServiceNow Vulnerability Response.

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Schedule: Daily at 2 AM UTC
- Manual trigger via `workflow_dispatch`

**Security Scanners**:
- **CodeQL**: Multi-language SAST (Python, JavaScript, Go, Java, C#)
- **Semgrep**: Pattern-based security analysis
- **Trivy**: Filesystem and dependency vulnerabilities
- **Checkov**: Infrastructure as Code security
- **tfsec**: Terraform security scanning
- **Kubesec & Polaris**: Kubernetes manifest security
- **OWASP Dependency Check**: Known vulnerable dependencies

**ServiceNow Integration**:
- Uploads SARIF results to ServiceNow DevOps Security
- Creates vulnerability records with severity mapping
- Blocks deployments if critical vulnerabilities found
- Tracks remediation status

**Usage**:
```bash
# Automatic: Runs on every push/PR
# Manual trigger:
gh workflow run security-scan-servicenow.yaml
```

**View Results**:
- GitHub: Security tab
- ServiceNow: DevOps > Security > Security Results

---

### 2. Deploy with ServiceNow Change Management (`deploy-with-servicenow.yaml`)

**Purpose**: Deploys microservices to EKS with ServiceNow change management and environment-specific approval workflows.

**Triggers**:
- Manual only (workflow_dispatch)

**Parameters**:
- `environment`: Choose dev, qa, or prod
- `change_request_id`: Optional existing change request ID

**Workflow Steps**:
1. **Create Change Request**: Automatically creates ServiceNow change request
2. **Wait for Approval** (qa/prod only):
   - Dev: Auto-approved
   - QA: Requires QA Lead approval
   - Prod: Requires Change Advisory Board approval
3. **Pre-Deployment Checks**: Validates cluster access and namespaces
4. **Deploy**: Uses Kustomize to deploy to selected environment
5. **Health Check**: Verifies all pods are running
6. **Smoke Tests**: Tests application endpoints
7. **Update CMDB**: Registers deployed services in ServiceNow
8. **Close Change Request**: Updates change with success/failure status

**On Failure**:
- Automatic rollback to previous version
- Change request updated with failure details
- Team notified via ServiceNow

**Usage**:
```bash
# Via GitHub Actions UI
1. Go to Actions tab
2. Select "Deploy with ServiceNow Change Management"
3. Click "Run workflow"
4. Select environment (dev/qa/prod)
5. Click "Run workflow"

# Via GitHub CLI
gh workflow run deploy-with-servicenow.yaml \
  -f environment=dev

gh workflow run deploy-with-servicenow.yaml \
  -f environment=qa

gh workflow run deploy-with-servicenow.yaml \
  -f environment=prod
```

**Approval Process**:

| Environment | Approval Required | Approvers | Typical Time |
|-------------|-------------------|-----------|--------------|
| Dev | ❌ Auto-approved | None | Immediate |
| QA | ✅ Manual approval | QA Lead | < 2 hours |
| Prod | ✅ CAB approval | Change Manager, App Owner, Security Team | < 24 hours |

**View Status**:
- GitHub: Actions tab > Workflow run
- ServiceNow: Change Management > My Changes

---

### 3. EKS Discovery to ServiceNow CMDB (`eks-discovery.yaml`)

**Purpose**: Automatically discovers EKS cluster and microservices, updating ServiceNow CMDB for infrastructure visibility.

**Triggers**:
- Schedule: Every 6 hours
- Push to Kustomize/manifest files
- Manual trigger via `workflow_dispatch`

**What It Discovers**:
- **EKS Cluster**:
  - Cluster name, ARN, version, endpoint
  - VPC ID, region, status
  - Node groups and instance types
- **Microservices** (across all namespaces):
  - Service name, namespace, environment
  - Replica counts (desired vs ready)
  - Container images and tags
  - Health status

**ServiceNow CMDB Updates**:
- Creates/updates `u_eks_cluster` CI
- Creates/updates `u_microservice` CIs
- Maintains relationships between services and cluster
- Timestamps for tracking staleness

**Usage**:
```bash
# Automatic: Runs every 6 hours
# Manual trigger:
gh workflow run eks-discovery.yaml
```

**View Results**:
- GitHub: Actions tab > Workflow artifacts
- ServiceNow: Configuration > CMDB > EKS Clusters

---

## Environment-Specific Workflows

### Dev Environment

**Purpose**: Rapid iteration and testing

**Characteristics**:
- Auto-approved deployments
- Minimal approval overhead
- Lower resource allocation (1 replica per service)
- Includes load generator for testing

**Workflow**:
```
Code Push → Security Scan → Change Request (Auto) → Deploy → CMDB Update
```

### QA Environment

**Purpose**: Testing and validation before production

**Characteristics**:
- Manual approval from QA Lead
- Moderate resources (2 replicas per service)
- Includes load generator for performance testing
- Full observability stack

**Workflow**:
```
Manual Trigger → Change Request → QA Lead Approval → Deploy → Testing → CMDB Update
```

### Prod Environment

**Purpose**: Production-ready deployments

**Characteristics**:
- Strict CAB approval (3 approvers)
- High availability (3 replicas per service)
- No load generator
- Full monitoring and alerting

**Workflow**:
```
Manual Trigger → Change Request → CAB Approval (3) → Deploy → Smoke Tests → CMDB Update
```

---

## Integration Flow Diagram

```
┌─────────────────┐
│  Developer      │
│  Commits Code   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  GitHub Actions                 │
│  ┌──────────────────────────┐  │
│  │  Security Scan Workflow  │  │
│  │  - CodeQL, Trivy, etc.   │  │
│  └──────────┬───────────────┘  │
└─────────────┼───────────────────┘
              │
              ▼
     ┌────────────────────┐
     │  ServiceNow        │
     │  Security Results  │
     └────────────────────┘
              │
              ▼
     {Critical Vulns?}
         │        │
         │ No     │ Yes
         ▼        └──> Block Deployment
┌─────────────────────────────────┐
│  Deploy Workflow (Manual)       │
│  ┌──────────────────────────┐  │
│  │  Create Change Request   │  │
│  └──────────┬───────────────┘  │
└─────────────┼───────────────────┘
              │
              ▼
     ┌────────────────────┐
     │  ServiceNow        │
     │  Change Management │
     └────────┬───────────┘
              │
              ▼
     {Environment?}
     ┌────┼────┐
  Dev│   QA│  Prod│
     │    │     │
  Auto│  QA│    CAB│
 Approve│Lead│ Approval│
     │    │     │
     └────┼────┘
          │
          ▼
┌─────────────────────────────────┐
│  Deploy to EKS                  │
│  - Apply Kustomize              │
│  - Health checks                │
│  - Smoke tests                  │
└──────────┬──────────────────────┘
           │
           ▼
     ┌────────────────────┐
     │  ServiceNow CMDB   │
     │  Update Services   │
     └────────────────────┘
           │
           ▼
     ┌────────────────────┐
     │  EKS Discovery     │
     │  (Every 6 hours)   │
     └────────────────────┘
```

---

## Monitoring and Dashboards

### GitHub Actions

**View Workflow Runs**:
```
https://github.com/your-org/microservices-demo/actions
```

**Monitor**:
- Workflow success/failure rates
- Execution times
- Security scan results
- Deployment status per environment

### ServiceNow

**Security Dashboard**:
```
DevOps > Security > Security Results
```
- Vulnerability trends
- Open findings by severity
- Remediation status

**Change Management Dashboard**:
```
Change Management > My Changes
```
- Active change requests
- Approval status
- Deployment history

**CMDB Dashboard**:
```
Configuration > CMDB > Dashboards
```
- EKS cluster health
- Microservices inventory
- Configuration drift

---

## Troubleshooting

For comprehensive troubleshooting information, see **[SERVICENOW-TROUBLESHOOTING.md](/docs/SERVICENOW-TROUBLESHOOTING.md)**.

The troubleshooting guide covers:
- Internal Server Error (500) diagnosis and solutions
- Authentication error fixes
- Change request creation failures
- CMDB update issues
- Security scan upload problems
- Debugging tips and techniques
- Common error messages reference
- Quick verification checklist

### Quick Troubleshooting

#### 1. ServiceNow Integration Token Invalid

**Symptom**: Workflow fails with authentication error

**Solution**:
```bash
# Verify token in GitHub Secrets
# Regenerate token in ServiceNow
1. DevOps > Configuration > Integration Tokens
2. Generate New Token
3. Update GitHub Secret: SN_DEVOPS_INTEGRATION_TOKEN
```

#### 2. Change Request Not Created (Internal Server Error)

**Symptom**: Deploy workflow fails with "Internal server error"

**Common Causes**:
- ServiceNow DevOps plugin not installed
- GitHub tool not configured in ServiceNow
- Invalid assignment group or other field values
- Missing mandatory fields

**Quick Fix**: See [SERVICENOW-TROUBLESHOOTING.md](/docs/SERVICENOW-TROUBLESHOOTING.md#internal-server-error-500)

#### 3. CMDB Updates Failing

**Symptom**: Discovery workflow completes but CMDB not updated

**Check**:
- ServiceNow instance URL correct in secrets
- Tool ID matches GitHub configuration in ServiceNow
- Integration user has proper roles

**Verify**:
```bash
# Test ServiceNow API access
curl -X GET "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer $SN_DEVOPS_INTEGRATION_TOKEN"
```

#### 3. CMDB Not Updating

**Symptom**: Discovery workflow completes but CMDB unchanged

**Check**:
- `SN_OAUTH_TOKEN` secret configured
- CMDB CI classes created (`u_eks_cluster`, `u_microservice`)
- OAuth token has table write permissions

**Verify**:
```bash
# Test CMDB API access
curl -X GET "$SN_INSTANCE_URL/api/now/table/u_eks_cluster" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN"
```

#### 4. Approval Workflow Stuck

**Symptom**: QA/Prod deployment waiting indefinitely

**Check**:
- Assignment groups configured in ServiceNow
- Approvers have correct permissions
- Notification emails being sent
- Timeout not exceeded (1 hour default)

**Manual Override**:
```
1. Go to ServiceNow: Change Management
2. Find change request
3. Manually approve as admin
4. Workflow will proceed
```

#### 5. Security Scan Results Not Appearing

**Symptom**: Scans complete but not in ServiceNow

**Check**:
- Security tool mappings configured
- Tool IDs match (trivy, codeql, checkov, semgrep)
- SARIF format valid

**Debug**:
```bash
# Check SARIF file format
cat trivy-fs-results.sarif | jq '.'

# Verify ServiceNow security tool config
# ServiceNow > DevOps > Security > Tool Configuration
```

---

## Best Practices

### Security Scans

1. **Run on Every PR**: Catch vulnerabilities early
2. **Review Results**: Don't ignore warnings
3. **Fix Critical Issues**: Block deployment until resolved
4. **Track Remediation**: Use ServiceNow vulnerability workflow

### Change Management

1. **Dev Deployments**: Auto-approve for speed
2. **QA Testing**: Require approval after security checks
3. **Prod Releases**: Full CAB approval with documented testing
4. **Change Windows**: Schedule prod deployments during maintenance windows

### CMDB Discovery

1. **Regular Discovery**: Every 6 hours keeps data fresh
2. **Manual Triggers**: After major infrastructure changes
3. **Verify Accuracy**: Periodically audit CMDB vs actual state
4. **Use for Incident Management**: Link incidents to affected services

---

## Getting Help

### Documentation

- **Complete Setup Guide**: [docs/SERVICENOW-INTEGRATION-PLAN.md](../../docs/SERVICENOW-INTEGRATION-PLAN.md)
- **Quick Start**: [docs/SERVICENOW-INTEGRATION-SUMMARY.md](../../docs/SERVICENOW-INTEGRATION-SUMMARY.md)
- **Architecture Diagrams**: [docs/SERVICENOW-ARCHITECTURE-DIAGRAM.md](../../docs/SERVICENOW-ARCHITECTURE-DIAGRAM.md)
- **Setup Checklist**: [docs/SERVICENOW-SETUP-CHECKLIST.md](../../docs/SERVICENOW-SETUP-CHECKLIST.md)

### Support

- **ServiceNow Issues**: Contact your ServiceNow admin
- **GitHub Actions Issues**: Check workflow logs and GitHub Actions status
- **AWS/EKS Issues**: Verify AWS credentials and cluster access

---

**Last Updated**: 2025-10-15
**Maintained By**: DevOps Team
