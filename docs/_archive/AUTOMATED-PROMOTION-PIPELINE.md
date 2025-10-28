# Automated Promotion Pipeline (Dev → QA → Prod)

> **Purpose**: Fully automated version promotion from development through production with ServiceNow integration

## Overview

This pipeline automates the complete deployment lifecycle from a single command:
- **Auto-merge** version bump PRs
- **Auto-deploy** to dev environment
- **Auto-promote** through qa and prod
- **Auto-create** ServiceNow Change Requests
- **Auto-generate** release tags

**Perfect for demos** showing complete CI/CD with ServiceNow integration!

---

## Quick Start

### One-Command Full Promotion

```bash
# Promote version 1.1.6 through all environments
just promote-all 1.1.6
```

**What this does**:
1. ✅ Triggers GitHub Actions workflow
2. ✅ Deploys to **DEV** (with ServiceNow CR)
3. ✅ Auto-promotes to **QA** (with ServiceNow CR)
4. ⏸️  Waits for manual approval for **PROD**
5. ✅ Deploys to **PROD** (with ServiceNow approval)
6. ✅ Creates release tag `v1.1.6`

---

## Available Commands

### Automated Promotion Commands

| Command | Description | Auto-Merge PR | Auto-QA | Auto-PROD |
|---------|-------------|---------------|---------|-----------|
| `just promote-all VERSION` | Full pipeline with manual prod approval | ✅ | ✅ | ⏸️ Manual |
| `just promote-all-auto VERSION` | Full pipeline with auto prod (⚠️ dangerous!) | ✅ | ✅ | ✅ Auto |
| `just promote-to-qa VERSION` | Promote from dev to qa only | - | - | - |
| `just promote-to-prod VERSION` | Promote from qa to prod only | - | - | - |
| `just promotion-status VERSION` | Check deployment status across all envs | - | - | - |

---

## Detailed Usage

### 1. Full Promotion (Recommended for Demos)

```bash
just promote-all 1.1.6
```

**Interactive Output**:
```
🚀 Starting Full Promotion Pipeline
==================================
Version: 1.1.6

This will:
  1. Create version bump PR (auto-merges when checks pass)
  2. Deploy to DEV
  3. Auto-promote to QA (after dev success)
  4. Wait for manual approval for PROD
  5. Deploy to PROD (requires ServiceNow approval)
  6. Create release tag v1.1.6

Continue? (y/N): y

✅ Full promotion pipeline started!

Track progress:
  gh run list --workflow='Full Promotion Pipeline'
  gh run watch

View in browser:
  https://github.com/Freundcloud/microservices-demo/actions/runs/12345
```

---

### 2. Check Promotion Status

```bash
just promotion-status 1.1.6
```

**Output**:
```
📊 Promotion Status for Version 1.1.6
==========================================

🔵 DEV:  ✅ Deployed
🟡 QA:   ✅ Deployed
🔴 PROD: ❌ Not deployed

🏷️  Git Tag: ❌ v1.1.6 not created
```

---

### 3. Manual Step-by-Step Promotion

If you prefer manual control over each stage:

```bash
# Step 1: Deploy to dev (using existing command)
just demo-run dev 1.1.6

# Step 2: Promote to qa
just promote-to-qa 1.1.6

# Step 3: Promote to prod
just promote-to-prod 1.1.6
```

---

## Complete Pipeline Flow

```
┌──────────────────────────────────────────────────────────────────┐
│ DEVELOPER ACTION: just promote-all 1.1.6                        │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 0: Workflow Trigger                                        │
├──────────────────────────────────────────────────────────────────┤
│ GitHub Actions: full-promotion-pipeline.yaml started             │
│ Input Parameters:                                                 │
│   - version: 1.1.6                                               │
│   - auto_promote_qa: true                                        │
│   - auto_promote_prod: false                                     │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 1: 🔵 DEV DEPLOYMENT                                      │
├──────────────────────────────────────────────────────────────────┤
│ 1. Workflow: deploy-environment.yaml (environment: dev)          │
│ 2. ServiceNow: Create Change Request                            │
│    - Title: "Deployment to dev - microservices-demo"            │
│    - Risk: low                                                   │
│    - Auto-Approved: ✅                                          │
│ 3. Kubernetes: kubectl apply -k kustomize/overlays/dev          │
│ 4. Health Check: Verify all pods running                        │
│ 5. ServiceNow: Update CR status → "Closed Successful"           │
│                                                                  │
│ Result: ✅ Dev deployment successful                            │
│ Duration: ~5-10 minutes                                         │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼ (Automatic after dev success)
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 2: 🟡 QA PROMOTION                                        │
├──────────────────────────────────────────────────────────────────┤
│ 1. Validate: Version 1.1.6 deployed in dev ✅                   │
│ 2. Workflow: promote-environments.yaml (target: qa)             │
│ 3. ServiceNow: Create Change Request                            │
│    - Title: "Deployment to qa - microservices-demo"             │
│    - Risk: low                                                   │
│    - Auto-Approved: ✅                                          │
│ 4. Kubernetes: kubectl apply -k kustomize/overlays/qa           │
│ 5. Health Check: Verify all pods running                        │
│ 6. ServiceNow: Update CR status → "Closed Successful"           │
│                                                                  │
│ Result: ✅ QA deployment successful                             │
│ Duration: ~5-10 minutes                                         │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼ (Manual approval gate)
┌──────────────────────────────────────────────────────────────────┐
│ GATE: ⏸️  MANUAL APPROVAL FOR PROD                              │
├──────────────────────────────────────────────────────────────────┤
│ Workflow Status: Waiting for approval                           │
│ GitHub Environment: prod-approval                                │
│                                                                  │
│ Action Required:                                                 │
│ 1. Go to GitHub Actions workflow run                            │
│ 2. Click "Review deployments"                                   │
│ 3. Approve "prod-approval" environment                          │
│                                                                  │
│ OR                                                               │
│                                                                  │
│ Skip this gate with: just promote-all-auto 1.1.6               │
│ (⚠️ Use with caution!)                                          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼ (After manual approval)
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 3: 🔴 PROD DEPLOYMENT                                     │
├──────────────────────────────────────────────────────────────────┤
│ 1. Validate: Version 1.1.6 deployed in qa ✅                    │
│ 2. Workflow: promote-environments.yaml (target: prod)           │
│ 3. ServiceNow: Create Change Request                            │
│    - Title: "Deployment to prod - microservices-demo"           │
│    - Risk: moderate                                              │
│    - Manual Approval Required: ⏸️                               │
│ 4. Wait for ServiceNow Approval                                 │
│    (Approver reviews CR in ServiceNow)                          │
│ 5. Kubernetes: kubectl apply -k kustomize/overlays/prod         │
│ 6. Health Check: Verify all pods running                        │
│ 7. ServiceNow: Update CR status → "Closed Successful"           │
│                                                                  │
│ Result: ✅ Prod deployment successful                           │
│ Duration: ~10-15 minutes (+ approval time)                      │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│ STAGE 4: 🏷️ RELEASE CREATION                                   │
├──────────────────────────────────────────────────────────────────┤
│ 1. Create Git Tag: v1.1.6                                       │
│ 2. Create GitHub Release                                        │
│    - Title: "Release v1.1.6"                                    │
│    - Body: Full release notes with service list                 │
│    - Tag: v1.1.6                                                │
│    - Latest: ✅                                                 │
│                                                                  │
│ Result: ✅ Release v1.1.6 published                             │
│ URL: github.com/Freundcloud/microservices-demo/releases/v1.1.6 │
└──────────────────────────────────────────────────────────────────┘
```

---

## ServiceNow Integration

Each environment deployment creates a separate Change Request:

### DEV Environment CR

```json
{
  "short_description": "Deployment to dev environment - microservices-demo",
  "risk": "low",
  "impact": "low",
  "priority": "4",
  "type": "standard",
  "u_environment": "dev",
  "approval": "auto-approved"
}
```

### QA Environment CR

```json
{
  "short_description": "Deployment to qa environment - microservices-demo",
  "risk": "low",
  "impact": "low",
  "priority": "4",
  "type": "standard",
  "u_environment": "qa",
  "approval": "auto-approved"
}
```

### PROD Environment CR

```json
{
  "short_description": "Deployment to prod environment - microservices-demo",
  "risk": "moderate",
  "impact": "medium",
  "priority": "3",
  "type": "standard",
  "u_environment": "prod",
  "approval": "manual-required"
}
```

---

## Auto-Merge Functionality

The pipeline includes automatic PR merging for version bumps:

### How It Works

1. **PR Creation**: Version bump scripts create PR with metadata
2. **Label Detection**: PR labeled with `auto-merge` or created by github-actions bot
3. **Check Wait**: Workflow waits for required checks to pass
4. **Auto-Merge**: PR automatically merged when checks complete
5. **Branch Cleanup**: Feature branch deleted after merge

### Workflow: auto-merge-version-bump.yaml

```yaml
Trigger: PR opened, synchronized, reopened, labeled
Condition: PR from github-actions bot OR has 'auto-merge' label
Actions:
  1. Wait for checks (Pipeline Initialization)
  2. Enable auto-merge
  3. Delete branch after merge
```

### Manually Label PR for Auto-Merge

```bash
# Add auto-merge label to any PR
gh pr edit <PR-NUMBER> --add-label "auto-merge"
```

---

## Safety Features

### Environment Validation

```bash
# Cannot skip environments
just promote-to-prod 1.1.6
# ❌ Error: Version 1.1.6 not deployed in qa
#    Promote to qa first: just promote-to-qa 1.1.6
```

### Confirmation Prompts

```bash
just promote-to-prod 1.1.6
# ⚠️  This will create a ServiceNow Change Request for production
#    Manual approval required in ServiceNow before deployment proceeds
#
# Continue? (y/N):
```

### Double Confirmation for Auto-PROD

```bash
just promote-all-auto 1.1.6
# ⚠️  FULL AUTO-PROMOTION TO PRODUCTION
# ====================================
# Version: 1.1.6
#
# ⚠️  WARNING: This will automatically promote to PRODUCTION
#   without manual approval gates!
#
# Are you SURE you want to auto-promote to PROD? (yes/NO):
```

---

## Troubleshooting

### Issue 1: Workflow Not Starting

**Problem**: `just promote-all 1.1.6` doesn't trigger workflow

**Checks**:
```bash
# Verify gh CLI authenticated
gh auth status

# Check workflows exist
gh workflow list

# View recent runs
gh run list --workflow="Full Promotion Pipeline"
```

**Fix**:
```bash
# Re-authenticate if needed
gh auth login

# Manually trigger workflow
gh workflow run full-promotion-pipeline.yaml \
  -f version=1.1.6 \
  -f auto_promote_qa=true \
  -f auto_promote_prod=false
```

---

### Issue 2: Auto-Merge Not Working

**Problem**: PR created but not auto-merging

**Checks**:
```bash
# Check PR status
gh pr view <PR-NUMBER>

# Check if auto-merge enabled
gh pr view <PR-NUMBER> --json autoMergeRequest
```

**Common Causes**:
- Required checks not passing
- Branch not up-to-date with main
- PR created by wrong user (not github-actions bot)
- Missing `auto-merge` label

**Fix**:
```bash
# Add auto-merge label manually
gh pr edit <PR-NUMBER> --add-label "auto-merge"

# Or merge manually
gh pr merge <PR-NUMBER> --auto --merge
```

---

### Issue 3: ServiceNow Approval Not Happening

**Problem**: Workflow stuck waiting for ServiceNow approval

**Checks**:
1. Log into ServiceNow instance
2. Navigate to: **Change Management → Open Change Requests**
3. Find CR for your deployment
4. Check approval status

**Fix**:
1. Open the Change Request
2. Click "Approve" button
3. Add approval notes
4. Workflow will resume automatically

---

### Issue 4: Promotion Fails Validation

**Problem**: `Version 1.1.6 not deployed in dev`

**Cause**: Trying to promote before previous environment is deployed

**Fix**:
```bash
# Check what's actually deployed
just promotion-status 1.1.6

# Deploy to missing environment first
just demo-run dev 1.1.6  # if missing from dev
just promote-to-qa 1.1.6  # if missing from qa
```

---

## Advanced Usage

### Custom Workflow Dispatch

Trigger workflows manually with custom parameters:

```bash
# Full control over automation
gh workflow run full-promotion-pipeline.yaml \
  -f version=1.1.6 \
  -f auto_promote_qa=true \
  -f auto_promote_prod=true
```

### Promote Specific Service Version

Combine with service-specific versioning:

```bash
# Deploy service-specific version to dev
just service-deploy dev paymentservice 1.1.5.1

# Promote that version through environments
just promote-to-qa 1.1.5.1
just promote-to-prod 1.1.5.1
```

### Skip Environments (Not Recommended)

If you really need to skip an environment (testing only):

```bash
# Update kustomization.yaml manually
echo "newTag: 1.1.6" >> kustomize/overlays/qa/kustomization.yaml
git commit -am "chore: Manual QA version update"
git push

# Then promote to prod
just promote-to-prod 1.1.6
```

⚠️ **Warning**: This bypasses safety validation. Only use for testing!

---

## Demo Script

Perfect for presenting the complete CI/CD pipeline:

```bash
# 1. Show current state
just promotion-status 1.1.5
# 📊 Shows nothing deployed

# 2. Kick off full promotion
just promote-all 1.1.6
# ✅ Confirm with 'y'

# 3. Watch in real-time
gh run watch
# Or open in browser (URL provided in output)

# 4. Narrate what's happening:
# "The pipeline is now deploying to dev..."
# "ServiceNow Change Request created automatically..."
# "Dev deployment successful, auto-promoting to QA..."
# "QA deployment complete, now we need approval for production..."

# 5. Show ServiceNow (optional)
# Open ServiceNow in browser, show Change Requests

# 6. Approve for prod
# Go to GitHub Actions, click "Review deployments", approve prod-approval

# 7. Show completion
just promotion-status 1.1.6
# 📊 All green!

# 8. Show release
gh release view v1.1.6
```

**Demo Duration**: ~15-20 minutes (including approvals)

---

## Configuration

### GitHub Secrets Required

```bash
# ServiceNow Integration
SN_DEVOPS_USER             # ServiceNow username
SN_DEVOPS_PASSWORD         # ServiceNow password
SN_INSTANCE_URL            # https://your-instance.service-now.com
SN_ORCHESTRATION_TOOL_ID   # Tool sys_id from ServiceNow

# AWS Credentials
AWS_ACCESS_KEY_ID          # AWS access key
AWS_SECRET_ACCESS_KEY      # AWS secret key
AWS_ACCOUNT_ID             # AWS account ID
```

### Workflow Configuration

Edit `.github/workflows/full-promotion-pipeline.yaml`:

```yaml
# Change default auto-promotion settings
inputs:
  auto_promote_qa:
    default: true   # Change to false for manual QA approval
  auto_promote_prod:
    default: false  # Change to true for auto prod (⚠️ dangerous!)
```

---

## Related Documentation

- [Service-Specific Versioning](SERVICE-SPECIFIC-VERSIONING.md) - Deploy individual services
- [ServiceNow Integration](SERVICENOW-INTEGRATION.md) - Complete ServiceNow setup
- [Multi-Environment Kustomize](../kustomize/overlays/README.md) - Environment configuration

---

## Summary

The automated promotion pipeline provides:

✅ **One-Command Deployment**: `just promote-all VERSION`
✅ **Auto-Merge PRs**: No manual PR handling
✅ **Auto-Promotion**: Dev → QA → Prod progression
✅ **ServiceNow Integration**: Complete audit trail
✅ **Safety Gates**: Manual approval for production
✅ **Release Management**: Auto-tagging and releases
✅ **Status Tracking**: Check deployment status anytime
✅ **Demo-Ready**: Perfect for CI/CD presentations

**Use this for**: Demos, automated deployments, complete CI/CD lifecycle showcases

🤖 Generated with [Claude Code](https://claude.com/claude-code)
