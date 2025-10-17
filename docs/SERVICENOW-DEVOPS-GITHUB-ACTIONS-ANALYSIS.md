# ServiceNow DevOps GitHub Actions Integration - Analysis & Recommendations

> Created: 2025-10-17
> Based on: ServiceNow Zurich Release Documentation
> Status: Research Complete

## Overview

This document analyzes our current ServiceNow DevOps GitHub Actions integration and provides recommendations based on official ServiceNow documentation and community best practices.

## Current State

### Our Implementation

**Workflow**: [`.github/workflows/deploy-with-servicenow-devops.yaml`](../.github/workflows/deploy-with-servicenow-devops.yaml)

**Actions Used**:
1. `ServiceNow/servicenow-devops-change@v6.1.0` - Create change requests
2. `ServiceNow/servicenow-devops-update-change@v5.1.0` - Update change requests

**Authentication**: Token-based using `SN_DEVOPS_INTEGRATION_TOKEN` ✅

**Status**:
- ❌ Change creation failing with "Internal server error"
- ❌ No change request number returned
- ✅ Hybrid REST API workflow working as fallback

## Research Findings

### 1. ServiceNow DevOps Change Action (v6.1.0)

**Purpose**: Create ServiceNow change requests and pause workflow until approval

**Key Inputs**:
```yaml
- uses: ServiceNow/servicenow-devops-change@v6.1.0
  with:
    # Authentication (choose one)
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}  # v4.0.0+ (recommended)
    # OR
    devops-integration-user-name: ${{ secrets.SN_USERNAME }}
    devops-integration-user-password: ${{ secrets.SN_PASSWORD }}

    # Required
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Create Change Request'  # MUST match job name exactly

    # Change details
    change-request: |
      {
        "setCloseCode": "true",
        "autoCloseChange": false,
        "attributes": {
          "short_description": "Deploy...",
          "business_service": "sys_id",
          "u_environment": "prod"
        }
      }

    # Timeout configuration
    interval: '30'              # Poll every 30 seconds
    timeout: '3600'             # 1 hour max wait
    changeCreationTimeOut: '3600'
    abortOnChangeCreationFailure: true
    abortOnChangeStepTimeout: true
```

**Outputs**:
- `change-request-number`: Change ticket number (e.g., CHG0030001)
- `change-request-sys-id`: System ID for the change record

**Behavior**:
1. Creates change request in ServiceNow
2. **Pauses workflow** waiting for approval
3. Polls ServiceNow every `interval` seconds
4. Resumes when change is approved
5. Fails if change is rejected or times out

### 2. ServiceNow DevOps Update Change Action (v5.1.0)

**Purpose**: Update change request with deployment results

**Key Inputs**:
```yaml
- uses: ServiceNow/servicenow-devops-update-change@v5.1.0
  with:
    # Authentication
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
    context-github: ${{ toJSON(github) }}

    # Required
    change-request-number: ${{ needs.create-job.outputs.change-request-number }}
    change-request-details: |
      {
        "close_code": "successful",  # or "unsuccessful"
        "close_notes": "Deployment completed...",
        "state": "3"  # 3=Closed, 4=Closed Incomplete
      }
```

**Important**:
- ❌ Does NOT support `job-name` parameter (causes warning)
- ✅ Used for updating existing change requests only
- ✅ Typically used in success/failure steps

### 3. ServiceNow DevOps Unit Test Results Action (v3.0.0)

**Purpose**: Register unit test results in ServiceNow DevOps

**We are NOT currently using this** - potential enhancement

**Usage**:
```yaml
- uses: ServiceNow/servicenow-devops-unit-test-results@v3.0.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Run Tests'
    xml-report-filename: 'test-results.xml'  # JUnit XML format
```

**Benefits**:
- Track test results in ServiceNow
- Link test failures to change requests
- Quality gates based on test coverage

## Critical Configuration Issues Discovered

### Issue 1: job-name MUST Match Exactly ⚠️

**Problem**: `job-name` parameter must **exactly match** the GitHub Actions `job.name` field.

**Example of Incorrect Configuration**:
```yaml
jobs:
  create-change:
    name: Create Change  # ← Job name in YAML
    steps:
      - uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          job-name: 'Create Change Request'  # ❌ MISMATCH!
```

**Correct Configuration**:
```yaml
jobs:
  create-change-request:
    name: Create Change Request  # ← Must match exactly
    steps:
      - uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          job-name: 'Create Change Request'  # ✅ MATCHES!
```

**Why This Matters**:
- ServiceNow creates task/step records linked to job names
- Mismatch causes "Task/Step Execution not created" error
- Change creation may timeout waiting for non-existent task

**Our Status**: ✅ **CORRECT** - We have `name: Create Change Request` matching `job-name: 'Create Change Request'`

### Issue 2: update-change Does NOT Support job-name ⚠️

**Problem**: `servicenow-devops-update-change` action does **not** accept `job-name` parameter

**Error Message**:
```
Warning: Unexpected input(s) 'job-name', valid inputs are [...]
```

**Our Fix**: ✅ **FIXED** - We removed `job-name` from update-change steps

### Issue 3: Missing IntegrationHub Plugins (ROOT CAUSE) ⚠️⚠️⚠️

**Critical Finding**: ServiceNow DevOps Change API requires IntegrationHub plugins that may not be installed.

**Required Plugins**:
1. **ServiceNow IntegrationHub Runtime** (`com.glide.hub.integrations`)
2. **IntegrationHub Action Step - REST** (`com.glide.hub.action_step.rest`)
3. **IntegrationHub Action Template - Data Stream** (`com.glide.hub.action_template.datastream`)
4. **Legacy IntegrationHub Usage Dashboard** (`com.glide.hub.legacy_usage`)

**Without these plugins**:
- DevOps Change API returns "Internal server error"
- No change request number returned
- Workflows fail even with correct authentication

**Verification Required**: Check ServiceNow instance for these plugins

**See**: [SERVICENOW-DEVOPS-API-PREREQUISITES.md](SERVICENOW-DEVOPS-API-PREREQUISITES.md)

## Comparison: DevOps Actions vs REST API

| Feature | DevOps Actions | REST API (Hybrid) |
|---------|---------------|-------------------|
| **Approval Pause** | ✅ Yes - workflow pauses until approval | ❌ No - continues immediately |
| **DevOps Workspace** | ✅ Should show in workspace (if plugins installed) | ⚠️ Limited visibility without correlation |
| **Pipeline Tracking** | ✅ Automatic via `context-github` | ⚠️ Manual via correlation fields |
| **Prerequisites** | ❌ Requires IntegrationHub plugins | ✅ Only needs REST API access |
| **Authentication** | ✅ Token or username/password | ✅ Basic auth or token |
| **Setup Complexity** | ⚠️ Medium - requires tool registration | ✅ Simple - direct API calls |
| **Current Status** | ❌ Not working (missing plugins) | ✅ Working reliably |

## Recommendations

### Immediate Actions

#### 1. Verify IntegrationHub Plugins (PRIORITY 1)

**Action**: Check if IntegrationHub plugins are installed in ServiceNow instance

**How to Verify** (ServiceNow UI):
```
1. Navigate to: System Definition > Plugins
2. Search for: "IntegrationHub"
3. Verify these are Active:
   - ServiceNow IntegrationHub Runtime
   - IntegrationHub Action Step - REST
   - IntegrationHub Action Template - Data Stream
   - Legacy IntegrationHub Usage Dashboard
```

**Next Steps Based on Results**:

**If Plugins Installed** ✅:
- Debug why DevOps Change API still failing
- Check ServiceNow logs: System Logs > System Log > All
- Verify tool registration: DevOps > Tools > GitHub

**If Plugins NOT Installed** ❌:
- **Option 1**: Request plugin installation from ServiceNow admin
- **Option 2**: Continue using hybrid REST API workflow (works now)
- **Option 3**: Use ServiceNow App Store to install IntegrationHub

#### 2. Continue Using Hybrid Workflow (Recommended for Now)

**Workflow**: [`.github/workflows/deploy-with-servicenow-hybrid.yaml`](../.github/workflows/deploy-with-servicenow-hybrid.yaml)

**Why**:
- ✅ Working reliably
- ✅ Creates proper change requests
- ✅ Updates with deployment results
- ✅ No plugin dependencies
- ⚠️ Manual approval process (doesn't pause workflow)

**For v1.0 Production Deployment**:
```bash
gh workflow run deploy-with-servicenow-hybrid.yaml --field environment=prod
```

#### 3. Add Unit Test Results Integration (Enhancement)

**Value**: Track test quality in ServiceNow

**Implementation**:
```yaml
- name: Run Tests
  run: pytest --junitxml=test-results.xml

- name: Report Test Results to ServiceNow
  uses: ServiceNow/servicenow-devops-unit-test-results@v3.0.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SERVICENOW_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Run Tests'
    xml-report-filename: 'test-results.xml'
```

**Benefits**:
- Quality metrics in ServiceNow
- Link test failures to changes
- Change approval gates based on test results

### Future Enhancements

#### 1. Security Scanning Results Integration

**Concept**: Report security scan results to ServiceNow

**Potential Actions**:
- Trivy vulnerability reports
- CodeQL SAST findings
- Semgrep issues
- Gitleaks secrets detection

**Implementation**: Custom REST API calls to ServiceNow Security Operations

#### 2. CMDB Integration

**Current**: We set `business_service` and `cmdb_ci` in change requests

**Enhancement**: Automatic CMDB updates
- Update application CI when deployed
- Track deployment history
- Link deployed versions to CMDB

#### 3. Multi-Stage Approval Gates

**Concept**: Different approval workflows per environment

**Implementation**:
```yaml
change-request: |
  {
    "attributes": {
      "type": "${{ github.event.inputs.environment == 'prod' && 'normal' || 'standard' }}",
      "assignment_group": "${{ github.event.inputs.environment == 'prod' && 'CAB' || 'DevOps' }}"
    }
  }
```

**Benefits**:
- Dev: Auto-approve
- QA: DevOps team approval
- Prod: CAB approval

## Action Items

### For ServiceNow Administrator

- [ ] Verify IntegrationHub plugins installed
- [ ] If not installed, request installation via ServiceNow Store
- [ ] Verify GitHub tool registration (sys_id: 4eaebb06c320f690e1bbf0cb05013135)
- [ ] Check DevOps Change Velocity workspace configuration
- [ ] Review System Logs for DevOps API errors

### For Development Team

- [ ] ✅ Use hybrid workflow for v1.0 production deployment
- [ ] Document which workflow to use for each scenario
- [ ] Add unit test results integration (optional)
- [ ] Create troubleshooting runbook for approval workflows
- [ ] Monitor ServiceNow integration during deployments

### For v1.0 Release

**Recommended Workflow**: `deploy-with-servicenow-hybrid.yaml`

**Reason**: Proven working, no plugin dependencies

**Steps**:
1. Build images with v1.0.0 tags
2. Push to ECR
3. Run: `gh workflow run deploy-with-servicenow-hybrid.yaml --field environment=prod`
4. Workflow creates change request
5. **Manual step**: Approve change in ServiceNow UI
6. Workflow completes deployment
7. Workflow updates change with success/failure

## Best Practices from Research

### 1. Job Name Consistency

**Always ensure**:
```yaml
jobs:
  my-job-name:
    name: My Job Name  # ← This
    steps:
      - uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          job-name: 'My Job Name'  # ← Must match this exactly
```

### 2. Timeout Configuration

**For production deployments**:
```yaml
interval: '30'              # Poll every 30 seconds (don't set too low)
timeout: '7200'             # 2 hours for prod (CAB approval can take time)
changeCreationTimeOut: '300' # 5 minutes to create change
```

**For dev/qa**:
```yaml
interval: '30'
timeout: '3600'             # 1 hour
```

### 3. Change Request Details

**Always include**:
- `short_description`: Clear deployment description
- `implementation_plan`: Step-by-step deployment steps
- `backout_plan`: Rollback procedure
- `test_plan`: Post-deployment validation
- `business_service`: Link to application
- `u_environment`: Track which environment

### 4. Error Handling

**Check outputs before using**:
```yaml
- name: Verify Change Created
  run: |
    if [ -z "${{ steps.create-change.outputs.change-request-number }}" ]; then
      echo "ERROR: Change request not created"
      exit 1
    fi
```

**Use conditional updates**:
```yaml
- name: Update Change - Success
  if: success() && needs.create-change.outputs.change_request_number != ''
  uses: ServiceNow/servicenow-devops-update-change@v5.1.0
```

### 5. GitHub Billing Consideration

**Important**: The ServiceNow DevOps Change action **waits** for approval, consuming GitHub Actions minutes.

**Example**:
- Change created at 10:00 AM
- Approved at 2:00 PM (4 hours later)
- **Billed for 4 hours** of runner time

**Mitigation**:
- Use self-hosted runners for approval-gated workflows
- Set reasonable timeout values
- Use hybrid approach (create change, continue workflow, check approval separately)

## Troubleshooting Guide

### Problem: Change Request Number Not Returned

**Symptoms**:
```
Error: Input required and not supplied: change-request-number
```

**Causes & Solutions**:

1. **Missing IntegrationHub plugins**
   - Verify plugins installed
   - See [SERVICENOW-DEVOPS-API-PREREQUISITES.md](SERVICENOW-DEVOPS-API-PREREQUISITES.md)

2. **Authentication failure**
   - Verify `SN_DEVOPS_INTEGRATION_TOKEN` is valid
   - Check token has not expired
   - Verify user has correct permissions

3. **Tool ID incorrect**
   - Verify tool-id: `4eaebb06c320f690e1bbf0cb05013135`
   - Check tool is active in ServiceNow

4. **Job name mismatch**
   - Verify job `name:` matches `job-name:` parameter exactly
   - Check for extra spaces or case differences

### Problem: Workflow Times Out Waiting for Approval

**Symptoms**:
```
Error: Change creation timed out after 3600 seconds
```

**Solutions**:

1. **Increase timeout**:
   ```yaml
   timeout: '7200'  # 2 hours
   ```

2. **Check change in ServiceNow**:
   - Navigate to change in ServiceNow UI
   - Verify change state (should be "Scheduled" or "Assess")
   - Check assignment group has been notified

3. **Manual intervention**:
   - Approve change in ServiceNow UI
   - Workflow should resume automatically

### Problem: Task/Step Not Created in ServiceNow

**Symptoms**:
```
Error: Task/Step Execution not created in ServiceNow DevOps for this job/stage
```

**Root Cause**: Job name mismatch

**Solution**: Ensure exact match:
```yaml
jobs:
  create-change:
    name: Create Change  # ← Must match below
    steps:
      - uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          job-name: 'Create Change'  # ← Must match above
```

## Conclusion

### Current Recommendation

**For immediate use (v1.0 deployment)**:
- ✅ Use `deploy-with-servicenow-hybrid.yaml` workflow
- ✅ Proven working without plugin dependencies
- ✅ Creates proper change requests with correlation

**For future (after plugin verification)**:
- ⏳ Revisit `deploy-with-servicenow-devops.yaml` workflow
- ⏳ Enable automatic approval pausing
- ⏳ Full DevOps Change Velocity integration

### Summary

We have:
1. ✅ Correctly configured ServiceNow DevOps GitHub Actions
2. ✅ Token-based authentication working
3. ✅ Job names properly aligned
4. ❌ IntegrationHub plugins potentially missing (blocking DevOps API)
5. ✅ Working hybrid REST API workflow as reliable fallback

**Next critical step**: Verify IntegrationHub plugin installation in ServiceNow instance.

## References

- [ServiceNow DevOps Change Action - GitHub](https://github.com/ServiceNow/servicenow-devops-change)
- [ServiceNow DevOps Update Change Action - GitHub](https://github.com/ServiceNow/servicenow-devops-update-change)
- [ServiceNow Community - DevOps Forum](https://www.servicenow.com/community/devops-forum)
- [GitHub Actions Marketplace - ServiceNow DevOps](https://github.com/marketplace?query=servicenow+devops)
- [Our Prerequisites Documentation](SERVICENOW-DEVOPS-API-PREREQUISITES.md)
- [Our Integration Guide](SERVICENOW-DEVOPS-CHANGE-API-INTEGRATION.md)
