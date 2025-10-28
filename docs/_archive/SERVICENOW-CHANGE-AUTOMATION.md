# ServiceNow Change Automation

## Overview

This document describes the automated change management integration that creates ServiceNow change requests before infrastructure and application deployments, with environment-specific approval workflows.

## Quick Summary

| Environment | Approval Type | Behavior |
|-------------|---------------|----------|
| **DEV** | Auto-Approve | Change created → Immediately approved → Deployment proceeds |
| **QA** | Manual Approval | Change created → **Waits for approval** → Deployment proceeds after approval |
| **PROD** | Manual Approval | Change created → **Waits for approval** → Deployment proceeds after approval |

## Architecture

### Complete Change Management Flow

```
┌────────────────────────────────────────────────────────────────┐
│ Developer Triggers Deployment                                  │
│ - just tf-apply (Terraform)                                    │
│ - just k8s-deploy (Kubernetes)                                 │
│ - GitHub Actions workflow dispatch                             │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ ServiceNow Change Automation Workflow                          │
│ (.github/workflows/servicenow-change.yaml)                     │
│                                                                 │
│ 1. Determine environment (dev/qa/prod)                         │
│ 2. Prepare change details (description, plans, etc.)           │
│ 3. Create change request in ServiceNow                         │
└────────────────┬───────────────────────────────────────────────┘
                 │
                 ▼
          ┌──────┴──────┐
          │             │
     DEV  │             │  QA/PROD
          │             │
          ▼             ▼
┌──────────────┐  ┌─────────────────────────────────────────────┐
│ Auto-Approve │  │ Manual Approval Required                    │
│              │  │                                             │
│ - state:     │  │ - state: "assess"                           │
│   "implement"│  │ - Workflow PAUSES                           │
│ - Immediate  │  │ - ServiceNow sends notification            │
│   deployment │  │ - Approver reviews change in ServiceNow    │
│              │  │ - Approver clicks "Approve"                 │
│              │  │ - GitHub workflow RESUMES                   │
└──────┬───────┘  └──────┬──────────────────────────────────────┘
       │                 │
       │                 │ ✅ Approved
       ▼                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Deployment Proceeds                                             │
│ - Terraform Apply  OR                                          │
│ - Kubernetes Deployment                                        │
└────────────────────────────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────────┐
│ Post-Deployment                                                 │
│ - Change automatically closed (autoCloseChange: true)          │
│ - Deployment results linked to change record                   │
│ - Complete audit trail in ServiceNow                           │
└────────────────────────────────────────────────────────────────┘
```

## Integration Points

### 1. Terraform Infrastructure Changes

**Workflow**: `.github/workflows/terraform-apply.yaml`

**When Triggered**:
- `just tf-apply` (applies to dev by default)
- `just tf-apply qa` (applies to QA)
- `just tf-apply prod` (applies to production)
- Manual workflow dispatch in GitHub Actions

**Change Request Details**:
```
Short Description: Terraform apply - {environment} infrastructure
Change Type: terraform
Description: Infrastructure change via Terraform apply command
  - Environment: dev/qa/prod
  - Action: apply/destroy
  - Triggered by: {github.actor}
  - Commit: {github.sha}

Implementation Plan:
  1. Initialize Terraform with remote backend
  2. Validate configuration syntax
  3. Generate and review execution plan
  4. Apply infrastructure changes
  5. Verify EKS cluster accessibility
  6. Update kubeconfig for kubectl access

Backout Plan:
  1. Review terraform state backup
  2. Execute terraform apply with previous configuration
  3. Verify infrastructure rolled back successfully
  4. Validate all services operational

Test Plan:
  1. Verify terraform validation passed
  2. Review terraform plan for expected changes
  3. Confirm EKS cluster accessible via kubectl
  4. Verify node groups healthy
  5. Check all AWS resources created/updated correctly
```

### 2. Kubernetes Application Deployments

**Workflow**: `.github/workflows/deploy-environment.yaml`

**When Triggered**:
- `just k8s-deploy` (deploys to dev)
- Manual workflow dispatch for specific environment
- Called by CI/CD pipelines

**Change Request Details**:
```
Short Description: Deploy microservices to {environment} (Kubernetes)
Change Type: kubernetes
Description: Kubernetes deployment of microservices application
  - Environment: dev/qa/prod
  - Namespace: microservices-{environment}
  - Deployment Method: Kustomize overlays
  - Triggered by: {github.actor}
  - Commit: {github.sha}

Implementation Plan:
  1. Configure kubectl access to EKS cluster
  2. Ensure namespace microservices-{environment} exists
  3. Apply Kustomize overlays for {environment}
  4. Monitor rollout status for all deployments
  5. Verify all pods healthy and running
  6. Test frontend application endpoint

Backout Plan:
  1. kubectl rollout undo -n microservices-{environment} --all
  2. Verify all services rolled back to previous version
  3. Monitor pod status and logs
  4. Test application functionality

Test Plan:
  1. Verify all deployments rolled out successfully
  2. Check all pods are in Running state
  3. Verify service endpoints responding
  4. Test frontend URL accessibility
  5. Monitor application metrics and logs
```

## Environment-Specific Behavior

### DEV Environment

**Configuration**:
```yaml
change-request:
  setCloseCode: "true"
  autoCloseChange: true
  attributes:
    type: "standard"
    state: "implement"      # Auto-approved state
    priority: "3"           # Low priority
```

**Behavior**:
- ✅ Change request created immediately
- ✅ Automatically moved to "implement" state (approved)
- ✅ No waiting period
- ✅ Deployment proceeds within seconds
- ✅ Automatically closed after deployment

**Timeout Settings**:
- `interval`: 30 seconds
- `timeout`: 600 seconds (10 minutes)
- `changeCreationTimeOut`: 300 seconds (5 minutes)
- `abortOnChangeCreationFailure`: false (continue even if creation fails)

### QA/PROD Environments

**Configuration**:
```yaml
change-request:
  setCloseCode: "true"
  autoCloseChange: true
  attributes:
    type: "standard"
    state: "assess"         # Requires approval
    priority: "2" (prod) or "3" (qa)
```

**Behavior**:
- 📋 Change request created
- ⏸️ Workflow **PAUSES** waiting for approval
- 📧 ServiceNow sends notification to approvers
- 👤 Approver reviews change in ServiceNow
- ✅ Approver clicks "Approve" button
- ▶️ GitHub workflow **RESUMES** automatically
- 🚀 Deployment proceeds
- ✅ Change automatically closed after deployment

**Timeout Settings**:
- `interval`: 100 seconds (checks approval status every 100s)
- `timeout`: 3600 seconds (1 hour max wait)
- `changeCreationTimeOut`: 600 seconds (10 minutes to create)
- `abortOnChangeCreationFailure`: true (fail workflow if creation fails)
- `abortOnChangeStepTimeout`: true (fail if timeout exceeded)

## Required GitHub Secrets

Same secrets used across all ServiceNow integrations:

| Secret | Description | Example |
|--------|-------------|---------|
| `SERVICENOW_USERNAME` | ServiceNow integration user | `github.integration@company.com` |
| `SERVICENOW_PASSWORD` | User password | `********` |
| `SERVICENOW_INSTANCE_URL` | Full ServiceNow URL | `https://dev12345.service-now.com` |
| `SN_ORCHESTRATION_TOOL_ID` | GitHub tool sys_id | `abc123def456...` |

## ServiceNow Configuration

### Prerequisites

1. **ServiceNow DevOps Plugin** - Version with Change Automation support
2. **GitHub Integration** - Orchestration tool configured
3. **Service Account** with permissions:
   - `sn_devops.devops_integration_user` role
   - Create/Update access to `change_request` table
   - API access enabled
4. **Change Management Process** - Standard change process configured

### Approver Configuration

**For QA/PROD Manual Approvals**:

1. Navigate to: **Change Management** → **Configuration** → **Approval Rules**
2. Create approval rule for GitHub changes:
   - **Condition**: `u_source = "GitHub Actions"`
   - **Environment**: QA or PROD
   - **Approvers**: DevOps team, Release Manager, etc.
3. Configure notifications for approvers

**Example Approval Rule**:
```
Name: GitHub QA/PROD Deployments
Conditions:
  - u_source = "GitHub Actions"
  - u_environment IN (qa, prod)
Approvers:
  - DevOps Manager
  - Release Manager
  - Security Team Lead (prod only)
Approval Type: All must approve (prod) / Any approves (qa)
```

## How Manual Approval Works

### Approver Experience (QA/PROD)

**1. Notification Received**:
```
Email Subject: Change Request CHG0012345 Awaiting Approval

Change: Deploy microservices to prod (Kubernetes)
Priority: High
Requested by: GitHub Actions (john.doe)
Environment: Production
Implementation: 2025-10-27 15:30 UTC

Review change details:
https://yourinstance.service-now.com/change_request.do?sys_id=...
```

**2. Review Change in ServiceNow**:
- Navigate to change request CHG0012345
- Review:
  - Description and justification
  - Implementation plan
  - Backout plan
  - Test plan
  - Linked packages (Docker images)
  - Test results (unit tests)
  - Security scan results
  - Git commit details

**3. Approve or Reject**:
- Click "Approve" button → GitHub workflow resumes
- Click "Reject" button → GitHub workflow fails
- Add comments if needed

**4. GitHub Workflow Resumes**:
- ServiceNow updates change state to "approved"
- GitHub Actions polls and detects approval
- Deployment proceeds automatically
- Change auto-closes upon completion

### Developer Experience

**DEV Deployment** (Auto-Approve):
```bash
$ just tf-apply

# Output:
Creating ServiceNow change request...
✅ Change CHG0012345 created and auto-approved
Proceeding with terraform apply...
```

**QA/PROD Deployment** (Manual Approval):
```bash
$ just tf-apply prod

# Output:
Creating ServiceNow change request...
📋 Change CHG0012346 created
⏸️ Waiting for approval in ServiceNow...
   Change URL: https://yourinstance.service-now.com/...

   Checking approval status every 100 seconds...
   [After approval in ServiceNow]

✅ Change approved!
Proceeding with terraform apply...
```

## Reusable Workflow

### servicenow-change.yaml

**Location**: `.github/workflows/servicenow-change.yaml`

**Purpose**: Reusable workflow called by other workflows to create change requests

**Inputs**:
- `environment` (required): dev/qa/prod
- `change_type` (required): terraform/kubernetes/application
- `short_description` (required): Brief change description
- `description` (optional): Detailed description
- `implementation_plan` (optional): How to implement
- `backout_plan` (optional): How to rollback
- `test_plan` (optional): Testing approach
- `assignment_group` (optional): ServiceNow group

**Outputs**:
- `change_request_number`: ServiceNow change number (e.g., CHG0012345)
- `change_request_sys_id`: ServiceNow sys_id
- `change_approved`: Whether change was approved

**Usage Example**:
```yaml
jobs:
  request-change:
    uses: ./.github/workflows/servicenow-change.yaml
    with:
      environment: 'prod'
      change_type: 'kubernetes'
      short_description: 'Deploy frontend v1.2.3 to production'
    secrets: inherit

  deploy:
    needs: request-change
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: kubectl apply -k overlays/prod
```

## Verification

### Check Change Request in ServiceNow

**1. Navigate to Change Requests**:
```
Change Management → All Changes
```

**2. Filter by Source**:
- Filter: `u_source = "GitHub Actions"`
- Sort by: Created (descending)

**3. Verify Change Details**:
- **Number**: CHG0012345
- **Short Description**: Matches workflow input
- **State**:
  - DEV: "Implement" or "Closed Complete"
  - QA/PROD: "Assess" → "Approved" → "Implement" → "Closed Complete"
- **Environment**: dev/qa/prod
- **Change Type**: terraform/kubernetes
- **Implementation Plan**: Populated
- **Backout Plan**: Populated
- **Test Plan**: Populated

### Check GitHub Actions Logs

**1. Navigate to Workflow Run**:
- Go to **Actions** tab
- Click on workflow run
- Expand "ServiceNow Change Request" job

**2. Verify Steps**:
- ✅ "Prepare Change Details"
- ✅ "Create Change Request (DEV)" OR "Create Change Request (QA/PROD)"
- ✅ "Consolidate Change Outputs"
- ✅ "Change Request Summary"

**3. Check Summary**:
```
📋 ServiceNow Change Request
Change Number: CHG0012345
Environment: prod
Change Type: terraform
Approval: ✅ Approved via ServiceNow

Next Steps: Deployment will proceed
```

## Troubleshooting

### Change Creation Fails

**Symptom**: "Create Change Request" step fails

**Common Causes**:

1. **Authentication Error**
   ```
   Error: 401 Unauthorized
   ```
   - Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD`
   - Test by logging into ServiceNow UI

2. **Invalid Tool ID**
   ```
   Error: Tool not found
   ```
   - Verify `SN_ORCHESTRATION_TOOL_ID` matches GitHub tool

3. **Insufficient Permissions**
   ```
   Error: User cannot create change requests
   ```
   - Grant `itil` or `change_manager` role to service account

4. **Invalid JSON**
   ```
   Error: Malformed change-request JSON
   ```
   - Check workflow YAML for syntax errors in change-request block

### Workflow Times Out Waiting for Approval

**Symptom**: Workflow fails after 1 hour in QA/PROD

**Solutions**:

1. **Extend Timeout**: Increase `timeout` parameter (default 3600s)
2. **Check Approver Notifications**: Verify approvers received emails
3. **Manual Intervention**: Approver can approve directly in ServiceNow
4. **Retry**: Re-run failed workflow after approval

### Change Created but Workflow Doesn't Resume

**Symptom**: Change approved in ServiceNow but GitHub workflow still waiting

**Solutions**:

1. **Check Polling**: Workflow polls every `interval` seconds (default 100s)
2. **Wait Longer**: May take up to 2-3 minutes to detect approval
3. **Check Change State**: Ensure state changed to "approved" or "implement"
4. **API Issues**: Check ServiceNow system logs for API errors

### DEV Not Auto-Approving

**Symptom**: DEV environment requires manual approval

**Solutions**:

1. **Check Environment**: Verify `environment` input is exactly `"dev"`
2. **Check Workflow**: Review servicenow-change.yaml conditional logic
3. **Check State**: DEV should create change with `state: "implement"`

## Integration with Existing Workflows

### Master Pipeline Integration

The change automation is already integrated into:

- ✅ `terraform-apply.yaml` - Infrastructure changes
- ✅ `deploy-environment.yaml` - Kubernetes deployments

For custom workflows, follow this pattern:

```yaml
jobs:
  # 1. Request change BEFORE deployment
  request-change:
    uses: ./.github/workflows/servicenow-change.yaml
    with:
      environment: ${{ inputs.environment }}
      change_type: 'application'
      short_description: 'Deploy my-app to ${{ inputs.environment }}'
    secrets: inherit

  # 2. Deploy AFTER change approved
  deploy:
    needs: request-change
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Application
        run: ./deploy.sh ${{ inputs.environment }}

      - name: Show Change Request
        run: |
          echo "Change Request: ${{ needs.request-change.outputs.change_request_number }}"
```

## Benefits

### For Operations Teams
- ✅ Automated change request creation
- ✅ No manual change request filing
- ✅ Complete audit trail automatically
- ✅ All deployment details captured

### For Change Approvers
- ✅ Full context for approval decisions
- ✅ Implementation/backout/test plans included
- ✅ Linked to test results and security scans
- ✅ Git commit history available

### For Compliance & Audit
- ✅ Every deployment has change record
- ✅ Approval evidence for regulated changes
- ✅ Complete traceability: Change → Code → Deployment
- ✅ Meets SOC 2 / ISO 27001 / ITIL requirements

### For Development Teams
- ✅ Minimal workflow disruption
- ✅ DEV environment fast (auto-approve)
- ✅ QA/PROD protected (manual approval)
- ✅ Transparent approval status

## Related Documentation

- **[Package Registration](SERVICENOW-PACKAGE-REGISTRATION.md)** - Docker image tracking
- **[Test Integration](SERVICENOW-TEST-INTEGRATION.md)** - Unit test results
- **[Terraform Apply Workflow](../.github/workflows/terraform-apply.yaml)** - Infrastructure deployment
- **[Deploy Environment Workflow](../.github/workflows/deploy-environment.yaml)** - Kubernetes deployment
- **[ServiceNow DevOps Change](https://github.com/ServiceNow/servicenow-devops-change)** - Official action

## Future Enhancements

Potential improvements:

1. **Emergency Changes**: Fast-track approval for critical fixes
2. **Scheduled Changes**: Pre-approved maintenance windows
3. **Risk Assessment**: Auto-calculate risk based on change scope
4. **Rollback Automation**: Automatic rollback if deployment fails
5. **Change Analytics**: Dashboard of change success rates
6. **Multi-Approval Workflows**: Different approvers for different environments

---

**Last Updated**: 2025-10-27
**Maintained By**: DevOps Team
