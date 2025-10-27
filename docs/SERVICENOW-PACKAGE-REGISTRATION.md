# ServiceNow Package Registration Integration

## Overview

This document describes how Docker container images are automatically registered as packages in ServiceNow whenever they are built and pushed to Amazon ECR.

## Architecture

### Registration Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ GitHub Actions: Build and Push Docker Images                        │
│                                                                      │
│  1. Detect changed services                                         │
│  2. Build Docker image for each service                             │
│  3. Run Trivy security scan                                         │
│  4. Push to Amazon ECR                                              │
│  5. Generate SBOM (Software Bill of Materials)                      │
│  6. ✅ Register Package with ServiceNow ← NEW                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ API Call (Basic Auth)
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ServiceNow DevOps Change Management                                 │
│                                                                      │
│  Package Table (sn_devops_package)                                  │
│  ├── Package Name: frontend-dev-1234.package                        │
│  ├── Artifacts:                                                     │
│  │   └── 123456789.dkr.ecr.eu-west-2.amazonaws.com/frontend         │
│  │       Version: dev-abc123def456                                  │
│  │       Semantic Version: dev-1234                                 │
│  │       Repository: Freundcloud/microservices-demo                 │
│  └── Associated with Change Request                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation Details

### Workflow: `.github/workflows/build-images.yaml`

Each microservice that is built and pushed to ECR is **individually registered** as a package in ServiceNow.

#### Registration Step

```yaml
- name: Register Package with ServiceNow
  if: inputs.push_images
  uses: ServiceNow/servicenow-devops-register-package@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Build ${{ matrix.service }}'
    artifacts: '[{"name": "${{ env.ECR_REGISTRY }}/${{ matrix.service }}", "version": "${{ inputs.environment }}-${{ github.sha }}", "semanticVersion": "${{ inputs.environment }}-${{ github.run_number }}", "repositoryName": "${{ github.repository }}"}]'
    package-name: '${{ matrix.service }}-${{ inputs.environment }}-${{ github.run_number }}.package'
  continue-on-error: true
```

### Authentication Method

This integration uses **Basic Authentication** with ServiceNow:

- **Username**: Stored in `SERVICENOW_USERNAME` secret
- **Password**: Stored in `SERVICENOW_PASSWORD` secret

### Package Naming Convention

Each package follows this naming pattern:

```
{service-name}-{environment}-{github-run-number}.package
```

**Examples**:
- `frontend-dev-1234.package`
- `cartservice-qa-5678.package`
- `checkoutservice-prod-9012.package`

### Artifact Details

Each package contains a single artifact (the Docker image) with the following metadata:

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Full ECR image path | `123456789.dkr.ecr.eu-west-2.amazonaws.com/frontend` |
| `version` | Environment + commit SHA | `dev-abc123def456` |
| `semanticVersion` | Environment + workflow run number | `dev-1234` |
| `repositoryName` | GitHub repository | `Freundcloud/microservices-demo` |

## Microservices Registered

All 12 microservices are registered when built:

1. **emailservice** - Python-based email notification service
2. **productcatalogservice** - Go-based product catalog
3. **recommendationservice** - Python ML recommendation engine
4. **shippingservice** - Go shipping cost calculator
5. **checkoutservice** - Go order orchestration service
6. **paymentservice** - Node.js payment processor
7. **currencyservice** - Node.js currency converter
8. **cartservice** - C# shopping cart with Redis
9. **frontend** - Go web UI
10. **adservice** - Java contextual ads service
11. **loadgenerator** - Python/Locust load testing tool
12. **shoppingassistantservice** - Java AI shopping assistant

## When Packages Are Registered

Packages are registered when:

1. ✅ The service source code has changed (detected by `dorny/paths-filter`)
2. ✅ Docker image is successfully built
3. ✅ Trivy security scan completes (even if vulnerabilities found)
4. ✅ Image is pushed to Amazon ECR (`inputs.push_images == true`)

Packages are **NOT** registered when:

- ❌ Build-only mode (`inputs.push_images == false`)
- ❌ Service build fails
- ❌ No services have changes and it's not a manual dispatch

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SERVICENOW_USERNAME` | ServiceNow user with API access | `github.integration@example.com` |
| `SERVICENOW_PASSWORD` | Password for ServiceNow user | `********` |
| `SERVICENOW_INSTANCE_URL` | Full URL to ServiceNow instance | `https://dev12345.service-now.com` |
| `SN_ORCHESTRATION_TOOL_ID` | sys_id of GitHub tool in ServiceNow | `abc123def456...` |
| `AWS_ACCOUNT_ID` | AWS account ID for ECR registry | `123456789012` |

### How to Configure Secrets

```bash
# Set ServiceNow credentials
gh secret set SERVICENOW_USERNAME --body "your-username"
gh secret set SERVICENOW_PASSWORD --body "your-password"
gh secret set SERVICENOW_INSTANCE_URL --body "https://yourinstance.service-now.com"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "your-tool-sys-id"

# AWS credentials (if not already set)
gh secret set AWS_ACCOUNT_ID --body "123456789012"
```

## ServiceNow Configuration

### Prerequisites

1. **ServiceNow DevOps Plugin** installed and activated
2. **GitHub Integration** configured in ServiceNow
3. **Orchestration Tool** created for GitHub (provides `SN_ORCHESTRATION_TOOL_ID`)
4. **Service Account** with permissions:
   - `sn_devops.devops_integration_user` role
   - Read/Write access to `sn_devops_package` table
   - API access enabled

### Finding Your Tool ID

1. Navigate to **DevOps** > **Orchestration** > **Tools**
2. Find your GitHub tool entry
3. Copy the **sys_id** from the URL or record
4. Store in `SN_ORCHESTRATION_TOOL_ID` secret

## Verification

### Check Package Registration in ServiceNow

1. **Navigate to Packages**:
   ```
   DevOps > Change > Packages
   ```

2. **Search for Recent Packages**:
   - Filter by package name pattern: `*-dev-*` (for dev environment)
   - Sort by "Created" date descending

3. **Verify Package Details**:
   - **Package Name**: Should match `{service}-{env}-{run-number}.package`
   - **Artifacts**: Click to expand, verify ECR image path
   - **Version**: Should be `{env}-{commit-sha}`
   - **Associated Change Request**: May be linked if change management enabled

### Check GitHub Actions Logs

1. Go to **Actions** tab in GitHub repository
2. Click on latest workflow run
3. Expand any service build job (e.g., "Build frontend")
4. Look for step: **Register Package with ServiceNow**
5. Verify success status

Expected output:
```
Package registered successfully:
- Package: frontend-dev-1234.package
- Artifact: 123456789.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev-abc123
```

## Troubleshooting

### Package Registration Fails

**Symptom**: Step "Register Package with ServiceNow" shows failure

**Common Causes**:

1. **Authentication Failure**
   ```
   Error: 401 Unauthorized
   ```
   - **Fix**: Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD` are correct
   - **Test**: Try logging into ServiceNow UI with same credentials

2. **Invalid Tool ID**
   ```
   Error: Tool not found
   ```
   - **Fix**: Verify `SN_ORCHESTRATION_TOOL_ID` matches GitHub tool sys_id in ServiceNow
   - **Check**: Navigate to DevOps > Orchestration > Tools and copy correct sys_id

3. **Insufficient Permissions**
   ```
   Error: User does not have permission to create packages
   ```
   - **Fix**: Grant `sn_devops.devops_integration_user` role to service account
   - **Check**: User roles in ServiceNow: User Menu > Impersonate User > Check Roles

4. **Invalid JSON in Artifacts**
   ```
   Error: Invalid JSON format
   ```
   - **Fix**: This is a workflow bug - check GitHub Actions logs for malformed JSON
   - **Verify**: The `artifacts` parameter is properly formatted

### Package Registered but Not Visible

**Symptom**: Workflow succeeds but package not visible in ServiceNow

**Solutions**:

1. **Clear Cache**: Reload ServiceNow page with Ctrl+Shift+R
2. **Check Table Access**: Verify user has read access to `sn_devops_package` table
3. **Search by Name**: Use exact package name in search (copy from GitHub logs)
4. **Check Application Scope**: Ensure you're in correct ServiceNow application scope

### Continue on Error

The registration step uses `continue-on-error: true`, meaning:

- ✅ Build will **continue** even if registration fails
- ✅ Image will still be pushed to ECR
- ✅ SBOM will still be generated
- ⚠️ But package won't be tracked in ServiceNow

**Recommendation**: Monitor registration failures and fix authentication/permissions issues.

## Integration with Change Management

### Linking Packages to Change Requests

ServiceNow can automatically link packages to change requests based on:

1. **Change Request Number in Commit Message**:
   ```
   git commit -m "feat: Update frontend UI (CHG0012345)"
   ```

2. **Automated Change Creation**:
   - ServiceNow can create change requests automatically
   - Packages registered during deployment are linked
   - Approvers can see exactly what containers are being deployed

3. **Approval Gates**:
   - Change requests can require approval before deployment
   - Packages provide evidence of what's being deployed
   - Integration with `ServiceNow/servicenow-devops-change` action

## Benefits

### For DevOps Teams

- ✅ **Automated Tracking**: Every container image automatically tracked in ServiceNow
- ✅ **Version History**: Complete history of all deployed artifacts
- ✅ **Traceability**: Link from ServiceNow back to GitHub commit and workflow run

### For Change Management

- ✅ **Visibility**: See exactly what containers are in each deployment
- ✅ **Approval Evidence**: Packages provide concrete evidence for approvers
- ✅ **Audit Trail**: Complete record of what was deployed, when, and by whom

### For Compliance & Security

- ✅ **SBOM Integration**: Each package linked to Software Bill of Materials
- ✅ **Vulnerability Tracking**: Trivy scan results available for each package
- ✅ **Compliance**: Meets requirements for software asset management

## Related Documentation

- [ServiceNow DevOps Integration](./GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [Build and Push Workflow](../.github/workflows/build-images.yaml)
- [ServiceNow Register Package Action](https://github.com/ServiceNow/servicenow-devops-register-package)
- [Docker Image Build Process](./ONBOARDING.md#docker-operations)

## Example: Complete Registration Lifecycle

### 1. Developer Commits Code

```bash
git add src/frontend/
git commit -m "feat: Add new product search feature"
git push origin main
```

### 2. GitHub Actions Workflow Triggers

```
✅ Detect changed services → frontend
✅ Build Docker image → frontend:dev-abc123
✅ Run Trivy scan → 2 medium vulnerabilities
✅ Push to ECR → 123456789.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev-abc123
✅ Generate SBOM → sbom-frontend.json
✅ Register with ServiceNow → frontend-dev-1234.package
```

### 3. ServiceNow Creates Package Record

```
Package: frontend-dev-1234.package
Created: 2025-10-27 14:30:00
Artifact:
  - Name: 123456789.dkr.ecr.eu-west-2.amazonaws.com/frontend
  - Version: dev-abc123def456
  - Semantic Version: dev-1234
  - Repository: Freundcloud/microservices-demo
  - Built by: github-actions[bot]
  - Commit: abc123def456 ("feat: Add new product search feature")
```

### 4. Change Request Links Package

If change management is enabled:

```
Change Request: CHG0012345
Title: Deploy Frontend Product Search Feature
State: Pending Approval
Packages:
  - frontend-dev-1234.package ✅
    Vulnerabilities: 2 medium (acceptable)
    SBOM: Available
    Tests: Passed
```

### 5. Deployment to Production

When deployed to prod:

```
✅ Build frontend for prod → frontend:prod-5.2.1
✅ Register → frontend-prod-5678.package
✅ Link to change request CHG0012345
✅ Approver reviews package details
✅ Change approved and deployed
```

## Future Enhancements

Potential improvements to this integration:

1. **Package Grouping**: Register all 12 services as single deployment package
2. **Vulnerability Linking**: Attach Trivy scan results to package record
3. **SBOM Upload**: Upload full SBOM to ServiceNow attachments
4. **Deployment Status**: Update package status after successful deployment
5. **Rollback Tracking**: Mark packages when rolled back
6. **Multi-Environment**: Link dev/qa/prod packages together

---

**Last Updated**: 2025-10-27
**Maintained By**: DevOps Team
