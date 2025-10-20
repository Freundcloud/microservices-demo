# ServiceNow Integration Guide

> Complete guide for integrating this microservices demo with ServiceNow DevOps Change Velocity
> Last Updated: 2025-10-20

## Overview

This demo integrates GitHub Actions with ServiceNow to provide automated change management, approvals, and CMDB population for Kubernetes microservices deployments.

**What You Get**:
- ✅ Automated change requests for every deployment
- ✅ Approval gates for QA and Production environments
- ✅ Security scan evidence attached to changes
- ✅ EKS cluster and microservice discovery in CMDB
- ✅ Complete audit trail of all deployments

## Prerequisites

- ServiceNow instance (Zurich v6.1.0 or later)
- Admin access to ServiceNow
- GitHub repository admin access (to add secrets)
- AWS EKS cluster (for CMDB features)

## Quick Setup (15 minutes)

### 1. Create ServiceNow Service Account

1. Navigate to **System Security → Users**
2. Click **New**
3. Fill in:
   - **User ID**: `github_integration`
   - **First name**: GitHub
   - **Last name**: Integration
   - **Email**: your-email@company.com
   - **Active**: ✓
   - **Web service access only**: ✓
4. Set a strong password
5. **Save**

### 2. Assign Required Roles

Open the `github_integration` user and assign these roles:

- `rest_service` - API access
- `api_analytics_read` - Read API metrics
- `itil` - Change management
- `devops_user` - DevOps integrations (if using DevOps Change Velocity)

### 3. Register GitHub Tool in ServiceNow

1. Navigate to **DevOps → Tools**
2. Click **New**
3. Fill in:
   - **Name**: GitHub microservices-demo
   - **Type**: GitHub
   - **URL**: https://github.com/your-org/microservices-demo
4. **Save** and copy the `sys_id` from the URL

### 4. Add GitHub Secrets

```bash
gh secret set SERVICENOW_INSTANCE_URL --body "https://your-instance.service-now.com"
gh secret set SERVICENOW_USERNAME --body "github_integration"
gh secret set SERVICENOW_PASSWORD --body "your-password"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "paste-sys-id-here"
```

### 5. Create Custom CMDB Tables (Optional)

For full CMDB integration, create these custom tables:

#### Table 1: u_eks_cluster

Stores EKS cluster information.

**Fields**:
- `u_cluster_name` (String, 100) - Cluster name
- `u_region` (String, 50) - AWS region
- `u_version` (String, 20) - Kubernetes version
- `u_node_count` (Integer) - Number of nodes
- `u_status` (String, 50) - Cluster status

**Create**: System Definition → Tables → New

#### Table 2: u_microservice

Stores microservice deployment information.

**Fields**:
- `u_name` (String, 100, Required) - Service name
- `u_namespace` (String, 100, Required) - Kubernetes namespace
- `u_cluster_name` (String, 100) - Which cluster
- `u_image` (String, 500) - Container image
- `u_replicas` (Integer) - Desired replicas
- `u_ready_replicas` (Integer) - Ready replicas
- `u_status` (String, 50) - Deployment status
- `u_language` (String, 50) - Programming language

**Extends**: Configuration Item [cmdb_ci]

## Available Workflows

This demo includes three pre-configured workflows:

### 1. Deploy with ServiceNow (Basic)

**File**: `.github/workflows/deploy-with-servicenow-basic.yaml`

**What it does**:
- Creates change request via Table API
- Uploads security scan evidence
- Waits for approval
- Deploys to Kubernetes
- Updates change request with result

**Best for**: Production use, most reliable

**Trigger**:
```bash
gh workflow run deploy-with-servicenow-basic.yaml -f environment=dev
```

### 2. Deploy with ServiceNow DevOps Change

**File**: `.github/workflows/deploy-with-servicenow-devops.yaml`

**What it does**:
- Uses DevOps Change Velocity API
- Creates changes visible in DevOps workspace
- Tracks pipeline runs
- Enables DORA metrics

**Best for**: Modern ServiceNow instances with DevOps Change Velocity

**Requirements**:
- ServiceNow DevOps Change plugin installed
- DevOps integration token configured

**Trigger**:
```bash
gh workflow run deploy-with-servicenow-devops.yaml -f environment=dev
```

### 3. EKS Discovery

**File**: `.github/workflows/aws-infrastructure-discovery.yaml`

**What it does**:
- Discovers EKS clusters in your AWS account
- Populates `u_eks_cluster` table
- Discovers all microservice deployments
- Populates `u_microservice` table
- Updates existing records or creates new ones

**Trigger**:
```bash
gh workflow run aws-infrastructure-discovery.yaml
```

## Integration Approaches

There are two ways to integrate with ServiceNow:

### Option A: Table API (Recommended)

**Pros**:
- ✅ Works on all ServiceNow versions
- ✅ Simple, reliable
- ✅ Uses standard change_request table
- ✅ Full control over change fields

**Cons**:
- ❌ Changes don't appear in DevOps workspace
- ❌ No DORA metrics tracking
- ❌ Manual correlation ID management

**Use when**: You want maximum reliability and compatibility

### Option B: DevOps Change API

**Pros**:
- ✅ Modern DevOps workspace UI
- ✅ DORA metrics automatically tracked
- ✅ Pipeline runs visible in ServiceNow
- ✅ Work item association

**Cons**:
- ❌ Requires DevOps Change plugin
- ❌ Needs additional configuration
- ❌ May require ServiceNow admin to enable properties

**Use when**: You have DevOps Change Velocity and want advanced features

## Environment-Specific Behaviors

This demo uses different approval workflows per environment:

| Environment | Approval Required | Timeout | Risk Level |
|-------------|-------------------|---------|------------|
| **dev** | No | N/A | Low |
| **qa** | Yes | 2 hours | Normal |
| **prod** | Yes | 24 hours | High |

Configure this in your workflows using the `change-request` JSON.

## Testing Your Integration

### Test 1: Authentication

```bash
PASSWORD='your-password'
curl -u "github_integration:${PASSWORD}" \
  "https://your-instance.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**Expected**: HTTP 200 with user data

### Test 2: Create Change Request

```bash
gh workflow run deploy-with-servicenow-basic.yaml -f environment=dev
```

**Expected**:
1. Workflow creates change request
2. Change appears in ServiceNow (change_request.list)
3. Deployment proceeds automatically (dev has no approval)
4. Change is marked successful

### Test 3: Approval Flow

```bash
gh workflow run deploy-with-servicenow-basic.yaml -f environment=qa
```

**Expected**:
1. Change request created
2. Workflow pauses waiting for approval
3. In ServiceNow, approve the change
4. Workflow resumes and deploys
5. Change is marked successful

### Test 4: CMDB Discovery

```bash
gh workflow run aws-infrastructure-discovery.yaml
```

**Expected**:
1. Workflow discovers EKS clusters
2. Records appear in u_eks_cluster table
3. Workflow discovers microservices
4. Records appear in u_microservice table

## Viewing Results

### In ServiceNow

**Change Requests**:
```
Filter Navigator → change_request.list
```

**DevOps Workspace** (if using DevOps Change API):
```
Filter Navigator → DevOps Change → Change Home
```

**EKS Clusters**:
```
Filter Navigator → u_eks_cluster.list
```

**Microservices**:
```
Filter Navigator → u_microservice.list
```

### In GitHub

**Workflow Runs**:
```
Repository → Actions tab
```

**Security Findings**:
```
Repository → Security → Code scanning alerts
```

## Best Practices

### 1. Use Descriptive Change Descriptions

Include:
- What is being deployed
- Which services are affected
- Commit SHA or version
- Who triggered it
- Link back to GitHub

### 2. Always Include Plans

Every change should have:
- **Implementation plan**: Step-by-step deployment process
- **Backout plan**: How to rollback if it fails
- **Test plan**: How to verify it worked

### 3. Set Appropriate Timeouts

- **Dev**: No timeout needed (auto-approved)
- **QA**: 2 hours (next business day)
- **Prod**: 24 hours (time for CAB review)

### 4. Use Correlation IDs

Always include:
```yaml
correlation_id: "${{ github.repository }}/${{ github.run_id }}"
```

This links the change back to the GitHub Actions run.

### 5. Handle Failures Gracefully

Always update the change request if deployment fails:
```yaml
- name: Update Change - Failed
  if: failure()
  run: |
    # Mark change as unsuccessful with failure details
```

## Common Issues

### Issue: 401 Unauthorized

**Cause**: Invalid credentials or missing roles

**Fix**:
1. Verify username/password in GitHub Secrets
2. Check user has `rest_service` role
3. Ensure "Web service access only" is checked

### Issue: Table not found (u_microservice)

**Cause**: Custom table not created

**Fix**: Create the table following Step 5 above

### Issue: Change not appearing in DevOps workspace

**Cause**: Using Table API instead of DevOps Change API

**Fix**: Switch to `deploy-with-servicenow-devops.yaml` workflow

### Issue: Workflow times out waiting for approval

**Cause**: Change was never approved in ServiceNow

**Fix**:
1. Check change request exists in ServiceNow
2. Approve it manually
3. Or cancel the workflow run

### Issue: Type compatibility property error

**Cause**: DevOps Change API requires property enabled

**Fix**:
1. Option A: Ask ServiceNow admin to enable `com.snc.change_management.change_model.type_compatibility`
2. Option B: Add `"changeModel":"Standard"` to change-request JSON
3. Option C: Use Table API workflow instead

## Security Considerations

### Credential Storage

- ✅ **DO**: Store credentials in GitHub Secrets
- ❌ **DON'T**: Hardcode credentials in workflows
- ❌ **DON'T**: Log credentials to console

### Service Account Permissions

- ✅ **DO**: Use dedicated service account
- ✅ **DO**: Enable "Web service access only"
- ❌ **DON'T**: Use your personal admin account
- ❌ **DON'T**: Give account more roles than needed

### Network Security

- ✅ **DO**: Use HTTPS for all API calls
- ✅ **DO**: Validate SSL certificates
- ❌ **DON'T**: Disable SSL verification

## Further Reading

- **ServiceNow DevOps Change Velocity Documentation**: [docs.servicenow.com](https://docs.servicenow.com/bundle/utah-devops/page/product/enterprise-dev-ops/concept/devops-change-velocity.html)
- **GitHub Actions ServiceNow Integration**: [github.com/ServiceNow](https://github.com/ServiceNow/servicenow-devops-change)
- **Change Management Best Practices**: Internal ServiceNow documentation

## Support

For issues with:
- **This demo repository**: Open GitHub issue
- **ServiceNow DevOps**: Contact ServiceNow support
- **GitHub Actions**: Check GitHub Community forums

---

**Quick Reference**:

```yaml
Instance: https://calitiiltddemo3.service-now.com
Version: Zurich v6.1.0
Username: github_integration
Authentication: Basic Auth

Tables:
  - change_request (standard)
  - u_eks_cluster (custom)
  - u_microservice (custom)

Workflows:
  - deploy-with-servicenow-basic.yaml (Table API)
  - deploy-with-servicenow-devops.yaml (DevOps Change API)
  - aws-infrastructure-discovery.yaml (CMDB)
```
