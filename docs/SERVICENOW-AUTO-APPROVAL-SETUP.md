# ServiceNow Auto-Approval Configuration for Dev Environment

> **Problem**: Change requests for dev environment are being canceled because they have `approval: "not requested"` but no approval workflow configured.
>
> **Solution**: Configure ServiceNow to auto-approve changes for dev environment based on criteria.

## Overview

This guide shows how to set up automatic approval for dev environment deployments in ServiceNow, allowing CI/CD pipelines to proceed without manual approval while maintaining approval controls for QA and production.

## Problem Statement

**Current Behavior**:
- Change requests created for dev environment: `approval: "not requested"`
- ServiceNow has no approval workflow configured for dev
- Change requests get canceled (state: 4)
- Canceled changes don't appear in DevOps Change workspace

**Desired Behavior**:
- Dev changes auto-approved immediately
- QA/Prod changes require manual approval
- All changes appear in DevOps Change workspace

## Solution: Auto-Approval Workflow

### Method 1: Approval Rules (Recommended)

Create an approval rule that automatically approves changes meeting dev criteria.

#### Step 1: Navigate to Approval Rules

1. Log in to ServiceNow as admin
2. Navigate to: **Change > Administration > Approval Rules**
   - Or use Application Navigator filter: type "approval rules"
   - Or direct URL: `https://instance.service-now.com/nav_to.do?uri=sysapproval_approver_rule_list.do`

#### Step 2: Create New Approval Rule

Click **New** to create a new approval rule with these settings:

**Basic Information**:
- **Name**: `Auto-Approve Dev Deployments`
- **Table**: `Change Request [change_request]`
- **Active**: ☑ (checked)
- **Order**: `100` (runs before manual approval rules)

**Conditions**:
Set up conditions to match dev environment changes:

```
Category is DevOps
AND
DevOps Change is true
AND
Short description contains dev
OR
Description contains "Env: dev"
```

**Advanced Conditions** (if your instance supports custom fields):
```
u_github_repo is Freundcloud/microservices-demo
AND
u_environment is dev
```

**Approval Action**:
- **Approval action**: `Auto Approve`
- **Approver**: `System Administrator` (or dedicated service account)
- **Due date**: Leave blank (immediate approval)

**Script** (Advanced - Optional):
If you want more control, use a script:

```javascript
(function executeRule(current, previous /*null when async*/) {
    // Auto-approve if dev environment
    if (current.category == 'DevOps' &&
        current.devops_change == 'true' &&
        (current.short_description.indexOf('dev') > -1 ||
         current.description.indexOf('Env: dev') > -1)) {

        // Set approval to approved
        current.approval = 'approved';

        // Move to Assess state (ready to implement)
        current.state = '-4';

        // Add work note
        current.work_notes = 'Auto-approved for dev environment deployment';

        // Update
        current.update();

        gs.info('Auto-approved dev change request: ' + current.number);
    }
})(current, previous);
```

#### Step 3: Test the Rule

1. Save the approval rule
2. Trigger a new GitHub Actions workflow for dev environment
3. Verify the change request is created
4. Check that it's automatically approved:
   ```bash
   curl -s --user "username:password" \
     "https://instance.service-now.com/api/now/table/change_request?sysparm_query=category=DevOps^devops_change=true&sysparm_fields=number,approval,state&sysparm_limit=1" | jq .
   ```
5. Expected: `approval: "approved"`, `state: "-4"` (Assess)

### Method 2: Business Rule (Alternative)

If approval rules don't work, use a business rule that runs on change request insert/update.

#### Step 1: Navigate to Business Rules

1. Navigate to: **System Definition > Business Rules**
2. Filter by Table: `change_request`
3. Click **New**

#### Step 2: Create Business Rule

**When to run**:
- **Name**: `Auto-Approve Dev Changes`
- **Table**: `Change Request [change_request]`
- **Active**: ☑
- **Advanced**: ☑ (checked)
- **When**: `before`
- **Insert**: ☑
- **Update**: ☑
- **Order**: `100`

**Conditions**:
```
Category is DevOps
AND
DevOps Change is true
AND
Approval is not requested
```

**Advanced Script**:
```javascript
(function executeRule(current, previous /*null when async*/) {

    // Only process if this is a dev environment change
    var isDev = current.short_description.indexOf('dev') > -1 ||
                current.description.indexOf('Env: dev') > -1;

    if (isDev && current.category == 'DevOps' && current.devops_change == 'true') {

        // Auto-approve
        if (current.approval == 'not requested' || current.approval == '') {
            current.approval = 'approved';
            current.state = '-4'; // Assess state

            // Log the auto-approval
            gs.info('Auto-approved dev change: ' + current.number);

            // Optionally add work note
            if (current.work_notes) {
                current.work_notes += '\n\n';
            }
            current.work_notes += 'Auto-approved for dev environment deployment (Business Rule)';
        }
    }

})(current, previous);
```

#### Step 3: Save and Test

Save the business rule and test as described in Method 1, Step 3.

### Method 3: Standard Change Template (Most Robust)

Create a standard change template for dev deployments that automatically approves.

#### Step 1: Create Change Model

1. Navigate to: **Change > Change Models**
2. Click **New**

**Settings**:
- **Name**: `Automated Dev Deployment`
- **Type**: `Standard`
- **Auto-approve**: ☑ (checked)
- **Default risk**: `Low`
- **Default category**: `DevOps`
- **Description**: `Automated deployments to dev environment via GitHub Actions`

#### Step 2: Define Standard Change Criteria

In the **Standard Change Catalog** section:
- **Match conditions**: Define when this template applies
- Add condition: `Short description contains dev`
- Add condition: `Category is DevOps`

#### Step 3: Configure Auto-Approval

In the template:
- **Approval**: Set to `Auto-approved`
- **Initial state**: `-4` (Assess - ready to implement)
- **Skip approval phase**: ☑

#### Step 4: Use Template in GitHub Actions

Update `.github/workflows/servicenow-integration.yaml` to reference the template:

```yaml
# Add change model sys_id for dev
if [ "${{ inputs.environment }}" == "dev" ]; then
  CHG_MODEL_ID="<standard-change-template-sys-id>"
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg model "$CHG_MODEL_ID" '. + {chg_model: $model}')
fi
```

Get the template sys_id:
```bash
curl -s --user "username:password" \
  "https://instance.service-now.com/api/now/table/chg_model?sysparm_query=name=Automated%20Dev%20Deployment&sysparm_fields=sys_id,name" | jq .
```

## Verification Steps

After configuring auto-approval, verify it works:

### 1. Trigger Test Deployment

```bash
gh workflow run "🚀 Master CI/CD Pipeline" \
  --repo Freundcloud/microservices-demo \
  --ref main \
  -f environment=dev \
  -f skip_terraform=true \
  -f skip_deploy=true
```

### 2. Check Change Request Status

```bash
# Get latest dev change request
curl -s --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=category=DevOps^devops_change=true^short_descriptionLIKEdev&sysparm_fields=number,sys_id,approval,state,short_description&sysparm_limit=1&sysparm_display_value=true" | jq .
```

**Expected Result**:
```json
{
  "result": [{
    "number": "CHG0030053",
    "approval": "approved",
    "state": "Assess",
    "short_description": "Deploy Online Boutique to dev"
  }]
}
```

### 3. Verify in DevOps Change Workspace

1. Navigate to: `https://calitiiltddemo3.service-now.com/now/devops-change/changes/`
2. Filter by: `Category = DevOps`, `Environment = dev`
3. Change request should appear with:
   - ✅ Status: Assess (not Canceled)
   - ✅ Approval: Approved
   - ✅ Visible in workspace

## Troubleshooting

### Change Still Being Canceled

**Problem**: Auto-approval rule created but changes still canceled.

**Solutions**:
1. Check rule order - approval rules run in order, lower numbers first
2. Verify conditions match exactly - use "Preview" to test
3. Check if conflicting business rule is canceling changes
4. Review System Logs: **System Logs > All** for errors

### Change Not Auto-Approving

**Problem**: Rule exists but approval stays "not requested".

**Solutions**:
1. Check rule is Active (☑)
2. Verify conditions match change request fields
3. Test condition in script debugger
4. Check user permissions - rule runner needs approval rights

### Can't See Approval Rules

**Problem**: Navigation menu doesn't show approval rules.

**Solution**: You may need specific role:
- `change_manager` role
- `admin` role
- Or contact your ServiceNow administrator

## Current Environment Configuration

**ServiceNow Instance**: `https://calitiiltddemo3.service-now.com`
**Change Request Fields**:
- `category: "DevOps"` - Set by GitHub Actions
- `devops_change: true` - Set by GitHub Actions
- `short_description` - Contains "dev", "qa", or "prod"
- `u_github_repo: "Freundcloud/microservices-demo"` - Custom field
- `correlation_id` - GitHub workflow run ID

**GitHub Actions Workflow**:
- File: `.github/workflows/servicenow-integration.yaml`
- Creates change requests via REST API
- No longer tries to set approval/state (permission issue)

## Recommended Configuration

For this project, we recommend **Method 1: Approval Rules** with these settings:

**Dev Environment**:
- Rule: Auto-approve changes with `short_description` contains "dev"
- Action: Set `approval="approved"`, `state="-4"` (Assess)
- Result: Changes proceed immediately to deployment

**QA Environment**:
- Rule: Require approval from QA team lead
- Action: Assign to approval group `QA Approvers`
- Result: Manual approval required before deployment

**Prod Environment**:
- Rule: Require approval from Change Advisory Board (CAB)
- Action: Multiple approvers, scheduled CAB review
- Result: Full governance and approval process

## Next Steps

1. **User Action Required**: Log in to ServiceNow and configure auto-approval using Method 1
2. **Test**: Trigger dev deployment and verify auto-approval
3. **Verify**: Check change request appears in DevOps Change workspace
4. **Monitor**: Watch for "Canceled" state - should not happen anymore

## References

- ServiceNow Docs: [Approval Rules](https://docs.servicenow.com/bundle/tokyo-platform-administration/page/administer/approval-policies/concept/c_ApprovalRules.html)
- ServiceNow Docs: [Business Rules](https://docs.servicenow.com/bundle/tokyo-platform-administration/page/script/server-scripting/concept/c_BusinessRules.html)
- ServiceNow Docs: [Standard Changes](https://docs.servicenow.com/bundle/tokyo-it-service-management/page/product/change-management/concept/c_ITILStandardChanges.html)
- GitHub Actions: `.github/workflows/servicenow-integration.yaml`
- Previous fix: Git commit `2676b283` (removed explicit approval/state fields)

---

**Status**: Configuration pending - requires ServiceNow admin access to implement
**Priority**: High - blocks automated dev deployments
**Owner**: User (ServiceNow administrator)
