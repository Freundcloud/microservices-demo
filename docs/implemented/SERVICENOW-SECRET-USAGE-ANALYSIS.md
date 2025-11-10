# ServiceNow Secret Usage Pattern Analysis

> **Date**: 2025-01-05
> **Status**: 🔴 CRITICAL ISSUE IDENTIFIED
> **Issue**: [#47](https://github.com/Freundcloud/microservices-demo/issues/47)
> **File**: `.github/workflows/servicenow-change-rest.yaml`
> **Impact**: All DevOps table uploads have "null" tool field

---

## Executive Summary

The `SN_ORCHESTRATION_TOOL_ID` secret exists in GitHub Actions secrets repository, but is being used **inconsistently** throughout the workflow. Secrets are referenced directly in shell scripts without being passed through the `env:` section first, causing:

- ❌ Tool field shows "null" in ServiceNow records
- ❌ Difficult debugging and validation
- ❌ Inconsistent behavior across steps
- ❌ Violates GitHub Actions best practices

### Root Cause

**Inconsistent Secret Usage Pattern**: Secrets are used directly via `${{ secrets.SECRET_NAME }}` in shell scripts instead of being passed through the `env:` section as environment variables.

---

## Secret Verification

### Confirmed: Secret Exists

```bash
$ gh secret list --repo Freundcloud/microservices-demo | grep SN_ORCHESTRATION_TOOL_ID
SN_ORCHESTRATION_TOOL_ID    2025-11-04T13:49:31Z
```

✅ **Secret is present and was updated on November 4, 2025**

### Expected Value

The secret should contain:
```
f62c4e49c3fcf614e1bbf0cb050131ef
```

This is the sys_id of the "GithHubARC" tool in ServiceNow:
```bash
$ curl -s -u "$USER:$PASS" \
  "$INSTANCE/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef" \
  | jq -r '.result.name'

GithHubARC
```

---

## Problem Analysis

### Current (Incorrect) Pattern

**File**: `.github/workflows/servicenow-change-rest.yaml`

#### Example 1: Lines 604-637 - DevOps Pipeline Link

```yaml
- name: Link Change Request to DevOps Pipeline
  if: steps.create-cr.outputs.change_sys_id != ''
  continue-on-error: true
  env:
    CHANGE_SYSID: ${{ steps.create-cr.outputs.change_sys_id }}
    CHANGE_NUMBER: ${{ steps.create-cr.outputs.change_number }}
    # ❌ MISSING: SN_ORCHESTRATION_TOOL_ID
    # ❌ MISSING: SERVICENOW_USERNAME
    # ❌ MISSING: SERVICENOW_PASSWORD
    # ❌ MISSING: SERVICENOW_INSTANCE_URL
  run: |
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d '{
        "change_request": "'"$CHANGE_SYSID"'",
        "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
      }' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_change_reference")
```

**Problems**:
1. ❌ Secrets used directly: `${{ secrets.SERVICENOW_USERNAME }}`
2. ❌ Not passed through `env:` section
3. ❌ No validation before use
4. ❌ Hard to debug if secret is empty or malformed
5. ❌ Inconsistent with `CHANGE_SYSID` (which IS in env)

#### Example 2: Lines 806-1021 - Test Summaries

```yaml
- name: Create Test Summaries in DevOps Workspace
  if: steps.create-cr.outputs.change_sys_id != ''
  continue-on-error: true
  env:
    CHANGE_SYSID: ${{ steps.create-cr.outputs.change_sys_id }}
    CHANGE_NUMBER: ${{ steps.create-cr.outputs.change_number }}
    # ❌ MISSING: All ServiceNow secrets
  run: |
    # Unit Test Summary (line 841)
    "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"

    # Security Scan Summary (line 904)
    "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"

    # SonarCloud Summary (line 960)
    "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"

    # Smoke Test Summary (line 1014)
    "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
```

**Same Problems**: Used 4 times in the same step, all directly without env section.

### Why This Pattern Fails

#### 1. Shell Interpolation Issues

When you use `${{ secrets.SECRET }}` directly in a shell script:

```bash
# GitHub Actions interpolates the secret BEFORE passing to shell
curl ... -d '{"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"}'

# If secret is empty or null, this becomes:
curl ... -d '{"tool": ""}'

# Or worse, if special characters exist:
curl ... -d '{"tool": "value-with-$pecial-chars"}'
# Shell might try to expand $pecial as a variable!
```

#### 2. No Validation Possible

```yaml
# Can't validate because secret is interpolated at YAML parse time
run: |
  # This doesn't work as expected:
  if [ -z "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}" ]; then
    echo "Secret is empty"
  fi
  # GitHub Actions evaluates ${{ }} BEFORE the shell sees it
```

#### 3. Inconsistent Behavior

Some environment variables are passed through `env:`:
```yaml
env:
  CHANGE_SYSID: ${{ steps.create-cr.outputs.change_sys_id }}  # ✅ Correct pattern
```

But secrets are used directly:
```yaml
"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"  # ❌ Wrong pattern
```

This inconsistency makes the code harder to maintain and debug.

---

## GitHub Actions Best Practices

### Correct Pattern

**From GitHub Actions Documentation**:

> **Best Practice**: Pass secrets to environment variables, then use the environment variables in your script.

**Why**:
1. ✅ Consistent behavior across all secrets and variables
2. ✅ Can validate values before use
3. ✅ Shell sees actual values, not interpolated strings
4. ✅ Easier to debug
5. ✅ More secure (limits secret exposure)

### Example: Correct Usage

```yaml
- name: Link Change Request to DevOps Pipeline
  if: steps.create-cr.outputs.change_sys_id != ''
  continue-on-error: true
  env:
    # Step outputs
    CHANGE_SYSID: ${{ steps.create-cr.outputs.change_sys_id }}
    CHANGE_NUMBER: ${{ steps.create-cr.outputs.change_number }}
    # Secrets - PASS THROUGH ENV
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
  run: |
    echo "🔗 Linking CR $CHANGE_NUMBER to DevOps workspace..."

    # Validate secrets BEFORE use
    if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
      echo "❌ ERROR: SN_ORCHESTRATION_TOOL_ID not set"
      echo "   Please verify secret exists in GitHub Actions"
      exit 1
    fi

    if [ "$SN_ORCHESTRATION_TOOL_ID" = "null" ]; then
      echo "⚠️  WARNING: SN_ORCHESTRATION_TOOL_ID is set to literal 'null'"
      echo "   Should be: f62c4e49c3fcf614e1bbf0cb050131ef"
    fi

    # Use environment variables (not secrets) in shell
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X POST \
      -d '{
        "change_request": "'"$CHANGE_SYSID"'",
        "pipeline_name": "Deploy to ${{ inputs.environment }}",
        "pipeline_id": "${{ github.run_id }}",
        "tool": "'"$SN_ORCHESTRATION_TOOL_ID"'"
      }' \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference")

    # Validate response
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

    if [ "$HTTP_CODE" = "201" ]; then
      TOOL_VALUE=$(echo "$BODY" | jq -r '.result.tool.value // .result.tool // "null"')
      echo "✅ Pipeline linked (tool: $TOOL_VALUE)"

      if [ "$TOOL_VALUE" = "null" ]; then
        echo "⚠️  WARNING: Tool field is 'null' in ServiceNow"
        echo "   This indicates the secret value is empty or 'null'"
      fi
    else
      echo "⚠️  Failed (HTTP $HTTP_CODE)"
      echo "$BODY" | jq '.'
    fi
```

**Key Improvements**:
1. ✅ All secrets in `env:` section
2. ✅ Validation before use
3. ✅ Clear error messages
4. ✅ Environment variables used in shell (not secret expressions)
5. ✅ Response validation checks tool field

---

## Affected Locations

### All Steps Using SN_ORCHESTRATION_TOOL_ID

| Line | Step Name | Usage | Status |
|------|-----------|-------|--------|
| 623 | Link Change Request to DevOps Pipeline | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 741 | Register Test Results (Performance) | `if [ -z "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}" ]` | ❌ Wrong |
| 762 | Register Test Results (Performance) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 841 | Create Test Summaries (Unit Tests) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 904 | Create Test Summaries (Security) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 960 | Create Test Summaries (SonarCloud) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 1014 | Create Test Summaries (Smoke Tests) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |
| 1392 | Register Test Results (Other) | `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` | ❌ Wrong |

**Total**: 8 locations need fixing

### All Steps Using ServiceNow Credentials

Almost ALL steps in the workflow use ServiceNow secrets directly without env section:
- `SERVICENOW_USERNAME`
- `SERVICENOW_PASSWORD`
- `SERVICENOW_INSTANCE_URL`

**Recommendation**: Fix ALL secret usage, not just `SN_ORCHESTRATION_TOOL_ID`

---

## Affected ServiceNow Tables

All these tables receive "null" tool field due to incorrect secret usage:

1. **sn_devops_change_reference** (line 623)
   - Links change requests to pipelines
   - Used by Change Velocity dashboard

2. **sn_devops_test_summary** (lines 841, 904, 960, 1014)
   - Aggregated test results
   - Used by DORA metrics

3. **sn_devops_performance_test_summary** (line 762)
   - Performance/smoke test results
   - Used by performance tracking

4. **sn_devops_test_result** (line 1392)
   - Individual test results
   - Used by detailed test tracking

---

## Solution Design

### Phase 1: Standardize All Secret Usage

**Update Pattern for ALL Steps**:

```yaml
- name: [Step Name]
  env:
    # Pass ALL secrets through env
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    # Plus any step-specific variables
  run: |
    # Validate secrets
    if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
      echo "❌ ERROR: SN_ORCHESTRATION_TOOL_ID not set"
      exit 1
    fi

    # Use env variables (not secret expressions) in shell
    curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      ... \
      -d '{"tool": "'"$SN_ORCHESTRATION_TOOL_ID"'"}' \
      "$SERVICENOW_INSTANCE_URL/..."
```

### Phase 2: Add Comprehensive Validation

```yaml
# Add as first step in workflow
- name: Validate ServiceNow Secrets
  run: |
    echo "🔍 Validating ServiceNow configuration..."

    ERRORS=0

    if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
      echo "❌ SN_ORCHESTRATION_TOOL_ID not set"
      ERRORS=$((ERRORS + 1))
    elif [ ${#SN_ORCHESTRATION_TOOL_ID} -ne 32 ]; then
      echo "❌ SN_ORCHESTRATION_TOOL_ID wrong length (expected 32, got ${#SN_ORCHESTRATION_TOOL_ID})"
      ERRORS=$((ERRORS + 1))
    else
      echo "✅ SN_ORCHESTRATION_TOOL_ID set (length: ${#SN_ORCHESTRATION_TOOL_ID})"
    fi

    if [ -z "$SERVICENOW_INSTANCE_URL" ]; then
      echo "❌ SERVICENOW_INSTANCE_URL not set"
      ERRORS=$((ERRORS + 1))
    else
      echo "✅ SERVICENOW_INSTANCE_URL set"
    fi

    if [ $ERRORS -gt 0 ]; then
      echo ""
      echo "❌ $ERRORS configuration error(s) found"
      echo "Please check GitHub Actions secrets"
      exit 1
    fi

    echo ""
    echo "✅ All ServiceNow secrets configured correctly"
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

### Phase 3: Response Validation

Add to EVERY ServiceNow API call:

```bash
# After creating record, check tool field
if [ "$HTTP_CODE" = "201" ]; then
  TOOL_VALUE=$(echo "$BODY" | jq -r '.result.tool.value // .result.tool // "null"')

  if [ "$TOOL_VALUE" = "null" ]; then
    echo "⚠️  WARNING: Tool field is 'null' in created record"
    echo "   Secret value: ${SN_ORCHESTRATION_TOOL_ID:0:10}..."
    echo "   Check secret is set correctly"
  else
    echo "✅ Tool field: $TOOL_VALUE"
  fi
fi
```

---

## Testing Strategy

### 1. Verify Secret Value in Workflow

Add diagnostic step:

```yaml
- name: Debug Secret Configuration
  run: |
    echo "Tool ID length: ${#SN_ORCHESTRATION_TOOL_ID}"
    echo "Tool ID (first 10 chars): ${SN_ORCHESTRATION_TOOL_ID:0:10}"
    echo "Tool ID (last 4 chars): ${SN_ORCHESTRATION_TOOL_ID: -4}"
  env:
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

Expected output:
```
Tool ID length: 32
Tool ID (first 10 chars): f62c4e49c3
Tool ID (last 4 chars): 31ef
```

### 2. Local Testing Script

```bash
#!/bin/bash
# File: /tmp/test-secret-pattern.sh

echo "Testing secret usage patterns..."

# Simulate secret value
export SN_ORCHESTRATION_TOOL_ID="f62c4e49c3fcf614e1bbf0cb050131ef"

# Test 1: Direct variable in JSON
echo ""
echo "Test 1: Using environment variable"
JSON='{"tool": "'"$SN_ORCHESTRATION_TOOL_ID"'"}'
echo "$JSON" | jq '.'
TOOL=$(echo "$JSON" | jq -r '.tool')
if [ "$TOOL" = "null" ]; then
  echo "❌ FAILED: Tool is null"
else
  echo "✅ PASSED: Tool = $TOOL"
fi

# Test 2: Empty secret
echo ""
echo "Test 2: Empty secret"
SN_ORCHESTRATION_TOOL_ID=""
JSON='{"tool": "'"$SN_ORCHESTRATION_TOOL_ID"'"}'
echo "$JSON" | jq '.'
TOOL=$(echo "$JSON" | jq -r '.tool')
if [ "$TOOL" = "" ] || [ "$TOOL" = "null" ]; then
  echo "✅ PASSED: Detected empty secret"
else
  echo "❌ FAILED: Should be empty"
fi

# Test 3: Validation
echo ""
echo "Test 3: Validation"
if [ -z "$SN_ORCHESTRATION_TOOL_ID" ]; then
  echo "✅ PASSED: Validation detected empty secret"
else
  echo "❌ FAILED: Validation should fail"
fi
```

### 3. End-to-End Test

After implementing fix:

1. **Trigger Workflow**:
   ```bash
   gh workflow run MASTER-PIPELINE.yaml -f environment=dev
   ```

2. **Check Logs**:
   - Look for validation messages
   - Verify tool field values logged
   - Confirm no "null" warnings

3. **Verify ServiceNow Records**:
   ```bash
   # Check sn_devops_change_reference
   curl -s -u "$USER:$PASS" \
     "$INSTANCE/api/now/table/sn_devops_change_reference?sysparm_query=sys_created_onONToday&sysparm_fields=sys_id,tool" \
     | jq '.result[] | {sys_id, tool: .tool.value}'

   # Check sn_devops_test_summary
   curl -s -u "$USER:$PASS" \
     "$INSTANCE/api/now/table/sn_devops_test_summary?sysparm_query=sys_created_onONToday&sysparm_fields=name,tool" \
     | jq '.result[] | {name, tool: .tool.value}'
   ```

   Expected: Tool value should be `f62c4e49c3fcf614e1bbf0cb050131ef`, NOT "null"

---

## Implementation Checklist

### Phase 1: Fix Secret Usage Pattern ⏳
- [ ] Create validation step at workflow start
- [ ] Update "Link Change Request" step (lines 604-637)
- [ ] Update "Register Test Results" step (lines 643-804)
- [ ] Update "Create Test Summaries" step (lines 806-1021)
  - [ ] Unit test summary (line 841)
  - [ ] Security scan summary (line 904)
  - [ ] SonarCloud summary (line 960)
  - [ ] Smoke test summary (line 1014)
- [ ] Update remaining steps using ServiceNow API

### Phase 2: Add Response Validation ⏳
- [ ] Add tool field check after each API call
- [ ] Log tool value for verification
- [ ] Warn if tool is "null"

### Phase 3: Testing ⏳
- [ ] Create local test script
- [ ] Run manual workflow test
- [ ] Verify all ServiceNow records
- [ ] Confirm tool field populated correctly

### Phase 4: Documentation ⏳
- [ ] Update implementation docs
- [ ] Add troubleshooting guide
- [ ] Document best practices

---

## Expected Results

### Before Fix

**Workflow Logs**:
```
✅ Pipeline linked to DevOps workspace (ref: abc123)
✅ Unit test summary created (sys_id: def456)
# No indication tool field is null
```

**ServiceNow Records**:
```json
{
  "tool": {
    "link": "https://.../sn_devops_tool/null",
    "value": "null"
  }
}
```

### After Fix

**Workflow Logs**:
```
🔍 Validating ServiceNow configuration...
✅ SN_ORCHESTRATION_TOOL_ID set (length: 32)
✅ All ServiceNow secrets configured correctly

✅ Pipeline linked to DevOps workspace (ref: abc123)
   Tool field: f62c4e49c3fcf614e1bbf0cb050131ef

✅ Unit test summary created (sys_id: def456)
   Tool field: f62c4e49c3fcf614e1bbf0cb050131ef
```

**ServiceNow Records**:
```json
{
  "tool": {
    "link": "https://.../sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef",
    "value": "f62c4e49c3fcf614e1bbf0cb050131ef"
  }
}
```

---

## Related Documentation

- **GitHub Issue**: [#47](https://github.com/Freundcloud/microservices-demo/issues/47)
- **Test Summary Fix**: [SERVICENOW-TEST-SUMMARY-IMPLEMENTATION.md](./SERVICENOW-TEST-SUMMARY-IMPLEMENTATION.md)
- **Performance Test Fix**: [SERVICENOW-PERFORMANCE-TEST-IMPLEMENTATION.md](./SERVICENOW-PERFORMANCE-TEST-IMPLEMENTATION.md)
- **GitHub Actions Best Practices**: [Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**Document Status**: ✅ Analysis Complete
**Last Updated**: 2025-01-05
**Priority**: 🔴 HIGH
**Estimated Effort**: 3-4 hours
**Impact**: Fixes tool field null issue across ALL DevOps tables
