# ServiceNow Orchestration Tool ID Setup

> **Issue**: Workflow fails with "Input required and not supplied: tool-id"
> **Solution**: Configure ServiceNow DevOps Change integration
> **Time Required**: 5 minutes

---

## Problem

The GitHub Actions workflow requires a `SERVICENOW_ORCHESTRATION_TOOL_ID` to connect to ServiceNow's DevOps Change API. This ID is missing from your GitHub secrets.

**Error Message**:
```
Error: Input required and not supplied: tool-id
```

---

## Solution Options

You have **two options** to fix this:

---

## Option 1: Use ServiceNow DevOps Change (Recommended for Full Integration)

This option enables full integration with ServiceNow DevOps Change, including automatic change request creation and approval tracking.

### Step 1: Install ServiceNow DevOps Change Plugin

1. **Navigate to**: https://calitiiltddemo3.service-now.com/v_plugin_list.do

2. **Search**: "DevOps Change"

3. **Find**: "DevOps Change" plugin

4. **Click**: Install/Activate

5. **Wait**: 2-3 minutes for activation

### Step 2: Create Orchestration Tool

1. **Navigate to**: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/devops_orchestration_tool_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name:        GitHub Actions
   Description: GitHub Actions orchestration for microservices-demo
   Type:        GitHub
   Tool URL:    https://github.com
   ```

4. **Click**: Submit

5. **Copy**: The `sys_id` from the URL (it will look like: `a1b2c3d4e5f6...`)

### Step 3: Configure GitHub Secret

```bash
# Set the tool ID as a GitHub secret
gh secret set SERVICENOW_ORCHESTRATION_TOOL_ID \
  --repo Freundcloud/microservices-demo \
  --body "YOUR_TOOL_SYS_ID_HERE"
```

**Or via GitHub UI**:
1. Navigate to: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions
2. Click: New repository secret
3. Name: `SERVICENOW_ORCHESTRATION_TOOL_ID`
4. Value: `YOUR_TOOL_SYS_ID_HERE`
5. Click: Add secret

### Step 4: Re-run Workflow

```bash
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=dev
```

---

## Option 2: Use Basic ServiceNow API (Simpler, No Plugin Required)

This option uses the standard ServiceNow REST API for change management without requiring the DevOps Change plugin.

### Benefits:
- ✅ No plugin installation required
- ✅ Works with standard ServiceNow instances
- ✅ Simpler configuration

### Limitations:
- ❌ Manual approval tracking (no automatic workflow resume)
- ❌ Less integrated with GitHub Actions

### Implementation:

I'll create a simplified workflow that doesn't require the tool-id.

---

## Option 2 Implementation (Recommended for Your Setup)

Since the ServiceNow DevOps Change plugin may not be available or you want a simpler approach, let me create an alternative workflow that uses the standard ServiceNow REST API.

### Modified Workflow Approach

Instead of using the `ServiceNow/servicenow-devops-change@v2.0.0` action, we'll use direct REST API calls with `curl` and the credentials you already have configured.

**Advantages**:
1. ✅ No plugin required
2. ✅ Works with standard ServiceNow
3. ✅ Uses existing credentials
4. ✅ Full control over change request lifecycle

**How it works**:
1. Create change request via REST API
2. Poll change request status for approval
3. Resume workflow when approved
4. Update change request with deployment results

---

## Quick Fix: Make Tool ID Optional

The simplest immediate fix is to make the tool-id optional in the workflow. Let me update the workflow to handle this:

### Edit the workflow file

The workflow can be modified to work without the tool-id by using conditional logic. However, this requires changing the workflow approach.

---

## Recommended Action

I recommend **Option 2** (use basic ServiceNow API) because:

1. ✅ You already have working credentials
2. ✅ No additional ServiceNow plugin needed
3. ✅ Simpler to maintain
4. ✅ Full control over the process

Would you like me to:

1. **Create a simplified workflow** that uses REST API directly? (Recommended)
2. **Help you install the DevOps Change plugin** and get the tool-id?

---

## Verification

After configuration, test with:

```bash
# Test that tool-id is configured
gh secret list --repo Freundcloud/microservices-demo | grep SERVICENOW_ORCHESTRATION_TOOL_ID

# Should show:
# SERVICENOW_ORCHESTRATION_TOOL_ID  Updated YYYY-MM-DD
```

---

## Alternative: Simplified Approval Workflow (No Tool ID Required)

If you want to proceed without the DevOps Change plugin, I can create a workflow that:

1. Creates change requests via REST API
2. Checks approval status via polling
3. Resumes based on approval state
4. Updates change request via REST API

This approach:
- ✅ Works with your current setup
- ✅ No additional configuration needed
- ✅ Uses credentials you already have
- ❌ Requires manual approval in ServiceNow UI (no email integration)

Let me know which approach you prefer, and I'll implement it!
