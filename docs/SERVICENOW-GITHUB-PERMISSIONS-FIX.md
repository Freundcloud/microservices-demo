# ServiceNow GitHub Integration - Permissions Fix

**Created**: 2025-10-21
**Status**: Active Issue - Permission Denied
**Error**: Authorization credentials do not have the minimum required permissions

## Current Error

```
Alert level: Critical.
Existing webhooks cannot be retrieved. Authorization credentials do not have the minimum required permissions. For more information, see the error logs in All > DevOps > Administration > Error Logs.
```

## Root Cause

ServiceNow is trying to connect to GitHub but the **GitHub credentials** (PAT or GitHub App) don't have sufficient permissions to:
- Read existing webhooks
- Create new webhooks
- Subscribe to repository events

## Solution Options

### Option 1: GitHub Personal Access Token (PAT) - Quickest

If using PAT authentication, create a new token with correct permissions:

#### Step 1: Create New GitHub PAT

1. **Go to GitHub**: https://github.com/settings/tokens
2. **Click**: "Generate new token" → "Generate new token (classic)"
3. **Name**: `ServiceNow DevOps Integration`
4. **Expiration**: 90 days (or as per your policy)
5. **Select these scopes** (CRITICAL - must have ALL of these):

   **Repository Permissions** (for `Freundcloud/microservices-demo`):
   - ✅ `repo` - Full control of private repositories (or `public_repo` if only public)
     - ✅ `repo:status` - Access commit status
     - ✅ `repo_deployment` - Access deployment status
     - ✅ `public_repo` - Access public repositories

   **Webhook Permissions**:
   - ✅ `admin:repo_hook` - Full control of repository hooks
     - ✅ `write:repo_hook` - Write repository hooks
     - ✅ `read:repo_hook` - Read repository hooks

   **Workflow Permissions**:
   - ✅ `workflow` - Update GitHub Action workflows

   **Organization Permissions** (if applicable):
   - ✅ `admin:org_hook` - Full control of organization hooks (if setting up org-wide)

6. **Click**: "Generate token"
7. **Copy the token** - You won't see it again!

#### Step 2: Configure in ServiceNow

1. **In ServiceNow**, go back to the GitHub tool setup
2. **Find the credentials/authentication section**
3. **Paste the new PAT** with full permissions
4. **Save and test the connection**

### Option 2: GitHub App Integration (Recommended)

GitHub Apps provide better security and permission management.

#### Step 1: Create GitHub App

1. **In GitHub**, go to: https://github.com/organizations/Freundcloud/settings/apps/new

2. **Configure Basic Information**:
   - **GitHub App name**: `ServiceNow DevOps` (must be unique)
   - **Homepage URL**: `https://calitiiltddemo3.service-now.com`
   - **Callback URL**: (leave blank for now, ServiceNow will provide)
   - **Webhook URL**: `https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/webhook/github`
   - **Webhook secret**: Generate a strong random secret (save it!)

3. **Repository Permissions** (Select "Read & write" or "Read-only" as needed):
   - ✅ **Actions**: Read & write
   - ✅ **Checks**: Read & write
   - ✅ **Contents**: Read-only
   - ✅ **Deployments**: Read & write
   - ✅ **Metadata**: Read-only (mandatory)
   - ✅ **Pull requests**: Read & write
   - ✅ **Webhooks**: Read & write (CRITICAL!)
   - ✅ **Workflows**: Read & write

4. **Subscribe to events**:
   - ✅ Check run
   - ✅ Check suite
   - ✅ Deployment
   - ✅ Deployment status
   - ✅ Pull request
   - ✅ Push
   - ✅ Workflow job
   - ✅ Workflow run

5. **Where can this GitHub App be installed?**
   - Select: "Only on this account" (Freundcloud)

6. **Create the GitHub App**

7. **After creation**:
   - **Note the App ID** (you'll need this)
   - **Generate a private key** (Download the .pem file - you'll upload to ServiceNow)
   - **Install the app**: Click "Install App" → Select your organization (Freundcloud)
   - **Grant access** to `microservices-demo` repository
   - **Note the Installation ID** (visible in URL after installation)

#### Step 2: Configure GitHub App in ServiceNow

1. **In ServiceNow**, go to GitHub tool setup
2. **Select "GitHub App" as authentication method**
3. **Provide**:
   - **App ID**: (from GitHub)
   - **Installation ID**: (from GitHub, in the URL after installing)
   - **Private Key**: Upload the .pem file you downloaded
   - **Webhook Secret**: The secret you generated earlier
4. **Save and complete setup**

### Option 3: Check Existing Token Permissions

If you want to keep using the existing token, verify its permissions:

#### Check PAT Permissions via API

```bash
# Get your current GitHub token
GITHUB_TOKEN="your_github_pat_here"

# Check token scopes
curl -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  https://api.github.com/user \
  -I | grep -i "x-oauth-scopes"
```

**Required scopes should include**:
- `admin:repo_hook` or `write:repo_hook`
- `repo` or `public_repo`
- `workflow`

**If missing scopes**, the token needs to be regenerated with proper permissions (see Option 1).

#### Check GitHub App Permissions

If using GitHub App:

1. Go to: https://github.com/organizations/Freundcloud/settings/installations
2. Find the ServiceNow app installation
3. Click "Configure"
4. Check "Repository access" and "Permissions"
5. Ensure "Webhooks" permission is set to "Read & write"

## Common Permission Issues

### Issue 1: "Cannot retrieve webhooks"
**Cause**: Missing `admin:repo_hook` or `read:repo_hook` scope
**Fix**: Add `admin:repo_hook` to PAT scopes

### Issue 2: "Cannot create webhooks"
**Cause**: Missing `admin:repo_hook` or `write:repo_hook` scope
**Fix**: Add `admin:repo_hook` to PAT scopes

### Issue 3: "Cannot access workflow runs"
**Cause**: Missing `workflow` scope
**Fix**: Add `workflow` scope to PAT

### Issue 4: "GitHub App lacks permissions"
**Cause**: GitHub App not granted webhook permissions
**Fix**:
1. Go to GitHub App settings
2. Edit permissions
3. Set "Webhooks" to "Read & write"
4. Save (will prompt users to accept new permissions)

## ServiceNow User Permissions

Also ensure the ServiceNow user has proper roles:

**Required ServiceNow Roles**:
- `sn_devops.user` - Basic DevOps access
- `sn_devops.integration_user` - For external integrations
- `sn_devops.orchestration_admin` - To manage orchestration tools

**To check**:
1. Navigate to: `User Administration > Users`
2. Find user: `github_integration` (or the user creating the tool)
3. Check "Roles" tab
4. Add missing roles if needed

## Testing After Fix

### Test 1: Check GitHub API Access
```bash
# Using PAT
curl -H "Authorization: Bearer YOUR_GITHUB_PAT" \
  https://api.github.com/repos/Freundcloud/microservices-demo/hooks

# Should return 200 OK and list of webhooks (or empty array)
```

### Test 2: ServiceNow Connection Test
After updating credentials in ServiceNow:
1. Go to the GitHub tool configuration
2. Click "Test Connection" or similar button
3. Should show success message
4. Check that "Overall Status" changes to "connected" or "configured"

### Test 3: Webhook Creation
ServiceNow should automatically create webhooks. Verify:
```bash
# List webhooks
gh api /repos/Freundcloud/microservices-demo/hooks | jq '.[] | {id, url: .config.url, active}'

# Should see ServiceNow webhook:
# {
#   "id": <number>,
#   "url": "https://calitiiltddemo3.service-now.com/api/sn_devops/...",
#   "active": true
# }
```

## Quick Fix Guide

**If you just need it working FAST**:

1. **Create new GitHub PAT** with ALL these scopes:
   - `repo`
   - `admin:repo_hook`
   - `workflow`

2. **In ServiceNow**:
   - Find credential field in GitHub tool
   - Paste the new PAT
   - Save

3. **Test**:
   ```bash
   # Verify webhooks can be retrieved
   gh api /repos/Freundcloud/microservices-demo/hooks
   ```

4. **Retry the ServiceNow setup**

## Current Configuration

**Known Information**:
- **Instance**: `https://calitiiltddemo3.service-now.com`
- **Repository**: `Freundcloud/microservices-demo`
- **ServiceNow User**: `github_integration`
- **Old Tool ID**: `2fe9c38bc36c72d0e1bbf0cb050131cc` (being replaced)

**What You Need**:
- ✅ GitHub PAT with `admin:repo_hook`, `repo`, `workflow` scopes
- OR
- ✅ GitHub App with "Webhooks: Read & write" permission

## Next Steps After Fixing Permissions

1. **Complete ServiceNow tool setup** with new credentials
2. **Note new Tool ID and Integration Token**
3. **Update `.envrc`**:
   ```bash
   export SN_ORCHESTRATION_TOOL_ID='new_tool_id'
   export SN_DEVOPS_INTEGRATION_TOKEN='new_token'
   ```
4. **Update GitHub secrets**:
   ```bash
   source .envrc
   gh secret set SN_ORCHESTRATION_TOOL_ID --body "$SN_ORCHESTRATION_TOOL_ID"
   gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "$SN_DEVOPS_INTEGRATION_TOKEN"
   ```
5. **Test connection**:
   ```bash
   curl -X POST \
     "https://calitiiltddemo3.service-now.com/api/sn_devops/v3/devops/tool/test?toolId=${SN_ORCHESTRATION_TOOL_ID}&token=${SN_DEVOPS_INTEGRATION_TOKEN}"
   ```

## Related Documentation

- [SERVICENOW-WEBHOOK-TROUBLESHOOTING.md](SERVICENOW-WEBHOOK-TROUBLESHOOTING.md) - Webhook issues
- [SERVICENOW-DEVOPS-INTEGRATION-TOKEN-SETUP.md](SERVICENOW-DEVOPS-INTEGRATION-TOKEN-SETUP.md) - Token setup
- [GitHub PAT Documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub Apps Documentation](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps)

---

**Status**: Awaiting GitHub credentials with proper permissions
**Last Updated**: 2025-10-21
