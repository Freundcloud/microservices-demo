# ServiceNow Authentication Troubleshooting Guide

## Overview

This guide helps you diagnose and fix ServiceNow authentication failures in GitHub Actions workflows.

## Common Authentication Errors

### Error: HTTP 401 - Unauthorized

**Symptoms:**
```
❌ ServiceNow Basic auth failed (HTTP 401)
- HTTP 401 = Invalid username or password
```

**Causes & Solutions:**

#### 1. **GitHub Secrets Not Set**

**Check:**
- Go to your GitHub repository
- Settings → Secrets and variables → Actions
- Verify these secrets exist:
  - `SERVICENOW_USERNAME` (or `SN_DEVOPS_USER`)
  - `SERVICENOW_PASSWORD` (or `SN_DEVOPS_PASSWORD`)
  - `SERVICENOW_INSTANCE_URL` (or `SN_INSTANCE_URL`)
  - `SN_ORCHESTRATION_TOOL_ID`

**Fix:**
```bash
# From your local .envrc, set each as a GitHub Secret:
# GitHub UI → Settings → Secrets → New repository secret

Name: SERVICENOW_USERNAME
Value: github_integration

Name: SERVICENOW_PASSWORD
Value: oA3KqdUVI8Q_^>

Name: SERVICENOW_INSTANCE_URL
Value: https://calitiiltddemo3.service-now.com

Name: SN_ORCHESTRATION_TOOL_ID
Value: f62c4e49c3fcf614e1bbf0cb050131ef
```

#### 2. **Incorrect Credentials**

**Test Locally:**
```bash
# Source your credentials
source .envrc

# Test authentication directly
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"
```

**Expected Response:**
```json
{
  "result": [{"user_name": "github_integration", ...}]
}
```

**If this fails:**
- Password is wrong
- User account is locked/disabled in ServiceNow
- Password has special characters that need escaping

#### 3. **Password Special Characters**

If your password contains special characters like `^`, `>`, `<`, `!`, etc., they might need escaping.

**Test:**
```bash
# Try URL encoding the password
PASSWORD_ENCODED=$(printf %s "oA3KqdUVI8Q_^>" | jq -sRr @uri)
echo "Encoded: $PASSWORD_ENCODED"

# Test with encoded password
curl -u "github_integration:$PASSWORD_ENCODED" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"
```

**Fix in GitHub Secrets:**
- If URL encoding works, store the **original** password in GitHub Secrets (not encoded)
- The workflow uses `curl -u` which handles encoding automatically

#### 4. **User Account Disabled**

**Check in ServiceNow:**
1. Navigate to: `sys_user.list`
2. Search for: `github_integration`
3. Verify:
   - Active: ✅ (checked)
   - Locked out: ❌ (not checked)
   - Password needs reset: ❌ (not checked)

### Error: HTTP 403 - Forbidden

**Symptoms:**
```
❌ ServiceNow Basic auth failed (HTTP 403)
- HTTP 403 = User lacks required permissions
```

**Cause:** User has valid credentials but lacks necessary roles.

**Required Roles:**
- `rest_service` - For API access
- `x_snc_devops` - For DevOps operations (if using DevOps app)
- `sn_devops.devops_user` - For DevOps user access

**Fix:**
1. Log into ServiceNow as admin
2. Navigate to: `sys_user.list`
3. Open user: `github_integration`
4. Go to "Roles" related list
5. Add missing roles

**Verification:**
```bash
# After adding roles, test again
source .envrc
./scripts/verify-servicenow-api.sh
```

### Error: HTTP 404 - Not Found

**Symptoms:**
```
❌ ServiceNow Basic auth failed (HTTP 404)
- HTTP 404 = Invalid instance URL
```

**Cause:** Wrong ServiceNow instance URL.

**Check:**
```bash
# Verify URL format
echo $SERVICENOW_INSTANCE_URL
# Should be: https://your-instance.service-now.com
# NOT: https://your-instance.service-now.com/
# NOT: http://your-instance.service-now.com (must be https)
```

**Common Mistakes:**
- ❌ `http://` instead of `https://`
- ❌ Trailing slash: `https://instance.service-now.com/`
- ❌ Wrong instance name
- ❌ Missing subdomain

**Fix:**
```bash
# Correct format
SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
```

## Debugging Workflow Failures

### Step 1: Check Which Secrets Are Set

In your workflow run logs, look for the validation step:

```
🔐 ServiceNow Inputs: Register Artifacts
- URL: present ✅ or MISSING ❌
- Username: present ✅ or MISSING ❌
- Password: present ✅ or MISSING ❌
- Tool ID: present ✅ or MISSING ❌
```

**If any show MISSING:**
- Go to GitHub → Settings → Secrets and variables → Actions
- Add the missing secret(s)

### Step 2: Verify Credentials Locally

```bash
# Run the verification script
source .envrc
./scripts/verify-servicenow-api.sh
```

**Expected Output:**
```
✅ TEST 1: Basic Authentication - PASS
✅ TEST 2: Tool ID Validation - PASS
✅ TEST 3: Change Request API - PASS
✅ TEST 4: Work Item API - PASS
✅ TEST 5: Artifact API - PASS
✅ TEST 6: Attachment API - PASS
```

**If tests fail locally:**
1. Your credentials are wrong (fix in `.envrc`)
2. User lacks roles (fix in ServiceNow)
3. ServiceNow instance is down (check status)

**If tests pass locally but fail in GitHub Actions:**
1. GitHub Secrets don't match `.envrc` values
2. Copy values from `.envrc` to GitHub Secrets exactly

### Step 3: Compare Local vs GitHub Credentials

```bash
# Show first 3 characters of each credential (for comparison)
echo "Username: ${SERVICENOW_USERNAME:0:3}***"
echo "Instance: ${SERVICENOW_INSTANCE_URL:0:30}..."
echo "Tool ID: ${SN_ORCHESTRATION_TOOL_ID:0:8}..."
```

Compare these with what you set in GitHub Secrets:
- Username should start with: `git***` (github_integration)
- Instance should start with: `https://calitiiltddemo3.se...`
- Tool ID should start with: `f62c4e49...`

### Step 4: Re-create GitHub Secrets

If nothing works, delete and re-create ALL secrets:

1. **Delete old secrets:**
   - GitHub → Settings → Secrets → Delete each one

2. **Re-create from `.envrc`:**
   ```bash
   # Show values to copy (excluding password)
   source .envrc
   echo "SERVICENOW_USERNAME=$SERVICENOW_USERNAME"
   echo "SERVICENOW_INSTANCE_URL=$SERVICENOW_INSTANCE_URL"
   echo "SN_ORCHESTRATION_TOOL_ID=$SN_ORCHESTRATION_TOOL_ID"
   # Copy password manually from .envrc line 48
   ```

3. **Trigger workflow again**

## Quick Diagnostics

### Run Full Verification

```bash
# This tests all APIs with your credentials
source .envrc
./scripts/verify-servicenow-api.sh
```

### Test Single Endpoint

```bash
source .envrc

# Test authentication
curl -v -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" 2>&1 | grep -E "(HTTP|401|403|200)"
```

### Check Tool Status

```bash
source .envrc

# Verify tool exists and is active
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/$SN_ORCHESTRATION_TOOL_ID?sysparm_fields=name,active" | jq .
```

**Should show:**
```json
{
  "result": {
    "name": "GithHubARC",
    "active": "true"  ← Must be true!
  }
}
```

**If active is false:**
```bash
# Try to activate via API
./scripts/activate-servicenow-tool.sh

# Or activate manually in ServiceNow UI:
# https://calitiiltddemo3.service-now.com/sn_devops_tool.do?sys_id=f62c4e49c3fcf614e1bbf0cb050131ef
```

## Known Issues

### 1. Tool Not Active

**Symptom:** All tests pass except workflows fail at change creation.

**Cause:** ServiceNow DevOps tool is not activated.

**Fix:**
```bash
source .envrc
./scripts/activate-servicenow-tool.sh
```

### 2. Password with Special Characters

**Symptom:** Local tests work, GitHub Actions fail with 401.

**Cause:** Password might be getting interpreted differently in GitHub Actions environment.

**Workaround:** Use a simpler password without special characters (for testing).

### 3. Secrets Not Refreshing

**Symptom:** Updated secrets but workflow still fails.

**Fix:**
- Delete the secret completely
- Wait 1 minute
- Re-create the secret
- Trigger a new workflow run (not re-run old one)

## Still Having Issues?

### Collect Diagnostic Information

```bash
# Run full verification and save output
source .envrc
./scripts/verify-servicenow-api.sh > servicenow-diagnostics.txt 2>&1

# Check the output
cat servicenow-diagnostics.txt
```

### Check Workflow Logs

In GitHub Actions, expand these sections:
1. "Validate ServiceNow Inputs" - Shows which credentials are present
2. "Preflight: Verify Basic Auth" - Shows authentication test results
3. Look for the detailed troubleshooting section with HTTP codes

### Contact Support

If all else fails, provide:
- Output of `./scripts/verify-servicenow-api.sh`
- HTTP error code from workflow logs
- ServiceNow instance URL (first 30 chars)
- Confirmation that user has required roles

## Success Checklist

- [ ] All GitHub Secrets are set correctly
- [ ] Local verification script passes all tests
- [ ] ServiceNow tool is activated (`active: true`)
- [ ] User has required roles (rest_service, x_snc_devops, sn_devops.devops_user)
- [ ] Workflow validation step shows all credentials "present"
- [ ] Workflow preflight check passes with HTTP 200

Once all items are checked, your workflows should work!
