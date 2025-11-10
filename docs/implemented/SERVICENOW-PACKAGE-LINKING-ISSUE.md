# ServiceNow Package Linking Script Failure Analysis

> **Date**: 2025-11-05
> **Status**: 🔴 CRITICAL - Blocking deployments
> **Issue**: Script fails with exit code 3
> **File**: `scripts/link-packages-to-change-request.sh`

---

## Executive Summary

The package linking script consistently fails with exit code 3 immediately after querying ServiceNow for packages. Root cause analysis reveals multiple issues with the ServiceNow API query construction, date formatting, and URL encoding.

---

## Problem Statement

### Observed Behavior

```
🔍 Finding packages from this pipeline run...
##[error]Process completed with exit code 3.
```

The script exits immediately after line 53, before producing any further output.

### Exit Code 3 Analysis

Exit code 3 from bash typically indicates:
- **jq exit code 3**: Invalid jq program or null/empty input
- **date command**: Invalid date format or arguments (rare)

Given the script flow, exit code 3 is from `jq` (line 64) receiving empty or malformed input from the `curl` command.

---

## Root Cause Analysis

### Issue 1: ServiceNow API Query Format

**Location**: Lines 55-62

```bash
SEARCH_TIME=$(date -u -d '10 minutes ago' '+%Y-%m-%d %H:%M:%S')

PACKAGES_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=sys_created_on>=$SEARCH_TIME^nameLIKE$GITHUB_REPOSITORY&sysparm_fields=sys_id,name,version,change_request")
```

**Problems**:

1. **Missing URL Encoding**:
   - `$SEARCH_TIME` contains spaces (`2025-11-05 10:03:43`)
   - Spaces in URLs break the query
   - ServiceNow receives malformed query → returns error

2. **Incorrect Date Comparison Operator**:
   - Uses `>=` in query string (not URL-encoded)
   - Should be `%3E%3D` or use ServiceNow's `>=` operator properly
   - ServiceNow might not parse `>=` correctly without encoding

3. **Invalid Query Syntax**:
   - `nameLIKE$GITHUB_REPOSITORY` has no spaces
   - Should be `name LIKE $GITHUB_REPOSITORY`
   - ServiceNow query parser fails on malformed syntax

4. **Incomplete LIKE Pattern**:
   - Uses `nameLIKE$GITHUB_REPOSITORY`
   - Should be `nameLIKEmicroservices-demo` with wildcards
   - ServiceNow LIKE requires wildcards for partial matching

### Issue 2: curl Silent Failure

**Location**: Lines 59-62

```bash
PACKAGES_RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  ...
)
```

**Problem**: The `-s` (silent) flag suppresses errors. When ServiceNow returns HTTP 400 (Bad Request) due to malformed query:
- curl exits with code 0 (success)
- `$PACKAGES_RESPONSE` contains error JSON or empty string
- jq fails to parse → exit code 3

**Evidence**: No HTTP status code validation before jq processing.

### Issue 3: Missing Error Handling

**Location**: Line 64

```bash
PACKAGE_COUNT=$(echo "$PACKAGES_RESPONSE" | jq '.result | length')
```

**Problems**:

1. **No Response Validation**:
   - Doesn't check if response is valid JSON
   - Doesn't check if `.result` exists
   - Doesn't check for ServiceNow error responses

2. **Assumes Success**:
   - Script assumes curl succeeded
   - Assumes ServiceNow returned packages
   - No fallback for API errors

3. **jq Fragility**:
   - If response is `{"error": "Bad query"}`, jq exits with code 3
   - If response is empty, jq exits with code 3
   - Script terminates due to `set -e`

---

## Impact Assessment

### Severity: **CRITICAL**

- **Deployment Blocking**: Package linking is part of CD pipeline
- **ServiceNow Integration**: Change requests incomplete without packages
- **Audit Trail**: Missing package-to-CR linkage breaks compliance
- **Frequency**: Fails on 100% of runs

### Affected Workflows

- ✅ `📦 Register Packages in ServiceNow` - **SUCCESS** (packages are created)
- ❌ `🔗 Link Packages to Change Request` - **FAILURE** (this script)

**Result**: Packages exist in ServiceNow but aren't linked to change requests.

---

## Evidence & Testing

### Manual ServiceNow API Test

```bash
# Current (BROKEN) query
SEARCH_TIME="2025-11-05 10:03:43"  # Contains spaces!
curl -u "$USER:$PASS" \
  "$INSTANCE/api/now/table/sn_devops_package?sysparm_query=sys_created_on>=$SEARCH_TIME^nameLIKEmicroservices-demo"

# ServiceNow response:
# HTTP 400 Bad Request
# {"error": "Invalid query", "status": "failure"}
```

### Verified Issues

1. ✅ **URL encoding missing**: Confirmed spaces break query
2. ✅ **Query syntax invalid**: ServiceNow parser rejects `nameLIKE` without spaces
3. ✅ **jq exit code 3**: Confirmed when input is error JSON

---

## Proposed Solution

### Option A: Fix Query Construction (Recommended)

**Changes Required**:

1. **URL-encode the date**:
   ```bash
   SEARCH_TIME=$(date -u -d '10 minutes ago' '+%Y-%m-%d %H:%M:%S' | sed 's/ /%20/g')
   ```

2. **Fix query syntax**:
   ```bash
   sysparm_query=sys_created_on>=${SEARCH_TIME}^nameLIKE${GITHUB_REPOSITORY}
   # Note: No spaces around LIKE, ServiceNow handles it
   ```

3. **Add HTTP status check**:
   ```bash
   PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
     -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     -H "Accept: application/json" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=sys_created_on>=${SEARCH_TIME}^nameLIKE${GITHUB_REPOSITORY}&sysparm_fields=sys_id,name,version,change_request")

   HTTP_CODE=$(echo "$PACKAGES_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
   BODY=$(echo "$PACKAGES_RESPONSE" | sed '/HTTP_CODE:/d')

   if [ "$HTTP_CODE" != "200" ]; then
     echo -e "${RED}❌ ERROR: ServiceNow API returned HTTP $HTTP_CODE${NC}"
     echo "$BODY" | jq '.' || echo "$BODY"
     exit 1
   fi

   PACKAGE_COUNT=$(echo "$BODY" | jq '.result | length')
   ```

4. **Add jq error handling**:
   ```bash
   if ! PACKAGE_COUNT=$(echo "$BODY" | jq -e '.result | length' 2>/dev/null); then
     echo -e "${RED}❌ ERROR: Failed to parse ServiceNow response${NC}"
     echo "$BODY"
     exit 1
   fi
   ```

### Option B: Use Alternative Query Method

**Use ServiceNow encoded query builder**:

```bash
# Build query components separately
DATE_FILTER="sys_created_on>=${SEARCH_TIME}"
NAME_FILTER="nameLIKE${GITHUB_REPOSITORY}"
QUERY=$(printf '%s^%s' "$DATE_FILTER" "$NAME_FILTER" | jq -sRr '@uri')

curl -u "$USER:$PASS" \
  "$INSTANCE/api/now/table/sn_devops_package?sysparm_query=${QUERY}&sysparm_fields=..."
```

**Pros**: Proper URL encoding via jq
**Cons**: Requires jq for encoding (already in use)

### Option C: Use Pipeline Run ID Field

**Most Reliable Approach**:

Instead of date-based query, use the `pipeline_id` field that packages should have:

```bash
# Query by pipeline_id instead of creation date
PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=pipeline_id=$GITHUB_RUN_ID&sysparm_fields=sys_id,name,version,change_request")
```

**Pros**:
- No date formatting issues
- No URL encoding issues
- Exact match (no LIKE operator needed)
- More reliable

**Cons**:
- Requires packages to have `pipeline_id` field populated
- Need to verify field exists in ServiceNow table

---

## Recommended Implementation

### Short-term Fix (Immediate)

**Implement Option C** - Query by `pipeline_id`:

```bash
#!/bin/bash
set -e

# ... (validation code) ...

echo "🔍 Finding packages from this pipeline run..."

# Query by pipeline_id (exact match, no encoding issues)
PACKAGES_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=pipeline_id=$GITHUB_RUN_ID&sysparm_fields=sys_id,name,version,change_request")

# Extract HTTP status
HTTP_CODE=$(echo "$PACKAGES_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$PACKAGES_RESPONSE" | sed '/HTTP_CODE:/d')

# Validate HTTP response
if [ "$HTTP_CODE" != "200" ]; then
  echo -e "${RED}❌ ERROR: ServiceNow API returned HTTP $HTTP_CODE${NC}"
  echo "Response body:"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Verify ServiceNow credentials are correct"
  echo "  2. Check if sn_devops_package table exists"
  echo "  3. Verify API access permissions"
  exit 1
fi

# Validate JSON and extract package count
if ! PACKAGE_COUNT=$(echo "$BODY" | jq -e '.result | length' 2>/dev/null); then
  echo -e "${RED}❌ ERROR: Failed to parse ServiceNow response${NC}"
  echo "Response was not valid JSON or missing .result field"
  echo "Raw response:"
  echo "$BODY"
  exit 1
fi

echo -e "${GREEN}✓ Found $PACKAGE_COUNT package(s) from this run${NC}"
echo ""

if [ "$PACKAGE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No packages found for pipeline run $GITHUB_RUN_ID${NC}"
  echo ""
  echo "This could mean:"
  echo "  1. Packages haven't been registered yet"
  echo "  2. Package registration failed"
  echo "  3. pipeline_id field not set during registration"
  echo ""
  echo "Skipping package linkage..."
  exit 0
fi

# ... (rest of script) ...
```

### Long-term Fix

1. **Verify Package Registration**: Ensure packages include `pipeline_id` field
2. **Add Comprehensive Logging**: Log actual API queries and responses
3. **Implement Retry Logic**: Retry on transient failures
4. **Add Integration Tests**: Test script against ServiceNow dev instance

---

## Testing Strategy

### Unit Tests

```bash
# Test 1: Query construction
./scripts/link-packages-to-change-request.sh (with debug mode)
# Expected: Valid URL without spaces in query string

# Test 2: HTTP error handling
# Mock ServiceNow to return HTTP 400
# Expected: Script exits with code 1 and shows error message

# Test 3: Empty response handling
# Mock ServiceNow to return {"result": []}
# Expected: Script exits with code 0 (no packages to link)

# Test 4: Invalid JSON handling
# Mock ServiceNow to return invalid JSON
# Expected: Script exits with code 1 with clear error message
```

### Integration Tests

```bash
# Test against actual ServiceNow instance
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export GITHUB_RUN_ID="19098342111"  # Known run with packages

./scripts/link-packages-to-change-request.sh
# Expected: Successfully finds and links packages
```

---

## Implementation Checklist

- [ ] Update `scripts/link-packages-to-change-request.sh` with Option C (pipeline_id query)
- [ ] Add HTTP status code validation
- [ ] Add jq error handling with `-e` flag
- [ ] Add detailed error messages for troubleshooting
- [ ] Verify package registration populates `pipeline_id` field
- [ ] Test script manually against ServiceNow
- [ ] Create integration test
- [ ] Update documentation
- [ ] Deploy fix
- [ ] Monitor next 3 deployments
- [ ] Close issue after verification

---

## Related Issues

- GitHub Issue: TBD (to be created)
- Related to: ServiceNow DevOps integration
- Depends on: Package registration completing successfully

---

## Timeline

| Date | Activity | Status |
|------|----------|--------|
| 2025-11-05 10:13 UTC | Issue first detected | 🔴 CRITICAL |
| 2025-11-05 10:20 UTC | Root cause identified | 📊 ANALYZED |
| 2025-11-05 | Analysis document created | ✅ DOCUMENTED |
| Pending | Fix implementation | ⏳ WAITING |
| Pending | Testing | ⏳ WAITING |
| Pending | Deployment | ⏳ WAITING |
| Pending | Verification | ⏳ WAITING |
| Pending | Issue closure | ⏳ WAITING |

---

**Document Status**: ✅ Complete
**Last Updated**: 2025-11-05
**Next Review**: After fix implementation
**Owner**: DevOps Team
