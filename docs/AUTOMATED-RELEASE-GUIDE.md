# Automated Release Management Guide

## Overview

This guide explains the **fully automated version bump and deployment workflows** available in this project. These workflows handle everything from creating tickets to deploying across environments with ServiceNow integration.

## Quick Start

### Automated Minor Version Release (Recommended)

```bash
# Complete workflow: bump version from 1.3.0 → 1.4.0 and deploy
just release-minor-auto
```

This single command:
1. ✅ Bumps minor version in `VERSION` file (1.3.0 → 1.4.0)
2. ✅ Commits and pushes version change to main
3. ✅ Creates GitHub issue (ticket) for the release
4. ✅ Creates release branch
5. ✅ Updates kustomize overlays with new version
6. ✅ Creates pull request
7. ✅ Auto-merges PR
8. ✅ Triggers MASTER-PIPELINE for dev
9. ✅ Deploys to dev (auto-approved)
10. ✅ Prompts for QA deployment (requires ServiceNow approval)
11. ✅ Prompts for prod deployment (requires ServiceNow approval)
12. ✅ Closes GitHub issue after success

### Automated Patch Version Release

```bash
# For bug fixes and minor updates: 1.3.0 → 1.3.1
just release-patch-auto
```

Same workflow as `release-minor-auto` but increments patch version instead.

## Available Commands

### Fully Automated Workflows

| Command | Description | Version Change |
|---------|-------------|----------------|
| `just release-minor-auto` | Complete automated minor release | 1.3.0 → 1.4.0 |
| `just release-patch-auto` | Complete automated patch release | 1.3.0 → 1.3.1 |
| `just release-deploy-version 1.4.0 dev` | Deploy existing version to specific environment | N/A |

### Manual Control Workflows

| Command | Description | Use Case |
|---------|-------------|----------|
| `just demo-run ENV=dev TAG=1.4.0` | Full workflow for specific env/version | Manual control over each environment |
| `just promote 1.4.0 all` | Promote version through all environments | Sequential deployment with pauses |
| `just bump-minor` | Only bump version file | Version bump without deployment |
| `just bump-patch` | Only bump version file | Version bump without deployment |

## Understanding `demo-run`

The `demo-run` command is the **core building block** that powers the automated workflows. It performs a complete deployment workflow for a single environment:

### Usage

```bash
just demo-run ENV=<dev|qa|prod> TAG=<version>
```

### Examples

```bash
# Deploy version 1.4.0 to dev
just demo-run ENV=dev TAG=1.4.0

# Deploy version 1.4.0 to qa (requires ServiceNow approval)
just demo-run ENV=qa TAG=1.4.0

# Deploy version 1.4.0 to prod (requires ServiceNow approval)
just demo-run ENV=prod TAG=1.4.0
```

### What `demo-run` Does

1. **Creates GitHub Issue**
   - Title: "Deploy {env} to {version}"
   - Body: Description of the deployment
   - Label: `enhancement`

2. **Creates Feature Branch**
   - For dev: `feat/version-bump-dev-{TAG}`
   - For qa/prod: `release/{TAG}` (complies with branch protection)

3. **Bumps Version in Kustomize**
   - Runs `scripts/bump-env-version.sh {ENV} {TAG}`
   - Updates `kustomize/overlays/{ENV}/kustomization.yaml`
   - Sets `newTag: {TAG}` for all service images

4. **Creates Commit**
   - Message: `chore({ENV}): bump version to {TAG} (refs #{ISSUE})`
   - Links commit to GitHub issue

5. **Pushes Branch**
   - Pushes to remote repository
   - Triggers CI/CD checks

6. **Creates Pull Request**
   - Title: "Bump {ENV} to {TAG}"
   - Body: Links to issue, describes deployment plan
   - Base: `main` branch

7. **Auto-Merges PR**
   - For dev: Auto-merges immediately
   - For release branches (qa/prod): Keeps PR open for review

8. **Triggers MASTER-PIPELINE**
   - Workflow: `.github/workflows/MASTER-PIPELINE.yaml`
   - Parameter: `environment={ENV}`
   - Waits for ServiceNow approval (qa/prod only)

9. **Monitors Deployment**
   - Watches GitHub Actions workflow run
   - Shows deployment progress
   - Displays ServiceNow change request status

10. **Closes GitHub Issue**
    - After successful deployment
    - Adds comment with deployment summary

### Branch Strategy

| Environment | Branch Pattern | Auto-Merge | Reason |
|-------------|----------------|------------|--------|
| dev | `feat/version-bump-dev-{TAG}` | ✅ Yes | Fast iteration, CI/CD validation |
| qa | `release/{TAG}` | ❌ No | Branch protection, review required |
| prod | `release/{TAG}` | ❌ No | Branch protection, CAB approval required |

## Workflow Comparison

### Option 1: Fully Automated (`release-minor-auto`)

**Best for**: Quick releases, continuous deployment

```bash
just release-minor-auto
```

**Process**:
```
1. Bump version file (1.3.0 → 1.4.0)
2. Push to main
3. Run demo-run ENV=dev TAG=1.4.0
   → Creates issue
   → Creates branch
   → Creates & merges PR
   → Deploys to dev
4. Prompt: Deploy to QA? (y/N)
   → If yes: Run demo-run ENV=qa TAG=1.4.0
5. Prompt: Deploy to prod? (y/N)
   → If yes: Run demo-run ENV=prod TAG=1.4.0
```

**Advantages**:
- ✅ Single command for complete workflow
- ✅ Consistent versioning across environments
- ✅ Full audit trail (tickets, PRs, ServiceNow CRs)
- ✅ Interactive approval gates for qa/prod

**When to use**:
- Regular feature releases
- Bug fix deployments
- Scheduled releases

### Option 2: Manual Control (`demo-run`)

**Best for**: Environment-specific deployments, testing

```bash
# Deploy to dev first
just demo-run ENV=dev TAG=1.4.0

# After testing, deploy to qa
just demo-run ENV=qa TAG=1.4.0

# After qa validation, deploy to prod
just demo-run ENV=prod TAG=1.4.0
```

**Advantages**:
- ✅ Fine-grained control over each environment
- ✅ Can deploy different versions to different environments
- ✅ Can skip environments
- ✅ Useful for hotfixes or rollbacks

**When to use**:
- Hotfix deployments (skip qa)
- Environment-specific versions
- Rollback scenarios
- Testing specific versions

### Option 3: Promotion Workflow (`promote`)

**Best for**: Sequential deployment with validation between stages

```bash
just promote 1.4.0 all
```

**Process**:
```
1. Create release/v1.4.0 branch
2. Update all kustomization files
3. Create PR
4. Wait for CI checks
5. Prompt for approval and merge
6. Deploy to dev with force build
7. Wait for dev completion
8. Prompt: Deploy to qa?
9. Wait for qa completion and ServiceNow approval
10. Prompt: Deploy to prod?
11. Wait for prod completion and ServiceNow approval
```

**Advantages**:
- ✅ Single version across all environments
- ✅ Validation between stages
- ✅ Complete CI/CD verification
- ✅ Force rebuilds all services

**When to use**:
- Major version releases
- When rebuilding all services is required
- When strict sequential deployment is needed

## ServiceNow Integration

All automated workflows integrate with ServiceNow DevOps Change Management:

### Dev Environment
- **Approval**: Auto-approved
- **State**: Automatically moves to "Implement"
- **Deployment**: Immediate after merge

### QA Environment
- **Approval**: Requires QA Lead approval
- **State**: Stays in "Assess" until approved
- **Workflow**: Pauses at approval gate, continues after approval

### Production Environment
- **Approval**: Requires CAB (Change Advisory Board) approval
- **Approvers**:
  - Change Manager
  - Application Owner
  - Security Team
- **State**: Stays in "Assess" until approved
- **Workflow**: Pauses at approval gate, continues after approval

### Approve Changes in ServiceNow

1. Navigate to: https://calitiiltddemo3.service-now.com
2. Go to: **Change Management → My Changes**
3. Find the change request (created by GitHub Actions)
4. Review details:
   - Implementation Plan
   - Test Plan
   - Backout Plan
   - Security scan results
5. **Approve** or **Reject** the change
6. Deployment continues automatically after approval

## Complete Examples

### Example 1: Standard Minor Release

```bash
# Start the automated release
just release-minor-auto

# Output:
# 📦 Bumping MINOR version: 1.3.0 → 1.4.0
# ✅ Version file updated and pushed
#
# 🟢 Deploying to DEV environment...
# 📌 Creating feature branch: feat/version-bump-dev-1.4.0
# 🧾 Creating GitHub issue (work item)
# Issue created: #123
# 🔧 Bumping version in kustomize overlay
# 📝 Commit changes
# 📤 Push branch
# 🔀 Open pull request
# ✅ Attempting to merge PR
# 🚀 Trigger MASTER-PIPELINE for dev
# ⏳ Waiting for ServiceNow approval and deployment to complete
# 🎉 Deployment completed successfully
#
# 🟡 Deploy to QA? (y/N): y
# 🟡 Deploying to QA environment (requires ServiceNow approval)...
# [Creates PR, waits for ServiceNow approval]
# ⏸️ Waiting for ServiceNow CR approval...
# 📝 Approve at: https://calitiiltddemo3.service-now.com
# [After approval in ServiceNow]
# 🎉 Deployment completed successfully
#
# 🔴 Deploy to PROD? (y/N): y
# 🔴 Deploying to PROD environment (requires ServiceNow approval)...
# [Creates PR, waits for CAB approval]
# ⏸️ Waiting for ServiceNow CR approval...
# 📝 Approve at: https://calitiiltddemo3.service-now.com
# [After CAB approval]
# 🎉 Deployment completed successfully
#
# 🎉 Release workflow complete!
# Version 1.4.0 deployed successfully
```

### Example 2: Deploy Existing Version to Specific Environment

```bash
# Deploy version 1.3.5 to dev for testing
just release-deploy-version 1.3.5 dev

# Output:
# 🚀 Deploying Version 1.3.5 to dev
# ==========================================
# [Runs demo-run workflow]
# ✅ Deployment to dev complete!
```

### Example 3: Hotfix to Production

```bash
# Create hotfix branch manually
git checkout -b hotfix/1.3.1

# Make your fixes...
git add .
git commit -m "fix: Critical security patch"
git push origin hotfix/1.3.1

# Bump patch version
just bump-patch

# Deploy directly to dev for verification
just demo-run ENV=dev TAG=1.3.1

# After verification, deploy to prod (skip qa)
just demo-run ENV=prod TAG=1.3.1
```

## Monitoring and Status

### Check Deployment Status

```bash
# Show current workflow run
just watch-deploy

# List recent deployments
just deployments

# Check version across all environments
just promotion-status 1.4.0
```

### View Logs

```bash
# View pod logs in specific environment
kubectl logs -l app=frontend -n microservices-dev --tail=50
kubectl logs -l app=frontend -n microservices-qa --tail=50
kubectl logs -l app=frontend -n microservices-prod --tail=50

# Check pod status
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod
```

### View Application URLs

```bash
# Get ALB URLs for each environment
kubectl get ingress frontend-ingress -n microservices-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress frontend-ingress -n microservices-qa -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress frontend-ingress -n microservices-prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Troubleshooting

### Issue Not Created

**Problem**: GitHub issue creation fails

**Solution**:
```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

### PR Auto-Merge Fails

**Problem**: PR cannot be merged automatically

**Possible causes**:
1. Branch protection rules require approval
2. CI checks failed
3. Merge conflicts

**Solution**:
```bash
# Check PR status
gh pr view <PR_NUMBER>

# Check CI status
gh pr checks <PR_NUMBER>

# Manually approve and merge
gh pr review <PR_NUMBER> --approve
gh pr merge <PR_NUMBER> --squash --delete-branch
```

### ServiceNow Approval Timeout

**Problem**: Deployment stuck waiting for ServiceNow approval

**Solution**:
1. Open ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: **Change Management → My Changes**
3. Find pending change request
4. Review and approve
5. Deployment will continue automatically

### Version Mismatch

**Problem**: Different versions deployed to different environments

**Solution**:
```bash
# Check current versions
just promotion-status 1.4.0

# Re-deploy specific environment
just demo-run ENV=qa TAG=1.4.0
```

## Best Practices

### 1. Always Start with Dev

```bash
# Good: Test in dev first
just demo-run ENV=dev TAG=1.4.0
# [Verify deployment]
just demo-run ENV=qa TAG=1.4.0

# Avoid: Deploying to prod without dev/qa validation
just demo-run ENV=prod TAG=1.4.0  # ❌ Risky!
```

### 2. Use Semantic Versioning

- **Major** (X.0.0): Breaking changes, major features
- **Minor** (1.X.0): New features, backwards compatible
- **Patch** (1.0.X): Bug fixes, minor updates

```bash
# New feature
just release-minor-auto  # 1.3.0 → 1.4.0

# Bug fix
just release-patch-auto  # 1.4.0 → 1.4.1
```

### 3. Review ServiceNow Change Requests

Always review the ServiceNow change request details:
- ✅ Implementation plan
- ✅ Test results
- ✅ Security scan results
- ✅ Rollback plan

### 4. Keep VERSION File in Sync

The `VERSION` file should always be bumped first:
```bash
# Good: Bump version, then deploy
just release-minor-auto

# Avoid: Using demo-run without updating VERSION file
just bump-minor
git push origin main
just demo-run ENV=dev TAG=1.4.0
```

### 5. Monitor Deployments

Always monitor the deployment progress:
```bash
# Watch GitHub Actions workflow
just watch-deploy

# Check pod status
kubectl get pods -n microservices-dev -w

# Check logs for errors
kubectl logs -l app=frontend -n microservices-dev --tail=50
```

## FAQ

### Q: Can I deploy different versions to different environments?

**A**: Yes! Use `demo-run` for each environment with different tags:
```bash
just demo-run ENV=dev TAG=1.5.0
just demo-run ENV=qa TAG=1.4.5
just demo-run ENV=prod TAG=1.4.0
```

### Q: How do I rollback a deployment?

**A**: Use the rollback command or deploy a previous version:
```bash
# Option 1: Kubernetes rollback
just rollback dev

# Option 2: Deploy previous version
just demo-run ENV=dev TAG=1.3.0
```

### Q: What happens if CI checks fail?

**A**: The workflow stops and you must fix issues:
1. Fix the issues in your branch
2. Push changes
3. Wait for CI to pass
4. Manually merge PR: `gh pr merge <PR_NUMBER> --squash --delete-branch`
5. Continue with deployment

### Q: Can I skip QA and deploy directly to prod?

**A**: Yes, but not recommended. Use `demo-run` to skip environments:
```bash
# Deploy to dev
just demo-run ENV=dev TAG=1.4.0

# Skip qa, deploy to prod (not recommended!)
just demo-run ENV=prod TAG=1.4.0
```

### Q: How do I see the GitHub issue created by demo-run?

**A**: Check the workflow output for the issue number, or view all issues:
```bash
gh issue list --label enhancement
```

## Summary

### Recommended Workflow

```bash
# 1. Start automated release
just release-minor-auto

# 2. Deploy to dev (automatic)
# → Creates issue, branch, PR
# → Merges and deploys automatically

# 3. Approve QA deployment when prompted
# → Enter 'y' to deploy to qa
# → Approve in ServiceNow

# 4. Approve prod deployment when prompted
# → Enter 'y' to deploy to prod
# → Approve via CAB in ServiceNow

# 5. Verify deployments
just promotion-status 1.4.0
```

This workflow provides:
- ✅ Complete automation
- ✅ Full audit trail
- ✅ ServiceNow integration
- ✅ Manual approval gates
- ✅ GitHub issue tracking
- ✅ Branch protection compliance
- ✅ Rollback capabilities

---

**Need help?** Run `just release-help` for a quick reference of all commands.
