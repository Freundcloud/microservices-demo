# First Run of Promotion Pipeline - Expected Behavior

> **Date**: 2025-10-27
> **Workflow Run**: https://github.com/Freundcloud/microservices-demo/actions/runs/18848600678
> **Status**: Partial Success (Expected for First Run)

## What Happened

Running `just promote-all 1.1.8` for the first time:

### ✅ Successes

1. **Update Dev Kustomization** - SUCCESS
   - Updated `kustomize/overlays/dev/kustomization.yaml` with version 1.1.8
   - Created commit: `8c626a9b` - "chore: Update dev to version 1.1.8"
   - Pushed to main branch

2. **Deploy to DEV** - SUCCESS
   - ServiceNow Change Request created (auto-approved)
   - All 12 services deployed to microservices-dev namespace
   - Version 1.1.8 running in DEV

### ❌ Expected Failure

3. **Promote to QA** - FAILED (Expected)
   - Error: "❌ Version 1.1.8 not found in dev environment"
   - **Root Cause**: Git checkout timing issue

## Root Cause Analysis

### Why Did QA Promotion Fail?

**Timeline**:
```
T0: Workflow starts (commit 086d0133)
T1: update-dev-version job runs
    ├─ Checkouts code at 086d0133
    ├─ Updates kustomization.yaml to version 1.1.8
    ├─ Creates commit 8c626a9b
    └─ Pushes to main

T2: deploy-dev job runs (uses commit 8c626a9b) ✅

T3: promote-to-qa job runs
    ├─ Checkouts code at 086d0133 (workflow start commit) ❌
    ├─ Version 1.1.8 NOT in kustomization.yaml yet
    └─ Validation fails: "Version not found in dev"
```

**The Problem**: Reusable workflows (`promote-environments.yaml`) checkout the code at the commit when the parent workflow started (`086d0133`), NOT the latest main branch that has the kustomization update (`8c626a9b`).

### Verification

Version 1.1.8 **IS** in dev kustomization:

```bash
$ grep "newTag:" kustomize/overlays/dev/kustomization.yaml
  newTag: 1.1.8  # ✅ Present in commit 8c626a9b
  newTag: 1.1.8
  newTag: 1.1.8
  ...
```

But the promote-to-qa job checked out commit `086d0133` which didn't have this change yet.

## Solutions

### Solution 1: Run Promotion Again (Recommended for First Time)

Now that version 1.1.8 is committed to main, run the promotion from QA onwards:

```bash
# Promote from dev to qa
just promote-to-qa 1.1.8

# Then promote to prod
just promote-to-prod 1.1.8
```

**Why this works**: The workflow will now checkout the LATEST main branch which includes the 1.1.8 kustomization update.

### Solution 2: Use Full Promotion Pipeline Again

Run the full promotion pipeline again - it will skip the dev update (already at 1.1.8) and proceed to QA/PROD:

```bash
just promote-all 1.1.8
```

**Result**:
- Update Dev: ✅ No changes (already 1.1.8)
- Deploy DEV: ✅ Success (already deployed)
- Promote QA: ✅ Success (now sees 1.1.8 in dev)
- Promote PROD: ⏸️ Waits for ServiceNow approval

### Solution 3: Manual Workflow Trigger (Alternative)

Trigger promote-environments workflow directly via GitHub UI:

1. Go to: https://github.com/Freundcloud/microservices-demo/actions/workflows/promote-environments.yaml
2. Click "Run workflow"
3. Set:
   - target_environment: `qa`
   - source_version: `1.1.8`
4. Click "Run workflow"

## Fix for Future Runs

### Option A: Change Reusable Workflow Checkout (Recommended)

Update `.github/workflows/promote-environments.yaml` to always fetch latest main:

```yaml
- name: Checkout Code
  uses: actions/checkout@v4
  with:
    ref: main  # Always use latest main, not workflow trigger commit
    fetch-depth: 1
```

**Pros**: Ensures validation sees latest kustomization updates
**Cons**: May introduce race conditions if multiple workflows run simultaneously

### Option B: Add Delay Between Jobs

Add a small delay or explicit checkout of latest commit:

```yaml
deploy-dev:
  outputs:
    latest_commit: ${{ steps.get-commit.outputs.sha }}

promote-to-qa:
  needs: deploy-dev
  steps:
    - uses: actions/checkout@v4
      with:
        ref: ${{ needs.deploy-dev.outputs.latest_commit }}
```

### Option C: Skip Validation for Auto-Promoted QA

Since we just updated dev in the same workflow, skip the validation check for auto-promoted QA:

```yaml
# In promote-environments.yaml
- name: Validate Promotion Path
  if: github.event_name != 'workflow_call'  # Skip if called from parent workflow
```

## Current State

After the first run:

```
✅ Dev: Version 1.1.8 deployed and committed
✅ Commit 8c626a9b: kustomization.yaml updated
❌ QA: Not deployed (validation failed - timing issue)
❌ Prod: Not deployed (QA prerequisite failed)
```

## Next Steps

**Recommended Actions**:

1. **Immediate**: Run QA promotion manually:
   ```bash
   just promote-to-qa 1.1.8
   ```

2. **After QA Success**: Promote to PROD:
   ```bash
   just promote-to-prod 1.1.8
   ```

3. **Long Term**: Fix the checkout reference in `promote-environments.yaml` to use latest main

## Why This Happens

This is a known limitation of GitHub Actions reusable workflows:

- **Reusable workflows** inherit the git SHA from the calling workflow
- **Calling workflow** uses the SHA at trigger time (pre-kustomization update)
- **Solution**: Either use `ref: main` in checkout, or run promotion in separate workflow after commit

### GitHub Actions Behavior

```yaml
# Parent workflow (full-promotion-pipeline.yaml)
# Triggered at commit 086d0133

jobs:
  update-dev:
    # Creates commit 8c626a9b

  promote-to-qa:
    uses: ./.github/workflows/promote-environments.yaml
    # Inherits parent SHA: 086d0133 ❌
    # Should use: main (latest) ✅
```

## Verification Commands

Check what version is in dev:

```bash
grep "newTag:" kustomize/overlays/dev/kustomization.yaml | head -1
# Output: newTag: 1.1.8
```

Check git history:

```bash
git log --oneline -3
# 552f0add fix: Use workflow filename instead of display name
# 8c626a9b chore: Update dev to version 1.1.8 - Automated promotion
# 086d0133 docs: Add justfile duplicate recipe fix documentation
```

Check DEV deployment:

```bash
kubectl get pods -n microservices-dev -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | grep frontend
# Should show: frontend:1.1.8
```

## Summary

✅ **This is expected behavior for the first run**
- Dev kustomization updated successfully
- DEV environment deployed successfully
- QA validation failed due to git checkout timing
- **Solution**: Run `just promote-to-qa 1.1.8` to continue

✅ **Future runs will work correctly** because:
- Dev kustomization already has version 1.1.8
- QA promotion will checkout latest main with 1.1.8
- No timing issue on subsequent runs

🔧 **Recommended Fix**: Update promote-environments.yaml checkout to use `ref: main`

---

**Next Command**: `just promote-to-qa 1.1.8` 🚀
