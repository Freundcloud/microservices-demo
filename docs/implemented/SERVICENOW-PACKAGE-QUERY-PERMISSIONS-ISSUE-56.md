# ServiceNow Package Query HTTP 403 Permission Error Analysis

> **Date**: 2025-11-05
> **Status**: 🔴 CRITICAL - Blocking package linkage
> **Issue**: GitHub Issue #56
> **File**: `scripts/link-packages-to-change-request.sh`
> **Error**: HTTP 403 "Insufficient rights to query records"

---

## Executive Summary

The `link-packages-to-change-request.sh` script fails with HTTP 403 when attempting to query the `sn_devops_package` table in ServiceNow. The error message indicates the `github_integration` user lacks read permissions on specific fields in the query, despite having admin-level roles. This is a **field-level ACL (Access Control List) issue**, not a table-level or role-level issue.

**Impact**: Packages registered in ServiceNow cannot be linked to Change Requests, breaking the compliance audit trail.

---

## Problem Statement

### Observed Error

```
❌ ERROR: ServiceNow API returned HTTP 403

Response body:
{
  "error": {
    "message": "Insufficient rights to query records",
    "detail": "Field(s) present in the query do not have permission to be read"
  },
  "status": "failure"
}
```

### Context

- **Workflow**: MASTER-PIPELINE.yaml → `link-packages-to-change-request` job
- **Script**: `scripts/link-packages-to-change-request.sh`
- **API Call**: Line 60
- **Table**: `sn_devops_package`
- **Query**: `pipeline_id=$GITHUB_RUN_ID`
- **Fields Requested**: `sys_id,name,version,change_request`

### Timeline

| Time | Event |
|------|-------|
| 10:13 UTC | Change Request created successfully (CHG0030427) |
| 10:13 UTC | Packages registered successfully (register-packages job) |
| 10:13 UTC | Link packages job starts |
| 10:13 UTC | **HTTP 403 error on query** |
| 10:13 UTC | Job fails with exit code 1 |

---

## Root Cause Analysis

### Issue: Field-Level ACL Restriction

**Root Cause**: The `github_integration` user has insufficient **field-level read permissions** on the `sn_devops_package` table, specifically for fields used in the query or requested in `sysparm_fields`.

#### Evidence

1. **Successful Operations**:
   - ✅ Register packages (ServiceNow action succeeds)
   - ✅ Create change requests (Table API succeeds)
   - ✅ Update change requests (Table API succeeds)

2. **Failed Operation**:
   - ❌ Query `sn_devops_package` table via REST API

3. **Error Analysis**:
   ```
   "detail": "Field(s) present in the query do not have permission to be read"
   ```

   This indicates **field-level ACL**, not table-level or role-level permission issue.

#### ServiceNow ACL Hierarchy

ServiceNow has multiple permission layers:

```
System Admin Role (✅ github_integration has this)
  └─ Table-Level ACL (✅ Can access sn_devops_package)
       └─ Field-Level ACL (❌ BLOCKED on specific fields)
            └─ Scripted ACL (Conditional logic blocking access)
```

The error occurs at the **Field-Level ACL** layer, meaning:
- User has table access
- User lacks read permission on **one or more fields** in the query or field list

### Possible Blocked Fields

From the query:
```bash
sysparm_query=pipeline_id=$GITHUB_RUN_ID
sysparm_fields=sys_id,name,version,change_request
```

**Likely culprits**:

1. **`pipeline_id`** (query field):
   - May be a custom field added by ServiceNow DevOps plugin
   - Field-level ACL may restrict read access
   - Not part of out-of-the-box `sn_devops_package` table

2. **`change_request`** (reference field):
   - Reference field pointing to `change_request` table
   - May require additional role beyond `sn_devops.*`
   - Could have scripted ACL checking change request permissions

3. **Standard fields** (unlikely but possible):
   - `sys_id`, `name`, `version` are standard
   - Should be readable with basic table access
   - Less likely to be blocked

---

## Impact Assessment

### Severity: **CRITICAL**

- **Deployment Workflow**: ❌ Blocked
- **ServiceNow Audit Trail**: ❌ Incomplete (packages not linked to CRs)
- **Compliance**: ❌ Missing package traceability
- **Frequency**: 100% failure rate

### Affected Components

| Component | Status | Impact |
|-----------|--------|--------|
| Package Registration | ✅ Working | Packages created in ServiceNow |
| Package Linkage | ❌ Failing | Cannot link packages to change requests |
| Change Request Creation | ✅ Working | Change requests created |
| Deployment | ⚠️ Continues | Deploys despite linkage failure |

**Result**: Packages exist in ServiceNow but are **orphaned** (not linked to any change request).

---

## Proposed Solutions

### Option A: Grant Field-Level Read Permissions (Recommended)

**Approach**: Add specific field-level read permissions for `github_integration` user on `sn_devops_package` table.

**Steps**:

1. **Navigate to ServiceNow**:
   ```
   System Security → Access Control (ACL)
   ```

2. **Filter by Table**:
   ```
   Table: sn_devops_package
   Type: field
   Operation: read
   ```

3. **Identify Restricted Fields**:
   - Look for ACLs on: `pipeline_id`, `change_request`
   - Check "Roles" column for required roles

4. **Grant Permissions** (Option 1 - Recommended):
   - Add `sn_devops.integration_user` role to ACL
   - Ensure `github_integration` user has this role

5. **Grant Permissions** (Option 2 - If custom field):
   - If `pipeline_id` is custom, add explicit read permission
   - Navigate to: System Definition → Tables & Columns
   - Find `sn_devops_package` → `pipeline_id` column
   - Add read ACL for `sn_devops.integration_user`

6. **Verify User Roles**:
   ```
   User Administration → Users → github_integration → Roles
   ```

   **Required roles**:
   - ✅ `admin` (already has)
   - ✅ `sn_devops.integration_user` (verify exists)
   - ✅ `sn_devops.viewer` (verify exists)
   - ✅ `change_manager` (for change_request field access)

**Pros**:
- ✅ Proper security model
- ✅ Follows ServiceNow best practices
- ✅ Reusable for other integrations

**Cons**:
- ⏳ Requires ServiceNow admin access
- ⏳ May require role assignment

**Estimated Time**: 15-30 minutes

---

### Option B: Query Without Restricted Fields

**Approach**: Query the table without requesting restricted fields, then fetch them individually.

**Implementation**:

```bash
# Step 1: Query without restricted fields
PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID&sysparm_fields=sys_id,name,version")

# Step 2: For each package, check if linked to change request
while IFS= read -r pkg; do
  PKG_SYS_ID=$(echo "$pkg" | jq -r '.sys_id')

  # Fetch change_request field separately
  PKG_DETAIL=$(curl -s \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Accept: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package/$PKG_SYS_ID?sysparm_fields=change_request")

  EXISTING_CR=$(echo "$PKG_DETAIL" | jq -r '.result.change_request.value // "none"')
  # ... rest of logic
done < <(echo "$BODY" | jq -c '.result[]')
```

**Pros**:
- ✅ No ServiceNow configuration changes
- ✅ Can implement immediately

**Cons**:
- ❌ Performance impact (N+1 queries)
- ❌ Workaround, not a fix
- ❌ May still fail if individual fetch is blocked

**Estimated Time**: 30-45 minutes

---

### Option C: Query by Tool ID Instead of Pipeline ID

**Approach**: Use `tool` field (less likely to be restricted) instead of `pipeline_id` to find packages, then filter by timestamp.

**Implementation**:

```bash
# Query by tool ID (should have permission)
SEARCH_TIME=$(date -u -d '10 minutes ago' '+%Y-%m-%d %H:%M:%S' | sed 's/ /%20/g')

PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=tool=$SN_ORCHESTRATION_TOOL_ID^sys_created_on>=$SEARCH_TIME&sysparm_fields=sys_id,name,version")

# Filter packages by matching GitHub repository in name
while IFS= read -r pkg; do
  PKG_NAME=$(echo "$pkg" | jq -r '.name')

  # Check if package name contains this repo
  if [[ "$PKG_NAME" == *"$GITHUB_REPOSITORY"* ]]; then
    # Process this package
    ...
  fi
done < <(echo "$BODY" | jq -c '.result[]')
```

**Pros**:
- ✅ Uses standard field (`tool`)
- ✅ Less likely to be ACL-restricted
- ✅ No ServiceNow changes needed

**Cons**:
- ❌ Less precise (time-based matching)
- ❌ Could match wrong packages (race condition)
- ❌ Still may fail if `change_request` field is restricted

**Estimated Time**: 45 minutes

---

### Option D: Use ServiceNow DevOps Change API

**Approach**: Use ServiceNow DevOps plugin's native API instead of Table API.

**Research Required**: Investigate if ServiceNow DevOps plugin provides endpoints like:
- `/api/sn_devops/v1/devops/package/query`
- `/api/sn_devops/v1/devops/package/{sys_id}/changeRequest`

**Pros**:
- ✅ Uses intended integration method
- ✅ May bypass field ACLs
- ✅ Better long-term solution

**Cons**:
- ⏳ Requires API documentation research
- ⏳ May not exist or may be unavailable

**Estimated Time**: 2-4 hours (research + implementation)

---

## Recommended Implementation

### Immediate Fix (Option A)

**Grant field-level read permissions** to `github_integration` user on `sn_devops_package` table fields.

**Why**:
1. ✅ Proper solution (not a workaround)
2. ✅ Follows ServiceNow security best practices
3. ✅ Fastest time to resolution
4. ✅ Reusable for future integrations

**Implementation Steps**:

#### Step 1: Verify Current User Roles

```bash
# Run diagnostic script
./scripts/verify-servicenow-devops-tables.sh

# Look for role list for github_integration user
# Expected roles:
# - admin
# - sn_devops.integration_user
# - sn_devops.viewer
# - change_manager
```

#### Step 2: Check Field-Level ACLs in ServiceNow

**Navigate to**: System Security → Access Control (ACL)

**Filter**:
- Table: `sn_devops_package`
- Type: `field`
- Operation: `read`

**Look for ACLs on**:
- `pipeline_id` field
- `change_request` field

**Check**:
- Required roles column
- Script (if scripted ACL)

#### Step 3: Grant Read Permission

**If pipeline_id field has ACL**:

1. Open ACL record
2. Click "Roles" tab
3. Add `sn_devops.integration_user` role (if not present)
4. Save

**If change_request field has ACL**:

1. Open ACL record
2. Verify `change_manager` role is included
3. Ensure `github_integration` user has `change_manager` role

**If no ACL exists** (unlikely):

1. Create new ACL:
   - Table: `sn_devops_package`
   - Field: `pipeline_id`
   - Operation: `read`
   - Roles: `sn_devops.integration_user`

#### Step 4: Clear User Session Cache

**Important**: ServiceNow caches user permissions

1. Log out of ServiceNow (if logged in)
2. Clear browser cache
3. Wait 5 minutes (permission cache TTL)
4. Or run in ServiceNow:
   ```javascript
   gs.getSession().invalidate();
   ```

#### Step 5: Test the Fix

```bash
# Set credentials
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD="..." # from secrets
export GITHUB_RUN_ID="19102042257"

# Test the query manually
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=pipeline_id=$GITHUB_RUN_ID&sysparm_fields=sys_id,name,version,change_request"

# Expected: HTTP 200 with package list (or empty array if no packages)
# If still 403: Check step 2-3 again
```

#### Step 6: Retry Workflow

Trigger a new workflow run or re-run the failed job to verify the fix.

---

### Fallback (Option B or C)

If ServiceNow admin access is not available or permissions cannot be granted, implement **Option C** (query by tool ID) as a temporary workaround.

---

## Testing Strategy

### Pre-Fix Testing

```bash
# Test 1: Verify current failure
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD="..." # from secrets
export GITHUB_RUN_ID="19102042257"

# Run script
./scripts/link-packages-to-change-request.sh

# Expected: HTTP 403 error (confirms issue)
```

### Post-Fix Testing

```bash
# Test 2: Verify fix (after permission grant)
./scripts/link-packages-to-change-request.sh

# Expected:
# - HTTP 200
# - Packages found and linked
# - Exit code 0
```

### Integration Testing

```bash
# Test 3: Full workflow
# Trigger MASTER-PIPELINE.yaml workflow
gh workflow run MASTER-PIPELINE.yaml --ref main

# Monitor:
# 1. Package registration (should succeed)
# 2. Package linkage (should succeed after fix)
# 3. Verify in ServiceNow:
#    - Packages have change_request field populated
#    - Change request shows linked packages
```

---

## ServiceNow Investigation Commands

### Check User Roles

**Navigate to**: User Administration → Users → `github_integration` → Roles

**Or via API**:
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration&sysparm_fields=role.name"
```

### Check Table ACLs

**Navigate to**: System Security → Access Control (ACL)

**Filter**: Name contains `sn_devops_package`

**Or via API**:
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_security_acl?sysparm_query=name=sn_devops_package&sysparm_fields=name,operation,type,roles"
```

### Check Field-Level ACLs

**Navigate to**: System Security → Access Control (ACL)

**Filter**:
- Table: `sn_devops_package`
- Type: `field`

**Look for**: `pipeline_id`, `change_request`, `tool`

### Test Field Access

```bash
# Test reading pipeline_id field
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=1&sysparm_fields=pipeline_id"

# Test reading change_request field
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=1&sysparm_fields=change_request"
```

---

## Implementation Checklist

### ServiceNow Admin Tasks
- [ ] Navigate to System Security → Access Control (ACL)
- [ ] Filter by table: `sn_devops_package`, type: `field`
- [ ] Identify ACLs on `pipeline_id` and `change_request` fields
- [ ] Add `sn_devops.integration_user` role to field ACLs
- [ ] Verify `github_integration` user has required roles
- [ ] Clear user session cache (logout + wait 5 min)
- [ ] Test API query manually (see Testing Strategy)

### Verification Tasks
- [ ] Test script manually: `./scripts/link-packages-to-change-request.sh`
- [ ] Verify HTTP 200 response
- [ ] Verify packages found and linked
- [ ] Check ServiceNow UI: packages linked to change request
- [ ] Trigger full workflow and verify success
- [ ] Monitor next 3 deployments for stability

### Documentation Tasks
- [ ] Update docs with field-level permission requirements
- [ ] Document required roles for `github_integration` user
- [ ] Add troubleshooting section for HTTP 403 errors
- [ ] Update onboarding docs with ServiceNow ACL setup

---

## Related Issues

- **Previous Issue**: SERVICENOW-PACKAGE-LINKING-ISSUE.md (query construction issue - FIXED)
- **Current Issue**: Field-level ACL permission issue (HTTP 403)
- **GitHub Issue**: #56
- **Depends On**: ServiceNow admin access to grant field permissions

---

## Timeline

| Date | Time | Activity | Status |
|------|------|----------|--------|
| 2025-11-05 | 10:13 UTC | Issue first detected | 🔴 CRITICAL |
| 2025-11-05 | 10:20 UTC | Root cause identified (field-level ACL) | 📊 ANALYZED |
| 2025-11-05 | 10:30 UTC | Analysis document created | ✅ DOCUMENTED |
| Pending | - | ServiceNow field permissions granted | ⏳ WAITING |
| Pending | - | Fix tested manually | ⏳ WAITING |
| Pending | - | Workflow verified | ⏳ WAITING |
| Pending | - | Issue closed | ⏳ WAITING |

---

## Additional Resources

### ServiceNow Documentation

- [Access Control Rules](https://docs.servicenow.com/bundle/vancouver-platform-security/page/administer/security/concept/c_AccessControlRules.html)
- [Field-Level Security](https://docs.servicenow.com/bundle/vancouver-platform-security/page/administer/security/concept/c_FieldLevelSecurity.html)
- [DevOps Change Management](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-change-management.html)

### Internal Documentation

- `docs/implemented/SERVICENOW-APPROVAL-WORKFLOW.md` - ServiceNow integration setup
- `scripts/verify-servicenow-devops-tables.sh` - Diagnostic script
- `scripts/link-packages-to-change-request.sh` - Failing script

---

**Document Status**: ✅ Complete
**Last Updated**: 2025-11-05 10:30 UTC
**Next Review**: After fix implementation
**Owner**: DevOps Team / ServiceNow Admin
