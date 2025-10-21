# ServiceNow GitHub Webhook Permissions Fix

> **Issue**: "Existing webhooks cannot be retrieved. Authorization credentials do not have the minimum required permissions."
> **Impact**: ServiceNow can't verify webhooks exist (but webhooks ARE working)
> **Root Cause**: GitHub Personal Access Token (PAT) or GitHub App in ServiceNow lacks `admin:repo_hook` (read) permission
> **Severity**: Low (webhooks function, but ServiceNow shows warning)

---

## Problem Statement

ServiceNow displays this error in the GitHub tool configuration:

```
The credentials for this tool will expire in 6 Hours 34 Minutes.
Update credentials and connect the tool to prevent any loss of data.

This tool needs attention. Webhook is not configured correctly.

Existing webhooks cannot be retrieved. Authorization credentials do not have
the minimum required permissions. For more information, see the error logs in
All > DevOps > Administration > Error Logs.
```

## Current Webhook Status (GitHub Side)

All 6 webhooks are **ACTIVE** and functioning correctly:

```bash
gh api /repos/Freundcloud/microservices-demo/hooks
```

**Results**:
| ID | Endpoint | Active | Last Response |
|----|----------|--------|---------------|
| 576508188 | /api/sn_devops/v2/devops/tool/softwarequality | ✅ | HTTP 201 OK |
| 576551992 | /api/sn_devops/v2/devops/tool/artifact | ✅ | HTTP 201 OK |
| 576552088 | /api/sn_devops/v2/devops/tool/softwarequality | ✅ | HTTP 201 OK |
| 576552164 | /api/sn_devops/v2/devops/tool/test | ✅ | HTTP 201 OK |
| 576552273 | /api/sn_devops/v2/devops/tool/orchestration | ✅ | HTTP 201 OK |
| 576552349 | /api/sn_devops/v2/devops/tool/code | ✅ | HTTP 201 OK |

**All webhooks registered with Tool ID**: `4c5e482cc3383214e1bbf0cb05013196`

### What This Means

- ✅ **GitHub → ServiceNow**: Webhooks are delivering events successfully (HTTP 201)
- ❌ **ServiceNow → GitHub**: ServiceNow can't READ webhooks back to verify they exist
- ⚠️ **Impact**: Warning message in ServiceNow, but **no functional impact** on CI/CD workflows

---

## Root Cause

The GitHub authentication credentials configured in ServiceNow (either Personal Access Token or GitHub App) do **NOT** have the `admin:repo_hook` (read) permission.

### Required GitHub Permissions

For ServiceNow to **verify** webhooks exist, it needs:

**Classic Personal Access Token** (if using PAT):
- ✅ `repo` (full control of private repositories)
- ✅ `admin:repo_hook` ← **THIS IS MISSING**
  - `write:repo_hook` (write repo hooks)
  - `read:repo_hook` (read repo hooks) ← **REQUIRED TO READ WEBHOOKS**

**Fine-Grained Personal Access Token** (if using fine-grained PAT):
- Repository permissions:
  - Contents: Read and write
  - Metadata: Read-only
  - **Webhooks: Read and write** ← **REQUIRED**

**GitHub App** (if using GitHub App):
- Repository permissions:
  - **Webhooks: Read & write** ← **REQUIRED**

---

## Solution Options

### Option A: Update Personal Access Token (PAT) Permissions

**If ServiceNow is using a Classic GitHub PAT**:

1. **Navigate to GitHub Settings**:
   - Go to: https://github.com/settings/tokens
   - Find the token used by ServiceNow (check token description)

2. **Edit Token Permissions**:
   - Click "Edit" on the token
   - Ensure these scopes are checked:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `admin:repo_hook` (Full control of repository hooks)
       - ✅ `write:repo_hook` (Write repository hooks)
       - ✅ `read:repo_hook` (Read repository hooks) ← **ADD THIS**
   - Click "Update token"

3. **Regenerate Token** (if editing doesn't work):
   - Click "Regenerate token"
   - **IMPORTANT**: Copy the new token immediately (shown only once)
   - Update ServiceNow with new token (see "Update ServiceNow Configuration" below)

**If ServiceNow is using a Fine-Grained PAT**:

1. Navigate to: https://github.com/settings/personal-access-tokens/
2. Find the token, click "Edit"
3. Under "Repository permissions":
   - **Webhooks**: Set to "Read and write"
4. Save changes
5. Regenerate if needed and update ServiceNow

### Option B: Use GitHub App (Recommended)

ServiceNow documentation recommends using a **GitHub App** instead of PAT for better security and automatic token rotation.

**Create GitHub App**:

1. Navigate to: https://github.com/organizations/Freundcloud/settings/apps
2. Click "New GitHub App"
3. Configure:
   - **Name**: ServiceNow DevOps Integration
   - **Homepage URL**: https://calitiiltddemo3.service-now.com
   - **Webhook URL**: (leave blank, ServiceNow manages these)
   - **Webhooks**: Active

4. **Repository permissions** (set to "Read & write"):
   - Actions
   - Contents
   - Metadata (read-only)
   - Pull requests
   - **Webhooks** ← **CRITICAL**
   - Workflows

5. Click "Create GitHub App"
6. Note the **App ID** and **Installation ID**
7. Generate a **private key** (download and save securely)

**Install GitHub App**:

1. Navigate to: https://github.com/organizations/Freundcloud/settings/installations
2. Click "Install" next to your new app
3. Select repository: `Freundcloud/microservices-demo`
4. Note the **Installation ID** from URL

**Configure in ServiceNow**:

See "Update ServiceNow Configuration" section below.

### Option C: Ignore the Warning (Temporary)

If webhooks are functioning correctly (which they are), you can temporarily ignore this warning. It's a **verification issue**, not a **functional issue**.

**Pros**:
- No immediate action required
- Webhooks continue to work

**Cons**:
- Warning persists in ServiceNow
- ServiceNow can't verify webhook health
- May cause confusion for other admins

---

## Update ServiceNow Configuration

After updating GitHub credentials, update the ServiceNow GitHub tool configuration:

### Method 1: Via ServiceNow UI

1. **Navigate to GitHub Tool**:
   - URL: `https://calitiiltddemo3.service-now.com/sn_devops_orchestration_tool.do?sys_id=4c5e482cc3383214e1bbf0cb05013196`
   - Or: All > DevOps > Tools > GitHub

2. **Update Credentials**:
   - **If using PAT**:
     - Find "Personal Access Token" or "Token" field
     - Paste new token with `admin:repo_hook` permission

   - **If using GitHub App**:
     - Set "Authentication Type" to "GitHub App"
     - Enter **App ID**
     - Enter **Installation ID**
     - Upload **Private Key** file
     - Save

3. **Test Connection**:
   - Click "Test Connection" button
   - Should succeed without webhook warnings

### Method 2: Via ServiceNow REST API

**Update PAT**:
```bash
curl -X PATCH \
  -H "Content-Type: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d '{"token":"NEW_GITHUB_PAT_WITH_ADMIN_REPO_HOOK"}' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/4c5e482cc3383214e1bbf0cb05013196"
```

**Update to GitHub App**:
```bash
curl -X PATCH \
  -H "Content-Type: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d '{
    "auth_type":"github_app",
    "app_id":"APP_ID",
    "installation_id":"INSTALLATION_ID",
    "private_key":"-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/4c5e482cc3383214e1bbf0cb05013196"
```

---

## Verification Steps

After updating credentials:

### 1. Check ServiceNow Tool Status

Navigate to: `https://calitiiltddemo3.service-now.com/sn_devops_orchestration_tool.do?sys_id=4c5e482cc3383214e1bbf0cb05013196`

**Expected**:
- ✅ No warning about webhook configuration
- ✅ "Test Connection" succeeds
- ✅ "Connected" status indicator

### 2. Check GitHub Webhooks Visibility

In ServiceNow, the tool should now be able to display webhooks:

**Via UI**:
- Navigate to GitHub tool
- Look for "Webhooks" section
- Should display all 6 webhooks

**Via API**:
```bash
# ServiceNow should be able to query GitHub webhooks
curl -s -H "Accept: application/json" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/webhooks?toolId=4c5e482cc3383214e1bbf0cb05013196"
```

### 3. Test Webhook Delivery

Trigger a GitHub Actions workflow:

```bash
git commit --allow-empty -m "test: Verify ServiceNow webhook delivery"
git push origin main
```

**Check ServiceNow**:
- Navigate to: All > DevOps > Administration > Event Logs
- Should see webhook events being received
- No errors about authentication or permissions

---

## Troubleshooting

### "Credentials will expire" Warning

**Cause**: Personal Access Tokens have expiration dates
**Solutions**:
- **Option A**: Regenerate token with longer expiration (up to 90 days for classic PAT)
- **Option B**: Switch to GitHub App (tokens auto-rotate, no expiration)
- **Option C**: Set up automated token rotation via ServiceNow

### Webhooks Still Not Visible After Update

**Check**:
1. Token has `admin:repo_hook` scope (verify in GitHub)
2. Token is for correct user/organization
3. Token is not expired
4. ServiceNow tool configuration saved properly
5. ServiceNow can reach GitHub API (firewall/proxy)

**Test GitHub API Access**:
```bash
# From ServiceNow server (if possible)
curl -H "Authorization: token YOUR_GITHUB_PAT" \
  https://api.github.com/repos/Freundcloud/microservices-demo/hooks
```

Should return JSON array of webhooks (not 403/401 error).

### GitHub App Installation Issues

**Common Issues**:
1. **App not installed on repository**: Install via https://github.com/organizations/Freundcloud/settings/installations
2. **Incorrect Installation ID**: Check URL when viewing installation
3. **Private key format**: Ensure newlines preserved (`\n` characters)
4. **Permissions not granted**: Re-configure app permissions in GitHub

---

## Security Best Practices

### Personal Access Tokens

1. **Use Fine-Grained PATs** instead of Classic PATs when possible
2. **Set shortest expiration** that's practical (30-90 days)
3. **Restrict to specific repositories** (not all repos)
4. **Rotate regularly** (before expiration)
5. **Store securely** in ServiceNow secrets/credential store

### GitHub Apps

1. **Use GitHub Apps** instead of PATs for production
2. **Minimal permissions** (only what's needed)
3. **Private key protection** (store encrypted in ServiceNow)
4. **Monitor app activity** via GitHub audit log
5. **Revoke compromised apps** immediately

### ServiceNow Configuration

1. **Restrict access** to GitHub tool configuration
2. **Use dedicated service account** in ServiceNow
3. **Enable audit logging** for tool changes
4. **Document token rotation** procedures
5. **Test in non-prod first** before production changes

---

## Related Issues

### DevOps Change Workspace Visibility

This webhook permissions issue is **SEPARATE** from the DevOps Change workspace visibility issue:

- **Webhook Issue**: ServiceNow can't READ webhooks (verification only)
- **Change Workspace Issue**: Change requests not appearing in `/now/devops-change/changes/`

**Webhook issue does NOT prevent**:
- ✅ Change requests from being created
- ✅ Webhooks from delivering events
- ✅ CI/CD workflows from running
- ✅ Security tools from registering
- ✅ Artifacts from being registered

It only prevents ServiceNow from **verifying** that webhooks exist.

---

## References

- **ServiceNow Documentation**: [Configure GitHub Webhooks Manually](https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/task/config-webhooks-github-manually.html)
- **ServiceNow Documentation**: [GitHub Actions Integration](https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/concept/github-actions-integration-with-devops.html)
- **GitHub Documentation**: [Personal Access Token Permissions](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- **GitHub Documentation**: [GitHub Apps Permissions](https://docs.github.com/en/apps/creating-github-apps/setting-up-a-github-app/choosing-permissions-for-a-github-app)
- **GitHub API**: [Repository Webhooks](https://docs.github.com/en/rest/webhooks/repos)

---

## Summary

**Current State**:
- ✅ All 6 GitHub webhooks are ACTIVE and delivering events (HTTP 201)
- ❌ ServiceNow can't READ webhooks due to missing `admin:repo_hook` permission
- ⚠️ Warning displayed but **no functional impact** on CI/CD

**Recommended Fix**:
1. Switch to **GitHub App** authentication (most secure, auto-rotating)
2. Or update GitHub PAT to include `admin:repo_hook` scope
3. Update ServiceNow GitHub tool configuration
4. Verify webhook visibility in ServiceNow

**Priority**: Low (cosmetic warning, no workflow impact)

**Estimated Fix Time**: 15-30 minutes

---

**Status**: Documented, awaiting GitHub credentials update
**Updated**: 2025-10-22 00:02 UTC
**Author**: Claude Code
