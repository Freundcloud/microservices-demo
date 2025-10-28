# Release Automation Guide

> Created: 2025-10-17
> Version: 1.0.0

## Overview

This document describes the automated release and deployment workflows for Online Boutique. The automation handles version management, container builds, and deployments across dev/qa/prod environments with integrated ServiceNow change management.

## Quick Start

### Dev Deployment (Automatic)

**Trigger**: Push to `main` branch automatically triggers deployment to dev

```bash
# Make changes to src/
git add .
git commit -m "feat: Add new feature"
git push origin main
# ✅ Auto-deploys to dev environment
```

**Manual dev deployment**:
```bash
just release-dev
# Auto-increments patch version and deploys
```

### QA/Prod Deployment (Manual with ServiceNow)

**QA Deployment**:
```bash
just release-qa 1.1.0
```

**Prod Deployment**:
```bash
just release-prod 1.1.0
```

**What happens**:
1. Creates `release/1.1` branch
2. Creates `v1.1.0` Git tag
3. Builds all 11 microservices
4. Pushes to ECR with 4 tags each (v1.1.0, 1.1.0, 1.1, qa/prod)
5. Updates Kustomize overlay
6. Triggers ServiceNow change workflow
7. Waits for approval
8. Deploys to environment
9. Merges release branch back to main

## CI/CD Workflows

### Workflow 1: Auto Deploy to Dev

**File**: `.github/workflows/auto-deploy-dev.yaml`

**Triggers**:
- Push to `main` branch (when code in `src/` or `kustomize/` changes)
- Manual workflow dispatch

**Process**:
1. **Detect Changes** - Only builds/deploys changed services
2. **Run Tests** - Executes service tests (can skip if needed)
3. **Build & Push** - Builds changed services, tags with `{version}-dev-{sha}`, `dev`, `latest`
4. **Generate SBOM** - Creates Software Bill of Materials
5. **Deploy to Dev** - Applies Kustomize overlay to `microservices-dev` namespace
6. **Verify** - Checks all pods are running

**Versioning**:
- Images tagged as: `1.0.0-dev-abc1234`, `dev`, `latest`
- No Git tags created
- No release branch

**Example**:
```bash
# Automatically triggers on push to main
git push origin main

# Or manually trigger
gh workflow run auto-deploy-dev.yaml
```

### Workflow 2: ServiceNow Hybrid Deployment

**File**: `.github/workflows/deploy-with-servicenow-hybrid.yaml`

**Triggers**:
- Manual workflow dispatch with environment parameter
- Called by release script for qa/prod deployments

**Process**:
1. **Create Change Request** (via REST API)
2. **Pre-deployment Checks** - Verify EKS access, namespace
3. **Deploy** - Apply Kustomize overlay
4. **Wait for Rollout** - Ensure all pods ready
5. **Health Check** - Verify deployment
6. **Update Change** - Close with success/failure
7. **Rollback** (if deployment fails)

**Example**:
```bash
# Manually deploy to QA
gh workflow run deploy-with-servicenow-hybrid.yaml --field environment=qa

# Manually deploy to prod
gh workflow run deploy-with-servicenow-hybrid.yaml --field environment=prod
```

## Release Management Commands

### Version Bumping

```bash
# Bump major version (1.0.0 → 2.0.0)
just bump-major

# Bump minor version (1.0.0 → 1.1.0)
just bump-minor

# Bump patch version (1.0.0 → 1.0.1)
just bump-patch
```

**What happens**:
- Updates `VERSION` file
- Commits change with message: `chore: Bump version to X.Y.Z`
- Does NOT push or deploy

### Release Commands

```bash
# Quick dev release (auto-increment patch)
just release-dev

# Manual dev release with specific version
just release 1.0.1 dev

# QA release (creates branch, tag, ServiceNow change)
just release-qa 1.1.0
# OR
just release 1.1.0 qa

# Prod release (creates branch, tag, ServiceNow change)
just release-prod 1.1.0
# OR
just release 1.1.0 prod
```

### Deployment Commands

```bash
# Deploy to environment (triggers GitHub Actions)
just deploy dev      # Auto-deploys to dev
just deploy qa       # Creates ServiceNow change for qa
just deploy prod     # Creates ServiceNow change for prod

# Watch deployment progress
just watch-deploy

# List recent deployments
just deployments

# Rollback environment
just rollback dev
just rollback qa
just rollback prod
```

### Version Info

```bash
# Show current version and recent tags
just version

# Output:
# Current version: 1.0.0
# Git tags:
# v0.9.0
# v0.9.1
# v1.0.0
# v1.0.1
# v1.1.0
```

## Release Script

### Script Location

[`scripts/release.sh`](../scripts/release.sh)

### Usage

```bash
./scripts/release.sh <version> [environment]

# Examples:
./scripts/release.sh 1.0.1 dev
./scripts/release.sh 1.1.0 qa
./scripts/release.sh 1.2.0 prod
```

### Script Flow

#### For Dev Environment

1. ✅ Update VERSION file
2. ✅ Commit and push to main
3. ✅ Build all 11 microservices
4. ✅ Tag images: `v{version}`, `{version}`, `{major.minor}`, `dev`
5. ✅ Push images to ECR
6. ✅ Update `kustomize/overlays/dev/kustomization.yaml`
7. ✅ Commit and push changes
8. ✅ Trigger `auto-deploy-dev.yaml` workflow

#### For QA/Prod Environment

1. ✅ Checkout main, pull latest
2. ✅ Create release branch: `release/{major.minor}`
3. ✅ Update VERSION file
4. ✅ Commit to release branch
5. ✅ Create Git tag: `v{version}`
6. ✅ Push branch and tag
7. ✅ Build all 11 microservices
8. ✅ Tag images: `v{version}`, `{version}`, `{major.minor}`, `qa/prod`
9. ✅ Push images to ECR (44 tags total: 11 services × 4 tags)
10. ✅ Update Kustomize overlay for environment
11. ✅ Commit and push changes
12. ✅ Trigger ServiceNow hybrid workflow
13. ✅ Merge release branch back to main

### Script Features

- ✅ **Validation**: Semantic versioning check, environment validation
- ✅ **Safety**: Branch verification, confirmation prompts for non-dev
- ✅ **Automation**: Full build, tag, push, deploy pipeline
- ✅ **Error Handling**: Stops on errors, provides clear messages
- ✅ **Logging**: Color-coded output for info, success, warnings, errors

## Image Tagging Strategy

### Dev Images

```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.0.0-dev-abc1234
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:latest
```

### QA Images

```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.1.0
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.1.0
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.1
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:qa
```

### Prod Images

```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.0
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.2.0
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.2
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:prod
```

## Branching Strategy

### Main Branch

- Always deployable
- Receives dev commits
- Source for release branches

### Release Branches

- Format: `release/{major.minor}` (e.g., `release/1.1`)
- Created for QA/Prod releases
- Contains version-specific commits
- Tagged with `v{major.minor.patch}`
- Merged back to main after release

### Branch Flow

```
main
 ├── (dev commits) → auto-deploy to dev
 │
 ├── release/1.0 (created for v1.0.x releases)
 │   ├── v1.0.0 (tag)
 │   ├── v1.0.1 (tag)
 │   └── v1.0.2 (tag)
 │
 ├── release/1.1 (created for v1.1.x releases)
 │   ├── v1.1.0 (tag)
 │   └── v1.1.1 (tag)
 │
 └── release/2.0 (created for v2.0.x releases)
     └── v2.0.0 (tag)
```

## Kustomize Configuration

### Base Manifests

**Location**: `kustomize/base/`

Contains shared configuration for all environments:
- Deployments
- Services
- ConfigMaps
- ServiceAccounts

### Overlays

**Dev**: `kustomize/overlays/dev/`
- 1 replica per service
- Load generator included
- Minimal resource limits
- Namespace: `microservices-dev`

**QA**: `kustomize/overlays/qa/`
- 2 replicas per service
- Load generator included (for testing)
- Moderate resource limits
- Namespace: `microservices-qa`

**Prod**: `kustomize/overlays/prod/`
- 3 replicas per service
- No load generator
- High resource limits
- Namespace: `microservices-prod`

### Image Tag Updates

The release script automatically updates `images:` section in `kustomization.yaml`:

```yaml
images:
  - name: frontend
    newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
    newTag: v1.1.0
  - name: cartservice
    newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/cartservice
    newTag: v1.1.0
  # ... all 11 services
```

## ServiceNow Integration

### Dev Environment

**No ServiceNow change required** - deploys automatically on push to main

### QA/Prod Environments

**ServiceNow change workflow**:
1. Release script triggers `deploy-with-servicenow-hybrid.yaml`
2. Workflow creates change request via REST API
3. Change includes:
   - Short description
   - Environment
   - Implementation plan
   - Backout plan
   - Test plan
   - Correlation ID for DevOps workspace
4. **Manual approval required** in ServiceNow UI
5. Workflow waits for approval (polls every 30 seconds)
6. On approval: Deployment proceeds
7. On rejection: Workflow fails, rollback triggered
8. On success: Change closed with success
9. On failure: Change closed with failure, rollback executed

### Approval URLs

**Change List**: https://calitiiltddemo3.service-now.com/change_request_list.do

**DevOps Workspace**: https://calitiiltddemo3.service-now.com/now/devops-change/home

## Troubleshooting

### Release Script Fails

**Check**:
1. On main branch? (QA/Prod only)
2. AWS credentials loaded? (`source .envrc`)
3. Docker daemon running?
4. GitHub CLI authenticated? (`gh auth status`)

**Common fixes**:
```bash
# Switch to main
git checkout main && git pull origin main

# Load AWS credentials
source .envrc

# Start Docker
systemctl start docker  # or: open -a Docker (macOS)

# Login to GitHub
gh auth login
```

### Image Build Fails

**cartservice special handling**:
```bash
# Cart service has different Dockerfile location
cd src/cartservice/src
docker buildx build -t cartservice:local -f Dockerfile .
```

### Deployment Stalls

**Check workflow status**:
```bash
gh run watch

# Or in browser
# https://github.com/Freundcloud/microservices-demo/actions
```

**Check ServiceNow approval**:
1. Go to ServiceNow change list
2. Find your change (look for correlation ID with run number)
3. Approve or reject

### Rollback Needed

```bash
# Rollback specific environment
just rollback qa

# Or manually
kubectl rollout undo deployment --all -n microservices-qa
```

## Best Practices

### Development Workflow

1. ✅ **Small, frequent commits** to main
2. ✅ **Let dev auto-deploy** after every push
3. ✅ **Test in dev** before releasing to QA
4. ✅ **Use semantic versioning** (MAJOR.MINOR.PATCH)

### Release Workflow

1. ✅ **Test thoroughly in dev** before releasing to QA
2. ✅ **Create QA release** for testing with QA team
3. ✅ **After QA approval**, create prod release
4. ✅ **Monitor deployment** via `just watch-deploy`
5. ✅ **Verify in ServiceNow** that change is approved
6. ✅ **Check pod status** after deployment

### Version Bumping Guidelines

**MAJOR** (1.0.0 → 2.0.0):
- Breaking API changes
- Major architectural changes
- Incompatible updates

**MINOR** (1.0.0 → 1.1.0):
- New features
- Non-breaking enhancements
- New services added

**PATCH** (1.0.0 → 1.0.1):
- Bug fixes
- Small improvements
- Security patches

## Examples

### Example 1: Quick Dev Fix

```bash
# 1. Make changes
vim src/frontend/main.go

# 2. Commit and push (triggers auto-deploy)
git add src/frontend/
git commit -m "fix: Correct pricing display"
git push origin main

# 3. Watch deployment
just watch-deploy

# 4. Verify in dev
kubectl get pods -n microservices-dev
```

### Example 2: QA Release

```bash
# 1. Test in dev first
just release-dev

# 2. Verify dev works
kubectl get pods -n microservices-dev

# 3. Release to QA
just release-qa 1.1.0

# 4. Script will:
#    - Create release/1.1 branch
#    - Create v1.1.0 tag
#    - Build and push images
#    - Update Kustomize
#    - Trigger ServiceNow workflow

# 5. Approve in ServiceNow
# Visit: https://calitiiltddemo3.service-now.com/change_request_list.do

# 6. Watch deployment
just watch-deploy

# 7. Verify QA
kubectl get pods -n microservices-qa
```

### Example 3: Production Release

```bash
# 1. Ensure QA is working
kubectl get pods -n microservices-qa

# 2. Release to prod
just release-prod 1.1.0

# 3. Script builds and pushes images

# 4. Approve in ServiceNow (requires CAB approval)

# 5. Monitor deployment
just watch-deploy

# 6. Verify production
kubectl get pods -n microservices-prod

# 7. Check application URL
just k8s-url
```

### Example 4: Rollback Production

```bash
# Quick rollback
just rollback prod

# Or manual rollback to specific version
kubectl set image deployment/frontend frontend=533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.0.0 -n microservices-prod
kubectl rollout status deployment/frontend -n microservices-prod
```

## Monitoring

### Deployment Progress

```bash
# Watch current workflow
gh run watch

# List recent runs
gh run list

# View specific run
gh run view <run-id>
```

### Kubernetes Status

```bash
# Check pods
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod

# Check deployment rollout
kubectl rollout status deployment/frontend -n microservices-prod

# View logs
kubectl logs -l app=frontend -n microservices-prod --tail=50
```

### ServiceNow

**Change Requests**:
- List: https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
- DevOps Workspace: https://calitiiltddemo3.service-now.com/now/devops-change/home

## Summary

### Dev Workflow
```
Push to main → Auto-build → Auto-test → Auto-deploy to dev
```

### QA/Prod Workflow
```
just release-qa X.Y.Z → Create branch/tag → Build images →
Push to ECR → Update Kustomize → Create ServiceNow change →
Wait for approval → Deploy → Merge to main
```

### Key Benefits

1. ✅ **Automated dev deployments** - Fast feedback loop
2. ✅ **Controlled QA/Prod releases** - ServiceNow approval gates
3. ✅ **Version management** - Semantic versioning with Git tags
4. ✅ **Smart builds** - Only changed services rebuilt (dev)
5. ✅ **Multi-environment** - Consistent process across dev/qa/prod
6. ✅ **Rollback capability** - Quick rollback when needed
7. ✅ **Audit trail** - ServiceNow change records + Git history

---

**For complete command reference**: Run `just release-help`
