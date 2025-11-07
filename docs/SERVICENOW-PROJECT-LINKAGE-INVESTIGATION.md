# ServiceNow Project Linkage Investigation - Phase 1 Findings

> **Investigation Date**: 2025-11-07
> **Issue**: [#77 - ServiceNow: Missing Software Quality Summaries and Test Summaries in Change Requests](https://github.com/Freundcloud/microservices-demo/issues/77)
> **Status**: Phase 1 Complete - Root Cause Identified

## Executive Summary

**Problem**: Software Quality Summaries, Test Summaries, and Performance Test Summaries are not appearing in ServiceNow change requests, despite records existing in ServiceNow.

**Root Cause Confirmed**: **ServiceNow actions are NOT creating or linking projects, despite using `context-github` parameter.**

**Key Finding**:
- ✅ 68 test summary records exist in ServiceNow
- ❌ 0 projects exist in `sn_devops_project` table
- ❌ ALL 68 records have empty `project` field
- ❌ ALL 68 records have "NO-NUMBER" (not assigned)
- ✅ ServiceNow actions run successfully with no errors
- ❌ `context-github` parameter is NOT triggering project creation

## Investigation Results

### 1. Test Summaries Status

**Query Results**:
```bash
Total test summaries: 68
With project linked: 0
Without project: 68
```

**Sample Records** (all follow this pattern):
```
[NO-NUMBER] SonarCloud Quality Gate (dev) - Project: () - Created: 2025-11-07 13:18:37
[NO-NUMBER] Smoke Tests - Post-Deployment (dev) - Project: () - Created: 2025-11-07 12:24:41
[NO-NUMBER] Security Scans - Manual Test (dev) - Project: () - Created: 2025-11-05 09:18:03
```

**Characteristics**:
- ✅ Records are being created successfully
- ❌ No `number` field assigned (shows as "NO-NUMBER")
- ❌ No `project` field populated (empty sys_id)
- ❌ Created by "github_integration" user
- ✅ Linked to correct tool (GithHubARC: f62c4e49c3fcf614e1bbf0cb050131ef)

### 2. ServiceNow Projects Status

**Query Results**:
```bash
# Query: sn_devops_project table
Results: 0 records

# Specifically for our repository:
Query: name=Freundcloud/microservices-demo
Result: null (no project found)
```

**Finding**: No projects exist in ServiceNow at all. This is the root cause - without projects, records cannot link to change requests.

### 3. ServiceNow Action Configuration

**SonarCloud Workflow** (`.github/workflows/sonarcloud-scan.yaml` lines 190-205):
```yaml
- name: Upload SonarCloud Results to ServiceNow
  id: upload-sonarcloud
  if: ${{ !inputs.skip_servicenow && !github.event.pull_request }}
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    # Basic Authentication (Option 2)
    devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
    devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: f62c4e49c3fcf614e1bbf0cb050131ef
    context-github: ${{ toJSON(github) }}  # ← SHOULD create project!
    job-name: 'SonarCloud Analysis'
    sonar-host-url: 'https://sonarcloud.io'
    sonar-project-key: 'Freundcloud_microservices-demo'
    sonar-org-key: 'freundcloud'
  continue-on-error: true
```

**Build Images Workflow** (`.github/workflows/build-images.yaml` lines 353-365):
```yaml
- name: Upload Test Results to ServiceNow
  if: always()
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}  # ← SHOULD create project!
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: 'src/${{ matrix.service }}/test-results.xml'
```

**Analysis**:
- ✅ Both actions use `context-github: ${{ toJSON(github) }}`
- ✅ Both actions run successfully (status: success)
- ✅ Both actions create records in ServiceNow
- ❌ Neither action creates projects
- ❌ No workflow logs show project creation attempts

### 4. GitHub Context Data

The `context-github` parameter passes this data structure:
```json
{
  "repository": "Freundcloud/microservices-demo",
  "ref": "refs/heads/main",
  "sha": "...",
  "actor": "...",
  "workflow": "...",
  "run_id": "...",
  ...
}
```

**Expected Behavior**: ServiceNow actions should:
1. Extract repository name from `context-github.repository`
2. Query `sn_devops_project` table for existing project
3. If not found, create new project record
4. Link test summary/quality scan to project sys_id

**Actual Behavior**: ServiceNow actions are:
1. ✅ Creating test summary/quality scan records
2. ❌ NOT querying for projects
3. ❌ NOT creating new projects
4. ❌ Leaving `project` field empty

## Possible Root Causes

### 1. ServiceNow DevOps Plugin Not Configured

**Hypothesis**: The ServiceNow DevOps plugin may not be properly activated or configured.

**Evidence**:
- No projects exist at all (0 records)
- Actions succeed but don't create projects
- Records lack proper numbering (NO-NUMBER)

**Investigation Needed**:
- Check ServiceNow DevOps plugin activation status
- Verify plugin version and compatibility
- Check ServiceNow system logs for errors

### 2. Missing ServiceNow API Permissions

**Hypothesis**: The `github_integration` user may lack permissions to create project records.

**Evidence**:
- User CAN create test_summary records (68 records created)
- User CANNOT (or doesn't attempt to) create project records (0 records)
- No error messages in workflow logs

**Investigation Needed**:
- Check `github_integration` user permissions
- Verify roles include `sn_devops.devops_user` or similar
- Check table-level ACLs for `sn_devops_project`

### 3. ServiceNow Action Version Incompatibility

**Hypothesis**: Action versions may have bugs or incompatibilities with our ServiceNow instance.

**Evidence**:
- Using `ServiceNow/servicenow-devops-sonar@v3.1.0`
- Using `ServiceNow/servicenow-devops-test-report@v6.0.0`
- ServiceNow instance version: Unknown

**Investigation Needed**:
- Check ServiceNow instance version
- Review action changelog for known issues
- Test with different action versions

### 4. Tool-ID Configuration Issue

**Hypothesis**: The hardcoded `tool-id` may not have proper configuration in ServiceNow.

**Evidence**:
- Using hardcoded tool-id: `f62c4e49c3fcf614e1bbf0cb050131ef`
- Tool exists (GithHubARC)
- Records link to tool successfully

**Investigation Needed**:
- Check tool configuration in ServiceNow
- Verify tool has `project_creation_enabled` flag (if exists)
- Review tool capabilities settings

### 5. context-github Parameter Not Processed

**Hypothesis**: ServiceNow actions may not be processing the `context-github` parameter.

**Evidence**:
- Parameter is passed correctly: `context-github: ${{ toJSON(github) }}`
- No errors in workflow logs
- No projects created despite successful runs

**Investigation Needed**:
- Enable debug logging in ServiceNow actions
- Check ServiceNow instance logs during action execution
- Verify `context-github` payload is received by ServiceNow

## Comparison: Manual Uploads vs ServiceNow Actions

### Manual REST API Uploads

**Examples**:
- SBOM summary upload (security-scan.yaml)
- Smoke test performance summary upload (servicenow-update-change.yaml)

**Behavior**:
- ❌ No `project` field included in payload
- ❌ No automatic project creation
- ❌ Records exist but orphaned

**Solution**: Add manual project query/creation before upload.

### ServiceNow Actions

**Examples**:
- `ServiceNow/servicenow-devops-sonar@v3.1.0`
- `ServiceNow/servicenow-devops-test-report@v6.0.0`

**Expected Behavior**:
- ✅ `context-github` parameter should trigger project auto-creation
- ✅ Should link records to project automatically

**Actual Behavior**:
- ❌ No projects created
- ❌ Records created without project linkage
- ✅ Otherwise successful (no errors)

## Impact Analysis

### Current State
- **Test Summaries**: 68 records exist, 0 visible in change requests
- **SBOM Summaries**: 1 record exists, 0 visible in change requests
- **Smoke Test Summaries**: 3 records exist, 0 visible in change requests
- **Total Orphaned Records**: 72+ records

### User Impact
- ❌ Change approvers cannot see test results
- ❌ Change approvers cannot see quality scan results
- ❌ Change approvers cannot see performance test results
- ❌ No audit trail linking deployments to test data
- ❌ Compliance evidence is incomplete

### Workflow Impact
- ✅ Workflows execute successfully
- ✅ Data is uploaded to ServiceNow
- ❌ Data is not visible where needed
- ❌ Change request tabs show "0 records"

## Recommended Next Steps

### Immediate Investigation (Phase 1 Continued)

1. **Check ServiceNow DevOps Plugin**:
   ```bash
   # Query via ServiceNow API
   curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=name=DevOps"
   ```

2. **Check User Permissions**:
   ```bash
   # Query github_integration user roles
   curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration"
   ```

3. **Check Tool Configuration**:
   ```bash
   # Get full tool details
   curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef?sysparm_display_value=all"
   ```

4. **Enable Action Debug Logging**:
   ```yaml
   env:
     ACTIONS_STEP_DEBUG: true
     ACTIONS_RUNNER_DEBUG: true
   ```

### Phase 2 Implementation Options

#### Option A: Manual Project Creation (Recommended)

Add project creation to ALL uploads (manual + actions):

**Advantages**:
- ✅ Works regardless of ServiceNow action bugs
- ✅ Full control over project creation
- ✅ Can include additional project metadata
- ✅ Doesn't depend on action version compatibility

**Disadvantages**:
- ❌ More code to maintain
- ❌ Duplicate project queries if action also tries to create

**Implementation**: See Phase 2 tasks in Issue #77

#### Option B: Fix ServiceNow Actions (Investigate First)

Identify and fix why `context-github` isn't working:

**Advantages**:
- ✅ Leverages official actions
- ✅ Less custom code
- ✅ May fix other undiscovered issues

**Disadvantages**:
- ❌ May require ServiceNow instance reconfiguration
- ❌ May require upgrading actions
- ❌ May require plugin updates

**Unknown**: Need to complete investigation first

#### Option C: Hybrid Approach (Safest)

1. Fix manual uploads (SBOM, smoke tests) with project creation
2. Continue investigating ServiceNow action behavior
3. Add manual project creation to action workflows if needed

**Advantages**:
- ✅ Immediate fix for manual uploads
- ✅ Time to properly investigate actions
- ✅ Redundant project creation won't cause errors

**Disadvantages**:
- ❌ More complex implementation
- ❌ Potential for duplicate project creation attempts

## Diagnostic Commands

### Check Current State
```bash
# All test summaries without projects
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary?sysparm_query=projectISEMPTY&sysparm_fields=number,name,sys_created_on&sysparm_limit=10"

# All quality scans without projects
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_software_quality_scan_summary?sysparm_query=projectISEMPTY&sysparm_fields=number,short_description,sys_created_on&sysparm_limit=10"

# Check if ANY projects exist
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project?sysparm_limit=1"
```

### Create Test Project Manually
```bash
# Create project via REST API
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "Freundcloud/microservices-demo",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "description": "Microservices demo application"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project"
```

### Link Existing Records to Project
```bash
# Update existing test summary with project
PROJECT_ID="<sys_id_from_above>"
RECORD_ID="ee162f39c381f650e1bbf0cb050131b3"

curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d '{
    "project": "'"$PROJECT_ID"'"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary/$RECORD_ID"
```

## Conclusion

**Phase 1 Investigation Complete**: The root cause is confirmed - ServiceNow actions are NOT creating projects despite using the `context-github` parameter correctly.

**Immediate Action**: Proceed with Phase 2 implementation using **Option C (Hybrid Approach)**:
1. Fix manual uploads (SBOM, smoke tests) with project query/creation
2. Continue parallel investigation of ServiceNow action behavior
3. Add manual project creation to action workflows if investigation doesn't yield fix

**Success Criteria for Phase 2**:
- ✅ New SBOM summary uploads include project linkage
- ✅ New smoke test summary uploads include project linkage
- ✅ Records appear in change request tabs
- ✅ Change approvers can see test/scan results

**Open Questions for Further Investigation**:
1. Why isn't `context-github` triggering project creation?
2. Is the ServiceNow DevOps plugin properly configured?
3. Does the `github_integration` user have correct permissions?
4. Are there ServiceNow instance logs showing errors?
5. Is this a known issue with these action versions?

---

**Next Document**: See implementation plan in `docs/SERVICENOW-PROJECT-LINKAGE-IMPLEMENTATION.md` (to be created in Phase 2)
