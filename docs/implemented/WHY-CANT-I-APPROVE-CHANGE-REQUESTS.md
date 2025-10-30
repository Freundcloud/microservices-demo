# Why Can't I Approve Change Requests?

## Quick Answer

**You couldn't approve CHG0030351 because**:
- **State**: -3 (Authorize)
- **Approval**: "not requested"
- **Reason**: The workflow created the change request but **didn't request approval**

The change request was created with state "Authorize" but the approval field is "not requested", meaning ServiceNow's approval workflow was never triggered.

---

## Understanding the Problem

### What You Saw

```
⏳ Waiting for approval of Change Request: CHG0030351
🔗 View: https://calitiiltddemo3.service-now.com/change_request.do?sys_id=f00ef5c3c374b294e1bbf0cb0501316f
```

The workflow is **waiting** for approval, but when you open the change request in ServiceNow, there's **no approval button** to click.

### Why This Happens

**ServiceNow Change Request States**:
```
-5 = New
-4 = Assess (awaiting assessment)
-3 = Authorize (awaiting authorization/approval)  ← CHG0030351 is here
-2 = Scheduled
-1 = Implement (authorized, ready to deploy)
0 = Review
3 = Closed
4 = Canceled
```

**ServiceNow Approval Field Values**:
```
"not requested" = No approval workflow triggered ← CHG0030351 has this
"requested" = Approval requested, waiting for approver
"approved" = Approved
"rejected" = Rejected
```

**The Problem**:
- Change request state = "Authorize" (-3) → **Implies manual approval needed**
- But approval = "not requested" → **No approval workflow running**
- Result: **State says "waiting for approval" but no way to approve it!**

---

## Root Cause Analysis

### Current Workflow Logic

**File**: `.github/workflows/servicenow-change-rest.yaml`

**Lines 194-204**: Environment-based state determination
```yaml
# Determine state based on environment
if [ "${{ inputs.environment }}" = "dev" ]; then
  STATE="implement"  # Auto-approved
  PRIORITY="3"       # Low priority
elif [ "${{ inputs.environment }}" = "qa" ]; then
  STATE="assess"     # Awaiting approval
  PRIORITY="3"       # Medium priority
else
  STATE="assess"     # Awaiting approval
  PRIORITY="2"       # High priority (production)
fi
```

**The Issue**: The workflow sets STATE as a **text value** ("assess", "implement"), but ServiceNow expects:
1. **Numeric state value** (-5, -4, -3, -2, -1, 0, 3, 4)
2. **Approval workflow to be triggered** (not just setting state)

### What ServiceNow Receives

When the workflow sends:
```json
{
  "state": "assess",
  "type": "standard",
  ...
}
```

ServiceNow might be:
1. **Converting** "assess" → -4 (Assess state)
2. But **not triggering** the approval workflow
3. Or somehow ending up in state -3 (Authorize) with no approval

---

## The Solution

### Option 1: Use Numeric State Values (Quick Fix)

Update the workflow to use numeric state values instead of text:

```yaml
# Determine state based on environment
if [ "${{ inputs.environment }}" = "dev" ]; then
  STATE="-1"  # Implement (auto-approved)
  PRIORITY="3"       # Low priority
elif [ "${{ inputs.environment }}" = "qa" ]; then
  STATE="-4"  # Assess (awaiting approval)
  PRIORITY="3"       # Medium priority
else
  STATE="-4"  # Assess (awaiting approval)
  PRIORITY="2"       # High priority (production)
fi
```

**State Values to Use**:
- **Dev**: `-1` (Implement) - Auto-approved, ready to deploy
- **QA**: `-4` (Assess) - Awaiting assessment/approval
- **Prod**: `-4` (Assess) - Awaiting assessment/approval

### Option 2: Trigger Approval Workflow (Proper Fix)

To actually trigger ServiceNow's approval workflow, you need to:

**A. Request Approval Explicitly**

Add approval request to the change request:

```bash
# After creating change request, request approval for QA/Prod
if [ "$ENVIRONMENT" != "dev" ]; then
  # Request approval
  curl -X POST \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sysapproval_approver" \
    -d '{
      "source_table": "change_request",
      "sysapproval": "'"$CHANGE_SYSID"'",
      "approver": "'"$APPROVER_SYS_ID"'",
      "state": "requested"
    }'
fi
```

**B. Configure Approval Rules in ServiceNow**

Set up automatic approval rules in ServiceNow:
1. Go to: **Change > Administration > Approval Rules**
2. Create rule: "QA/Prod Deployments Require Approval"
3. Conditions:
   - Type = standard
   - Category = DevOps
   - Short description CONTAINS "qa" OR "prod"
4. Who approves: Change Manager group or specific user
5. When: Before state changes to "Implement"

### Option 3: Use ServiceNow DevOps Plugin

The official ServiceNow DevOps plugin handles this automatically:

```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v4.0.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    change-request: '{"setCloseCode":"true","attributes":{"short_description":"Automated deployment","description":"Deployment from GitHub Actions"}}'
```

This plugin:
- ✅ Creates change request with correct state values
- ✅ Triggers approval workflow automatically (if configured)
- ✅ Waits for approval
- ✅ Proceeds with deployment after approval

---

## Immediate Workaround

### For QA Deployments Stuck Waiting for Approval

**Option A: Manually Approve in ServiceNow**

Even though there's no approval button, you can manually change the state:

1. Open change request: `CHG0030351`
2. Click **Edit** or unlock the record
3. Change **State** from "Authorize" (-3) to "Implement" (-1)
4. **Save**

This will unblock the workflow.

**Option B: Configure Auto-Approval for QA**

Change the workflow to auto-approve QA (same as dev):

```yaml
if [ "${{ inputs.environment }}" = "dev" ] || [ "${{ inputs.environment }}" = "qa" ]; then
  STATE="-1"  # Implement (auto-approved)
elif [ "${{ inputs.environment }}" = "prod" ]; then
  STATE="-4"  # Assess (awaiting approval)
fi
```

This way:
- **Dev**: Auto-approved
- **QA**: Auto-approved
- **Prod**: Requires manual approval

---

## Recommended Fix

I recommend **Option 1 (Quick Fix) + Option 2B (Approval Rules)** combination:

### 1. Update Workflow to Use Numeric States

```yaml
# In .github/workflows/servicenow-change-rest.yaml
# Lines 194-204

# Determine state based on environment
if [ "${{ inputs.environment }}" = "dev" ]; then
  STATE="-1"  # Implement - auto-approved
  PRIORITY="3"
elif [ "${{ inputs.environment }}" = "qa" ]; then
  STATE="-1"  # Implement - auto-approved for QA
  PRIORITY="3"
else
  STATE="-4"  # Assess - requires approval for prod
  PRIORITY="2"
fi
```

### 2. Configure ServiceNow Approval Rules for Prod

Set up approval rule in ServiceNow that automatically triggers when:
- State = -4 (Assess)
- Environment = prod
- Category = DevOps

This gives you:
- ✅ **Dev/QA**: Auto-approved, deploy immediately
- ✅ **Prod**: Requires approval via ServiceNow approval workflow
- ✅ **Workflow**: Will wait for approval and proceed when approved

---

## Testing the Fix

### After Implementing the Fix

**Test 1: Dev Deployment**
1. Deploy to dev
2. Change request created with state = -1 (Implement)
3. Workflow proceeds immediately (no approval wait)

**Test 2: QA Deployment**
1. Deploy to QA
2. Change request created with state = -1 (Implement)
3. Workflow proceeds immediately (no approval wait)

**Test 3: Prod Deployment**
1. Deploy to prod
2. Change request created with state = -4 (Assess)
3. Approval workflow triggers (if configured in ServiceNow)
4. Approver sees approval request in ServiceNow
5. Approver clicks "Approve"
6. State changes to -1 (Implement)
7. Workflow detects approved state and proceeds

---

## Current State Values Reference

### ServiceNow Standard States

| Value | Label | Meaning |
|-------|-------|---------|
| -5 | New | Initial state |
| -4 | Assess | Awaiting assessment/approval |
| -3 | Authorize | Authorization in progress |
| -2 | Scheduled | Scheduled for implementation |
| -1 | Implement | Authorized, ready to implement |
| 0 | Review | Under review |
| 3 | Closed | Completed |
| 4 | Canceled | Canceled |

### What We Should Use

| Environment | State Value | State Label | Approval Needed? |
|-------------|-------------|-------------|------------------|
| dev | -1 | Implement | No (auto-approved) |
| qa | -1 | Implement | No (auto-approved) |
| prod | -4 | Assess | Yes (manual approval) |

---

## Next Steps

1. **Immediate**: Manually approve stuck change requests (change state to -1)
2. **Short-term**: Update workflow to use numeric state values
3. **Medium-term**: Configure ServiceNow approval rules for prod
4. **Long-term**: Consider migrating to ServiceNow DevOps plugin for full integration

---

## Related Documentation

- **Custom Fields Setup**: `docs/SERVICENOW-CUSTOM-FIELDS-SETUP.md`
- **Integration Guide**: `docs/SERVICENOW-TEST-RESULTS-INTEGRATION.md`
- **DevOps Plugin Setup**: `docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md`
- **Where to Find Test Data**: `docs/WHERE-TO-FIND-UNIT-TEST-DATA.md`
