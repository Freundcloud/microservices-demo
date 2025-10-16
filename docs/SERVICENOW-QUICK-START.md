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

### Step 5: Create u_microservice Table (5 minutes)

**Required for CMDB features**

```
1. Filter Navigator: sys_db_object.list
2. Click: New
3. Configure:
   - Label: Microservice
   - Name: u_microservice
   - Extends: Configuration Item (cmdb_ci)
4. Save
5. Add columns (via Columns tab → New):
```

| Column Name | Type | Length | Mandatory |
|-------------|------|--------|-----------|
| u_name | String | 100 | Yes |
| u_namespace | String | 100 | Yes |
| u_cluster_name | String | 100 | No |
| u_image | String | 500 | No |
| u_replicas | Integer | - | No |
| u_ready_replicas | Integer | - | No |
| u_status | String | 50 | No |
| u_language | String | 50 | No |

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
