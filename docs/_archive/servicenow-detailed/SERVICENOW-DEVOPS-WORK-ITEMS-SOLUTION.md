# ServiceNow DevOps Work Items Integration - Complete Solution

> **Critical**: How to make work items appear in DevOps Change workspace
> **Last Updated**: 2025-10-20
> **Version**: 1.0.0

## Problem Statement

**Issue**: Work items (commits, PRs, issues) are not appearing in the ServiceNow DevOps Change workspace at:
`https://calitiiltddemo3.service-now.com/now/devops-change/`

**Root Cause**: We're missing the complete DevOps integration chain:
1. ❌ Not using official ServiceNow DevOps GitHub Actions
2. ❌ Not registering artifacts
3. ❌ Not registering packages
4. ❌ GitHub tool not properly registered
5. ❌ Application not properly configured

---

## Understanding Work Item Visibility

### What Are "Work Items" in ServiceNow DevOps?

Work items are:
- **GitHub Issues** (planning tool)
- **Git Commits** (code changes)
- **Pull Requests** (code reviews)
- **Build Artifacts** (deployable assets)
- **Packages** (grouped artifacts)

### How Work Items Flow

```
GitHub Issue → Commit → PR → Build → Artifact → Package → Change → Deployment
     ↓           ↓       ↓      ↓        ↓          ↓        ↓         ↓
ServiceNow DevOps automatically links all of these together
```

### Why They Don't Appear Currently

**Current Approach (Wrong)**:
```yaml
# Direct API call to change_request table
curl -X POST .../api/now/table/change_request
```

**Result**: ❌ Creates change but NO work item linkage

**Required Approach (Correct)**:
```yaml
# Use official ServiceNow DevOps GitHub Actions
- uses: ServiceNow/servicenow-devops-change@v4
- uses: ServiceNow/servicenow-devops-register-artifact@v3
- uses: ServiceNow/servicenow-devops-register-package@v3
```

**Result**: ✅ Creates change WITH work item linkage

---

## Complete Solution Architecture

### Step 1: Register GitHub Tool in ServiceNow

**Why**: DevOps Change Velocity needs to know about your GitHub instance

**How**:

#### Option A: Via UI (Easiest)

1. **Navigate to**: `https://calitiiltddemo3.service-now.com/now/devops-change/`
2. **Click**: "Connect Tools" or "Add Tool"
3. **Select**: "GitHub" as tool type
4. **Configure**:
   - **Tool Name**: `GitHubARC`
   - **Tool Type**: `Orchestration`
   - **URL**: `https://github.com`
   - **API URL**: `https://api.github.com`
   - **Authentication**: Token
   - **Token**: Your GitHub Personal Access Token with these scopes:
     - `repo` (full control of private repositories)
     - `workflow` (update GitHub Action workflows)
     - `write:packages` (upload packages to GitHub Package Registry)
     - `admin:repo_hook` (read and write repository hooks)

5. **Save** and copy the **sys_id** - This is your `SN_ORCHESTRATION_TOOL_ID`

#### Option B: Via API

```bash
# Create GitHub tool programmatically
BASIC_AUTH=$(echo -n "github_integration:PASSWORD" | base64)
GITHUB_PAT="ghp_your_github_personal_access_token"

TOOL_PAYLOAD=$(jq -n \
  --arg name "GitHubARC" \
  --arg url "https://api.github.com" \
  --arg token "$GITHUB_PAT" \
  '{
    "name": $name,
    "type": "orchestration",
    "url": $url,
    "token": $token
  }'
)

# Create tool (API endpoint depends on your ServiceNow version)
curl -X POST \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d "$TOOL_PAYLOAD" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/tool"
```

---

### Step 2: Register Application in ServiceNow

**Why**: Groups planning, coding, and orchestration tools together

**How**:

1. **Navigate to**: DevOps Change > Applications (or Configuration > Applications)
2. **Click**: "New"
3. **Configure**:
   - **Name**: `Online Boutique`
   - **Description**: `Microservices demo application`
   - **Planning Tool**: GitHub (for Issues) - Select your GitHubARC tool
   - **Coding Tool**: GitHub (for Commits/PRs) - Select your GitHubARC tool
   - **Orchestration Tool**: GitHub (for Actions) - Select your GitHubARC tool
   - **Repository**: `olafkfreund/microservices-demo`

4. **Save** and note the application sys_id

---

### Step 3: Configure GitHub Secrets

Add these to your GitHub repository:

**Settings > Secrets and variables > Actions > New repository secret**

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `SN_DEVOPS_INTEGRATION_TOKEN` | OAuth token | ServiceNow > System OAuth > Application Registry > Create OAuth API endpoint |
| `SN_INSTANCE_URL` | `https://calitiiltddemo3.service-now.com` | Your instance URL |
| `SN_ORCHESTRATION_TOOL_ID` | `abc123...` | From Step 1 (sys_id of GitHub tool) |

**Creating OAuth Token**:
```
1. In ServiceNow: System OAuth > Application Registry
2. Click "New" > Create an OAuth API endpoint for external clients
3. Name: "GitHub Actions Integration"
4. Client ID: (auto-generated)
5. Client Secret: (auto-generated) ← This is your SN_DEVOPS_INTEGRATION_TOKEN
6. Accessible from: All application scopes
7. Grant type: Client Credentials
8. Submit
```

---

### Step 4: Create New DevOps-Integrated Workflow

**File**: `.github/workflows/deploy-with-servicenow-devops.yaml`

This is a NEW workflow that uses official ServiceNow DevOps actions:

```yaml
name: Deploy with ServiceNow DevOps Integration

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - qa
          - prod

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices

jobs:
  # Job 1: Security Scans (existing)
  security-scans:
    name: Run Security Scans
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Security Scans
        run: |
          echo "Running security scans..."
          # Your existing security scan logic

  # Job 2: Create Change Request (NEW - Using DevOps Action)
  create-change:
    name: Create DevOps Change Request
    runs-on: ubuntu-latest
    needs: security-scans
    outputs:
      change-request-number: ${{ steps.create-change.outputs.change-request-number }}
      change-request-sys-id: ${{ steps.create-change.outputs.change-request-sys-id }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Create Change Request
        id: create-change
        uses: ServiceNow/servicenow-devops-change@v4
        with:
          # Authentication
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

          # GitHub context (critical for work item linking)
          context-github: ${{ toJSON(github) }}

          # Job identification
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'

          # Change request details
          change-request: |
            {
              "autoCloseChange": true,
              "attributes": {
                "short_description": "Deploy Online Boutique to ${{ github.event.inputs.environment }}",
                "description": "Automated deployment via GitHub Actions DevOps integration",
                "assignment_group": "Change Management",
                "implementation_plan": "1. Security scans\n2. Build artifacts\n3. Deploy to EKS\n4. Verify health",
                "backout_plan": "kubectl rollout undo deployment -n microservices-${{ github.event.inputs.environment }}",
                "test_plan": "1. Security scans\n2. Pod health checks\n3. Service endpoints\n4. Istio metrics",
                "type": "normal",
                "risk": "${{ github.event.inputs.environment == 'prod' && 'moderate' || 'low' }}",
                "priority": "${{ github.event.inputs.environment == 'prod' && '2' || '3' }}"
              }
            }

      - name: Display Change Info
        run: |
          echo "✅ Change Request Created"
          echo "Number: ${{ steps.create-change.outputs.change-request-number }}"
          echo "Sys ID: ${{ steps.create-change.outputs.change-request-sys-id }}"
          echo "URL: ${{ secrets.SN_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=${{ steps.create-change.outputs.change-request-sys-id }}"

  # Job 3: Build Artifacts
  build-artifacts:
    name: Build Container Images
    runs-on: ubuntu-latest
    needs: create-change
    outputs:
      image-tags: ${{ steps.build.outputs.tags }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build images
        id: build
        run: |
          # Build your images
          echo "Building images..."
          # Example: docker build -t frontend:${{ github.sha }} src/frontend/
          # Push to ECR
          echo "tags=${{ github.sha }}" >> $GITHUB_OUTPUT

  # Job 4: Register Artifacts (NEW - Critical for work item visibility)
  register-artifacts:
    name: Register Deployment Artifacts
    runs-on: ubuntu-latest
    needs: [create-change, build-artifacts]

    steps:
      - name: Register Artifacts in ServiceNow
        uses: ServiceNow/servicenow-devops-register-artifact@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          artifacts: |
            [
              {
                "name": "frontend",
                "version": "${{ github.sha }}",
                "semanticVersion": "1.0.${{ github.run_number }}",
                "repositoryName": "${{ github.repository }}"
              },
              {
                "name": "cartservice",
                "version": "${{ github.sha }}",
                "semanticVersion": "1.0.${{ github.run_number }}",
                "repositoryName": "${{ github.repository }}"
              },
              {
                "name": "productcatalogservice",
                "version": "${{ github.sha }}",
                "semanticVersion": "1.0.${{ github.run_number }}",
                "repositoryName": "${{ github.repository }}"
              }
            ]

  # Job 5: Register Package (NEW - Groups artifacts together)
  register-package:
    name: Register Deployment Package
    runs-on: ubuntu-latest
    needs: register-artifacts

    steps:
      - name: Register Package in ServiceNow
        uses: ServiceNow/servicenow-devops-register-package@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          artifacts: |
            [
              {
                "name": "frontend",
                "version": "${{ github.sha }}",
                "semanticVersion": "1.0.${{ github.run_number }}",
                "repositoryName": "${{ github.repository }}"
              },
              {
                "name": "cartservice",
                "version": "${{ github.sha }}",
                "semanticVersion": "1.0.${{ github.run_number }}",
                "repositoryName": "${{ github.repository }}"
              }
            ]
          package-name: "online-boutique-${{ github.event.inputs.environment }}-${{ github.run_number }}"

  # Job 6: Deploy
  deploy:
    name: Deploy to ${{ github.event.inputs.environment }}
    runs-on: ubuntu-latest
    needs: [create-change, register-package]
    environment:
      name: ${{ github.event.inputs.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy
        run: |
          kubectl apply -k kustomize/overlays/${{ github.event.inputs.environment }}

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/frontend -n microservices-${{ github.event.inputs.environment }}
          kubectl get pods -n microservices-${{ github.event.inputs.environment }}

  # Job 7: Update Change Status (NEW - Using DevOps Action)
  update-change:
    name: Update Change Request Status
    runs-on: ubuntu-latest
    needs: [create-change, deploy]
    if: always()

    steps:
      - name: Update Change Request
        uses: ServiceNow/servicenow-devops-update-change@v3
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          change-request-number: ${{ needs.create-change.outputs.change-request-number }}
          change-request-details: |
            {
              "state": "${{ needs.deploy.result == 'success' && '3' || '4' }}",
              "close_code": "${{ needs.deploy.result == 'success' && 'successful' || 'unsuccessful' }}",
              "work_notes": "Deployment ${{ needs.deploy.result }} to ${{ github.event.inputs.environment }}\nWorkflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
```

---

## Why This Works

### The Complete Chain

**1. Tool Registration**:
- ServiceNow knows about your GitHub instance
- Can authenticate and make API calls
- Links all GitHub activity to ServiceNow

**2. Application Registration**:
- Groups all tools together
- Enables cross-tool traceability
- Maps DevOps activity to business services

**3. Official Actions**:
- `servicenow-devops-change` creates change WITH work item context
- `servicenow-devops-register-artifact` registers build outputs
- `servicenow-devops-register-package` groups artifacts
- `servicenow-devops-update-change` updates status

**4. Context Passing**:
```yaml
context-github: ${{ toJSON(github) }}
```
This passes ALL GitHub context:
- Repository, branch, commit SHA
- Author, committer
- PR number, title, reviewers
- Workflow run ID, attempt
- Event type, trigger

**5. Work Item Linking**:
ServiceNow automatically links:
- Commits mentioned in PR
- Issues mentioned in commits (e.g., "Fixes #123")
- PRs to changes
- Artifacts to changes
- Packages to deployments

---

## Verification Steps

### 1. Check Tool Registration

```bash
# Via API
curl -s -H "Authorization: Basic $BASIC_AUTH" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/v1/devops/tool?name=GitHubARC" \
  | jq .
```

**Expected**: Tool record with sys_id

### 2. Check Application Registration

Navigate to:
```
https://calitiiltddemo3.service-now.com/now/devops-change/
```

**Expected**: "Online Boutique" application visible

### 3. Test Workflow

```bash
gh workflow run deploy-with-servicenow-devops.yaml -f environment=dev
```

### 4. Verify in DevOps Workspace

Navigate to:
```
https://calitiiltddemo3.service-now.com/now/devops-change/
```

**Expected to see**:
- ✅ Change request
- ✅ Linked to workflow run
- ✅ Artifacts registered
- ✅ Package registered
- ✅ Commits visible
- ✅ PR information (if applicable)
- ✅ GitHub Issues linked (if referenced in commits)

---

## Troubleshooting

### Issue: "Tool ID not found"

**Fix**: Verify tool sys_id is correct in secrets

### Issue: "Authentication failed"

**Fix**:
1. Check SN_DEVOPS_INTEGRATION_TOKEN is correct
2. Verify OAuth application in ServiceNow
3. Check token hasn't expired

### Issue: "No work items visible"

**Possible causes**:
1. Tool not properly registered → Re-register
2. Application not configured → Create application
3. Not using DevOps actions → Update workflow
4. Missing context-github → Add `context-github: ${{ toJSON(github) }}`

### Issue: "Artifacts not registered"

**Fix**:
1. Check `servicenow-devops-register-artifact` step ran
2. Verify artifact JSON format
3. Check tool-id is correct

---

## Migration Path

### Phase 1: Test in Parallel

Keep existing workflow, add new DevOps workflow:
- `.github/workflows/deploy-with-servicenow-basic.yaml` (existing)
- `.github/workflows/deploy-with-servicenow-devops.yaml` (new)

Test new workflow in dev first.

### Phase 2: Compare Results

Run both workflows side-by-side:
- Old: Creates change, no work items
- New: Creates change WITH work items

Verify DevOps workspace shows work items.

### Phase 3: Full Migration

Once verified:
1. Archive old workflow
2. Rename new workflow
3. Update documentation

---

## Summary

**Root Cause**: Not using ServiceNow DevOps API/actions

**Solution**:
1. ✅ Register GitHub tool (get sys_id)
2. ✅ Register application
3. ✅ Configure secrets
4. ✅ Create new workflow using official actions
5. ✅ Register artifacts
6. ✅ Register packages
7. ✅ Pass GitHub context

**Result**: Complete work item visibility in DevOps Change workspace!

---

**Next**: Implement this new workflow and test in dev environment.
