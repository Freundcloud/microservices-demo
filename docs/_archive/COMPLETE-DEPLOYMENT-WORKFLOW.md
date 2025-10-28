# Complete Version Bump and Deployment Workflow

This guide demonstrates the end-to-end workflow for version bumping and deploying services with ServiceNow approval integration.

## Overview

The `demo-run` command in the justfile automates the complete deployment workflow:

1. ✅ Create GitHub work item (issue)
2. ✅ Create feature/ branch
3. ✅ Bump version in Kustomize overlays
4. ✅ Create pull request
5. ✅ Run tests before merging (via GitHub Actions)
6. ✅ Deploy with ServiceNow approval request
7. ⚠️ Approve the change request (manual step)
8. ✅ Deploy services to environment
9. ✅ Close work item automatically

## Prerequisites

Before running the workflow, ensure:

- [ ] AWS credentials configured (`.envrc` sourced)
- [ ] GitHub CLI authenticated (`gh auth login`)
- [ ] ServiceNow credentials set in GitHub Secrets
- [ ] ServiceNow tool "GithHubARC" is **ACTIVE**
- [ ] EKS cluster is running (`just cluster-status`)
- [ ] You're on the `main` branch with latest changes

## Running the Workflow

### Command Syntax

```bash
just demo-run ENV=<environment> TAG=<version>
```

**Parameters:**
- `ENV`: Target environment (`dev`, `qa`, or `prod`)
- `TAG`: Semantic version (e.g., `v1.0.1`, `v1.2.3`)

### Example: Deploy to Dev

```bash
# Full workflow: create issue → bump version → PR → merge → deploy → close issue
just demo-run ENV=dev TAG=v1.0.1
```

### Example: Deploy to QA

```bash
# Deploy tested version from dev to qa
just demo-run ENV=qa TAG=v1.0.2
```

### Example: Deploy to Production

```bash
# Deploy approved version to production
just demo-run ENV=prod TAG=v1.1.0
```

## Step-by-Step Workflow Breakdown

### Step 1: Create GitHub Work Item (Issue)

**What Happens:**
```bash
gh issue create \
  --title "Deploy dev to v1.0.1" \
  --body "Automated version bump and deployment to dev environment..." \
  --label "deployment,dev" \
  --json number,url
```

**Output:**
```
🧾 Creating GitHub issue (work item)
✅ Created issue #123: https://github.com/Calitii/ARC/issues/123
```

**Verification:**
- Visit: https://github.com/Calitii/ARC/microservices-demo/issues
- Issue appears with label "deployment" and "dev"
- Issue body contains environment, version, and workflow details

---

### Step 2: Create Feature Branch

**What Happens:**
```bash
BRANCH="feat/version-bump-dev-v1.0.1"
git checkout -b "$BRANCH"
```

**Output:**
```
🌿 Creating branch: feat/version-bump-dev-v1.0.1
Switched to a new branch 'feat/version-bump-dev-v1.0.1'
```

**Verification:**
```bash
git branch --show-current
# Expected: feat/version-bump-dev-v1.0.1
```

---

### Step 3: Bump Version

**What Happens:**
```bash
./scripts/bump-env-version.sh "dev" "v1.0.1"
```

**Files Modified:**
- `kustomize/overlays/dev/kustomization.yaml`

**Changes:**
```yaml
# Before
images:
  - name: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
    newTag: dev

# After
images:
  - name: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
    newTag: v1.0.1
```

**Output:**
```
🔧 Bumping version in kustomize/overlays/dev
✅ Updated all 10 service images to v1.0.1
```

**Verification:**
```bash
git status
# Modified: kustomize/overlays/dev/kustomization.yaml

git diff kustomize/overlays/dev/kustomization.yaml
# Shows newTag: dev → newTag: v1.0.1 for all services
```

---

### Step 4: Commit and Push

**What Happens:**
```bash
git add kustomize/overlays/dev/kustomization.yaml
git commit -m "chore(dev): bump version to v1.0.1 (refs #123)"
git push -u origin feat/version-bump-dev-v1.0.1
```

**Output:**
```
📤 Committing and pushing changes
[feat/version-bump-dev-v1.0.1 abc1234] chore(dev): bump version to v1.0.1 (refs #123)
 1 file changed, 10 insertions(+), 10 deletions(-)
```

**Verification:**
- Visit: https://github.com/Calitii/ARC/microservices-demo/branches
- Branch `feat/version-bump-dev-v1.0.1` appears

---

### Step 5: Create Pull Request

**What Happens:**
```bash
gh pr create \
  --fill \
  --title "Bump dev to v1.0.1" \
  --body "Automated version bump for deployment to dev environment..." \
  --label "deployment,dev"
```

**Output:**
```
🔀 Opening pull request
✅ Created PR #456: https://github.com/Calitii/ARC/pulls/456
```

**GitHub Actions Triggered:**
- ✅ **Terraform Validate**: Validates Terraform configuration
- ✅ **Security Scan**: Runs CodeQL, Gitleaks, Semgrep
- ✅ **Kustomize Validate**: Validates Kustomize overlays
- ✅ **Lint Check**: Runs YAML linting

**Verification:**
- Visit: https://github.com/Calitii/ARC/microservices-demo/pulls
- PR appears with checks running
- All checks must pass before merge

---

### Step 6: Merge Pull Request

**What Happens:**
```bash
gh pr merge --squash --delete-branch --merge
```

**Conditions:**
- ✅ All GitHub Actions checks must pass
- ✅ No merge conflicts
- ✅ Branch is up to date with main

**Output:**
```
✅ Attempting to merge PR #456
⏳ Waiting for checks to pass...
✅ All checks passed
✅ Merged PR #456 into main
✅ Deleted branch feat/version-bump-dev-v1.0.1
```

**Verification:**
```bash
git checkout main
git pull origin main
cat kustomize/overlays/dev/kustomization.yaml | grep newTag
# Shows: newTag: v1.0.1
```

---

### Step 7: Trigger Deployment Pipeline

**What Happens:**
```bash
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f skip_build=false
```

**Output:**
```
🚀 Triggering MASTER-PIPELINE for dev
✅ Workflow dispatched: Run ID 12345678
📍 URL: https://github.com/Calitii/ARC/actions/runs/12345678
```

**Pipeline Phases:**

#### Phase 1: Security Validation (jobs: security-validate)
- Terraform security scan (tfsec, checkov)
- Secret detection (gitleaks)
- Code analysis (semgrep)
- Duration: ~2 minutes

#### Phase 2: Build and Push Images (jobs: build-images)
- Smart builds (only changed services)
- Multi-arch builds (amd64, arm64)
- Container scanning (trivy)
- Push to ECR with tag `v1.0.1`
- Duration: ~8 minutes (if all services changed)

#### Phase 3: ServiceNow Change Request (jobs: register-change)
- Creates change request in ServiceNow
- **Status**: "Pending Approval"
- **Risk**: Normal (dev), High (prod)
- **Description**: Includes GitHub context (Actor, Branch, Commit, PR)
- **Artifacts**: Registers container images
- **Evidence**: Uploads security scan results

**Change Request Details:**
```
Short Description: Deploy to dev - PR #456 by olafkfreund
Description:
  Automated deployment to dev environment via GitHub Actions

  GitHub Context:
  - Actor: olafkfreund
  - Branch: main
  - Commit: abc1234
  - Pull Request: #456
  - PR URL: https://github.com/Calitii/ARC/pulls/456

  Workflow Run: https://github.com/Calitii/ARC/actions/runs/12345678
  Repository: Calitii/ARC/microservices-demo
  Event: workflow_dispatch
```

#### Phase 4: Wait for Approval (jobs: wait-for-approval)
- Polls ServiceNow every 30 seconds
- **Timeout**: 2 hours (dev/qa), 24 hours (prod)
- **Status**: "Waiting for ServiceNow approval..."

**Console Output:**
```
⏳ Waiting for ServiceNow approval (Change Request: CHG0012345)
⏳ Status: Pending Approval (attempt 1/240)
⏳ Status: Pending Approval (attempt 2/240)
⏳ Status: Pending Approval (attempt 3/240)
...
```

**This is where the workflow PAUSES and waits for manual approval in ServiceNow.**

---

### Step 8: Approve Change Request in ServiceNow (MANUAL STEP)

**⚠️ This is the ONLY manual step in the entire workflow.**

#### 8.1. Access ServiceNow

**URL**: https://calitiiltddemo3.service-now.com

**Login Credentials:**
- Username: `github_integration` (or your admin account)
- Password: (from .envrc)

#### 8.2. Navigate to Change Requests

**Path**: Change → All → Find CHG0012345

**Alternative**: Use the URL from GitHub Actions logs:
```
https://calitiiltddemo3.service-now.com/change_request.do?sysparm_query=number=CHG0012345
```

#### 8.3. Review Change Request

**Check the following:**

✅ **Short Description**: "Deploy to dev - PR #456 by olafkfreund"

✅ **Description**: Contains GitHub context (Actor, Branch, Commit, PR)

✅ **Attachments**: Security scan evidence files
- `security-scan-evidence-123.md`
- `terraform-scan-results-123.txt`
- `container-scan-results-123.json`

✅ **Work Notes**: Shows GitHub workflow URL

✅ **Related Artifacts**: Registered container images
- `frontend:v1.0.1`
- `cartservice:v1.0.1`
- `productcatalogservice:v1.0.1`
- ... (all 10 services)

✅ **GitHub Custom Fields** (if created):
- `u_github_actor`: olafkfreund
- `u_github_branch`: main
- `u_github_pr`: 456
- `u_github_commit`: abc1234

#### 8.4. Approve Change Request

**Steps:**
1. Click **"State"** dropdown
2. Select **"Authorize"** or **"Implement"** (depending on your CAB process)
3. Add approval comment (optional):
   ```
   Approved for deployment to dev environment.
   Security scans passed. All tests successful.
   ```
4. Click **"Update"** or **"Save"**

**Expected Result:**
```
✅ Change Request CHG0012345 approved
✅ Status changed to: Implement
```

#### 8.5. Verify Approval in GitHub Actions

**Return to GitHub Actions:**
- Visit: https://github.com/Calitii/ARC/actions/runs/12345678

**Console Output Changes:**
```
⏳ Status: Pending Approval (attempt 15/240)
✅ Change Request approved! Proceeding with deployment...
```

---

### Step 9: Deploy Services to Environment

**What Happens Automatically After Approval:**

#### 9.1. Apply Kustomize Overlays
```bash
kubectl apply -k kustomize/overlays/dev
```

**Output:**
```
🚀 Deploying to dev environment
namespace/microservices-dev configured
serviceaccount/frontend configured
deployment.apps/frontend configured
service/frontend configured
... (all 10 services)
✅ Deployment applied successfully
```

#### 9.2. Wait for Rollout
```bash
kubectl rollout status deployment/frontend -n microservices-dev
kubectl rollout status deployment/cartservice -n microservices-dev
... (all 10 services)
```

**Output:**
```
⏳ Waiting for deployments to be ready...
deployment "frontend" successfully rolled out
deployment "cartservice" successfully rolled out
... (all 10 services)
✅ All deployments ready
```

#### 9.3. Register Deployment in ServiceNow
```bash
curl -X POST "$SERVICENOW_URL/api/sn_devops/v1/devops/artifact/deploy" \
  -H "Content-Type: application/json" \
  -d '{
    "artifacts": [...],
    "deployment_env": "dev",
    "correlation_id": "12345678"
  }'
```

**Output:**
```
✅ Deployment registered in ServiceNow
✅ Change Request status: Complete
```

#### 9.4. Close Change Request
```bash
curl -X PATCH "$SERVICENOW_URL/api/now/table/change_request/$CHANGE_SYS_ID" \
  -d '{
    "state": "Closed Complete",
    "close_code": "successful",
    "close_notes": "Deployment completed successfully"
  }'
```

**Output:**
```
✅ Change Request CHG0012345 closed successfully
```

**Verification:**
```bash
# Check pods are running
kubectl get pods -n microservices-dev

# Expected:
NAME                           READY   STATUS    RESTARTS   AGE
frontend-xxx                   2/2     Running   0          2m
cartservice-xxx                2/2     Running   0          2m
productcatalogservice-xxx      2/2     Running   0          2m
... (all 10 services with 2/2 ready - app + istio-proxy)

# Check image versions
kubectl get deployment frontend -n microservices-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.0.1
```

---

### Step 10: Close GitHub Work Item

**What Happens Automatically:**
```bash
gh issue close "$ISSUE_NUM" \
  -c "Deployment to dev environment (v1.0.1) succeeded.

  ServiceNow Change Request: CHG0012345
  Status: Closed Complete

  Workflow Run: https://github.com/Calitii/ARC/actions/runs/12345678
  Deployed at: $(date -u)"
```

**Output:**
```
🧹 Closing work item #123
✅ Issue #123 closed with comment
```

**Verification:**
- Visit: https://github.com/Calitii/ARC/microservices-demo/issues/123
- Issue is **Closed**
- Comment contains:
  - Deployment success message
  - ServiceNow Change Request number
  - Workflow run URL
  - Timestamp

---

## Complete Workflow Timeline

| Time | Step | Duration | Status |
|------|------|----------|--------|
| 00:00 | Create GitHub Issue | ~5s | ✅ Automated |
| 00:05 | Create Feature Branch | ~2s | ✅ Automated |
| 00:07 | Bump Version | ~3s | ✅ Automated |
| 00:10 | Commit & Push | ~5s | ✅ Automated |
| 00:15 | Create Pull Request | ~5s | ✅ Automated |
| 00:20 | Run Tests (GitHub Actions) | ~3min | ✅ Automated |
| 03:20 | Merge Pull Request | ~5s | ✅ Automated |
| 03:25 | Trigger MASTER-PIPELINE | ~2s | ✅ Automated |
| 03:27 | Security Validation | ~2min | ✅ Automated |
| 05:27 | Build & Push Images | ~8min | ✅ Automated |
| 13:27 | Create ServiceNow Change | ~10s | ✅ Automated |
| 13:37 | Wait for Approval | ~5-60min | ⚠️ **MANUAL** |
| **→** | **Approve in ServiceNow** | **~1min** | **🔴 YOU DO THIS** |
| 18:37 | Deploy to Kubernetes | ~2min | ✅ Automated |
| 20:37 | Register Deployment | ~5s | ✅ Automated |
| 20:42 | Close Change Request | ~5s | ✅ Automated |
| 20:47 | Close GitHub Issue | ~5s | ✅ Automated |

**Total Time**: ~20-75 minutes (depends on approval speed)

**Manual Steps**: **1** (ServiceNow approval)

---

## Monitoring the Workflow

### Watch Workflow in Terminal
```bash
# From the demo-run command
gh run watch --run-id "$RUN_ID" --exit-status
```

**Output:**
```
✓ security-validate (2m 15s)
✓ build-images (8m 32s)
✓ register-change (12s)
* wait-for-approval (in progress) 5m 23s
  deploy-services (pending)
  close-change (pending)
```

### View in GitHub Actions UI
```
https://github.com/Calitii/ARC/microservices-demo/actions/runs/12345678
```

**Visual Status:**
- ✅ Green checkmark: Step completed
- 🔵 Blue dot: Step in progress
- ⏸️ Gray pause: Waiting for approval
- ❌ Red X: Step failed

### Check ServiceNow Status
```bash
# Via API (from another terminal)
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=numberSTARTSWITHCHG&sysparm_limit=1&sysparm_fields=number,state,short_description" \
  | jq '.result[0]'
```

**Expected Output:**
```json
{
  "number": "CHG0012345",
  "state": "Pending Approval",
  "short_description": "Deploy to dev - PR #456 by olafkfreund"
}
```

### Check Kubernetes Deployment
```bash
# Check if pods are updating
kubectl get pods -n microservices-dev -w

# Check rollout status
kubectl rollout status deployment/frontend -n microservices-dev
```

---

## Environment-Specific Behavior

### Dev Environment
- **Approval**: Optional (can auto-approve)
- **Risk**: Normal
- **Timeout**: 2 hours
- **Replicas**: 1 per service
- **Resources**: Minimal (requests: 50m CPU, 64Mi RAM)
- **Load Generator**: Disabled

### QA Environment
- **Approval**: Required (CAB member)
- **Risk**: Moderate
- **Timeout**: 2 hours
- **Replicas**: 2 per service
- **Resources**: Moderate (requests: 100m CPU, 128Mi RAM)
- **Load Generator**: Enabled

### Prod Environment
- **Approval**: Required (CAB lead + manager)
- **Risk**: High
- **Timeout**: 24 hours
- **Replicas**: 3 per service (HA)
- **Resources**: High (requests: 200m CPU, 256Mi RAM)
- **Load Generator**: Disabled

---

## Troubleshooting

### Workflow Failed at "Wait for Approval"

**Symptom:**
```
❌ Timeout waiting for ServiceNow approval (2 hours)
```

**Possible Causes:**
1. Change request not approved in ServiceNow
2. ServiceNow tool is inactive
3. Change request state not updated

**Fix:**
1. Check ServiceNow: https://calitiiltddemo3.service-now.com/change_request_list.do
2. Approve the change request manually
3. Verify tool is active: https://calitiiltddemo3.service-now.com/sn_devops_tool.do?sys_id=f62c4e49c3fcf614e1bbf0cb050131ef

### Workflow Failed at "Deploy Services"

**Symptom:**
```
❌ Error: deployment failed
Error from server: deployments.apps "frontend" not found
```

**Possible Causes:**
1. Namespace doesn't exist
2. Kustomize overlay has errors
3. Kubernetes API unreachable

**Fix:**
```bash
# Create namespace if missing
kubectl create namespace microservices-dev
kubectl label namespace microservices-dev istio-injection=enabled

# Validate Kustomize
kubectl kustomize kustomize/overlays/dev

# Check cluster connectivity
kubectl cluster-info
```

### Change Request Not Created

**Symptom:**
```
❌ Failed to create change request (HTTP 403)
```

**Possible Causes:**
1. ServiceNow credentials not set
2. User lacks permissions
3. Tool is inactive

**Fix:**
```bash
# Verify credentials
source .envrc
./scripts/verify-servicenow-api.sh

# Check GitHub Secrets
gh secret list | grep SERVICENOW

# Activate tool
./scripts/activate-servicenow-tool.sh
```

### Issue Not Closed

**Symptom:**
- Deployment succeeds but issue remains open

**Possible Causes:**
1. GitHub CLI not authenticated
2. Issue number not captured
3. Workflow step failed silently

**Fix:**
```bash
# Close manually
gh issue close 123 -c "Deployment succeeded (manual close)"

# Check workflow logs
gh run view 12345678 --log
```

---

## Advanced Usage

### Run Workflow for Multiple Environments

```bash
# Deploy same version to all environments
just demo-run ENV=dev TAG=v1.0.1
# Wait for approval and deployment
just demo-run ENV=qa TAG=v1.0.1
# Wait for approval and deployment
just demo-run ENV=prod TAG=v1.0.1
```

### Skip Building Images

```bash
# If images already exist in ECR
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f skip_build=true
```

### Deploy Without Version Bump

```bash
# Just trigger deployment (no PR, no version change)
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f skip_build=false
```

### Rollback to Previous Version

```bash
# Get previous version
git log --oneline kustomize/overlays/dev/kustomization.yaml | head -5

# Create rollback PR
just demo-run ENV=dev TAG=v1.0.0  # previous version
```

---

## Success Checklist

After running `just demo-run ENV=dev TAG=v1.0.1`, verify:

- [ ] GitHub Issue created (#123)
- [ ] Feature branch created (feat/version-bump-dev-v1.0.1)
- [ ] kustomization.yaml updated (newTag: v1.0.1)
- [ ] Pull Request created (#456)
- [ ] All PR checks passed (green checkmarks)
- [ ] PR merged to main
- [ ] MASTER-PIPELINE triggered (Run ID 12345678)
- [ ] Security validation passed
- [ ] Images built and pushed to ECR
- [ ] ServiceNow Change Request created (CHG0012345)
- [ ] Change Request approved in ServiceNow
- [ ] Services deployed to microservices-dev namespace
- [ ] All pods running (2/2 ready - app + istio-proxy)
- [ ] Deployment registered in ServiceNow
- [ ] Change Request closed (Closed Complete)
- [ ] GitHub Issue closed (#123)

---

## Quick Reference Commands

```bash
# Run complete workflow
just demo-run ENV=dev TAG=v1.0.1

# Watch workflow progress
gh run watch --exit-status

# Check ServiceNow change requests
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_limit=5" | jq .

# Check Kubernetes deployment
kubectl get pods -n microservices-dev
kubectl rollout status deployment/frontend -n microservices-dev

# View application
just k8s-url

# Check Istio service mesh
just istio-kiali

# View workflow logs
gh run view --log

# Close issue manually if needed
gh issue close <ISSUE_NUM> -c "Deployment succeeded"
```

---

## Related Documentation

- **ServiceNow Integration Guide**: [docs/GITHUB-SERVICENOW-INTEGRATION-GUIDE.md](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- **Authentication Troubleshooting**: [docs/SERVICENOW-AUTHENTICATION-TROUBLESHOOTING.md](SERVICENOW-AUTHENTICATION-TROUBLESHOOTING.md)
- **Antipatterns Guide**: [docs/GITHUB-SERVICENOW-ANTIPATTERNS.md](GITHUB-SERVICENOW-ANTIPATTERNS.md)
- **Kustomize Multi-Environment**: [kustomize/overlays/README.md](../kustomize/overlays/README.md)
- **Developer Onboarding**: [docs/ONBOARDING.md](ONBOARDING.md)

---

## Summary

This workflow provides:

✅ **Full Automation** - Only 1 manual step (ServiceNow approval)

✅ **Audit Trail** - Complete traceability from issue → code → approval → deployment

✅ **Compliance** - Meets SOC 2 / ISO 27001 requirements

✅ **Safety** - Tests run before merge, approval required before deploy

✅ **Visibility** - Real-time status in GitHub Actions and ServiceNow

✅ **Repeatability** - Consistent process for all environments

Run it now:
```bash
just demo-run ENV=dev TAG=v1.0.1
```
