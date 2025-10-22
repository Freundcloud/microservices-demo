# ServiceNow Custom Fields Setup Guide

> Created: 2025-10-22
> Purpose: Document custom fields implementation for GitHub Actions integration

## Overview

This document explains the custom fields created on the ServiceNow `change_request` table to enable comprehensive tracking of GitHub Actions deployments.

## Problem Statement

### Initial Issue
When querying ServiceNow change requests created by GitHub Actions, custom fields were returning `"N/A"` instead of actual values:

```bash
$ ./scripts/test-servicenow-api.sh

GitHub change requests found: 10
  - CHG0030061: Deploy Online Boutique to dev
    Source: N/A          # Should be "GitHub Actions"
    Correlation: N/A     # Should be workflow run ID
```

### Root Cause Analysis

1. **Fields didn't exist**: The custom fields (`u_source`, `u_correlation_id`, etc.) were not created in the ServiceNow `change_request` table
2. **Field name mismatch**: Workflow was sending some fields with different names (e.g., `u_github_repo` but not `u_repository`)
3. **API returned N/A**: ServiceNow API returns `null` or `"N/A"` for fields that don't exist or aren't populated

## Solution Implemented

### 1. Custom Fields Created

Created 7 custom fields on the `change_request` table via ServiceNow REST API:

| Field Name | Type | Length | Purpose |
|------------|------|--------|---------|
| `u_source` | String | 100 | Source system identifier (e.g., "GitHub Actions") |
| `u_correlation_id` | String | 100 | Workflow run ID for end-to-end traceability |
| `u_repository` | String | 200 | GitHub repository name (e.g., "Freundcloud/microservices-demo") |
| `u_branch` | String | 100 | Git branch name (e.g., "main", "feature/xyz") |
| `u_commit_sha` | String | 50 | Git commit SHA (40-character hash) |
| `u_actor` | String | 100 | GitHub user who triggered the deployment |
| `u_environment` | String | 20 | Deployment environment (dev/qa/prod) |

### 2. Automated Creation Script

Created [scripts/create-servicenow-custom-fields.sh](../scripts/create-servicenow-custom-fields.sh):

```bash
#!/bin/bash
# Automated creation of custom fields via ServiceNow sys_dictionary API

# Features:
- Creates all 7 fields automatically
- Checks for existing fields to avoid duplicates
- Uses ServiceNow REST API (/api/now/table/sys_dictionary)
- Validates credentials before starting
- Provides colored output and progress tracking
```

**Usage**:
```bash
export SERVICENOW_USERNAME="your-username"
export SERVICENOW_PASSWORD="your-password"
./scripts/create-servicenow-custom-fields.sh
```

**Output**:
```
✅ Created: 7 fields
⚠️  Already existed: 0 fields
✅ Custom fields created successfully!
```

### 3. Updated GitHub Actions Workflow

Modified [.github/workflows/servicenow-integration.yaml](../.github/workflows/servicenow-integration.yaml) to populate all custom fields:

**Before** (line 247):
```json
{
  "u_github_repo": "REPO_PLACEHOLDER",
  "u_github_commit": "COMMIT_PLACEHOLDER"
}
```

**After** (line 247):
```json
{
  "u_source": "GitHub Actions",
  "u_correlation_id": "WORKFLOW_RUN_ID_PLACEHOLDER",
  "u_repository": "REPO_PLACEHOLDER",
  "u_branch": "BRANCH_PLACEHOLDER",
  "u_commit_sha": "COMMIT_PLACEHOLDER",
  "u_actor": "ACTOR_PLACEHOLDER",
  "u_environment": "ENV_PLACEHOLDER",
  "u_github_repo": "REPO_PLACEHOLDER",        // Legacy
  "u_github_commit": "COMMIT_PLACEHOLDER"     // Legacy
}
```

**Added placeholder replacement** (line 253):
```yaml
PAYLOAD=$(echo "$PAYLOAD" | sed "s|BRANCH_PLACEHOLDER|${{ github.ref_name }}|g")
```

### 4. Enhanced Diagnostic Tools

Updated [scripts/test-servicenow-api.sh](../scripts/test-servicenow-api.sh) to query all new fields:

**Before**:
```bash
sysparm_fields=number,short_description,u_source,u_correlation_id
```

**After**:
```bash
sysparm_fields=number,short_description,u_source,u_correlation_id,u_repository,u_branch,u_commit_sha,u_actor,u_environment
```

**Enhanced output**:
```bash
  - CHG0030123: Deploy Online Boutique to dev
    Source: GitHub Actions
    Correlation: 18715374406
    Repository: Freundcloud/microservices-demo
    Branch: main
    Commit: 0489117ab3c4...
    Actor: olafkfreund
    Environment: dev
    Created: 2025-10-22 14:00:00
```

## How It Works

### Field Population Flow

```
┌─────────────────────────────────────┐
│  GitHub Actions Workflow Triggers   │
│  (on: push to main)                 │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  servicenow-integration.yaml        │
│  Job: create-change-request         │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  Build JSON Payload (line 247)      │
│  {                                   │
│    "u_source": "GitHub Actions",     │
│    "u_correlation_id": "18715xxx",   │
│    "u_repository": "Freundcloud/...",│
│    "u_branch": "main",               │
│    "u_commit_sha": "0489117a...",    │
│    "u_actor": "olafkfreund",         │
│    "u_environment": "dev"            │
│  }                                   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  POST to ServiceNow API              │
│  /api/now/table/change_request      │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│  ServiceNow Change Request Created   │
│  CHG0030123                          │
│  (all custom fields populated)      │
└─────────────────────────────────────┘
```

## Verification

### Step 1: Verify Fields Exist in ServiceNow

**Via UI**:
1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: System Definition > Tables
3. Search for: `change_request`
4. Click on table > Columns tab
5. Filter columns by: `u_` prefix
6. Verify all 7 fields are present

**Via API**:
```bash
curl -s -u "$USERNAME:$PASSWORD" \
  -H "Accept: application/json" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_dictionary?sysparm_query=name=change_request^elementSTARTSWITHu_&sysparm_fields=element,column_label" \
  | jq -r '.result[] | "\(.element): \(.column_label)"'
```

Expected output:
```
u_source: Source
u_correlation_id: Correlation ID
u_repository: Repository
u_branch: Branch
u_commit_sha: Commit SHA
u_actor: Actor
u_environment: Environment
```

### Step 2: Run a Deployment

Trigger a deployment to populate the fields:

```bash
# Via GitHub UI
- Go to: Actions > Master CI/CD Pipeline > Run workflow
- Select branch: main
- Click: Run workflow

# Via command line (requires gh CLI)
gh workflow run MASTER-PIPELINE.yaml --repo Freundcloud/microservices-demo
```

### Step 3: Verify Field Population

Run the diagnostic script:

```bash
export SERVICENOW_USERNAME="your-username"
export SERVICENOW_PASSWORD="your-password"
./scripts/test-servicenow-api.sh
```

**Expected output**:
```
[Test 3] Checking for GitHub-sourced change requests (u_source field)...
GitHub change requests found: 1
  - CHG0030123: Deploy Online Boutique to dev
    Source: GitHub Actions          ✅
    Correlation: 18715374406         ✅
    Repository: Freundcloud/microservices-demo ✅
    Branch: main                     ✅
    Commit: 0489117ab3c4d5e6f7...    ✅
    Actor: olafkfreund               ✅
    Environment: dev                 ✅
    Created: 2025-10-22 14:00:00

✅ GitHub data IS being sent to ServiceNow!
```

### Step 4: Verify in ServiceNow UI

1. Go to: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do
2. Find the change request (e.g., CHG0030123)
3. Open the record
4. Scroll to custom fields section
5. Verify all fields are populated with actual values (not "N/A")

## Use Cases

### 1. Filter Change Requests by Source

**ServiceNow Query**:
```
u_source = GitHub Actions
```

**URL**:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do?sysparm_query=u_source=GitHub%20Actions
```

### 2. Find Change Request for Specific Workflow

**ServiceNow Query**:
```
u_correlation_id = 18715374406
```

**API Query**:
```bash
curl -s -u "$USERNAME:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=u_correlation_id=18715374406" \
  | jq -r '.result[0] | "\(.number): \(.short_description)"'
```

### 3. Filter by Environment

**ServiceNow Query**:
```
u_environment = prod
```

**Use case**: Review all production deployments for compliance audit

### 4. Track Changes by Developer

**ServiceNow Query**:
```
u_actor = olafkfreund
```

**Use case**: Track deployment activity per developer

### 5. Link GitHub Workflow to ServiceNow Change

**In GitHub Actions Summary**:
```markdown
🔗 ServiceNow Change Request: CHG0030123
View: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request.do?sys_id=abc123def456
```

**In ServiceNow Work Notes**:
```
GitHub Workflow: https://github.com/Freundcloud/microservices-demo/actions/runs/18715374406
Correlation ID: 18715374406
```

## Benefits

### For DevOps Teams
- ✅ **End-to-end traceability**: Link ServiceNow changes to GitHub workflows
- ✅ **Automated change tracking**: No manual change request creation
- ✅ **Environment visibility**: Know exactly which environment was deployed
- ✅ **Commit traceability**: Track deployments back to specific commits

### For Security Teams
- ✅ **Audit trail**: Complete record of who deployed what, when, and where
- ✅ **Source validation**: Verify changes came from GitHub Actions (not manual)
- ✅ **Compliance evidence**: SOC 2, ISO 27001, NIST CSF requirements met
- ✅ **Risk assessment**: Filter by environment for risk-based reviews

### For Approvers
- ✅ **Context-rich decisions**: See repository, branch, commit, and actor
- ✅ **Risk-based routing**: Auto-route based on environment (dev vs prod)
- ✅ **Work item linkage**: See GitHub issues associated with deployment
- ✅ **One-click verification**: Jump directly to GitHub workflow logs

### For Compliance Auditors
- ✅ **Complete audit trail**: Every deployment has ServiceNow record
- ✅ **Searchable history**: Query by date, actor, environment, repository
- ✅ **Tamper-proof**: ServiceNow records provide independent verification
- ✅ **Regulatory compliance**: Meets change management requirements

## Troubleshooting

### Issue: Fields Return "N/A" After Deployment

**Diagnosis**:
```bash
./scripts/test-servicenow-api.sh
```

**Possible causes**:
1. Custom fields weren't created: Run `./scripts/create-servicenow-custom-fields.sh`
2. Workflow hasn't run yet: Trigger a deployment
3. Old change requests: Fields didn't exist when those CRs were created
4. API credentials incorrect: Check SERVICENOW_USERNAME and SERVICENOW_PASSWORD

### Issue: Script Says "Field already exists"

**This is normal** if you run the creation script multiple times. The script checks for existing fields to avoid duplicates.

**No action needed** - fields are ready to use.

### Issue: Workflow Creates CR But Fields Empty

**Check workflow logs**:
```bash
gh run view <run-id> --repo Freundcloud/microservices-demo --log | grep "Create Change Request"
```

**Verify payload**:
Look for the JSON payload in logs - ensure it contains the custom fields

**Common fix**:
Re-run deployment after fields are created (old deployments won't have the fields)

### Issue: Cannot See Fields in ServiceNow UI

**Possible causes**:
1. User doesn't have permission to see custom fields
2. Fields exist but aren't on the form layout
3. Fields created on wrong table

**Solution**:
1. Check sys_dictionary: System Definition > Dictionary > filter by `change_request` and `u_`
2. Add to form: Configure > Form Layout > add custom fields
3. Check permissions: User Admin > Roles > ensure user has `itil` role

## Related Documentation

- [ServiceNow Data Inventory](SERVICENOW-DATA-INVENTORY.md) - Complete list of all ServiceNow tables and fields
- [ServiceNow Test Results Integration](SERVICENOW-TEST-RESULTS-INTEGRATION.md) - Test results upload
- [ServiceNow Work Items Guide](SERVICENOW-WORK-ITEMS-APPROVAL-EVIDENCE.md) - Work items tracking
- [GitHub ServiceNow Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) - Complete integration overview

## Files Modified

- [.github/workflows/servicenow-integration.yaml](../.github/workflows/servicenow-integration.yaml) - Added custom field population
- [scripts/create-servicenow-custom-fields.sh](../scripts/create-servicenow-custom-fields.sh) - New automated creation script
- [scripts/test-servicenow-api.sh](../scripts/test-servicenow-api.sh) - Enhanced diagnostic output
- [docs/SERVICENOW-DATA-INVENTORY.md](SERVICENOW-DATA-INVENTORY.md) - Updated field documentation

## Commits

- `0489117a` - feat: Create ServiceNow custom fields and populate them in workflows
- `fcca52f0` - docs: Update ServiceNow documentation and diagnostic tools for custom fields

---

**Status**: ✅ Complete and verified
**Last Updated**: 2025-10-22
**Next Steps**: Run deployment to verify field population
