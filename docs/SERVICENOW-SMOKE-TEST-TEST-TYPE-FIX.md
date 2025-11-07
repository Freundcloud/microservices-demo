# ServiceNow Smoke Test - Test Type Field Issue

**Date**: 2025-11-07
**Status**: 🔍 **INVESTIGATION** - Test Type field showing empty
**Record**: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_performance_test_summary.do?sys_id=fe6c4775c3057a50b71ef44c050131b6

---

## Problem

The smoke test performance summary record was successfully created (sys_id: `fe6c4775c3057a50b71ef44c050131b6`), but the **Test Type** field is empty/null.

### Current Payload (servicenow-update-change.yaml, line 195)

```json
{
  "name": "Smoke Tests - Post-Deployment (dev)",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "url": "https://github.com/Freundcloud/microservices-demo/actions/runs/19166856977",
  "test_type": "functional",  // ← String value sent
  ...
}
```

### Expected Behavior

The Test Type field should display "Functional" (or appropriate test type).

---

## Root Cause

The `test_type` field in `sn_devops_performance_test_summary` is likely a **reference field** pointing to the `sn_devops_test_type` table, not a string field.

### Evidence

1. **Table Relationship**: `sn_devops_test_type` table exists (confirmed in sys_db_object.json)
2. **Common ServiceNow Pattern**: Test type fields are typically references to lookup tables
3. **String Value Rejected**: Sending `"test_type": "functional"` as a string doesn't populate the field

### Expected Field Type

The `test_type` field should accept:
- **sys_id** of a record in `sn_devops_test_type` table
- **OR** string value if it's a choice field (not reference)

---

## Investigation Steps

### 1. Check Field Type

Query ServiceNow to understand the field type:

```bash
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_performance_test_summary^element=test_type" \
  | jq '.result[] | {element, internal_type, reference}'
```

**Expected Results**:
- If `internal_type: "reference"` → Need sys_id from `sn_devops_test_type` table
- If `internal_type: "choice"` → Need valid choice value
- If `internal_type: "string"` → Current approach should work

### 2. Query Available Test Types

If reference field, query available test types:

```bash
curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_type?sysparm_fields=sys_id,name,label" \
  | jq '.result[] | {sys_id, name, label}'
```

**Expected Output** (example):
```json
[
  {
    "sys_id": "abc123...",
    "name": "functional",
    "label": "Functional Test"
  },
  {
    "sys_id": "def456...",
    "name": "performance",
    "label": "Performance Test"
  },
  {
    "sys_id": "ghi789...",
    "name": "unit",
    "label": "Unit Test"
  }
]
```

### 3. Check If Test Types Exist

If `sn_devops_test_type` table is empty, we may need to:
1. Create test type records manually in ServiceNow
2. OR use a different field/table
3. OR check if DevOps plugin provides default test types

---

## Possible Solutions

### Solution A: Use sys_id for Test Type (If Reference Field)

**If test_type is a reference field**, we need to:

1. **Query `sn_devops_test_type` for "functional" test**:
   ```bash
   curl -s \
     -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     -H "Accept: application/json" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_type?sysparm_query=name=functional&sysparm_fields=sys_id" \
     | jq -r '.result[0].sys_id'
   ```

2. **Update workflow to use sys_id**:
   ```yaml
   # In servicenow-update-change.yaml

   # First, query for test type sys_id
   TEST_TYPE_SYS_ID=$(curl -s \
     -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
     -H "Accept: application/json" \
     "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_test_type?sysparm_query=name=functional&sysparm_fields=sys_id" \
     | jq -r '.result[0].sys_id // "null"')

   # Then use in payload
   RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
     -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{
       "name": "Smoke Tests - Post-Deployment (${{ inputs.environment }})",
       "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
       "test_type": "'$TEST_TYPE_SYS_ID'",  // ← Use sys_id
       ...
     }' \
     "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_performance_test_summary")
   ```

**Pros**:
- ✅ Correct approach if test_type is a reference field
- ✅ Will properly link to test type record

**Cons**:
- ⚠️ Additional API call required
- ⚠️ Requires test type record to exist

---

### Solution B: Create Test Type Record (If Missing)

If `sn_devops_test_type` table is empty or missing "functional" type:

```bash
# Create "functional" test type
curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "name": "functional",
    "label": "Functional Test",
    "description": "Post-deployment smoke tests and functional validation"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_type"
```

**Pros**:
- ✅ One-time setup
- ✅ Test type available for all future tests

**Cons**:
- ⚠️ Manual ServiceNow configuration required
- ⚠️ May conflict with DevOps plugin defaults

---

### Solution C: Use Different Table (sn_devops_test_summary)

If `sn_devops_performance_test_summary` requires specific test types we don't have, consider using the parent table `sn_devops_test_summary` instead:

```yaml
# Change table from:
"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary"

# To:
"$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_summary"
```

**Pros**:
- ✅ More generic table, fewer constraints
- ✅ May not require test_type field

**Cons**:
- ❌ Loses performance-specific fields (avg_time, throughput, etc.)
- ❌ Not semantically correct for smoke tests

---

### Solution D: Omit test_type Field (If Optional)

If test_type is optional, try removing it from the payload:

```json
{
  "name": "Smoke Tests - Post-Deployment (dev)",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "url": "...",
  // Remove: "test_type": "functional",
  "start_time": "...",
  ...
}
```

**Pros**:
- ✅ Simplest approach
- ✅ Record still created

**Cons**:
- ⚠️ Test type field remains empty
- ⚠️ May not meet compliance/audit requirements

---

## Recommended Approach

**Investigate first, then fix**:

1. **Run diagnostic queries** (see Investigation Steps above)
2. **Determine field type** (reference vs choice vs string)
3. **Query available test types** (if reference field)
4. **Choose appropriate solution**:
   - If reference field + test types exist → Use Solution A (sys_id lookup)
   - If reference field + test types missing → Use Solution B (create test type)
   - If string/choice field → Current approach should work (investigate why it's not)
   - If optional and not critical → Use Solution D (omit field)

---

## Testing Plan

Once fix is implemented:

1. **Trigger workflow**:
   ```bash
   gh workflow run "MASTER-PIPELINE.yaml" \
     --repo Freundcloud/microservices-demo \
     --ref main \
     -f environment=dev
   ```

2. **Verify test_type populated**:
   - Navigate to: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_performance_test_summary_list.do
   - Find latest "Smoke Tests - Post-Deployment (dev)" record
   - Check "Test Type" field shows value (e.g., "Functional")

3. **API verification**:
   ```bash
   curl -s \
     -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     -H "Accept: application/json" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_performance_test_summary/fe6c4775c3057a50b71ef44c050131b6?sysparm_display_value=all" \
     | jq '.result.test_type'
   ```

   **Expected**: `{"display_value": "Functional", "value": "abc123..."}`

---

## Next Steps

**Immediate**:
1. Run diagnostic queries to determine field type
2. Query available test types in `sn_devops_test_type` table
3. Choose appropriate solution based on findings
4. Update workflow if needed
5. Test and verify

**User Action Required**:
- Need ServiceNow credentials to run diagnostic queries
- Need decision on which solution to implement

---

## Related Files

- `.github/workflows/servicenow-update-change.yaml` (line 195: test_type payload)
- `docs/SERVICENOW-SMOKE-TEST-INTEGRATION-ANALYSIS.md` (original analysis)
- `sys_db_object.json` (table schema reference)

---

**Status**: 🔍 **AWAITING INVESTIGATION** - Need to query ServiceNow for field type and available test types
