# ServiceNow Integration Setup Checklist

> **Status**: In Progress
> **Started**: 2025-10-15
> **AWS Account**: 533267307120
> **EKS Cluster**: microservices (eu-west-2) ✅ ACTIVE

## Overview

This checklist will guide you through setting up ServiceNow integration for the microservices-demo project. Complete each section in order.

---

## 📋 Pre-Implementation Checklist

### Required Information to Gather

Before starting, collect the following information:

- [ ] **ServiceNow Instance URL**: `https://__________.service-now.com`
- [ ] **ServiceNow Admin Username**: `__________`
- [ ] **ServiceNow Admin Access**: Confirmed ✅ / Not Yet ❌
- [ ] **DevOps Plugin License**: Available ✅ / Need to Request ❌
- [ ] **AWS Service Management License**: Available ✅ / Need to Request ❌

**Action**: Fill in the information above before proceeding.

---

## Week 1: ServiceNow Foundation Setup

### Day 1: Plugin Installation (2-3 hours)

#### Task 1.1: Install ServiceNow DevOps Plugin

**Steps:**
1. Log into your ServiceNow instance as admin
2. Navigate to: **System Definition > Plugins**
3. In the search box, type: `DevOps`
4. Find plugin: **DevOps (com.snc.devops)**
5. Click **Install** or **Activate**
6. Wait for installation to complete (5-10 minutes)
7. Verify installation:
   - Navigate to: **All > DevOps**
   - You should see DevOps menu items

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Installation Details:**
- Plugin Name: `com.snc.devops`
- Installation Time: ~5-10 minutes
- Requires: Admin privileges

**Verification Command:**
```javascript
// In ServiceNow Background Scripts (System Definition > Scripts - Background)
var plugin = new GlideRecord('sys_plugins');
plugin.addQuery('name', 'com.snc.devops');
plugin.query();
if (plugin.next()) {
    gs.info('DevOps plugin status: ' + plugin.state);
    gs.info('Version: ' + plugin.version);
} else {
    gs.info('DevOps plugin not found');
}
```

**Expected Output:**
```
DevOps plugin status: active
Version: [version number]
```

---

#### Task 1.2: Install AWS Service Management Connector (OPTIONAL)

**⚠️ NOTE**: This is **OPTIONAL** for the GitHub Actions integration. The AWS Service Management Connector is only needed if you want ServiceNow to directly discover AWS resources. Our GitHub Actions workflows handle discovery automatically.

**You can skip this step if**:
- You don't have access to this plugin
- You prefer GitHub Actions to handle discovery (recommended)
- You don't need native AWS integration in ServiceNow

**If you want to install it** (Optional):
1. Navigate to: **System Applications > All Available Applications > All**
2. Search for: `AWS Service Management` or `AWS Service Management Connector`
3. If found: Click **Install**
4. If not found: This plugin requires a separate license or may not be available in your ServiceNow instance

**Alternative (Recommended)**: Use the GitHub Actions `eks-discovery.yaml` workflow we created, which:
- Doesn't require any additional ServiceNow plugins
- Runs automatically every 6 hours
- Updates CMDB via ServiceNow REST API
- Works with standard ServiceNow licenses

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed | ⏭️ Skipped (Using GitHub Actions)

**Installation Details:**
- Plugin Name: `com.snc.aws_service_management_connector`
- Installation Time: ~10-15 minutes
- Requires: Admin privileges + Additional license may be required

---

### Day 1-2: Service Account Setup (1-2 hours)

#### Task 1.3: Create Integration User

**Steps:**

1. Navigate to: **User Administration > Users**
   - Or: **All > User Administration > Users**

2. Click **New**

3. Fill in the **User Details**:
   - **User ID**: `github_integration`
   - **First Name**: `GitHub`
   - **Last Name**: `Integration`
   - **Email**: `devops@yourcompany.com` (use your actual email)
   - **Active**: ✅ Checked
   - **Web service access only**: ✅ Checked (for security)

4. **Set Password** (IMPORTANT):

   📖 **Need detailed help?** See: [SERVICENOW-PASSWORD-MANAGEMENT.md](SERVICENOW-PASSWORD-MANAGEMENT.md)

   **Method 1: Set password during creation (Recommended)**
   - Scroll to the **Password** section on the form
   - Click **Set Password** button
   - Enter a strong password (see requirements below)
   - Confirm the password
   - **IMPORTANT**: Save this password securely!

   **Method 2: Set password after creation**
   - Click **Submit** to create the user first
   - Find the user: **User Administration > Users** > Search `github_integration`
   - Open the user record
   - Right-click the header bar
   - Select **Set Password**
   - Enter a strong password
   - Confirm the password

5. Click **Submit**

**Password Requirements:**

ServiceNow typically requires:
- Minimum 8-12 characters (check your instance policy)
- Mix of uppercase and lowercase letters
- At least one number
- At least one special character (!, @, #, $, %, etc.)

**Example Strong Password:**
```
GitHubInt3gr@ti0n2024!
```

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Record These Values Securely:**
```
Username: github_integration
Password: ________________________________
SYS_ID: ________________________________
```

⚠️ **Security Notes:**
- Store password in a secure password manager
- Do NOT commit password to Git
- This password will be used as `SERVICENOW_PASSWORD` in GitHub Secrets (Task 1.5)
- Rotate password every 90 days

---

#### Task 1.4: Assign Roles to Integration User

**Steps:**
1. Navigate to: **User Administration > Users**
2. Search for: `github_integration`
3. Open the user record
4. Scroll to **Roles** tab
5. Click **Edit**
6. Add the following roles:
   - ✅ `devops_user` - DevOps operations
   - ✅ `api_analytics_read` - API access
   - ✅ `rest_api_explorer` - REST API access
   - ✅ `web_service_admin` - Web service administration (if needed)
7. Click **Save**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

#### Task 1.5: Configure GitHub Tool and Authentication

⚠️ **IMPORTANT**: The menu path "DevOps > Configuration > Integration Tokens" does NOT exist in ServiceNow. The `SN_DEVOPS_INTEGRATION_TOKEN` is actually obtained from the GitHub Tool configuration in ServiceNow DevOps.

**What is the DevOps Integration Token?**

The DevOps Integration Token is automatically generated when you create a GitHub tool in ServiceNow DevOps. This token is embedded in the GitHub tool record and is used to authenticate GitHub Actions workflows with your ServiceNow instance.

**Steps to Configure GitHub Tool:**

1. Navigate to: **DevOps > Orchestration > GitHub**
   - Alternative path: **All > DevOps > Configuration > Tool Connections**

2. Click **New** to create a new GitHub tool connection

3. Fill in the GitHub Tool configuration:
   - **Name**: `GitHub Actions Integration`
   - **Type**: GitHub
   - **URL**: `https://github.com/your-org/microservices-demo`
   - **Branch**: `main` (or your default branch)

4. Authentication section:
   - **Credential Type**: Select `Basic Auth` or `Token`
   - **GitHub Token**: Enter your GitHub Personal Access Token (PAT)
     - Create PAT at: https://github.com/settings/tokens
     - Required scopes: `repo`, `workflow`, `read:org`

5. Click **Submit**

6. **Copy the sys_id from the URL or record:**

   📖 **Need help?** See detailed guide: [SERVICENOW-SYSID-EXTRACTION-GUIDE.md](SERVICENOW-SYSID-EXTRACTION-GUIDE.md)

   **Modern ServiceNow (Vancouver/Utah+):**
   - The URL will look like: `https://your-instance.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135`
   - The sys_id is the **last part** of the URL: `4eaebb06c320f690e1bbf0cb05013135`

   **Example with your URL:**
   ```
   URL: https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135

   Your sys_id is: 4eaebb06c320f690e1bbf0cb05013135
   ```

   **Older ServiceNow (Rome/Tokyo):**
   - The URL will look like: `.../sn_devops_tool.do?sys_id=XXXXXXXXXX`
   - The sys_id is in the query parameter

   **Alternative Method (Works in all versions):**
   - Right-click the form header
   - Select **Copy sys_id** (if available)
   - Or select **Copy URL** and extract the sys_id from it

   ✅ **This sys_id is your `SN_ORCHESTRATION_TOOL_ID`**

   **Verify your sys_id:**
   - Length: Exactly 32 characters
   - Format: Lowercase letters (a-f) and numbers (0-9) only
   - Example: `4eaebb06c320f690e1bbf0cb05013135` ✅

7. **Important Note about the Integration Token:**
   - The `SN_DEVOPS_INTEGRATION_TOKEN` is used by ServiceNow's GitHub Actions
   - In many cases, you can use **Basic Authentication** instead (username:password)
   - The token-based authentication is version-dependent (requires ServiceNow DevOps v4.0.0+)

**Authentication Options for GitHub Actions:**

**Option A: Basic Authentication (Simpler, more widely supported)**
```yaml
# In GitHub Actions workflows
- uses: ServiceNow/servicenow-devops-change@v2
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    tool-id: ${{ secrets.SERVICENOW_ORCHESTRATION_TOOL_ID }}
```

**Option B: Token-Based Authentication (If supported by your ServiceNow version)**
```yaml
# In GitHub Actions workflows
- uses: ServiceNow/servicenow-devops-change@v4
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-token: ${{ secrets.SERVICENOW_DEVOPS_TOKEN }}
    tool-id: ${{ secrets.SERVICENOW_ORCHESTRATION_TOOL_ID }}
```

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Record These Values:**
```
# GitHub Tool Configuration
SN_ORCHESTRATION_TOOL_ID (sys_id)=________________________________

# Choose ONE authentication method:

# Method A: Basic Auth (username from Task 1.3)
SERVICENOW_USERNAME=github_integration
SERVICENOW_PASSWORD=________________________________

# Method B: Token-based (if supported)
SERVICENOW_DEVOPS_TOKEN=________________________________
```

**Verification Steps:**

1. Test the GitHub tool connection in ServiceNow
2. Verify the tool appears in: **DevOps > Orchestration > GitHub**
3. Confirm the sys_id is captured correctly

⚠️ **Security Warning**: Store these credentials securely. Do not commit to Git. We'll add to GitHub Secrets in Week 2.

---

#### Task 1.6: Generate OAuth Token for CMDB API

**Steps:**
1. Navigate to: **System OAuth > Application Registry**
2. Click **New**
3. Select: **Create an OAuth API endpoint for external clients**
4. Fill in:
   - **Name**: `GitHub CMDB Integration`
   - **Client ID**: (auto-generated, copy this)
   - **Client Secret**: (auto-generated, copy this)
   - **Redirect URL**: `https://oauth.pstmn.io/v1/callback` (for testing)
5. Click **Submit**
6. Generate access token using client credentials

**Alternative Authentication Methods:**

**Option 1: Basic Authentication (Simpler, but less secure)**

Basic Authentication sends your username and password with every API request. While simpler to set up than OAuth, it's less secure because credentials are transmitted with each call (even though base64-encoded, not encrypted).

**When to use:**
- Quick testing or proof-of-concept
- Small teams with limited ServiceNow configuration access
- When OAuth setup is blocked by organizational policies

**Setup Steps:**

1. **Create the credentials string:**
   - Format: `username:password`
   - Example: `github_integration:MySecurePassword123!`

2. **Encode to Base64:**
   ```bash
   # On Linux/Mac terminal
   echo -n "github_integration:MySecurePassword123!" | base64

   # Output example:
   # Z2l0aHViX2ludGVncmF0aW9uOk15U2VjdXJlUGFzc3dvcmQxMjMh
   ```

   **Important:** The `-n` flag prevents adding a newline character, which would break authentication.

3. **Add to GitHub Secrets:**
   - Go to: `https://github.com/your-org/microservices-demo/settings/secrets/actions`
   - Click **New repository secret**
   - Name: `SERVICENOW_BASIC_AUTH`
   - Value: Paste the base64 string (e.g., `Z2l0aHViX2ludGVncmF0aW9uOk15U2VjdXJlUGFzc3dvcmQxMjMh`)
   - Click **Add secret**

4. **Use in GitHub Actions workflows:**
   ```yaml
   - name: Call ServiceNow API
     run: |
       curl -X POST \
         -H "Authorization: Basic ${{ secrets.SERVICENOW_BASIC_AUTH }}" \
         -H "Content-Type: application/json" \
         -d '{"field": "value"}' \
         https://calitiiltddemo3.service-now.com/api/now/table/change_request
   ```

5. **Use in ServiceNow DevOps actions:**
   ```yaml
   - name: ServiceNow DevOps Change
     uses: ServiceNow/servicenow-devops-change@v2
     with:
       instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
       username: github_integration
       password: ${{ secrets.SERVICENOW_PASSWORD }}  # Store password separately, not base64
   ```

**Security Considerations:**

⚠️ **Limitations:**
- Credentials are sent with every API request
- Base64 is encoding, NOT encryption (easily decoded)
- If credentials are compromised, attacker has full user access
- No expiration - credentials valid until manually changed
- Harder to audit which application made which API call

✅ **Best Practices if using Basic Auth:**
- Use a dedicated service account (`github_integration`) with minimal required permissions
- Set "Web service access only" = Yes (prevents UI login)
- Rotate password regularly (every 90 days)
- Monitor API access logs in ServiceNow
- Consider IP allowlisting in ServiceNow for GitHub Actions IPs
- Never commit credentials to Git (always use GitHub Secrets)

**Option 2: User Token (If supported by your ServiceNow instance)**
1. Navigate to: **System Security > Users and Groups > Users**
2. Open `github_integration` user
3. Check if your instance supports REST API token generation
4. Some ServiceNow versions have built-in token generation under user profile
5. Consult your ServiceNow documentation for version-specific token features

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Token Storage:**
```
SN_OAUTH_TOKEN=___________________________________________
```

---

### Day 2: Verify GitHub Integration (30 minutes)

#### Task 1.7: Verify GitHub Tool Configuration

⚠️ **NOTE**: GitHub tool configuration was completed in Task 1.5. This task is for verification only.

**Verification Steps:**

1. Navigate to: **DevOps > Orchestration > GitHub**
   - Or: **All > DevOps > Configuration > Tool Connections**

2. Verify the GitHub tool exists:
   - ✅ Name: `GitHub Actions Integration`
   - ✅ Type: GitHub
   - ✅ URL: Points to your repository
   - ✅ Status: Active

3. Test the connection:
   - Click on the GitHub tool record
   - Look for **Test Connection** button (if available)
   - Verify: ✅ Connection Successful

4. Confirm the sys_id is captured:
   - Open the GitHub tool record
   - **Modern URL format**: `https://your-instance.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135`
     - sys_id is the last part: `4eaebb06c320f690e1bbf0cb05013135`
   - **Older URL format**: `.../sn_devops_tool.do?sys_id=XXXXXXXXXX`
   - **Or**: Right-click header > **Copy sys_id**
   - Verify this matches what you recorded in Task 1.5

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Checklist:**
- [ ] GitHub tool exists in ServiceNow
- [ ] Connection test passes
- [ ] sys_id (ORCHESTRATION_TOOL_ID) is recorded
- [ ] GitHub PAT is stored securely
- [ ] Authentication method chosen (Basic Auth or Token)

**Troubleshooting:**

If connection test fails:
- Verify GitHub PAT has correct scopes: `repo`, `workflow`, `read:org`
- Check if PAT has expired
- Ensure repository URL is correct
- Verify network connectivity from ServiceNow to GitHub

If GitHub tool doesn't exist:
- Return to Task 1.5 and complete the GitHub tool creation

---

### Day 2-3: CMDB Configuration (3-4 hours)

#### Task 1.8: Create EKS Cluster CI Class

**Steps:**
1. Navigate to: **Configuration > CI Class Manager**
2. Click **New** or search for existing classes
3. Create new class:
   - **Name**: `AWS EKS Cluster`
   - **Parent Class**: `cmdb_ci_cluster` (Cluster)
   - **Table Name**: `u_eks_cluster` (auto-generated)
4. Click **Create**

**Add Attributes:**
5. In the CI Class, click **Attributes** tab
6. Add the following fields:

| Field Name | Type | Max Length | Mandatory |
|------------|------|------------|-----------|
| u_cluster_name | String | 255 | Yes |
| u_arn | String | 512 | No |
| u_version | String | 20 | No |
| u_endpoint | URL | 512 | No |
| u_region | String | 50 | Yes |
| u_vpc_id | String | 100 | No |
| u_status | String | 50 | No |
| u_provider | String | 50 | No |
| u_last_discovered | Date/Time | - | No |
| u_discovered_by | String | 100 | No |

7. Click **Save**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**CI Class Table Name**: `u_eks_cluster`

---

#### Task 1.9: Create Microservice CI Class ✅ COMPLETED

**Steps:**
1. Navigate to: **System Definition > Tables** (`sys_db_object.list`)
2. Click **New**
3. Create new table:
   - **Label**: `Microservice`
   - **Name**: `u_microservice`
   - **Extends table**: `Configuration Item [cmdb_ci]`
   - **Application**: `Global`
   - **Create access controls**: ✅ Yes
   - **Add module to menu**: ✅ Yes
   - **Extensible**: ✅ Yes
4. Click **Submit**

**Add Attributes:**
5. Add the following fields via "Insert a new row..." in Table Columns section:

| Field Name | Type | Max Length | Mandatory | Display | Status |
|------------|------|------------|-----------|---------|--------|
| u_name | String | 100 | Yes | Yes | ✅ Created |
| u_namespace | String | 100 | Yes | Yes | ✅ Created |
| u_cluster_name | String | 100 | No | Yes | ✅ Created |
| u_image | String | 500 | No | Yes | ✅ Created |
| u_replicas | Integer | 40 | No | Yes | ✅ Created |
| u_ready_replicas | Integer | 40 | No | Yes | ✅ Created |
| u_status | String | 50 | No | Yes | ✅ Created |
| u_language | String | 50 | No | Yes | ✅ Created |

6. Click **Submit** for each field

**Status**: ✅ **Completed** (2025-10-16)

**CI Class Table Name**: `u_microservice`

**Verification Results**:
- ✅ Table accessible via API (HTTP 200)
- ✅ All 8 custom fields created
- ✅ Full CRUD operations tested (CREATE, READ, UPDATE, DELETE)
- ✅ github_integration user has admin role and full access
- ✅ Ready for GitHub Actions workflows

**ServiceNow URL**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_microservice_list.do

---

#### Task 1.10: Create Relationship Types

**Steps:**
1. Navigate to: **Configuration > Related Lists > Relationship Types**
2. Click **New**
3. Create relationship:
   - **Name**: `Runs on`
   - **Applies to**: `u_microservice`
   - **From**: `u_microservice`
   - **To**: `u_eks_cluster`
4. Click **Submit**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

### Day 3: Security Tool Configuration (2-3 hours)

#### Task 1.11: Verify Security Integration via GitHub Actions

**⚠️ IMPORTANT**: ServiceNow DevOps integrates with security tools via **API calls from GitHub Actions**, not through a UI menu. Security tools are automatically registered when scan results are sent via the ServiceNow DevOps Security Result action.

**Understanding the Integration:**

ServiceNow DevOps receives security scan results programmatically through GitHub Actions workflows using the `ServiceNow/servicenow-devops-security-result@v2` action. Each security tool is identified by its `tool-id` parameter in the workflow.

**Security Tools Integrated via GitHub Actions:**

Our repository already has the following security tools configured in `.github/workflows/`:

1. **Trivy** (Container Scanner)
   - Workflow: `security-scan.yaml`
   - Tool ID: `trivy`
   - Scans: Container images for vulnerabilities

2. **CodeQL** (SAST)
   - Workflow: `security-scan.yaml`
   - Tool ID: `codeql`
   - Scans: Source code for security issues (5 languages)

3. **Checkov** (IaC Scanner)
   - Workflow: `terraform-validate.yaml`
   - Tool ID: `checkov`
   - Scans: Terraform infrastructure code

4. **Gitleaks** (Secret Scanner)
   - Workflow: `security-scan.yaml`
   - Tool ID: `gitleaks`
   - Scans: Git history for exposed secrets

5. **Semgrep** (SAST)
   - Workflow: `security-scan.yaml`
   - Tool ID: `semgrep`
   - Scans: Source code with semantic rules

**Verification Steps:**

1. **Check that GitHub workflows are configured correctly:**
   ```bash
   # Verify security scan workflow exists
   cat .github/workflows/security-scan.yaml | grep -A 5 "servicenow-devops-security-result"
   ```

2. **Verify ServiceNow secrets are configured in GitHub:**
   - Go to: https://github.com/your-org/microservices-demo/settings/secrets/actions
   - Confirm these secrets exist:
     - ✅ `SERVICENOW_INSTANCE_URL`
     - ✅ `SERVICENOW_DEVOPS_TOKEN`
     - ✅ `SERVICENOW_ORCHESTRATION_TOOL_ID`

3. **Trigger a test security scan:**
   ```bash
   # Manually trigger security scan workflow
   gh workflow run security-scan.yaml
   ```

4. **Verify results appear in ServiceNow:**
   - Navigate to: **DevOps > Security > Security Results**
   - Look for scan results from each tool
   - Verify tool names appear correctly (Trivy, CodeQL, Checkov, Gitleaks, Semgrep)

**What Happens Automatically:**

When GitHub Actions runs a security scan, it:
1. Executes the security tool (e.g., Trivy, CodeQL)
2. Formats the results into ServiceNow-compatible JSON
3. Sends results to ServiceNow via REST API using `servicenow-devops-security-result` action
4. ServiceNow automatically registers the tool if it's the first time seeing that `tool-id`
5. ServiceNow creates security records and associates them with the change request

**Reference Documentation:**
- ServiceNow DevOps Security Result Action: https://github.com/ServiceNow/servicenow-devops-security-result
- Official Documentation: https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/security-tool-framework.html

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Notes:**
```
Tool registration date: __________
First successful scan: __________
```

---

#### Task 1.12: Configure Security Severity Mapping

**Steps:**
1. Navigate to: **DevOps > Security > Severity Mapping**
2. Configure mappings:

| Scanner Severity | ServiceNow Severity | Action |
|------------------|---------------------|--------|
| CRITICAL | Critical | Block Deployment |
| HIGH | High | Require Approval |
| MEDIUM | Medium | Warning Only |
| LOW | Low | Informational |

3. Click **Save**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

### Day 3-4: Approval Workflows (3-4 hours)

#### Task 1.13: Create Dev Auto-Approval Workflow

**Steps:**
1. Navigate to: **Workflow > Workflow Editor**
2. Click **New Workflow**
3. Name: `Dev Environment Auto-Approval`
4. Create workflow:

```
[Start] → [Check Environment] → {Is Dev?}
   ↓ Yes
[Auto-Approve] → [Notify Team] → [End]
   ↓ No
[Go to Manual Approval] → [End]
```

**Workflow Configuration:**
- Trigger: Change Request Created
- Condition: `environment = 'dev'` AND `security_scans = 'passed'`
- Action: Set state to 'Approved'
- Notification: Send email to DevOps team

5. Click **Publish**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

#### Task 1.14: Create QA Manual Approval Workflow

**Steps:**
1. Navigate to: **Workflow > Workflow Editor**
2. Click **New Workflow**
3. Name: `QA Environment Manual Approval`
4. Create workflow:

```
[Start] → [Check Environment] → {Is QA?}
   ↓ Yes
[Request QA Lead Approval] → {Approved?}
   ↓ Yes                         ↓ No
[Proceed] → [End]          [Block] → [Notify] → [End]
```

**Workflow Configuration:**
- Trigger: Change Request Created
- Condition: `environment = 'qa'`
- Approver: QA Lead (configure assignment group)
- Timeout: 4 hours

5. Click **Publish**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**QA Lead Assignment Group**: `________________________________`

---

#### Task 1.15: Create Prod CAB Approval Workflow

**Steps:**
1. Navigate to: **Workflow > Workflow Editor**
2. Click **New Workflow**
3. Name: `Production CAB Approval`
4. Create workflow:

```
[Start] → [Check Environment] → {Is Prod?}
   ↓ Yes
[Request CAB Approval]
   ├─→ [Change Manager] → {Approved?}
   ├─→ [App Owner] → {Approved?}
   └─→ [Security Team] → {Approved?}
        ↓ All Yes              ↓ Any No
[Proceed] → [End]          [Block] → [Notify] → [End]
```

**Workflow Configuration:**
- Trigger: Change Request Created
- Condition: `environment = 'prod'`
- Approvers:
  - Change Manager (parallel approval)
  - Application Owner (parallel approval)
  - Security Team (parallel approval)
- All must approve to proceed
- Timeout: 24 hours

5. Click **Publish**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Approval Groups:**
- Change Manager: `________________________________`
- App Owner: `________________________________`
- Security Team: `________________________________`

---

### Day 4-5: Change Management Templates (2-3 hours)

#### Task 1.16: Create Change Request Templates

**Steps:**
1. Navigate to: **Change > Templates**
2. Create three templates:

**Template 1: Dev Deployment**
- Name: `Automated Dev Deployment`
- Type: `Standard`
- Risk: `Low`
- Auto-approve: `Yes`
- Assignment Group: `DevOps Team`

**Template 2: QA Deployment**
- Name: `QA Environment Deployment`
- Type: `Standard`
- Risk: `Medium`
- Auto-approve: `No`
- Assignment Group: `QA Team`

**Template 3: Prod Deployment**
- Name: `Production Deployment`
- Type: `Standard`
- Risk: `High`
- Auto-approve: `No`
- Assignment Group: `Change Advisory Board`

3. Save all templates

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

---

## Week 1 Completion Checklist

### Verification Steps

Before proceeding to Week 2, verify:

- [ ] DevOps plugin installed and active
- [ ] AWS Service Management Connector installed
- [ ] Integration user created with proper roles
- [ ] DevOps integration token generated and stored securely
- [ ] OAuth token generated for CMDB access
- [ ] GitHub tool configured and connection tested
- [ ] EKS Cluster CI class created (`u_eks_cluster`)
- [ ] Microservice CI class created (`u_microservice`)
- [ ] Relationship types defined
- [ ] All 5 security tools configured
- [ ] Severity mappings defined
- [ ] Dev auto-approval workflow created
- [ ] QA manual approval workflow created
- [ ] Prod CAB approval workflow created
- [ ] Change request templates created

### Export Configuration Details

**Save this information for Week 2:**

```bash
# ServiceNow Configuration
SN_INSTANCE_URL=https://__________.service-now.com
SN_DEVOPS_INTEGRATION_TOKEN=______________________________
SN_ORCHESTRATION_TOOL_ID=______________________________
SN_OAUTH_TOKEN=______________________________

# CMDB Table Names
CMDB_EKS_CLUSTER_TABLE=u_eks_cluster
CMDB_MICROSERVICE_TABLE=u_microservice

# Assignment Groups
QA_LEAD_GROUP=______________________________
CAB_GROUP=______________________________
```

---

## Next Steps

Once Week 1 is complete:

1. **Week 2**: GitHub Actions Integration
   - Add secrets to GitHub repository
   - Create security scan workflow
   - Create deployment workflow
   - Test integrations

2. **Week 3**: Discovery and Production
   - Create EKS discovery workflow
   - Test CMDB population
   - Configure production workflows

3. **Week 4**: Testing and Launch
   - End-to-end testing
   - Team training
   - Production rollout

---

## Support and Resources

### ServiceNow Documentation
- DevOps Plugin: [ServiceNow DevOps Docs](https://docs.servicenow.com/devops)
- CMDB Configuration: [CMDB Documentation](https://docs.servicenow.com/cmdb)
- Workflow Editor: [Workflow Guide](https://docs.servicenow.com/workflow)

### Internal Support
- ServiceNow Admin: `______________________________`
- DevOps Team: `______________________________`
- Security Team: `______________________________`

### Questions or Issues?
Document any issues encountered:

**Issue Log:**
```
Date: _________
Issue: _________
Resolution: _________
```

---

**Last Updated**: 2025-10-15
**Maintained By**: DevOps Team
