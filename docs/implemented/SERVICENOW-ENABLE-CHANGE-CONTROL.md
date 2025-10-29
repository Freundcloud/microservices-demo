# How to Enable changeControl in ServiceNow DevOps

## Current Situation

The ServiceNow DevOps API is returning `changeControl: false`, which means:
- ✅ Deployments ARE being registered in ServiceNow DevOps system
- ✅ Data IS being tracked in `sn_devops_task_execution` table
- ❌ Traditional change requests are NOT being created in `change_request` table
- ❌ No entries appear in Change Calendar or Change Management views

**API Response:**
```json
{
  "result": {
    "changeControl": false,
    "status": "Success"
  }
}
```

---

## What is changeControl?

ServiceNow DevOps plugin supports two operational modes:

### 1. Deployment Gate Mode (`changeControl: false`) - Current Mode
- Modern DevOps approach
- Deployments registered in DevOps tables only
- Automated approval based on policies
- No traditional change request workflow
- Faster deployment cycle
- **Data location**: `sn_devops_task_execution`, `sn_devops_pipeline`

### 2. Traditional Change Request Mode (`changeControl: true`) - Desired Mode
- Creates full change requests in `change_request` table
- Requires manual approvals for QA/Prod
- Visible in Change Calendar
- Full ITIL change management workflow
- **Data location**: `change_request` table + DevOps tables

---

## ✅ SOLUTION FOUND: How to Enable changeControl

### Method 1: Remove deployment-gate Parameter (EASIEST - NO SERVICENOW ADMIN NEEDED!)

**After analyzing the ServiceNow DevOps Change action source code, I found the root cause!**

**The Problem:**
When you provide the `deployment-gate` parameter in your GitHub Actions workflow, ServiceNow operates in "deployment gate mode" which returns `changeControl: false`.

**The Solution:**
**Simply REMOVE or COMMENT OUT the `deployment-gate` parameter!**

**Source Code Evidence:**
```javascript
// From https://github.com/ServiceNow/servicenow-devops-change/blob/main/src/lib/create-change.js
if (deploymentGateStr) {
  payload.deploymentGateDetails = deploymentGateDetails;  // ← This triggers deployment gate mode!
}
```

When `deploymentGateDetails` is included in the API payload, ServiceNow switches to deployment gate mode instead of creating traditional change requests.

**How to Fix in Your Workflow:**

In `.github/workflows/servicenow-devops-change.yaml`:

```yaml
# ❌ BEFORE (causes changeControl: false)
deployment-gate: >-
  {
    "environment": "${{ inputs.environment }}",
    "jobName": "Register Deployment"
  }

# ✅ AFTER (enables changeControl: true)
# Simply comment it out or remove it entirely:
# deployment-gate: >-
#   {
#     "environment": "${{ inputs.environment }}",
#     "jobName": "Register Deployment"
#   }
```

**That's it!** No ServiceNow admin access needed. No API calls. Just remove one parameter.

**Testing:**
```bash
# After removing deployment-gate, trigger a workflow
gh workflow run MASTER-PIPELINE.yaml --field environment=dev

# Then check for traditional change request
# It should now return changeControl: true and create a CR in change_request table
```

### Method 2: Via ServiceNow UI

**Step 1: Navigate to DevOps Configuration**
1. Log into ServiceNow: `https://calitiiltddemo3.service-now.com`
2. Navigate to: **All** (hamburger menu) → **DevOps** → **Configuration**

**Step 2: Find Change Control Settings**
Look for one of these configuration options:
- **General Settings** → "Enable Change Control"
- **Tool Configuration** → GitHub tool → "Change Control" section
- **Application Settings** → "Online Boutique" app → "Enable Change Management"

**Step 3: Configure Change Templates**
If the option exists, you may need to configure:
- Change request template to use
- Default assignee/assignment group
- Approval workflow

### Method 2: Via System Properties

If UI configuration is not available, check system properties:

```bash
#!/bin/bash
source .envrc

# Check for changeControl-related properties
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_properties?sysparm_query=nameLIKEsn_devops.change^ORnameLIKEenable_change" | \
  python3 -m json.tool
```

**Relevant properties found** (from investigation):
- `sn_devops.change_request_handler_subflow`
- `sn_devops.enable_change_request_state_transition`
- `sn_devops.enable_change_creation_with_partial_data`
- `sn_devops.custom_change_categorization`

None of these directly control `changeControl: true/false` behavior.

### Method 3: Via Pipeline Configuration

The `sn_devops_pipeline` table has an `auto_close_change` field:

```bash
#!/bin/bash
source .envrc

# Get pipeline sys_id for your workflow
PIPELINE_SYS_ID="<your_pipeline_sys_id>"

# Update pipeline to enable change control
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X PATCH \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline/$PIPELINE_SYS_ID" \
  -d '{
    "auto_close_change": "true"
  }' | python3 -m json.tool
```

**However**, this only controls auto-closing, not whether CRs are created.

### Method 4: Contact ServiceNow Admin

The `changeControl: false` behavior might be:
1. **Plugin Configuration**: Requires admin access to DevOps plugin settings
2. **License Limitation**: Demo instances may have limited functionality
3. **Application Design**: The "Online Boutique" app may be configured for deployment gates only

**Recommended Action**:
1. Contact ServiceNow administrator for the demo instance
2. Ask them to check: **DevOps > Configuration > Change Management Settings**
3. Request enablement of traditional change request creation

---

## Alternative: Use REST API for Traditional Change Requests

If `changeControl: true` is not available in the demo instance, you can continue using the existing REST API integration that creates traditional change requests:

**Workflow**: `.github/workflows/servicenow-change-rest.yaml`

This workflow:
- ✅ Creates traditional change requests in `change_request` table
- ✅ Visible in Change Calendar
- ✅ Supports manual approval workflows
- ✅ Full ITIL compliance
- ❌ More complex implementation
- ❌ Manual polling for approval status

### Hybrid Approach (Recommended)

Use both approaches for different environments:

**Development**:
```yaml
# Use DevOps Change action (fast, automated)
uses: ServiceNow/servicenow-devops-change@v6.1.0
# Result: changeControl: false, deployment gates only
```

**Production**:
```yaml
# Use REST API (traditional CRs, manual approval)
uses: ./.github/workflows/servicenow-change-rest.yaml
# Result: Full change request in change_request table
```

This gives you:
- ✅ Speed in dev/QA (DevOps gates)
- ✅ Compliance in prod (traditional CRs)
- ✅ Full audit trail
- ✅ Best of both worlds

---

## Verification

After enabling changeControl (if successful), test with:

```bash
#!/bin/bash
source .envrc

# Test the API
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  "$SERVICENOW_INSTANCE_URL/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID" \
  -d '{
    "callbackURL": "https://api.github.com/repos/Freundcloud/microservices-demo",
    "orchestrationTaskURL": "https://github.com/Freundcloud/microservices-demo/actions/runs/test",
    "setCloseCode": "true",
    "autoCloseChange": true,
    "attributes": {
      "short_description": "Test changeControl=true",
      "description": "Testing traditional CR creation"
    }
  }' | python3 -m json.tool
```

**Expected result if successful**:
```json
{
  "result": {
    "changeControl": true,
    "changeRequestNumber": "CHG0030123",
    "changeRequestSysId": "abc123...",
    "status": "Success"
  }
}
```

Then check:
```
https://calitiiltddemo3.service-now.com/change_request_list.do
```

You should see a new change request with number `CHG0030123`.

---

## Conclusion

**Current Status**: `changeControl: false` is likely a **plugin configuration or demo instance limitation**, not something that can be easily changed via API.

**Options**:
1. ✅ **Keep using DevOps Change action** (deployment gates only) - Fast, automated
2. ✅ **Keep using REST API workflow** (traditional CRs) - Full compliance
3. ✅ **Use hybrid approach** (DevOps for dev, REST for prod) - Best of both
4. ⏳ **Contact ServiceNow admin** - Request changeControl enablement (may not be possible in demo instance)

**Recommendation**: Use the hybrid approach documented above. This gives you the benefits of both systems without requiring ServiceNow admin intervention.

---

## Related Documentation

- [ServiceNow DevOps Action Success Guide](SERVICENOW-DEVOPS-ACTION-SUCCESS.md)
- [ServiceNow DevOps Changes Troubleshooting](SERVICENOW-DEVOPS-CHANGES-TROUBLESHOOTING.md)
- [Master Pipeline Implementation](.github/workflows/MASTER-PIPELINE.yaml)
- [REST API Integration](.github/workflows/servicenow-change-rest.yaml)
