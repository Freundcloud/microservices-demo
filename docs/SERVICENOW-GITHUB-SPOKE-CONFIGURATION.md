# ServiceNow GitHub Spoke Configuration Guide

> Complete guide to installing and configuring the GitHub Spoke plugin in ServiceNow
>
> Last Updated: 2025-10-22
> Version: 1.0

## Overview

The **ServiceNow GitHub Spoke** is an IntegrationHub plugin that enables native bidirectional integration between ServiceNow and GitHub. It provides pre-built actions for managing repositories, pull requests, issues, and more directly from ServiceNow Flow Designer.

### What is a "Spoke"?

In ServiceNow terminology:
- **IntegrationHub** - The platform for building integrations
- **Spoke** - A plugin containing pre-built integration actions for a specific application (like GitHub, Slack, Jira)
- **Flow Designer** - Visual workflow builder that uses Spoke actions

## Prerequisites

### ServiceNow Requirements

1. **IntegrationHub License**
   - Required for Spoke functionality
   - Check: Navigate to **System Diagnostics** > **Licensing** > Look for "IntegrationHub"
   - If missing, contact your ServiceNow Account Manager

2. **ServiceNow Version**
   - Minimum: Tokyo release or later
   - Recommended: Vancouver, Washington, or Xanadu releases
   - Check: Click profile icon > **About ServiceNow**

3. **Admin/IntegrationHub Admin Role**
   - Required for installation and configuration
   - Check: **User Administration** > **Users** > Your user > **Roles**

### GitHub Requirements

1. **GitHub Account** with appropriate permissions:
   - Organization Owner (for org-level integrations)
   - Repository Admin (for repo-level integrations)

2. **GitHub Personal Access Token (Classic)** with scopes:
   - `repo` (Full control of private repositories)
   - `admin:org` (Full control of orgs, teams, and projects - if using org features)
   - `workflow` (Update GitHub Action workflows)
   - `read:packages` (Download packages from GitHub Package Registry)
   - `admin:repo_hook` (Full control of repository hooks)

   **Or GitHub App** (recommended for production):
   - Create a GitHub App with required permissions
   - Install app to organization/repositories
   - Generate private key for authentication

## Installation Steps

### Step 1: Install GitHub Spoke Plugin

#### Option A: Via ServiceNow Store (Recommended)

1. **Navigate to ServiceNow Store**:
   ```
   https://<your-instance>.service-now.com/sn_devstudio_store.do
   ```
   Or: **All** > **System Applications** > **All Available Applications** > **All**

2. **Search for "GitHub"**:
   - Look for: **"GitHub Spoke"** or **"GitHub IntegrationHub"**
   - Publisher: ServiceNow

3. **Install the Spoke**:
   - Click **Install** or **Get**
   - Review required roles and dependencies
   - Click **Activate**
   - Wait for installation (2-5 minutes)

4. **Verify Installation**:
   - Navigate to: **All** > **System Applications** > **Applications**
   - Search for: "GitHub"
   - Status should be: **Active**
   - Expected apps:
     - **GitHub Spoke** (com.snc.integration.github)
     - **IntegrationHub GitHub Spoke** (com.glide.hub.integrations.github)

#### Option B: Manual Upload (If Store Not Available)

1. **Download GitHub Spoke**:
   - Contact ServiceNow Support or your TAM
   - Request: GitHub Spoke plugin XML file

2. **Upload Plugin**:
   - Navigate to: **System Definition** > **Plugins**
   - Click **Upload Plugin**
   - Select downloaded XML file
   - Click **Upload**
   - Activate when prompted

### Step 2: Create GitHub Connection (Credential)

#### Generate GitHub Personal Access Token

1. **Go to GitHub**:
   ```
   https://github.com/settings/tokens
   ```

2. **Generate new token (classic)**:
   - Click: **Generate new token** > **Generate new token (classic)**
   - Note: "ServiceNow Integration"
   - Expiration: 90 days or No expiration (based on security policy)
   - Select scopes:
     - ✅ `repo` (all sub-scopes)
     - ✅ `workflow`
     - ✅ `admin:repo_hook`
     - ✅ `admin:org` (if needed)
     - ✅ `read:packages` (if using packages)

3. **Copy Token**:
   - Click **Generate token**
   - **Copy the token immediately** (you won't see it again)
   - Example format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

#### Create Connection in ServiceNow

1. **Navigate to Connections**:
   ```
   All > Connections & Credentials > Connection & Credential Aliases
   ```

2. **Create New Connection Alias**:
   - Click **New**
   - **Name**: `GitHub Production` (or descriptive name)
   - **Type**: Select **Connection & Credential** from dropdown

3. **Configure Connection**:
   - Click on the new alias to edit
   - Under **Connections** tab, click **New**

   **Connection Details**:
   - **Name**: `GitHub API Connection`
   - **Credential**: (Create new - see next step)
   - **Connection URL**: `https://api.github.com`
   - **Connection timeout**: `30` (seconds)

4. **Create Credential**:
   - Click **New** next to Credential field
   - **Credential Type**: Select **Basic Auth** or **API Key**

   **For Basic Auth** (Token as password):
   - **Name**: `GitHub PAT - Production`
   - **User name**: Your GitHub username (e.g., `olafkfreund`)
   - **Password**: Paste your GitHub Personal Access Token
   - Click **Submit**

   **For API Key** (Recommended):
   - **Name**: `GitHub PAT - Production`
   - **API key**: Paste your GitHub Personal Access Token
   - Click **Submit**

5. **Test Connection**:
   - Back in Connection record, click **Test Connection**
   - Expected result: ✅ **Connection Successful**
   - If failed: Check token permissions and URL

### Step 3: Configure GitHub Spoke Actions

#### Access Flow Designer

1. **Navigate to Flow Designer**:
   ```
   All > Process Automation > Flow Designer
   ```

2. **Create New Flow** (for testing):
   - Click **New** > **Flow**
   - Name: `Test GitHub Integration`
   - Application: Choose your application scope

#### Add GitHub Actions

**Available GitHub Spoke Actions** (examples):

1. **Repository Actions**:
   - `Get Repository` - Fetch repository details
   - `List Repositories` - List all accessible repos
   - `Create Repository` - Create new repository
   - `Update Repository` - Modify repository settings

2. **Issue Actions**:
   - `Get Issue` - Fetch issue details
   - `List Issues` - Query issues with filters
   - `Create Issue` - Create new issue
   - `Update Issue` - Modify issue (labels, assignees, state)
   - `Close Issue` - Close an issue

3. **Pull Request Actions**:
   - `Get Pull Request` - Fetch PR details
   - `List Pull Requests` - Query PRs
   - `Create Pull Request` - Create new PR
   - `Merge Pull Request` - Merge a PR
   - `Update Pull Request` - Modify PR

4. **Branch Actions**:
   - `Get Branch` - Fetch branch details
   - `List Branches` - List all branches
   - `Create Branch` - Create new branch
   - `Delete Branch` - Delete branch

5. **Webhook Actions**:
   - `Create Webhook` - Register webhook
   - `Delete Webhook` - Remove webhook
   - `List Webhooks` - List configured webhooks

#### Configure a Test Action

Let's test with "List Repositories":

1. **Add Action**:
   - In Flow Designer, click **Add an Action, Flow Logic, or Subflow**
   - Search: "GitHub"
   - Select: **List Repositories**

2. **Configure Action**:
   - **Connection**: Select your connection alias (e.g., `GitHub Production`)
   - **Owner**: Your GitHub username or organization name
   - **Type**: `all` (or `owner`, `public`, `private`)
   - **Per page**: `10`

3. **Add Output**:
   - Click on the action
   - Note the output data pills (e.g., `Response Body`)

4. **Test the Flow**:
   - Click **Test**
   - Click **Run Test**
   - Check execution log for repositories returned

### Step 4: Create Connection Alias (Optional but Recommended)

Connection Aliases allow you to swap connections without modifying flows (e.g., dev vs prod).

1. **Navigate to Connection Aliases**:
   ```
   All > Connections & Credentials > Connection & Credential Aliases
   ```

2. **Create Alias**:
   - Click **New**
   - **Name**: `GitHub_Default`
   - **Type**: Connection & Credential
   - **Connection**: Select your GitHub connection

3. **Use Alias in Flows**:
   - In Flow Designer actions, select the alias instead of direct connection
   - Swap connections by updating the alias (no flow changes needed)

## Advanced Configuration

### Using GitHub App Instead of PAT

GitHub Apps provide more granular permissions and better security.

#### Create GitHub App

1. **In GitHub**:
   - Navigate to: **Settings** > **Developer settings** > **GitHub Apps**
   - Click: **New GitHub App**

2. **Configure App**:
   - **GitHub App name**: `ServiceNow Integration`
   - **Homepage URL**: `https://<your-instance>.service-now.com`
   - **Webhook URL**: `https://<your-instance>.service-now.com/api/now/webhook/github`
   - **Webhook secret**: Generate strong secret (save for later)

3. **Permissions** (Repository permissions):
   - **Issues**: Read and write
   - **Pull requests**: Read and write
   - **Contents**: Read and write
   - **Metadata**: Read-only (auto-selected)
   - **Workflows**: Read and write

4. **Subscribe to Events**:
   - ✅ Issues
   - ✅ Pull request
   - ✅ Push
   - ✅ Workflow run

5. **Create App**:
   - Click **Create GitHub App**
   - Generate and download private key (.pem file)
   - Note the App ID

#### Configure GitHub App in ServiceNow

1. **Create GitHub App Credential**:
   - Navigate to: **Connections & Credentials** > **Credentials**
   - Click **New**
   - **Type**: GitHub App
   - **App ID**: From GitHub App settings
   - **Installation ID**: Install app to org/repo, get installation ID from URL
   - **Private Key**: Paste contents of .pem file

2. **Update Connection**:
   - Use GitHub App credential instead of PAT
   - Test connection

### Configure Webhooks for Real-Time Updates

Webhooks push events from GitHub to ServiceNow in real-time.

#### In GitHub

1. **Repository Settings** > **Webhooks** > **Add webhook**:
   - **Payload URL**: `https://<instance>.service-now.com/api/now/webhook/github`
   - **Content type**: `application/json`
   - **Secret**: Strong random string (save for ServiceNow)
   - **Events**: Select specific events (Issues, PRs, Push, etc.)
   - **Active**: ✅

#### In ServiceNow

1. **Create Webhook Registry**:
   - Navigate to: **System Web Services** > **Webhooks** > **Registry**
   - Click **New**
   - **Name**: `GitHub Webhook`
   - **Authentication**: Basic (use secret as password)
   - **Processing script**:

   ```javascript
   (function process(request, response) {
       var payload = request.body.data;
       var event = request.headers['x-github-event'];

       // Route based on event type
       if (event == 'issues') {
           handleIssueEvent(payload);
       } else if (event == 'pull_request') {
           handlePREvent(payload);
       }

       response.setStatus(200);
   })(request, response);

   function handleIssueEvent(payload) {
       // Create work item in sn_devops_work_item table
       var gr = new GlideRecord('sn_devops_work_item');
       gr.initialize();
       gr.setValue('name', payload.issue.title);
       gr.setValue('url', payload.issue.html_url);
       gr.setValue('native_id', payload.issue.number);
       gr.setValue('type', 'issue');
       gr.setValue('state', payload.issue.state);
       gr.insert();
   }
   ```

2. **Test Webhook**:
   - Trigger event in GitHub (create issue, PR, etc.)
   - Check ServiceNow logs: **System Logs** > **System Log** > **All**
   - Search for: "Webhook"

## Troubleshooting

### Connection Test Fails

**Error**: "Connection refused" or "Authentication failed"

**Fixes**:
1. Verify token has required scopes:
   ```bash
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
   ```
2. Check token hasn't expired
3. Verify connection URL: `https://api.github.com` (no trailing slash)
4. Test from ServiceNow instance IP (check firewall rules)

### Actions Return Empty Results

**Error**: Action succeeds but returns no data

**Fixes**:
1. Check GitHub API rate limits:
   ```bash
   curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/rate_limit
   ```
2. Verify repository/organization name spelling
3. Check token has access to specified repos (private repos need `repo` scope)

### Webhook Events Not Received

**Error**: GitHub shows webhook delivery succeeded, but ServiceNow doesn't process

**Fixes**:
1. Check webhook secret matches in both systems
2. Verify webhook URL is publicly accessible
3. Check ServiceNow webhook logs: **System Web Services** > **Webhooks** > **Execution History**
4. Test webhook manually:
   ```bash
   curl -X POST https://<instance>.service-now.com/api/now/webhook/github \
     -H "Content-Type: application/json" \
     -H "X-GitHub-Event: ping" \
     -d '{"zen": "Design for failure."}'
   ```

### IntegrationHub License Issues

**Error**: "IntegrationHub is not licensed"

**Fixes**:
1. Contact ServiceNow Account Manager to purchase/activate IntegrationHub
2. Check licensing: **System Diagnostics** > **Licensing**
3. Verify roles: **User Administration** > **Users** > Check for `integration_hub_admin`

## Security Best Practices

### 1. Token Management

- ✅ Use GitHub Apps instead of Personal Access Tokens for production
- ✅ Rotate tokens every 90 days (or less)
- ✅ Use separate tokens for dev/test/prod environments
- ✅ Never commit tokens to code repositories
- ✅ Store tokens in ServiceNow Credentials (encrypted)

### 2. Least Privilege

- ✅ Grant minimum required permissions
- ✅ Use repository-scoped tokens when possible
- ✅ Separate read vs write tokens (if applicable)

### 3. Audit Logging

- ✅ Enable audit logging for all Spoke actions
- ✅ Monitor for unusual API usage
- ✅ Track who creates/modifies connections

### 4. Network Security

- ✅ Whitelist ServiceNow instance IPs in GitHub (if using GitHub Enterprise)
- ✅ Use HTTPS for all connections
- ✅ Validate webhook signatures

## Integration Patterns

### Pattern 1: Issue Tracking Sync

**Use Case**: Automatically create ServiceNow incidents when GitHub issues are created

**Flow**:
1. **Trigger**: Webhook from GitHub (issue created)
2. **Action**: Create incident in ServiceNow
3. **Action**: Post comment to GitHub issue with incident number
4. **Sync**: Update both systems on status changes

### Pattern 2: Change Management Integration

**Use Case**: Link GitHub PRs to ServiceNow change requests

**Flow**:
1. **Trigger**: PR created/merged
2. **Action**: Create change request in ServiceNow
3. **Action**: Extract related issues from PR body
4. **Action**: Register issues as work items
5. **Action**: Update change request on PR merge

### Pattern 3: Deployment Automation

**Use Case**: Trigger GitHub Actions workflow from ServiceNow

**Flow**:
1. **Trigger**: Change request approved
2. **Action**: Trigger GitHub Actions workflow via API
3. **Action**: Monitor workflow status
4. **Action**: Update change request with deployment results

## Testing Your Configuration

### Test 1: List Repositories

```javascript
// ServiceNow Script
var r = new sn_ws.RESTMessageV2();
r.setEndpoint('https://api.github.com/user/repos');
r.setHttpMethod('GET');
r.setRequestHeader('Authorization', 'token YOUR_TOKEN');
r.setRequestHeader('Accept', 'application/vnd.github.v3+json');

var response = r.execute();
gs.info('Status: ' + response.getStatusCode());
gs.info('Body: ' + response.getBody());
```

### Test 2: Create Issue

```javascript
// ServiceNow Script
var payload = {
    title: 'Test Issue from ServiceNow',
    body: 'This is a test issue created by ServiceNow integration',
    labels: ['test', 'servicenow']
};

var r = new sn_ws.RESTMessageV2();
r.setEndpoint('https://api.github.com/repos/OWNER/REPO/issues');
r.setHttpMethod('POST');
r.setRequestHeader('Authorization', 'token YOUR_TOKEN');
r.setRequestHeader('Accept', 'application/vnd.github.v3+json');
r.setRequestBody(JSON.stringify(payload));

var response = r.execute();
gs.info('Status: ' + response.getStatusCode());
gs.info('Body: ' + response.getBody());
```

### Test 3: Webhook Processing

```javascript
// ServiceNow Webhook Processing Script
(function process(request, response) {
    try {
        var payload = request.body.dataString;
        var event = request.headers['x-github-event'];

        gs.info('GitHub Event: ' + event);
        gs.info('Payload: ' + payload);

        response.setStatus(200);
        response.getWriter().write('Event processed successfully');
    } catch (e) {
        gs.error('Error processing webhook: ' + e.message);
        response.setStatus(500);
    }
})(request, response);
```

## Next Steps

1. ✅ Install GitHub Spoke plugin
2. ✅ Create GitHub Personal Access Token
3. ✅ Configure Connection in ServiceNow
4. ✅ Test connection with simple action
5. ✅ Create test flow in Flow Designer
6. ✅ Configure webhooks for real-time sync
7. ✅ Build production workflows
8. ✅ Monitor and maintain integration

## Related Documentation

- **ServiceNow Docs**: https://docs.servicenow.com/bundle/xanadu-integrate-applications/page/administer/integrationhub/concept/github-spoke.html
- **GitHub API Docs**: https://docs.github.com/en/rest
- **IntegrationHub Docs**: https://docs.servicenow.com/bundle/xanadu-integrate-applications/page/administer/integrationhub/concept/integrationhub.html

## Support

- **ServiceNow Support Portal**: https://support.servicenow.com
- **GitHub Support**: https://support.github.com
- **Community**: ServiceNow Community forums

---

**Note**: This guide assumes ServiceNow Xanadu release or later. Configuration may vary slightly for older releases.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
