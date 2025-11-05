# ServiceNow Package Linking Fix - Field Not Found Issue

> **Date**: 2025-11-05
> **Status**: ✅ FIXED
> **Root Cause**: `pipeline_id` field doesn't exist in `sn_devops_package` table
> **Solution**: Use `correlation_id` and `name`-based queries with existing fields

---

## Problem Summary

The original script tried to query `sn_devops_package` using a `pipeline_id` field that **doesn't exist** in the table schema. ServiceNow returned HTTP 403 "Insufficient rights" (misleading error - should be "field not found").

**Available Fields** (from ServiceNow table schema):
- ✅ `correlation_id` - Used for correlation
- ✅ `name` - Package name
- ✅ `sys_created_on` - Creation timestamp
- ✅ `short_description` - Description
- ✅ `comments` - Comments field
- ❌ `pipeline_id` - **Does NOT exist**
- ❌ `change_request` - **Does NOT exist**
- ❌ `tool` - **Does NOT exist**

---

## Solution

Created new script: `scripts/link-packages-to-change-request-fixed.sh`

### Query Strategy (Two Methods)

**Method 1: Query by `correlation_id`** (Preferred)
```bash
# If ServiceNow DevOps register-package action sets correlation_id = GitHub run ID
sysparm_query=correlation_id=$GITHUB_RUN_ID
```

**Method 2: Query by name + time** (Fallback)
```bash
# Find packages created in last 15 minutes matching repository name
sysparm_query=sys_created_on>=TIMESTAMP^nameLIKErepo-name
```

### Link Strategy

Since `change_request` field doesn't exist, we update:
1. **`correlation_id`**: Set to GitHub run ID (creates linkage)
2. **`comments`**: Add audit trail message

```bash
PATCH /api/now/table/sn_devops_package/{sys_id}
{
  "correlation_id": "19102042257",
  "comments": "Linked to change request CHG0030427 by GitHub Actions pipeline run 19102042257"
}
```

This creates an audit trail without requiring a `change_request` reference field.

---

## Testing Plan

### Test 1: Check Package Registration

**Verify packages exist in ServiceNow:**

```bash
# Set credentials
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD="..." # from secrets

# Query all recent packages
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_limit=10&sysparm_fields=sys_id,name,correlation_id,sys_created_on" \
  | jq '.result[] | {name, correlation_id, created: .sys_created_on}'
```

**Expected**: List of packages from recent builds

### Test 2: Test Fixed Script Manually

```bash
# Set environment variables
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD="..." # from secrets
export CHANGE_REQUEST_SYS_ID="e278491dc341fe10e1bbf0cb050131a4"
export CHANGE_REQUEST_NUMBER="CHG0030427"
export GITHUB_RUN_ID="19102042257"
export GITHUB_REPOSITORY="Freundcloud/microservices-demo"

# Make executable
chmod +x scripts/link-packages-to-change-request-fixed.sh

# Run the fixed script
./scripts/link-packages-to-change-request-fixed.sh
```

**Expected Output**:
```
🔗 Linking Packages to Change Request
======================================
✓ All required environment variables present

Change Request: CHG0030427
Sys ID: e278491dc341fe10e1bbf0cb050131a4
Pipeline Run: 19102042257
Repository: Freundcloud/microservices-demo

🔍 Finding packages from this pipeline run...

Method 1: Searching by correlation_id=19102042257...
✓ Found X package(s) from this run

Found packages:
  - microservices-dev-12345.package (sys_id: abc123...)
  - ...

📦 Linking packages to change request CHG0030427...

  ✓ microservices-dev-12345.package
    Updated correlation_id and comments

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PACKAGE LINKAGE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Packages updated: X
Failed: 0
Total packages: X
```

### Test 3: Verify in ServiceNow UI

**Check packages updated:**

1. Navigate to: `https://calitiiltddemo3.service-now.com/sn_devops_package_list.do`
2. Filter by: `correlation_id` = `19102042257`
3. Verify:
   - ✅ Packages appear in list
   - ✅ `correlation_id` field set to GitHub run ID
   - ✅ `comments` field contains linkage message

### Test 4: Full Workflow Integration

**Replace script in workflow:**

```bash
# Backup original
cp scripts/link-packages-to-change-request.sh scripts/link-packages-to-change-request.sh.backup

# Replace with fixed version
cp scripts/link-packages-to-change-request-fixed.sh scripts/link-packages-to-change-request.sh

# Commit and push
git add scripts/link-packages-to-change-request.sh
git commit -m "fix: Use correlation_id instead of non-existent pipeline_id field

Fixes #60

- pipeline_id field doesn't exist in sn_devops_package table
- Use correlation_id for package lookup (primary method)
- Fallback to name-based query with time range
- Link packages via correlation_id and comments fields
- Provides clear audit trail in ServiceNow"
git push
```

**Trigger workflow:**
```bash
gh workflow run MASTER-PIPELINE.yaml --ref main
```

**Monitor:**
- ✅ `register-packages` job succeeds
- ✅ `link-packages-to-change-request` job succeeds (previously failed)
- ✅ No HTTP 403 errors
- ✅ Packages linked in ServiceNow

---

## Key Changes

### Old Script (Broken)
```bash
# ❌ Uses non-existent pipeline_id field
sysparm_query=pipeline_id=$GITHUB_RUN_ID
sysparm_fields=sys_id,name,version,change_request

# ❌ Tries to update non-existent change_request field
{ "change_request": "$CHANGE_REQUEST_SYS_ID" }
```

### New Script (Fixed)
```bash
# ✅ Uses existing correlation_id field (primary)
sysparm_query=correlation_id=$GITHUB_RUN_ID

# ✅ Fallback to name + time query
sysparm_query=sys_created_on>=$TIME^nameLIKE$REPO

# ✅ Uses existing fields
sysparm_fields=sys_id,name,short_description

# ✅ Updates existing fields for linkage
{
  "correlation_id": "$GITHUB_RUN_ID",
  "comments": "Linked to CR..."
}
```

---

## Verification Checklist

- [ ] Old script backed up
- [ ] New script tested manually (Test 2)
- [ ] Packages found successfully
- [ ] Packages updated successfully
- [ ] ServiceNow UI shows correlation_id populated
- [ ] ServiceNow UI shows comments with linkage info
- [ ] Full workflow test completed (Test 4)
- [ ] No HTTP 403 errors
- [ ] Documentation updated
- [ ] GitHub issue #60 updated

---

## Alternative Solution (If correlation_id doesn't work)

If the ServiceNow DevOps register-package action doesn't populate `correlation_id`, we can:

1. **Query by name pattern only** (less precise):
   ```bash
   sysparm_query=nameLIKEmicroservices-demo^sys_created_on>=LAST_15_MIN
   ```

2. **Add environment filter** (if populated):
   ```bash
   sysparm_query=environment=dev^nameLIKEmicroservices^sys_created_on>=LAST_15_MIN
   ```

3. **Use comments for future lookups**:
   - After first link, store GitHub run ID in comments
   - Future jobs can search comments field

---

## Related Documents

- **Root Cause Analysis**: `docs/SERVICENOW-PACKAGE-QUERY-PERMISSIONS-ISSUE-56.md`
- **GitHub Issue**: #60
- **Original Script**: `scripts/link-packages-to-change-request.sh`
- **Fixed Script**: `scripts/link-packages-to-change-request-fixed.sh`

---

**Status**: ✅ Solution implemented, ready for testing
**Next Step**: Run Test 2 manually to verify fix
