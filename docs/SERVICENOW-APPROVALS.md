# ServiceNow Change Management Approvals

> **Purpose**: Configure multi-level approval workflow for dev, qa, and prod deployments
> **Last Updated**: 2025-10-16
> **Status**: Implementation Guide

---

## Overview

This guide sets up a **3-tier approval workflow** for deployments using ServiceNow Change Management:

- **Dev**: Auto-approved, minimal gates
- **QA**: Single approval required (QA Lead)
- **Prod**: Multi-level approval (DevOps Lead → Change Advisory Board)

---

## Approval Matrix

| Environment | Auto-Approved | Approval Required | Approvers | Timeout |
|-------------|---------------|-------------------|-----------|---------|
| **Dev** | ✅ Yes | No | N/A | Immediate |
| **QA** | ❌ No | Yes | QA Team Lead | 2 hours |
| **Prod** | ❌ No | Yes | DevOps Lead + CAB | 24 hours |

---

## Architecture

### Workflow Flow

```
┌──────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                    │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
          ┌──────────────────────────────────────┐
          │  1. Create Change Request            │
          │     - Environment: dev/qa/prod       │
          │     - Auto-close: dev only           │
          │     - Risk: low/medium/high          │
          └──────────────────────────────────────┘
                              │
                              ▼
                  ┌─────────────────────┐
                  │  Environment?       │
                  └─────────────────────┘
                   │              │              │
           dev ────┘              │              └──── prod
                                qa│
                                  │
                                  ▼
          ┌──────────────────────────────────────┐
          │  2. Wait for Approval                │
          │     - Poll ServiceNow every 30s      │
          │     - Timeout: 2h (QA) / 24h (Prod)  │
          │     - GitHub Actions paused          │
          └──────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Approval Status │
                    └──────────────────┘
                   │                  │
            Approved                Rejected
                   │                  │
                   ▼                  ▼
  ┌────────────────────────┐   ┌────────────────┐
  │  3. Deploy Application │   │  4. Fail Job   │
  │     - Pre-checks       │   │     - Notify   │
  │     - Kustomize apply  │   │     - Close CR │
  │     - Health checks    │   └────────────────┘
  │     - Smoke tests      │
  └────────────────────────┘
              │
              ▼
  ┌────────────────────────┐
  │  5. Update CMDB        │
  │     - Service records  │
  │     - Deployment info  │
  └────────────────────────┘
              │
              ▼
  ┌────────────────────────┐
  │  6. Close Change       │
  │     - Success/Failure  │
  │     - Add close notes  │
  └────────────────────────┘
```

---

## ServiceNow Configuration

### Step 1: Create Approval Groups (5 minutes)

#### 1.1 Create QA Team Group

1. **Navigate**: https://calitiiltddemo3.service-now.com/sys_user_group_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name:          QA Team
   Description:   Quality Assurance team responsible for QA environment approvals
   Type:          [Leave default]
   Manager:       [Your QA Lead user]
   ```

4. **Add Members**:
   - Click on "Group Members" tab
   - Add QA team members who can approve QA deployments

5. **Click**: Submit

#### 1.2 Create DevOps Team Group

1. **Click**: New (on groups list)

2. **Fill in**:
   ```
   Name:          DevOps Team
   Description:   DevOps engineers responsible for infrastructure
   Type:          [Leave default]
   Manager:       [Your DevOps Lead user]
   ```

3. **Add Members**:
   - Add DevOps engineers
   - Add Site Reliability Engineers (SREs)

4. **Click**: Submit

#### 1.3 Create Change Advisory Board (CAB) Group

1. **Click**: New

2. **Fill in**:
   ```
   Name:          Change Advisory Board
   Description:   Executive board for production change approvals
   Type:          [Leave default]
   Manager:       [Your CTO/VP Engineering]
   ```

3. **Add Members**:
   - CTO / VP Engineering
   - Lead DevOps Engineer
   - Lead QA Engineer
   - Security Lead
   - Product Manager

4. **Click**: Submit

---

### Step 2: Configure Approval Rules (10 minutes)

#### 2.1 Create QA Approval Rule

1. **Navigate**: https://calitiiltddemo3.service-now.com/change_approval_rule_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name:                QA Deployment Approval
   Description:         Requires QA Team Lead approval for QA deployments
   Active:              ✓ (checked)

   Conditions:
     - Risk: equals "Medium"
     - Assignment Group: equals "QA Team"
     - Short description: contains "qa"

   Approval:
     - Type: Group
     - Approver: QA Team
     - Required approvals: 1
   ```

4. **Click**: Submit

#### 2.2 Create Production Approval Rule

1. **Click**: New

2. **Fill in**:
   ```
   Name:                Production Deployment Approval
   Description:         Requires DevOps Lead + CAB approval for production
   Active:              ✓ (checked)

   Conditions:
     - Risk: equals "High"
     - Assignment Group: equals "Change Advisory Board"
     - Short description: contains "prod"

   Approval:
     - Type: Sequential
     - Stage 1: DevOps Team (1 required)
     - Stage 2: Change Advisory Board (2 required)
   ```

3. **Advanced Settings**:
   ```
   Approval timeout:     24 hours
   Auto-reject on timeout: No
   Notification: Send email to approvers
   ```

4. **Click**: Submit

#### 2.3 Create Dev Auto-Approval Rule

1. **Click**: New

2. **Fill in**:
   ```
   Name:                Dev Auto-Approval
   Description:         Auto-approves dev environment deployments
   Active:              ✓ (checked)

   Conditions:
     - Risk: equals "Low"
     - Assignment Group: equals "DevOps Team"
     - Short description: contains "dev"

   Approval:
     - Type: Auto-approve
     - No approvers needed
   ```

3. **Click**: Submit

---

### Step 3: Configure Email Notifications (5 minutes)

#### 3.1 Enable Change Request Notifications

1. **Navigate**: https://calitiiltddemo3.service-now.com/sys_email_list.do

2. **Search**: "change approval"

3. **Find**: "Change Request - Approval Requested"

4. **Click**: to open

5. **Configure**:
   ```
   Active:       ✓ (checked)
   Subject:      Approval Required: ${number} - ${short_description}
   Recipients:   Approvers
   CC:           Requester, Assignment Group

   Body:
   A change request requires your approval:

   Change Number: ${number}
   Environment: ${u_environment}
   Risk: ${risk}
   Requested by: ${sys_created_by}

   Description:
   ${description}

   Implementation Plan:
   ${implementation_plan}

   Approve or Reject:
   ${approval_link}

   View Change Request:
   ${instance_url}/nav_to.do?uri=change_request.do?sys_id=${sys_id}
   ```

6. **Click**: Update

---

### Step 4: Create Approval Policies (10 minutes)

#### 4.1 QA Approval Policy

1. **Navigate**: https://calitiiltddemo3.service-now.com/sys_script_list.do?sysparm_query=name=Change%20Request

2. **Click**: New

3. **Fill in**:
   ```
   Name:         QA Deployment Approval Check
   Table:        Change Request [change_request]
   When:         Before Insert
   Active:       ✓ (checked)

   Script:
   ```

```javascript
(function executeRule(current, previous /*null when async*/) {

    // Check if this is a QA deployment
    var shortDesc = current.short_description + '';
    if (shortDesc.toLowerCase().indexOf('qa') === -1) {
        return; // Not a QA deployment
    }

    // Set required approvals
    current.approval = 'requested'; // Pending approval
    current.priority = 2; // High priority
    current.risk = 2; // Medium risk

    // Add QA Team as approver
    var gr = new GlideRecord('sys_user_group');
    if (gr.get('name', 'QA Team')) {
        var approval = new GlideRecord('sysapproval_approver');
        approval.initialize();
        approval.approver = gr.manager;
        approval.source_table = 'change_request';
        approval.sysapproval = current.sys_id;
        approval.state = 'requested';
        approval.insert();

        gs.addInfoMessage('QA Team approval required for this change');
    }

})(current, previous);
```

4. **Click**: Submit

#### 4.2 Production Approval Policy

1. **Click**: New

2. **Fill in**:
   ```
   Name:         Production Deployment Approval Check
   Table:        Change Request [change_request]
   When:         Before Insert
   Active:       ✓ (checked)

   Script:
   ```

```javascript
(function executeRule(current, previous /*null when async*/) {

    // Check if this is a production deployment
    var shortDesc = current.short_description + '';
    if (shortDesc.toLowerCase().indexOf('prod') === -1) {
        return; // Not a production deployment
    }

    // Set required approvals
    current.approval = 'requested'; // Pending approval
    current.priority = 1; // Critical priority
    current.risk = 3; // High risk

    // Stage 1: DevOps Team Lead
    var devopsGr = new GlideRecord('sys_user_group');
    if (devopsGr.get('name', 'DevOps Team')) {
        var approval1 = new GlideRecord('sysapproval_approver');
        approval1.initialize();
        approval1.approver = devopsGr.manager;
        approval1.source_table = 'change_request';
        approval1.sysapproval = current.sys_id;
        approval1.state = 'requested';
        approval1.approval_order = 1;
        approval1.insert();
    }

    // Stage 2: Change Advisory Board
    var cabGr = new GlideRecord('sys_user_group');
    if (cabGr.get('name', 'Change Advisory Board')) {
        // Get all CAB members
        var memberGr = new GlideRecord('sys_user_grmember');
        memberGr.addQuery('group', cabGr.sys_id);
        memberGr.query();

        var cabMembers = [];
        while (memberGr.next()) {
            var approval2 = new GlideRecord('sysapproval_approver');
            approval2.initialize();
            approval2.approver = memberGr.user;
            approval2.source_table = 'change_request';
            approval2.sysapproval = current.sys_id;
            approval2.state = 'requested';
            approval2.approval_order = 2;
            approval2.insert();
        }

        gs.addInfoMessage('DevOps Lead + CAB approval required for production change');
    }

})(current, previous);
```

3. **Click**: Submit

---

## GitHub Actions Configuration

### Required GitHub Secrets

Ensure these secrets are configured in your repository:

```bash
# ServiceNow Integration
SERVICENOW_INSTANCE_URL=https://calitiiltddemo3.service-now.com
SERVICENOW_USERNAME=github_integration
SERVICENOW_PASSWORD=<your-password>
SERVICENOW_ORCHESTRATION_TOOL_ID=<tool-id>  # Optional, for DevOps Change

# AWS Credentials
AWS_ACCESS_KEY_ID=<your-key>
AWS_SECRET_ACCESS_KEY=<your-secret>
```

### Workflow Configuration

The workflow is already configured in [`.github/workflows/deploy-with-servicenow.yaml`](.github/workflows/deploy-with-servicenow.yaml).

**Key Features**:
- ✅ Environment-specific risk levels
- ✅ Auto-close for dev
- ✅ Approval gates for qa/prod
- ✅ Automatic rollback on failure
- ✅ CMDB updates
- ✅ Smoke tests

---

## Usage Guide

### Deploying to Dev (No Approval Required)

```bash
# Trigger via GitHub UI or CLI
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=dev
```

**Expected Flow**:
1. ✅ Change Request created (auto-approved)
2. ✅ Pre-deployment checks
3. ✅ Deploy to dev namespace
4. ✅ Health checks
5. ✅ Change Request closed automatically

**Time**: ~5-10 minutes

---

### Deploying to QA (Single Approval Required)

```bash
# Trigger deployment
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=qa
```

**Expected Flow**:
1. ✅ Change Request created
2. ⏸️ **Workflow PAUSES** - Waiting for approval
3. 📧 Email sent to QA Team Lead
4. 👤 **QA Lead approves in ServiceNow**
5. ✅ Workflow resumes
6. ✅ Deploy to qa namespace
7. ✅ Health checks + load tests
8. ✅ Change Request closed

**Time**: ~10-15 minutes + approval wait time

---

### Deploying to Prod (Multi-Level Approval Required)

```bash
# Trigger deployment
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=prod
```

**Expected Flow**:
1. ✅ Change Request created (HIGH risk, CRITICAL priority)
2. ⏸️ **Workflow PAUSES** - Waiting for Stage 1 approval
3. 📧 Email sent to DevOps Lead
4. 👤 **DevOps Lead approves** → Stage 1 complete
5. ⏸️ **Workflow PAUSES** - Waiting for Stage 2 approval
6. 📧 Email sent to all CAB members
7. 👥 **2+ CAB members approve** → Stage 2 complete
8. ✅ Workflow resumes
9. ✅ Deploy to prod namespace (3 replicas, HA)
10. ✅ Comprehensive smoke tests
11. ✅ CMDB updated
12. ✅ Change Request closed

**Time**: ~15-20 minutes + approval wait time (up to 24 hours)

---

## Approval Process

### How to Approve a Change Request

#### Method 1: Via Email Link (Fastest)

1. **Receive**: Email notification "Approval Required: CHGxxxxxxx"
2. **Click**: "Approve" link in email
3. **Add**: Optional approval comments
4. **Submit**: Approval

#### Method 2: Via ServiceNow UI

1. **Navigate**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do

2. **Filter**:
   - State: Assessment
   - Approval: Requested

3. **Open**: Your change request

4. **Scroll**: To "Approvers" section

5. **Click**: "Approve" or "Reject"

6. **Add**: Comments explaining decision

7. **Submit**: Approval decision

#### Method 3: Via My Approvals

1. **Navigate**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=sysapproval_approver_list.do?sysparm_query=approver=javascript:gs.getUserID()^state=requested

2. **View**: All pending approvals assigned to you

3. **Click**: Change request link

4. **Approve/Reject**: Follow steps above

---

## Monitoring Approvals

### GitHub Actions

While waiting for approval, the workflow shows:

```
⏸️ Wait for Change Approval
   ├─ Polling ServiceNow every 30 seconds...
   ├─ Change Request: CHG0123456
   ├─ Environment: prod
   ├─ Timeout in: 23h 45m
   └─ View in ServiceNow: [link]
```

### ServiceNow Dashboard

Create a custom dashboard to track approvals:

1. **Navigate**: https://calitiiltddemo3.service-now.com/pa_dashboards_list.do

2. **Click**: New

3. **Add Widgets**:
   - Pending Approvals (by environment)
   - Approval Turnaround Time
   - Approval History
   - Rejected Changes

---

## Approval SLAs

| Environment | Target Approval Time | Escalation |
|-------------|---------------------|------------|
| Dev | Immediate (auto) | N/A |
| QA | 2 hours | Manager after 2h |
| Prod | 4 hours (business hours) | VP after 8h |

---

## Rejection Handling

### What Happens When Rejected

1. ❌ Change Request state → "Closed/Rejected"
2. ❌ GitHub Actions workflow fails
3. 📧 Email sent to requester with rejection reason
4. 📝 Rejection comments logged in Change Request

### How to Retry After Rejection

1. **Review**: Rejection comments
2. **Fix**: Issues mentioned
3. **Create**: New Pull Request (if code changes needed)
4. **Trigger**: New deployment workflow
5. **Reference**: Previous Change Request in description

---

## Security & Audit

### Audit Trail

Every approval action is logged:

```
┌─────────────────────────────────────────────────────────────┐
│ Approval History                                            │
├─────────────────────────────────────────────────────────────┤
│ 2025-10-16 14:30:00 | DevOps Lead      | Approved | Stage 1│
│ 2025-10-16 14:35:00 | CAB Member 1     | Approved | Stage 2│
│ 2025-10-16 14:40:00 | CAB Member 2     | Approved | Stage 2│
│ 2025-10-16 14:45:00 | Deployment       | Success  | Complete│
└─────────────────────────────────────────────────────────────┘
```

### Compliance Reports

Generate compliance reports showing:
- ✅ All production changes had required approvals
- ✅ Approval turnaround times
- ✅ Rejection reasons and remediation
- ✅ Emergency change frequency

---

## Troubleshooting

### Workflow Stuck "Waiting for Approval"

**Check**:
1. Is Change Request state "Assessment"?
2. Are approvers assigned?
3. Did approval timeout expire?

**Fix**:
```bash
# Check Change Request status
curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=number=CHG0123456" \
  | jq '.result[0] | {state, approval, approval_set}'
```

### Approval Not Triggering Workflow Resume

**Symptoms**: Change approved in ServiceNow, but workflow still waiting

**Causes**:
1. ServiceNow DevOps Change plugin not installed
2. Orchestration Tool ID mismatch
3. Network connectivity issue

**Fix**:
1. Verify plugin: Navigate to "Plugins" → Search "DevOps Change"
2. Check Tool ID: `SERVICENOW_ORCHESTRATION_TOOL_ID` matches ServiceNow config
3. Re-approve and wait 30 seconds (polling interval)

### Approval Email Not Sent

**Check**: Email notification active
```
Navigate: System Logs → Emails
Filter: Recipients = [Approver email]
Check: Delivery status
```

**Fix**: Enable outbound email in ServiceNow instance settings

---

## Advanced Configuration

### Custom Approval Logic

Add business rules for complex approval scenarios:

```javascript
// Example: Require security team approval for changes after 5 PM
(function executeRule(current, previous) {
    var now = new GlideDateTime();
    var hour = now.getHourLocalTime();

    if (hour >= 17 && current.risk == 3) { // After 5 PM + High risk
        // Add Security Team to approvers
        var secGr = new GlideRecord('sys_user_group');
        if (secGr.get('name', 'Security Team')) {
            var approval = new GlideRecord('sysapproval_approver');
            approval.initialize();
            approval.approver = secGr.manager;
            approval.source_table = 'change_request';
            approval.sysapproval = current.sys_id;
            approval.state = 'requested';
            approval.insert();

            gs.addInfoMessage('After-hours production change requires Security Team approval');
        }
    }
})(current, previous);
```

### Emergency Change Process

For urgent production fixes:

```bash
# Use emergency change type (bypasses some approvals)
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=prod \
  --field change_type=emergency
```

Requires: CTO/VP approval only (instead of full CAB)

---

## Best Practices

### For Requesters

✅ **DO**:
- Provide detailed implementation plan
- Include rollback procedure
- Test in dev/qa first
- Deploy during maintenance windows
- Add relevant documentation links

❌ **DON'T**:
- Deploy untested code to prod
- Skip qa environment
- Deploy without backout plan
- Make changes during peak hours without approval

### For Approvers

✅ **DO**:
- Review implementation plan thoroughly
- Verify testing was completed
- Check for security implications
- Ensure monitoring is in place
- Approve/reject within SLA

❌ **DON'T**:
- Approve without reading
- Rubber-stamp approvals
- Ignore risk indicators
- Skip rollback plan review

---

## Metrics & KPIs

Track these metrics to improve approval process:

| Metric | Target | Current |
|--------|--------|---------|
| Average QA Approval Time | < 2 hours | TBD |
| Average Prod Approval Time | < 4 hours | TBD |
| Approval Rejection Rate | < 5% | TBD |
| Emergency Changes | < 5% of total | TBD |
| Rollback Rate | < 2% | TBD |

---

## Next Steps

1. ✅ **Complete ServiceNow Configuration** (Steps 1-4 above)
2. ✅ **Test Approval Flow** (Start with dev, then qa)
3. ✅ **Train Team Members** (Approvers and requesters)
4. ✅ **Monitor First 10 Deployments** (Refine process as needed)
5. ✅ **Create Custom Dashboards** (Track KPIs)
6. ✅ **Document Lessons Learned** (Continuous improvement)

---

## Related Documentation

- [Deploy with ServiceNow Workflow](.github/workflows/deploy-with-servicenow.yaml)
- [ServiceNow Quick Start](SERVICENOW-QUICK-START.md)
- [Kustomize Multi-Environment Guide](../kustomize/overlays/README.md)
- [Security Scanning Integration](SERVICENOW-SECURITY-SCANNING.md)

---

**Questions?** Contact the DevOps team or create an issue in the repository.
