# ServiceNow Actions Not Creating Projects - Root Cause Analysis

> **Issue Type**: Bug / Integration Issue
> **Component**: ServiceNow DevOps Actions
> **Severity**: High
> **Status**: Under Investigation
> **Created**: 2025-11-07

## Executive Summary

ServiceNow DevOps actions (`servicenow-devops-test-report@v6.0.0` and `servicenow-devops-sonar@v3.1.0`) are configured correctly with `context-github` parameter but are **NOT creating projects** in the `sn_devops_project` table, resulting in 68 orphaned test summary records that don't appear in change requests.

**Impact**: Change approvers cannot see test results, SonarCloud scans, or quality metrics when reviewing change requests for approval.

**Workaround Implemented**: Manual project creation added to SBOM and smoke test uploads (Issue #77 Phase 2).

**This Issue**: Investigate and fix ServiceNow actions to properly create/link projects as designed.

---

## Problem Statement

### Observed Behavior

**ServiceNow Actions Execute Successfully But:**
1. ❌ Do NOT create projects in `sn_devops_project` table (0 projects exist)
2. ❌ Do NOT link test summaries to projects (all 68 records have `project = null`)
3. ❌ Do NOT assign proper record numbers (all show "NO-NUMBER")
4. ✅ DO create test summary records (68 records created)
5. ✅ DO link to correct tool (GithHubARC)

### Evidence

**ServiceNow Query Results** (from Phase 1 investigation):
```bash
# Total projects in sn_devops_project table
Result: 0 records

# Test summaries without project linkage
Query: sn_devops_test_summary?projectISEMPTY
Result: 68 records (100% of all test summaries)

# Sample record
Number: NO-NUMBER
Name: SonarCloud Quality Gate (dev)
Project: () [empty]
Created By: github_integration
Tool: GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)
```

### Affected Workflows

**1. SonarCloud Quality Analysis** (`.github/workflows/sonarcloud-scan.yaml`):
```yaml
- name: Upload SonarCloud Results to ServiceNow
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
    devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: f62c4e49c3fcf614e1bbf0cb050131ef
    context-github: ${{ toJSON(github) }}  # ← SHOULD create project
    job-name: 'SonarCloud Analysis'
    sonar-host-url: 'https://sonarcloud.io'
    sonar-project-key: 'Freundcloud_microservices-demo'
    sonar-org-key: 'freundcloud'
```

**2. Unit Test Reports** (`.github/workflows/build-images.yaml`):
```yaml
- name: Upload Test Results to ServiceNow
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}  # ← SHOULD create project
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: 'src/${{ matrix.service }}/test-results.xml'
```

---

## Root Cause Analysis

### Investigation Methodology

1. ✅ Verified action configuration is correct (`context-github` parameter present)
2. ✅ Confirmed workflow runs complete successfully (no errors in logs)
3. ✅ Verified credentials work (actions CAN create test summary records)
4. ✅ Confirmed 0 projects exist in ServiceNow (not a query issue)
5. ❌ Unable to see action internals (black box)

### Possible Root Causes

#### 1. ServiceNow DevOps Plugin Not Activated/Configured

**Hypothesis**: The ServiceNow DevOps plugin may not be properly activated or missing required configuration.

**Evidence**:
- Actions run without errors (suggests plugin IS installed)
- Records created successfully (suggests plugin IS partially working)
- No projects created (suggests plugin configuration incomplete)

**Investigation Needed**:
```bash
# Check plugin status
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_plugins?sysparm_query=name=DevOps"

# Check plugin configuration
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/sn_devops/v1/devops/config"
```

**Likelihood**: **HIGH** - Most common cause of partial functionality

---

#### 2. Missing API Permissions for `github_integration` User

**Hypothesis**: The `github_integration` user lacks permissions to create project records.

**Evidence**:
- User CAN create in `sn_devops_test_summary` table (68 records)
- User CANNOT create in `sn_devops_project` table (0 records)
- Suggests table-level ACL restrictions

**Investigation Needed**:
```bash
# Check user roles
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration"

# Check ACLs for sn_devops_project table
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_security_acl?sysparm_query=name=sn_devops_project"
```

**Expected Roles**:
- `sn_devops.devops_user` - Required for DevOps operations
- `sn_devops.devops_admin` - May be required for project creation

**Likelihood**: **HIGH** - Common misconfiguration

---

#### 3. ServiceNow Action Version Incompatibility

**Hypothesis**: Action versions may have bugs or incompatibilities with our ServiceNow instance version.

**Evidence**:
- Using `ServiceNow/servicenow-devops-sonar@v3.1.0`
- Using `ServiceNow/servicenow-devops-test-report@v6.0.0`
- ServiceNow instance version: Unknown (need to check)

**Known Issues**:
- Review GitHub issues for these actions:
  - https://github.com/ServiceNow/servicenow-devops-sonar/issues
  - https://github.com/ServiceNow/servicenow-devops-test-report/issues

**Investigation Needed**:
```bash
# Check ServiceNow instance version
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_properties?sysparm_query=name=glide.war"
```

**Likelihood**: **MEDIUM** - Possible but actions widely used

---

#### 4. Tool Configuration Missing Project Creation Flag

**Hypothesis**: The GithHubARC tool (f62c4e49c3fcf614e1bbf0cb050131ef) may be missing configuration to enable project auto-creation.

**Evidence**:
- Tool exists and links correctly to test summaries
- No errors in workflow logs
- Actions may check tool config before creating projects

**Investigation Needed**:
```bash
# Get full tool configuration
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef?sysparm_display_value=all" \
  | jq '.'

# Check for project-related fields
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_tool&sysparm_fields=element,column_label" \
  | jq '.result[] | select(.element | contains("project"))'
```

**Likelihood**: **MEDIUM** - Tool config may control behavior

---

#### 5. context-github Parameter Not Processed Correctly

**Hypothesis**: Actions receive `context-github` but internal logic fails to process it.

**Evidence**:
- Parameter correctly passed: `context-github: ${{ toJSON(github) }}`
- No errors in logs (actions don't report failure)
- Possible silent failure in action code

**GitHub Context Structure**:
```json
{
  "repository": "Freundcloud/microservices-demo",
  "ref": "refs/heads/main",
  "sha": "commit_sha",
  "actor": "username",
  "workflow": "workflow_name",
  "run_id": "12345",
  "run_number": 123,
  ...
}
```

**Investigation Needed**:
- Enable GitHub Actions debug logging:
  ```yaml
  env:
    ACTIONS_STEP_DEBUG: true
    ACTIONS_RUNNER_DEBUG: true
  ```
- Review ServiceNow instance logs during action execution
- Check ServiceNow inbound REST API logs

**Likelihood**: **LOW** - Would affect all users, likely documented

---

#### 6. ServiceNow DevOps Change Control Not Enabled

**Hypothesis**: Project auto-creation may require ServiceNow DevOps Change Control to be enabled.

**Evidence**:
- Change requests work (CHG0030504 exists)
- But change request tabs don't show linked records
- May require specific Change Control configuration

**Investigation Needed**:
```bash
# Check Change Control settings
curl -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/sn_devops/v1/devops/changecontrol/settings"
```

**Likelihood**: **MEDIUM** - Possible prerequisite

---

## Proposed Solutions

### Option A: Fix ServiceNow DevOps Plugin Configuration (Recommended)

**Approach**: Identify and fix missing ServiceNow DevOps plugin configuration.

**Steps**:
1. Check plugin activation status
2. Review plugin configuration settings
3. Verify required properties are set
4. Enable project auto-creation if disabled
5. Test with new workflow run

**Pros**:
- ✅ Fixes root cause (actions will work as designed)
- ✅ Leverages official actions (less custom code)
- ✅ Will fix all 68 existing orphaned records (retroactive linking possible)
- ✅ Future-proof (official support)

**Cons**:
- ❌ Requires ServiceNow admin access to check/modify plugin settings
- ❌ May require plugin upgrade or reconfiguration
- ❌ Investigation time unknown

**Implementation Checklist**:
- [ ] Check ServiceNow DevOps plugin version and status
- [ ] Review plugin configuration in ServiceNow UI
- [ ] Check for missing properties or disabled features
- [ ] Enable project auto-creation (if setting exists)
- [ ] Test with single workflow run
- [ ] Verify project created and test summary linked
- [ ] Document required configuration for future reference

**Testing Strategy**:
1. Trigger SonarCloud workflow manually
2. Check if project appears in `sn_devops_project` table
3. Verify test summary has `project` field populated
4. Confirm record appears in change request tabs

---

### Option B: Fix User Permissions (If Root Cause #2)

**Approach**: Grant `github_integration` user permissions to create project records.

**Steps**:
1. Check current user roles
2. Add `sn_devops.devops_admin` role if missing
3. Verify ACL permissions for `sn_devops_project` table
4. Test with new workflow run

**Pros**:
- ✅ Quick fix if this is the issue
- ✅ No code changes required
- ✅ Actions will work as designed

**Cons**:
- ❌ Only fixes if permissions are the issue
- ❌ Requires ServiceNow admin access

**Implementation Checklist**:
- [ ] Query user roles for `github_integration`
- [ ] Add `sn_devops.devops_admin` role
- [ ] Verify table ACLs allow project creation
- [ ] Test workflow run
- [ ] Verify project created

---

### Option C: Add Manual Project Creation to ServiceNow Action Workflows

**Approach**: Duplicate the manual project creation logic from SBOM/smoke test uploads to all workflows using ServiceNow actions.

**Steps**:
1. Create reusable workflow step or composite action
2. Add project query/creation before ServiceNow action calls
3. Update all affected workflows (build-images.yaml, sonarcloud-scan.yaml)

**Pros**:
- ✅ Full control over project creation
- ✅ Consistent with existing manual uploads (SBOM, smoke tests)
- ✅ Works regardless of action internals
- ✅ Can implement immediately without ServiceNow admin access

**Cons**:
- ❌ Doesn't fix root cause (workaround only)
- ❌ More code to maintain
- ❌ Duplicate project creation attempts (action + manual)
- ❌ Doesn't leverage official action functionality

**Implementation Checklist**:
- [ ] Create composite action for project query/creation
- [ ] Update `.github/workflows/sonarcloud-scan.yaml`
- [ ] Update `.github/workflows/build-images.yaml`
- [ ] Test all workflows
- [ ] Verify no conflicts with action's own project creation

---

### Option D: Hybrid Approach (Recommended for Now)

**Approach**: Implement Option C (manual project creation) while investigating Options A & B in parallel.

**Steps**:
1. Add manual project creation to affected workflows (immediate fix)
2. Investigate ServiceNow plugin configuration (background)
3. Check user permissions (background)
4. Once root cause found, remove manual workaround

**Pros**:
- ✅ Immediate solution (unblocks change request visibility)
- ✅ Time to investigate properly without user impact
- ✅ Easy to remove workaround once fixed
- ✅ Redundant project creation won't cause errors

**Cons**:
- ❌ Temporary code debt
- ❌ Two code paths doing same thing

**Implementation Checklist**:
- [ ] Phase 1: Implement manual project creation (Option C)
- [ ] Phase 2: Investigation (Options A & B in parallel)
- [ ] Phase 3: Remove manual creation if actions start working
- [ ] Phase 4: Document findings for future reference

---

## Recommended Implementation

**Primary Recommendation**: **Option D (Hybrid Approach)**

**Justification**:
1. **Immediate Value**: Manual project creation unblocks change approvers today
2. **No Risk**: Doesn't depend on ServiceNow admin access or plugin changes
3. **Investigable**: Can research root cause without user impact
4. **Reversible**: Easy to remove manual code once actions work
5. **Proven**: Already working for SBOM and smoke test uploads

**Implementation Order**:
1. **Week 1**: Add manual project creation to sonarcloud-scan.yaml and build-images.yaml
2. **Week 2**: Investigate ServiceNow plugin configuration (with admin access)
3. **Week 2**: Check github_integration user permissions
4. **Week 3**: Test fixes, remove manual creation if successful
5. **Week 4**: Document findings and update runbooks

---

## Testing Strategy

### Test Cases

**Test 1: Verify Manual Project Creation**
```bash
# Trigger SonarCloud workflow
gh workflow run sonarcloud-scan.yaml --ref main

# Check project created
curl "$SN_URL/api/now/table/sn_devops_project?sysparm_query=name=Freundcloud/microservices-demo"

# Expected: 1 project record
```

**Test 2: Verify Test Summary Linkage**
```bash
# After Test 1, check latest test summary
curl "$SN_URL/api/now/table/sn_devops_test_summary?sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=1"

# Expected: project field populated with project sys_id
```

**Test 3: Verify Change Request Visibility**
```bash
# Query test summaries for project
PROJECT_ID="<sys_id_from_test1>"
curl "$SN_URL/api/now/table/sn_devops_test_summary?sysparm_query=project=$PROJECT_ID"

# Expected: Test summaries returned
# Then: Check change request UI - records should appear in tabs
```

**Test 4: Verify No Duplicate Projects**
```bash
# Run workflow twice
gh workflow run sonarcloud-scan.yaml --ref main
sleep 120
gh workflow run sonarcloud-scan.yaml --ref main

# Check project count
curl "$SN_URL/api/now/table/sn_devops_project?sysparm_query=name=Freundcloud/microservices-demo"

# Expected: Still only 1 project (query finds existing)
```

---

## Impact Analysis

### Current Impact

**Affected Stakeholders**:
- ❌ **Change Approvers**: Cannot see test results when reviewing change requests
- ❌ **Security Team**: Cannot see SonarCloud quality scans in change records
- ❌ **Compliance**: Missing audit trail linking tests to deployments
- ❌ **Developers**: Cannot demonstrate test coverage for approvals

**Data Impact**:
- 68 test summary records orphaned (no project linkage)
- 0 SonarCloud scan summaries visible in change requests
- Change request tabs show "0 records" despite data existing

### Post-Fix Impact

**Benefits**:
- ✅ Change approvers can see all test results
- ✅ Complete compliance audit trail
- ✅ All future test summaries will link correctly
- ✅ Historical records can be updated (if project sys_id added retroactively)

**Metrics**:
- Before: 0% of test summaries visible in change requests
- After: 100% of test summaries visible in change requests

---

## Implementation Checklist

### Phase 1: Manual Project Creation (Option D - Immediate)

**SonarCloud Workflow** (`.github/workflows/sonarcloud-scan.yaml`):
- [ ] Add project query/creation step before `Upload SonarCloud Results to ServiceNow`
- [ ] Use same pattern as SBOM upload (lines 189-224 of security-scan.yaml)
- [ ] Test workflow run
- [ ] Verify project created and SonarCloud results linked

**Build Images Workflow** (`.github/workflows/build-images.yaml`):
- [ ] Add project query/creation step before `Upload Test Results to ServiceNow`
- [ ] Handle matrix builds (multiple services)
- [ ] Test workflow run for 1 service
- [ ] Verify project created and test results linked
- [ ] Test full matrix build (all 12 services)

**Verification**:
- [ ] Run verification script: `/tmp/verify-phase3-success.sh`
- [ ] Check test summaries have project linkage
- [ ] Check change request tabs show records
- [ ] Update Issue #77 with results

### Phase 2: Root Cause Investigation (Background)

**ServiceNow Plugin Investigation**:
- [ ] Access ServiceNow admin console
- [ ] Navigate to DevOps plugin configuration
- [ ] Check plugin version and activation status
- [ ] Review plugin properties and settings
- [ ] Look for "project auto-creation" setting
- [ ] Document findings

**User Permissions Investigation**:
- [ ] Query `github_integration` user roles
- [ ] Check `sn_devops_project` table ACLs
- [ ] Verify required roles for project creation
- [ ] Add missing roles if needed
- [ ] Test after permission change

**Action Internals Investigation**:
- [ ] Enable GitHub Actions debug logging
- [ ] Trigger workflow with debug enabled
- [ ] Review detailed action logs
- [ ] Check ServiceNow instance logs
- [ ] Correlate workflow + ServiceNow logs
- [ ] Identify where project creation fails

### Phase 3: Cleanup (Once Root Cause Fixed)

- [ ] Remove manual project creation if actions start working
- [ ] Update documentation with root cause findings
- [ ] Create runbook for future troubleshooting
- [ ] Consider retroactive linking of 68 orphaned records

---

## Related Documentation

- **Phase 1 Investigation**: [`docs/SERVICENOW-PROJECT-LINKAGE-INVESTIGATION.md`](SERVICENOW-PROJECT-LINKAGE-INVESTIGATION.md)
- **Issue #77**: ServiceNow: Missing Software Quality Summaries and Test Summaries in Change Requests
- **Commit 13da5523**: feat: Add ServiceNow project linkage to SBOM and smoke test uploads (Phase 2)

---

## Appendix: Diagnostic Commands

### Check ServiceNow DevOps Plugin Status
```bash
curl -s -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_plugins?sysparm_query=name=DevOps&sysparm_display_value=all" \
  | jq '.result[] | {name, version, active, source}'
```

### Check User Roles
```bash
curl -s -u "$SN_USER:$SN_PASS" \
  "$SN_URL/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration&sysparm_display_value=all" \
  | jq '.result[] | {role: .role.display_value, granted_by: .granted_by.display_value}'
```

### Check Project Creation Capability
```bash
# Try to create test project via API
curl -s -u "$SN_USER:$SN_PASS" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "TEST-PROJECT-DELETE-ME",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "description": "Test project creation"
  }' \
  "$SN_URL/api/now/table/sn_devops_project" \
  | jq '.'

# If successful, delete test project
# curl -X DELETE "$SN_URL/api/now/table/sn_devops_project/<sys_id>"
```

### Monitor Workflow with Debug Logging
```yaml
# Add to workflow for debugging
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-07
**Author**: Claude Code (Issue #77 Investigation)
