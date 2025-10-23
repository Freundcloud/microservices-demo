# ServiceNow DevOps Change Troubleshooting Guide

> Status: Internal Server Error persists despite all required fields
> Created: 2025-10-23
> Issue: ServiceNow DevOps Change GitHub Action v6.1.0 returns 500 Internal Server Error

## Problem Summary

The ServiceNow DevOps Change GitHub Action consistently returns:
```
Error: Internal server error. An unexpected error occurred while processing the request.
```

**Key Finding**: The standard ServiceNow REST API (`/api/now/table/change_request`) works perfectly, but the ServiceNow DevOps Change action fails.

## Investigation Timeline

### 1. Initial Diagnosis
- Created diagnostic script ([scripts/test-servicenow-change-request.sh](../scripts/test-servicenow-change-request.sh))
- Tested ServiceNow REST API directly with curl
- **Result**: All 3 tests passed ✅
  - Test 1: Minimal change request (CHG0030105) ✅
  - Test 2: With custom GitHub fields (CHG0030106) ✅
  - Test 3: With multi-line description (CHG0030107) ✅

**Conclusion**: Our JSON format, custom fields (u_github_*), and multi-line handling are all correct.

### 2. Required Fields Analysis
Consulted official ServiceNow DevOps Change documentation and added:
- `implementation_plan` - Deployment process description
- `backout_plan` - Rollback procedure
- `test_plan` - Pre/post deployment testing

Verified these fields work via REST API (CHG0030108) ✅

### 3. Current Status
- ❌ ServiceNow DevOps Change action still returns 500 Internal Server Error
- ✅ ServiceNow REST API works perfectly with same data
- ✅ All required fields present and validated
- ✅ Custom fields (u_github_*) exist and are writable

## Root Cause Analysis

The issue is NOT with our data or JSON structure. The ServiceNow DevOps Change action uses a **different API endpoint** than `/api/now/table/change_request`, and that endpoint appears to have additional validation, configuration requirements, or plugin issues.

### Possible Causes

1. **ServiceNow DevOps Plugin Not Fully Configured**
   - The DevOps API may require additional plugin configuration
   - Could need DevOps-specific settings in ServiceNow

2. **Missing DevOps-Specific Configuration**
   - Tool registration may be incomplete
   - DevOps workspace may not be properly configured
   - Pipeline/orchestration settings missing

3. **API Version Mismatch**
   - GitHub Action v6.1.0 may be incompatible with ServiceNow instance version
   - DevOps plugin version may be outdated

4. **ServiceNow Instance Permissions**
   - The `github_integration` user may lack specific DevOps API permissions
   - May need additional roles beyond standard change management

5. **Assignment Group Requirement**
   - Official examples include `assignment_group` field
   - May be required by DevOps API even if not documented as required

## Troubleshooting Steps

### Step 1: Verify ServiceNow DevOps Plugin Installation

1. **Log into ServiceNow** as admin
2. **Navigate to**: System Applications > All Available Applications
3. **Search for**: "DevOps Change"
4. **Verify**: ServiceNow DevOps Change plugin is installed and activated
5. **Check version**: Ensure compatible with GitHub Action v6.1.0

### Step 2: Check DevOps Configuration

1. **Navigate to**: DevOps > Configuration
2. **Verify**: GitHub tool (GitHubARC) is fully configured
3. **Check**: All required fields in tool configuration
4. **Validate**: Tool ID matches `SN_ORCHESTRATION_TOOL_ID` secret

### Step 3: Verify User Permissions

Check if `github_integration` user has required roles:

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_query=user_name=github_integration&sysparm_display_value=true" \
  | jq '.result[0].roles'
```

**Required roles**:
- `sn_devops.devops_user` (or `sn_devops.devops_admin`)
- `itil` or `itil_admin`
- `change_manager` (or equivalent)

### Step 4: Check ServiceNow Instance Logs

1. **Navigate to**: System Logs > System Log > All
2. **Filter by**: Last 15 minutes
3. **Search for**: "DevOps" or "Change" or "500" or "Internal Server Error"
4. **Look for**: Specific error message that explains the failure

### Step 5: Test with Assignment Group

Try adding an assignment_group field (if groups exist in your instance):

```bash
# List available groups
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user_group?sysparm_limit=5" \
  | jq '.result[] | {sys_id, name}'

# Create change with assignment_group
# (Use sys_id from above query)
```

### Step 6: Try Token-Based Authentication

The GitHub Action supports two authentication methods:
1. **Basic Auth** (current - using username/password)
2. **Token Auth** (recommended - using integration token)

**To switch to token auth**:
1. In ServiceNow, generate a DevOps integration token
2. Update secrets in GitHub:
   - Remove: `SN_DEVOPS_USER`, `SN_DEVOPS_PASSWORD`
   - Add: `SN_DEVOPS_INTEGRATION_TOKEN`
3. Update workflow to use `devops-integration-token` instead of `devops-integration-user-name`/`devops-integration-user-password`

### Step 7: Contact ServiceNow Support

If all above steps fail, the issue may be with the ServiceNow instance configuration or DevOps plugin itself. Contact ServiceNow support with:

1. **Error message**: "Internal server error" from DevOps Change API
2. **Workflow run**: https://github.com/Freundcloud/microservices-demo/actions/runs/18760313980
3. **Proof of working REST API**: Change requests CHG0030105-CHG0030108 created successfully via standard API
4. **GitHub Action version**: v6.1.0
5. **ServiceNow instance**: calitiiltddemo3.service-now.com

## Workaround: Use ServiceNow REST API Directly

Since the standard REST API works perfectly, we can bypass the ServiceNow DevOps Change action entirely and use curl:

```yaml
- name: Create ServiceNow Change Request
  id: create-change
  run: |
    CHANGE_JSON=$(jq -n \
      --arg short_desc "Deploy to ${{ inputs.environment }} - ${{ github.ref_name }} by ${{ github.actor }}" \
      --arg desc "Automated deployment via GitHub Actions..." \
      --arg impl_plan "..." \
      --arg backout_plan "..." \
      --arg test_plan "..." \
      '{
        short_description: $short_desc,
        description: $desc,
        implementation_plan: $impl_plan,
        backout_plan: $backout_plan,
        test_plan: $test_plan,
        u_github_actor: "${{ github.actor }}",
        u_github_branch: "${{ github.ref_name }}",
        u_github_commit: "${{ github.sha }}"
      }')

    RESPONSE=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -d "$CHANGE_JSON" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "201" ]; then
      CHANGE_NUMBER=$(echo "$BODY" | jq -r '.result.number')
      echo "change_number=$CHANGE_NUMBER" >> $GITHUB_OUTPUT
      echo "✅ Change request created: $CHANGE_NUMBER"
    else
      echo "❌ Failed to create change request (HTTP $HTTP_CODE)"
      echo "$BODY" | jq .
      exit 1
    fi
```

**Benefits of REST API approach**:
- ✅ Works reliably (proven with 4 successful test change requests)
- ✅ Full control over request format
- ✅ Better error messages
- ✅ No dependency on DevOps plugin configuration
- ✅ Can implement polling for approval status manually

**Drawbacks**:
- ❌ Must implement approval polling ourselves
- ❌ No automatic integration with ServiceNow DevOps workspace
- ❌ Loses some DevOps-specific features

## Files Modified

- [.github/workflows/servicenow-integration.yaml](../.github/workflows/servicenow-integration.yaml) - Added implementation_plan, backout_plan, test_plan
- [scripts/test-servicenow-change-request.sh](../scripts/test-servicenow-change-request.sh) - Diagnostic script for testing REST API

## Test Results

All curl-based tests passed:
- CHG0030105: Minimal change request
- CHG0030106: With custom GitHub fields
- CHG0030107: With multi-line description
- CHG0030108: With required DevOps fields (implementation_plan, backout_plan, test_plan)

View in ServiceNow: https://calitiiltddemo3.service-now.com/change_request_list.do

## Next Steps

1. **Investigate ServiceNow configuration** - Check DevOps plugin settings, user permissions, instance logs
2. **Consider workaround** - Use REST API directly instead of DevOps Change action
3. **Contact ServiceNow support** - If plugin configuration issue

## Related Documentation

- [ServiceNow DevOps Change Action](https://github.com/ServiceNow/servicenow-devops-change)
- [ServiceNow REST API - Change Management](https://docs.servicenow.com/bundle/latest/page/integrate/inbound-rest/concept/c_TableAPI.html)
- [GitHub + ServiceNow Integration Guide](./GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [ServiceNow Custom Fields Setup](./SERVICENOW-CUSTOM-FIELDS-SETUP.md)
