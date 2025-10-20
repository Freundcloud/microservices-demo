# ServiceNow DevOps Change Velocity Setup Guide

> **Status**: 🔧 Configuration Required
> **Last Updated**: 2025-10-20
> **Version**: 1.0.0

## Problem Statement

**Issue**: Changes created via GitHub Actions are not appearing in the ServiceNow DevOps Change workspace at:
`https://calitiiltddemo3.service-now.com/now/devops-change/`

**Root Cause**: The GitHub Actions workflow is using the **Table API** (`/api/now/table/change_request`) to create changes, but the **DevOps Change Velocity** workspace requires changes to be created through the **DevOps-specific APIs** and requires proper tool registration.

---

## Understanding the Two Approaches

### Current Approach: Table API (Basic Integration) ❌

**What we're doing**:
```yaml
curl -X POST \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request" \
  -d '{"short_description": "...", "description": "..."}'
```

**Result**:
- ✅ Creates change requests in ServiceNow
- ✅ Appears in standard Change Management module
- ✅ Works with approval workflows
- ❌ **Does NOT appear in DevOps Change workspace**
- ❌ No integration with DevOps Change Velocity features
- ❌ No DORA metrics tracking
- ❌ No pipeline/workflow visualization

**Where it appears**:
- `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/change_request_list.do`

---

### Required Approach: DevOps Change API (Full Integration) ✅

**What we need to do**:
```yaml
# Use ServiceNow DevOps GitHub Action
- uses: ServiceNow/servicenow-devops-change@v4
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Deploy'
    change-request: '{
      "setCloseCode": false,
      "attributes": {
        "short_description": "Deployment via GitHub Actions",
        "description": "..."
      }
    }'
```

**Result**:
- ✅ Creates change requests via DevOps API
- ✅ Appears in DevOps Change workspace
- ✅ Full DevOps Change Velocity integration
- ✅ DORA metrics tracked automatically
- ✅ Pipeline visualization
- ✅ Deployment gates support
- ✅ Automatic test result registration
- ✅ Work item linking

**Where it appears**:
- `https://calitiiltddemo3.service-now.com/now/devops-change/` ✅
- Change Management module (also)

---

## Prerequisites

Before setting up DevOps Change Velocity integration, verify:

### 1. DevOps Change Velocity Plugin Installed

**Check if installed**:
1. Navigate to: `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/v_plugin.do`
2. Search for: `DevOps Change Velocity` or plugin ID `com.snc.devops.change.velocity`
3. Verify status: **Active**

**If not installed**:
1. Go to: System Applications > All Available Applications > All
2. Search: "DevOps Change Velocity"
3. Click **Install** (requires admin rights)
4. Wait 10-30 minutes for installation

**Plugin Details**:
- **Name**: DevOps Change Velocity
- **ID**: `com.snc.devops.change.velocity`
- **Store Link**: https://store.servicenow.com/store/app/1b2aabe21b246a50a85b16db234bcbe1
- **Version**: Check compatibility with your instance version

### 2. Required Roles

**Integration User Needs**:
- `sn_devops.integration_user` - DevOps integration role
- `change_manager` - Change management role (optional, for approval)

**Verify roles**:
```bash
# Check user roles
curl -s -H "Authorization: Basic $BASIC_AUTH" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration&sysparm_fields=role.name" \
  | jq '.result[] | .role.name'
```

### 3. GitHub Tool Registration

**This is the missing piece!** You need to register GitHub as an orchestration tool in ServiceNow.

---

## Setup Steps

### Step 1: Register GitHub Tool in ServiceNow

#### Option A: Via DevOps Change Workspace (Recommended)

1. **Navigate to DevOps Change workspace**:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/
   ```

2. **Click "Connect Tools"** in the getting started section

3. **Select "GitHub"** as orchestration tool

4. **Configure GitHub tool**:
   - **Tool Name**: `GitHubARC` (or any descriptive name)
   - **Tool Type**: Orchestration
   - **API URL**: `https://api.github.com`
   - **Authentication**: Token-based
   - **Token**: GitHub Personal Access Token (PAT)

5. **Save and note the sys_id** - This will be your `SN_ORCHESTRATION_TOOL_ID`

#### Option B: Via API (Programmatic)

```bash
# Create GitHub orchestration tool
BASIC_AUTH=$(echo -n "github_integration:PASSWORD" | base64)

TOOL_PAYLOAD=$(jq -n \
  --arg name "GitHubARC" \
  --arg type "orchestration" \
  --arg url "https://api.github.com" \
  --arg token "$GITHUB_TOKEN" \
  '{
    "name": $name,
    "type": $type,
    "url": $url,
    "token": $token
  }'
)

# Create tool (exact API endpoint depends on DevOps Change Velocity version)
RESPONSE=$(curl -X POST \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d "$TOOL_PAYLOAD" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/tool/orchestration")

# Extract sys_id
TOOL_SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')
echo "SN_ORCHESTRATION_TOOL_ID=$TOOL_SYS_ID"
```

#### Option C: Via ServiceNow UI (Classic)

1. **Navigate to**: All > DevOps Change > Tools
2. **Click "New"**
3. **Fill in details**:
   - Name: GitHubARC
   - Type: Orchestration
   - URL: https://api.github.com
   - Integration Token: (GitHub PAT)
4. **Submit**
5. **Copy sys_id** from the URL or record

### Step 2: Register Application in ServiceNow

**Why**: DevOps Change Velocity requires an "application" that groups tools together (planning, coding, orchestration).

1. **Navigate to**: DevOps Change > Applications
2. **Click "New"**
3. **Configure application**:
   - **Name**: `Online Boutique`
   - **Description**: `Microservices demo application`
   - **Orchestration Tool**: Select your GitHub tool
   - **Code Tool**: Select GitHub (same tool or separate)
   - **Planning Tool**: Select GitHub Issues (optional)

4. **Save** and note the application sys_id

### Step 3: Configure GitHub Secrets

Add these secrets to your GitHub repository:

**Settings > Secrets and variables > Actions > New repository secret**

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `SN_DEVOPS_INTEGRATION_TOKEN` | ServiceNow integration token | From ServiceNow: System OAuth > Application Registry |
| `SN_INSTANCE_URL` | `https://calitiiltddemo3.service-now.com` | Your instance URL |
| `SN_ORCHESTRATION_TOOL_ID` | `abc123...` (sys_id) | From Step 1 tool registration |

**Creating Integration Token**:
```bash
# In ServiceNow, navigate to:
# System OAuth > Application Registry
# Create new OAuth API endpoint for external clients
# Grant type: Client Credentials
# Note the Client ID and Client Secret
# Use Client Secret as SN_DEVOPS_INTEGRATION_TOKEN
```

### Step 4: Update GitHub Actions Workflow

Replace the current Table API approach with the DevOps Change GitHub Action:

**Before** (current approach):
```yaml
- name: Create Change Request
  run: |
    curl -X POST \
      -H "Authorization: Basic $BASIC_AUTH" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request"
```

**After** (DevOps approach):
```yaml
- name: Create DevOps Change Request
  uses: ServiceNow/servicenow-devops-change@v4
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Deploy to ${{ github.event.inputs.environment }}'
    change-request: |
      {
        "setCloseCode": false,
        "autoCloseChange": true,
        "attributes": {
          "short_description": "Deploy microservices to ${{ github.event.inputs.environment }}",
          "description": "Automated deployment via GitHub Actions for Online Boutique application",
          "assignment_group": "Change Management",
          "implementation_plan": "Deploy using Kustomize overlays to Kubernetes",
          "backout_plan": "Rollback using kubectl rollout undo",
          "test_plan": "Security scans and health checks",
          "type": "normal",
          "risk": "${{ github.event.inputs.environment == 'prod' && 'moderate' || 'low' }}",
          "impact": "${{ github.event.inputs.environment == 'prod' && '2' || '3' }}"
        }
      }
  id: create-change

- name: Get Change Request Number
  run: |
    echo "CHANGE_NUMBER=${{ steps.create-change.outputs.change-request-number }}"
    echo "CHANGE_SYS_ID=${{ steps.create-change.outputs.change-request-sys-id }}"
```

---

## Enhanced Workflow with DevOps Change

### Complete Example

```yaml
name: Deploy with ServiceNow DevOps Change
on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, qa, prod]

jobs:
  create-devops-change:
    name: Create DevOps Change Request
    runs-on: ubuntu-latest
    outputs:
      change-request-number: ${{ steps.create.outputs.change-request-number }}
      change-request-sys-id: ${{ steps.create.outputs.change-request-sys-id }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Create Change Request
        id: create
        uses: ServiceNow/servicenow-devops-change@v4
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          change-request: |
            {
              "autoCloseChange": true,
              "attributes": {
                "short_description": "Deploy Online Boutique to ${{ github.event.inputs.environment }}",
                "type": "normal",
                "risk": "${{ github.event.inputs.environment == 'prod' && 'moderate' || 'low' }}",
                "implementation_plan": "Deploy microservices using Kustomize"
              }
            }

      - name: Display Change Info
        run: |
          echo "✅ Change Request Created: ${{ steps.create.outputs.change-request-number }}"
          echo "   Sys ID: ${{ steps.create.outputs.change-request-sys-id }}"
          echo "   URL: ${{ secrets.SN_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=${{ steps.create.outputs.change-request-sys-id }}"

  register-artifact:
    name: Register Deployment Artifact
    needs: create-devops-change
    runs-on: ubuntu-latest

    steps:
      - name: Register Artifact
        uses: ServiceNow/servicenow-devops-register-artifact@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          artifacts: |
            [{
              "name": "frontend",
              "version": "${{ github.sha }}",
              "semanticVersion": "1.0.${{ github.run_number }}",
              "repositoryName": "${{ github.repository }}"
            }]

  register-package:
    name: Register Deployment Package
    needs: register-artifact
    runs-on: ubuntu-latest

    steps:
      - name: Register Package
        uses: ServiceNow/servicenow-devops-register-package@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          artifacts: |
            [{
              "name": "frontend",
              "version": "${{ github.sha }}",
              "semanticVersion": "1.0.${{ github.run_number }}",
              "repositoryName": "${{ github.repository }}"
            }]
          package-name: "online-boutique-${{ github.event.inputs.environment }}"

  deploy:
    name: Deploy Application
    needs: create-devops-change
    runs-on: ubuntu-latest

    steps:
      - name: Deploy to Kubernetes
        run: |
          kubectl apply -k kustomize/overlays/${{ github.event.inputs.environment }}

      - name: Update Change Request
        uses: ServiceNow/servicenow-devops-update-change@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          change-request-number: ${{ needs.create-devops-change.outputs.change-request-number }}
          change-request-details: |
            {
              "state": "implement",
              "work_notes": "Deployment completed successfully to ${{ github.event.inputs.environment }}"
            }
```

---

## Verification Steps

### 1. Verify Tool Registration

```bash
# Check if GitHub tool exists
PASSWORD='your-password'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)

curl -s -H "Authorization: Basic $BASIC_AUTH" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/tool?sysparm_query=name=GitHubARC" \
  | jq .
```

**Expected output**:
```json
{
  "result": [
    {
      "sys_id": "abc123...",
      "name": "GitHubARC",
      "type": "orchestration",
      "url": "https://api.github.com"
    }
  ]
}
```

### 2. Verify Application Registration

Navigate to:
```
https://calitiiltddemo3.service-now.com/now/devops-change/
```

You should see:
- ✅ "Online Boutique" application listed
- ✅ GitHub tool connected
- ✅ Status: Active

### 3. Test Change Creation

Run the updated workflow:
```bash
gh workflow run deploy-with-servicenow-devops.yaml -f environment=dev
```

Check DevOps Change workspace:
```
https://calitiiltddemo3.service-now.com/now/devops-change/
```

You should see:
- ✅ Change request appears in workspace
- ✅ Linked to GitHub workflow
- ✅ Pipeline visualization
- ✅ DORA metrics tracking

---

## Troubleshooting

### Issue: "Tool ID not found"

**Symptom**:
```
Error: Unable to find tool with sys_id: abc123...
```

**Solution**:
1. Verify tool sys_id is correct
2. Check tool is active in ServiceNow
3. Verify integration user has access to tool

### Issue: "Authentication failed"

**Symptom**:
```
Error: Authentication failed for instance
```

**Solution**:
1. Verify `SN_DEVOPS_INTEGRATION_TOKEN` is correct
2. Check token hasn't expired
3. Verify OAuth application registry configuration
4. Test token manually:
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     "$INSTANCE_URL/api/sn_devops/v1/devops/tool"
   ```

### Issue: "Changes not appearing in DevOps workspace"

**Symptom**:
- Changes created successfully
- Appear in Change Management
- Don't appear in DevOps Change workspace

**Root Cause**:
- Using Table API instead of DevOps Change API
- Tool not registered
- Application not configured

**Solution**:
1. Complete Steps 1-4 above
2. Use `ServiceNow/servicenow-devops-change@v4` action
3. Verify tool and application registration

### Issue: "DevOps Change Velocity not installed"

**Symptom**:
```
Error: API endpoint not found: /api/sn_devops/
```

**Solution**:
1. Install DevOps Change Velocity plugin
2. Wait for installation to complete (10-30 min)
3. Verify plugin is active
4. Restart workflow

---

## Benefits of DevOps Change Integration

### Before (Table API)

- ❌ Manual change tracking
- ❌ No pipeline visibility
- ❌ No DORA metrics
- ❌ Manual artifact registration
- ❌ No test result integration
- ❌ Basic work notes only

### After (DevOps Change API)

- ✅ **Automatic change tracking** - Changes linked to pipelines
- ✅ **Pipeline visualization** - See deployment flow in ServiceNow
- ✅ **DORA metrics** - Deployment frequency, lead time, change failure rate
- ✅ **Artifact tracking** - Automatic artifact and package registration
- ✅ **Test results** - Security scans and test results automatically registered
- ✅ **Rich metadata** - Complete GitHub context, commits, PRs, issues
- ✅ **Deployment gates** - Block deployments pending approval
- ✅ **Work item linking** - Automatic linking of issues, commits, PRs

---

## Migration Path

### Phase 1: Dual Mode (Recommended)

Keep both approaches temporarily:

```yaml
jobs:
  # New DevOps approach
  create-devops-change:
    uses: ServiceNow/servicenow-devops-change@v4
    # ... configuration ...

  # Legacy Table API (for comparison)
  create-table-change:
    run: |
      curl -X POST .../change_request
      # ... existing logic ...
```

**Benefits**:
- Compare both approaches
- Verify DevOps changes appear correctly
- Rollback if needed

### Phase 2: Full Migration

Once verified DevOps changes work:

1. Remove Table API job
2. Update all workflows to use DevOps actions
3. Archive legacy workflow
4. Update documentation

### Phase 3: Enhanced Features

Add advanced DevOps features:

1. Artifact registration
2. Package tracking
3. Test result publishing
4. Deployment gates
5. Automated rollback

---

## API Comparison

### Table API vs DevOps Change API

| Feature | Table API | DevOps Change API |
|---------|-----------|------------------|
| Endpoint | `/api/now/table/change_request` | `/api/sn_devops/v1/devops/change` |
| Authentication | Basic Auth | OAuth Token |
| DevOps Workspace | ❌ No | ✅ Yes |
| DORA Metrics | ❌ No | ✅ Yes |
| Pipeline Linking | ❌ Manual | ✅ Automatic |
| Artifact Tracking | ❌ No | ✅ Yes |
| Test Results | ❌ Manual | ✅ Automatic |
| Work Item Linking | ❌ Manual | ✅ Automatic |
| Deployment Gates | ❌ No | ✅ Yes |
| GitHub Action | ❌ No | ✅ Yes |

---

## Next Steps

### Immediate Actions

1. ✅ **Verify DevOps Change Velocity is installed**
2. ✅ **Register GitHub orchestration tool**
3. ✅ **Create application registration**
4. ✅ **Configure GitHub secrets**
5. ✅ **Update workflow to use DevOps actions**

### Testing

6. ✅ **Test in dev environment**
7. ✅ **Verify change appears in DevOps workspace**
8. ✅ **Check DORA metrics tracking**
9. ✅ **Validate pipeline visualization**

### Rollout

10. ✅ **Deploy to qa environment**
11. ✅ **Deploy to prod environment**
12. ✅ **Archive legacy workflow**
13. ✅ **Update documentation**

---

## Related Documentation

- **[Work Item Association Guide](GITHUB-SERVICENOW-WORK-ITEM-ASSOCIATION.md)** - GitHub-ServiceNow linking
- **[Approval Criteria](GITHUB-SERVICENOW-APPROVAL-CRITERIA.md)** - Risk-based approvals
- **[Compliance Gap Analysis](COMPLIANCE-GAP-ANALYSIS.md)** - SOC 2 & ISO 27001
- **[Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)** - Complete setup

---

## Support Resources

- **ServiceNow DevOps Community**: https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps
- **GitHub Actions Marketplace**: https://github.com/marketplace?type=actions&query=servicenow+devops
- **ServiceNow Store**: https://store.servicenow.com/store/app/1b2aabe21b246a50a85b16db234bcbe1
- **Official Documentation**: https://www.servicenow.com/docs/bundle/yokohama-it-service-management/page/product/enterprise-dev-ops/concept/github-integration-dev-ops.html

---

**Questions?** This is the missing piece to get your changes visible in the DevOps Change workspace!
