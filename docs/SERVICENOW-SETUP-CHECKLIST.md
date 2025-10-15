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
2. Click **New**
3. Fill in details:
   - **User ID**: `github_integration`
   - **First Name**: `GitHub`
   - **Last Name**: `Integration`
   - **Email**: `devops@yourcompany.com` (use your actual email)
   - **Active**: ✅ Checked
   - **Web service access only**: ✅ Checked (for security)
4. Click **Submit**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Record SYS_ID here**: `________________________________`

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

#### Task 1.5: Generate DevOps Integration Token

**Steps:**
1. Navigate to: **DevOps > Configuration > Integration Tokens**
2. Click **Generate New Token**
3. Fill in:
   - **Token Name**: `GitHub Actions Integration`
   - **User**: Select `github_integration`
   - **Expires**: Set to 1 year from now
4. Click **Generate**
5. **IMPORTANT**: Copy the token immediately and store securely
6. You will not be able to see this token again!

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Token Storage:**
```
SN_DEVOPS_INTEGRATION_TOKEN=___________________________________________
```

⚠️ **Security Warning**: Store this token securely. Do not commit to Git. We'll add to GitHub Secrets later.

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

**Alternative - Simple Token Method:**
1. Navigate to: **System Security > Users and Groups > Users**
2. Open `github_integration` user
3. Right-click header, select **Personalize > Form Layout**
4. Add field: **Token** (if available in your ServiceNow version)
5. Or use Basic Auth (less secure): base64(username:password)

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Token Storage:**
```
SN_OAUTH_TOKEN=___________________________________________
```

---

### Day 2: GitHub Integration Configuration (2-3 hours)

#### Task 1.7: Configure GitHub Tool in ServiceNow

**Steps:**
1. Navigate to: **DevOps > Configuration > Tool Configuration**
2. Click **New**
3. Fill in:
   - **Name**: `GitHub Actions`
   - **Type**: Select `GitHub`
   - **URL**: `https://github.com/your-org/microservices-demo`
   - **Tool ID**: Leave blank (will be auto-generated)
4. Authentication section:
   - **Username**: Your GitHub username
   - **Token/Password**: GitHub Personal Access Token
5. Click **Test Connection**
6. Should see: ✅ Connection Successful
7. Click **Submit**
8. **IMPORTANT**: Copy the **Tool ID** from the record

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**Tool Configuration:**
```
SN_ORCHESTRATION_TOOL_ID=___________________________________________
```

**GitHub Personal Access Token Requirements:**
- Permissions needed:
  - ✅ `repo` (Full control of private repositories)
  - ✅ `workflow` (Update GitHub Actions workflows)
  - ✅ `read:org` (Read organization data)

**To create GitHub PAT:**
1. Go to: https://github.com/settings/tokens
2. Click: **Generate new token (classic)**
3. Select scopes above
4. Copy token immediately

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

#### Task 1.9: Create Microservice CI Class

**Steps:**
1. Navigate to: **Configuration > CI Class Manager**
2. Click **New**
3. Create new class:
   - **Name**: `Microservice`
   - **Parent Class**: `cmdb_ci_service` (Service)
   - **Table Name**: `u_microservice`
4. Click **Create**

**Add Attributes:**
5. Add the following fields:

| Field Name | Type | Max Length | Mandatory |
|------------|------|------------|-----------|
| u_service_name | String | 255 | Yes |
| u_namespace | String | 100 | Yes |
| u_environment | String | 50 | Yes |
| u_replicas | Integer | - | No |
| u_ready_replicas | Integer | - | No |
| u_image | String | 512 | No |
| u_image_tag | String | 100 | No |
| u_status | String | 50 | No |
| u_cluster | Reference (u_eks_cluster) | - | No |
| u_language | String | 50 | No |
| u_last_discovered | Date/Time | - | No |
| u_discovered_by | String | 100 | No |

6. Click **Save**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

**CI Class Table Name**: `u_microservice`

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

#### Task 1.11: Configure Security Tool Mappings

**Steps:**
1. Navigate to: **DevOps > Security > Tool Configuration**
2. Add each security tool:

**Tool 1: Trivy**
- Name: `Trivy`
- Type: `Container Scanner`
- Tool ID: `trivy`
- Click **Submit**

**Tool 2: CodeQL**
- Name: `CodeQL`
- Type: `SAST`
- Tool ID: `codeql`
- Click **Submit**

**Tool 3: Checkov**
- Name: `Checkov`
- Type: `IaC Scanner`
- Tool ID: `checkov`
- Click **Submit**

**Tool 4: Gitleaks**
- Name: `Gitleaks`
- Type: `Secret Scanner`
- Tool ID: `gitleaks`
- Click **Submit**

**Tool 5: Semgrep**
- Name: `Semgrep`
- Type: `SAST`
- Tool ID: `semgrep`
- Click **Submit**

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Completed

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
