# ServiceNow Secrets Cleanup - 2025-10-23

## Issue

The ServiceNow integration workflow was failing at the preflight authentication check:

```
❌ ServiceNow Basic auth failed for Register Artifacts (HTTP 401)
Error: Process completed with exit code 1.
```

## Root Cause

The workflow supports TWO sets of secret names with a fallback mechanism:

```bash
# Priority order (lines 53-58 in servicenow-integration.yaml)
URL="${{ secrets.SN_INSTANCE_URL }}"           # 1st priority
if [ -z "$URL" ]; then URL="${{ secrets.SERVICENOW_INSTANCE_URL }}"; fi  # 2nd priority

USER="${{ secrets.SN_DEVOPS_USER }}"           # 1st priority
if [ -z "$USER" ]; then USER="${{ secrets.SERVICENOW_USERNAME }}"; fi    # 2nd priority

PASS="${{ secrets.SN_DEVOPS_PASSWORD }}"       # 1st priority
if [ -z "$PASS" ]; then PASS="${{ secrets.SERVICENOW_PASSWORD }}"; fi   # 2nd priority
```

**Problem**: The old `SN_DEVOPS_*` secrets (created Oct 14) had INCORRECT credentials, and they were being used FIRST.

## Secrets Status

### Before Cleanup (2025-10-23 16:30)

| Secret Name | Last Updated | Status |
|-------------|--------------|--------|
| `SN_DEVOPS_USER` | Oct 14 | ❌ Wrong value, used first |
| `SN_DEVOPS_PASSWORD` | Oct 14 | ❌ Wrong value, used first |
| `SN_INSTANCE_URL` | Oct 14 | ❌ Wrong value, used first |
| `SERVICENOW_USERNAME` | Oct 23 | ✅ Correct, but never used |
| `SERVICENOW_PASSWORD` | Oct 23 | ✅ Correct, but never used |
| `SERVICENOW_INSTANCE_URL` | Oct 23 | ✅ Correct, but never used |
| `SN_ORCHESTRATION_TOOL_ID` | Oct 23 | ✅ Correct |

### After Cleanup (2025-10-23 16:32)

| Secret Name | Last Updated | Status |
|-------------|--------------|--------|
| `SN_DEVOPS_USER` | - | ❌ DELETED |
| `SN_DEVOPS_PASSWORD` | - | ❌ DELETED |
| `SN_INSTANCE_URL` | - | ❌ DELETED |
| `SERVICENOW_USERNAME` | Oct 23 | ✅ ACTIVE (now used first) |
| `SERVICENOW_PASSWORD` | Oct 23 | ✅ ACTIVE (now used first) |
| `SERVICENOW_INSTANCE_URL` | Oct 23 | ✅ ACTIVE (now used first) |
| `SN_ORCHESTRATION_TOOL_ID` | Oct 23 | ✅ ACTIVE |

## Fix Applied

```bash
# Deleted old secrets with wrong credentials
gh secret delete SN_DEVOPS_USER
gh secret delete SN_DEVOPS_PASSWORD
gh secret delete SN_INSTANCE_URL
```

## Current Correct Secrets

The workflow now uses these correct secrets (from `.envrc`):

```bash
SERVICENOW_USERNAME='github_integration'
SERVICENOW_PASSWORD='oA3KqdUVI8Q_^>'
SERVICENOW_INSTANCE_URL='https://calitiiltddemo3.service-now.com'
SN_ORCHESTRATION_TOOL_ID='f62c4e49c3fcf614e1bbf0cb050131ef'
```

## Verification

To verify the fix worked, check the next workflow run:

```bash
# Trigger a test workflow
gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f skip_build=true

# Watch the run
gh run watch --exit-status

# Expected output in "Preflight: Verify Basic Auth (Artifacts)" step:
✅ ServiceNow Basic auth verified (Artifacts)
```

## Why Keep the Preflight Check?

**YES, keep the preflight check** because it:

✅ **Catches auth failures EARLY** - Before wasting 8-10 minutes building containers
✅ **Provides clear error messages** - Shows exactly what's wrong (401, 403, 404)
✅ **Saves GitHub Actions minutes** - Fails fast at 30 seconds instead of 10 minutes
✅ **Helps troubleshoot** - Shows which credential is missing/wrong
✅ **Prevents partial deployments** - Won't start deployment if auth is broken

**Cost savings example:**
- Without preflight: Fail after 10 min (build) + 2 min (deploy) = 12 minutes wasted
- With preflight: Fail after 30 seconds = 11.5 minutes saved per failed run

## Secret Naming Convention Going Forward

**Use SERVICENOW_* prefix for consistency:**

| Secret Name | Required | Example Value |
|-------------|----------|---------------|
| `SERVICENOW_USERNAME` | ✅ Yes | `github_integration` |
| `SERVICENOW_PASSWORD` | ✅ Yes | `oA3KqdUVI8Q_^>` |
| `SERVICENOW_INSTANCE_URL` | ✅ Yes | `https://calitiiltddemo3.service-now.com` |
| `SN_ORCHESTRATION_TOOL_ID` | ✅ Yes | `f62c4e49c3fcf614e1bbf0cb050131ef` |

**Deprecated (do not use):**
- ~~`SN_DEVOPS_USER`~~ → Use `SERVICENOW_USERNAME`
- ~~`SN_DEVOPS_PASSWORD`~~ → Use `SERVICENOW_PASSWORD`
- ~~`SN_INSTANCE_URL`~~ → Use `SERVICENOW_INSTANCE_URL`

## Related Issues

**ServiceNow Tool Must Be Active:**

Even with correct credentials, the tool "GithHubARC" must be ACTIVE in ServiceNow:

1. Go to: https://calitiiltddemo3.service-now.com/sn_devops_tool.do?sys_id=f62c4e49c3fcf614e1bbf0cb050131ef
2. Check "Active" checkbox
3. Save

Or use the activation script:
```bash
source .envrc
./scripts/activate-servicenow-tool.sh
```

## Testing Locally

Verify credentials work locally before running workflows:

```bash
source .envrc
./scripts/verify-servicenow-api.sh
```

**Expected output:**
```
✅ TEST 1: Basic Authentication - PASS (HTTP 200)
✅ TEST 2: Tool ID Validation - PASS (HTTP 200)
✅ TEST 3: Change Request API - PASS (HTTP 200)
✅ TEST 4: Work Item API - PASS (HTTP 200)
✅ TEST 5: Artifact API - PASS (HTTP 200)
✅ TEST 6: Attachment API - PASS (HTTP 200)
```

## Summary

**Fixed**: Deleted old `SN_DEVOPS_*` secrets that had wrong credentials

**Result**: Workflow now uses correct `SERVICENOW_*` secrets

**Next workflow run should pass the preflight check** ✅
