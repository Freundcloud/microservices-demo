# GitHub Secrets Setup for ServiceNow Integration

> Complete guide for configuring GitHub repository secrets for ServiceNow integration
> Last Updated: 2025-10-16

## Overview

The updated workflows require **4 GitHub Secrets** for ServiceNow integration:

1. `SERVICENOW_INSTANCE_URL` - Your ServiceNow instance URL
2. `SERVICENOW_USERNAME` - Integration user account
3. `SERVICENOW_PASSWORD` - Integration user password
4. `SERVICENOW_ORCHESTRATION_TOOL_ID` - GitHub tool sys_id

## Prerequisites

Before adding GitHub secrets, ensure you have:

- ✅ ServiceNow instance access (admin rights)
- ✅ Created `github_integration` user in ServiceNow
- ✅ Assigned required roles: `rest_service`, `api_analytics_read`, `devops_user`
- ✅ Created GitHub Tool in ServiceNow DevOps
- ✅ Extracted Tool sys_id from ServiceNow URL

**Need help with ServiceNow setup?** See: [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md)

## Step-by-Step Setup

### Step 1: Navigate to GitHub Secrets Settings

1. Go to your GitHub repository
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. You should see the "Actions secrets" page

**Direct URL format**:
```
https://github.com/YOUR-ORG/microservices-demo/settings/secrets/actions
```

### Step 2: Add SERVICENOW_INSTANCE_URL

1. Click **"New repository secret"** button
2. Enter details:
   ```
   Name: SERVICENOW_INSTANCE_URL
   Secret: https://calitiiltddemo3.service-now.com
   ```
3. Click **"Add secret"**

**Important Notes**:
- ⚠️ Do NOT include trailing slash
- ✅ Use HTTPS (not HTTP)
- ✅ Example: `https://calitiiltddemo3.service-now.com` ← Correct
- ❌ Example: `https://calitiiltddemo3.service-now.com/` ← Wrong (trailing slash)

### Step 3: Add SERVICENOW_USERNAME

1. Click **"New repository secret"**
2. Enter details:
   ```
   Name: SERVICENOW_USERNAME
   Secret: github_integration
   ```
3. Click **"Add secret"**

**Important Notes**:
- This must match the user created in ServiceNow
- Default: `github_integration`
- Must have roles: `rest_service`, `api_analytics_read`, `devops_user`

### Step 4: Add SERVICENOW_PASSWORD

1. Click **"New repository secret"**
2. Enter details:
   ```
   Name: SERVICENOW_PASSWORD
   Secret: [YOUR-PASSWORD-HERE]
   ```
3. Click **"Add secret"**

**Important Security Notes**:
- 🔒 This is the password for the `github_integration` user
- ⚠️ Keep this password secure and complex
- ✅ Use password manager to generate and store
- ✅ Rotate regularly (every 90 days recommended)
- ❌ Never commit this password to code
- ❌ Never share in plain text

**Example working password**: `oA3KqdUVI8Q_^>`

**Password Requirements**:
- Minimum length: 8 characters (16+ recommended)
- Mix of upper/lowercase, numbers, symbols
- Avoid overly complex shell special characters: `$`, `` ` ``, `"`, `'`, `\`
- Simpler passwords reduce shell escaping issues

**Need to reset password?** See: [SERVICENOW-PASSWORD-MANAGEMENT.md](SERVICENOW-PASSWORD-MANAGEMENT.md)

### Step 5: Add SERVICENOW_ORCHESTRATION_TOOL_ID

1. Click **"New repository secret"**
2. Enter details:
   ```
   Name: SERVICENOW_ORCHESTRATION_TOOL_ID
   Secret: 4eaebb06c320f690e1bbf0cb05013135
   ```
3. Click **"Add secret"**

**How to find your Tool sys_id**:

1. Log into ServiceNow
2. Navigate to: **DevOps** → **Orchestration** → **GitHub**
3. Open your GitHub tool record
4. Copy the sys_id from the URL:

**Modern ServiceNow URL format**:
```
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135
                                                                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                                                                     This is your sys_id
```

**Need detailed extraction guide?** See: [SERVICENOW-SYSID-EXTRACTION-GUIDE.md](SERVICENOW-SYSID-EXTRACTION-GUIDE.md)

## Verification

### Step 1: Verify All Secrets Added

After adding all 4 secrets, your "Actions secrets" page should show:

```
Repository secrets
─────────────────────────────────────────────────
SERVICENOW_INSTANCE_URL         Updated [DATE]
SERVICENOW_USERNAME             Updated [DATE]
SERVICENOW_PASSWORD             Updated [DATE]
SERVICENOW_ORCHESTRATION_TOOL_ID Updated [DATE]
```

**Important**: You cannot view secret values after creation (security feature)

### Step 2: Test Authentication

Create a test workflow to verify authentication:

```yaml
# .github/workflows/test-servicenow-auth.yaml
name: Test ServiceNow Authentication

on:
  workflow_dispatch:

jobs:
  test-auth:
    runs-on: ubuntu-latest
    steps:
      - name: Test ServiceNow API
        run: |
          # Create Basic Auth header
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          # Test API call
          RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Accept: application/json" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sys_user?sysparm_limit=1")

          HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

          if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Authentication successful!"
            echo "$RESPONSE" | grep -v "HTTP_CODE:"
          else
            echo "❌ Authentication failed with HTTP $HTTP_CODE"
            echo "$RESPONSE" | grep -v "HTTP_CODE:"
            exit 1
          fi
```

**Run the test**:
1. Go to: **Actions** → **Test ServiceNow Authentication**
2. Click **"Run workflow"**
3. Check results:
   - ✅ HTTP 200 = Authentication works!
   - ❌ HTTP 401 = Authentication failed (check credentials)
   - ❌ HTTP 403 = Permissions issue (check roles)

**If authentication fails**: See [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)

### Step 3: Test Workflows

After secrets are configured, test each workflow:

**1. Test Security Scanning**:
```bash
# Trigger manually or push to main/develop
git push origin main
```
- Workflow: `.github/workflows/security-scan-servicenow.yaml`
- Expected: Security results uploaded to ServiceNow
- Verify: Check ServiceNow → Security → Security Results

**2. Test Deployment**:
```bash
# Trigger deploy workflow
gh workflow run deploy-with-servicenow.yaml
```
- Workflow: `.github/workflows/deploy-with-servicenow.yaml`
- Expected: Change request created, deployment tracked
- Verify: Check ServiceNow → Change → All

**3. Test EKS Discovery**:
```bash
# Trigger discovery workflow
gh workflow run eks-discovery.yaml
```
- Workflow: `.github/workflows/eks-discovery.yaml`
- Expected: Cluster and services in CMDB
- Verify: Check ServiceNow → CMDB → u_eks_cluster and u_microservice tables

## Troubleshooting

### Secret Not Found Errors

**Symptom**: Workflow fails with "secret not found"

**Solution**:
1. Verify secret name matches exactly (case-sensitive)
2. Check you're adding to the correct repository
3. Ensure workflow references match secret names:
   ```yaml
   ${{ secrets.SERVICENOW_INSTANCE_URL }}  # Correct
   ${{ secrets.SN_INSTANCE_URL }}          # Wrong (old name)
   ```

### Authentication Failures (401)

**Symptom**: Workflow fails with HTTP 401 Unauthorized

**Solutions**:
1. **Verify username is correct**: Should be `github_integration`
2. **Check password**: Reset in ServiceNow if unsure
3. **Verify roles**: User must have `rest_service` role
4. **Check account status**: User must be Active, not Locked

**Complete troubleshooting guide**: [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)

### Missing Tool ID Error

**Symptom**: Workflow fails finding GitHub tool

**Solutions**:
1. Verify sys_id is 32-character hex string
2. Check tool exists in ServiceNow DevOps
3. Extract sys_id from correct URL section

**Complete guide**: [SERVICENOW-SYSID-EXTRACTION-GUIDE.md](SERVICENOW-SYSID-EXTRACTION-GUIDE.md)

### Permission Errors (403)

**Symptom**: HTTP 403 Forbidden errors

**Solutions**:
1. Check user has all required roles:
   - `rest_service` (required for API access)
   - `api_analytics_read` (required for analytics)
   - `devops_user` (required for DevOps operations)
2. Verify user is Active (not locked)
3. Check ACL rules aren't blocking API access

### URL Format Errors

**Symptom**: Connection timeout or DNS errors

**Solutions**:
1. Remove trailing slash from `SERVICENOW_INSTANCE_URL`
2. Verify HTTPS (not HTTP)
3. Test URL in browser first
4. Check ServiceNow instance is accessible

## Security Best Practices

### Password Management

**✅ Do**:
- Use strong, unique passwords (16+ characters)
- Rotate passwords every 90 days
- Store in password manager
- Use service account (not personal account)
- Monitor authentication logs

**❌ Don't**:
- Share passwords in Slack, email, etc.
- Commit passwords to code
- Use same password for multiple services
- Use weak/simple passwords
- Use personal user accounts

### Secret Rotation

**Recommended schedule**:
- **Passwords**: Every 90 days
- **After security incident**: Immediately
- **When team members leave**: Within 24 hours

**Rotation process**:
1. Reset password in ServiceNow
2. Update GitHub secret
3. Test workflows
4. Document change

### Access Control

**Limit access to**:
- GitHub repository admin access (can view/edit secrets)
- ServiceNow integration user (minimal privileges)
- ServiceNow admin console (for user management)

**Audit regularly**:
- Review who has repository admin access
- Check ServiceNow authentication logs
- Monitor workflow execution logs

## Required Roles Summary

The `github_integration` user **must have** these roles:

| Role | Purpose | Required For |
|------|---------|--------------|
| `rest_service` | Basic REST API access | ✅ All API calls |
| `api_analytics_read` | Read API analytics | ✅ Security results upload |
| `devops_user` | DevOps operations | ✅ Change automation |

**How to verify roles**:
1. Log into ServiceNow as admin
2. Navigate to: **User Administration** → **Users**
3. Search for: `github_integration`
4. Open user record
5. Click **Roles** tab
6. Verify all 3 roles present

**Missing roles?** See: [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) Task 1.4

## Workflow Migration Summary

All workflows have been updated to use Basic Authentication:

| Workflow | Status | Changes Made |
|----------|--------|--------------|
| `deploy-with-servicenow.yaml` | ✅ Complete | Updated to v2.0.0, Basic Auth |
| `security-scan-servicenow.yaml` | ✅ Complete | Updated all security uploads |
| `eks-discovery.yaml` | ✅ Complete | Updated CMDB API calls |

**Old variable names (deprecated)**:
- ❌ `SN_INSTANCE_URL` → Now: `SERVICENOW_INSTANCE_URL`
- ❌ `SN_DEVOPS_TOKEN` → Now: `SERVICENOW_PASSWORD`
- ❌ `SN_OAUTH_TOKEN` → Now: `SERVICENOW_PASSWORD`
- ❌ `SN_TOOL_ID` → Now: `SERVICENOW_ORCHESTRATION_TOOL_ID`

**If you have old secrets**: You can delete them (not used anymore)

## Complete Configuration Checklist

Use this checklist to verify complete setup:

### ServiceNow Configuration
- [ ] Created `github_integration` user
- [ ] Set strong password for user
- [ ] Added roles: `rest_service`, `api_analytics_read`, `devops_user`
- [ ] User is Active (not locked)
- [ ] Tested authentication with curl
- [ ] Created GitHub Tool in DevOps
- [ ] Extracted Tool sys_id

### GitHub Secrets
- [ ] Added `SERVICENOW_INSTANCE_URL`
- [ ] Added `SERVICENOW_USERNAME`
- [ ] Added `SERVICENOW_PASSWORD`
- [ ] Added `SERVICENOW_ORCHESTRATION_TOOL_ID`
- [ ] All 4 secrets visible in repository settings
- [ ] Tested authentication with test workflow

### Workflow Testing
- [ ] Tested `security-scan-servicenow.yaml`
- [ ] Tested `deploy-with-servicenow.yaml`
- [ ] Tested `eks-discovery.yaml`
- [ ] Verified security results in ServiceNow
- [ ] Verified change requests in ServiceNow
- [ ] Verified CMDB entries in ServiceNow

### Documentation Review
- [ ] Read [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md)
- [ ] Read [SERVICENOW-PASSWORD-MANAGEMENT.md](SERVICENOW-PASSWORD-MANAGEMENT.md)
- [ ] Read [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)
- [ ] Bookmarked troubleshooting guides

## Next Steps

After completing GitHub secrets setup:

1. **Test each workflow**: Run manually and verify ServiceNow integration
2. **Monitor execution**: Check GitHub Actions logs for errors
3. **Verify ServiceNow**: Confirm data appears in ServiceNow tables
4. **Document team process**: Share this guide with team members
5. **Schedule secret rotation**: Set calendar reminder for 90 days

## Support Resources

### Documentation
- [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) - Complete ServiceNow setup
- [SERVICENOW-PASSWORD-MANAGEMENT.md](SERVICENOW-PASSWORD-MANAGEMENT.md) - Password management
- [SERVICENOW-SYSID-EXTRACTION-GUIDE.md](SERVICENOW-SYSID-EXTRACTION-GUIDE.md) - Extract Tool sys_id
- [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md) - Fix authentication errors
- [SERVICENOW-AUTH-TROUBLESHOOTING.md](SERVICENOW-AUTH-TROUBLESHOOTING.md) - Detailed troubleshooting

### Working Configuration Example
```yaml
# Tested and verified configuration
Instance URL: https://calitiiltddemo3.service-now.com
Username: github_integration
Password: oA3KqdUVI8Q_^>
Tool sys_id: 4eaebb06c320f690e1bbf0cb05013135
Roles: rest_service, api_analytics_read, devops_user
```

### Test Commands
```bash
# Test authentication locally
INSTANCE_URL="https://calitiiltddemo3.service-now.com"
USERNAME="github_integration"
PASSWORD="oA3KqdUVI8Q_^>"

curl -s -w "\nHTTP: %{http_code}\n" \
  -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1"

# Expected: HTTP: 200
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**Tested Configuration**: calitiiltddemo3.service-now.com
