# ServiceNow Change Request States - Understanding the Workflow

**What You're Seeing**: "request approval" in the Change Request list

**Why**: The change request was created but is waiting for approval to be requested

---

## 🔍 Current Situation

### Change Request Details:
```
Number: CHG0030013
Short Description: Deploy Online Boutique to dev
State: New
Approval: Not Yet Requested
Environment: dev
Business Service: Online Boutique
```

### What "Request Approval" Means:
When you see "request approval" in the change request list, it means:
- ✅ Change request was created successfully
- ⏳ Approval status is "Not Yet Requested"
- 📋 State is "New" (not yet submitted for approval)
- 🔄 Waiting for approval to be requested before proceeding

This is **expected behavior** - it's not an error!

---

## 📊 Change Request Lifecycle

### Standard ServiceNow Change Flow:

```
1. New (Created)
   ↓
2. Assess (Risk Assessment)
   ↓
3. Authorize (Approval Requested) ← You are here
   ↓
4. Scheduled (Approved)
   ↓
5. Implement (Deployment Proceeds)
   ↓
6. Review (Post-Implementation)
   ↓
7. Closed Complete
```

### Approval States:

| Approval State | Description | What Happens |
|----------------|-------------|--------------|
| **Not Yet Requested** | Initial state after creation | Nothing - waiting for approval request |
| **Requested** | Approval has been requested | Sent to approvers |
| **Approved** | All approvals granted | Can proceed to implementation |
| **Rejected** | Approval denied | Cannot proceed |
| **Cancelled** | Change cancelled | Workflow stops |

---

## 🔧 How Our Workflow Should Work

### For Dev Environment (Auto-Approved):
```
1. GitHub Actions creates change request
   ↓
2. Change state: New
3. Approval: Not Yet Requested
   ↓
4. Workflow requests approval (API call)
   ↓
5. Dev auto-approval rule triggers
   ↓
6. Approval: Approved
7. State: Scheduled
   ↓
8. Deployment proceeds
   ↓
9. State: Closed Complete
```

### For QA/Prod (Manual Approval Required):
```
1. GitHub Actions creates change request
   ↓
2. Change state: New
3. Approval: Not Yet Requested
   ↓
4. Workflow requests approval (API call)
   ↓
5. Approval: Requested
6. Assigned to: QA Team / DevOps Team
   ↓
7. Approver reviews and approves
   ↓
8. Approval: Approved
9. State: Scheduled
   ↓
10. Deployment proceeds
    ↓
11. State: Closed Complete
```

---

## ❓ Why You're Seeing "Not Yet Requested"

### Current Workflow Behavior:

Looking at the change request created, it's in the "New" state with "Not Yet Requested" approval. This means:

1. **Change request was created** ✅
2. **Approval was NOT yet requested** ⏳
3. **Workflow is waiting** ⏸️

### What Should Happen Next:

The workflow needs to **request approval** by updating the change request:

```bash
# API call to request approval
curl -X PATCH \
  -H "Authorization: Basic ${BASIC_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
    "approval": "requested",
    "state": "authorize"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/${CHANGE_SYS_ID}"
```

---

## 🔍 Checking the Workflow

Let me check if the workflow is requesting approval properly:

### Expected Workflow Steps:

1. **Create Change Request** ✅ (This is working - CHG0030013 exists)
2. **Request Approval** ⏳ (This may be missing)
3. **Poll for Approval** ⏳ (Waiting every 30 seconds)
4. **Proceed with Deployment** ⏳ (After approval)
5. **Update Change Status** ⏳ (Mark as complete)

### Where We Are:
- Step 1: ✅ Complete (CHG0030013 created)
- Step 2: ❓ Needs verification (approval should be requested)
- Steps 3-5: ⏳ Waiting

---

## 🛠️ Fix: Update Workflow to Request Approval

The current workflow in `.github/workflows/deploy-with-servicenow-basic.yaml` creates the change request but may not be requesting approval.

### Required Changes:

After creating the change request, the workflow should:

1. **Set approval to "requested"**
2. **Update state to "authorize"** (or appropriate state)
3. **Then start polling**

### Current Workflow Section (Needs Update):
```yaml
- name: Create Change Request via REST API
  # Creates change but doesn't request approval
```

### Should Include:
```yaml
- name: Request Approval for Change
  run: |
    CHANGE_SYS_ID="${{ steps.create-cr.outputs.change_sys_id }}"

    # Request approval by updating change request
    curl -X PATCH \
      -H "Authorization: Basic ${BASIC_AUTH}" \
      -H "Content-Type: application/json" \
      -d '{
        "approval": "requested",
        "state": "authorize"
      }' \
      "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request/${CHANGE_SYS_ID}"
```

---

## 📋 Manual Workaround (For Now)

Until we update the workflow, you can manually request approval:

### Option 1: Via ServiceNow UI
1. Open the change request: CHG0030013
2. Click: **Request Approval** button
3. For dev environment, it should auto-approve
4. For qa/prod, it will be sent to approvers

### Option 2: Via REST API
```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)
CHANGE_SYS_ID="20cd77f2c3e4fe90e1bbf0cb050131b8"

# Request approval
curl -X PATCH \
  -H "Authorization: Basic ${BASIC_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
    "approval": "requested",
    "state": "authorize"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/${CHANGE_SYS_ID}"
```

---

## 🔄 Auto-Approval Rules

### Dev Environment Auto-Approval:

For dev environment, we should have an approval rule that:
- Triggers when: Environment = "dev"
- Action: Auto-approve
- No human interaction needed

### Checking If Rule Exists:
```bash
PASSWORD='oA3KqdUVI8Q_^>'
curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sysapproval_approver?sysparm_query=document_id=20cd77f2c3e4fe90e1bbf0cb050131b8" \
  | jq .
```

---

## 🎯 What You Should See

### In Change Request List:
When properly configured, you should see:

**For Dev (Auto-Approved)**:
```
Number: CHG0030013
State: Scheduled (or Implement)
Approval: Approved
Approver: System (auto-approved)
```

**For QA/Prod (Manual)**:
```
Number: CHG0030014
State: Authorize
Approval: Requested
Assigned to: QA Team / DevOps Team
```

---

## 🚀 Next Steps

### Immediate Actions:

1. **Manually request approval** for CHG0030013 (dev environment):
   - This will trigger auto-approval
   - Verify it works as expected

2. **Update workflow** to automatically request approval after creating change:
   - Add approval request step
   - Test with dev deployment

3. **Verify auto-approval rules** are configured:
   - Dev should auto-approve
   - QA/Prod should require manual approval

---

## 📊 Viewing Change Requests

### What to Look For:

When viewing the change request list:
- **Number**: CHG0030013
- **Short Description**: Deploy Online Boutique to dev
- **State**: Should progress from "New" → "Authorize" → "Scheduled" → "Implement" → "Closed"
- **Approval**: Should change from "Not Yet Requested" → "Requested" → "Approved"
- **Business Service**: Online Boutique ✅

### Filtering:
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
```

This shows all changes for the Online Boutique application.

---

## ✅ Summary

**What You're Seeing**:
- Change request CHG0030013 exists ✅
- State: "New" ⏳
- Approval: "Not Yet Requested" ⏳
- Shows "request approval" action ✅

**What This Means**:
- Change was created successfully ✅
- Approval needs to be requested ⏳
- Workflow is working but needs one more step ⏳

**How to Fix**:
1. Manually request approval (for now)
2. Update workflow to auto-request approval
3. Verify auto-approval rules for dev

**Expected End State**:
- State: "Closed Complete" ✅
- Approval: "Approved" ✅
- Implementation: Successful ✅

---

## 🔧 Workflow Update Required

I'll create an updated workflow that properly requests approval after creating the change request.

**See**: Updated workflow coming next!

---

**Last Updated**: 2025-10-16
**Change Request**: CHG0030013
**Status**: Created, awaiting approval request
