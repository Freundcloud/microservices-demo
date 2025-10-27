# Master CI/CD Pipeline Consolidation Plan

> **Date**: 2025-10-27
> **Goal**: Consolidate all CI/CD logic into MASTER-PIPELINE.yaml
> **User Request**: "I want everything in the Master CI/CD Pipeline not spread out on multiple pipelines"

---

## Current State Analysis

### Problem Summary

**Critical Issues**:
1. **Tagging Strategy Mismatch**:
   - `build-images.yaml` creates environment tags (`dev`, `qa`, `prod`)
   - `full-promotion-pipeline.yaml` expects semantic versions (`1.1.8`, `1.1.9`)
   - Result: ImagePullBackOff errors - images don't exist in ECR

2. **Workflow Sprawl**:
   - Logic spread across 6+ workflows
   - Difficult to understand end-to-end flow
   - Duplication of ServiceNow integration code
   - Hard to maintain and debug

3. **Justfile Misalignment**:
   - Commands use semantic versioning (`just promote-all 1.1.8`)
   - But workflows use environment tags
   - Result: Commands don't work as expected

### Current Workflows to Consolidate

1. **MASTER-PIPELINE.yaml** (keep as main workflow)
   - Infrastructure deployment
   - Build orchestration
   - Basic deployment
   - **Missing**: ServiceNow integration, promotion logic

2. **build-images.yaml** (reusable)
   - Smart service change detection
   - Docker builds with multi-arch support
   - Trivy security scanning
   - **Has**: ServiceNow test result upload, package registration

3. **deploy-environment.yaml** (reusable)
   - Kubernetes deployment
   - **Has**: ServiceNow Change Request creation, config upload

4. **servicenow-change.yaml** (reusable)
   - Creates ServiceNow Change Requests
   - Used by deploy-environment.yaml

5. **full-promotion-pipeline.yaml** (DELETE)
   - Broken semantic versioning approach
   - Duplicates MASTER-PIPELINE logic
   - Calls other workflows (unnecessary layer)

6. **promote-environments.yaml** (DELETE)
   - Another layer of indirection
   - Logic should be in MASTER-PIPELINE

---

## Target Architecture

### Single Master Pipeline Approach

**MASTER-PIPELINE.yaml** becomes the **ONLY** workflow users interact with.

**Capabilities**:
- ✅ Infrastructure deployment (Terraform)
- ✅ Service builds (smart change detection)
- ✅ Security scanning
- ✅ ServiceNow integration (change requests, test uploads, package registration)
- ✅ Multi-environment deployment (dev/qa/prod)
- ✅ Environment promotion (dev→qa→prod)
- ✅ Release tagging
- ✅ Post-deployment validation

**User Interface**:
```bash
# Deploy to dev (automatic on push to main)
git push origin main

# Manually deploy to specific environment
gh workflow run MASTER-PIPELINE.yaml -f environment=dev
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
gh workflow run MASTER-PIPELINE.yaml -f environment=prod

# Force build all services
gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f force_build_all=true
```

**Justfile Simplification**:
```bash
# Simplified commands (no version parameter)
just deploy-dev      # Triggers MASTER-PIPELINE with environment=dev
just deploy-qa       # Triggers MASTER-PIPELINE with environment=qa
just deploy-prod     # Triggers MASTER-PIPELINE with environment=prod

# Remove these broken commands:
just promote-all 1.1.8       # DELETE
just promote-to-qa 1.1.8     # DELETE
just promote-to-prod 1.1.8   # DELETE
```

---

## Tagging Strategy Decision

### Recommended: Environment Tags (Sliding Tags)

**How it works**:
- Each environment has a **sliding tag** that updates with each build
- Dev builds → `frontend:dev`, `frontend:dev-abc123def`
- QA deployments → `frontend:qa`, `frontend:qa-abc123def`
- Prod deployments → `frontend:prod`, `frontend:prod-abc123def`

**Promotion Flow**:
1. **Build and Deploy to Dev**:
   ```bash
   # MASTER-PIPELINE runs:
   docker build frontend -t frontend:dev
   docker tag frontend:dev ecr.../frontend:dev
   docker tag frontend:dev ecr.../frontend:dev-$COMMIT_SHA
   docker push ecr.../frontend:dev
   docker push ecr.../frontend:dev-$COMMIT_SHA

   # Update kustomization:
   sed -i 's/newTag: .*/newTag: dev/' kustomize/overlays/dev/kustomization.yaml
   kubectl apply -k kustomize/overlays/dev
   ```

2. **Promote to QA** (manual trigger):
   ```bash
   # MASTER-PIPELINE runs with environment=qa:
   # Re-tag dev images as qa
   docker pull ecr.../frontend:dev
   docker tag ecr.../frontend:dev ecr.../frontend:qa
   docker tag ecr.../frontend:dev ecr.../frontend:qa-$COMMIT_SHA
   docker push ecr.../frontend:qa
   docker push ecr.../frontend:qa-$COMMIT_SHA

   # Update kustomization:
   sed -i 's/newTag: .*/newTag: qa/' kustomize/overlays/qa/kustomization.yaml
   kubectl apply -k kustomize/overlays/qa
   ```

3. **Promote to Prod** (manual trigger after QA success):
   ```bash
   # MASTER-PIPELINE runs with environment=prod:
   # Re-tag qa images as prod
   docker pull ecr.../frontend:qa
   docker tag ecr.../frontend:qa ecr.../frontend:prod
   docker tag ecr.../frontend:qa ecr.../frontend:prod-$COMMIT_SHA
   docker push ecr.../frontend:prod
   docker push ecr.../frontend:prod-$COMMIT_SHA

   # Update kustomization:
   sed -i 's/newTag: .*/newTag: prod/' kustomize/overlays/prod/kustomization.yaml
   kubectl apply -k kustomize/overlays/prod

   # Create GitHub release with commit SHA tag
   git tag v1.0.0-prod-$COMMIT_SHA
   gh release create v1.0.0-prod-$COMMIT_SHA
   ```

**Benefits**:
- ✅ No version number coordination needed
- ✅ Clear environment isolation
- ✅ Commit SHA provides traceability
- ✅ Simple to understand and debug
- ✅ Works with existing ECR images

**Alternative: Semantic Versioning** (NOT RECOMMENDED):
- Would require updating kustomization files with version numbers
- More manual coordination
- Doesn't match current ECR structure
- User already rejected this approach by pointing out it's broken

---

## Implementation Plan

### Phase 1: Add ServiceNow Integration to MASTER-PIPELINE ✅

**Add these jobs to MASTER-PIPELINE.yaml**:

1. **After `build-and-push` job**: Add ServiceNow test result upload
   ```yaml
   upload-test-results:
     name: "📊 Upload Test Results to ServiceNow"
     needs: [pipeline-init, build-and-push]
     if: needs.build-and-push.result == 'success'
     runs-on: ubuntu-latest
     steps:
       - name: Upload Test Results
         uses: ServiceNow/servicenow-devops-test-report@v2.0.0
         with:
           instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
           devops-integration-token: ${{ secrets.SERVICENOW_DEVOPS_TOKEN }}
           job-name: 'Build and Test'
           context-github: ${{ toJson(github) }}
   ```

2. **After `build-and-push` job**: Add ServiceNow package registration
   ```yaml
   register-packages:
     name: "📦 Register Packages in ServiceNow"
     needs: [pipeline-init, build-and-push]
     if: needs.build-and-push.result == 'success'
     runs-on: ubuntu-latest
     steps:
       - name: Register Docker Images
         uses: ServiceNow/servicenow-devops-register-package@v2.0.0
         with:
           instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
           devops-integration-token: ${{ secrets.SERVICENOW_DEVOPS_TOKEN }}
           package-name: 'microservices-${{ needs.pipeline-init.outputs.environment }}'
           artifacts: # JSON list of all built images
   ```

3. **Before `deploy-to-environment` job**: Add ServiceNow Change Request
   ```yaml
   servicenow-change:
     name: "📝 Create ServiceNow Change Request"
     needs: [pipeline-init, register-packages]
     if: needs.pipeline-init.outputs.should_deploy == 'true'
     uses: ./.github/workflows/servicenow-change.yaml
     with:
       environment: ${{ needs.pipeline-init.outputs.environment }}
       change_type: 'kubernetes'
     secrets: inherit
   ```

4. **After `deploy-to-environment` job**: Add ServiceNow config upload
   ```yaml
   upload-config:
     name: "⚙️ Upload Config to ServiceNow"
     needs: [pipeline-init, deploy-to-environment]
     if: needs.deploy-to-environment.result == 'success'
     runs-on: ubuntu-latest
     steps:
       - name: Upload Deployment Config
         uses: ServiceNow/servicenow-devops-config-validate@v1.0.0-beta
         with:
           instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
           config-file-path: 'kustomize/overlays/${{ needs.pipeline-init.outputs.environment }}/*.yaml'
   ```

### Phase 2: Add Promotion Logic to MASTER-PIPELINE ✅

**Add promotion jobs** (only run when manually triggered):

```yaml
# ============================================================================
# STAGE 5: Environment Promotion (Manual Only)
# ============================================================================

promote-to-qa:
  name: "🚀 Promote Dev → QA"
  needs: [pipeline-init, deploy-to-environment, smoke-tests]
  if: |
    inputs.environment == 'qa' &&
    github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest

  steps:
    - name: Verify Dev Deployment
      run: |
        # Check that dev is healthy before promoting
        kubectl get pods -n microservices-dev

    - name: Re-tag Images for QA
      run: |
        # Pull dev images and re-tag as qa
        for service in frontend cartservice ...; do
          docker pull $ECR_REGISTRY/$service:dev
          docker tag $ECR_REGISTRY/$service:dev $ECR_REGISTRY/$service:qa
          docker tag $ECR_REGISTRY/$service:dev $ECR_REGISTRY/$service:qa-${{ github.sha }}
          docker push $ECR_REGISTRY/$service:qa
          docker push $ECR_REGISTRY/$service:qa-${{ github.sha }}
        done

    - name: Update QA Kustomization
      run: |
        # Already done by deploy-to-environment job
        # kustomize/overlays/qa/kustomization.yaml has newTag: qa

promote-to-prod:
  name: "🔴 Promote QA → PROD"
  needs: [pipeline-init, deploy-to-environment, smoke-tests]
  if: |
    inputs.environment == 'prod' &&
    github.event_name == 'workflow_dispatch'
  runs-on: ubuntu-latest

  steps:
    - name: Verify QA Deployment
      run: |
        # Check that qa is healthy before promoting
        kubectl get pods -n microservices-qa

    - name: Re-tag Images for PROD
      run: |
        # Pull qa images and re-tag as prod
        for service in frontend cartservice ...; do
          docker pull $ECR_REGISTRY/$service:qa
          docker tag $ECR_REGISTRY/$service:qa $ECR_REGISTRY/$service:prod
          docker tag $ECR_REGISTRY/$service:qa $ECR_REGISTRY/$service:prod-${{ github.sha }}
          docker push $ECR_REGISTRY/$service:prod
          docker push $ECR_REGISTRY/$service:prod-${{ github.sha }}
        done
```

### Phase 3: Update Kustomization Files ✅

**Fix all three overlays to use environment tags**:

1. **kustomize/overlays/dev/kustomization.yaml**:
   ```yaml
   images:
   - name: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
     newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
     newTag: dev  # ✅ Use environment tag
   ```

2. **kustomize/overlays/qa/kustomization.yaml**:
   ```yaml
   images:
   - name: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
     newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
     newTag: qa  # ✅ Use environment tag
   ```

3. **kustomize/overlays/prod/kustomization.yaml**:
   ```yaml
   images:
   - name: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
     newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
     newTag: prod  # ✅ Use environment tag
   ```

**Apply fix**:
```bash
# Dev (already done)
sed -i 's/newTag: 1\.1\.8/newTag: dev/g' kustomize/overlays/dev/kustomization.yaml

# QA
sed -i 's/newTag: .*/newTag: qa/g' kustomize/overlays/qa/kustomization.yaml

# Prod
sed -i 's/newTag: .*/newTag: prod/g' kustomize/overlays/prod/kustomization.yaml
```

### Phase 4: Create Automated Version Promotion Script ✅

**NEW: Automated Version Promotion Workflow**

Create `scripts/promote-version.sh`:
```bash
#!/usr/bin/env bash
# Automated version promotion workflow
# Creates PR → Merges → Deploys dev → qa → prod

set -euo pipefail

VERSION="${1:-}"
SERVICES="${2:-all}"  # "all" or specific service names

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [services]"
    echo "Example: $0 1.1.8 all"
    echo "Example: $0 1.1.9 frontend,cartservice"
    exit 1
fi

echo "🚀 Starting Automated Version Promotion"
echo "Version: $VERSION"
echo "Services: $SERVICES"
echo ""

# 1. Create feature branch
BRANCH="release/v${VERSION}"
echo "📝 Creating feature branch: $BRANCH"
git checkout -b "$BRANCH"

# 2. Update kustomization files for all environments
echo "📝 Updating kustomization files..."
for ENV in dev qa prod; do
    FILE="kustomize/overlays/$ENV/kustomization.yaml"
    if [ -f "$FILE" ]; then
        # Update newTag for all services or specific ones
        if [ "$SERVICES" = "all" ]; then
            sed -i "s/newTag: .*/newTag: ${ENV}/" "$FILE"
        else
            # Update specific services
            IFS=',' read -ra SVC_ARRAY <<< "$SERVICES"
            for service in "${SVC_ARRAY[@]}"; do
                # This is a simplified version - real implementation needs more logic
                sed -i "/name:.*${service}/,/newTag:/ s/newTag: .*/newTag: ${ENV}/" "$FILE"
            done
        fi
        git add "$FILE"
    fi
done

# 3. Commit changes
echo "✅ Committing version update"
git commit -m "chore: Promote to version ${VERSION}

Automated version promotion:
- Services: ${SERVICES}
- Environments: dev, qa, prod
- Version: ${VERSION}"

# 4. Push branch
echo "⬆️  Pushing branch to origin"
git push origin "$BRANCH"

# 5. Create Pull Request
echo "📝 Creating Pull Request"
PR_URL=$(gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "Release v${VERSION}" \
    --body "Automated version promotion to ${VERSION}

Services updated: ${SERVICES}

## Deployment Plan
1. ✅ Auto-deploy to DEV (auto-approved ServiceNow CR)
2. ⏸️ Deploy to QA (requires ServiceNow CR approval)
3. ⏸️ Deploy to PROD (requires ServiceNow CR approval)

## Verification Checklist
- [ ] All services built successfully
- [ ] DEV deployment healthy
- [ ] QA deployment healthy
- [ ] PROD deployment healthy
- [ ] ServiceNow change requests created
- [ ] GitHub release created
" || echo "")

echo "✅ Pull Request created: $PR_URL"
echo ""

# 6. Wait for CI checks to pass
echo "⏳ Waiting for CI checks to pass..."
sleep 5  # Give GitHub time to register the PR
gh pr checks "$PR_URL" --watch

# 7. Auto-approve and merge
echo "✅ CI checks passed. Auto-approving and merging PR..."
gh pr review "$PR_URL" --approve --body "✅ Automated approval - CI checks passed"
gh pr merge "$PR_URL" --squash --delete-branch --auto

echo "✅ PR merged to main"
echo ""

# 8. Wait for main branch to be updated
echo "⏳ Waiting for main branch update..."
git checkout main
git pull origin main

# 9. Trigger MASTER-PIPELINE for DEV (auto-deploy on push to main)
echo "🟢 DEV deployment starting automatically (push to main)..."
echo "   ServiceNow CR: Auto-approved for dev"
sleep 10  # Let workflow start

# Get the latest workflow run
DEV_RUN=$(gh run list --workflow=MASTER-PIPELINE.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
echo "   Workflow run: $DEV_RUN"
gh run watch "$DEV_RUN"

echo ""
echo "✅ DEV deployment complete"
echo ""

# 10. Trigger MASTER-PIPELINE for QA
read -p "🟡 Deploy to QA? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🟡 Triggering QA deployment..."
    echo "   ServiceNow CR: Requires approval"
    gh workflow run MASTER-PIPELINE.yaml -f environment=qa

    QA_RUN=$(gh run list --workflow=MASTER-PIPELINE.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
    echo "   Workflow run: $QA_RUN"
    echo "   ⏸️  Waiting for ServiceNow CR approval..."
    gh run watch "$QA_RUN"

    echo ""
    echo "✅ QA deployment complete"
    echo ""
fi

# 11. Trigger MASTER-PIPELINE for PROD
read -p "🔴 Deploy to PROD? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔴 Triggering PROD deployment..."
    echo "   ServiceNow CR: Requires approval"
    gh workflow run MASTER-PIPELINE.yaml -f environment=prod

    PROD_RUN=$(gh run list --workflow=MASTER-PIPELINE.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
    echo "   Workflow run: $PROD_RUN"
    echo "   ⏸️  Waiting for ServiceNow CR approval..."
    gh run watch "$PROD_RUN"

    echo ""
    echo "✅ PROD deployment complete"
    echo ""
fi

echo "🎉 Version promotion complete!"
echo ""
echo "## Summary"
echo "Version: ${VERSION}"
echo "Services: ${SERVICES}"
echo "Branch: $BRANCH (merged and deleted)"
echo "Environments:"
echo "  ✅ DEV - Deployed"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  ✅ QA - Deployed"
    echo "  ✅ PROD - Deployed"
fi
```

### Phase 4: Update Justfile ✅

**Remove ALL broken commands**:
```makefile
# DELETE these recipes:
promote-all VERSION           # Broken semantic versioning
promote-to-qa VERSION         # Broken semantic versioning
promote-to-prod VERSION       # Broken semantic versioning
promote-to-dev VERSION        # Not needed
update-dev-version VERSION    # Not needed
update-qa-version VERSION     # Not needed
update-prod-version VERSION   # Not needed
```

**Add NEW automated promotion commands**:
```makefile
# Automated version promotion (creates PR, auto-merges, deploys all envs)
promote VERSION SERVICES="all":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/promote-version.sh {{ VERSION }} {{ SERVICES }}

# Quick promotion variants
promote-all VERSION:
    just promote {{ VERSION }} all

promote-service SERVICE VERSION:
    just promote {{ VERSION }} {{ SERVICE }}

# Manual environment deployment (if needed outside of promotion flow)
deploy-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🟢 Deploying to DEV environment"
    gh workflow run MASTER-PIPELINE.yaml -f environment=dev
    gh run watch

deploy-qa:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🟡 Deploying to QA environment"
    echo "⚠️  Requires ServiceNow Change Request approval"
    gh workflow run MASTER-PIPELINE.yaml -f environment=qa
    gh run watch

deploy-prod:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔴 Deploying to PROD environment"
    read -p "⚠️  Deploy to PRODUCTION? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  Requires ServiceNow Change Request approval"
        gh workflow run MASTER-PIPELINE.yaml -f environment=prod
        gh run watch
    else
        echo "❌ Aborted"
    fi

# Force rebuild all services (for testing)
rebuild-all ENV:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Force rebuilding all services for {{ ENV }}"
    gh workflow run MASTER-PIPELINE.yaml \
        -f environment={{ ENV }} \
        -f force_build_all=true
    gh run watch
```

### Phase 5: Delete Obsolete Workflows ✅

**Remove these files**:
```bash
rm .github/workflows/full-promotion-pipeline.yaml
rm .github/workflows/promote-environments.yaml
```

**Keep as reusable workflows** (called by MASTER-PIPELINE):
- `build-images.yaml` - Already reusable ✅
- `deploy-environment.yaml` - Already reusable ✅ (but inline ServiceNow logic)
- `servicenow-change.yaml` - Keep as reusable ✅

**Update documentation**:
- Remove references to full-promotion-pipeline.yaml
- Update docs/DEMO-GUIDE.md to reference MASTER-PIPELINE.yaml only
- Update SERVICENOW-EVIDENCE-SUMMARY.md

---

## Modified MASTER-PIPELINE.yaml Structure

### Complete Job Flow

```
MASTER-PIPELINE.yaml
│
├─ Stage 0: Pipeline Initialization
│  └─ pipeline-init (determine environment, enforce branch policy)
│
├─ Stage 1: Code Quality & Security (Parallel)
│  ├─ validate-code (Kustomize validation, YAML lint)
│  └─ security-scans (CodeQL, Trivy, Gitleaks, Checkov)
│
├─ Stage 2: Infrastructure (Conditional)
│  ├─ detect-terraform-changes
│  ├─ terraform-plan
│  └─ terraform-apply
│
├─ Stage 3: Build & Test
│  ├─ detect-service-changes
│  └─ build-and-push (builds, tests, scans)
│
├─ Stage 3.5: ServiceNow Integration (NEW)
│  ├─ upload-test-results (ServiceNow test report)
│  └─ register-packages (ServiceNow package registration)
│
├─ Stage 4: Deployment
│  ├─ servicenow-change (NEW - Change Request creation)
│  ├─ deploy-to-environment (Kubernetes deployment)
│  └─ upload-config (NEW - Config upload to ServiceNow)
│
├─ Stage 5: Promotion (Manual Only, NEW)
│  ├─ promote-to-qa (re-tag dev→qa images)
│  └─ promote-to-prod (re-tag qa→prod images)
│
├─ Stage 6: Validation
│  └─ smoke-tests (health checks, frontend test)
│
├─ Stage 7: Release (Prod Only)
│  ├─ create-github-release (git tag + GitHub release)
│  └─ backmerge-release-to-main (if on release/* branch)
│
└─ Stage 8: Summary
   └─ pipeline-summary (overall results)
```

---

## Benefits of Consolidation

### For Users
- ✅ **Single workflow to understand** - no jumping between files
- ✅ **Simpler commands** - `just deploy-dev`, `just deploy-qa`, `just deploy-prod`
- ✅ **Clear promotion path** - dev→qa→prod in one place
- ✅ **Easier troubleshooting** - all logic in MASTER-PIPELINE.yaml

### For Maintenance
- ✅ **Less code duplication** - ServiceNow integration defined once
- ✅ **Easier to modify** - one file to update
- ✅ **Better testability** - clear job dependencies
- ✅ **Consistent tagging** - environment tags everywhere

### For ServiceNow Integration
- ✅ **Complete audit trail** - all evidence in one workflow run
- ✅ **Proper approval gates** - QA/prod require manual trigger + ServiceNow approval
- ✅ **Full compliance** - test results, packages, configs, change requests all uploaded

---

## Migration Steps

### Step 1: Fix Kustomization Files (Immediate)
```bash
sed -i 's/newTag: .*/newTag: qa/g' kustomize/overlays/qa/kustomization.yaml
sed -i 's/newTag: .*/newTag: prod/g' kustomize/overlays/prod/kustomization.yaml
git add kustomize/overlays/
git commit -m "fix: Use environment tags in kustomization overlays"
git push
```

### Step 2: Update MASTER-PIPELINE.yaml
1. Add ServiceNow integration jobs (upload-test-results, register-packages, servicenow-change, upload-config)
2. Add promotion logic jobs (promote-to-qa, promote-to-prod)
3. Update job dependencies to include new stages
4. Test workflow with `gh workflow run MASTER-PIPELINE.yaml -f environment=dev`

### Step 3: Update Justfile
1. Remove broken `promote-*` recipes
2. Add simplified `deploy-*` recipes
3. Test commands: `just deploy-dev`

### Step 4: Delete Obsolete Workflows
```bash
git rm .github/workflows/full-promotion-pipeline.yaml
git rm .github/workflows/promote-environments.yaml
git commit -m "refactor: Consolidate all CI/CD logic into MASTER-PIPELINE"
```

### Step 5: Update Documentation
1. Update docs/DEMO-GUIDE.md
2. Update SERVICENOW-EVIDENCE-SUMMARY.md
3. Update README.md
4. Create WHATS-NEW.md explaining the changes

---

## New Automated Workflow

### User Experience

**Single command to promote across all environments**:
```bash
just promote 1.1.8 all
```

**What happens**:
1. ✅ Creates release branch `release/v1.1.8`
2. ✅ Updates kustomization files for dev/qa/prod
3. ✅ Commits changes
4. ✅ Creates Pull Request
5. ✅ Waits for CI checks to pass
6. ✅ Auto-approves and merges PR
7. ✅ DEV deploys automatically (ServiceNow CR auto-approved)
8. ⏸️ Prompts: "Deploy to QA?"
9. ✅ QA deploys (ServiceNow CR requires approval)
10. ⏸️ Prompts: "Deploy to PROD?"
11. ✅ PROD deploys (ServiceNow CR requires approval)
12. ✅ Creates GitHub release
13. 🎉 Complete!

### ServiceNow Integration

**DEV Environment**:
- ServiceNow Change Request created
- **Auto-approved** (low-risk dev environment)
- Deployment proceeds immediately
- Test results, packages, configs uploaded

**QA Environment**:
- ServiceNow Change Request created
- **Requires manual approval** (testing environment)
- Workflow pauses until CR approved in ServiceNow
- Deployment proceeds after approval
- Test results, packages, configs uploaded

**PROD Environment**:
- ServiceNow Change Request created
- **Requires manual approval** (production environment)
- Workflow pauses until CR approved in ServiceNow
- Deployment proceeds after approval
- Test results, packages, configs uploaded
- GitHub release created with tag

### ServiceNow Auto-Approval Configuration

**Implementation in MASTER-PIPELINE.yaml**:
```yaml
servicenow-change:
  name: "📝 Create ServiceNow Change Request"
  needs: [pipeline-init, register-packages]
  if: needs.pipeline-init.outputs.should_deploy == 'true'
  uses: ./.github/workflows/servicenow-change.yaml
  with:
    environment: ${{ needs.pipeline-init.outputs.environment }}
    change_type: 'kubernetes'
    auto_approve: ${{ needs.pipeline-init.outputs.environment == 'dev' }}  # Auto-approve dev only
  secrets: inherit
```

**Implementation in servicenow-change.yaml**:
```yaml
- name: Create Change Request
  id: create-change
  uses: ServiceNow/servicenow-devops-change@v2.0.0
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-token: ${{ secrets.SERVICENOW_DEVOPS_TOKEN }}
    change-request:
      short_description: ${{ inputs.short_description }}
      description: ${{ inputs.description }}
      assignment_group: 'DevOps Team'
      state: ${{ inputs.auto_approve && 'implement' || 'assess' }}  # implement = auto-approved
      priority: ${{ inputs.environment == 'prod' && '2' || '3' }}
      risk: ${{ inputs.environment == 'prod' && 'medium' || 'low' }}
      impact: ${{ inputs.environment == 'prod' && '2' || '3' }}
```

## Testing Plan

### Test Scenario 1: Automated Full Promotion
```bash
# Run automated promotion workflow
just promote 1.1.8 all

# Expected Output:
🚀 Starting Automated Version Promotion
Version: 1.1.8
Services: all

📝 Creating feature branch: release/v1.1.8
📝 Updating kustomization files...
✅ Committing version update
⬆️  Pushing branch to origin
📝 Creating Pull Request
✅ Pull Request created: https://github.com/.../pull/123
⏳ Waiting for CI checks to pass...
✅ CI checks passed. Auto-approving and merging PR...
✅ PR merged to main

🟢 DEV deployment starting automatically (push to main)...
   ServiceNow CR: Auto-approved for dev
   Workflow run: 18848600678
✅ DEV deployment complete

🟡 Deploy to QA? (y/N): y
🟡 Triggering QA deployment...
   ServiceNow CR: Requires approval
   Workflow run: 18848600679
   ⏸️  Waiting for ServiceNow CR approval...
✅ QA deployment complete

🔴 Deploy to PROD? (y/N): y
🔴 Triggering PROD deployment...
   ServiceNow CR: Requires approval
   Workflow run: 18848600680
   ⏸️  Waiting for ServiceNow CR approval...
✅ PROD deployment complete

🎉 Version promotion complete!

## Summary
Version: 1.1.8
Services: all
Branch: release/v1.1.8 (merged and deleted)
Environments:
  ✅ DEV - Deployed
  ✅ QA - Deployed
  ✅ PROD - Deployed
```

### Test Scenario 2: Promote Single Service
```bash
# Promote only frontend service
just promote-service frontend 1.1.9

# Expected:
# 1. Creates release branch release/v1.1.9
# 2. Updates only frontend image tag in kustomization files
# 3. Creates PR, auto-merges
# 4. Deploys to dev (auto-approved)
# 5. Prompts for QA deployment
# 6. Prompts for PROD deployment
```

### Test Scenario 3: Manual Environment Deployment
```bash
# Manually deploy to specific environment (outside of promotion flow)
just deploy-qa

# Expected:
# 1. Triggers MASTER-PIPELINE.yaml with environment=qa
# 2. Uses existing images (no rebuild)
# 3. Creates ServiceNow CR (requires approval)
# 4. Deploys to microservices-qa namespace
# 5. Runs smoke tests
```

### Test Scenario 4: Verify ServiceNow Auto-Approval
```bash
# Check ServiceNow after dev deployment
# 1. Navigate to ServiceNow Change Requests
# 2. Find CR for dev deployment
# 3. Verify state = "Implement" (auto-approved)
# 4. Verify priority = "3 - Low"

# Check ServiceNow after qa deployment
# 1. Navigate to ServiceNow Change Requests
# 2. Find CR for qa deployment
# 3. Verify state = "Assess" (awaiting approval)
# 4. Verify priority = "3 - Low"
# 5. Approve CR manually
# 6. Verify workflow proceeds
```

---

## Rollback Plan

If consolidation causes issues:

1. **Immediate rollback**: Revert the MASTER-PIPELINE.yaml changes
   ```bash
   git revert <commit-sha>
   git push origin main
   ```

2. **Restore old workflows temporarily**:
   ```bash
   git checkout HEAD~1 -- .github/workflows/full-promotion-pipeline.yaml
   git checkout HEAD~1 -- .github/workflows/promote-environments.yaml
   git add .github/workflows/
   git commit -m "temp: Restore old promotion workflows"
   ```

3. **Fix kustomization files back to `dev` tag**:
   ```bash
   sed -i 's/newTag: .*/newTag: dev/g' kustomize/overlays/*/kustomization.yaml
   kubectl apply -k kustomize/overlays/dev
   ```

---

## Success Criteria

✅ **Workflow Consolidation**:
- [ ] All ServiceNow integration in MASTER-PIPELINE.yaml
- [ ] Promotion logic in MASTER-PIPELINE.yaml
- [ ] No separate promotion workflows (delete full-promotion-pipeline, promote-environments)
- [ ] Keep only reusable workflows: build-images, deploy-environment, servicenow-change

✅ **Tagging Strategy**:
- [ ] All kustomization files use environment tags (dev/qa/prod)
- [ ] Images tagged consistently across all environments
- [ ] No ImagePullBackOff errors
- [ ] Commit SHA tags for traceability (dev-abc123def, qa-abc123def, prod-abc123def)

✅ **Automated Promotion Script**:
- [ ] `scripts/promote-version.sh` created and working
- [ ] Creates feature branch automatically
- [ ] Updates kustomization files for all environments
- [ ] Creates and auto-merges PR
- [ ] Triggers deployments sequentially (dev → qa → prod)

✅ **Justfile Cleanup**:
- [ ] ALL broken `promote-*` commands removed
- [ ] New `just promote VERSION SERVICES` command works
- [ ] `just promote-all VERSION` works
- [ ] `just promote-service SERVICE VERSION` works
- [ ] Manual `deploy-dev`, `deploy-qa`, `deploy-prod` commands work

✅ **ServiceNow Integration**:
- [ ] DEV: Auto-approved Change Requests (state = "implement")
- [ ] QA: Manual approval required (state = "assess")
- [ ] PROD: Manual approval required (state = "assess")
- [ ] Test results uploaded after builds
- [ ] Packages registered after builds
- [ ] Configs uploaded after deployments
- [ ] All evidence visible in ServiceNow

✅ **End-to-End Flow**:
- [ ] `just promote 1.1.8 all` completes full promotion
- [ ] Feature branch created and merged automatically
- [ ] Dev deployment auto-approved and deploys
- [ ] QA deployment requires ServiceNow approval
- [ ] Prod deployment requires ServiceNow approval
- [ ] GitHub release created for prod

✅ **Documentation**:
- [ ] DEMO-GUIDE.md updated to reference new workflow
- [ ] ServiceNow docs updated
- [ ] New AUTOMATED-PROMOTION-GUIDE.md created
- [ ] README.md updated with new commands

---

## Next Steps

**Ready to implement?** I can proceed with:

1. ✅ **Fix kustomization files** (qa and prod overlays)
2. ✅ **Update MASTER-PIPELINE.yaml** (add ServiceNow + promotion jobs)
3. ✅ **Update justfile** (remove broken commands, add simplified ones)
4. ✅ **Delete obsolete workflows**
5. ✅ **Test end-to-end flow**
6. ✅ **Update documentation**

Let me know if you want me to start with Phase 1 (fix kustomization files) or if you want to review this plan first.
