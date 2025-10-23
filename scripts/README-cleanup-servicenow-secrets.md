# ServiceNow Secrets Cleanup Script

## Overview

The `cleanup-servicenow-secrets.sh` script automates the process of cleaning up old/incorrect ServiceNow secrets and setting the correct ones from your `.envrc` file.

## What It Does

### Phase 1: Delete Old Secrets ✂️
Removes old secrets that have incorrect credentials:
- `SN_DEVOPS_USER`
- `SN_DEVOPS_PASSWORD`
- `SN_INSTANCE_URL`

### Phase 2: Check Deprecated Secrets ⚠️
Identifies deprecated secrets that may be unused:
- `SN_OAUTH_TOKEN`
- `SN_DEVOPS_INTEGRATION_TOKEN`
- `SERVICENOW_BASIC_AUTH`
- `SERVICENOW_APP_SYS_ID`
- `SERVICENOW_TOOL_ID`

Provides commands to delete them manually if desired.

### Phase 3: Set Correct Secrets ✅
Sets the 4 required secrets from `.envrc`:
- `SERVICENOW_USERNAME`
- `SERVICENOW_PASSWORD`
- `SERVICENOW_INSTANCE_URL`
- `SN_ORCHESTRATION_TOOL_ID`

### Phase 4: Verify Final Secrets 🔍
Lists all ServiceNow-related secrets with their last updated timestamps.

### Phase 5: Test Credentials 🧪
Tests the credentials against the ServiceNow API:
- **Basic Authentication** - Verifies username/password work
- **Tool ID Validation** - Confirms tool exists and checks if active

If the tool is inactive, it provides instructions to activate it.

## Usage

### Quick Run (via justfile)
```bash
just sn-cleanup
```

### Direct Execution
```bash
./scripts/cleanup-servicenow-secrets.sh
```

## Prerequisites

1. **`.envrc` file** with ServiceNow credentials:
   ```bash
   export SERVICENOW_USERNAME='github_integration'
   export SERVICENOW_PASSWORD='your_password'
   export SERVICENOW_INSTANCE_URL='https://your-instance.service-now.com'
   export SN_ORCHESTRATION_TOOL_ID='your_tool_id'
   ```

2. **GitHub CLI** (`gh`) installed and authenticated:
   ```bash
   gh auth login
   ```

3. **Source .envrc** before running:
   ```bash
   source .envrc
   ```

## Example Output

```
🧹 ServiceNow Secrets Cleanup Script
=====================================

📄 Loading credentials from .envrc...
✅ All required variables found in .envrc

✅ GitHub CLI is authenticated

🔍 Checking current GitHub Secrets...

🗑️  Phase 1: Delete Old Secrets with Incorrect Credentials
-----------------------------------------------------------
  Skipping: SN_DEVOPS_USER (not found)
  Skipping: SN_DEVOPS_PASSWORD (not found)
  Skipping: SN_INSTANCE_URL (not found)

✅ No old secrets to delete

⚠️  Phase 2: Check Deprecated Secrets
--------------------------------------
  Found: SN_OAUTH_TOKEN
  Found: SERVICENOW_BASIC_AUTH

⚠️  Found 2 deprecated secrets
Consider deleting them manually if they're no longer needed:

  gh secret delete SN_OAUTH_TOKEN
  gh secret delete SERVICENOW_BASIC_AUTH

📝 Phase 3: Set Correct Secrets from .envrc
--------------------------------------------
  Setting: SERVICENOW_USERNAME
    ✅ Set
  Setting: SERVICENOW_PASSWORD
    ✅ Set
  Setting: SERVICENOW_INSTANCE_URL
    ✅ Set
  Setting: SN_ORCHESTRATION_TOOL_ID
    ✅ Set

✅ Phase 3 complete

🔍 Phase 4: Verify Final Secrets
---------------------------------
Current ServiceNow secrets:

  ✅ SERVICENOW_INSTANCE_URL (updated: 2025-10-23 16:35:17)
  ✅ SERVICENOW_PASSWORD (updated: 2025-10-23 16:35:17)
  ✅ SERVICENOW_USERNAME (updated: 2025-10-23 16:35:16)
  ✅ SN_ORCHESTRATION_TOOL_ID (updated: 2025-10-23 16:35:18)

🧪 Phase 5: Test Credentials Against ServiceNow API
-----------------------------------------------------
  Testing: Basic Authentication...
    ✅ Basic auth works (HTTP 200)
  Testing: Tool ID Validation...
    ✅ Tool ID exists (HTTP 200)
       Name: GithHubARC
       Active: true

📊 Summary
==========

✅ Old secrets deleted: 0
✅ Correct secrets set: 4
✅ API credentials validated successfully

📄 Next Steps:

1. Run a test workflow to verify the fix:
   gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f skip_build=true

2. Watch the workflow run:
   gh run watch --exit-status

3. The 'Preflight: Verify Basic Auth' step should now show:
   ✅ ServiceNow Basic auth verified (Artifacts)

✅ Cleanup complete!
```

## When to Use This Script

### Use when:
- ✅ ServiceNow workflows fail with HTTP 401 (authentication errors)
- ✅ Setting up ServiceNow integration for the first time
- ✅ After updating ServiceNow credentials in `.envrc`
- ✅ After changing ServiceNow instances
- ✅ Old secrets exist from previous setup attempts

### Don't use when:
- ❌ Credentials are working fine
- ❌ You don't have access to `.envrc`
- ❌ GitHub CLI is not authenticated

## Troubleshooting

### Error: "Missing required variables in .envrc"
**Solution**: Ensure your `.envrc` file contains all 4 required variables:
```bash
grep SERVICENOW .envrc
grep SN_ORCHESTRATION .envrc
```

### Error: "GitHub CLI is not authenticated"
**Solution**: Authenticate with GitHub:
```bash
gh auth login
```

### Warning: "Tool is INACTIVE"
**Solution**: Activate the tool in ServiceNow:
```bash
./scripts/activate-servicenow-tool.sh
```

Or manually:
1. Go to: https://your-instance.service-now.com/sn_devops_tool.do?sys_id=YOUR_TOOL_ID
2. Check "Active" checkbox
3. Save

### Error: "Basic auth failed (HTTP 401)"
**Possible causes**:
- Username or password is incorrect in `.envrc`
- Password contains special characters that need escaping
- User account is disabled in ServiceNow
- User lacks required roles

**Solution**:
1. Verify credentials in `.envrc` are correct
2. Test login manually: https://your-instance.service-now.com
3. Check user has `rest_service` and `x_snc_devops` roles

### Error: "Tool ID validation failed (HTTP 404)"
**Possible causes**:
- Tool ID is incorrect
- Tool was deleted from ServiceNow
- User lacks permission to view tools

**Solution**:
1. Verify tool ID in ServiceNow: Navigate to **System DevOps → Tools**
2. Find your GitHub tool and copy the `sys_id`
3. Update `SN_ORCHESTRATION_TOOL_ID` in `.envrc`

## Secret Naming Convention

**Current Standard** (use these):
- `SERVICENOW_USERNAME`
- `SERVICENOW_PASSWORD`
- `SERVICENOW_INSTANCE_URL`
- `SN_ORCHESTRATION_TOOL_ID`

**Deprecated** (don't use):
- ~~`SN_DEVOPS_USER`~~ → Use `SERVICENOW_USERNAME`
- ~~`SN_DEVOPS_PASSWORD`~~ → Use `SERVICENOW_PASSWORD`
- ~~`SN_INSTANCE_URL`~~ → Use `SERVICENOW_INSTANCE_URL`

## How the Workflow Resolves Secrets

The workflow checks secrets in this priority order:

```bash
# 1st priority (old names)
URL="${{ secrets.SN_INSTANCE_URL }}"
USER="${{ secrets.SN_DEVOPS_USER }}"
PASS="${{ secrets.SN_DEVOPS_PASSWORD }}"

# 2nd priority (new names - fallback)
if [ -z "$URL" ]; then URL="${{ secrets.SERVICENOW_INSTANCE_URL }}"; fi
if [ -z "$USER" ]; then USER="${{ secrets.SERVICENOW_USERNAME }}"; fi
if [ -z "$PASS" ]; then PASS="${{ secrets.SERVICENOW_PASSWORD }}"; fi
```

**Problem**: If old secrets exist with wrong values, they're used first!

**Solution**: Delete old secrets so the workflow uses the correct new ones.

## Related Scripts

- **`activate-servicenow-tool.sh`** - Activates the ServiceNow tool via API
- **`verify-servicenow-api.sh`** - Tests all 8 ServiceNow API endpoints
- **`diagnose-servicenow.sh`** - Comprehensive integration diagnostics

## Related Documentation

- **[SERVICENOW-SECRETS-CLEANUP.md](../docs/SERVICENOW-SECRETS-CLEANUP.md)** - Detailed explanation of the 2025-10-23 cleanup
- **[SERVICENOW-AUTHENTICATION-TROUBLESHOOTING.md](../docs/SERVICENOW-AUTHENTICATION-TROUBLESHOOTING.md)** - Auth troubleshooting guide
- **[COMPLETE-DEPLOYMENT-WORKFLOW.md](../docs/COMPLETE-DEPLOYMENT-WORKFLOW.md)** - End-to-end deployment guide

## Support

If issues persist after running this script:

1. Run diagnostics: `just sn-diagnose`
2. Check workflow logs: `gh run view --log`
3. Review documentation: `just sn-docs`
4. Test API manually: `./scripts/verify-servicenow-api.sh`
