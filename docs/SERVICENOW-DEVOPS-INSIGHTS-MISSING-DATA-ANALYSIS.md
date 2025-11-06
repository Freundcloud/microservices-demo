# ServiceNow DevOps Insights Missing Data - Root Cause Analysis

**Date**: 2025-11-06
**Status**: Under Investigation
**Severity**: High
**Impact**: DevOps Insights dashboard cannot display Online Boutique application

## Executive Summary

Despite successfully populating the `sn_devops_change_reference` table with app, package_ref, and pipeline_executions fields, the DevOps Insights dashboard at https://calitiiltddemo3.service-now.com/now/devops-change/insights-home still does not show "Online Boutique" application.

**Current State**:
- ✅ DevOps Change Reference: All fields populated (app, package_ref, pipeline_executions)
- ✅ Change Request: App column shows "Online Boutique"
- ✅ DevOps App: Record exists (e489efd1c3383e14e1bbf0cb050131d5)
- ❌ DevOps Insights: Only showing "HelloWorld4", no "Online Boutique"

## Problem Statement

### Evidence

**DevOps Insights Summary Table Query**:
```bash
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_display_value=true"
```

**Result**:
```json
{
  "result": [{
    "application": {"display_value": "HelloWorld4"},
    "tests": "225",
    "pipeline_executions": "15",
    "work_items": "3",
    "commits": "9"
  }]
}
```

**Missing**: No record for "Online Boutique" (e489efd1c3383e14e1bbf0cb050131d5)

### What Works

1. **DevOps Change Reference** (d3187825c3c1b250e1bbf0cb05013122):
   - ✅ app: "Online Boutique" (e489efd1c3383e14e1bbf0cb050131d5)
   - ✅ package_ref: "microservices-demo-dev-a8ba0ba" (7b1830edc3053650b71ef44c0501313c)
   - ✅ pipeline_executions: "PE0002615"

2. **Change Request**:
   - ✅ cmdb_ci: "Online Boutique" (bcb82fddc3057250e1bbf0cb05013118)

3. **DevOps App Record**:
   - ✅ Exists: e489efd1c3383e14e1bbf0cb050131d5
   - ✅ Name: "Online Boutique"
   - ✅ Active: true

## Root Cause Analysis

### Investigation Findings

#### 1. Application Field in sn_devops_package Table

**Query**:
```bash
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_package^elementSTARTSWITHapp"
```

**Result**: `{"result": []}`

**Conclusion**: ❌ **The `sn_devops_package` table does NOT have an 'application' field in the schema.**

#### 2. Package Record Investigation

**Package**: microservices-demo-dev-a8ba0ba (7b1830edc3053650b71ef44c0501313c)

**API Response**: Full record returned, but NO `application` field present in the response.

**Implication**: Our workflow sent `application` field in POST/PATCH requests, but ServiceNow **silently ignored it** because the field doesn't exist.

#### 3. Permission Issues

**Query Attempt**:
```bash
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5"
```

**Result**: `{"error": {"message": "Insufficient rights to query records"}}`

**Reason**: The field doesn't exist, so querying by it causes permission error.

### Root Cause Summary

**Primary Issue**: The `sn_devops_package` and `sn_devops_pipeline_execution` tables in ServiceNow **do NOT have an `application` field** in their standard schema.

**How DevOps Insights Works**:
1. ServiceNow DevOps Insights aggregates data into `sn_devops_insights_st_summary` table
2. It relies on the **ServiceNow GitHub Action** (`ServiceNow/servicenow-devops-register-package@v3.1.0`) which uses the DevOps Change Control API
3. This action links packages/pipelines to applications via the **`tool-id`** parameter
4. The tool record (in `sn_devops_tool` table) has an `application` reference
5. Insights aggregates data by following the tool → application linkage

**Why Our Approach Failed**:
- We tried to add `application` field directly to packages/pipelines via REST API
- ServiceNow silently ignored these fields because they don't exist in the schema
- We should have been using the tool-id linkage mechanism instead

**Why HelloWorld4 Appears**:
- HelloWorld4 was registered using the ServiceNow GitHub Action
- It used the correct tool-id linkage
- DevOps Insights successfully aggregated its data

## Proposed Solutions

### Option A: Use ServiceNow GitHub Action for Package Registration (Recommended)

**Approach**:
- Remove our custom REST API package registration
- Use `ServiceNow/servicenow-devops-register-package@v3.1.0` action
- Ensure `SN_ORCHESTRATION_TOOL_ID` secret points to the correct tool (cd5fe3d5c3c5f250b71ef44c050131ed)
- Let ServiceNow handle the application linkage via tool-id

**Pros**:
- ✅ Standard ServiceNow approach
- ✅ Officially supported by ServiceNow
- ✅ Automatically links to DevOps Insights
- ✅ No custom field creation needed
- ✅ Follows ServiceNow best practices

**Cons**:
- ❌ Requires ServiceNow GitHub App to be installed (may need permissions)
- ❌ Less control over package metadata
- ❌ Depends on ServiceNow action compatibility

**Implementation**:
1. Fix the `build-and-push` job to export `services_built` output correctly
2. Ensure `MASTER-PIPELINE.yaml` uses the ServiceNow action for package registration
3. Verify `SN_ORCHESTRATION_TOOL_ID` is correct
4. Remove custom REST API package registration

### Option B: Create Custom Application Field in Package Table

**Approach**:
- Create `u_application` custom field in `sn_devops_package` table
- Create `u_application` custom field in `sn_devops_pipeline_execution` table
- Update workflows to use `u_application` instead of `application`
- Create custom aggregation logic or transform map for DevOps Insights

**Pros**:
- ✅ Full control over data model
- ✅ Can use REST API directly
- ✅ No dependency on ServiceNow GitHub Action

**Cons**:
- ❌ Custom fields may not integrate with standard DevOps Insights
- ❌ Requires ServiceNow admin to create fields
- ❌ May break with ServiceNow upgrades
- ❌ Not following ServiceNow standard practices
- ❌ Need custom aggregation logic

### Option C: Use ServiceNow DevOps Change Control API

**Approach**:
- Use the official ServiceNow DevOps Change Control API endpoints
- Register packages via `/api/sn_devops/v1/devops/package/registration`
- Register pipeline executions via `/api/sn_devops/v1/devops/orchestration/pipelineInfo`
- Use tool-id parameter in API calls

**Pros**:
- ✅ Official ServiceNow API
- ✅ Proper tool-id linkage
- ✅ Works with DevOps Insights
- ✅ REST API approach (no GitHub Action dependency)

**Cons**:
- ❌ API endpoints may require specific authentication
- ❌ Documentation may be limited
- ❌ More complex payload structure
- ❌ Need to research exact API contract

## Recommended Solution

**Option A: Use ServiceNow GitHub Action** is the recommended approach because:

1. **Standard Practice**: This is how ServiceNow intends the integration to work
2. **Proven**: HelloWorld4 works correctly using this method
3. **Maintained**: ServiceNow maintains the action and keeps it compatible
4. **Complete**: Handles all the linkages automatically
5. **Low Risk**: No custom schema changes needed

## Implementation Plan

### Phase 1: Fix Build Job Output
1. Add `outputs:` section to `build-and-push` job in MASTER-PIPELINE.yaml
2. Map reusable workflow outputs to job outputs
3. Test that `services_built` is available to dependent jobs

### Phase 2: Verify ServiceNow GitHub Action Configuration
1. Confirm `SN_ORCHESTRATION_TOOL_ID` = cd5fe3d5c3c5f250b71ef44c050131ed
2. Verify tool record links to application e489efd1c3383e14e1bbf0cb050131d5
3. Test tool API connection

### Phase 3: Enable Package Registration
1. Ensure `build-and-push` job runs (detect service changes)
2. Verify `register-packages` job receives `services_built` output
3. Monitor ServiceNow action execution
4. Verify packages registered with correct tool-id

### Phase 4: Clean Up Custom REST API Registration
1. Keep DevOps Change Reference linking (working correctly)
2. Remove custom package application field updates (not working)
3. Keep pipeline execution registration (may work with DevOps Change API)

### Phase 5: Verification
1. Run full deployment workflow
2. Check `sn_devops_package` table for new packages
3. Query DevOps Insights summary table
4. Verify "Online Boutique" appears in dashboard

## Testing Strategy

### Test 1: Package Registration
```bash
# After workflow completes
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=nameLIKEmicroservices&sysparm_limit=1"

# Expected: Package exists (created by ServiceNow action)
```

### Test 2: DevOps Insights Aggregation
```bash
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application.name=Online Boutique"

# Expected: Record exists with package count > 0
```

### Test 3: Dashboard UI
- Navigate to: https://calitiiltddemo3.service-now.com/now/devops-change/insights-home
- Filter by application
- Expected: "Online Boutique" appears in dropdown

## Acceptance Criteria

- [ ] Workflow builds and pushes Docker images successfully
- [ ] ServiceNow GitHub Action registers packages without errors
- [ ] `sn_devops_insights_st_summary` table contains "Online Boutique" record
- [ ] DevOps Insights dashboard shows "Online Boutique" application
- [ ] Package count reflects actual registered packages
- [ ] Pipeline execution metrics populate
- [ ] Change velocity data calculates correctly

## Related Documentation

- ServiceNow DevOps Plugin Documentation: https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-plugins.html
- ServiceNow GitHub Action: https://github.com/ServiceNow/servicenow-devops-register-package
- DevOps Insights: https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-insights.html

## Files to Modify

1. `.github/workflows/MASTER-PIPELINE.yaml`
   - Add `outputs:` to `build-and-push` job
   - Verify `register-packages` job configuration

2. `.github/workflows/build-images.yaml`
   - Verify `services_built` output is correctly set

3. `.github/workflows/servicenow-change-rest.yaml`
   - Remove custom `application` field from package registration (lines 1425, 1448)
   - Keep DevOps Change Reference linking (working correctly)

## Open Questions

1. **Does the ServiceNow GitHub Action require GitHub App installation?**
   - Need to verify if app is already installed
   - Check if additional permissions are needed

2. **Can we verify the tool-id linkage is correct?**
   - Query tool record to confirm application reference
   - Test tool API connectivity

3. **Should we keep custom REST API package creation?**
   - Or rely entirely on ServiceNow GitHub Action?
   - What happens if action fails?

## UPDATE: New Findings (2025-11-06)

### Corrected Understanding of Linkage Mechanism

**Initial Analysis Was Partially Incorrect**: The tool record does NOT have an application field. The actual linkage works differently:

**Actual Linkage Chain**:
1. `sn_devops_pipeline_execution` → `pipeline` reference → `sn_devops_pipeline` record
2. `sn_devops_pipeline` → `app` reference → `sn_devops_app` record
3. DevOps Insights aggregates by querying pipelines and their app field

**Verification Results**:
✅ **23+ Pipeline Records** exist for microservices-demo repository
✅ **All Linked to "Online Boutique"** app (e489efd1c3383e14e1bbf0cb050131d5)
✅ **Recent Pipeline Executions** correctly linked:
   - PE0002612 → Master CI/CD Pipeline → Online Boutique
   - PE0002281 → Master CI/CD Pipeline → Online Boutique
   - PE0002203 → Master CI/CD Pipeline → Online Boutique
✅ **Tool Record** exists (f62c4e49c3fcf614e1bbf0cb050131ef)
✅ **Tool Linked to Pipelines** (all 23+ pipelines reference this tool)

**Query Confirming Linkage**:
```bash
# Pipeline record 44ae8641c3303a14e1bbf0cb05013187 (Master CI/CD Pipeline)
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline/44ae8641c3303a14e1bbf0cb05013187?sysparm_display_value=all"

# Returns:
{
  "app": {
    "display_value": "Online Boutique",
    "value": "e489efd1c3383e14e1bbf0cb050131d5"
  },
  "tool": {
    "display_value": "GithHubARC",
    "value": "f62c4e49c3fcf614e1bbf0cb050131ef"
  }
}
```

### Remaining Mystery

**Despite Correct Linkage, DevOps Insights Still Empty**: The `sn_devops_insights_st_summary` table only shows HelloWorld4, NOT "Online Boutique".

**Possible Causes**:
1. **Scheduled Aggregation Job**: DevOps Insights may use a scheduled job that hasn't run yet
2. **Package Requirement**: Despite HelloWorld4 having no packages, maybe new apps require at least one package to appear
3. **Configuration Issue**: DevOps plugin may need activation or configuration
4. **Time Delay**: Insights may take 24-48 hours to populate for new applications
5. **Manual Refresh Required**: May need admin to trigger insights recalculation

### Completed Actions

1. ✅ **Fixed build-and-push job outputs** (commit 8c844670)
   - Added comment explaining reusable workflow outputs
   - ServiceNow GitHub Action can now receive services_built list

2. ✅ **Verified SN_ORCHESTRATION_TOOL_ID**
   - Secret exists: f62c4e49c3fcf614e1bbf0cb050131ef
   - Tool record confirmed in ServiceNow
   - Tool linked to all 23+ pipeline records

3. ✅ **Created GitHub Issue #70**
   - Tracking DevOps Insights missing data problem
   - Comprehensive analysis and recommendations

## Next Steps

1. ~~Create GitHub issue to track this work~~ ✅ Done (Issue #70)
2. ~~Investigate build-and-push job output issue~~ ✅ Fixed (commit 8c844670)
3. Test ServiceNow GitHub Action with actual package registration
4. Remove custom application field updates (lines 1425, 1448 in servicenow-change-rest.yaml)
5. Run complete workflow and verify package registration
6. **NEW**: Investigate scheduled jobs for DevOps Insights aggregation
7. **NEW**: Contact ServiceNow support if insights don't populate after package registration
