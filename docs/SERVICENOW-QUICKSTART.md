# ServiceNow Integration - Quick Start Guide

> **Status**: Ready to Use
> **Prerequisites**: GitHub Secrets configured, ServiceNow access available
> **Time to First Deployment**: ~5 minutes

## What We've Built

You now have three new GitHub Actions workflows that integrate with ServiceNow:

1. **Security Scanning** → Sends vulnerability data to ServiceNow
2. **Deployment Automation** → Creates change requests and deploys with approval workflows
3. **Infrastructure Discovery** → Keeps ServiceNow CMDB updated with your EKS cluster

## Quick Start: Your First ServiceNow Deployment

### Step 1: Verify GitHub Secrets (1 minute)

Check that these secrets are configured:

```bash
# In your GitHub repository:
# Settings → Secrets and variables → Actions

✅ SN_DEVOPS_INTEGRATION_TOKEN    # ServiceNow DevOps token
✅ SN_INSTANCE_URL                # Your ServiceNow URL
✅ SN_ORCHESTRATION_TOOL_ID       # GitHub tool ID from ServiceNow
✅ SN_OAUTH_TOKEN                 # For CMDB updates (optional)
✅ AWS_ACCESS_KEY_ID              # Already configured
✅ AWS_SECRET_ACCESS_KEY          # Already configured
```

### Step 2: Run Security Scan (5 minutes)

The security scan workflow runs automatically, but you can trigger it manually:

```bash
# Via GitHub CLI
gh workflow run security-scan-servicenow.yaml

# Or via GitHub UI:
# 1. Go to Actions tab
# 2. Select "Security Scanning with ServiceNow Integration"
# 3. Click "Run workflow"
# 4. Click "Run workflow" button
```

**What happens**:
- Runs 5 security scanners (CodeQL, Trivy, Checkov, Semgrep, etc.)
- Uploads results to GitHub Security tab
- Sends results to ServiceNow DevOps Security module
- Creates vulnerability records in ServiceNow

**View Results**:
- **GitHub**: Repository → Security tab
- **ServiceNow**: DevOps → Security → Security Results

### Step 3: Deploy to Dev Environment (5 minutes)

Deploy to dev with auto-approval:

```bash
# Via GitHub CLI
gh workflow run deploy-with-servicenow.yaml -f environment=dev

# Or via GitHub UI:
# 1. Go to Actions tab
# 2. Select "Deploy with ServiceNow Change Management"
# 3. Click "Run workflow"
# 4. Select environment: "dev"
# 5. Click "Run workflow" button
```

**What happens**:
1. Creates ServiceNow change request
2. Auto-approves (dev environment)
3. Deploys to `microservices-dev` namespace
4. Verifies pod health
5. Runs smoke tests
6. Updates ServiceNow CMDB
7. Closes change request

**Monitor Progress**:
- **GitHub**: Actions tab → Workflow run
- **ServiceNow**: Change Management → My Changes

### Step 4: View Infrastructure in ServiceNow (Auto)

The discovery workflow runs automatically every 6 hours, or trigger manually:

```bash
# Via GitHub CLI
gh workflow run eks-discovery.yaml

# Or via GitHub UI:
# 1. Go to Actions tab
# 2. Select "EKS Cluster Discovery to ServiceNow"
# 3. Click "Run workflow"
```

**View in ServiceNow**:
- **EKS Cluster**: Configuration → CMDB → EKS Clusters
- **Microservices**: Configuration → CMDB → Microservices

---

## Deployment Workflows by Environment

### Dev Environment (Auto-Approved)

**Use For**: Development testing, rapid iteration

**Command**:
```bash
gh workflow run deploy-with-servicenow.yaml -f environment=dev
```

**Approval**: ✅ **Automatic** (no waiting)

**Timeline**:
- Create change request: ~30 seconds
- Deploy: ~2-3 minutes
- Total: ~3-4 minutes

---

### QA Environment (Manual Approval Required)

**Use For**: Testing before production, QA validation

**Command**:
```bash
gh workflow run deploy-with-servicenow.yaml -f environment=qa
```

**Approval**: ⏳ **QA Lead approval required**

**Timeline**:
- Create change request: ~30 seconds
- Wait for approval: Up to 2 hours
- Deploy: ~2-3 minutes
- Total: ~2-4 hours (depends on approval time)

**Approval Process**:
1. Workflow creates change request
2. QA Lead receives ServiceNow notification
3. QA Lead reviews and approves in ServiceNow
4. Deployment proceeds automatically

---

### Prod Environment (CAB Approval Required)

**Use For**: Production releases

**Command**:
```bash
gh workflow run deploy-with-servicenow.yaml -f environment=prod
```

**Approval**: 🔒 **Change Advisory Board (3 approvers)**

**Required Approvals**:
- Change Manager
- Application Owner
- Security Team

**Timeline**:
- Create change request: ~30 seconds
- Wait for all approvals: Up to 24 hours
- Deploy: ~3-4 minutes
- Total: ~24 hours (depends on approval time)

**Approval Process**:
1. Workflow creates change request
2. All three approvers receive notifications
3. Each approver reviews independently
4. All must approve before deployment proceeds
5. Deployment happens automatically after all approvals

---

## Viewing Results

### GitHub Actions

**Workflow Runs**:
```
https://github.com/your-org/microservices-demo/actions
```

**What to Check**:
- ✅ Green checkmark = Success
- ❌ Red X = Failed (check logs)
- 🟡 Yellow dot = In progress
- ⏸️ Paused = Waiting for approval

**Logs**:
```
Click on workflow run → Click on job name → View logs
```

### ServiceNow Dashboards

**Security Results**:
```
URL: {Your ServiceNow URL}/nav_to.do?uri=sn_devops_security_result_list.do

What you'll see:
- List of all security scans
- Vulnerability counts by severity
- Scan timestamps
- GitHub repository links
```

**Change Requests**:
```
URL: {Your ServiceNow URL}/nav_to.do?uri=change_request_list.do

What you'll see:
- All change requests
- Status (Draft, Approved, Implementing, Closed)
- Environment (dev/qa/prod)
- Approval history
```

**CMDB - EKS Cluster**:
```
URL: {Your ServiceNow URL}/nav_to.do?uri=u_eks_cluster_list.do

What you'll see:
- Cluster name, version, status
- ARN, endpoint, VPC
- Last discovery timestamp
```

**CMDB - Microservices**:
```
URL: {Your ServiceNow URL}/nav_to.do?uri=u_microservice_list.do

What you'll see:
- All deployed microservices
- Environment, namespace
- Replica counts
- Container images
- Health status
```

---

## Common Scenarios

### Scenario 1: Emergency Hotfix to Production

**Situation**: Critical bug needs immediate fix

**Steps**:
1. Create hotfix branch
2. Make fix and push
3. Run security scan: `gh workflow run security-scan-servicenow.yaml`
4. Wait for scan results (~5 minutes)
5. If no critical vulnerabilities, deploy:
   ```bash
   gh workflow run deploy-with-servicenow.yaml -f environment=prod
   ```
6. In ServiceNow, mark change as "Emergency" for faster approval
7. Get emergency approvals from CAB
8. Deployment proceeds automatically

**Timeline**: 30-60 minutes with emergency approvals

---

### Scenario 2: Regular Feature Release

**Situation**: New feature ready for production

**Steps**:
1. Deploy to dev:
   ```bash
   gh workflow run deploy-with-servicenow.yaml -f environment=dev
   ```
2. Test in dev environment
3. Deploy to QA:
   ```bash
   gh workflow run deploy-with-servicenow.yaml -f environment=qa
   ```
4. QA Lead approves in ServiceNow
5. Run QA tests
6. Schedule production deployment during maintenance window
7. Deploy to prod:
   ```bash
   gh workflow run deploy-with-servicenow.yaml -f environment=prod
   ```
8. CAB approves during change window
9. Deployment proceeds

**Timeline**: 1-2 days (dev → qa → prod)

---

### Scenario 3: Rollback Failed Deployment

**Situation**: Production deployment failed

**What Happens Automatically**:
- Workflow detects failure
- Automatically rolls back to previous version
- Updates ServiceNow change request with failure details
- Notifies team

**Manual Rollback**:
```bash
# Configure kubectl
aws eks update-kubeconfig --name microservices --region eu-west-2

# Rollback specific service
kubectl rollout undo deployment/frontend -n microservices-prod

# Or use Kustomize to redeploy previous version
git checkout <previous-commit>
kubectl apply -k kustomize/overlays/prod
```

---

## Troubleshooting

### Issue: "Change request not created"

**Check**:
```bash
# Verify ServiceNow secrets
echo "SN_INSTANCE_URL: Check GitHub Secrets"
echo "SN_DEVOPS_INTEGRATION_TOKEN: Check GitHub Secrets"
echo "SN_ORCHESTRATION_TOOL_ID: Check GitHub Secrets"
```

**Fix**:
1. Go to GitHub repository → Settings → Secrets
2. Verify all three secrets are present
3. Test ServiceNow API access:
   ```bash
   curl -X GET "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
     -H "Authorization: Bearer $SN_DEVOPS_INTEGRATION_TOKEN"
   ```

---

### Issue: "Deployment stuck waiting for approval"

**Check**:
- ServiceNow: Change Management → Find your change request
- Verify approvers received notification emails
- Check if approval groups are configured correctly

**Fix**:
1. In ServiceNow, manually approve the change as admin
2. Or cancel the workflow and re-run
3. Contact approvers to complete approval

---

### Issue: "Security scan results not appearing in ServiceNow"

**Check**:
- GitHub Actions workflow completed successfully?
- ServiceNow security tools configured?
- Tool IDs match (trivy, codeql, checkov, semgrep)?

**Fix**:
1. Go to ServiceNow: DevOps → Security → Tool Configuration
2. Verify each tool is configured with correct tool ID
3. Re-run security scan workflow

---

### Issue: "CMDB not updating"

**Check**:
- Is `SN_OAUTH_TOKEN` secret configured?
- Do CMDB CI classes exist (`u_eks_cluster`, `u_microservice`)?

**Fix**:
1. Verify `SN_OAUTH_TOKEN` in GitHub Secrets
2. In ServiceNow: Configuration → CI Class Manager
3. Verify both CI classes exist
4. Re-run discovery workflow

---

## Best Practices

### Security Scans

✅ **Do**:
- Run on every PR
- Review all findings before deploying
- Fix critical vulnerabilities immediately

❌ **Don't**:
- Ignore security warnings
- Deploy with unresolved critical issues
- Skip security scans

### Change Management

✅ **Do**:
- Use dev for testing
- Get QA approval before prod
- Document changes in commit messages
- Schedule prod deployments

❌ **Don't**:
- Deploy directly to prod without testing
- Rush approvals
- Skip change documentation

### CMDB Maintenance

✅ **Do**:
- Let discovery run automatically
- Review CMDB accuracy weekly
- Update manually after major changes

❌ **Don't**:
- Disable discovery
- Manually edit CMDB entries (they'll be overwritten)
- Ignore stale data

---

## Next Steps

### Week 1: Get Comfortable
- ✅ Deploy to dev multiple times
- ✅ Review security scan results
- ✅ Check ServiceNow CMDB

### Week 2: QA Process
- ✅ Deploy to QA environment
- ✅ Test approval workflow
- ✅ Run full QA test suite

### Week 3: Production Ready
- ✅ Schedule prod deployment
- ✅ Get CAB approval
- ✅ Deploy to production
- ✅ Monitor and verify

### Ongoing
- ✅ Review security scans weekly
- ✅ Track deployment metrics
- ✅ Audit CMDB accuracy monthly

---

## Support and Resources

### Documentation
- **Complete Plan**: [docs/SERVICENOW-INTEGRATION-PLAN.md](SERVICENOW-INTEGRATION-PLAN.md)
- **Architecture Diagrams**: [docs/SERVICENOW-ARCHITECTURE-DIAGRAM.md](SERVICENOW-ARCHITECTURE-DIAGRAM.md)
- **Setup Checklist**: [docs/SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md)
- **Workflow README**: [.github/workflows/SERVICENOW-WORKFLOWS-README.md](../.github/workflows/SERVICENOW-WORKFLOWS-README.md)

### Command Reference

```bash
# Security scan
gh workflow run security-scan-servicenow.yaml

# Deploy to dev (auto-approved)
gh workflow run deploy-with-servicenow.yaml -f environment=dev

# Deploy to qa (manual approval)
gh workflow run deploy-with-servicenow.yaml -f environment=qa

# Deploy to prod (CAB approval)
gh workflow run deploy-with-servicenow.yaml -f environment=prod

# EKS discovery
gh workflow run eks-discovery.yaml

# View workflow runs
gh run list

# View specific workflow run
gh run view <run-id>
```

---

**Last Updated**: 2025-10-15
**Questions?** Check the [complete documentation](SERVICENOW-INTEGRATION-PLAN.md) or contact your ServiceNow admin.
