# ServiceNow DevOps API Testing Guide

> **Purpose**: Test and compare DevOps Change Control API vs Table API approaches
> **Status**: Experimental - For Evaluation Only
> **Created**: 2025-11-04

---

## Overview

This guide explains how to test the experimental DevOps Change Control API workflow and compare it with the current Table API implementation.

### What's Being Tested

**Current Production** (`.github/workflows/servicenow-change-rest.yaml`):
- Uses ServiceNow Table API: `/api/now/table/change_request`
- Supports 40+ custom fields (u_*)
- Creates records in standard `change_request` table
- Full audit trail and compliance data

**Experimental** (`.github/workflows/servicenow-change-devops-api.yaml`):
- Uses ServiceNow DevOps Change Control API: `/api/sn_devops/v1/devops/orchestration/changeControl?toolId={tool_id}`
- Requires `toolId` query parameter AND `sn_devops_orchestration_tool_id` header
- No custom field support
- Creates records in `change_request` AND `sn_devops_change_reference` tables
- Auto-close functionality built-in
- Visible in ServiceNow DevOps workspace

---

## Prerequisites

### 1. ServiceNow DevOps Plugin

**Check if Installed**:
```bash
source .envrc
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=source=com.snc.devops&sysparm_fields=name,active,version" \
  | jq '.result[] | {name, active, version}'
```

**Expected Output**:
```json
{
  "name": "DevOps Change Velocity",
  "active": "true",
  "version": "1.x.x"
}
```

**If Not Installed**:
1. Log into ServiceNow as admin
2. Navigate to: **System Applications → All**
3. Search for "DevOps Change Velocity"
4. Click **Install** (requires elevated permissions)
5. Wait for installation to complete (~5-10 minutes)

### 2. Tool Registration (SN_ORCHESTRATION_TOOL_ID)

**Check if Configured**:
```bash
# Check GitHub secret exists
gh secret list --repo Freundcloud/microservices-demo | grep SN_ORCHESTRATION_TOOL_ID
```

**If Not Found**, use the finder script:
```bash
./scripts/find-servicenow-tool-id.sh

# If no tool found, create one:
./scripts/find-servicenow-tool-id.sh --create
```

**Manually Create Tool**:
1. Log into ServiceNow
2. Navigate to: **DevOps → Orchestration → Tool Configuration**
3. Click **New**
4. Fill in:
   - **Name**: GitHub Actions
   - **Type**: GitHub
   - **Tool Type**: CI/CD
5. Save and copy the **sys_id**
6. Add to GitHub Secrets:
   ```bash
   gh secret set SN_ORCHESTRATION_TOOL_ID --body "<sys_id>" --repo Freundcloud/microservices-demo
   ```

### 3. Required GitHub Secrets

Verify all secrets exist:
```bash
gh secret list --repo Freundcloud/microservices-demo
```

**Required**:
- `SERVICENOW_USERNAME`
- `SERVICENOW_PASSWORD`
- `SERVICENOW_INSTANCE_URL`
- `SN_ORCHESTRATION_TOOL_ID` (for DevOps API only)

---

## Testing Procedure

### Step 1: Baseline Check (Current State)

**Check Current Implementation**:
```bash
# Run diagnostic script
./scripts/check-servicenow-tables.sh
```

**Expected Output**:
```
Standard ITSM Tables
========================
✅ Found X records in change_request
   Latest: 2025-11-04 14:08:56

ServiceNow DevOps Tables
============================
❌ No records found in sn_devops_change_reference
❌ No records found in sn_devops_test_summary
```

**Why**: Table API creates records in `change_request` but NOT in DevOps tables.

### Step 2: Trigger Test Deployment

**Option A: Use Existing Workflow (Table API)**
```bash
# Make small change to trigger deployment
echo "# Test change $(date)" >> terraform-aws/README.md
git add terraform-aws/README.md
git commit -m "test: Trigger deployment for ServiceNow testing"
git push origin main
```

**Monitor Workflow**:
```bash
gh run watch --repo Freundcloud/microservices-demo
```

**Check Result in ServiceNow**:
```bash
# Get latest change request
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=u_source=GitHub Actions&sysparm_limit=1&sysparm_fields=number,short_description,u_github_repo,u_environment,u_correlation_id" \
  | jq '.result[0]'
```

**Expected**: Change request with all custom fields populated.

### Step 3: Test DevOps API Workflow

**Option 1: Modify Master Pipeline (Temporary)**

Edit `.github/workflows/MASTER-PIPELINE.yaml`:
```yaml
servicenow-change:
  name: "📝 ServiceNow Change Request"
  needs: [pipeline-init, detect-service-changes, ...]
  uses: ./.github/workflows/servicenow-change-devops-api.yaml  # Changed from servicenow-change-rest.yaml
  with:
    environment: ${{ needs.pipeline-init.outputs.environment }}
    short_description: "Deploy microservices to ${{ needs.pipeline-init.outputs.environment }}"
    # ... rest of inputs
```

**Option 2: Standalone Test (Recommended)**

Create test workflow `.github/workflows/test-devops-api.yaml`:
```yaml
name: "Test DevOps API"

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        type: choice
        options: [dev, qa, prod]
        default: dev

jobs:
  test-devops-api:
    uses: ./.github/workflows/servicenow-change-devops-api.yaml
    with:
      environment: ${{ inputs.environment }}
      short_description: "Test DevOps API - DO NOT DEPLOY"
      description: "Testing ServiceNow DevOps Change Control API for comparison with Table API"
    secrets: inherit
```

**Run Test**:
```bash
# Create test workflow file first (above)
git add .github/workflows/test-devops-api.yaml
git commit -m "test: Add DevOps API test workflow"
git push origin main

# Trigger manually
gh workflow run "Test DevOps API" --field environment=dev --repo Freundcloud/microservices-demo

# Watch execution
gh run watch --repo Freundcloud/microservices-demo
```

### Step 4: Compare Results

**Check Both Tables**:

```bash
# Table API - Standard Change Request
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=u_source=GitHub Actions&sysparm_limit=1&sysparm_fields=number,short_description,u_github_repo,u_environment,u_correlation_id,u_security_scan_status" \
  | jq '.result[0]'

# DevOps API - DevOps Change Reference
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=1&sysparm_fields=change_request_number,correlation_id,created_on" \
  | jq '.result[0]'
```

**Visual Check in ServiceNow**:

1. **Standard Change Request Table**:
   - URL: `$SERVICENOW_INSTANCE_URL/change_request_list.do?sysparm_query=u_source=GitHub Actions`
   - Look for: Custom fields (u_github_repo, u_environment, u_security_scan_status, etc.)

2. **DevOps Change Reference Table**:
   - URL: `$SERVICENOW_INSTANCE_URL/sn_devops_change_reference_list.do`
   - Look for: Records only appear if DevOps API was used

3. **DevOps Workspace**:
   - Navigate to: **DevOps → Workspace**
   - Check if change requests appear in DevOps dashboard

---

## Comparison Checklist

Use this checklist to evaluate both approaches:

### Data Completeness

| Field/Feature | Table API | DevOps API | Winner |
|--------------|-----------|-----------|--------|
| **Basic Change Info** |
| Change Number | ✅ | ✅ | Tie |
| Short Description | ✅ | ✅ | Tie |
| Description | ✅ | ✅ | Tie |
| Implementation Plan | ✅ | ✅ | Tie |
| Backout Plan | ✅ | ✅ | Tie |
| Test Plan | ✅ | ✅ | Tie |
| **GitHub Context** |
| u_github_repo | ✅ | ❌ | Table API |
| u_github_commit | ✅ | ❌ | Table API |
| u_github_actor | ✅ | ❌ | Table API |
| u_github_workflow_url | ✅ | ❌ | Table API |
| u_correlation_id | ✅ | ❌ | Table API |
| **Environment & Deployment** |
| u_environment | ✅ | ❌ | Table API |
| u_deployed_version | ✅ | ❌ | Table API |
| u_previous_version | ✅ | ❌ | Table API |
| u_services_updated | ✅ | ❌ | Table API |
| **Security & Compliance** |
| u_security_scan_status | ✅ | ❌ | Table API |
| u_vulnerability_count | ✅ | ❌ | Table API |
| u_sonarqube_status | ✅ | ❌ | Table API |
| u_code_quality_gate | ✅ | ❌ | Table API |
| **Test Results** |
| u_unit_test_status | ✅ | ❌ | Table API |
| u_test_coverage | ✅ | ❌ | Table API |
| **Automation Features** |
| Auto-Close on Success | ❌ | ✅ | DevOps API |
| Auto-Close Code Setting | ❌ | ✅ | DevOps API |
| **Visibility** |
| Standard Change List | ✅ | ✅ | Tie |
| DevOps Workspace | ❌ | ✅ | DevOps API |
| sn_devops_change_reference | ❌ | ✅ | DevOps API |

### Functional Testing

- [ ] **Change Request Created Successfully**
  - Table API: _____ (change number)
  - DevOps API: _____ (change number)

- [ ] **All Plans Formatted Correctly**
  - Table API: Multi-line format? ☑️ Yes ☐ No
  - DevOps API: Multi-line format? ☑️ Yes ☐ No

- [ ] **Auto-Close Functionality**
  - Table API: N/A (manual close required)
  - DevOps API: Auto-closed? ☐ Yes ☐ No

- [ ] **DevOps Workspace Visibility**
  - Table API: Visible in DevOps workspace? ☐ Yes ☑️ No
  - DevOps API: Visible in DevOps workspace? ☑️ Yes ☐ No

- [ ] **Custom Fields Populated**
  - Table API: u_github_repo = _____
  - DevOps API: u_github_repo = _____ (should be empty/null)

### Performance

- [ ] **API Response Time**
  - Table API: _____ seconds
  - DevOps API: _____ seconds

- [ ] **Workflow Execution Time**
  - Table API: _____ seconds
  - DevOps API: _____ seconds

---

## Decision Matrix

After testing, use this matrix to make your decision:

### Choose Table API If:

✅ **Compliance is critical** (SOC 2, ISO 27001, NIST CSF)
- Need complete audit trail with GitHub context
- Need security scan results linked to changes
- Need test coverage and quality gate data

✅ **Custom reporting required**
- Need to filter changes by GitHub repo
- Need to track deployment metrics
- Need correlation between changes and test results

✅ **No DevOps workspace needed**
- Standard ServiceNow change management is sufficient
- Users comfortable with traditional change request interface

### Choose DevOps API If:

✅ **Auto-close is critical**
- Want changes to close automatically on deployment success
- Reduce manual work for change coordinators

✅ **DevOps workspace visibility important**
- Want changes visible in ServiceNow DevOps dashboard
- Integration with other DevOps tools (test results, artifacts)

✅ **Custom fields not needed**
- Basic change tracking is sufficient
- Don't need detailed GitHub/security/test metadata

### Hybrid Approach (Advanced)

⚠️ **Use both APIs** (complex but possible):
- DevOps API creates change in DevOps tables
- Custom workflow updates change_request with additional fields via Table API
- Best of both worlds but requires careful orchestration

---

## Integration Instructions

### If You Choose DevOps API

**Step 1: Update Master Pipeline**

Edit `.github/workflows/MASTER-PIPELINE.yaml` line 564:
```yaml
# Before
uses: ./.github/workflows/servicenow-change-rest.yaml

# After
uses: ./.github/workflows/servicenow-change-devops-api.yaml
```

**Step 2: Remove Custom Field Logic**

Remove all custom field references from workflows since DevOps API doesn't support them:
- Remove `u_*` field construction in `servicenow-integration.yaml`
- Update documentation to reflect simplified change tracking

**Step 3: Update Documentation**

Update these files:
- `docs/3-SERVICENOW-INTEGRATION-GUIDE.md` - Reflect DevOps API usage
- `docs/SERVICENOW-IMPLEMENTATION-ANALYSIS.md` - Update architecture diagrams
- `docs/SERVICENOW-INTEGRATION-FIX.md` - Add DevOps API context

**Step 4: Test Auto-Close**

Deploy to dev and verify:
```bash
# Trigger deployment
git commit --allow-empty -m "test: Verify auto-close functionality"
git push origin main

# Wait for deployment to complete
gh run watch

# Check change request state
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=u_source=GitHub Actions&sysparm_limit=1&sysparm_fields=number,state,close_code,close_notes" \
  | jq '.result[0]'
```

**Expected**: `state: "3"` (Closed), `close_code: "successful"`, `close_notes: "Deployment completed successfully"`

### If You Keep Table API

**Step 1: Archive DevOps API Workflow**

```bash
mkdir -p .github/workflows/archive
git mv .github/workflows/servicenow-change-devops-api.yaml .github/workflows/archive/
git commit -m "docs: Archive DevOps API experimental workflow"
git push origin main
```

**Step 2: Document Decision**

Add to `docs/SERVICENOW-IMPLEMENTATION-ANALYSIS.md`:
```markdown
## API Choice Decision (2025-11-04)

After testing both Table API and DevOps Change Control API, we chose **Table API** for the following reasons:

1. **Compliance Requirements**: SOC 2/ISO 27001 require complete audit trail with security scan data
2. **Custom Fields Essential**: 40+ custom fields provide critical GitHub context and deployment metadata
3. **Reporting Needs**: Custom fields enable filtering by repo, environment, security status
4. **Trade-off Accepted**: Manual close process is acceptable given compliance benefits

**DevOps API Tested**: Change requests created successfully in DevOps workspace, auto-close worked, but lack of custom field support was a blocker.
```

**Step 3: Implement Auto-Close Business Rule (Optional)**

Create ServiceNow business rule to auto-close changes based on `u_deployment_status`:

1. Navigate to: **System Definition → Business Rules**
2. Click **New**
3. Name: "Auto-Close GitHub Actions Changes"
4. Table: "change_request"
5. When: "after update"
6. Conditions: `u_deployment_status` changes to "successful"
7. Script:
   ```javascript
   (function executeRule(current, previous) {
       if (current.u_deployment_status == 'successful' && current.state != '3') {
           current.state = '3'; // Closed
           current.close_code = 'successful';
           current.close_notes = 'Deployment completed successfully. Auto-closed by business rule.';
           current.update();
       }
   })(current, previous);
   ```

This gives you auto-close functionality with Table API.

---

## Troubleshooting

### DevOps API Returns 400: Missing toolId

**Error**:
```json
{
  "result": {
    "status": "Error",
    "details": {
      "errors": [
        {
          "message": "Missing query parameters: toolId"
        }
      ]
    }
  }
}
```

**Cause**: The `toolId` query parameter is missing from the API call

**Fix**: Ensure the API endpoint includes `?toolId={tool_id}`:
```bash
# Correct URL format
/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID

# In workflow:
"${{ secrets.SERVICENOW_INSTANCE_URL }}/api/sn_devops/v1/devops/orchestration/changeControl?toolId=${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
```

**Note**: The DevOps API requires toolId BOTH as query parameter AND as header (`sn_devops_orchestration_tool_id`).

### DevOps API Returns 404

**Error**:
```json
{
  "error": {
    "message": "No such table sn_devops",
    "detail": "..."
  }
}
```

**Cause**: ServiceNow DevOps plugin not installed or not activated

**Fix**:
1. Install plugin (see Prerequisites section)
2. Verify activation:
   ```bash
   curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=source=com.snc.devops" \
     | jq '.result[] | {name, active}'
   ```
3. If `active: "false"`, activate in ServiceNow UI

### DevOps API Returns 401 Unauthorized

**Error**:
```json
{
  "error": {
    "message": "User Not Authenticated",
    "detail": "Required to provide Auth information"
  }
}
```

**Cause**: Missing or invalid `sn_devops_orchestration_tool_id` header

**Fix**:
1. Verify `SN_ORCHESTRATION_TOOL_ID` secret exists
2. Verify tool ID is valid in ServiceNow:
   ```bash
   curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=sys_id=$SN_ORCHESTRATION_TOOL_ID" \
     | jq '.result[0]'
   ```
3. If not found, create new tool (see Prerequisites)

### Change Request Created But Not in DevOps Workspace

**Symptom**: Change request appears in `change_request` table but not in DevOps workspace

**Cause**: Using Table API (not DevOps API)

**Fix**: This is expected behavior. Table API creates standard change requests. Only DevOps API creates records visible in DevOps workspace.

### Auto-Close Not Working

**Symptom**: Change request created but doesn't close automatically

**Cause**: `autoCloseChange` or `setCloseCode` not set correctly

**Fix**:
1. Check workflow payload includes:
   ```json
   {
     "autoCloseChange": true,
     "setCloseCode": true
   }
   ```
2. Verify deployment step updates change request on completion
3. Check ServiceNow logs for errors

---

## References

- **DevOps API Documentation**: [ServiceNow DevOps API Reference](https://developer.servicenow.com/dev.do#!/reference/api/zurich/rest/devops-api)
- **Table API Documentation**: [ServiceNow Table API](https://developer.servicenow.com/dev.do#!/reference/api/zurich/rest/c_TableAPI)
- **API Comparison**: [docs/SERVICENOW-API-COMPARISON.md](SERVICENOW-API-COMPARISON.md)
- **Integration Fix**: [docs/SERVICENOW-INTEGRATION-FIX.md](SERVICENOW-INTEGRATION-FIX.md)
- **Diagnostic Script**: [scripts/check-servicenow-tables.sh](../scripts/check-servicenow-tables.sh)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Status**: Ready for Testing
**Next Review**: After first test execution
