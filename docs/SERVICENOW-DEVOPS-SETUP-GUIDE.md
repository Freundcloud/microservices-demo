# ServiceNow DevOps Integration Setup Guide

> **Status**: ✅ Ready for Implementation
> **Last Updated**: 2025-10-20
> **Version**: 1.0.0
> **Workflow**: `.github/workflows/deploy-with-servicenow-devops.yaml`

## Overview

This guide provides step-by-step instructions to configure ServiceNow DevOps integration for **work item visibility** in the DevOps Change workspace. This integration enables:

- ✅ **Work items visible in DevOps Change workspace** (commits, PRs, artifacts, packages)
- ✅ **DORA metrics tracking** (deployment frequency, lead time, MTTR, change failure rate)
- ✅ **Automatic artifact and package registration**
- ✅ **Full GitHub context linked to ServiceNow changes**
- ✅ **Bi-directional integration** between GitHub Actions and ServiceNow

## Prerequisites

Before starting this setup:

1. **ServiceNow Instance Requirements**:
   - ServiceNow DevOps plugin installed (`com.snc.devops`)
   - Admin or sufficient permissions to:
     - Create OAuth applications
     - Register DevOps tools
     - Configure DevOps settings
   - Access to ServiceNow instance: `https://calitiiltddemo3.service-now.com`

2. **GitHub Repository Requirements**:
   - Admin access to repository settings (for secrets)
   - GitHub Actions enabled
   - Repository: `olafkfreund/microservices-demo`

3. **AWS Requirements**:
   - EKS cluster deployed (`microservices`)
   - AWS credentials configured in GitHub secrets

## Part 1: ServiceNow Configuration

### Step 1: Verify DevOps Plugin Installation

**Check if ServiceNow DevOps plugin is installed**:

1. Navigate to **ServiceNow instance**: `https://calitiiltddemo3.service-now.com`
2. In filter navigator, search for: **Plugins** → **System Definition** → **Plugins**
3. Search for plugin ID: `com.snc.devops`
4. **Verify status**: Active ✅

**If plugin is NOT installed**:
1. Go to **System Definition** → **Plugins**
2. Search for "**ServiceNow DevOps**"
3. Click **Install**
4. Wait for installation to complete (~10-15 minutes)
5. Refresh the page and verify status is **Active**

**Important tables created by DevOps plugin**:
- `sn_devops_tool` - Stores registered DevOps tools (GitHub, Jenkins, etc.)
- `sn_devops_package` - Stores deployment packages
- `sn_devops_artifact` - Stores build artifacts
- `sn_devops_change` - DevOps change requests (links to change_request table)

### Step 2: Register GitHub as DevOps Tool

**Why**: ServiceNow needs to know about GitHub as an orchestration tool to link work items.

**Steps**:

1. **Navigate to DevOps Tools**:
   ```
   ServiceNow → Filter Navigator → "DevOps" → "Tools"
   OR directly: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_tool_list.do
   ```

2. **Check if GitHub tool already exists**:
   - Look for tool named "**GitHubARC**" or "**GitHub**"
   - If found, note the **sys_id** (you'll need this later)
   - **Example sys_id**: `4eaebb06c320f690e1bbf0cb05013135`

3. **If GitHub tool does NOT exist, create it**:
   - Click **New** button
   - Fill in the form:
     - **Name**: `GitHubARC` (or `GitHub`)
     - **Type**: Select "**Orchestration**"
     - **Tool Type**: Select "**GitHub**"
     - **URL**: `https://github.com`
     - **Description**: "GitHub Actions orchestration for Online Boutique"
   - Click **Submit**

4. **Get the tool sys_id**:
   - Click on the tool you just created (or existing tool)
   - **Right-click** on the header bar → **Copy sys_id**
   - **Save this sys_id** - you'll add it to GitHub secrets as `SERVICENOW_TOOL_ID`

**Example**:
```
Tool Name: GitHubARC
Tool Type: Orchestration
sys_id: 4eaebb06c320f690e1bbf0cb05013135
```

### Step 3: Register Online Boutique Application

**Why**: Groups all DevOps activities (coding, building, deploying) under one application.

**Steps**:

1. **Navigate to DevOps Applications**:
   ```
   ServiceNow → Filter Navigator → "DevOps" → "Applications"
   OR: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_application_list.do
   ```

2. **Check if application already exists**:
   - Look for "**Online Boutique**"
   - If found, note the **sys_id**

3. **If application does NOT exist, create it**:
   - Click **New** button
   - Fill in the form:
     - **Name**: `Online Boutique`
     - **Description**: "Cloud-native microservices demo application (12 services)"
     - **Owner**: Your username
   - Click **Submit**

4. **Link GitHub tool to application**:
   - Open the "**Online Boutique**" application record
   - Scroll to **Related Lists** section
   - Find "**Orchestration Tools**" tab
   - Click **New** to add a tool
   - Select: **GitHubARC** (the tool you registered in Step 2)
   - Click **Submit**

5. **Get application sys_id** (optional, for future use):
   - Right-click header bar → **Copy sys_id**
   - Save as `SERVICENOW_APP_SYS_ID` (optional secret)

### Step 4: Create OAuth Token for GitHub Actions

**Why**: GitHub Actions needs a secure token to authenticate with ServiceNow DevOps API.

**Important**: OAuth token is MORE secure than username/password (basic auth).

**Steps**:

1. **Create OAuth Application**:
   ```
   ServiceNow → System OAuth → Application Registry
   OR: https://calitiiltddemo3.service-now.com/oauth_entity_list.do
   ```

2. **Click "New"** → Select "**Create an OAuth API endpoint for external clients**"

3. **Fill in OAuth application details**:
   - **Name**: `GitHub Actions Integration`
   - **Client ID**: (auto-generated, copy this)
   - **Client Secret**: (auto-generated, copy this - you'll only see it once!)
   - **Refresh Token Lifespan**: `3600` (1 hour)
   - **Access Token Lifespan**: `1800` (30 minutes)
   - **Active**: ✅ (checked)

4. **Click "Submit"**

5. **CRITICAL: Save the Client ID and Client Secret immediately!**
   - You'll need these to generate the OAuth token
   - **Client Secret is only shown ONCE** - if you lose it, create a new application

6. **Generate OAuth Token**:

   **Option A: Using curl (recommended)**:
   ```bash
   CLIENT_ID="<your-client-id>"
   CLIENT_SECRET="<your-client-secret>"
   INSTANCE_URL="https://calitiiltddemo3.service-now.com"
   USERNAME="github_integration"  # ServiceNow integration user
   PASSWORD="<password>"

   curl -X POST \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=password" \
     -d "client_id=$CLIENT_ID" \
     -d "client_secret=$CLIENT_SECRET" \
     -d "username=$USERNAME" \
     -d "password=$PASSWORD" \
     "$INSTANCE_URL/oauth_token.do"
   ```

   **Expected response**:
   ```json
   {
     "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
     "refresh_token": "dGhpc2lzYXJlZnJlc2h0b2tlbg...",
     "scope": "useraccount",
     "token_type": "Bearer",
     "expires_in": 1800
   }
   ```

   **Option B: Using Postman**:
   - Method: `POST`
   - URL: `https://calitiiltddemo3.service-now.com/oauth_token.do`
   - Headers: `Content-Type: application/x-www-form-urlencoded`
   - Body (x-www-form-urlencoded):
     - `grant_type`: `password`
     - `client_id`: `<your-client-id>`
     - `client_secret`: `<your-client-secret>`
     - `username`: `github_integration`
     - `password`: `<password>`

7. **Copy the `access_token`** from response - this is your `SN_DEVOPS_INTEGRATION_TOKEN`

**Token Security Best Practices**:
- ✅ Store token in GitHub Secrets (never commit to code)
- ✅ Rotate token every 90 days
- ✅ Use dedicated integration user (not personal account)
- ✅ Monitor token usage via ServiceNow logs
- ❌ Never log token in workflow outputs
- ❌ Never share token via email or chat

### Step 5: Verify ServiceNow DevOps API Access

**Test that your token works**:

```bash
TOKEN="<your-access-token>"
INSTANCE_URL="https://calitiiltddemo3.service-now.com"
TOOL_ID="4eaebb06c320f690e1bbf0cb05013135"  # Your GitHub tool sys_id

# Test API access
curl -X GET \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  "$INSTANCE_URL/api/sn_devops/v1/devops/tool/$TOOL_ID"
```

**Expected response**:
```json
{
  "result": {
    "sys_id": "4eaebb06c320f690e1bbf0cb05013135",
    "name": "GitHubARC",
    "type": "orchestration",
    "tool_type": "github"
  }
}
```

**If you get an error**:
- `401 Unauthorized`: Token is invalid or expired
- `403 Forbidden`: User lacks permissions
- `404 Not Found`: Tool ID is incorrect

## Part 2: GitHub Configuration

### Step 6: Add Secrets to GitHub Repository

**Why**: Securely store ServiceNow credentials for GitHub Actions workflows.

**Steps**:

1. **Navigate to GitHub repository settings**:
   ```
   GitHub → olafkfreund/microservices-demo → Settings → Secrets and variables → Actions
   ```

2. **Click "New repository secret"** for each of the following:

**Required Secrets**:

| Secret Name | Value | Example | Notes |
|------------|-------|---------|-------|
| `SN_DEVOPS_INTEGRATION_TOKEN` | OAuth access token | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` | Generated in Step 4 |
| `SERVICENOW_TOOL_ID` | GitHub tool sys_id | `4eaebb06c320f690e1bbf0cb05013135` | From Step 2 |
| `SERVICENOW_INSTANCE_URL` | ServiceNow URL | `https://calitiiltddemo3.service-now.com` | Your instance |

**Optional Secrets (for fallback REST API)**:

| Secret Name | Value | Example | Notes |
|------------|-------|---------|-------|
| `SERVICENOW_USERNAME` | Integration user | `github_integration` | For REST API fallback |
| `SERVICENOW_PASSWORD` | User password | `oA3KqdUVI8Q_^>` | For REST API fallback |
| `SERVICENOW_APP_SYS_ID` | Application sys_id | `abc123...` | From Step 3 (optional) |

**Existing AWS Secrets** (should already exist):

| Secret Name | Value | Notes |
|------------|-------|-------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | For EKS deployment |
| `AWS_SECRET_ACCESS_KEY` | `...` | For EKS deployment |

3. **Verify all secrets are added**:
   - Go back to **Actions secrets** page
   - You should see at least 5 secrets listed
   - Secrets values are hidden (shown as `***`)

## Part 3: Test the Integration

### Step 7: Run the DevOps Workflow (Dev Environment)

**Test the integration in dev environment first**:

1. **Navigate to GitHub Actions**:
   ```
   GitHub → olafkfreund/microservices-demo → Actions
   ```

2. **Select workflow**: "**Deploy with ServiceNow DevOps (Official Actions)**"

3. **Click "Run workflow"** button

4. **Select environment**: Choose **dev**

5. **Click "Run workflow"** (green button)

6. **Monitor workflow execution**:
   - Wait for "**Create Change Request**" job to complete
   - Check job summary for change request number
   - Look for: "Change Request Created via DevOps Change API"

**Expected Output in Job Summary**:
```
✅ Change Request Created via DevOps Change API
Number: CHG0030001
Sys ID: abc123xyz...
View in ServiceNow: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request.do?sys_id=abc123xyz
DevOps Workspace: https://calitiiltddemo3.service-now.com/now/devops-change/home
```

### Step 8: Verify Work Items in ServiceNow

**Check if work items appear in DevOps Change workspace**:

1. **Navigate to ServiceNow DevOps workspace**:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/home
   ```

2. **Look for your change request**:
   - Filter by: **Application** = "Online Boutique"
   - OR search by: **Change Number** (CHG0030001)

3. **Click on the change request**

4. **Verify work items are visible**:
   - **Artifacts tab**: Should show 11 Docker images (frontend, cartservice, etc.)
   - **Packages tab**: Should show deployment package
   - **Pipeline tab**: Should show GitHub Actions workflow run
   - **Commits tab**: Should show recent commits
   - **Work notes tab**: Should show deployment details

**What You Should See**:

```
Change Request: CHG0030001
Application: Online Boutique
Environment: dev
Status: Closed/Complete (dev auto-closes)

Work Items:
├─ Artifacts (11)
│  ├─ frontend:1.0.123
│  ├─ cartservice:1.0.123
│  ├─ productcatalogservice:1.0.123
│  ├─ currencyservice:1.0.123
│  ├─ paymentservice:1.0.123
│  ├─ shippingservice:1.0.123
│  ├─ emailservice:1.0.123
│  ├─ checkoutservice:1.0.123
│  ├─ recommendationservice:1.0.123
│  ├─ adservice:1.0.123
│  └─ loadgenerator:1.0.123
│
├─ Packages (1)
│  └─ online-boutique-dev-123
│
├─ Pipeline (1)
│  └─ GitHub Actions: Deploy with ServiceNow DevOps
│
└─ Commits (1+)
   └─ SHA: abc123... "feat: Add ServiceNow DevOps integration"
```

### Step 9: Test QA and Prod Deployments

**QA Environment**:
1. Run workflow with **qa** environment
2. **Wait for approval** (QA requires approval)
3. Approve in ServiceNow:
   - Go to change request
   - Click "**Approve**" button
4. Workflow continues and deploys
5. Verify work items in DevOps workspace

**Production Environment**:
1. Run workflow with **prod** environment
2. **Wait for Change Advisory Board approval**
3. Approval required before deployment
4. After approval, deployment proceeds
5. Verify work items in DevOps workspace

## Troubleshooting

### Problem: "Token authentication failed"

**Symptoms**:
- Workflow fails at "Create Change Request" step
- Error: `401 Unauthorized` or `403 Forbidden`

**Solutions**:
1. Verify token is correct in GitHub secrets
2. Check token hasn't expired (tokens expire after 30 minutes)
3. Regenerate token using Step 4
4. Verify integration user has correct permissions

**Test token manually**:
```bash
TOKEN="<your-token>"
curl -H "Authorization: Bearer $TOKEN" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/tool"
```

### Problem: "Tool ID incorrect"

**Symptoms**:
- Error: `404 Not Found` when creating change
- Error message mentions "tool not found"

**Solutions**:
1. Verify `SERVICENOW_TOOL_ID` secret matches GitHub tool sys_id from Step 2
2. Check tool exists in ServiceNow:
   ```
   ServiceNow → DevOps → Tools
   Look for: GitHubARC
   Copy sys_id
   ```
3. Update secret in GitHub

### Problem: "Work items not visible in DevOps workspace"

**Symptoms**:
- Change request created successfully
- But artifacts/packages don't show in DevOps Change workspace

**Possible Causes**:
1. **Not using DevOps workflow**: Make sure you're running `.github/workflows/deploy-with-servicenow-devops.yaml` (NOT the basic workflow)
2. **Missing GitHub context**: Verify workflow passes `context-github: ${{ toJSON(github) }}`
3. **Tool not linked to application**: Check Step 3, ensure GitHub tool is linked to Online Boutique application
4. **DevOps plugin not installed**: Verify Step 1

**Verify correct workflow is running**:
- Check workflow file name in Actions UI
- Should say: "Deploy with ServiceNow DevOps (Official Actions)"
- NOT: "Deploy with ServiceNow (Basic API)"

### Problem: "Change Control API not configured"

**Symptoms**:
- Error: "Change Control API not configured in ServiceNow"

**Solutions**:
1. Verify DevOps plugin is active (Step 1)
2. Check Change Control settings:
   ```
   ServiceNow → System Properties → DevOps
   Find: sn_devops.change.enabled
   Value: true (should be checked)
   ```
3. If false, enable it:
   - Click on property
   - Set to `true`
   - Click **Save**

### Problem: "Deployment succeeds but change not updated"

**Symptoms**:
- Deployment completes successfully
- Change request stays in "Implement" status (not closed)

**Solutions**:
1. Check `autoCloseChange` is set to `true` (for dev) or `false` (for qa/prod)
2. Verify "Update Change Request" job runs successfully
3. Check if job has permission to update change
4. Verify change request number is passed correctly between jobs

**Manual update** (if needed):
```bash
BASIC_AUTH=$(echo -n "github_integration:password" | base64)
CHANGE_SYS_ID="<sys-id>"

curl -X PATCH \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d '{"state": "3", "close_code": "successful", "close_notes": "Deployment completed"}' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/$CHANGE_SYS_ID"
```

## Verification Checklist

Before marking setup as complete, verify:

- [ ] ServiceNow DevOps plugin installed and active
- [ ] GitHub tool registered with correct sys_id
- [ ] Online Boutique application created
- [ ] GitHub tool linked to application
- [ ] OAuth token generated and tested
- [ ] All required secrets added to GitHub
- [ ] Dev workflow runs successfully
- [ ] Change request created with work items
- [ ] Artifacts visible in DevOps workspace (11 Docker images)
- [ ] Packages visible in DevOps workspace
- [ ] Pipeline linked to change request
- [ ] Commits visible in change request
- [ ] QA workflow runs with approval
- [ ] Prod workflow runs with CAB approval

## Next Steps

After successful setup:

1. **Run Demo**:
   - Deploy to dev → Show immediate deployment
   - Deploy to qa → Show approval workflow
   - Deploy to prod → Show CAB approval
   - Show work items in DevOps Change workspace

2. **Configure DORA Metrics**:
   - Navigate to: ServiceNow → DevOps → Metrics
   - Enable DORA metrics tracking
   - Set baseline values
   - Configure reporting dashboards

3. **Set Up Alerts**:
   - Configure Slack/email notifications for change approvals
   - Set up PagerDuty integration for deployment failures
   - Create ServiceNow reports for change metrics

4. **Document for Team**:
   - Share this guide with development team
   - Create quick reference card
   - Schedule training session on workflow usage

## Comparison: DevOps Actions vs Basic API

| Feature | Basic API Workflow | DevOps Actions Workflow |
|---------|-------------------|------------------------|
| **Work Item Visibility** | ❌ No | ✅ Yes |
| **DORA Metrics** | ❌ No | ✅ Yes |
| **Artifact Registration** | ❌ Manual | ✅ Automatic |
| **Package Tracking** | ❌ Manual | ✅ Automatic |
| **Pipeline Integration** | ❌ No | ✅ Yes |
| **Commit Linking** | ⚠️ Manual (work notes) | ✅ Automatic |
| **Authentication** | Basic Auth (username/password) | OAuth Token (more secure) |
| **Setup Complexity** | Simple (5 minutes) | Moderate (30 minutes) |
| **Demo Value** | Low | ⭐⭐⭐⭐⭐ High |
| **Use Case** | Simple integration | **Full DevOps visibility** |

**Recommendation**: Use **DevOps Actions workflow** for demo to showcase full integration capabilities.

## Related Documentation

- **[Complete DevOps Solution](SERVICENOW-DEVOPS-WORK-ITEMS-SOLUTION.md)** - Why work items weren't visible
- **[Work Item Association Guide](GITHUB-SERVICENOW-WORK-ITEM-ASSOCIATION.md)** - Correlation IDs and metadata
- **[Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)** - Complete integration overview
- **[Approval Criteria](GITHUB-SERVICENOW-APPROVAL-CRITERIA.md)** - What approvers need to know
- **[Compliance Gap Analysis](COMPLIANCE-GAP-ANALYSIS.md)** - SOC 2 & ISO 27001 compliance

## Support

**Getting Help**:

1. **Check workflow logs**:
   ```
   GitHub → Actions → Select workflow run → Click on failed job → View logs
   ```

2. **Check ServiceNow logs**:
   ```
   ServiceNow → System Logs → Application Logs
   Filter: sn_devops
   ```

3. **Review this guide**: Most issues covered in Troubleshooting section

4. **ServiceNow community**: https://community.servicenow.com/

**Common Issues Already Solved**:
- ✅ Token authentication → Step 4
- ✅ Tool not found → Step 2
- ✅ Work items not visible → Use DevOps workflow
- ✅ Change not updated → Check autoCloseChange setting

---

**Ready for Demo?** ✅

Once all checklist items are complete, your GitHub-ServiceNow DevOps integration is ready for demo! Work items will be fully visible in the DevOps Change workspace with complete traceability from GitHub commits to ServiceNow changes.

**Questions?** See related documentation above or review troubleshooting section.
