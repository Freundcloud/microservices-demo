# GitHub + ServiceNow Integration - Comprehensive Guide

**Last Updated**: 2025-10-20
**Version**: 2.0
**ServiceNow Instance**: https://calitiiltddemo3.service-now.com
**DevOps Change Velocity**: v6.1.0

---

## Table of Contents

1. [Introduction](#introduction)
2. [Integration Architecture](#integration-architecture)
3. [Authentication Methods](#authentication-methods)
4. [Integration Approaches](#integration-approaches)
5. [Implementation Examples](#implementation-examples)
6. [Best Practices](#best-practices)
7. [Common Pitfalls & Antipatterns](#common-pitfalls--antipatterns)
8. [Troubleshooting](#troubleshooting)
9. [Migration Path](#migration-path)

---

## Introduction

### What is ServiceNow DevOps Change?

ServiceNow DevOps Change Velocity is a modern change management solution that integrates directly with CI/CD pipelines. It provides:

- **Automated Change Requests**: Create changes automatically from GitHub Actions
- **DevOps Workspace**: Modern UI for tracking deployments and DORA metrics
- **Approval Gates**: Pause deployments until approvals are granted
- **Pipeline Visibility**: See GitHub Actions runs directly in ServiceNow
- **DORA Metrics**: Track deployment frequency, lead time, MTTR, and change failure rate

### Why Integrate GitHub with ServiceNow?

**For Compliance**:
- Complete audit trail of all deployments
- Multi-level approval for production changes
- Automated change documentation

**For Operations**:
- Single pane of glass for all changes
- Automated CMDB updates
- Impact analysis before deployments

**For Development Teams**:
- Automated approvals for dev environments
- Clear visibility into approval status
- Reduced manual overhead

---

## Integration Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│  ┌────────────────────────────────────────────────────┐     │
│  │           GitHub Actions Workflows                  │     │
│  │  • Build & Test                                     │     │
│  │  • Security Scanning                                │     │
│  │  • Deploy to EKS                                    │     │
│  └────────────┬──────────────┬────────────────────────┘     │
└───────────────┼──────────────┼──────────────────────────────┘
                │              │
        ┌───────▼──────┐   ┌──▼──────────────────────┐
        │   REST API   │   │ ServiceNow DevOps       │
        │  (Standard)  │   │ GitHub Action           │
        │              │   │ (servicenow-devops-     │
        │              │   │  change@v6.1.0)         │
        └───────┬──────┘   └──┬──────────────────────┘
                │              │
                │              │ Requires IntegrationHub
                │              │ plugins + OAuth token
                │              │
                └──────┬───────┘
                       │
┌──────────────────────▼────────────────────────────────────────┐
│                  ServiceNow Platform                          │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         Change Request (change_request table)        │    │
│  │  • Standard ITSM change management                   │    │
│  │  • Approval workflows                                │    │
│  │  • State transitions                                 │    │
│  │  • Audit trail                                       │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │      DevOps Change (sn_devops_change table)          │    │
│  │  • Pipeline tracking                                 │    │
│  │  • DORA metrics                                      │    │
│  │  • Modern workspace UI                               │    │
│  │  • AI risk insights                                  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              CMDB (Business Applications)            │    │
│  │  • Service dependencies                              │    │
│  │  • Impact analysis                                   │    │
│  │  • Configuration items                               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Data Flow: GitHub Actions → ServiceNow

**Option 1: REST API (Works Everywhere)**
```
GitHub Workflow
    ↓
curl with Basic Auth
    ↓
ServiceNow REST API (/api/now/table/change_request)
    ↓
Change Request Created
    ↓
Manual or workflow-based approval
    ↓
GitHub polls for approval status
    ↓
Deployment continues
```

**Option 2: ServiceNow DevOps Action (Requires IntegrationHub)**
```
GitHub Workflow
    ↓
servicenow-devops-change@v6.1.0
    ↓
OAuth Token Authentication
    ↓
DevOps Change Control API
    ↓
Creates both:
  - Change Request (change_request)
  - DevOps Change (sn_devops_change)
    ↓
Automatic correlation with pipeline
    ↓
Visible in DevOps Workspace
    ↓
Action polls for approval
    ↓
Deployment continues
```

---

## Authentication Methods

### Method 1: Basic Authentication (REST API)

**Pros**:
- Simple to set up
- Works with all ServiceNow instances
- No plugin dependencies
- Easy to troubleshoot

**Cons**:
- Less secure (username/password in secrets)
- No automatic DevOps workspace visibility
- Manual correlation ID management

**Setup**:
```yaml
# GitHub Secrets Required
SERVICENOW_INSTANCE_URL: https://your-instance.service-now.com
SERVICENOW_USERNAME: integration_user
SERVICENOW_PASSWORD: secure_password

# In workflow
- name: Create Change Request
  run: |
    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

    curl -X POST \
      -H "Authorization: Basic $BASIC_AUTH" \
      -H "Content-Type: application/json" \
      -d '{"short_description": "Deploy to production"}' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request"
```

### Method 2: OAuth Token (DevOps Action)

**Pros**:
- More secure (token-based)
- Automatic DevOps workspace correlation
- Built-in approval polling
- DORA metrics enabled
- Modern UI

**Cons**:
- Requires IntegrationHub plugins
- More complex setup
- Plugin licensing may be required
- Limited error messages

**Setup**:
```yaml
# GitHub Secrets Required
SN_DEVOPS_INTEGRATION_TOKEN: your_oauth_token
SERVICENOW_INSTANCE_URL: https://your-instance.service-now.com
SERVICENOW_TOOL_ID: sys_id_of_github_tool

# In workflow
- name: Create Change Request
  uses: ServiceNow/servicenow-devops-change@v6.1.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Create Change Request'
    change-request: |
      {
        "setCloseCode": "true",
        "autoCloseChange": true,
        "attributes": {
          "short_description": "Deploy to production",
          "type": "standard"
        }
      }
```

### Method 3: Hybrid Approach (Recommended for Most)

Combines REST API reliability with DevOps correlation fields.

**Benefits**:
- Works without IntegrationHub plugins
- Provides correlation IDs for tracking
- Uses basic auth (simpler)
- Better error handling
- Fallback path

**Setup**:
```yaml
- name: Create Change Request with Correlation
  run: |
    CORRELATION_ID="github-${{ github.repository }}-${{ github.run_id }}"

    PAYLOAD=$(cat <<EOF
    {
      "short_description": "Deploy to production",
      "correlation_id": "$CORRELATION_ID",
      "correlation_display": "GitHub Run #${{ github.run_number }}",
      "u_source": "GitHub Actions"
    }
    EOF
    )

    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

    curl -X POST \
      -H "Authorization: Basic $BASIC_AUTH" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request"
```

---

## Integration Approaches

### Approach Comparison Matrix

| Feature | REST API | DevOps Action | Hybrid |
|---------|----------|---------------|--------|
| **Setup Complexity** | Low | High | Medium |
| **Plugin Dependencies** | None | IntegrationHub | None |
| **DevOps Workspace** | ❌ No | ✅ Yes | ⚠️ Limited |
| **DORA Metrics** | ❌ No | ✅ Yes | ❌ No |
| **Approval Polling** | Manual | Built-in | Manual |
| **Error Handling** | Good | Poor | Good |
| **Authentication** | Basic Auth | OAuth Token | Basic Auth |
| **Troubleshooting** | Easy | Hard | Easy |
| **Recommended For** | Simple use cases | Full DevOps platform | Most scenarios |

### Decision Tree: Which Approach Should You Use?

```
Do you have IntegrationHub plugins installed?
    │
    ├─ No ──→ Use Hybrid Approach
    │         (Best balance of features)
    │
    └─ Yes
        │
        Do you need DORA metrics and full DevOps workspace?
            │
            ├─ Yes ──→ Use DevOps Action
            │          (Full platform experience)
            │
            └─ No ──→ Use Hybrid Approach
                      (Simpler, more reliable)
```

---

## Implementation Examples

### Example 1: Simple REST API Integration

**Use Case**: Basic change request creation for deployments

```yaml
name: Deploy with ServiceNow (Simple)

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Create Change Request
        id: create-cr
        run: |
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          PAYLOAD=$(cat <<'EOF'
          {
            "short_description": "Deploy to ${{ github.event.inputs.environment }}",
            "description": "GitHub Actions deployment\n\nCommit: ${{ github.sha }}\nActor: ${{ github.actor }}",
            "type": "standard",
            "state": "-5",
            "priority": "3",
            "risk": "3"
          }
          EOF
          )

          RESPONSE=$(curl -s -X POST \
            -H "Authorization: Basic $BASIC_AUTH" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

          CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
          CHANGE_SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')

          echo "change_number=$CHANGE_NUMBER" >> $GITHUB_OUTPUT
          echo "change_sys_id=$CHANGE_SYS_ID" >> $GITHUB_OUTPUT

          echo "✅ Created: $CHANGE_NUMBER"

      - name: Your deployment steps here
        run: |
          echo "Deploying application..."

      - name: Close Change Request
        if: success()
        run: |
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          curl -s -X PUT \
            -H "Authorization: Basic $BASIC_AUTH" \
            -H "Content-Type: application/json" \
            -d '{"state": "3", "close_code": "successful"}' \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/${{ steps.create-cr.outputs.change_sys_id }}"
```

### Example 2: Multi-Environment Approval Workflow

**Use Case**: Different approval requirements per environment

```yaml
name: Deploy with Approvals

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]

jobs:
  create-change:
    runs-on: ubuntu-latest
    outputs:
      change_sys_id: ${{ steps.create.outputs.sys_id }}
      needs_approval: ${{ steps.settings.outputs.needs_approval }}
    steps:
      - name: Determine Settings
        id: settings
        run: |
          ENV="${{ github.event.inputs.environment }}"

          if [ "$ENV" == "dev" ]; then
            echo "state=3" >> $GITHUB_OUTPUT  # Auto-close
            echo "needs_approval=false" >> $GITHUB_OUTPUT
          elif [ "$ENV" == "qa" ]; then
            echo "state=-5" >> $GITHUB_OUTPUT  # Pending
            echo "needs_approval=true" >> $GITHUB_OUTPUT
            echo "timeout=7200" >> $GITHUB_OUTPUT  # 2 hours
          else  # prod
            echo "state=-5" >> $GITHUB_OUTPUT  # Pending
            echo "needs_approval=true" >> $GITHUB_OUTPUT
            echo "timeout=86400" >> $GITHUB_OUTPUT  # 24 hours
          fi

      - name: Create Change Request
        id: create
        run: |
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          PAYLOAD=$(cat <<EOF
          {
            "short_description": "Deploy to ${{ github.event.inputs.environment }}",
            "state": "${{ steps.settings.outputs.state }}",
            "type": "standard",
            "u_environment": "${{ github.event.inputs.environment }}"
          }
          EOF
          )

          RESPONSE=$(curl -s -X POST \
            -H "Authorization: Basic $BASIC_AUTH" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

          echo "sys_id=$(echo "$RESPONSE" | jq -r '.result.sys_id')" >> $GITHUB_OUTPUT

  wait-approval:
    needs: create-change
    if: needs.create-change.outputs.needs_approval == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Wait for Approval
        run: |
          CHANGE_SYS_ID="${{ needs.create-change.outputs.change_sys_id }}"
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          TIMEOUT=7200
          ELAPSED=0
          INTERVAL=30

          while [ $ELAPSED -lt $TIMEOUT ]; do
            RESPONSE=$(curl -s \
              -H "Authorization: Basic $BASIC_AUTH" \
              "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/$CHANGE_SYS_ID?sysparm_fields=approval")

            APPROVAL=$(echo "$RESPONSE" | jq -r '.result.approval')

            if [ "$APPROVAL" == "approved" ]; then
              echo "✅ Approved!"
              exit 0
            elif [ "$APPROVAL" == "rejected" ]; then
              echo "❌ Rejected"
              exit 1
            fi

            echo "⏸️ Waiting for approval... ($ELAPSED/$TIMEOUT seconds)"
            sleep $INTERVAL
            ELAPSED=$((ELAPSED + INTERVAL))
          done

          echo "❌ Timeout waiting for approval"
          exit 1

  deploy:
    needs: [create-change, wait-approval]
    if: always() && (needs.create-change.outputs.needs_approval == 'false' || needs.wait-approval.result == 'success')
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Application
        run: |
          echo "Deploying to ${{ github.event.inputs.environment }}..."
```

### Example 3: Full DevOps Action Integration

**Use Case**: Maximum ServiceNow integration with DORA metrics

```yaml
name: Deploy with DevOps Action

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create and Wait for Change
        id: change
        uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          interval: '30'
          timeout: '3600'
          change-request: |
            {
              "setCloseCode": "true",
              "autoCloseChange": ${{ github.event.inputs.environment == 'dev' }},
              "attributes": {
                "short_description": "Deploy Online Boutique to ${{ github.event.inputs.environment }}",
                "description": "Automated deployment\n\nCommit: ${{ github.sha }}\nActor: ${{ github.actor }}",
                "type": "standard",
                "business_service": "${{ secrets.SERVICENOW_APP_SYS_ID }}",
                "u_environment": "${{ github.event.inputs.environment }}"
              }
            }

      - name: Deploy Application
        run: |
          echo "Change approved: ${{ steps.change.outputs.change-request-number }}"
          echo "Deploying..."

      - name: Update Change - Success
        if: success()
        uses: ServiceNow/servicenow-devops-update-change@v5.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          change-request-number: ${{ steps.change.outputs.change-request-number }}
          change-request-details: |
            {
              "close_code": "successful",
              "close_notes": "Deployment successful",
              "state": "3"
            }
```

---

## Best Practices

### 1. Authentication & Security

✅ **DO**:
- Use GitHub repository secrets for all credentials
- Rotate passwords/tokens regularly
- Use service accounts with minimal required permissions
- Enable audit logging in ServiceNow
- Use OAuth tokens when IntegrationHub is available

❌ **DON'T**:
- Hard-code credentials in workflows
- Use personal accounts for automation
- Share credentials across teams
- Store credentials in code or logs
- Use admin accounts for integration

### 2. Change Request Management

✅ **DO**:
- Include detailed descriptions with commit SHA, actor, and run URL
- Set appropriate risk levels based on environment
- Include implementation and backout plans
- Use correlation IDs for tracking
- Associate changes with business applications

❌ **DON'T**:
- Create generic "deploy application" descriptions
- Use same risk level for all environments
- Skip backout plans
- Reuse change request numbers
- Leave changes in pending state

### 3. Approval Workflows

✅ **DO**:
- Auto-approve dev environments
- Require approval for qa and prod
- Set realistic timeout values (2 hours QA, 24 hours prod)
- Poll frequently during business hours (30 seconds)
- Send notifications to approval groups

❌ **DON'T**:
- Require manual approval for dev
- Set infinite timeouts
- Poll too frequently (< 15 seconds)
- Assume approvals happen instantly
- Skip approval for "emergency" changes

### 4. Error Handling

✅ **DO**:
- Check API responses for errors
- Validate change request number is returned
- Implement retry logic for transient failures
- Log full error responses for debugging
- Update change request on deployment failure

❌ **DON'T**:
- Assume API calls always succeed
- Continue deployment if change creation fails
- Ignore HTTP error codes
- Hide error messages from users
- Leave change requests in wrong state

### 5. Application Association

✅ **DO**:
- Create business application in ServiceNow CMDB
- Associate all changes with the application
- Map service dependencies
- Use consistent application naming
- Store application sys_id in GitHub secrets

❌ **DON'T**:
- Skip application association
- Use different names across systems
- Hard-code sys_ids in workflows
- Create duplicate applications
- Ignore CMDB relationships

### 6. Monitoring & Observability

✅ **DO**:
- Use GitHub step summaries for visibility
- Include ServiceNow URLs in outputs
- Track DORA metrics when available
- Monitor approval wait times
- Set up alerts for stuck approvals

❌ **DON'T**:
- Deploy blindly without checking status
- Hide ServiceNow integration from developers
- Ignore metrics and trends
- Let changes timeout without notification
- Skip deployment verification

### 7. Multi-Environment Strategy

✅ **DO**:
- Use workflow inputs for environment selection
- Apply different rules per environment
- Test in dev before promoting to prod
- Use kustomize overlays for configuration
- Document promotion process

❌ **DON'T**:
- Deploy directly to production
- Use same configuration for all environments
- Skip testing in lower environments
- Hard-code environment names
- Allow anyone to deploy to prod

---

## Common Pitfalls & Antipatterns

### Antipattern 1: The "Fire and Forget" Integration

**❌ Problem**:
```yaml
- name: Create Change
  run: |
    curl -X POST ... # Creates change
    # Immediately continues deployment without checking status
```

**Why it's bad**:
- Defeats purpose of change management
- No approval enforcement
- Compliance violation
- No audit trail

**✅ Solution**:
```yaml
- name: Create Change
  id: create
  run: |
    # Create change and capture sys_id

- name: Wait for Approval
  run: |
    # Poll until approved or rejected

- name: Deploy
  run: |
    # Only runs if approved
```

### Antipattern 2: The "Magic String" Configuration

**❌ Problem**:
```yaml
change-request: |
  {
    "business_service": "4ffc7bfec3a4fe90e1bbf0cb0501313f",  # Hard-coded sys_id
    "assignment_group": "DevOps Team"  # Hardcoded name
  }
```

**Why it's bad**:
- Breaks if group/app is renamed
- Can't reuse across repositories
- Difficult to maintain
- Not environment-specific

**✅ Solution**:
```yaml
# Store in GitHub secrets
SERVICENOW_APP_SYS_ID
SERVICENOW_DEVOPS_GROUP_SYS_ID
SERVICENOW_QA_GROUP_SYS_ID

# Reference in workflow
"business_service": "${{ secrets.SERVICENOW_APP_SYS_ID }}"
```

### Antipattern 3: The "One Size Fits All" Workflow

**❌ Problem**:
```yaml
# Same approval rules for dev, qa, and prod
state: "-5"  # Always pending approval
```

**Why it's bad**:
- Slows down dev iterations
- No environment-specific risk management
- Frustrates developers
- Reduces adoption

**✅ Solution**:
```yaml
- name: Set Environment Rules
  run: |
    if [ "$ENV" == "dev" ]; then
      echo "state=3" >> $GITHUB_OUTPUT  # Auto-approved
    elif [ "$ENV" == "qa" ]; then
      echo "state=-5" >> $GITHUB_OUTPUT  # Single approval
    else
      echo "state=-5" >> $GITHUB_OUTPUT  # CAB approval
    fi
```

### Antipattern 4: The "Silent Failure"

**❌ Problem**:
```yaml
- name: Update Change
  run: |
    curl -X PUT ... > /dev/null 2>&1  # Suppresses all output
```

**Why it's bad**:
- Hides API errors
- Leaves changes in wrong state
- No visibility into failures
- Difficult to troubleshoot

**✅ Solution**:
```yaml
- name: Update Change
  run: |
    RESPONSE=$(curl -s -X PUT ...)

    if ! echo "$RESPONSE" | jq -e '.result' > /dev/null; then
      echo "❌ Failed to update change"
      echo "$RESPONSE" | jq .
      exit 1
    fi

    echo "✅ Change updated successfully"
```

### Antipattern 5: The "Credential Exposure"

**❌ Problem**:
```yaml
- name: Create Change
  run: |
    curl -X POST \
      -u "admin:P@ssw0rd123" \  # Credentials in plain text!
      ...
```

**Why it's bad**:
- Security violation
- Credentials in logs
- No rotation capability
- Compliance failure

**✅ Solution**:
```yaml
# Store in GitHub secrets (encrypted)
SERVICENOW_USERNAME
SERVICENOW_PASSWORD

# Use in workflow
BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)
curl -H "Authorization: Basic $BASIC_AUTH" ...
```

### Antipattern 6: The "Timeout Disaster"

**❌ Problem**:
```yaml
timeout: '99999999'  # Effectively infinite timeout
interval: '5'        # Poll every 5 seconds
```

**Why it's bad**:
- Workflow runs forever if never approved
- Wastes GitHub Actions minutes
- Hammers ServiceNow API
- No escalation path

**✅ Solution**:
```yaml
# Environment-specific timeouts
- QA: timeout: '7200' (2 hours), interval: '30'
- Prod: timeout: '86400' (24 hours), interval: '60'

# Add timeout notification
if [ $ELAPSED -gt $WARNING_THRESHOLD ]; then
  # Send notification to approval group
fi
```

### Antipattern 7: The "Missing Correlation"

**❌ Problem**:
```yaml
# Creates change but no way to track it back to GitHub
{
  "short_description": "Deploy application"
}
```

**Why it's bad**:
- Can't link change to deployment
- No DevOps workspace visibility
- Difficult to audit
- Can't track metrics

**✅ Solution**:
```yaml
{
  "short_description": "Deploy Online Boutique to prod",
  "correlation_id": "github-${{ github.repository }}-${{ github.run_id }}",
  "correlation_display": "GitHub Run #${{ github.run_number }}",
  "u_source": "GitHub Actions",
  "description": "Run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
}
```

### Antipattern 8: The "Assumed Success"

**❌ Problem**:
```yaml
- name: Deploy
  run: kubectl apply -f manifests/

- name: Update Change to Success
  run: curl -X PUT ... -d '{"state": "3"}'  # Always marks as successful
```

**Why it's bad**:
- Reports success even if deployment failed
- Incorrect audit trail
- Wrong DORA metrics
- No rollback trigger

**✅ Solution**:
```yaml
- name: Deploy
  id: deploy
  run: kubectl apply -f manifests/

- name: Update Change - Success
  if: success()
  run: |
    # Mark as successful

- name: Update Change - Failed
  if: failure()
  run: |
    # Mark as unsuccessful
    # Trigger rollback
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: "Internal Server Error" from DevOps Action

**Symptoms**:
```
Error: Internal server error
change-request-number output is empty
```

**Root Cause**: Missing IntegrationHub plugins

**Solution**:
1. Check if IntegrationHub plugins are installed:
   ```bash
   bash scripts/diagnose-servicenow.sh
   ```

2. If plugins are missing, use hybrid approach instead:
   ```yaml
   # Switch to deploy-with-servicenow-hybrid.yaml
   ```

3. Or request IntegrationHub installation from ServiceNow admin

**Reference**: [SERVICENOW-DEVOPS-API-PREREQUISITES.md](SERVICENOW-DEVOPS-API-PREREQUISITES.md)

#### Issue 2: Change Requests Not Visible in DevOps Workspace

**Symptoms**:
- Change created in change_request table
- Not showing in DevOps Change workspace

**Root Cause**: Missing correlation fields or IntegrationHub

**Solution**:
Add correlation fields to REST API calls:
```json
{
  "correlation_id": "github-repo-run-123",
  "correlation_display": "GitHub Run #45",
  "u_source": "GitHub Actions"
}
```

#### Issue 3: Approval Timeout

**Symptoms**:
```
Timeout waiting for approval (7200 seconds)
Workflow failed
```

**Root Causes**:
1. Approval group not notified
2. No approvers assigned to group
3. Change in wrong state

**Solutions**:
1. Verify approval groups exist and have members
2. Check change request state is "-5" (Pending)
3. Verify assignment_group is correct
4. Check email notifications are configured

#### Issue 4: Authentication Failures

**Symptoms**:
```
401 Unauthorized
Required to provide Auth information
```

**Solutions**:

For Basic Auth:
```yaml
# Verify secrets are set correctly
gh secret list

# Test credentials manually
curl -u "$USERNAME:$PASSWORD" \
  "$INSTANCE_URL/api/now/table/change_request?sysparm_limit=1"
```

For OAuth Token:
```yaml
# Verify token is valid
# Check tool-id matches GitHub tool sys_id in ServiceNow
# Ensure user has correct roles
```

#### Issue 5: JSON Parsing Errors

**Symptoms**:
```
jq: parse error: Invalid numeric literal at line 1, column 4
```

**Root Cause**: API returned error instead of JSON

**Solution**:
```yaml
- name: Create Change
  run: |
    RESPONSE=$(curl -s -X POST ...)

    # Check if response is valid JSON
    if ! echo "$RESPONSE" | jq . > /dev/null 2>&1; then
      echo "❌ Invalid JSON response:"
      echo "$RESPONSE"
      exit 1
    fi

    # Now safe to parse
    CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
```

---

## Migration Path

### From Manual Changes to Automated

**Phase 1: Read-Only Integration** (Week 1)
- Set up GitHub secrets
- Deploy `deploy-with-servicenow-basic.yaml` workflow
- Create changes for dev environment only
- Verify change requests appear in ServiceNow
- **Goal**: Prove integration works, no process changes yet

**Phase 2: Dev Auto-Approval** (Week 2)
- Enable auto-close for dev environment
- Configure dev namespace correlation
- Test end-to-end deployment
- **Goal**: Automate dev deployments, reduce friction

**Phase 3: QA Approval Workflow** (Week 3)
- Create QA approval group
- Configure QA approval requirement
- Set 2-hour timeout
- Train QA team on approval process
- **Goal**: Introduce approval gates for QA

**Phase 4: Production Readiness** (Week 4)
- Create CAB approval group
- Configure multi-level production approval
- Set 24-hour timeout
- Document emergency change process
- **Goal**: Full compliance for production

**Phase 5: Optimization** (Ongoing)
- Add application association
- Enable DORA metrics (if IntegrationHub available)
- Tune timeout values based on real data
- Implement automatic notifications
- **Goal**: Continuous improvement

### From REST API to DevOps Action

**Prerequisites Check**:
```bash
# Run diagnostic script
bash scripts/diagnose-servicenow.sh

# Verify IntegrationHub plugins installed
# Verify at least 4 plugins active
```

**Migration Steps**:

1. **Create GitHub Tool in ServiceNow**
   ```
   Navigate to: DevOps Change > Tools
   Create new tool:
     - Name: GitHubARC
     - Type: GitHub Actions
     - Generate integration token
     - Copy sys_id
   ```

2. **Update GitHub Secrets**
   ```bash
   gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "token_from_servicenow"
   gh secret set SERVICENOW_TOOL_ID --body "sys_id_from_tool"
   ```

3. **Test DevOps Action**
   ```yaml
   # Start with deploy-with-servicenow-devops.yaml
   # Test in dev environment first
   gh workflow run deploy-with-servicenow-devops.yaml \
     --field environment=dev
   ```

4. **Verify DevOps Workspace**
   ```
   Navigate to: https://instance.service-now.com/now/devops-change/home
   Verify: Pipeline visible with correlation to GitHub run
   ```

5. **Gradual Rollout**
   - Dev environment (Week 1)
   - QA environment (Week 2)
   - Production (Week 3)

### Rollback Plan

If DevOps Action integration fails:

```yaml
# Immediately switch back to hybrid workflow
# deploy-with-servicenow-hybrid.yaml

# No data loss - change requests still created
# Approval workflow still functions
# Less visibility but fully functional
```

---

## Quick Reference

### GitHub Secrets Required

**Minimum (REST API)**:
```
SERVICENOW_INSTANCE_URL
SERVICENOW_USERNAME
SERVICENOW_PASSWORD
```

**Full (DevOps Action)**:
```
SN_DEVOPS_INTEGRATION_TOKEN
SERVICENOW_INSTANCE_URL
SERVICENOW_TOOL_ID
SERVICENOW_APP_SYS_ID (optional)
```

### ServiceNow API Endpoints

```bash
# Create change
POST /api/now/table/change_request

# Get change
GET /api/now/table/change_request/{sys_id}

# Update change
PUT /api/now/table/change_request/{sys_id}

# Query changes
GET /api/now/table/change_request?sysparm_query=correlation_id={id}
```

### Useful ServiceNow URLs

```
DevOps Change Workspace:
https://instance.service-now.com/now/devops-change/home

Change Requests List:
https://instance.service-now.com/change_request_list.do

Business Applications:
https://instance.service-now.com/cmdb_ci_business_app_list.do

DevOps Tools:
https://instance.service-now.com/sn_devops_tool_list.do
```

### Workflow Templates

Available in `.github/workflows/`:
- `deploy-with-servicenow-basic.yaml` - Simple REST API
- `deploy-with-servicenow-hybrid.yaml` - REST API + correlation
- `deploy-with-servicenow-devops.yaml` - Full DevOps Action

---

## Additional Resources

### Internal Documentation
- [ServiceNow Index](SERVICENOW-INDEX.md) - Complete documentation index
- [Quick Start Guide](SERVICENOW-QUICK-START.md) - Get started in 5 minutes
- [Approval Setup](SERVICENOW-APPROVALS-QUICKSTART.md) - 15-minute approval configuration
- [Application Setup](SERVICENOW-APPLICATION-QUICKSTART.md) - 10-minute CMDB setup
- [DevOps Prerequisites](SERVICENOW-DEVOPS-API-PREREQUISITES.md) - IntegrationHub requirements

### ServiceNow Documentation
- [DevOps Change Velocity](https://www.servicenow.com/docs/bundle/yokohama-it-service-management/page/product/enterprise-dev-ops/concept/devops-landing-page-new.html)
- [GitHub Actions Configuration](https://www.servicenow.com/docs/bundle/yokohama-it-service-management/page/product/enterprise-dev-ops/concept/github-actions-integration-with-devops.html)
- [Change Management REST API](https://developer.servicenow.com/dev.do#!/reference/api/sandiego/rest/c_ChangeManagementAPI)

### GitHub Actions Marketplace
- [ServiceNow DevOps Change](https://github.com/marketplace/actions/servicenow-devops-change-automation)
- [ServiceNow DevOps Update Change](https://github.com/marketplace/actions/servicenow-devops-update-change)

### Community Support
- [ServiceNow Community - DevOps](https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps)
- [GitHub Actions Community](https://github.com/orgs/community/discussions/categories/actions-and-packages)

---

**Document Version**: 2.0
**Last Updated**: 2025-10-20
**Maintained By**: DevOps Team
**Questions?**: See [SERVICENOW-INDEX.md](SERVICENOW-INDEX.md) for support resources
