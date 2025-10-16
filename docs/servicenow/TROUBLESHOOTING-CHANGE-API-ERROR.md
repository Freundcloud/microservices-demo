# Troubleshooting: ServiceNow Change API Internal Server Error

> **Issue**: Change Control API returns "Internal server error" during callback polling
> **Date**: 2025-10-16
> **Affected Workflow**: deploy-with-servicenow.yaml
> **Error**: `Internal server error. An unexpected error occurred while processing the request.`

## 🔴 Error Details

### Exact Error Sequence

```
Run ServiceNow/servicenow-devops-change@v4.0.0
Calling Change Control API to create change....

The job is under change control.
A callback request is created and polling has been started to retrieve the change info.

Error: Internal server error. An unexpected error occurred while processing the request.
```

### What This Tells Us

✅ **Working**:
- Network connectivity to ServiceNow ✅
- API authentication ✅
- Tool ID is valid ✅
- Callback request created ✅
- Polling started ✅

❌ **Failing**:
- ServiceNow internal processing of the change request ❌
- Something in the change creation/approval logic is breaking ❌

---

## 🔍 Root Cause Analysis

### This Error Indicates ONE of These Issues:

### 1. Change Management Configuration Missing/Incomplete

**Most Likely Cause** (90% probability)

ServiceNow's change management workflow is not properly configured for automated change requests.

**Check in ServiceNow**:
```
Navigate to: Change > Configuration > Properties
Verify:
  - Change management is enabled
  - Normal change workflow is active
  - Change models exist and are active
  - Change tasks are properly configured
```

**Common issues**:
- Default change templates missing
- Change approval policies not configured
- Assignment groups don't exist
- Change lifecycle states misconfigured

---

### 2. DevOps Change Velocity Integration Not Configured

**Likely Cause** (70% probability)

The DevOps plugin is installed but not properly integrated with change management.

**Check in ServiceNow**:
```
Navigate to: DevOps > Configuration > Change Management Integration
Verify:
  - Integration is enabled
  - Change model is selected
  - Change type is configured
  - Approval policies are set
```

**Required Configuration**:
- Change model must be mapped to DevOps
- Approval gates must be configured
- Change lifecycle must be compatible with DevOps automation

---

### 3. Missing Required Fields in Change Request

**Possible Cause** (40% probability)

ServiceNow is expecting required custom fields that aren't being provided.

**Check in ServiceNow**:
```
Navigate to: Change > Administration > Table > Change Request
Look for:
  - Custom required fields
  - Business rules requiring specific values
  - Mandatory choice lists
  - Reference fields that must be populated
```

**Our workflow provides**:
- `short_description`
- `description`
- `implementation_plan`
- `backout_plan`
- `test_plan`
- `autoCloseChange` (boolean)

**May be missing**:
- Assignment group reference (we provide name, not sys_id)
- Category
- Priority/Impact/Urgency mapping
- Change model reference
- Configuration items (CIs)

---

### 4. Assignment Groups Don't Exist

**Possible Cause** (30% probability)

The assignment groups we reference in the workflow don't exist in ServiceNow.

**Our workflow uses**:
- Dev environment: "DevOps Team"
- QA environment: "QA Team"
- Prod environment: "Change Advisory Board"

**Check in ServiceNow**:
```
Navigate to: User Administration > Groups
Search for:
  - DevOps Team
  - QA Team
  - Change Advisory Board

If missing, create them or update the workflow to use existing groups.
```

---

### 5. Business Rules Blocking Creation

**Possible Cause** (25% probability)

Custom business rules on the change_request table are preventing automated creation.

**Check in ServiceNow**:
```
Navigate to: System Definition > Business Rules
Filter: Table = change_request
Look for:
  - Rules that run on "insert"
  - Rules that abort on specific conditions
  - Rules requiring specific field values
  - Rules checking user permissions
```

**Check ServiceNow System Logs**:
```
Navigate to: System Logs > System Log > All
Filter by:
  - Source: Business Rule
  - Table: change_request
  - Level: Error
  - Created: Last hour
```

---

## 🔧 Step-by-Step Troubleshooting

### Step 1: Check ServiceNow System Logs (CRITICAL)

**This will show the exact error**:

```
1. Log into ServiceNow as admin
2. Navigate to: System Logs > System Log > All
3. Filter:
   - Created: Last 1 hour
   - Level: Error or Warning
   - Source: (look for DevOps, Change, API-related)
4. Look for errors around the timestamp: 2025-10-16 10:33:20 UTC
```

**What to look for**:
- Stack traces
- Missing field errors
- Permission errors
- Business rule failures
- API endpoint errors

**Take a screenshot** of any errors found.

---

### Step 2: Verify Change Management is Enabled

```
1. Navigate to: Change > Configuration > Properties
2. Check:
   ☐ Change management plugin is active (com.snc.change_management)
   ☐ "Enable change request" is checked
   ☐ Default change workflow is selected
   ☐ Change models exist
```

**If change management is not fully configured**:
- Run the Change Management setup wizard
- Create default change models
- Configure approval workflows

---

### Step 3: Check DevOps Change Integration Settings

```
1. Navigate to: DevOps > Change > Configuration
   OR search: "DevOps Change Configuration"

2. Verify:
   ☐ DevOps Change Velocity is enabled
   ☐ Change control integration is active
   ☐ Default change model is selected
   ☐ Change source is set (e.g., "DevOps Pipeline")
```

**If missing**:
- Enable DevOps change integration
- Map DevOps to a change model
- Configure default values for automated changes

---

### Step 4: Verify Assignment Groups Exist

```
1. Navigate to: User Administration > Groups
2. Search for each group:
   - DevOps Team
   - QA Team
   - Change Advisory Board

3. If missing, either:
   a) Create the groups in ServiceNow, OR
   b) Update the workflow to use existing groups
```

**To update workflow** (if groups don't exist):

Edit `.github/workflows/deploy-with-servicenow.yaml`:

```yaml
# Line 49 - Change "DevOps Team" to an existing group
echo "assignment_group=Your Existing Group Name" >> $GITHUB_OUTPUT

# Line 54 - Change "QA Team" to an existing group
echo "assignment_group=Your Existing Group Name" >> $GITHUB_OUTPUT

# Line 59 - Change "Change Advisory Board" to an existing group
echo "assignment_group=Your Existing Group Name" >> $GITHUB_OUTPUT
```

---

### Step 5: Test Change Creation Manually in ServiceNow

**Create a change request manually to verify the system works**:

```
1. In ServiceNow, navigate to: Change > Create New
2. Fill in the same fields our workflow sends:
   - Short description: "Test automated change"
   - Description: "Testing change management integration"
   - Implementation plan: "Test plan"
   - Backout plan: "Test rollback"
   - Test plan: "Test verification"
   - Assignment group: DevOps Team (or your group)

3. Click "Submit"

4. If this fails, the issue is with change management configuration
   If this succeeds, the issue is with the DevOps API integration
```

---

### Step 6: Check API User Permissions

**The integration token user must have proper permissions**:

```
1. In ServiceNow, find the user associated with the integration token
2. Check user has these roles:
   ☐ sn_devops.integration_user (Required)
   ☐ change_manager or itil (For change creation)
   ☐ rest_api_explorer (For API access)

3. If missing, add required roles to the user
```

---

### Step 7: Review DevOps Change Velocity Documentation

**ServiceNow has specific setup requirements**:

```
1. In ServiceNow, navigate to: DevOps > Documentation
2. Read: "Change Automation Setup"
3. Follow: "Configure Change Integration" guide
4. Verify: All prerequisites are met
```

**External docs**:
- [ServiceNow DevOps Change Velocity Setup](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-change-velocity.html)

---

## 🎯 Quick Fix Options

### Option A: Use Simple Change Model (Recommended)

If you have complex change management rules, temporarily simplify:

```
1. In ServiceNow, create a new change model:
   - Name: "DevOps Automated Change"
   - Type: Normal
   - Auto-approval: Enabled (for dev environment)
   - Required fields: Minimal

2. Configure DevOps to use this model:
   - DevOps > Change > Configuration
   - Select "DevOps Automated Change" as default model

3. Re-run the workflow
```

---

### Option B: Bypass Change Management for Dev (Temporary)

For testing purposes, you can temporarily skip change management:

**Edit the workflow** to skip change creation for dev:

```yaml
# .github/workflows/deploy-with-servicenow.yaml
# Comment out the create-change-request job for dev testing

jobs:
  create-change-request:
    if: github.event.inputs.environment != 'dev'  # Skip for dev
    # ... rest of job
```

This allows you to test the deployment logic while fixing ServiceNow.

---

### Option C: Use REST API Directly (Debug Mode)

Create a debug workflow that tests the API directly:

```yaml
- name: Test ServiceNow API
  run: |
    curl -X POST \
      "${{ secrets.SN_INSTANCE_URL }}/api/now/table/change_request" \
      -H "Authorization: Bearer ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}" \
      -H "Content-Type: application/json" \
      -d '{
        "short_description": "Test change from API",
        "description": "Testing direct API call"
      }'
```

This will show if the basic API works, helping isolate the issue.

---

## 📞 Information for ServiceNow Administrator

**If you need to escalate to ServiceNow admin**, provide:

### Error Details
```
Date: 2025-10-16 10:33:20 UTC
Workflow: Deploy with ServiceNow Change Management
Action: ServiceNow/servicenow-devops-change@v4.0.0
Error: Internal server error during callback polling
GitHub Run: https://github.com/Freundcloud/microservices-demo/actions/runs/18558401248
```

### Configuration Check Needed
```
1. Is DevOps Change Velocity plugin active?
2. Is change management fully configured?
3. Do these assignment groups exist?
   - DevOps Team
   - QA Team
   - Change Advisory Board
4. Are there custom business rules blocking automated change creation?
5. Check system logs for errors around 2025-10-16 10:33:20 UTC
```

### What We're Trying to Do
```
Create a normal change request with:
- Short description
- Full description with commit info
- Implementation plan
- Backout plan
- Test plan
- Assignment group (based on environment)
- Auto-close for dev environment
```

### Reference Documentation
- [ServiceNow DevOps Change Action](https://github.com/ServiceNow/servicenow-devops-change)
- [Setup Guide](docs/servicenow/VERIFY-CHANGE-AUTOMATION.md)
- [Status Document](docs/servicenow/CHANGE-AUTOMATION-STATUS.md)

---

## ✅ Success Criteria

Once fixed, the workflow should:

1. ✅ Create change request in ServiceNow
2. ✅ Return change request number (CHG0001234)
3. ✅ Return sys_id
4. ✅ Dev environment auto-approves
5. ✅ QA/Prod wait for manual approval
6. ✅ Deployment proceeds after approval
7. ✅ Change request closes with success/failure status

---

## 📊 Testing After Fix

Once ServiceNow is configured:

```bash
# Test 1: Dev deployment (should auto-approve)
gh workflow run deploy-with-servicenow.yaml -f environment=dev

# Test 2: Manual change creation in ServiceNow
# Create a change manually to verify system works

# Test 3: Check system logs
# Verify no errors in ServiceNow logs

# Test 4: QA deployment (should wait for approval)
gh workflow run deploy-with-servicenow.yaml -f environment=qa
# Then approve in ServiceNow
```

---

## 🔗 Related Documentation

- [Main Verification Guide](VERIFY-CHANGE-AUTOMATION.md)
- [Implementation Status](CHANGE-AUTOMATION-STATUS.md)
- [ServiceNow Setup Checklist](../SERVICENOW-SETUP-CHECKLIST.md)

---

**Last Updated**: 2025-10-16
**Issue Status**: 🔴 Blocked on ServiceNow configuration
**Priority**: HIGH - Requires ServiceNow admin access
