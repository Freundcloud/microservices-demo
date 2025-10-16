# ServiceNow Integration - Quick Start Guide

> Fast-track setup guide for ServiceNow Zurich v6.1.0 integration
> Last Updated: 2025-10-16

## Prerequisites

- ServiceNow Zurich v6.1.0 instance
- Admin access to ServiceNow
- GitHub repository admin access
- AWS EKS cluster (optional, for CMDB features)

## 5-Minute Setup

### Step 1: Create ServiceNow User (2 minutes)

```
1. ServiceNow → Filter Navigator: sys_user.list
2. Click: New
3. Fill in:
   - User ID: github_integration
   - First name: GitHub
   - Last name: Integration
   - Email: (your email)
   - Active: ✓
   - Web service access only: ✓
4. Set Password: Click "Set Password" → Enter strong password → Save
5. Save user
```

### Step 2: Assign Roles (1 minute)

```
1. Open github_integration user
2. Roles tab → Edit
3. Add these roles:
   - rest_service
   - api_analytics_read
   - devops_user
4. Save
```

### Step 3: Create GitHub Tool (1 minute)

```
1. Filter Navigator: sn_devops_tool.list
2. Click: New
3. Fill in:
   - Name: GitHub microservices-demo
   - Type: GitHub
   - URL: https://github.com/your-org/microservices-demo
4. Save
5. Copy sys_id from URL (last part after /sn_devops_tool/)
```

### Step 4: Add GitHub Secrets (1 minute)

```bash
gh secret set SERVICENOW_INSTANCE_URL --body "https://your-instance.service-now.com"
gh secret set SERVICENOW_USERNAME --body "github_integration"
gh secret set SERVICENOW_PASSWORD --body "your-password"
gh secret set SERVICENOW_ORCHESTRATION_TOOL_ID --body "your-sys-id"
```

### Step 5: Create u_microservice Table (10 minutes) ✅ COMPLETED

**Required for CMDB features** - This table stores microservice deployment information from your EKS cluster.

**Status**: ✅ Table created and verified working (2025-10-16)

#### Part A: Create the Table (3 minutes)

**IMPORTANT**: There are two ways to create a CI table in ServiceNow. Use **Method 1** (simpler):

---

##### **Method 1: Direct Table Creation (RECOMMENDED)**

This is the simplest method that avoids complex CI dependency configuration.

**Step-by-Step Instructions**:

1. **Open Table Definition List**
   ```
   - Click in the Filter Navigator (search box at top left)
   - Type: sys_db_object.list
   - Press Enter
   ```
   This opens the "Tables" list showing all database tables in ServiceNow.

2. **Create New Table**
   ```
   - Click the "New" button (top right)
   ```
   You'll see a form to define a new table.

3. **Fill in Table Details**
   ```
   Label: Microservice
     ↳ This is the human-readable name users will see

   Name: u_microservice
     ↳ This is the actual database table name
     ↳ ServiceNow automatically adds "u_" prefix for custom tables
     ↳ Use lowercase, no spaces

   Extends table: Configuration Item [cmdb_ci]
     ↳ Click the search icon (magnifying glass)
     ↳ Search for: "cmdb_ci"
     ↳ Select: "Configuration Item [cmdb_ci]"
     ↳ This inherits CMDB fields like name, sys_id, sys_created_on, etc.

   Application: Global (leave as default)

   Create access controls: ✓ (checked)
     ↳ This automatically creates security rules

   Add module to menu: ✓ (checked)
     ↳ This adds it to the left navigation menu

   Extensible: ✓ (checked)
     ↳ Allows extending this table in the future
   ```

4. **Save the Table**
   ```
   - Click "Submit" button (NOT "Submit and Make Dependent")
   ```
   ServiceNow will create the table. This takes 5-10 seconds.

5. **Verify Table Created**
   ```
   - You should see a success message
   - The table now appears in the Tables list
   ```

---

##### **Method 2: CI Class Manager (If You See Dependency Screen)**

If you're seeing a screen asking for "Select class for the new CI" with fields like:
- Class (Required)
- Application (Required)
- Dependent-upon class
- Identifier entries

You're in the **CI Class Manager** workflow. Here's what to do:

**Step 1: Select Class**
```
Class: Configuration Item [cmdb_ci]
  ↳ Use the lookup icon to search for "cmdb_ci"
  ↳ Select: Configuration Item [cmdb_ci]

Application: Global
  ↳ Leave as Global unless working in a scoped app
```

**Step 2: Handle Dependency Configuration (if prompted)**
```
Dependent-upon class: (Leave blank or skip)
  ↳ Microservices don't have a "depends on" relationship in ServiceNow
  ↳ If required, you can select Configuration Item [cmdb_ci] again
```

**Step 3: Identifier Entries (if prompted)**

Identifier entries define how ServiceNow uniquely identifies each microservice CI.

```
Criterion attributes: Select these attributes:
  ✓ Name (u_name)
  ✓ Namespace (u_namespace)
  ✓ Cluster Name (u_cluster_name)

  ↳ A microservice is unique by: name + namespace + cluster
  ↳ Example: "frontend" in "default" namespace on "microservices" cluster
```

**Note**: If this seems too complex, **cancel and use Method 1 instead** (sys_db_object.list).

---

**Why Method 1 is Recommended**:
- ✅ Simpler - fewer screens and configuration
- ✅ Faster - direct table creation
- ✅ Same result - you get the same u_microservice table
- ✅ Can add CI identification rules later if needed

**Continue with Part B below after table is created with either method.**

#### Part B: Add Custom Fields (7 minutes)

Now add columns to store microservice-specific data:

**Step-by-Step for Each Field**:

1. **Open Your New Table**
   ```
   - In the Tables list, find "Microservice [u_microservice]"
   - Click on it to open
   ```

2. **Go to Columns Section**
   ```
   - Scroll down to the "Columns" related list
   - Click "New" button in the Columns section
   ```

3. **Add Field #1: Service Name**
   ```
   Type: String
   Column label: Name
   Column name: u_name
   Max length: 100
   Mandatory: ✓ (checked)

   Click: Submit
   ```
   **Purpose**: Stores the Kubernetes service name (e.g., "frontend", "cartservice")

4. **Add Field #2: Namespace**
   ```
   Click "New" again in Columns section

   Type: String
   Column label: Namespace
   Column name: u_namespace
   Max length: 100
   Mandatory: ✓ (checked)

   Click: Submit
   ```
   **Purpose**: Stores the Kubernetes namespace (e.g., "default", "microservices-dev")

5. **Add Field #3: Cluster Name**
   ```
   Click "New" in Columns section

   Type: String
   Column label: Cluster Name
   Column name: u_cluster_name
   Max length: 100
   Mandatory: ☐ (unchecked)

   Click: Submit
   ```
   **Purpose**: Links to which EKS cluster this service runs on (e.g., "microservices")

6. **Add Field #4: Container Image**
   ```
   Click "New" in Columns section

   Type: String
   Column label: Image
   Column name: u_image
   Max length: 500
   Mandatory: ☐ (unchecked)

   Click: Submit
   ```
   **Purpose**: Stores the Docker image (e.g., "123456.dkr.ecr.eu-west-2.amazonaws.com/frontend:latest")

7. **Add Field #5: Desired Replicas**
   ```
   Click "New" in Columns section

   Type: Integer
   Column label: Replicas
   Column name: u_replicas
   Mandatory: ☐ (unchecked)

   Click: Submit
   ```
   **Purpose**: How many pods should be running (e.g., 3)

8. **Add Field #6: Ready Replicas**
   ```
   Click "New" in Columns section

   Type: Integer
   Column label: Ready Replicas
   Column name: u_ready_replicas
   Mandatory: ☐ (unchecked)

   Click: Submit
   ```
   **Purpose**: How many pods are actually running and healthy (e.g., 3/3)

9. **Add Field #7: Status**
   ```
   Click "New" in Columns section

   Type: String
   Column label: Status
   Column name: u_status
   Max length: 50
   Mandatory: ☐ (unchecked)

   Click: Submit
   ```
   **Purpose**: Deployment status (e.g., "Running", "Pending", "Failed")

10. **Add Field #8: Programming Language**
    ```
    Click "New" in Columns section

    Type: String
    Column label: Language
    Column name: u_language
    Max length: 50
    Mandatory: ☐ (unchecked)

    Click: Submit
    ```
    **Purpose**: What language the service is written in (e.g., "Go", "Python", "Java")

#### Part C: Verify Table is Ready (1 minute)

1. **Test Table Access**
   ```bash
   # Replace with your details
   PASSWORD='your-password'
   curl -u "github_integration:${PASSWORD}" \
     "https://your-instance.service-now.com/api/now/table/u_microservice?sysparm_limit=1"
   ```

2. **Expected Result**:
   ```json
   {"result":[]}
   ```
   ✅ Empty array means table exists and is accessible (just no records yet)

3. **If you get an error**:
   ```json
   {"error":{"message":"Invalid table u_microservice",...}}
   ```
   ❌ Table wasn't created correctly - retry the steps above

#### Part D: Access Your New Table in ServiceNow

After creation, you can view the table:

**Method 1: Direct Access**
```
Filter Navigator: u_microservice.list
```

**Method 2: Via Menu**
```
Left Navigation → Configuration → Microservices
(If you checked "Add module to menu")
```

**Method 3: Via REST API**
```bash
curl -u "github_integration:password" \
  "https://instance.service-now.com/api/now/table/u_microservice"
```

#### What This Table Does

Once created, the `eks-discovery.yaml` workflow will automatically populate this table with data like:

| Name | Namespace | Cluster | Replicas | Status | Language |
|------|-----------|---------|----------|--------|----------|
| frontend | default | microservices | 1/1 | Running | Go |
| cartservice | default | microservices | 1/1 | Running | C# |
| productcatalogservice | default | microservices | 1/1 | Running | Go |
| ... | ... | ... | ... | ... | ... |

This gives you complete visibility of all microservices in your EKS cluster(s) within ServiceNow CMDB.

#### Complete Field Summary

| # | Field Name | Type | Length | Required | Example Value |
|---|------------|------|--------|----------|---------------|
| 1 | u_name | String | 100 | Yes | "frontend" |
| 2 | u_namespace | String | 100 | Yes | "default" |
| 3 | u_cluster_name | String | 100 | No | "microservices" |
| 4 | u_image | String | 500 | No | "123456.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.0" |
| 5 | u_replicas | Integer | - | No | 3 |
| 6 | u_ready_replicas | Integer | - | No | 3 |
| 7 | u_status | String | 50 | No | "Running" |
| 8 | u_language | String | 50 | No | "Go" |

Plus inherited CMDB fields: sys_id, sys_created_on, sys_updated_on, sys_created_by, etc.

## Test Your Setup

```bash
# Test authentication
PASSWORD='your-password'
curl -u "github_integration:${PASSWORD}" \
  "https://your-instance.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# Expected: HTTP 200 with user data
```

## What Works

| Feature | Status | Uses |
|---------|--------|------|
| Change Management | ✅ Ready | Deployment approvals |
| Approval Gates | ✅ Ready | Manual approvals for QA/Prod |
| EKS Cluster CMDB | ✅ Ready | Cluster tracking |
| Microservices CMDB | ⏸️ After table creation | Service tracking |
| Security Scanning | ✅ Ready | GitHub Security tab |

## Run Your First Workflow

**Deploy to Dev** (with change management):
```bash
gh workflow run deploy-with-servicenow.yaml -f environment=dev
```

**Discover EKS Resources** (populate CMDB):
```bash
gh workflow run eks-discovery.yaml
```

**Run Security Scans** (results in GitHub):
```bash
gh workflow run security-scan-servicenow.yaml
```

## View Results

**In ServiceNow**:
- Change requests: `change_request.list`
- EKS clusters: `u_eks_cluster.list`
- Microservices: `u_microservice.list`

**In GitHub**:
- Security findings: Repository → Security → Code scanning
- Workflow runs: Actions tab

## Troubleshooting

**401 Unauthorized**:
- Check password is correct
- Verify `rest_service` role assigned
- Test with curl command above

**Table not found**:
- Verify table name: `u_microservice`
- Create table if missing (Step 5)
- Test: `curl .../api/now/table/u_microservice?sysparm_limit=1`

**Change request not created**:
- Verify Tool sys_id is correct
- Check GitHub Secrets are set
- Review workflow logs

## Documentation

- **Complete Setup**: [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md)
- **Zurich Compatibility**: [SERVICENOW-ZURICH-COMPATIBILITY.md](SERVICENOW-ZURICH-COMPATIBILITY.md)
- **Workflow Testing**: [SERVICENOW-WORKFLOW-TESTING.md](SERVICENOW-WORKFLOW-TESTING.md)
- **Migration History**: [SERVICENOW-MIGRATION-SUMMARY.md](SERVICENOW-MIGRATION-SUMMARY.md)

## Quick Reference

**Your Configuration**:
```yaml
Instance: https://calitiiltddemo3.service-now.com
Version: Zurich v6.1.0
DevOps: v6.1.0
Username: github_integration
Tool sys_id: 4eaebb06c320f690e1bbf0cb05013135

Authentication: Basic Auth (username:password)
Action Version: v2.0.0

Tables:
  ✅ change_request (standard)
  ✅ u_eks_cluster (custom, exists)
  ⏸️ u_microservice (custom, needs creation)
```

**Common Commands**:
```bash
# List tables starting with u_
curl -u "user:pass" "https://instance.service-now.com/api/now/table/sys_db_object?sysparm_query=nameLIKEu_"

# View change requests
curl -u "user:pass" "https://instance.service-now.com/api/now/table/change_request?sysparm_limit=5"

# View EKS clusters
curl -u "user:pass" "https://instance.service-now.com/api/now/table/u_eks_cluster"
```

---

**Setup Time**: ~10 minutes
**Status**: Production-ready for change management
**Next**: Create u_microservice table for full CMDB integration
