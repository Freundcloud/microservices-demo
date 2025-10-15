# ServiceNow Integration - Executive Summary

## Overview

This document summarizes the key changes needed to integrate GitHub Actions with ServiceNow for automated change management, security scanning, and AWS EKS infrastructure discovery.

## What This Integration Enables

### 1. Automated Change Management
- **Dev Environment**: Auto-approved deployments for rapid iteration
- **QA Environment**: Manual approval required from QA team
- **Prod Environment**: Strict approval from Change Advisory Board (CAB)
- All deployments tracked in ServiceNow with full audit trail

### 2. Security Scan Integration
- Automatically send results from 5 security tools to ServiceNow:
  - **Trivy**: Container vulnerability scanning
  - **CodeQL**: Static application security testing (SAST)
  - **Checkov**: Infrastructure as Code (IaC) security
  - **Gitleaks**: Secret detection
  - **Semgrep**: Pattern-based SAST
- Block deployments if critical vulnerabilities detected
- Track vulnerability remediation in ServiceNow

### 3. AWS Infrastructure Discovery
- Automatically discover and register EKS cluster in ServiceNow CMDB
- Track all 12 microservices across dev/qa/prod environments
- Update CMDB every 6 hours with current state
- Link deployments to CMDB configuration items

## Key Changes Required

### 1. ServiceNow Configuration

**New Components to Install:**
- ServiceNow DevOps plugin
- AWS Service Management Connector

**New Service Accounts:**
- GitHub integration user with DevOps permissions
- API tokens for GitHub Actions

**New CMDB CI Classes:**
- `AWS EKS Cluster` - Stores cluster information
- `Microservice` - Stores service deployment details

**Approval Workflows:**
- Dev: Auto-approval workflow (no manual intervention)
- QA: QA Lead approval required
- Prod: Change Advisory Board approval required

### 2. GitHub Repository Changes

**New Workflow Files to Create:**

1. **`.github/workflows/security-scan-servicenow.yaml`**
   - Runs all 5 security scanners
   - Converts results to ServiceNow format
   - Uploads to ServiceNow DevOps Security module
   - Blocks deployment if critical vulnerabilities found

2. **`.github/workflows/deploy-with-servicenow.yaml`**
   - Creates ServiceNow change request
   - Waits for approval (qa/prod only)
   - Deploys to EKS using Kustomize
   - Updates change request with results
   - Rolls back on failure
   - Updates CMDB with deployment info

3. **`.github/workflows/eks-discovery.yaml`**
   - Discovers EKS cluster details
   - Scans all namespaces for microservices
   - Updates ServiceNow CMDB
   - Runs every 6 hours automatically

**New GitHub Secrets Required:**
```bash
SN_DEVOPS_INTEGRATION_TOKEN  # DevOps integration token from ServiceNow
SN_INSTANCE_URL              # Your ServiceNow instance URL
SN_ORCHESTRATION_TOOL_ID     # GitHub tool ID from ServiceNow
SN_OAUTH_TOKEN               # OAuth token for CMDB API access
```

### 3. Workflow Integration Points

**Current State:**
```
Code Push → Build → Test → Deploy
```

**Future State:**
```
Code Push → Build → Security Scan → ServiceNow Change Request →
Approval Gate → Deploy → Update CMDB → Close Change Request
```

## Deployment Workflow Changes

### Dev Environment (Auto-Approved)

**Before:**
```bash
just k8s-deploy dev
# Or: kubectl apply -k kustomize/overlays/dev
```

**After:**
```bash
# Via GitHub Actions UI
1. Go to Actions tab
2. Select "Deploy with ServiceNow Change Management"
3. Click "Run workflow"
4. Select environment: dev
5. Click "Run workflow"

# Workflow automatically:
- Creates ServiceNow change request
- Auto-approves for dev
- Runs security checks
- Deploys to dev namespace
- Updates CMDB
- Closes change request
```

### QA Environment (Manual Approval)

**After:**
```bash
# Via GitHub Actions UI
1. Run workflow for qa environment
2. GitHub Actions creates change request
3. QA Lead receives notification in ServiceNow
4. QA Lead reviews and approves in ServiceNow
5. Deployment proceeds automatically
6. CMDB updated
```

### Prod Environment (CAB Approval)

**After:**
```bash
# Via GitHub Actions UI
1. Run workflow for prod environment
2. GitHub Actions creates change request
3. Change Manager, App Owner, Security Team notified
4. All approvals required in ServiceNow
5. Once approved, deployment proceeds
6. Full audit trail maintained
```

## Benefits

### 1. Compliance & Governance
- ✅ Full audit trail of all changes
- ✅ Approval workflows enforce governance
- ✅ Change requests linked to CMDB items
- ✅ Rollback procedures documented

### 2. Security
- ✅ Automated vulnerability detection
- ✅ Block deployments with critical issues
- ✅ Track remediation status
- ✅ Security gates before production

### 3. Visibility
- ✅ Real-time infrastructure inventory
- ✅ Deployment dashboards in ServiceNow
- ✅ Service dependency mapping
- ✅ Historical change data

### 4. Automation
- ✅ Auto-approve dev deployments
- ✅ Automated CMDB updates
- ✅ Automatic rollback on failure
- ✅ Scheduled infrastructure discovery

## Implementation Timeline

| Week | Phase | Activities | Outcome |
|------|-------|------------|---------|
| 1 | ServiceNow Setup | Install plugins, configure integrations | ServiceNow ready |
| 2 | Security Integration | Update scan workflows, test submissions | Security results in ServiceNow |
| 3 | Change Management | Create deployment workflows, configure approvals | Change automation working |
| 3 | EKS Discovery | Set up CMDB, create discovery workflow | Infrastructure tracked |
| 4 | Testing & Launch | End-to-end testing, team training | Production ready |

**Total Duration**: 4 weeks

## Quick Start Guide

### For ServiceNow Administrators

1. **Install Plugins** (Day 1)
   ```
   System Applications → All Available Applications → All
   Search: "DevOps" and "AWS Service Management"
   Install both plugins
   ```

2. **Create Integration User** (Day 1)
   ```
   User Administration → Users → New
   Username: github_integration
   Assign roles: devops_user, api_access
   Generate integration token: DevOps → Configuration → Integration Tokens
   ```

3. **Configure GitHub Integration** (Day 2)
   ```
   DevOps → Configuration → Tool Configuration → New
   Type: GitHub
   URL: https://github.com/your-org/microservices-demo
   Test connection
   Copy Tool ID for GitHub
   ```

4. **Create CMDB Classes** (Day 2)
   ```
   Configuration → CI Class Manager
   Create: AWS EKS Cluster (extends cmdb_ci_cluster)
   Create: Microservice (extends cmdb_ci_service)
   ```

5. **Set Up Approval Workflows** (Day 3)
   ```
   Workflow → Workflow Editor
   Create: Dev Auto Approval
   Create: QA Manual Approval
   Create: Prod CAB Approval
   ```

### For GitHub Repository Administrators

1. **Add Secrets** (Day 1)
   ```
   GitHub Settings → Secrets and variables → Actions
   Add: SN_DEVOPS_INTEGRATION_TOKEN
   Add: SN_INSTANCE_URL
   Add: SN_ORCHESTRATION_TOOL_ID
   Add: SN_OAUTH_TOKEN
   ```

2. **Create Security Scan Workflow** (Day 2-3)
   ```
   Copy from: docs/SERVICENOW-INTEGRATION-PLAN.md (Phase 2.2)
   File: .github/workflows/security-scan-servicenow.yaml
   Test: Push to trigger workflow
   Verify: Results appear in ServiceNow
   ```

3. **Create Deployment Workflow** (Day 4-5)
   ```
   Copy from: docs/SERVICENOW-INTEGRATION-PLAN.md (Phase 3.1)
   File: .github/workflows/deploy-with-servicenow.yaml
   Test: Deploy to dev
   Verify: Change request created and auto-approved
   ```

4. **Create Discovery Workflow** (Day 6-7)
   ```
   Copy from: docs/SERVICENOW-INTEGRATION-PLAN.md (Phase 4.2)
   File: .github/workflows/eks-discovery.yaml
   Test: Run manually
   Verify: Cluster and services in CMDB
   ```

### For Development Team

**New Deployment Process:**

1. **Development Phase**
   ```bash
   # Continue normal development
   git checkout -b feature/new-feature
   # Make changes
   git commit -m "Add new feature"
   git push origin feature/new-feature
   # Create PR (security scans run automatically)
   ```

2. **Deploy to Dev**
   ```
   GitHub → Actions → Deploy with ServiceNow → Run workflow
   Environment: dev
   (Auto-approved, deploys immediately)
   ```

3. **Deploy to QA**
   ```
   GitHub → Actions → Deploy with ServiceNow → Run workflow
   Environment: qa
   Wait for QA Lead approval in ServiceNow
   (Deployment proceeds after approval)
   ```

4. **Deploy to Prod**
   ```
   GitHub → Actions → Deploy with ServiceNow → Run workflow
   Environment: prod
   Wait for CAB approval in ServiceNow
   (Deployment proceeds after all approvals)
   ```

## Monitoring and Dashboards

### ServiceNow Dashboards

**1. Deployment Dashboard**
- Deployments by environment (last 30 days)
- Change success/failure rate
- Average approval time
- Current deployment status

**2. Security Dashboard**
- Vulnerabilities by severity
- Open security findings
- Mean time to remediate
- Security scan trends

**3. CMDB Dashboard**
- EKS cluster health
- Microservices by environment
- Service dependencies
- Configuration drift

### GitHub Actions

**Monitoring:**
- Workflow run history
- Success/failure rates
- Average execution time
- Security scan results

**Notifications:**
- Slack/Teams integration for failures
- Email notifications for approvals
- Status checks on PRs

## Troubleshooting

### Common Issues

**1. Change Request Not Created**
```bash
# Check ServiceNow connectivity
curl -X GET "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer $SN_DEVOPS_INTEGRATION_TOKEN"

# Verify: Should return HTTP 200 with user data
```

**2. Security Scans Not Appearing**
```bash
# Check security tool mapping
ServiceNow → DevOps → Security → Tool Configuration
# Verify tool IDs match: trivy, codeql, checkov, gitleaks, semgrep
```

**3. CMDB Not Updating**
```bash
# Check AWS credentials
aws eks describe-cluster --name microservices --region eu-west-2

# Check kubectl access
kubectl cluster-info

# Verify ServiceNow CMDB API access
curl -X GET "$SN_INSTANCE_URL/api/now/table/u_eks_cluster" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN"
```

**4. Approval Workflow Stuck**
```bash
# Check in ServiceNow:
1. Change Management → My Approvals
2. Verify approver has correct permissions
3. Check notification settings
4. Review workflow conditions
```

## Cost Considerations

**ServiceNow Licensing:**
- DevOps plugin: Included in DevOps Edition
- AWS Service Management: Additional license may be required
- Estimated: $100-500/month (depends on ServiceNow plan)

**AWS Costs:**
- No additional AWS costs (using existing resources)
- EKS API calls: Minimal impact

**GitHub Actions:**
- Workflow minutes: ~500-1000 min/month additional
- Estimated: $8-16/month (depends on plan)

**Total Additional Cost: ~$108-516/month**

## Security Considerations

**Credentials Management:**
- ✅ All credentials stored in GitHub Secrets
- ✅ OAuth tokens preferred over basic auth
- ✅ Token rotation every 90 days
- ✅ Least privilege principle applied

**Network Security:**
- ✅ HTTPS/TLS for all API calls
- ✅ ServiceNow IP whitelisting recommended
- ✅ VPC endpoints for AWS resources
- ✅ Security Groups properly configured

**Data Protection:**
- ✅ No PII in change requests
- ✅ Sensitive data redacted from logs
- ✅ Audit logs maintained
- ✅ Compliance with data retention policies

## Success Metrics

**Deployment Metrics:**
- Deployment frequency: 10+ per week (target)
- Lead time: <1 hour dev, <4 hours prod (target)
- Change failure rate: <5% (target)
- MTTR: <30 minutes (target)

**Security Metrics:**
- Security scans: 100% of deployments
- Critical vulnerabilities blocked: 100%
- Mean time to remediate: <7 days (target)
- False positive rate: <10% (target)

**Approval Metrics:**
- Dev auto-approval: 100%
- QA approval time: <2 hours (target)
- Prod approval time: <24 hours (target)
- Rejection rate: <5% (target)

## Next Steps

### Immediate Actions (This Week)

1. **Review Plan**
   - Share with stakeholders
   - Get buy-in from team
   - Identify ServiceNow admin

2. **Access Setup**
   - Obtain ServiceNow instance access
   - Verify licensing requirements
   - Prepare AWS/GitHub credentials

3. **Schedule Kickoff**
   - Set up weekly check-ins
   - Assign responsibilities
   - Create project timeline

### Phase 1 Start (Next Week)

1. **ServiceNow Setup**
   - Install plugins
   - Create service accounts
   - Configure integrations

2. **GitHub Configuration**
   - Add secrets
   - Create test workflows
   - Validate connectivity

## Resources

### Documentation
- **Complete Plan**: [SERVICENOW-INTEGRATION-PLAN.md](SERVICENOW-INTEGRATION-PLAN.md)
- **ServiceNow Docs**: https://docs.servicenow.com/devops
- **GitHub Actions**: https://docs.github.com/actions

### Support
- **ServiceNow Support**: Via ServiceNow portal
- **GitHub Support**: support@github.com
- **AWS Support**: Via AWS console

### Training
- **ServiceNow DevOps**: Online courses available
- **GitHub Actions**: GitHub Learning Lab
- **AWS EKS**: AWS Training and Certification

## Questions?

For questions or clarification on this integration plan, please contact:
- **DevOps Team**: devops@yourcompany.com
- **ServiceNow Admin**: servicenow-admin@yourcompany.com
- **Security Team**: security@yourcompany.com
