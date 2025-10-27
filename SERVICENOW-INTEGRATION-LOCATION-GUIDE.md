# ServiceNow Integration - Where Is It and How Does It Work?

> **Quick Answer**: ServiceNow integration is in **4 GitHub Actions workflows** that work together

---

## Overview: The Complete Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER COMMAND                              │
│                  just promote-all 1.1.8                      │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 1. FULL PROMOTION PIPELINE                                   │
│    .github/workflows/full-promotion-pipeline.yaml            │
│                                                              │
│    ┌──────────────────────────────────────────────┐         │
│    │ update-dev-version                           │         │
│    │ - Updates kustomization.yaml                 │         │
│    │ - No ServiceNow (just git commit)            │         │
│    └──────────────────────────────────────────────┘         │
│                       ↓                                      │
│    ┌──────────────────────────────────────────────┐         │
│    │ deploy-dev                                   │         │
│    │ Calls → deploy-environment.yaml              │         │
│    │   ├─ ServiceNow Change Request ✅            │         │
│    │   ├─ ServiceNow Config Upload ✅             │         │
│    │   └─ Kubernetes Deployment                   │         │
│    └──────────────────────────────────────────────┘         │
│                       ↓                                      │
│    ┌──────────────────────────────────────────────┐         │
│    │ promote-to-qa                                │         │
│    │ Calls → promote-environments.yaml            │         │
│    │   ├─ ServiceNow Change Request ✅            │         │
│    │   ├─ PAUSES for approval ⏸️                 │         │
│    │   ├─ ServiceNow Config Upload ✅             │         │
│    │   └─ Kubernetes Deployment                   │         │
│    └──────────────────────────────────────────────┘         │
│                       ↓                                      │
│    ┌──────────────────────────────────────────────┐         │
│    │ promote-to-prod                              │         │
│    │ Calls → promote-environments.yaml            │         │
│    │   ├─ ServiceNow Change Request ✅            │         │
│    │   ├─ PAUSES for approval ⏸️                 │         │
│    │   ├─ ServiceNow Config Upload ✅             │         │
│    │   └─ Kubernetes Deployment                   │         │
│    └──────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘

PLUS (runs separately during image builds):

┌─────────────────────────────────────────────────────────────┐
│ 2. BUILD IMAGES PIPELINE                                     │
│    .github/workflows/build-images.yaml                       │
│                                                              │
│    For each of 12 services:                                 │
│    ┌──────────────────────────────────────────────┐         │
│    │ - Run unit tests                             │         │
│    │ - Upload test results → ServiceNow ✅        │         │
│    │ - Build Docker image                         │         │
│    │ - Push to ECR                                │         │
│    │ - Register package → ServiceNow ✅           │         │
│    └──────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## The 4 Core ServiceNow Integration Files

### 1. **servicenow-change.yaml** - Change Request Creator
📁 **Location**: `.github/workflows/servicenow-change.yaml`

**What it does**: Creates ServiceNow Change Requests

**Used by**:
- deploy-environment.yaml
- promote-environments.yaml

**ServiceNow Action**: `ServiceNow/servicenow-devops-change@v6.1.0`

**Code snippet**:
```yaml
- name: Create Change Request (DEV - Auto-Approve)
  if: inputs.environment == 'dev'
  uses: ServiceNow/servicenow-devops-change@v6.1.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    change-request: |
      {
        "setCloseCode": "true",
        "autoCloseChange": true,
        "attributes": {
          "state": "implement",
          "priority": "3"
        }
      }
```

**View the full file**:
```bash
cat .github/workflows/servicenow-change.yaml
```

---

### 2. **deploy-environment.yaml** - Deployment with Evidence
📁 **Location**: `.github/workflows/deploy-environment.yaml`

**What it does**: Deploys to Kubernetes and uploads evidence

**ServiceNow integrations** (2):
1. **Creates Change Request** (via servicenow-change.yaml)
2. **Uploads Kubernetes Configs** (via config-validate action)

**Code snippet - Change Request**:
```yaml
jobs:
  servicenow-change:
    name: ServiceNow Change Request
    uses: ./.github/workflows/servicenow-change.yaml
    with:
      environment: ${{ inputs.environment }}
      change_type: 'kubernetes'
      short_description: 'Deploy microservices to ${{ inputs.environment }}'
      implementation_plan: |
        1. Configure kubectl access to EKS cluster
        2. Apply Kustomize overlays
        3. Verify all pods healthy
      backout_plan: |
        1. kubectl rollout undo
      test_plan: |
        1. Verify deployments succeeded
        2. Test application endpoints
```

**Code snippet - Config Upload**:
```yaml
- name: Upload Deployment Config to ServiceNow
  uses: ServiceNow/servicenow-devops-config-validate@v1.0.0-beta
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-username: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    application-name: 'microservices-demo'
    deployable-name: '${{ inputs.environment }}'
    config-file-path: 'kustomize/overlays/${{ inputs.environment }}/*.yaml'
    data-format: 'yaml'
    auto-commit: true
    auto-validate: true
    auto-publish: true
```

**View the full file**:
```bash
cat .github/workflows/deploy-environment.yaml
```

**Line numbers for ServiceNow integration**:
- Lines 45-79: servicenow-change job
- Lines 157-175: config-validate step

---

### 3. **build-images.yaml** - Test Results & Package Registration
📁 **Location**: `.github/workflows/build-images.yaml`

**What it does**: Builds Docker images and uploads evidence

**ServiceNow integrations** (2):
1. **Uploads Unit Test Results**
2. **Registers Docker Packages**

**Code snippet - Test Results**:
```yaml
- name: Upload Test Results to ServiceNow
  if: steps.find-test-results.outputs.found == 'true'
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: ${{ steps.find-test-results.outputs.path }}
```

**Code snippet - Package Registration**:
```yaml
- name: Register Package with ServiceNow
  if: inputs.push_images
  uses: ServiceNow/servicenow-devops-register-package@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    artifacts: '[{"name": "${{ env.ECR_REGISTRY }}/${{ matrix.service }}",
                  "version": "${{ inputs.environment }}-${{ github.sha }}"}]'
    package-name: '${{ matrix.service }}-${{ inputs.environment }}-${{ github.run_number }}.package'
```

**View the full file**:
```bash
cat .github/workflows/build-images.yaml
```

**Line numbers for ServiceNow integration**:
- Lines ~380-392: Upload Test Results
- Lines ~395-407: Register Package

---

### 4. **promote-environments.yaml** - Promotion Orchestrator
📁 **Location**: `.github/workflows/promote-environments.yaml`

**What it does**: Promotes versions between environments

**ServiceNow integration**: Calls deploy-environment.yaml which has ServiceNow integration

**Code snippet**:
```yaml
deploy-target:
  name: "Deploy to ${{ inputs.target_environment }}"
  needs: validate-promotion
  uses: ./.github/workflows/deploy-environment.yaml  # ← Has ServiceNow integration
  with:
    environment: ${{ inputs.target_environment }}
    wait_for_ready: true
  secrets: inherit
```

**View the full file**:
```bash
cat .github/workflows/promote-environments.yaml
```

---

## ServiceNow Actions Used

### Official ServiceNow GitHub Actions

| Action | Version | Purpose |
|--------|---------|---------|
| `servicenow-devops-change` | v6.1.0 | Create Change Requests |
| `servicenow-devops-config-validate` | v1.0.0-beta | Upload Kubernetes configs |
| `servicenow-devops-test-report` | v6.0.0 | Upload test results |
| `servicenow-devops-register-package` | v3.1.0 | Register Docker packages |

**Documentation**: https://github.com/ServiceNow/servicenow-devops-change

---

## Required GitHub Secrets

All ServiceNow integrations need these 4 secrets:

```bash
# View configured secrets
gh secret list --repo Freundcloud/microservices-demo

# Required secrets:
SERVICENOW_USERNAME          # ServiceNow username
SERVICENOW_PASSWORD          # ServiceNow password
SERVICENOW_INSTANCE_URL      # e.g., https://instance.service-now.com
SN_ORCHESTRATION_TOOL_ID     # Tool ID from ServiceNow DevOps config
```

**Set secrets**:
```bash
gh secret set SERVICENOW_USERNAME --body "your-username"
gh secret set SERVICENOW_PASSWORD --body "your-password"
gh secret set SERVICENOW_INSTANCE_URL --body "https://instance.service-now.com"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "tool-id-from-servicenow"
```

---

## How It Works: Step-by-Step Example

### When you run: `just promote-all 1.1.8`

**Step 1: Workflow Triggers**
```bash
gh workflow run full-promotion-pipeline.yaml -f version=1.1.8
```

**Step 2: Update Dev Kustomization** (no ServiceNow)
```
Job: update-dev-version
- Updates kustomize/overlays/dev/kustomization.yaml
- Commits to git
```

**Step 3: Deploy to DEV** ← **ServiceNow Integration #1**
```
Job: deploy-dev
├─ Calls: deploy-environment.yaml
│
├─ ServiceNow Job 1: servicenow-change
│  └─ Action: ServiceNow/servicenow-devops-change@v6.1.0
│     ├─ Creates Change Request in ServiceNow
│     ├─ State: "implement" (auto-approved for DEV)
│     ├─ Adds implementation/backout/test plans
│     └─ Returns: CR Number (e.g., CHG0030145)
│
├─ Deploy Job: deploy
│  ├─ kubectl apply -k kustomize/overlays/dev
│  │
│  └─ ServiceNow Step: Upload Deployment Config
│     └─ Action: ServiceNow/servicenow-devops-config-validate@v1.0.0-beta
│        ├─ Uploads all YAML files from kustomize/overlays/dev/
│        ├─ Creates configuration snapshot
│        └─ Attaches to Change Request
```

**Step 4: Promote to QA** ← **ServiceNow Integration #2**
```
Job: promote-to-qa
├─ Calls: promote-environments.yaml
│  └─ Calls: deploy-environment.yaml
│
├─ ServiceNow Job: servicenow-change
│  └─ Action: ServiceNow/servicenow-devops-change@v6.1.0
│     ├─ Creates Change Request in ServiceNow
│     ├─ State: "assess" (requires approval for QA)
│     ├─ Workflow PAUSES here ⏸️
│     └─ Waits for ServiceNow approval
│
├─ (Approver reviews in ServiceNow and approves)
│
└─ Deploy Job: (continues after approval)
   └─ ServiceNow Step: Upload Deployment Config
      └─ Uploads QA Kubernetes configs
```

**Step 5: Promote to PROD** ← **ServiceNow Integration #3**
```
Job: promote-to-prod
├─ Same as QA but for PROD environment
├─ Creates Change Request (requires approval)
├─ Workflow PAUSES ⏸️
├─ Waits for ServiceNow approval
└─ Deploys after approval
```

---

## Separately: Build Pipeline ServiceNow Integration

When Docker images are built (triggered by code changes):

**Workflow**: `build-images.yaml`

**For each service** (12 total):
```
1. Run unit tests (Go/C#/Java/Python/Node.js)
   ↓
2. ServiceNow Integration: Upload Test Results
   Action: ServiceNow/servicenow-devops-test-report@v6.0.0
   ├─ Converts test output to JUnit XML
   ├─ Uploads to ServiceNow
   └─ Attaches to job/CR
   ↓
3. Build Docker image
   ↓
4. Push to ECR
   ↓
5. ServiceNow Integration: Register Package
   Action: ServiceNow/servicenow-devops-register-package@v3.1.0
   ├─ Registers Docker image in ServiceNow
   ├─ Includes: ECR URL, version, commit SHA
   └─ Creates package artifact
```

---

## Quick Reference: Where to Find ServiceNow Code

### View ServiceNow Integration Code

```bash
# 1. Change Request creation
cat .github/workflows/servicenow-change.yaml

# 2. Kubernetes deployment (with config upload)
cat .github/workflows/deploy-environment.yaml | grep -A 20 "servicenow"

# 3. Test results & package registration
cat .github/workflows/build-images.yaml | grep -A 15 "ServiceNow"

# 4. Promotion workflow
cat .github/workflows/promote-environments.yaml
```

### View in GitHub

```bash
# Open workflows in browser
gh workflow view servicenow-change.yaml --web
gh workflow view deploy-environment.yaml --web
gh workflow view build-images.yaml --web
```

---

## Testing the Integration

### Test Change Request Creation

```bash
# Deploy to dev (auto-approved)
gh workflow run deploy-environment.yaml \
  -f environment=dev \
  -f wait_for_ready=true

# Check for Change Request in ServiceNow
# Should see: CHG number in workflow logs
```

### Test Full Integration

```bash
# Full promotion with all ServiceNow integrations
just promote-all 1.1.8

# Watch the workflow
gh run watch

# Check ServiceNow:
# 1. Change Requests created (3 total: dev, qa, prod)
# 2. Test results uploaded (10 services)
# 3. Packages registered (12 services)
# 4. Configs uploaded (3 snapshots: dev, qa, prod)
```

---

## Troubleshooting

### ServiceNow Integration Not Working?

**Check 1: Secrets configured**
```bash
gh secret list | grep SERVICENOW
# Should show: SERVICENOW_USERNAME, SERVICENOW_PASSWORD,
#              SERVICENOW_INSTANCE_URL, SN_ORCHESTRATION_TOOL_ID
```

**Check 2: Workflow logs**
```bash
gh run view --log-failed | grep -i servicenow
```

**Check 3: ServiceNow plugin enabled**
```
ServiceNow → System Applications → DevOps Change
Status: Active
```

**Check 4: Action continues even if ServiceNow fails**
All ServiceNow steps have `continue-on-error: true`, so deployments succeed even if ServiceNow is unavailable.

---

## Summary

### **Where is ServiceNow integration?**

| Workflow | ServiceNow Actions | Purpose |
|----------|-------------------|---------|
| `servicenow-change.yaml` | Change request | Creates CRs |
| `deploy-environment.yaml` | Change + Config | Deploys with evidence |
| `build-images.yaml` | Test + Package | Build evidence |
| `promote-environments.yaml` | (via deploy) | Orchestrates promotion |

### **What gets uploaded?**

✅ Change Requests (1 per deployment)
✅ Test Results (10 per build)
✅ Docker Packages (12 per build)
✅ Kubernetes Configs (15 files per deployment)

### **When does it happen?**

- **Change Request**: Before every deployment
- **Test Results**: During Docker build
- **Packages**: After Docker push
- **Configs**: Before Kubernetes deployment

---

**Next**: Run `just promote-all 1.1.8` and watch the ServiceNow integration in action! 🚀
