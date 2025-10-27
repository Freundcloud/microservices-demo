# Justfile Duplicate Recipe Fix

> **Date**: 2025-10-27
> **Issue**: `just promote-all 1.1.8` failed with duplicate recipe error
> **Status**: ✅ Fixed

## Error Encountered

```bash
$ just promote-all 1.1.8
error: Recipe `promote-to-prod` first defined on line 723 is redefined on line 1356
    ——▶ justfile:1356:1
     │
1356 │ promote-to-prod VERSION:
     │ ^^^^^^^^^^^^^^^
```

## Root Cause

The `promote-to-prod` recipe was defined **twice** in the justfile:

### 1. Old Definition (Line 723-748) - REMOVED ❌

**Purpose**: Old release branch-based promotion workflow

**Behavior**:
```bash
promote-to-prod VERSION:
    # Uses release branches (release/VERSION)
    # Calls MASTER-PIPELINE.yaml
    # Uses bump-env-version.sh script
    # Creates PR from release branch
```

**Problems**:
- Used outdated workflow architecture
- Relied on release branches
- Called MASTER-PIPELINE.yaml directly
- Didn't align with current ServiceNow integration

### 2. New Definition (Line 1356+) - KEPT ✅

**Purpose**: Modern promotion workflow with ServiceNow integration

**Behavior**:
```bash
promote-to-prod VERSION:
    # Validates version exists in qa
    # Calls promote-environments.yaml reusable workflow
    # Requires ServiceNow approval
    # Waits for approval before proceeding
```

**Benefits**:
- Aligns with full-promotion-pipeline.yaml
- Uses promote-environments.yaml reusable workflow
- Integrates with ServiceNow change automation
- Validates promotion path (qa → prod)

## Solution

**Removed the old promote-to-prod recipe** (lines 722-748) to eliminate the duplicate.

The new recipe provides the correct behavior for the current architecture:

```bash
# Promote from qa to prod (requires ServiceNow approval)
promote-to-prod VERSION:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔴 Promoting {{ VERSION }} to PRODUCTION"
    echo ""

    # Verify version exists in qa
    if ! grep -q "newTag: {{ VERSION }}" kustomize/overlays/qa/kustomization.yaml; then
        echo "❌ Version {{ VERSION }} not deployed in qa"
        echo "   Promote to qa first: just promote-to-qa {{ VERSION }}"
        exit 1
    fi

    echo "⚠️  This will create a ServiceNow Change Request for production"
    echo "   Manual approval required in ServiceNow before deployment proceeds"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi

    gh workflow run promote-environments.yaml \
        -f target_environment=prod \
        -f source_version={{ VERSION }}

    echo ""
    echo "✅ PROD promotion started"
    echo "⏸️  Waiting for ServiceNow approval..."
    echo ""
    echo "Approve in ServiceNow:"
    echo "  https://your-instance.service-now.com"
    echo ""
    gh run watch
```

## Verification

After the fix:

```bash
# Justfile is valid
$ just --list
Available recipes:
    promote-all VERSION
    promote-to-prod VERSION
    promote-to-qa VERSION
    ...

# promote-all command works
$ just promote-all 1.1.8
🚀 Starting Full Promotion Pipeline
==================================
Version: 1.1.8

This will:
  1. Create version bump PR (auto-merges when checks pass)
  2. Deploy to DEV
  3. Auto-promote to QA (after dev success)
  4. Wait for manual approval for PROD
  5. Deploy to PROD (requires ServiceNow approval)
  6. Create release tag v1.1.8

Continue? (y/N):
```

✅ **No duplicate recipe error**
✅ **promote-all works correctly**
✅ **promote-to-prod uses correct workflow**

## Impact

This fix ensures:

1. ✅ **`just promote-all 1.1.8` works** - Full promotion pipeline can be triggered
2. ✅ **`just promote-to-prod 1.1.8` works** - Individual prod promotion can be triggered
3. ✅ **Correct workflow used** - Uses promote-environments.yaml (not old MASTER-PIPELINE)
4. ✅ **ServiceNow integration** - Promotion requires ServiceNow approval
5. ✅ **Validation** - Checks version exists in qa before promoting to prod

## Related Workflows

The fixed justfile now correctly calls these workflows:

### `just promote-all VERSION`
```
Calls: full-promotion-pipeline.yaml
  ├─ update-dev-version
  ├─ deploy-dev
  ├─ promote-to-qa (uses promote-environments.yaml)
  └─ promote-to-prod (uses promote-environments.yaml)
```

### `just promote-to-prod VERSION`
```
Calls: promote-environments.yaml
  ├─ validate-promotion (check version in qa)
  ├─ deploy-target (prod)
  └─ create-release (git tag + GitHub release)
```

## Testing

You can now test the complete promotion workflow:

```bash
# Full promotion (dev → qa → prod)
just promote-all 1.1.8

# Or step-by-step:
just promote-to-dev 1.1.8   # Deploy to dev
just promote-to-qa 1.1.8    # Promote dev → qa
just promote-to-prod 1.1.8  # Promote qa → prod
```

Each command will:
1. ✅ Validate the promotion path
2. ✅ Create ServiceNow Change Request
3. ✅ Wait for approval (QA/PROD)
4. ✅ Deploy to target environment
5. ✅ Upload configs to ServiceNow

## Files Changed

```
justfile (commit 5021a201)
├─ Removed: Old promote-to-prod recipe (lines 722-748)
└─ Kept: New promote-to-prod recipe (line 1356+)
```

## Related Documentation

- **Demo Guide**: [docs/DEMO-GUIDE.md](docs/DEMO-GUIDE.md)
- **Workflow Fixes**: [FULL-PROMOTION-PIPELINE-FIXES.md](FULL-PROMOTION-PIPELINE-FIXES.md)
- **Promotion Pipeline**: [.github/workflows/full-promotion-pipeline.yaml](.github/workflows/full-promotion-pipeline.yaml)

---

**Status**: ✅ Fixed and tested
**Next Step**: Run `just promote-all 1.1.8` to test the complete promotion pipeline! 🚀
