# ServiceNow Essential Setup Guide

> **Quick Setup**: What you ACTUALLY need to get started
> **Time Required**: 30-60 minutes
> **Prerequisites**: ServiceNow admin access

## What You Actually Need

Good news! You only need **2 things** in ServiceNow to get started:

1. ✅ **DevOps Plugin** - For change management and security results
2. ✅ **Basic CMDB Tables** - To store EKS cluster and microservices data

**You DON'T need**:
- ❌ AWS Service Management Connector (our GitHub Actions handle this)
- ❌ Additional licenses beyond standard ServiceNow + DevOps
- ❌ Complex AWS integrations

## Essential Setup (3 Steps)

### Step 1: Install DevOps Plugin (15 minutes)

**Check if already installed**:
1. In ServiceNow, click **All** (top left)
2. Type: `DevOps`
3. If you see "DevOps > Configuration", it's already installed! Skip to Step 2.

**If not installed**:
1. Navigate to: **System Definition > Plugins**
2. Search: `DevOps`
3. Find: **DevOps (com.snc.devops)**
4. Click **Activate** or **Install**
5. Wait 5-10 minutes
6. Verify: **All > DevOps** should now appear

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

### Step 2: Create Integration User and Token (10 minutes)

**Create User**:
1. Navigate to: **User Administration > Users**
2. Click **New**
3. Fill in:
   - User ID: `github_integration`
   - First Name: `GitHub`
   - Last Name: `Integration`
   - Email: Your email
   - Active: ✅ Checked
   - Web service access only: ✅ Checked
4. Click **Submit**

**Assign Roles**:
1. Find the user you just created
2. Scroll to **Roles** tab
3. Click **Edit**
4. Add these roles:
   - `devops_user`
   - `rest_api_explorer`
5. Click **Save**

**Generate Token**:
1. Navigate to: **DevOps > Configuration > Integration Tokens**
2. If you don't see this menu, the DevOps plugin isn't fully installed yet
3. Click **Generate New Token**
4. Fill in:
   - Token Name: `GitHub Actions Integration`
   - User: `github_integration`
   - Expires: 1 year from now
5. Click **Generate**
6. **IMPORTANT**: Copy the token NOW (you can't see it again!)
7. Save it as: `SN_DEVOPS_INTEGRATION_TOKEN`

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Your Token**:
```
SN_DEVOPS_INTEGRATION_TOKEN=_________________________________
```

---

### Step 3: Configure GitHub Tool (10 minutes)

**Create GitHub Personal Access Token** (if you don't have one):
1. Go to: https://github.com/settings/tokens
2. Click: **Generate new token (classic)**
3. Select scopes:
   - ✅ `repo` (Full control)
   - ✅ `workflow` (Update workflows)
4. Click **Generate token**
5. Copy the token (you can't see it again!)

**Add to ServiceNow**:
1. Navigate to: **DevOps > Configuration > Tool Configuration**
2. Click **New**
3. Fill in:
   - Name: `GitHub Actions`
   - Type: `GitHub`
   - URL: `https://github.com/Freundcloud/microservices-demo`
   - Username: Your GitHub username
   - Token/Password: Paste your GitHub token
4. Click **Test Connection**
5. Should see: ✅ Success
6. Click **Submit**
7. **IMPORTANT**: Copy the **Tool ID** that appears
8. Save it as: `SN_ORCHESTRATION_TOOL_ID`

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Your Tool ID**:
```
SN_ORCHESTRATION_TOOL_ID=_________________________________
```

---

## Optional: CMDB Tables for Discovery (15 minutes)

**Note**: This is only needed if you want the `eks-discovery.yaml` workflow to update ServiceNow CMDB. You can skip this initially and add it later.

### Create EKS Cluster Table

1. Navigate to: **System Definition > Tables**
2. Click **New**
3. Fill in:
   - Label: `EKS Cluster`
   - Name: `u_eks_cluster`
   - Extends table: `cmdb_ci_cluster`
4. Click **Submit**
5. Open the table you just created
6. Click **New** under Columns tab to add fields:

| Column Label | Column Name | Type | Max Length |
|--------------|-------------|------|------------|
| Cluster Name | u_cluster_name | String | 255 |
| ARN | u_arn | String | 512 |
| Version | u_version | String | 20 |
| Endpoint | u_endpoint | URL | 512 |
| Region | u_region | String | 50 |
| VPC ID | u_vpc_id | String | 100 |
| Status | u_status | String | 50 |
| Provider | u_provider | String | 50 |
| Last Discovered | u_last_discovered | Date/Time | - |
| Discovered By | u_discovered_by | String | 100 |

7. Click **Update** after adding all columns

### Create Microservice Table

1. Navigate to: **System Definition > Tables**
2. Click **New**
3. Fill in:
   - Label: `Microservice`
   - Name: `u_microservice`
   - Extends table: `cmdb_ci_service`
4. Click **Submit**
5. Add columns:

| Column Label | Column Name | Type | Max Length |
|--------------|-------------|------|------------|
| Service Name | u_service_name | String | 255 |
| Namespace | u_namespace | String | 100 |
| Environment | u_environment | String | 50 |
| Replicas | u_replicas | Integer | - |
| Ready Replicas | u_ready_replicas | Integer | - |
| Image | u_image | String | 512 |
| Image Tag | u_image_tag | String | 100 |
| Status | u_status | String | 50 |
| Cluster | u_cluster | Reference (u_eks_cluster) | - |
| Language | u_language | String | 50 |
| Last Discovered | u_last_discovered | Date/Time | - |
| Discovered By | u_discovered_by | String | 100 |

6. Click **Update** after adding all columns

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed | ⏭️ Skipped (will add later)

---

## Add Secrets to GitHub

Now that you have the ServiceNow tokens, add them to GitHub:

1. Go to: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions
2. Click **New repository secret**
3. Add these three secrets:

**Secret 1**:
- Name: `SN_DEVOPS_INTEGRATION_TOKEN`
- Value: [Token from Step 2]

**Secret 2**:
- Name: `SN_INSTANCE_URL`
- Value: `https://your-instance.service-now.com` (your actual ServiceNow URL)

**Secret 3**:
- Name: `SN_ORCHESTRATION_TOOL_ID`
- Value: [Tool ID from Step 3]

**Optional Secret 4** (only if you created CMDB tables):
- Name: `SN_OAUTH_TOKEN`
- Value: [OAuth token for CMDB API access]

---

## Test Your Setup

### Test 1: Security Scan (2 minutes)

```bash
# This will test if ServiceNow can receive security results
gh workflow run security-scan-servicenow.yaml
```

**Wait 5 minutes, then check**:
1. GitHub: Actions tab → Should see workflow running
2. ServiceNow: DevOps > Security > Security Results (should populate after scan completes)

**Expected Result**: ✅ Security results appear in ServiceNow

---

### Test 2: Deploy to Dev (5 minutes)

```bash
# This will test change management integration
gh workflow run deploy-with-servicenow.yaml -f environment=dev
```

**What should happen**:
1. GitHub Actions creates a change request in ServiceNow
2. Change is auto-approved (dev environment)
3. Deployment proceeds to EKS
4. Change request is closed

**Check in ServiceNow**:
1. Navigate to: **Change Management > All Changes**
2. You should see a new change request for "Deploy microservices-demo to dev"
3. Status should be "Closed" (successful)

**Expected Result**: ✅ Change request created and closed automatically

---

## What If Something Doesn't Work?

### Issue: "DevOps menu doesn't appear"

**Solution**: DevOps plugin not fully installed
```
1. Go to: System Definition > Plugins
2. Find: DevOps (com.snc.devops)
3. Check status - should be "Active"
4. If installing, wait 10 minutes and refresh
5. If failed, contact ServiceNow admin
```

### Issue: "Can't generate integration token"

**Solution**: DevOps plugin not fully installed or user doesn't have permissions
```
1. Verify DevOps plugin is Active
2. Check user has 'devops_user' role
3. Try logging out and back in
4. If still fails, assign 'admin' role temporarily
```

### Issue: "Test Connection fails for GitHub"

**Solution**: GitHub token invalid or insufficient permissions
```
1. Verify GitHub token hasn't expired
2. Check token has 'repo' and 'workflow' scopes
3. Verify repository URL is correct
4. Try generating a new GitHub token
```

### Issue: "Workflow runs but nothing appears in ServiceNow"

**Solution**: Check secrets and ServiceNow connectivity
```
1. Verify GitHub Secrets are set correctly
2. Check ServiceNow instance URL has no trailing slash
3. Verify integration token hasn't expired
4. Check workflow logs for error messages
```

---

## You're Ready!

Once you've completed the essential steps (Steps 1-3) and added GitHub Secrets, you're ready to use the ServiceNow integration!

**What works now**:
- ✅ Security scan results → ServiceNow
- ✅ Deployments with change management
- ✅ Automatic change requests
- ✅ Environment-specific approvals

**What you can add later**:
- CMDB discovery (optional)
- Additional approval workflows
- Custom security gates
- Integration with other tools

---

## Next Steps

1. **Read the Quick Start**: [SERVICENOW-QUICKSTART.md](SERVICENOW-QUICKSTART.md)
2. **Test dev deployment**: Deploy to dev and watch the change request
3. **Configure QA approval**: Set up QA Lead in ServiceNow
4. **Add CMDB tables**: If you want infrastructure discovery

---

## Summary Checklist

**Essential (Required)**:
- [ ] DevOps plugin installed
- [ ] Integration user created with devops_user role
- [ ] Integration token generated
- [ ] GitHub tool configured in ServiceNow
- [ ] GitHub Secrets added (3 secrets minimum)
- [ ] Tested security scan workflow
- [ ] Tested dev deployment workflow

**Optional (Nice to Have)**:
- [ ] CMDB tables created
- [ ] OAuth token generated for CMDB
- [ ] Discovery workflow tested
- [ ] QA approval workflow configured
- [ ] Prod CAB approval workflow configured

---

**Questions?** Check the [complete setup guide](SERVICENOW-SETUP-CHECKLIST.md) or contact your ServiceNow admin.

**Last Updated**: 2025-10-15
