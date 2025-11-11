# Automated Release Workflow - Quick Reference

## 🎯 Your Complete Solution

You wanted an automated workflow that:
- ✅ Creates a ticket (GitHub issue) with version bump
- ✅ Creates a new branch
- ✅ Deploys to dev
- ✅ Creates and merges PR
- ✅ Pushes to QA with ServiceNow approval
- ✅ Creates production branch with new version
- ✅ Deploys to prod with ServiceNow approval
- ✅ Closes ticket after success

**All of this is now available with a single command!**

## The Magic Command

```bash
just release-minor-auto
```

That's it! This single command does **everything** you asked for.

## What Happens Step-by-Step

### 1. Version Bump (Automatic)
```
Current: 1.3.0
New:     1.4.0
```
- Updates `VERSION` file
- Commits to main
- Pushes to GitHub

### 2. Dev Deployment (Automatic)
```
🟢 DEV Environment
```
- Creates GitHub issue: "Deploy dev to 1.4.0"
- Creates branch: `feat/version-bump-dev-1.4.0`
- Updates `kustomize/overlays/dev/kustomization.yaml`
- Creates PR linked to issue
- Auto-merges PR
- Triggers MASTER-PIPELINE with:
  - `environment=dev`
  - `version=1.4.0`
  - `force_build_all=true`
- **Builds all 12 Docker images** (frontend, cart, catalog, etc.)
- **Tags images**: `v1.4.0`, `dev-sha123`, `latest`
- **Pushes images to ECR**
- Deploys to `microservices-dev` namespace
- ServiceNow: Auto-approved ✅

### 3. QA Deployment (Manual Approval)
```
🟡 Deploy to QA? (y/N): y
```
- Creates branch: `release/1.4.0`
- Updates `kustomize/overlays/qa/kustomization.yaml`
- Creates PR
- Triggers MASTER-PIPELINE with:
  - `environment=qa`
  - `version=1.4.0`
  - `force_build_all=true`
- **Builds all 12 Docker images** (if not already built)
- **Tags images**: `v1.4.0`, `qa-sha123`
- **Pushes images to ECR**
- **PAUSES** for ServiceNow approval ⏸️
- Waits for QA Lead approval in ServiceNow
- After approval: Deploys to `microservices-qa` namespace

### 4. Production Deployment (CAB Approval)
```
🔴 Deploy to PROD? (y/N): y
```
- Uses same `release/1.4.0` branch
- Updates `kustomize/overlays/prod/kustomization.yaml`
- Creates PR
- Triggers MASTER-PIPELINE with:
  - `environment=prod`
  - `version=1.4.0`
  - `force_build_all=true`
- **Builds all 12 Docker images** (if not already built)
- **Tags images**: `v1.4.0`, `prod-sha123`, `latest`
- **Pushes images to ECR**
- **PAUSES** for ServiceNow CAB approval ⏸️
- Waits for Change Advisory Board approval
- After approval: Deploys to `microservices-prod` namespace

### 5. Cleanup (Automatic)
```
✅ Success
```
- Closes GitHub issue with deployment summary
- Deletes merged branches
- Complete audit trail in ServiceNow

## Alternative Commands

### For Patch Releases (Bug Fixes)
```bash
just release-patch-auto
# 1.3.0 → 1.3.1
```

### For Manual Control Per Environment
```bash
# Deploy to dev only
just demo-run ENV=dev TAG=1.4.0

# Later, deploy to qa
just demo-run ENV=qa TAG=1.4.0

# Later, deploy to prod
just demo-run ENV=prod TAG=1.4.0
```

### For Version Bump Without Deployment
```bash
just bump-minor     # 1.3.0 → 1.4.0
just bump-patch     # 1.3.0 → 1.3.1
just bump-major     # 1.3.0 → 2.0.0
```

## ServiceNow Approval Process

### For QA
1. Workflow pauses with message:
   ```
   ⏸️ Waiting for ServiceNow CR approval...
   📝 Approve at: https://calitiiltddemo3.service-now.com
   ```
2. Go to ServiceNow → **Change Management → My Changes**
3. Find change request for v1.4.0 QA deployment
4. Review:
   - Implementation plan
   - Test results
   - Security scan results
5. Click **Approve**
6. Deployment continues automatically

### For Production
Same as QA, but requires **three approvals**:
- ✅ Change Manager
- ✅ Application Owner
- ✅ Security Team

## Complete Example

```bash
$ just release-minor-auto

🚀 Starting Automated Minor Version Release Workflow
=====================================================

📦 Bumping MINOR version: 1.3.0 → 1.4.0
✅ Version file updated and pushed

🟢 Deploying to DEV environment...
📌 Creating feature branch: feat/version-bump-dev-1.4.0
🧾 Creating GitHub issue (work item)
Issue created: #456
🔧 Bumping version in kustomize overlay
📝 Commit changes: chore(dev): bump version to 1.4.0 (refs #456)
📤 Push branch
🔀 Open pull request: PR #457
✅ Auto-merged PR
🚀 Trigger MASTER-PIPELINE for dev
⏳ Waiting for deployment to complete...
🎉 Deployment completed successfully
🧹 Closing work item #456

🟡 Deploy to QA? (y/N): y
🟡 Deploying to QA environment (requires ServiceNow approval)...
📌 Creating release branch: release/1.4.0
🧾 Creating GitHub issue: #458
🔧 Bumping version in kustomize overlay
📝 Commit changes
📤 Push branch
🔀 Open pull request: PR #459
🚀 Trigger MASTER-PIPELINE for qa
⏸️  Waiting for ServiceNow CR approval...
📝 Approve at: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/change_request_list.do

[Go to ServiceNow and approve]

✅ Change request approved
🎉 Deployment completed successfully
🧹 Closing work item #458

🔴 Deploy to PROD? (y/N): y
🔴 Deploying to PROD environment (requires ServiceNow approval)...
🧾 Creating GitHub issue: #460
🔧 Bumping version in kustomize overlay
📝 Commit changes
📤 Push branch
🔀 Open pull request: PR #461
🚀 Trigger MASTER-PIPELINE for prod
⏸️  Waiting for ServiceNow CR approval...
📝 Approve at: https://calitiiltddemo3.service-now.com

[Go to ServiceNow, wait for CAB approval]

✅ Change request approved by CAB
🎉 Deployment completed successfully
🧹 Closing work item #460

🎉 Release workflow complete!
Version 1.4.0 deployed successfully
```

## Monitoring Commands

```bash
# Check deployment status
just watch-deploy

# List recent deployments
just deployments

# Check version across all environments
just promotion-status 1.4.0

# View pods in each environment
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod

# Get application URLs
kubectl get ingress frontend-ingress -n microservices-dev
kubectl get ingress frontend-ingress -n microservices-qa
kubectl get ingress frontend-ingress -n microservices-prod
```

## Quick Help

```bash
# Show all release commands with explanations
just release-help

# Show all available justfile commands
just --list
```

## Files Modified

The automation creates/modifies these files:

1. **VERSION** - Version number (1.3.0 → 1.4.0)
2. **kustomize/overlays/dev/kustomization.yaml** - Dev image tags
3. **kustomize/overlays/qa/kustomization.yaml** - QA image tags
4. **kustomize/overlays/prod/kustomization.yaml** - Prod image tags

## Audit Trail

Complete audit trail is maintained in:
- 📝 GitHub Issues (work items)
- 🔀 GitHub Pull Requests (code changes)
- 🚀 GitHub Actions (CI/CD workflows)
- 📊 ServiceNow Change Requests (approvals)
- 🐳 Kubernetes (deployment history)

## Key Features

### Automated Docker Image Building
The workflow **automatically builds all Docker images** as part of the deployment:
- No manual image building required
- Images are built with the correct version tag
- All 12 services built in parallel for efficiency
- Images pushed to ECR before Kubernetes deployment
- Eliminates ImagePullBackOff errors from missing images

This means you **never need to manually run**:
```bash
# ❌ NOT NEEDED - Automated workflow does this
just docker-build-all
just ecr-push service dev
```

The `demo-run` command and automated workflows handle everything!

## Troubleshooting

### PR Auto-Merge Fails
```bash
# Check why merge failed
gh pr view <PR_NUMBER>

# Manually merge
gh pr merge <PR_NUMBER> --squash --delete-branch
```

### ServiceNow Approval Stuck
1. Go to ServiceNow
2. Navigate to **Change Management → My Changes**
3. Review and approve the change request
4. Workflow continues automatically

### Deployment Failed
```bash
# Check workflow logs
gh run view <RUN_ID>

# Check pod status
kubectl get pods -n microservices-dev

# View pod logs
kubectl logs -l app=frontend -n microservices-dev
```

## Key Benefits

✅ **Fully Automated** - One command does everything
✅ **Complete Audit Trail** - GitHub + ServiceNow integration
✅ **Approval Gates** - ServiceNow integration for qa/prod
✅ **Branch Protection** - Complies with branch policies
✅ **Issue Tracking** - Auto-creates and closes GitHub issues
✅ **Rollback Support** - Full version history maintained
✅ **SOC 2 / ISO 27001 Compliant** - Change management controls

## Next Steps

1. **Test it out**:
   ```bash
   just release-minor-auto
   ```

2. **Read the complete guide**:
   ```bash
   cat docs/AUTOMATED-RELEASE-GUIDE.md
   ```

3. **Explore all commands**:
   ```bash
   just release-help
   ```

---

**You're all set!** Your automated version bump and deployment workflow is ready to use. 🚀
