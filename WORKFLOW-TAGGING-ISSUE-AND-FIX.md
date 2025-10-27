# Critical Workflow Issue: Image Tagging Strategy Mismatch

> **Status**: 🔴 **CRITICAL - Workflows Not Working**
> **Date**: 2025-10-27
> **Issue**: Semantic versioning (1.1.8) vs Environment tags (dev/qa/prod)

---

## The Problem

### What Happened

```bash
$ just promote-all 1.1.8
✅ Kustomization updated to version 1.1.8
✅ Deployed to Kubernetes
❌ ALL PODS FAILING: ImagePullBackOff

$ kubectl describe pod frontend
Error: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:1.1.8: not found
```

**Root Cause**: The workflows are using **TWO DIFFERENT TAGGING STRATEGIES** that conflict:

### Strategy 1: Environment Tags (What EXISTS in ECR)
```bash
# Check ECR - what actually exists:
$ aws ecr describe-images --repository-name frontend

Tags found:
✅ dev
✅ qa
✅ prod
✅ dev-ce68b19e... (commit SHA)
✅ qa-0c9ccb17...  (commit SHA)
✅ prod-979625d0... (commit SHA)
✅ 1.1.6 (old semantic version)

❌ 1.1.8 (DOES NOT EXIST!)
```

### Strategy 2: Semantic Versioning (What workflows TRY to use)
```bash
# full-promotion-pipeline.yaml tries to use:
just promote-all 1.1.8
  ├─ Updates kustomization.yaml → newTag: 1.1.8
  └─ Deploys → Tries to pull frontend:1.1.8 ❌

# But build-images.yaml creates:
  ├─ frontend:dev
  ├─ frontend:dev-abc123def
  └─ Does NOT create frontend:1.1.8
```

---

## Why This Happened

### Build Images Workflow (`build-images.yaml`)
**Creates environment-based tags**:

```yaml
# Line ~340
- name: Tag and Push Image
  run: |
    # Tags created:
    docker tag ${{ matrix.service }}:latest \
      ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}

    docker tag ${{ matrix.service }}:latest \
      ${{ env.ECR_REGISTRY }}/${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}
```

**Result**: Creates `frontend:dev` and `frontend:dev-abc123def`

### Promotion Pipeline (`full-promotion-pipeline.yaml`)
**Uses semantic versioning**:

```yaml
# Line 48-56
- name: Update Kustomization Version
  run: |
    VERSION="${{ inputs.version }}"  # e.g., 1.1.8
    sed -i "s/newTag: .*/newTag: $VERSION/" "$KUSTOMIZE_FILE"
```

**Result**: Updates kustomization to use `frontend:1.1.8` which **doesn't exist**!

---

## Current State

### What Works ✅
- Building Docker images
- Pushing to ECR with environment tags (dev/qa/prod)
- ServiceNow integration
- Change Request creation

### What's Broken ❌
- `just promote-all 1.1.8` - Creates non-existent tags
- `just promote-to-qa 1.1.8` - Same issue
- `just promote-to-prod 1.1.8` - Same issue
- Any semantic versioning (1.x.x) - Images don't exist

### What Images Exist in ECR
```
✅ frontend:dev (latest dev build)
✅ frontend:qa (latest qa deployment)
✅ frontend:prod (latest prod deployment)
✅ frontend:dev-abc123 (specific commit)
❌ frontend:1.1.8 (doesn't exist)
❌ frontend:1.1.7 (doesn't exist)
```

---

## The Fix: Choose ONE Strategy

We need to pick ONE consistent tagging strategy across all workflows.

### Option A: Environment Tags (Recommended - Simpler)

**Use**: `dev`, `qa`, `prod` tags that slide forward

**Pros**:
- ✅ Simpler - no version management needed
- ✅ Already working in build-images.yaml
- ✅ Clear which version is in each environment
- ✅ No manual version bumps

**Cons**:
- ❌ No semantic versioning
- ❌ Can't rollback to specific versions easily
- ❌ GitHub Releases use generic names

**Changes needed**:
1. Remove semantic versioning from promotion workflows
2. Use environment tags: `dev`, `qa`, `prod`
3. Optionally keep commit SHA tags for rollback

### Option B: Semantic Versioning (Complex - Requires VERSION file)

**Use**: `1.1.8`, `1.1.9`, etc.

**Pros**:
- ✅ Clear version history
- ✅ Easy rollbacks (frontend:1.1.6)
- ✅ Professional versioning
- ✅ Good for GitHub Releases

**Cons**:
- ❌ Requires VERSION file in repo
- ❌ Must build images with semantic version tags
- ❌ More complex workflows
- ❌ Need to bump version manually

**Changes needed**:
1. Create VERSION file (e.g., `echo "1.1.8" > VERSION`)
2. Update build-images.yaml to read VERSION and tag images
3. Update promotion workflows to use VERSION
4. Add version bump commands to justfile

---

## Recommended Solution: Option A (Environment Tags)

### Step 1: Fix `full-promotion-pipeline.yaml`

**REMOVE** the `update-dev-version` job entirely:

```yaml
# DELETE THIS ENTIRE JOB (lines 38-77)
update-dev-version:
  name: "📝 Update Dev Kustomization"
  ...
```

**WHY**: Kustomization files should already have `newTag: dev` (not version numbers)

### Step 2: Fix Kustomization Files

Set all overlays to use environment tags:

```bash
# Dev overlay
sed -i 's/newTag: .*/newTag: dev/g' kustomize/overlays/dev/kustomization.yaml

# QA overlay
sed -i 's/newTag: .*/newTag: qa/g' kustomize/overlays/qa/kustomization.yaml

# Prod overlay
sed -i 's/newTag: .*/newTag: prod/g' kustomize/overlays/prod/kustomization.yaml
```

**Result**: Kustomization files use tags that actually exist in ECR

### Step 3: Update Promotion Workflow Logic

**Instead of** updating kustomization files (they're already set):

```yaml
# NEW promote-all workflow logic:
jobs:
  build-dev-images:
    # Build all images and tag as 'dev'
    uses: ./.github/workflows/build-images.yaml
    with:
      environment: dev
      push_images: true

  deploy-dev:
    needs: build-dev-images
    uses: ./.github/workflows/deploy-environment.yaml
    with:
      environment: dev
```

### Step 4: Simplify Justfile Commands

**REMOVE** semantic version parameters:

```makefile
# OLD (broken):
promote-all VERSION:
    gh workflow run full-promotion-pipeline.yaml -f version={{ VERSION }}

# NEW (working):
promote-all:
    #!/usr/bin/env bash
    echo "🚀 Full Promotion Pipeline (dev → qa → prod)"
    echo ""
    echo "This will:"
    echo "  1. Build images and tag as 'dev'"
    echo "  2. Deploy to DEV"
    echo "  3. Re-tag images as 'qa' and deploy to QA"
    echo "  4. Re-tag images as 'prod' and deploy to PROD"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

    gh workflow run full-promotion-pipeline.yaml
```

---

## Implementation Plan

### Phase 1: Immediate Fix (Get Pods Running)

```bash
# 1. Fix dev kustomization (ALREADY DONE)
sed -i 's/newTag: 1\.1\.8/newTag: dev/g' kustomize/overlays/dev/kustomization.yaml

# 2. Redeploy
kubectl apply -k kustomize/overlays/dev

# 3. Verify pods running
kubectl get pods -n microservices-dev
```

### Phase 2: Fix QA/Prod Overlays

```bash
# Fix QA
sed -i 's/newTag: .*/newTag: qa/g' kustomize/overlays/qa/kustomization.yaml

# Fix Prod
sed -i 's/newTag: .*/newTag: prod/g' kustomize/overlays/prod/kustomization.yaml

# Commit
git add kustomize/overlays/
git commit -m "fix: Use environment tags (dev/qa/prod) instead of semantic versions"
git push
```

### Phase 3: Redesign Promotion Workflow

**NEW full-promotion-pipeline.yaml logic**:

```yaml
jobs:
  # Step 1: Build images for dev
  build-dev:
    uses: ./.github/workflows/build-images.yaml
    with:
      environment: dev
      push_images: true

  # Step 2: Deploy to dev
  deploy-dev:
    needs: build-dev
    uses: ./.github/workflows/deploy-environment.yaml
    with:
      environment: dev

  # Step 3: Promote to QA (re-tag dev images as qa)
  retag-for-qa:
    needs: deploy-dev
    uses: ./.github/workflows/retag-images.yaml  # NEW workflow
    with:
      source_tag: dev
      target_tag: qa

  deploy-qa:
    needs: retag-for-qa
    uses: ./.github/workflows/deploy-environment.yaml
    with:
      environment: qa

  # Step 4: Promote to PROD (re-tag qa images as prod)
  retag-for-prod:
    needs: deploy-qa
    uses: ./.github/workflows/retag-images.yaml
    with:
      source_tag: qa
      target_tag: prod

  deploy-prod:
    needs: retag-for-prod
    uses: ./.github/workflows/deploy-environment.yaml
    with:
      environment: prod
```

### Phase 4: Create Re-tag Workflow

**NEW `.github/workflows/retag-images.yaml`**:

```yaml
name: Re-tag ECR Images

on:
  workflow_call:
    inputs:
      source_tag:
        required: true
        type: string
      target_tag:
        required: true
        type: string

jobs:
  retag:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [frontend, cartservice, productcatalogservice, ...]

    steps:
      - name: Pull source image
        run: |
          docker pull $ECR_REGISTRY/${{ matrix.service }}:${{ inputs.source_tag }}

      - name: Tag as target
        run: |
          docker tag $ECR_REGISTRY/${{ matrix.service }}:${{ inputs.source_tag }} \
                     $ECR_REGISTRY/${{ matrix.service }}:${{ inputs.target_tag }}

      - name: Push target tag
        run: |
          docker push $ECR_REGISTRY/${{ matrix.service }}:${{ inputs.target_tag }}
```

---

## Testing the Fix

### Test 1: Dev Deployment Works

```bash
# Trigger build and deploy to dev
gh workflow run build-images.yaml -f environment=dev -f push_images=true
gh workflow run deploy-environment.yaml -f environment=dev

# Verify
kubectl get pods -n microservices-dev
# All pods should be Running
```

### Test 2: Promotion Works

```bash
# Promote dev → qa
just promote-to-qa

# Should:
# 1. Re-tag all dev images as qa
# 2. Deploy to QA
# 3. All pods Running
```

### Test 3: Full Pipeline Works

```bash
just promote-all

# Should:
# 1. Build images (tag: dev)
# 2. Deploy to DEV
# 3. Re-tag as qa and deploy to QA
# 4. Re-tag as prod and deploy to PROD
```

---

## Summary

### What's Wrong Now
❌ Workflows use semantic versions (1.1.8) but images are tagged with environment names (dev/qa/prod)
❌ `just promote-all 1.1.8` creates kustomization with non-existent tags
❌ All pods fail with ImagePullBackOff

### The Fix
✅ Use environment tags consistently: `dev`, `qa`, `prod`
✅ Remove semantic versioning from workflows
✅ Keep kustomization files static (always use env tags)
✅ Build → Tag as `dev` → Deploy → Re-tag as `qa` → Deploy → Re-tag as `prod` → Deploy

### Next Steps
1. ✅ Immediate: Fix dev kustomization (DONE)
2. ⏳ Short-term: Fix qa/prod kustomizations
3. ⏳ Medium-term: Redesign promotion workflow
4. ⏳ Long-term: Clean up justfile commands

---

**Status**: Phase 1 (Immediate Fix) COMPLETE
**Next**: Implement Phase 2-4 for complete solution
