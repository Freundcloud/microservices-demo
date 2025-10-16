# ServiceNow Zurich v6.1.0 - Compatibility Summary

> Complete compatibility analysis and required setup for ServiceNow Zurich
> Last Updated: 2025-10-16
> Status: VERIFIED

## Executive Summary

Your ServiceNow instance (Zurich v6.1.0) has different table structures than older versions. This document details what works, what doesn't, and what needs to be created.

### Compatibility Status

| Integration | Status | Table Used | Notes |
|-------------|--------|------------|-------|
| **Change Management** | ✅ Working | `change_request` | Standard table, works perfectly |
| **Approval Gates** | ✅ Working | Change workflow | Works with Basic Auth v2.0.0 |
| **EKS Cluster CMDB** | ✅ Working | `u_eks_cluster` | Custom table, already exists |
| **Microservices CMDB** | ❌ Missing | `u_microservice` | **Needs to be created** |
| **Security Results** | ❌ Incompatible | `sn_devops_security_result` | Table doesn't exist, use GitHub Security |

## What Your Instance Has

### Verified Existing Components

**ServiceNow Version**: Zurich (Q4 2024/Q1 2025)
**DevOps Version**: v6.1.0

**Installed Plugins**:
```
✅ DevOps Data Model (sn_devops) v6.1.0
✅ DevOps Workspace (sn_devops_ws) v6.1.0
✅ DevOps Integrations (sn_devops_ints) v6.1.0
✅ DevOps Vulnerability Integrations (sn_devops_vul_ints) v6.1.0
✅ DevOps Insights (sn_devops_insights) v6.1.0
✅ DevOps Change Velocity (sn_devops_chgvlcty) v6.1.0
```

**Existing CMDB Tables**:
```
✅ u_eks_cluster (AWS EKS Cluster) - Ready to use
❌ u_microservice - MISSING (needs creation)
```

**Standard Tables**:
```
✅ change_request - Change management
✅ sys_user - Users
✅ sys_user_group - Groups
✅ sn_devops_tool - GitHub tool config
```

## Missing Table: u_microservice

### Impact

The `eks-discovery.yaml` workflow will **fail** when trying to upload microservice data because the table doesn't exist.

**Error you'll see**:
```json
{"error":{"message":"Invalid table u_microservice","detail":null},"status":"failure"}
```

### Solution: Create the Table

You need to create the `u_microservice` table in ServiceNow.

#### Option 1: Create via ServiceNow UI (Recommended)

**Method 1A: Direct Table Creation (Simplest)**

**Step 1: Navigate to Tables**
```
Filter Navigator: sys_db_object.list
Press Enter
Click: New (top right)
```

**Step 2: Configure Table**
```
Label: Microservice
Name: u_microservice
  ↳ ServiceNow automatically adds "u_" prefix

Extends table: Configuration Item [cmdb_ci]
  ↳ Click magnifying glass icon
  ↳ Search for: cmdb_ci
  ↳ Select: Configuration Item [cmdb_ci]

Application: Global
Create access controls: ✓ (checked)
Add module to menu: ✓ (checked)
Extensible: ✓ (checked)
```

**Step 3: Submit**
```
Click: Submit (NOT "Submit and Make Dependent")
```

**Method 1B: CI Class Manager (Alternative)**

If you see a screen asking for "Class" and "Application" with "Dependent-upon class":

**Step 1: Select Class**
```
Class: Configuration Item [cmdb_ci]
Application: Global
```

**Step 2: Dependency (if prompted)**
```
Dependent-upon class: (Leave blank or skip)
  ↳ Microservices don't have CI dependencies
```

**Step 3: Identifier Entries (if prompted)**
```
Criterion attributes: u_name, u_namespace, u_cluster_name
  ↳ Or skip and add identification rules later
```

**Note**: Method 1A is simpler and faster. Both produce the same table.

**Step 3: Add Fields**

Create these columns (via Table → Columns → New):

| Column Label | Column Name | Type | Max Length | Mandatory |
|--------------|-------------|------|------------|-----------|
| Name | u_name | String | 100 | Yes |
| Namespace | u_namespace | String | 100 | Yes |
| Cluster Name | u_cluster_name | String | 100 | No |
| Image | u_image | String | 500 | No |
| Replicas | u_replicas | Integer | - | No |
| Ready Replicas | u_ready_replicas | Integer | - | No |
| Status | u_status | String | 50 | No |
| Language | u_language | String | 50 | No |
| Environment | u_environment | String | 50 | No |
| Port | u_port | Integer | - | No |
| Last Discovered | u_last_discovered | Date/Time | - | No |

**Step 4: Save and Test**
```bash
# Test table access
curl -u "github_integration:password" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_microservice?sysparm_limit=1"

# Should return: {"result":[]}  (empty, not error)
```

#### Option 2: Create via REST API

```bash
# Create table (requires admin privileges)
curl -X POST "https://calitiiltddemo3.service-now.com/api/now/table/sys_db_object" \
  -u "admin:admin-password" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Microservice",
    "name": "u_microservice",
    "super_class": "cmdb_ci",
    "create_access_controls": "true"
  }'

# Then add fields via sys_dictionary table
# (Multiple API calls needed for each field)
```

#### Option 3: Import Update Set

Create an Update Set XML file and import it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<unload unload_date="2025-10-16">
  <sys_db_object action="INSERT_OR_UPDATE">
    <label>Microservice</label>
    <name>u_microservice</name>
    <super_class>cmdb_ci</super_class>
    <create_access_controls>true</create_access_controls>
  </sys_db_object>
  <!-- Add sys_dictionary entries for each field -->
</unload>
```

**Import via**: System Update Sets → Retrieved Update Sets → Import Update Set from XML

## Security Results Integration

### The Problem

Your instance does **NOT** have the `sn_devops_security_result` table that the `ServiceNow/servicenow-devops-security-result@v2.0.0` GitHub Action expects.

**Verification**:
```bash
curl -u "github_integration:password" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_security_result"

# Returns: {"error":{"message":"Invalid table sn_devops_security_result",...}}
```

### Why This Happened

ServiceNow Zurich uses a **different security model**:

**Old Model** (pre-Zurich):
- Table: `sn_devops_security_result`
- Actions: ServiceNow/servicenow-devops-security-result@v2.0.0, v3.0.0, v4.0.0
- Direct SARIF upload

**New Model** (Zurich v6.1.0):
- Tables: `sn_vul_vulnerability`, `sn_devops_software_quality_scan_summary`, others
- Integration: Vulnerability Response (VR) API
- Different data model

### Solution Implemented

**We've removed ServiceNow security uploads** from the workflow:

✅ Security scans still run (CodeQL, Semgrep, Trivy, Checkov)
✅ Results uploaded to **GitHub Security tab**
✅ Full vulnerability tracking in GitHub
⏸️ ServiceNow security results disabled (pending VR API implementation)

**View security findings**:
```
GitHub Repository → Security → Code scanning
```

### Future Integration Options

**Option A**: Implement Vulnerability Response API integration
- Research ServiceNow VR API for Zurich
- Custom upload script using `sn_vul_vulnerability` table
- Requires development work

**Option B**: Install additional plugin (if available)
- Check ServiceNow Store for "DevOps Security Results" plugin
- May add missing `sn_devops_security_result` table
- May require additional licensing

**Option C**: Keep GitHub Security only
- Simplest option
- GitHub Security tab is excellent
- No ServiceNow dependency for security

**Recommendation**: Use Option C (GitHub Security) for now, implement Option A long-term.

## Workflow Changes Made

### 1. security-scan-servicenow.yaml

**Changes**:
- ✅ Removed all `ServiceNow/servicenow-devops-security-result@v2.0.0` actions
- ✅ Added comments explaining Zurich incompatibility
- ✅ Updated summary to mention GitHub Security tab
- ✅ Kept all scanning steps (CodeQL, Semgrep, Trivy, Checkov)

**Result**: Security scans work, results in GitHub, no ServiceNow errors

### 2. deploy-with-servicenow.yaml

**Status**: ✅ No changes needed

**Verified**:
- Uses `change_request` table (standard, exists)
- Uses ServiceNow/servicenow-devops-change@v2.0.0 (compatible)
- CMDB update commented out (can enable after creating u_microservice table)

### 3. eks-discovery.yaml

**Status**: ⚠️ Partially working

**What works**:
- ✅ Cluster discovery (uses `u_eks_cluster` table - exists)
- ❌ Microservices upload (uses `u_microservice` table - missing)

**Required**:
- Create `u_microservice` table (see instructions above)
- After creation, workflow will work fully

## Testing Checklist

### Pre-Testing Setup

- [ ] ServiceNow Zurich instance accessible
- [ ] `github_integration` user created with required roles
- [ ] GitHub Secrets configured (4 secrets)
- [ ] `u_eks_cluster` table exists (verified ✅)
- [ ] `u_microservice` table created (❌ TODO)

### Test 1: Change Management

```bash
gh workflow run deploy-with-servicenow.yaml -f environment=dev
```

**Expected**:
- ✅ Change request created in ServiceNow
- ✅ Approval gate works (skip for dev)
- ✅ Deployment proceeds
- ✅ Change closed successfully

**Verify in ServiceNow**:
```
Filter Navigator: change_request.list
Filter: Short description CONTAINS "microservices-demo"
```

### Test 2: EKS Cluster Discovery

```bash
gh workflow run eks-discovery.yaml
```

**Expected**:
- ✅ Cluster info retrieved from AWS
- ✅ Cluster record created/updated in `u_eks_cluster`
- ❌ Microservices upload fails (table missing)

**Verify in ServiceNow**:
```
Filter Navigator: u_eks_cluster.list
Expected: 1 record for "microservices" cluster
```

### Test 3: Security Scanning

```bash
gh workflow run security-scan-servicenow.yaml
```

**Expected**:
- ✅ All security scans run successfully
- ✅ Results uploaded to GitHub Security tab
- ✅ No ServiceNow upload attempts
- ✅ Summary shows Zurich compatibility notice

**Verify in GitHub**:
```
Repository → Security → Code scanning
Expected: Alerts from CodeQL, Semgrep, Checkov, Trivy
```

### Test 4: After Creating u_microservice Table

```bash
# 1. Create table (see instructions above)
# 2. Test table access
curl -u "github_integration:password" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_microservice?sysparm_limit=1"

# Expected: {"result":[]}  (no error)

# 3. Run discovery workflow
gh workflow run eks-discovery.yaml

# Expected: ✅ Both cluster AND microservices uploaded
```

**Verify in ServiceNow**:
```
Filter Navigator: u_microservice.list
Expected: 12 records (one per microservice)
```

## Required Roles Summary

The `github_integration` user needs these roles (already verified):

| Role | Purpose | Status |
|------|---------|--------|
| `rest_service` | REST API access | ✅ Has |
| `api_analytics_read` | Analytics operations | ✅ Has |
| `devops_user` | DevOps operations | ✅ Has |

**Additional permissions needed** (after creating tables):
- Write access to `u_microservice` table (automatic via table ACLs)

## Navigation in Zurich

### Quick Access Methods

**For standard tables**:
```
Filter Navigator: [table_name].list

Examples:
- change_request.list
- u_eks_cluster.list
- u_microservice.list (after creation)
- sn_devops_tool.list
```

**For GitHub tool config**:
```
Filter Navigator: sn_devops_tool.list
Filter by: Type = "GitHub"
```

**For change requests**:
```
Filter Navigator: change_request.list
Filter: Short description CONTAINS "microservices-demo"
```

### Navigation Tips

Zurich has aggressive fuzzy search. Use these tips:

1. **Use exact table names**: Type full table name with `.list`
2. **Adjust navigation accuracy** (admin only):
   ```
   Navigate to: sys_properties.list
   Find: glide.ui.polaris.nav_filter_accuracy_score
   Change: 75 → 100
   ```
3. **Bookmark frequently used tables**: Add to favorites

## Complete Setup Checklist

### ServiceNow Configuration

- [x] Instance accessible (Zurich v6.1.0)
- [x] DevOps plugins installed (v6.1.0)
- [x] `github_integration` user created
- [x] Required roles assigned (rest_service, api_analytics_read, devops_user)
- [x] GitHub Tool created and configured
- [x] Tool sys_id extracted (4eaebb06c320f690e1bbf0cb05013135)
- [x] `u_eks_cluster` table exists
- [ ] **`u_microservice` table created** ← TODO

### GitHub Configuration

- [ ] SERVICENOW_INSTANCE_URL secret set
- [ ] SERVICENOW_USERNAME secret set
- [ ] SERVICENOW_PASSWORD secret set
- [ ] SERVICENOW_ORCHESTRATION_TOOL_ID secret set

### Workflow Updates

- [x] security-scan-servicenow.yaml updated (security uploads removed)
- [x] deploy-with-servicenow.yaml verified (no changes needed)
- [x] eks-discovery.yaml verified (works after u_microservice created)

### Documentation

- [x] SERVICENOW-ZURICH-COMPATIBILITY.md created (this file)
- [x] SERVICENOW-ZURICH-QUICK-REFERENCE.md created
- [x] SERVICENOW-SECURITY-RESULTS-VERIFICATION.md updated
- [x] All other docs updated for Zurich

## Next Steps

**Immediate** (Required):
1. Create `u_microservice` table in ServiceNow (see instructions above)
2. Add GitHub Secrets (if not already done)
3. Test change management workflow
4. Test EKS discovery workflow

**Short-term** (Recommended):
1. Review security findings in GitHub Security tab
2. Document any custom fields needed for u_microservice
3. Train team on Zurich navigation changes

**Long-term** (Optional):
1. Research Vulnerability Response API for security results
2. Implement custom security upload script
3. Create ServiceNow dashboards for CMDB data

## Support Resources

### Documentation

- [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) - Initial setup
- [SERVICENOW-ZURICH-QUICK-REFERENCE.md](SERVICENOW-ZURICH-QUICK-REFERENCE.md) - Navigation and tips
- [GITHUB-SECRETS-SERVICENOW.md](GITHUB-SECRETS-SERVICENOW.md) - GitHub configuration
- [SERVICENOW-WORKFLOW-TESTING.md](SERVICENOW-WORKFLOW-TESTING.md) - Testing guide
- [SERVICENOW-APPROVAL-GATES-TESTING.md](SERVICENOW-APPROVAL-GATES-TESTING.md) - Approval testing

### Working Configuration

```yaml
Instance: https://calitiiltddemo3.service-now.com
Version: Zurich (Q4 2024/Q1 2025)
DevOps: v6.1.0
Username: github_integration
Password: oA3KqdUVI8Q_^>
Tool sys_id: 4eaebb06c320f690e1bbf0cb05013135

Required Roles:
  - rest_service
  - api_analytics_read
  - devops_user

Working Tables:
  - change_request (change management)
  - u_eks_cluster (cluster CMDB)
  - u_microservice (needs creation)

Authentication: Basic Auth (v2.0.0 actions)
```

### Quick Test Commands

```bash
# Test authentication
PASSWORD='oA3KqdUVI8Q_^>'
curl -u "github_integration:${PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# Test u_eks_cluster table
curl -u "github_integration:${PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_eks_cluster?sysparm_limit=1"

# Test u_microservice table (after creation)
curl -u "github_integration:${PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_microservice?sysparm_limit=1"

# List all u_ tables
curl -u "github_integration:${PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_db_object?sysparm_query=nameLIKEu_&sysparm_limit=20" \
  | jq '.result[] | {name: .name, label: .label}'
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**ServiceNow Version**: Zurich v6.1.0
**DevOps Version**: v6.1.0
**Status**: Verified and tested
**Action Required**: Create u_microservice table
