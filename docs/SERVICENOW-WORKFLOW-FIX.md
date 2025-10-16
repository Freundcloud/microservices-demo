# ServiceNow Workflow Fix - Proper State Management

**Issue**: Change requests created in "New" state with "Not Yet Requested" approval

**Root Cause**: Workflow doesn't properly request approval and transition through states

**Solution**: Update workflow to follow proper ServiceNow change lifecycle

---

## 🔍 Problem Analysis

### What's Happening:
```
Current Workflow:
1. Creates change request
2. State: "New" (-5)
3. Approval: "Not Yet Requested"
4. For dev: Skips approval wait
5. Result: Change stuck in "New" state
```

### ServiceNow State Values:
```
-5 = New
-4 = Assess
-3 = Authorize (approval requested)
-2 = Scheduled (approved)
-1 = Implement (deployment)
 0 = Review
 3 = Closed
 4 = Canceled
```

### Correct Flow:
```
Should Be:
1. Create change (state: -5 "New")
2. Request approval (state: -3 "Authorize", approval: "requested")
3. Auto-approve for dev (approval: "approved")
4. Move to Scheduled (state: -2)
5. Deploy (state: -1 "Implement")
6. Close (state: 3 "Closed")
```

---

## 🔧 Workflow Fix

### Current Problematic Code:
```yaml
# Line 41 - WRONG: Can't create directly in "Closed" state
if [ "$ENV" == "dev" ]; then
  echo "state=3" >> $GITHUB_OUTPUT  # Closed/Complete - DOESN'T WORK
```

### Fixed Code:
```yaml
# Create in proper state and request approval
if [ "$ENV" == "dev" ]; then
  echo "state=-5" >> $GITHUB_OUTPUT  # New
  echo "approval=requested" >> $GITHUB_OUTPUT  # Request approval immediately
  echo "auto_approve=true" >> $GITHUB_OUTPUT  # Auto-approve for dev
```

---

## ✅ Complete Workflow Update

### Add Approval Request Step:

After creating the change request, add this step:

```yaml
      - name: Request Approval
        id: request-approval
        run: |
          CHANGE_SYS_ID="${{ steps.create-cr.outputs.change_sys_id }}"
          ENV="${{ github.event.inputs.environment }}"
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          # Request approval and move to Authorize state
          RESPONSE=$(curl -s -X PATCH \
            -H "Authorization: Basic $BASIC_AUTH" \
            -H "Content-Type: application/json" \
            -d '{
              "state": "-3",
              "approval": "requested"
            }' \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/$CHANGE_SYS_ID")

          echo "✅ Approval requested for change request" >> $GITHUB_STEP_SUMMARY

          # For dev environment, immediately approve
          if [ "$ENV" == "dev" ]; then
            sleep 2  # Give ServiceNow time to process

            # Auto-approve for dev
            APPROVE_RESPONSE=$(curl -s -X PATCH \
              -H "Authorization: Basic $BASIC_AUTH" \
              -H "Content-Type: application/json" \
              -d '{
                "state": "-2",
                "approval": "approved"
              }' \
              "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/$CHANGE_SYS_ID")

            echo "✅ Auto-approved for dev environment" >> $GITHUB_STEP_SUMMARY
          fi
```

---

## 🎯 Manual Fix for Current Change Request

For the existing change request (CHG0030013), you can manually request approval:

### Via REST API:
```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)
CHANGE_SYS_ID="20cd77f2c3e4fe90e1bbf0cb050131b8"

# Request approval
curl -X PATCH \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "state": "-3",
    "approval": "requested"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/${CHANGE_SYS_ID}"

# Auto-approve for dev
curl -X PATCH \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "state": "-2",
    "approval": "approved"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/${CHANGE_SYS_ID}"

# Close change
curl -X PATCH \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d '{
    "state": "3",
    "close_code": "successful",
    "close_notes": "Deployment completed successfully"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/${CHANGE_SYS_ID}"
```

### Via ServiceNow UI:
1. Open: https://calitiiltddemo3.service-now.com/change_request.do?sys_id=20cd77f2c3e4fe90e1bbf0cb050131b8
2. Click: **Request Approval** button
3. For dev, it should auto-approve (if approval rules configured)
4. Close the change request

---

## 📋 Complete Updated Workflow

I'll create the complete updated workflow file next with all proper state transitions.

---

**See**: Complete updated workflow in next commit

**Last Updated**: 2025-10-16
**Issue**: Change stuck in "New" state
**Fix**: Proper state management and approval request
