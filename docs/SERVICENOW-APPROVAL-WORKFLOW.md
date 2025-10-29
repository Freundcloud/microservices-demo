# ServiceNow Change Request Approval Workflow

> **Last Updated**: 2025-10-29
> **Status**: ✅ Implemented and Working
> **Version**: 3.0 (Final)

## Quick Reference

| Environment | State | State Name | Approval Required? | Auto-Deploy? |
|-------------|-------|------------|-------------------|--------------|
| **Dev** | `-2` | Scheduled | ❌ No | ✅ Yes |
| **QA** | `-4` | Assess | ✅ Yes | ❌ No |
| **Prod** | `-4` | Assess | ✅ Yes | ❌ No |

## Overview

This document describes the complete ServiceNow change request approval workflow implemented in our GitHub Actions CI/CD pipeline.

**Key Features**:
- ✅ Dev deployments proceed immediately (no approval gate)
- ✅ QA deployments require manual approval in ServiceNow
- ✅ Prod deployments require manual approval in ServiceNow
- ✅ All 13 custom test result fields populated automatically
- ✅ Respects ServiceNow business rule state transitions

## Approval Workflow

### Development Environment (dev)

**Workflow Behavior**:
1. Push to `main` branch triggers deployment
2. Change Request created with state `-2` (Scheduled)
3. Workflow **proceeds immediately** without waiting
4. Deployment completes within ~5-10 minutes

**Change Request Details**:
```json
{
  "state": "-2",              // Scheduled (auto-approved)
  "approval": "not_requested", // No approval needed
  "priority": "3",            // Low priority
  "short_description": "Deploy microservices to dev"
}
```

**ServiceNow UI**:
- State shows: "Scheduled"
- No approval buttons visible
- CR moves automatically to "Implement" then "Review" then "Closed"

### QA Environment (qa)

**Workflow Behavior**:
1. Manual workflow dispatch with `environment: qa`
2. Change Request created with state `-4` (Assess)
3. Workflow **waits for approval** (up to 30 minutes)
4. Approver manually approves in ServiceNow UI
5. Workflow detects approval and proceeds with deployment

**Change Request Details**:
```json
{
  "state": "-4",              // Assess (requires approval)
  "approval": "not_requested", // Initially
  "priority": "3",            // Medium priority
  "short_description": "Deploy microservices to qa"
}
```

**ServiceNow UI**:
- State shows: "Assess"
- "Approve" button visible
- Approver clicks "Approve"
- State progresses: Assess → Authorize → Scheduled → Implement

**Approval Process**:
1. Approver navigates to Change Request (link provided in workflow output)
2. Reviews test results (13 custom fields with actual data)
3. Reviews security scan results
4. Reviews deployment plan, backout plan, test plan
5. Clicks "Approve" button
6. Change moves to "Authorize" state with `approval=approved`
7. Workflow detects approval and proceeds

### Production Environment (prod)

**Workflow Behavior**: Same as QA, but:
- Higher priority (2 instead of 3)
- Stricter timeout enforcement
- Deployment aborts if approval rejected
- Additional monitoring after deployment

**Change Request Details**:
```json
{
  "state": "-4",              // Assess (requires approval)
  "approval": "not_requested", // Initially
  "priority": "2",            // High priority (production)
  "short_description": "Deploy microservices to prod"
}
```

## ServiceNow State Flow

### State Values Reference

| State Value | State Name | Description |
|-------------|------------|-------------|
| `-5` | New | Initial creation state |
| `-4` | Assess | Awaiting assessment/approval |
| `-3` | Authorize | Authorized, awaiting scheduling |
| `-2` | Scheduled | Approved and scheduled for deployment |
| `-1` | Implement | Deployment in progress |
| `0` | Review | Post-deployment review |
| `3` | Closed | Successfully completed |
| `4` | Canceled | Canceled/aborted |

### State Transition Rules

ServiceNow enforces strict state progression via **"Change Model: Check State Transition"** business rule:

```
New (-5)
  ↓
Assess (-4) ← QA/Prod start here
  ↓
Authorize (-3)
  ↓
Scheduled (-2) ← Dev starts here
  ↓
Implement (-1)
  ↓
Review (0)
  ↓
Closed (3)
```

**Allowed Transitions**:
- ✅ Assess → Authorize → Scheduled → Implement
- ✅ Scheduled → Implement (auto-progression)
- ❌ Cannot skip states (e.g., Assess → Implement blocked)
- ❌ Cannot reverse (e.g., Implement → Scheduled blocked)

### Approval Values

| Approval Value | Description |
|---------------|-------------|
| `not_requested` | No approval workflow initiated |
| `requested` | Approval requested, awaiting decision |
| `approved` | Approved by authorized user |
| `rejected` | Rejected by authorized user |

## Workflow Implementation

### State Determination Logic

**File**: [.github/workflows/servicenow-change-rest.yaml](.github/workflows/servicenow-change-rest.yaml)

**Lines 194-208**: Environment-based state determination
```yaml
# Determine state based on environment
# ServiceNow state values: -5=New, -4=Assess, -3=Authorize, -2=Scheduled, -1=Implement, 0=Review, 3=Closed, 4=Canceled
# State flow enforced by business rules: New → Assess → Authorize → Scheduled → Implement → Review → Closed
# Dev: Auto-deploy (Scheduled state, no approval needed)
# QA/Prod: Requires manual approval (Assess state)
if [ "${{ inputs.environment }}" = "dev" ]; then
  STATE="-2"  # Scheduled (auto-approved, ready to deploy)
  PRIORITY="3"       # Low priority
elif [ "${{ inputs.environment }}" = "qa" ]; then
  STATE="-4"  # Assess (requires manual approval for QA)
  PRIORITY="3"       # Medium priority
else
  STATE="-4"  # Assess (requires manual approval for production)
  PRIORITY="2"       # High priority (production)
fi
```

### Approval Wait Logic

**Lines 520-533**: Approval detection
```yaml
# Accept if:
# 1. State is Scheduled (-2) or Implement (-1) - already authorized, ready to deploy
# 2. Approval is approved (any state except Assess/New)
# 3. State is Review (0) - post-deployment
if [ "$STATE" = "-2" ] || [ "$STATE" = "-1" ]; then
  echo "✅ Change Request authorized (state: $STATE) - ready for deployment"
  exit 0
elif [ "$APPROVAL" = "approved" ]; then
  echo "✅ Change Request approved (approval: $APPROVAL, state: $STATE) - ready for deployment"
  exit 0
elif [ "$APPROVAL" = "rejected" ]; then
  echo "❌ Change Request was rejected"
  exit 1
fi
```

**Polling Behavior**:
- Interval: 30 seconds
- Max wait: 30 minutes (dev/qa), 60 minutes (prod)
- Aborts if rejected
- Times out if no decision within max wait

## How to Approve a Change Request

### Method 1: Via Direct Link (Fastest)

1. Check workflow output for change request link:
   ```
   🔗 View in ServiceNow: https://calitiiltddemo3.service-now.com/change_request.do?sys_id=...
   ```
2. Click the link
3. Review change request details
4. Click "Approve" button
5. Workflow proceeds automatically

### Method 2: Via ServiceNow UI

1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: **Change → All**
3. Filter by:
   - State: Assess
   - Short description contains: "Deploy microservices to qa" (or "prod")
4. Open the change request
5. Review details
6. Click "Approve" button

### Method 3: Via API (Advanced)

```bash
# Get change request sys_id from workflow output
CR_SYSID="..."

# Approve via API
curl -X PATCH \
  -u "$USER:$PASS" \
  -H "Content-Type: application/json" \
  "$INSTANCE/api/now/table/change_request/$CR_SYSID" \
  -d '{"approval": "approved", "approval_history": "Approved via API", "comments": "Tests passed, deploying to QA"}'
```

## Test Results Visible in Change Requests

Every change request includes 13 custom fields with actual test data:

### Unit Test Fields
- `u_unit_test_status`: passed/failed/skipped
- `u_unit_test_total`: Total number of tests
- `u_unit_test_passed`: Number passed
- `u_unit_test_failed`: Number failed
- `u_unit_test_coverage`: Code coverage percentage
- `u_unit_test_url`: Link to GitHub Actions test results

### SonarCloud Fields
- `u_sonarcloud_status`: passed/failed/warning
- `u_sonarcloud_bugs`: Number of bugs
- `u_sonarcloud_vulnerabilities`: Number of vulnerabilities
- `u_sonarcloud_code_smells`: Number of code smells
- `u_sonarcloud_coverage`: SonarCloud coverage percentage
- `u_sonarcloud_duplications`: Code duplication percentage
- `u_sonarcloud_url`: Link to SonarCloud dashboard

**Approvers can review all test data before approving!**

## Troubleshooting

### "Can't find Approve button"

**Possible causes**:
1. Change Request in wrong state (not Assess)
2. Already approved (check approval field)
3. User lacks approval permissions
4. Change Request canceled or closed

**Solution**:
```bash
# Check CR state
curl -s -u "$USER:$PASS" \
  "$INSTANCE/api/now/table/change_request/$CR_SYSID?sysparm_fields=state,approval,number" \
  | jq '.'
```

### "Workflow times out waiting for approval"

**Possible causes**:
1. No one approved within max wait time (30 minutes)
2. Change Request was rejected
3. ServiceNow API unreachable

**Solution**:
- Approve change requests promptly
- Increase timeout in workflow if needed (lines 469-471)
- Check ServiceNow connectivity

### "Change Request stuck in Assess state"

**Possible causes**:
1. Approval not requested (approval field = "not_requested")
2. Approver hasn't acted yet
3. Business rules blocking state progression

**Solution**:
- Manually approve the change request
- Verify approval workflow configuration in ServiceNow
- Check user has approval permissions

## Related Documentation

- [WHERE-TO-FIND-UNIT-TEST-DATA.md](WHERE-TO-FIND-UNIT-TEST-DATA.md) - Test data location guide
- [SERVICENOW-CUSTOM-FIELDS-SETUP.md](SERVICENOW-CUSTOM-FIELDS-SETUP.md) - Custom fields reference
- [ACTUAL-DATA-IMPLEMENTATION.md](ACTUAL-DATA-IMPLEMENTATION.md) - Test data implementation
- [SESSION-SUMMARY-SERVICENOW-APPROVAL-FIX.md](SESSION-SUMMARY-SERVICENOW-APPROVAL-FIX.md) - Complete fix history

## Change History

### Version 3.0 (2025-10-29) - Current

**Commit**: 89af4315

**Changes**:
- QA environment now requires approval (state -4 instead of -2)
- Dev remains auto-deploy (state -2)
- Prod requires approval (state -4)
- Updated approval wait logic to accept `approval=approved` regardless of state

**Rationale**: User requirement - "set qa to 'Assess' for approval only dev can auto deploy"

### Version 2.0 (2025-10-29)

**Commit**: f45864d3

**Changes**:
- Changed from text state values to numeric
- Dev/QA use state -2 (Scheduled) to respect business rules
- Prod uses state -4 (Assess)

**Rationale**: ServiceNow business rules prevent jumping states

### Version 1.0 (2025-10-29)

**Commit**: 6d07c71f

**Changes**:
- Initial fix from text to numeric state values
- Dev/QA used state -1 (Implement)
- Prod used state -4 (Assess)

**Issue**: Business rules blocked Authorize → Implement transition

### Version 0.x (Before fixes)

**Issue**: Text state values ("assess", "implement") sent to ServiceNow, resulting in incorrect states and no approval workflow.

---

**Questions?** See troubleshooting section above or contact the DevOps team.
