# ServiceNow Auto-Approval Configuration for Dev Environment

## Overview

This guide explains how to configure ServiceNow to automatically approve change requests for the development environment while requiring manual approval for QA and production.

**Strategy**: Use different change request types based on environment:
- **Dev**: `standard` change type → Auto-approved
- **QA/Prod**: `normal` change type → Manual approval required

---

## Workflow Configuration (Already Done ✅)

The workflow has been updated to set the change type dynamically:

```yaml
# .github/workflows/servicenow-devops-change.yaml
change-request: >-
  {
    "attributes": {
      "type": "${{ inputs.environment == 'dev' && 'standard' || 'normal' }}",
      "justification": "${{ inputs.environment == 'dev' && 'Development environment - low risk deployment with automated testing' || '' }}"
    }
  }
```

**Result**:
- Dev environment: Creates "Standard" change requests
- QA/Prod environments: Creates "Normal" change requests

---

## ServiceNow Configuration Required

### Method 1: Create Standard Change Template (Recommended)

Standard changes in ServiceNow can be configured for automatic approval through templates.

**Step 1: Navigate to Standard Change Catalog**
1. Log into ServiceNow: `https://calitiiltddemo3.service-now.com`
2. Navigate to: **Change** → **Standard Changes** → **Standard Change Catalog**

**Step 2: Create New Standard Change Template**
1. Click **New**
2. Fill in template details:
   - **Name**: "Dev Environment Deployment"
   - **Short description**: "Automated deployment to development environment"
   - **Template**: Create a new template
   - **Auto-approve**: Enable this option ✅

**Step 3: Configure Template Properties**
```
Template Name: Dev Environment Deployment
Category: DevOps
Subcategory: Deployment
Risk: Low (4)
Impact: Low (3)
Priority: Low (4)
Assignment Group: GitHubARC DevOps Admin
Auto-Approve: Yes
State transition: New → Implement → Review → Closed
```

**Step 4: Set Template Conditions**
Configure when this template applies:
- Short description contains: `[dev]`
- OR Assignment group: `GitHubARC DevOps Admin`
- AND Category: `DevOps`

### Method 2: Configure Change Approval Rules

If standard change templates are not available, use approval rules.

**Step 1: Navigate to Approval Rules**
1. **Change** → **Administration** → **Approval Rules**

**Step 2: Create Auto-Approval Rule for Dev**
```
Rule Name: Auto-Approve Dev Deployments
Table: Change Request [change_request]
Conditions:
  - Category = DevOps
  - Short description CONTAINS [dev]
  - Type = Standard
Actions:
  - Set approval to: Approved
  - Set state to: Implement
```

### Method 3: Use Business Rules (Advanced)

Create a business rule that auto-approves dev changes.

**Step 1: Navigate to Business Rules**
1. **System Definition** → **Business Rules**

**Step 2: Create New Business Rule**
```javascript
Name: Auto-Approve Dev Changes
Table: Change Request [change_request]
When: before
Insert: false
Update: true
Conditions:
  - Category is DevOps
  - Short description contains [dev]
  - Type is standard

Script:
if (current.short_description.indexOf('[dev]') > -1 &&
    current.category == 'DevOps' &&
    current.type == 'standard') {
  current.approval = 'approved';
  current.state = 3; // Implement state
}
```

---

## Verification Steps

### Step 1: Test Dev Deployment

```bash
# Trigger a dev deployment
gh workflow run MASTER-PIPELINE.yaml --field environment=dev
```

### Step 2: Check Change Request Created

Navigate to: `https://calitiiltddemo3.service-now.com/change_request_list.do`

Look for the new change request and verify:
- ✅ Type: Standard
- ✅ State: Implement (or higher)
- ✅ Approval: Approved
- ✅ Short description contains: `[dev]`

### Step 3: Verify Auto-Approval Worked

The change should automatically transition through states:
1. **New** → Created
2. **Implement** → Auto-approved and ready for deployment
3. **Review** → After deployment completes
4. **Closed** → Auto-closed with success code

**Check workflow logs**:
```bash
gh run view <run-id> --repo Freundcloud/microservices-demo --log
```

Look for:
- Change request number returned: `CHG00301XX`
- No waiting for approval (should proceed immediately)

### Step 4: Test QA/Prod (Manual Approval)

```bash
# Trigger QA deployment
gh workflow run MASTER-PIPELINE.yaml --field environment=qa
```

This should:
- ✅ Create "Normal" change request
- ✅ Require manual approval
- ❌ NOT auto-approve
- ⏸️ Wait for approval before deploying

---

## Alternative: Use Deployment Gates for Dev (Faster)

If you want even faster dev deployments without traditional change requests:

**For Dev Only**: Re-enable deployment-gate parameter

```yaml
# Option: Fast dev deployments with deployment gates
deployment-gate: ${{ inputs.environment == 'dev' && '{ "environment": "dev", "jobName": "Deploy to dev" }' || '' }}
```

**Result**:
- **Dev**: Uses deployment gates (changeControl: false) - No CR, instant approval
- **QA/Prod**: Creates traditional CRs (changeControl: true) - Manual approval required

This hybrid approach gives you:
- ⚡ Ultra-fast dev deployments (no CR overhead)
- 📋 Compliance for QA/prod (traditional CRs with approval)

---

## Comparison: Standard Change vs Deployment Gate

### Standard Change (Current Configuration)

**Pros**:
- ✅ Creates audit trail (CR in change_request table)
- ✅ Visible in Change Calendar
- ✅ Automatic approval (if configured)
- ✅ Can be reported on for compliance
- ✅ Consistent process across environments

**Cons**:
- ⏱️ Slightly slower (CR creation overhead ~1-2 seconds)
- 🔧 Requires ServiceNow configuration

**Best for**: Organizations that need audit trail even for dev

### Deployment Gate (Alternative for Dev)

**Pros**:
- ⚡ Fastest possible deployment (no CR)
- ✅ Simple configuration (just add parameter)
- ✅ No ServiceNow admin access needed

**Cons**:
- ❌ No CR created (only in sn_devops_task_execution)
- ❌ Not visible in Change Calendar
- ❌ Less comprehensive audit trail

**Best for**: Fast-moving dev teams prioritizing speed

---

## Current Configuration Summary

### What's Configured

**Workflow** (`.github/workflows/servicenow-devops-change.yaml`):
- ✅ Deployment-gate parameter removed (enables traditional CRs)
- ✅ Dynamic change type based on environment:
  - Dev → `standard` type
  - QA/Prod → `normal` type
- ✅ Justification field populated for dev

### What Needs ServiceNow Configuration

**In ServiceNow** (requires admin access):
- ⏳ Create standard change template for dev
- ⏳ Configure auto-approval rule
- ⏳ OR create business rule for auto-approval

**Alternative** (no ServiceNow config needed):
- Use deployment gate for dev only (see hybrid approach above)

---

## Recommended Configuration

**Option A: Audit Trail Priority**
```yaml
# All environments use traditional CRs
# Dev uses standard change type (auto-approve in ServiceNow)
# QA/Prod uses normal change type (manual approval)
change-request:
  type: ${{ env == 'dev' && 'standard' || 'normal' }}
# deployment-gate: NOT USED
```

**Option B: Speed Priority (Hybrid)**
```yaml
# Dev uses deployment gates (fast, no CR)
# QA/Prod uses traditional CRs (manual approval)
deployment-gate: ${{ env == 'dev' && '...' || '' }}
change-request: # only for qa/prod
```

**Recommendation**: Start with Option A (current configuration) for consistency. Switch to Option B if dev deployment speed becomes critical.

---

## Troubleshooting

### Issue: Dev Changes Still Require Approval

**Check**:
1. Verify change type is `standard`:
   ```
   https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=type=standard
   ```
2. Check if standard change template exists
3. Verify approval rules are configured
4. Check business rules are active

**Solution**: Configure auto-approval using one of the three methods above

### Issue: Can't Create Standard Change Templates

**Cause**: May require specific ServiceNow license or plugin

**Solution**: Use approval rules (Method 2) or business rules (Method 3) instead

### Issue: Want Even Faster Dev Deployments

**Solution**: Switch to hybrid approach (deployment gate for dev, traditional CR for qa/prod)

---

## Next Steps

1. **Test current configuration**:
   ```bash
   gh workflow run MASTER-PIPELINE.yaml --field environment=dev
   ```

2. **Configure ServiceNow auto-approval** (choose one method):
   - Standard change template (recommended)
   - Approval rules
   - Business rules

3. **Verify auto-approval works**:
   - Check CR is automatically approved
   - Deployment proceeds without waiting

4. **Optional: Switch to hybrid** if dev speed is critical

---

## Related Documentation

- [ServiceNow DevOps Action Success Guide](SERVICENOW-DEVOPS-ACTION-SUCCESS.md)
- [Enable changeControl Guide](SERVICENOW-ENABLE-CHANGE-CONTROL.md)
- [ServiceNow Integration Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)
- [Master Pipeline](.github/workflows/MASTER-PIPELINE.yaml)
