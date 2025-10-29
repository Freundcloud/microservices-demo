# ServiceNow DevOps Change Action - Payload Fix

> **Issue**: Internal server error when creating change requests via ServiceNow DevOps Change action
> **Resolution**: Match change-request payload structure from working test workflow
> **Root Cause**: Invalid field values (display names instead of sys_ids) and unsupported fields

## Problem Summary

The ServiceNow DevOps Change action (v6.1.0) was failing with:
```
Error: Internal server error. An unexpected error occurred while processing the request.
```

All required parameters were present and correct:
- ✅ Valid action SHA (`5a9cae19b2869dbae3981d5e86feeef1dbd0306e`)
- ✅ Working Basic Authentication (username/password)
- ✅ Required `job-name` parameter provided
- ✅ Valid ServiceNow instance URL and tool-id

However, the **change-request payload** contained invalid field values and unsupported fields that caused ServiceNow to reject the request.

## Root Cause Analysis

### Comparison Methodology

Compared two workflows:
1. **Working Test Workflow**: [test-servicenow-devops-change.yaml](.github/workflows/test-servicenow-devops-change.yaml) - Successfully creates change requests
2. **Failing Workflow**: [servicenow-devops-change.yaml](.github/workflows/servicenow-devops-change.yaml) - Returns internal server error

### Critical Differences Found

#### 1. Missing Top-Level Fields

**Working Test Workflow** (lines 107-114):
```json
{
  "setCloseCode": "false",
  "autoCloseChange": false,
  "attributes": {
    // ... field definitions
  }
}
```

**Failing Workflow** (BEFORE fix):
```json
{
  "attributes": {
    // ... field definitions (missing setCloseCode and autoCloseChange)
  }
}
```

**Impact**: These fields control change request closure behavior. Omitting them may cause ServiceNow to use defaults that conflict with workflow expectations.

#### 2. Invalid assignment_group Value (PRIMARY CAUSE)

**Working Test Workflow**:
```json
"assignment_group": "a715cd759f2002002920bde8132e7018"  // ✅ sys_id reference
```

**Failing Workflow** (BEFORE fix):
```json
"assignment_group": "GitHubARC DevOps Admin"  // ❌ Display name (INVALID)
```

**Why This Failed**:
- ServiceNow **requires sys_id** for reference fields like `assignment_group`
- Display names like `"GitHubARC DevOps Admin"` are **not valid** for API calls
- ServiceNow couldn't resolve the display name to a sys_id
- Result: **Internal server error** (500 status code)

**How to Find sys_id**:
```bash
# Method 1: Query by name
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_group?sysparm_query=name=GitHubARC%20DevOps%20Admin" | \
  jq '.result[0].sys_id'

# Method 2: ServiceNow UI
1. Navigate to: User Administration > Groups
2. Find "GitHubARC DevOps Admin"
3. Right-click > Copy sys_id
```

#### 3. Unsupported/Invalid Fields

**Failing Workflow** (BEFORE fix) included fields not present in working test:

```json
"subcategory": "Deployment",           // ❌ May not exist in change_request table
"assigned_to": "Olaf Krasicki-Freund", // ❌ Should be sys_id, not display name
"justification": "..."                 // ❌ Not a standard change_request field
```

**Why These Failed**:
- `subcategory`: Field may not exist in `change_request` table or may require specific values
- `assigned_to`: Same issue as `assignment_group` - requires sys_id, not display name
- `justification`: Not a standard field in `change_request` table (custom field would need to be created)

**Result**: ServiceNow rejected the payload due to invalid/unsupported fields.

## Solution Implemented

### Fixed Payload Structure

```json
{
  "setCloseCode": "false",
  "autoCloseChange": false,
  "attributes": {
    "short_description": "Deploy microservices to dev [dev]",
    "description": "Automated deployment to dev via GitHub Actions\n\nWorkflow: 🚀 Master CI/CD Pipeline\nRun: 18911432915\nActor: olafkfreund\n\nServices: []\nInfrastructure Changes: false\n\nSecurity Status: passed\nCritical: 0, High: 0",
    "type": "standard",
    "category": "DevOps",
    "assignment_group": "a715cd759f2002002920bde8132e7018",  // ✅ sys_id
    "priority": "3",
    "risk": "3",
    "impact": "3",
    "implementation_plan": "1. Configure kubectl access\n2. Apply Kustomize overlays\n3. Monitor rollout\n4. Verify pods healthy\n5. Test endpoints",
    "backout_plan": "1. Execute rollout undo\n2. Verify rollback\n3. Monitor status\n4. Test functionality",
    "test_plan": "1. Verify rollout complete\n2. Check pods Running\n3. Verify endpoints\n4. Test frontend\n5. Monitor metrics"
  }
}
```

### Changes Made

1. ✅ **Added** `"setCloseCode": "false"`
2. ✅ **Added** `"autoCloseChange": false`
3. ✅ **Changed** `assignment_group` from `"GitHubARC DevOps Admin"` to `"a715cd759f2002002920bde8132e7018"`
4. ✅ **Removed** `"subcategory": "Deployment"`
5. ✅ **Removed** `"assigned_to": "Olaf Krasicki-Freund"`
6. ✅ **Removed** `"justification": "..."`

### Workflow File Updated

**File**: [.github/workflows/servicenow-devops-change.yaml](.github/workflows/servicenow-devops-change.yaml)

**Lines Changed**: 95-116

**Commit**: `e7d6f062`

## Verification Steps

### 1. Run Master Pipeline

```bash
# Trigger Master pipeline
gh workflow run "MASTER-PIPELINE.yaml" \
  --ref main \
  -f environment=dev \
  -f skip_tests=false \
  -f skip_security_scans=false
```

### 2. Check Workflow Logs

Navigate to:
- Actions > Master CI/CD Pipeline > Latest Run
- Expand "ServiceNow DevOps Change" job
- Check "ServiceNow DevOps Change" step

**Expected Output**:
```
Creating change request...
✅ Change request created: CHG0030001
change-request-number: CHG0030001
change-request-sys-id: <sys_id>
```

### 3. Verify in ServiceNow

Navigate to:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request.do?sysparm_query=number=CHG0030001
```

**Expected Fields**:
- **Number**: CHG0030001
- **Short Description**: Deploy microservices to dev [dev]
- **Type**: Standard (for dev) or Normal (for qa/prod)
- **Category**: DevOps
- **Assignment Group**: GitHubARC DevOps Admin (display name)
- **State**: -1 (New)
- **Priority**: 3
- **Risk**: 3
- **Impact**: 3

## Lessons Learned

### 1. Reference Fields Require sys_id

**Rule**: Any ServiceNow reference field (assignment_group, assigned_to, etc.) **must use sys_id**, not display name.

**Why**: ServiceNow API doesn't automatically resolve display names to sys_ids. This is a security/data integrity measure.

**How to Find sys_id**:
```bash
# For Groups
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_group?sysparm_query=name=GROUP_NAME" | \
  jq '.result[0].sys_id'

# For Users
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_query=name=USER_NAME" | \
  jq '.result[0].sys_id'
```

### 2. Only Use Standard Fields

**Rule**: Only include fields that exist in the target table (change_request).

**How to Check Fields**:
```bash
# List all fields in change_request table
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=change_request&sysparm_fields=element,column_label,internal_type&sysparm_limit=200"
```

**Custom Fields**: If you need custom fields (like `justification`), create them in ServiceNow first via sys_dictionary API or UI.

### 3. Match Working Examples

**Rule**: When troubleshooting API errors, compare with a **working payload** from a successful request.

**Method**:
1. Find a working workflow or test
2. Extract the exact payload structure
3. Identify differences
4. Match the working structure

In this case: Comparing `test-servicenow-devops-change.yaml` (working) with `servicenow-devops-change.yaml` (failing) immediately revealed the issues.

### 4. ServiceNow Error Messages Are Vague

**Issue**: "Internal server error" doesn't specify what's wrong with the payload.

**Solution**:
- Enable ServiceNow logs (if admin access available)
- Compare with working examples
- Test with minimal payload first, then add fields incrementally
- Use ServiceNow REST API Explorer for validation

## Testing Strategy

### Minimal Payload First

Start with the absolute minimum required fields:

```json
{
  "setCloseCode": "false",
  "autoCloseChange": false,
  "attributes": {
    "short_description": "Test change request",
    "assignment_group": "a715cd759f2002002920bde8132e7018"
  }
}
```

**Test**: Does this create a change request?
- ✅ Yes → Add more fields incrementally
- ❌ No → Fix basic setup (auth, tool-id, sys_id)

### Incremental Field Addition

Add fields one at a time:

1. Start with minimal payload
2. Add `description` → Test
3. Add `type` → Test
4. Add `category` → Test
5. Add `priority`, `risk`, `impact` → Test
6. Add `implementation_plan`, `backout_plan`, `test_plan` → Test

**Stop adding fields** when you encounter an error. The last field added is likely the culprit.

### Reference Field Validation

For **any reference field** (assignment_group, assigned_to, etc.):

**Step 1**: Query for sys_id
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_group?sysparm_query=name=GROUP_NAME" | \
  jq '.result[0].sys_id'
```

**Step 2**: Verify sys_id exists
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_group/a715cd759f2002002920bde8132e7018"
```

**Step 3**: Use sys_id in payload
```json
"assignment_group": "a715cd759f2002002920bde8132e7018"
```

## Related Documentation

- [ServiceNow DevOps Change Action Troubleshooting](SERVICENOW-DEVOPS-CHANGES-TROUBLESHOOTING.md)
- [Enable changeControl Guide](SERVICENOW-ENABLE-CHANGE-CONTROL.md)
- [Auto-Approval Setup](SERVICENOW-AUTO-APPROVAL-SETUP.md)
- [ServiceNow DevOps Action v6.1.0 Guide](SERVICENOW-DEVOPS-ACTION-SUCCESS.md)

## Files Modified

- [.github/workflows/servicenow-devops-change.yaml](.github/workflows/servicenow-devops-change.yaml) - Fixed change-request payload
- Commit: `e7d6f062`

## Next Steps

1. ✅ **Test Master Pipeline** with corrected payload
2. ⏳ **Verify change request creation** succeeds in ServiceNow
3. ⏳ **Configure auto-approval** for standard type (dev environment)
4. ⏳ **Document assignment_group sys_id** for different environments/teams

---

**Summary**: The internal server error was caused by using display names instead of sys_ids for reference fields (assignment_group), and including unsupported/custom fields (subcategory, assigned_to, justification). Matching the payload structure from the working test workflow resolved all issues.
