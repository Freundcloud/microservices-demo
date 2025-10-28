# ServiceNow Integration Guide - Complete Setup

> **Purpose**: Configure complete ServiceNow + GitHub DevOps integration for automated change management
> **Time**: 45-60 minutes
> **Prerequisites**: ServiceNow instance (developer or production), GitHub repository configured, AWS infrastructure deployed

## 📋 Table of Contents

1. [Overview](#overview)
2. [ServiceNow Prerequisites](#servicenow-prerequisites)
3. [Install ServiceNow DevOps Plugin](#install-servicenow-devops-plugin)
4. [Configure ServiceNow Tables](#configure-servicenow-tables)
5. [Create Custom Fields](#create-custom-fields)
6. [Configure Orchestration Tool](#configure-orchestration-tool)
7. [Set Up GitHub Spoke (Optional)](#set-up-github-spoke-optional)
8. [Configure GitHub Secrets](#configure-github-secrets)
9. [Test the Integration](#test-the-integration)
10. [Configure Approval Workflows](#configure-approval-workflows)
11. [Troubleshooting](#troubleshooting)

---

## Overview

### What This Integration Does

```
GitHub Actions Workflow
         ↓
   Creates Change Request in ServiceNow
         ↓
   Uploads Test Results (security scans, builds)
         ↓
   Links Work Items (GitHub Issues)
         ↓
   Pauses for ServiceNow Approval
         ↓
   Approval granted in ServiceNow UI
         ↓
   Workflow resumes automatically
         ↓
   Deployment completes
         ↓
   Updates ServiceNow CR with results
```

### Benefits

- ✅ **Zero Manual CRs**: Automated creation from GitHub
- ✅ **Complete Audit Trail**: Every deployment tracked
- ✅ **Risk-Based Approvals**: Dev auto-approved, QA/Prod manual
- ✅ **Test Evidence**: Security scans attached to CRs
- ✅ **Compliance Ready**: SOC 2 Type II, ISO 27001
- ✅ **Work Item Tracking**: GitHub Issues → ServiceNow

---

## ServiceNow Prerequisites

### 1. ServiceNow Instance

You need one of these:

**Option A: Personal Developer Instance (Free)**
- Go to: https://developer.servicenow.com/
- Sign up for free developer account
- Request "Personal Developer Instance"
- Wait 5-10 minutes for instance provisioning
- Instance URL: `https://devXXXXXX.service-now.com`

**Option B: Company ServiceNow Instance**
- Use your company's ServiceNow instance
- Requires admin access or support ticket
- Production instance recommended for real deployment

### 2. ServiceNow Account with Admin Rights

You'll need:
- **Admin role** to install plugins
- **Integration user** for API access
- **Table admin** to create custom fields

### 3. Check ServiceNow Version

**Minimum required**: Orlando (or newer)

Check version:
1. Login to ServiceNow
2. Top right → User menu → About
3. Should see: "Orlando", "Paris", "Quebec", "Rome", "San Diego", "Tokyo", "Utah", "Vancouver", or "Washington"

---

## Install ServiceNow DevOps Plugin

### Step 1: Navigate to Plugin Management

1. Login to ServiceNow instance
2. Click "All" (Application Navigator)
3. Type: "Plugins"
4. Click: "System Applications" → "All Available Applications" → "All"

### Step 2: Search for DevOps Plugin

1. Filter: Type "DevOps"
2. Find: **"DevOps Change"** or **"ServiceNow DevOps"**
3. Click on it

### Step 3: Install Plugin

1. Click "Install" or "Activate"
2. Accept license agreement
3. Click "Activate"

**Installation time**: 5-10 minutes

### Step 4: Verify Installation

After installation:

1. Refresh browser
2. Click "All" → Type "DevOps"
3. Should see new modules:
   - DevOps > Change
   - DevOps > Work Items
   - DevOps > Test Results
   - DevOps > Security Results
   - DevOps > Packages

**Success**: DevOps modules visible!

---

## Configure ServiceNow Tables

### 1. Access Tables

Navigate to: "System Definition" → "Tables"

### 2. Verify Required Tables Exist

Search for these tables (should exist after plugin installation):

- ✅ `change_request` - Change Request table
- ✅ `sn_devops_change` - DevOps Change table
- ✅ `sn_devops_work_item` - Work Items
- ✅ `sn_devops_test_result` - Test Results
- ✅ `sn_devops_security_result` - Security Results
- ✅ `sn_devops_package` - Packages/Artifacts

### 3. Set Permissions (If Needed)

For each table:
1. Open table record
2. Click "Controls" tab
3. Ensure: "Can create", "Can read", "Can write" enabled for integration user
4. Save

---

## Create Custom Fields

These custom fields track GitHub context on Change Requests.

### Why Custom Fields?

Standard ServiceNow CRs don't have fields for:
- Git repository name
- Commit SHA
- Branch name
- GitHub actor (who triggered it)
- Correlation ID (workflow run ID)

We'll add 13 custom fields to capture this.

### Option 1: Automated Script (Recommended)

Use the provided script:

```bash
# From your local machine
chmod +x scripts/create-servicenow-custom-fields.sh
./scripts/create-servicenow-custom-fields.sh
```

This creates all 13 fields automatically!

### Option 2: Manual Creation

If script doesn't work, create fields manually:

#### Navigate to Change Request Table

1. "All" → "System Definition" → "Tables"
2. Search: `change_request`
3. Click on "change_request" record

#### Add Fields

For each field below, click "New" in Related Links → "Columns":

**Field 1: Source**
- Column label: `Source`
- Column name: `u_source`
- Type: String
- Max length: 100
- Description: "Source system (e.g., GitHub Actions)"

**Field 2: Correlation ID**
- Column label: `Correlation ID`
- Column name: `u_correlation_id`
- Type: String
- Max length: 100
- Description: "Unique identifier for tracking (workflow run ID)"

**Field 3: Repository**
- Column label: `Repository`
- Column name: `u_repository`
- Type: String
- Max length: 200
- Description: "Git repository name (e.g., org/repo)"

**Field 4: Branch**
- Column label: `Branch`
- Column name: `u_branch`
- Type: String
- Max length: 100
- Description: "Git branch name"

**Field 5: Commit SHA**
- Column label: `Commit SHA`
- Column name: `u_commit_sha`
- Type: String
- Max length: 50
- Description: "Git commit SHA hash"

**Field 6: Actor**
- Column label: `Actor`
- Column name: `u_actor`
- Type: String
- Max length: 100
- Description: "User who triggered the action"

**Field 7: Environment**
- Column label: `Environment`
- Column name: `u_environment`
- Type: String
- Max length: 20
- Description: "Deployment environment (dev/qa/prod)"

**Field 8: GitHub Run ID**
- Column label: `GitHub Run ID`
- Column name: `u_github_run_id`
- Type: String
- Max length: 50
- Description: "GitHub Actions workflow run ID"

**Field 9: GitHub Run URL**
- Column label: `GitHub Run URL`
- Column name: `u_github_run_url`
- Type: URL
- Max length: 500
- Description: "Link to GitHub Actions workflow run"

**Field 10: GitHub Repo URL**
- Column label: `GitHub Repo URL`
- Column name: `u_github_repo_url`
- Type: URL
- Max length: 500
- Description: "Link to GitHub repository"

**Field 11: GitHub Commit URL**
- Column label: `GitHub Commit URL`
- Column name: `u_github_commit_url`
- Type: URL
- Max length: 500
- Description: "Link to specific commit"

**Field 12: Version**
- Column label: `Version`
- Column name: `u_version`
- Type: String
- Max length: 50
- Description: "Application version being deployed"

**Field 13: Deployment Type**
- Column label: `Deployment Type`
- Column name: `u_deployment_type`
- Type: String
- Max length: 50
- Description: "Type of deployment (full/partial/rollback)"

### Verify Custom Fields

1. Navigate to: "Change" → "Open"
2. Click any Change Request
3. Right-click form header → "Configure" → "Form Layout"
4. Search for fields starting with "u_"
5. Drag them to form if not visible
6. Save layout

---

## Configure Orchestration Tool

ServiceNow tracks external tools (like GitHub Actions) in the `sn_devops_tool` table.

### Step 1: Find or Create Tool Record

#### Option A: Automated (Recommended)

```bash
# From your local machine
chmod +x scripts/find-servicenow-tool-id.sh
./scripts/find-servicenow-tool-id.sh --create
```

This will:
- Search for existing "GitHub Actions" tool
- Create one if it doesn't exist
- Display the Tool ID (sys_id)

**Save the Tool ID** - you'll need it for GitHub secrets!

#### Option B: Manual

1. Navigate to: "DevOps" → "Tools" (or search "sn_devops_tool")
2. Click "New"
3. Fill in:
   - **Name**: GitHub Actions
   - **Tool type**: CI/CD
   - **Description**: GitHub Actions for CI/CD automation
   - **Active**: ✅ Yes
4. Click "Submit"
5. Open the record you just created
6. Copy the "Sys ID" (bottom of form)
   - Example: `f76a57c9c3307a14e1bbf0cb05013135`

**Save this Sys ID** - this is your `SN_ORCHESTRATION_TOOL_ID`!

---

## Set Up GitHub Spoke (Optional)

GitHub Spoke enables bidirectional integration (ServiceNow can call GitHub APIs).

**Note**: This is optional. The basic integration (GitHub → ServiceNow) works without it.

### Step 1: Install GitHub Spoke

1. Navigate to: "All" → "System Applications" → "All Available Applications" → "All"
2. Search: "GitHub Spoke"
3. Click "GitHub" spoke
4. Click "Install" or "Activate"
5. Wait 5-10 minutes

### Step 2: Generate GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Name: "ServiceNow Integration"
4. Scopes needed:
   - ✅ `repo` (all sub-scopes)
   - ✅ `admin:repo_hook`
   - ✅ `read:org`
5. Click "Generate token"
6. **Copy token immediately** - you won't see it again!

### Step 3: Create Connection in ServiceNow

1. Navigate to: "Connections & Credentials" → "Connection & Credential Aliases"
2. Click "New"
3. Fill in:
   - **Name**: GitHub Connection
   - **Type**: HTTP(s)
4. Click "Submit"

5. Open the connection record
6. Under "Connections", click "New"
7. Fill in:
   - **Name**: GitHub API
   - **Credential**: (create new, see below)
   - **Connection URL**: `https://api.github.com`
8. Save

### Step 4: Create Credential

1. In connection form, click "New" under Credential
2. Type: "Basic Auth" or "API Key"
3. Fill in:
   - **Name**: GitHub PAT
   - **Username**: Your GitHub username
   - **Password**: Paste Personal Access Token
4. Save

### Step 5: Test Connection

1. Navigate to: "Flow Designer"
2. Create test flow
3. Add GitHub action: "Get Repository"
4. Configure:
   - Connection: GitHub Connection
   - Owner: Freundcloud
   - Repo: microservices-demo
5. Test → Should return repository details

**Success**: GitHub Spoke working!

---

## Configure GitHub Secrets

Now configure GitHub to authenticate with ServiceNow.

### Step 1: Get ServiceNow Credentials

You need:
- ServiceNow instance URL
- Integration user username
- Integration user password
- Orchestration Tool ID (from previous step)

### Step 2: Add Secrets to GitHub

Navigate to: https://github.com/YOUR-USERNAME/microservices-demo/settings/secrets/actions

Add these secrets:

**SERVICENOW_INSTANCE_URL**:
- Name: `SERVICENOW_INSTANCE_URL`
- Value: `https://your-instance.service-now.com`
- Example: `https://dev123456.service-now.com`

**SERVICENOW_USERNAME**:
- Name: `SERVICENOW_USERNAME`
- Value: ServiceNow integration user
- Example: `admin` (dev instance) or `github.integration` (production)

**SERVICENOW_PASSWORD**:
- Name: `SERVICENOW_PASSWORD`
- Value: User password
- Keep secure!

**SN_ORCHESTRATION_TOOL_ID**:
- Name: `SN_ORCHESTRATION_TOOL_ID`
- Value: Tool Sys ID from earlier step
- Example: `f76a57c9c3307a14e1bbf0cb05013135`

### Step 3: Verify Secrets

Your GitHub secrets should now show:

```
✅ SERVICENOW_INSTANCE_URL      Updated X minutes ago
✅ SERVICENOW_USERNAME           Updated X minutes ago
✅ SERVICENOW_PASSWORD           Updated X minutes ago
✅ SN_ORCHESTRATION_TOOL_ID      Updated X minutes ago
```

---

## Test the Integration

### Step 1: Trigger Test Workflow

```bash
# From your local machine
gh workflow run MASTER-PIPELINE.yaml -f environment=dev
```

### Step 2: Watch GitHub Actions

1. Go to: https://github.com/YOUR-USERNAME/microservices-demo/actions
2. Click latest "🚀 Master CI/CD Pipeline" run
3. Watch jobs:
   - ✅ Code Validation
   - ✅ Security Scanning
   - 🔄 **ServiceNow Change Request / Create Change Request (dev)**
   - ⏸️ Deploy (waiting for approval)

### Step 3: Check ServiceNow

1. Login to ServiceNow
2. Navigate to: "Change" → "Open"
3. Should see NEW change request with:
   - **Source**: GitHub Actions ✅
   - **Repository**: Freundcloud/microservices-demo ✅
   - **Branch**: main ✅
   - **Actor**: your-github-username ✅
   - **Environment**: dev ✅
   - **State**: Implement (auto-approved for dev) ✅

### Step 4: Verify Test Results

1. Open the Change Request
2. Click "Test Results" tab
3. Should see:
   - Security scan results
   - Build status
   - Test execution results

### Step 5: Check Workflow Completion

For dev environment:
- Change Request auto-approved
- Deployment proceeds automatically
- CR updated with deployment results

**Success**: Integration working! 🎉

---

## Configure Approval Workflows

Set up different approval requirements per environment.

### Approval Matrix

| Environment | Auto-Approve | Approvers Required |
|-------------|--------------|-------------------|
| **dev** | ✅ Yes | None (automatic) |
| **qa** | ❌ No | QA Lead |
| **prod** | ❌ No | CAB (Change Manager, App Owner, Security) |

### Step 1: Create Approval Groups

#### QA Approvers Group

1. Navigate to: "User Administration" → "Groups"
2. Click "New"
3. Fill in:
   - **Name**: QA Approvers
   - **Type**: Approval Group
4. Click "Submit"
5. Add members:
   - Open group
   - "Group Members" tab
   - Add QA team members

#### CAB (Change Advisory Board)

1. Navigate to: "User Administration" → "Groups"
2. Click "New"
3. Fill in:
   - **Name**: Change Advisory Board
   - **Type**: Approval Group
4. Add members:
   - Change Manager
   - Application Owner
   - Security Team Lead

### Step 2: Configure Approval Rules

#### For QA Environment

1. Navigate to: "Change" → "Approval Rules"
2. Click "New"
3. Fill in:
   - **Name**: QA Deployment Approval
   - **Table**: Change Request
   - **Conditions**:
     - Environment = qa
     - State = Assess
   - **Approvers**: QA Approvers (group)
   - **Required approvals**: 1
4. Save

#### For Production Environment

1. Create new approval rule
2. Fill in:
   - **Name**: Production CAB Approval
   - **Table**: Change Request
   - **Conditions**:
     - Environment = prod
     - State = Assess
   - **Approvers**: Change Advisory Board (group)
   - **Required approvals**: 3 (all CAB members)
4. Save

### Step 3: Test Approval Workflow

#### Deploy to QA

```bash
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
```

**Expected**:
1. CR created in ServiceNow
2. State = "Assess" (not auto-approved)
3. Workflow PAUSES at deployment gate
4. QA Lead gets notification
5. QA Lead approves in ServiceNow
6. Workflow resumes automatically
7. Deployment proceeds

#### Deploy to Production

```bash
gh workflow run MASTER-PIPELINE.yaml -f environment=prod
```

**Expected**:
1. CR created in ServiceNow
2. State = "Assess"
3. Workflow PAUSES
4. CAB members get notifications
5. All 3 CAB members must approve
6. After all approvals, workflow resumes
7. Deployment to production

---

## Work Item Integration

Link GitHub Issues to ServiceNow Work Items.

### Step 1: Create GitHub Issue

```bash
gh issue create \
  --title "Add payment gateway integration" \
  --body "Integrate Stripe for checkout" \
  --label enhancement
```

### Step 2: Trigger Deployment with Issue Reference

Make commit with issue reference:

```bash
git commit -m "feat: Add payment integration (fixes #123)"
git push origin main
```

### Step 3: Verify in ServiceNow

1. Navigate to: "DevOps" → "Work Items"
2. Should see GitHub Issue #123
3. Open Change Request for this deployment
4. "Work Items" tab should show linked issue

**Result**: Complete traceability from issue to deployment!

---

## Troubleshooting

### Issue: Change Request Not Created

**Symptoms**: Workflow runs but no CR in ServiceNow

**Solutions**:

```bash
# Verify ServiceNow secrets
gh secret list | grep SERVICENOW

# Test ServiceNow API manually
./scripts/test-servicenow-change-api.sh

# Check workflow logs
gh run view --log | grep -i servicenow

# Common causes:
# 1. Wrong credentials
# 2. Tool ID doesn't exist
# 3. ServiceNow plugin not installed
```

### Issue: "Authentication failed" Error

**Error**: `401 Unauthorized`

**Solutions**:

1. Verify credentials:
   ```bash
   # Test login via browser
   open https://YOUR-INSTANCE.service-now.com

   # Try username/password
   ```

2. Check user permissions:
   - User must have `x_snc_devops.admin` role
   - Or `admin` role for dev instances

3. Re-add secrets:
   ```bash
   gh secret set SERVICENOW_USERNAME --body "admin"
   gh secret set SERVICENOW_PASSWORD --body "your-password"
   ```

### Issue: Custom Fields Show "N/A"

**Symptoms**: CR created but custom fields empty

**Cause**: Fields not created or workflow not sending data

**Solutions**:

```bash
# Verify fields exist
# ServiceNow → System Definition → Tables → change_request → Columns
# Look for: u_source, u_repository, u_branch, u_commit_sha, etc.

# Re-run field creation script
./scripts/create-servicenow-custom-fields.sh

# Check workflow is sending data
gh run view --log | grep "u_source"
```

### Issue: Workflow Doesn't Wait for Approval

**Symptoms**: Deploys to QA/Prod without approval

**Cause**: Approval rules not configured or workflow not checking approval

**Solutions**:

1. Verify approval rules exist:
   - "Change" → "Approval Rules"
   - Should see rules for qa and prod environments

2. Check CR state:
   - Should be "Assess" (not "Implement")
   - "Implement" = auto-approved

3. Verify workflow waits:
   - `.github/workflows/servicenow-change-rest.yaml`
   - Should have polling logic for approval

### Issue: Tool ID Not Found

**Error**: `Tool with sys_id 'xxx' not found`

**Solutions**:

```bash
# Find correct tool ID
./scripts/find-servicenow-tool-id.sh

# Or manually
# ServiceNow → DevOps → Tools
# Copy sys_id from URL or form

# Update GitHub secret
gh secret set SN_ORCHESTRATION_TOOL_ID --body "CORRECT-SYS-ID"
```

### Issue: Work Items Not Syncing

**Symptoms**: GitHub Issues not appearing in ServiceNow

**Cause**: GitHub Spoke not configured or workflow not extracting issues

**Solutions**:

1. Verify GitHub Spoke installed
2. Check issue extraction in workflow:
   ```bash
   gh run view --log | grep "work.*item"
   ```
3. Manually link issue to CR:
   - Open CR in ServiceNow
   - "Work Items" tab → "New"
   - Add issue details

---

## Advanced Configuration

### Customize Change Request Template

Edit: `.github/workflows/servicenow-change-rest.yaml`

```yaml
- name: Create Change Request
  run: |
    curl -X POST "$SERVICENOW_INSTANCE_URL/api/now/table/change_request" \
      -H "Content-Type: application/json" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -d '{
        "short_description": "Deployment to ${{ inputs.environment }}",
        "description": "Automated deployment via GitHub Actions",
        "u_source": "GitHub Actions",
        "u_repository": "${{ github.repository }}",
        "u_branch": "${{ github.ref_name }}",
        "u_commit_sha": "${{ github.sha }}",
        "u_actor": "${{ github.actor }}",
        "u_environment": "${{ inputs.environment }}",
        "category": "Software",
        "impact": "3",
        "urgency": "3",
        "priority": "3"
      }'
```

### Add Scheduled Changes

Create scheduled maintenance windows:

```yaml
- name: Schedule Change
  run: |
    SCHEDULED_TIME=$(date -u -d "+2 hours" "+%Y-%m-%d %H:%M:%S")
    curl -X POST "$SERVICENOW_INSTANCE_URL/api/now/table/change_request" \
      -d '{
        "planned_start_date": "'"$SCHEDULED_TIME"'",
        "planned_end_date": "'"$(date -u -d "+4 hours" "+%Y-%m-%d %H:%M:%S")"'"
      }'
```

---

## Next Steps

✅ **ServiceNow Integration Complete!**

Now you can:

1. **Run Full Promotion Demo**:
   ```bash
   just promote 1.0.0 all
   ```
   - Creates CR automatically
   - Waits for approvals
   - Deploys through environments

2. **Present to Stakeholders**:
   - Use [ServiceNow Demo Guide](SERVICENOW-GITHUB-DEMO-GUIDE.md)
   - Show automated change management
   - Highlight compliance benefits

3. **Train Your Team**:
   - Developers: Never need to log into ServiceNow
   - Approvers: Review CRs with complete context
   - Auditors: Complete audit trail available

---

## Reference

### ServiceNow URLs

Direct links to common pages:

```
Change Requests:
https://YOUR-INSTANCE.service-now.com/now/nav/ui/classic/params/target/change_request_list.do

DevOps Work Items:
https://YOUR-INSTANCE.service-now.com/now/nav/ui/classic/params/target/sn_devops_work_item_list.do

DevOps Test Results:
https://YOUR-INSTANCE.service-now.com/now/nav/ui/classic/params/target/sn_devops_test_result_list.do

DevOps Tools:
https://YOUR-INSTANCE.service-now.com/now/nav/ui/classic/params/target/sn_devops_tool_list.do

Change Calendar:
https://YOUR-INSTANCE.service-now.com/now/nav/ui/classic/params/target/change_calendar.do
```

### API Endpoints

```bash
# Create Change Request
POST /api/now/table/change_request

# Get Change Request
GET /api/now/table/change_request/{sys_id}

# Update Change Request
PATCH /api/now/table/change_request/{sys_id}

# Create Test Result
POST /api/now/table/sn_devops_test_result

# Create Work Item
POST /api/now/table/sn_devops_work_item
```

---

**Estimated Time**: 45-60 minutes

**Ready?** Start with [ServiceNow Prerequisites](#servicenow-prerequisites)! 🚀
