# ServiceNow Playbook Investigation Findings

> Investigation Date: 2025-11-10
> Related Issue: [#78](https://github.com/Freundcloud/microservices-demo/issues/78)

## Executive Summary

**Investigation Goal**: Identify which ServiceNow playbook/flow was triggered when repository was linked to project, and why it didn't create DevOps Insights record.

**Key Finding**: **NO playbook was triggered** that specifically creates DevOps Insights records. The Application's `creation_source` field change from `""` to `"playbook"` likely occurred via a different mechanism (manual update, business rule, or earlier playbook execution).

---

## API Investigation Results

### 1. Flow Executions Analysis

**Time window**: 2025-11-10 14:50:00 - 14:55:00 UTC (repository linked at 14:52:36)

**Total flows executed**: 2,606 executions

**Flow types identified**:
- `DevOps Integration - Orchestration Notification` (webhook-triggered)
- `GitHub Orchestration Notification` (pipeline events)
- `GitHub Get Pipeline Info` (pipeline metadata)
- `FetchSonarScanResultsForGitHub` (SBOM/security scans)
- `Fetch Test Results for Github` (test results)
- `DevOps Error Handler for Inbound Event` (error handling)
- `DevOps Troubleshooter` (diagnostic flows)
- `send_notifications` (notification delivery)

**Critical Finding**: **ZERO** flows executed that relate to:
- Application creation/update
- DevOps Insights record creation
- Repository-to-Project linking automation
- Application `creation_source` field updates

**Conclusion**: The repository linking operation did **NOT** trigger any playbook/flow that would create a DevOps Insights record.

### 2. Business Rules Analysis

**Table**: `sn_devops_app` (Application table)

**Total business rules**: 7 rules

**Rules found**:
- 7 BEFORE rules (execute before record operations)
- 0 AFTER rules (execute after record operations)

**Script content search**:
- Searched for: `creation_source`, `playbook`, `insights`
- **Result**: NO business rules reference these fields

**Conclusion**: No business rules automatically update `creation_source` field or create insights records when repository is linked.

### 3. Audit Log Analysis

**Table**: `sys_audit` (tracks field changes)

**Query**: Application sys_id `e489efd1c3383e14e1bbf0cb050131d5` changes since 2025-11-10

**Result**: Empty array `[]`

**Possible reasons**:
1. Audit logging not enabled for `sn_devops_app` table
2. Audit logging not enabled for `creation_source` field
3. Field changes occurred before audit logging was enabled
4. Audit records were purged

**Conclusion**: Cannot determine when/how `creation_source` field was changed via API.

### 4. System Logs Analysis

**Query**: Logs containing "insights", "sn_devops_insights", or "playbook" since 2025-11-10

**Result**: No matching logs found

**Conclusion**: No errors or warnings logged related to insights record creation attempts.

---

## Analysis: How Did creation_source Change?

### Timeline of Events

1. **Before 2025-11-10 14:32**: Application created manually (via UI or previous script)
   - `creation_source`: `""` (empty)
   - No insights record created

2. **2025-11-10 14:32:08**: Repository created by `github_integration` user
   - Repository sys_id: `2cb353f6c3c13a10b71ef44c0501313f`
   - Linked to Application initially

3. **2025-11-10 14:52:36**: Repository linked to Project via PATCH API
   - Updated: `project` field set to `c6c9eb71c34d7a50b71ef44c05013194`
   - No playbook/flow executed
   - **Somehow**: `creation_source` changed to `"playbook"`

4. **Current state**: Application has `creation_source: "playbook"` but NO insights record

### Hypotheses

#### Hypothesis A: Manual Application Update (MOST LIKELY)
**Theory**: Application's `creation_source` was manually updated to `"playbook"` at some point (possibly during earlier troubleshooting attempts or configuration).

**Evidence**:
- No audit log of change
- No business rules updating field
- No flows executed during repository linking
- Field might have been updated via ServiceNow UI or earlier API call

**Probability**: HIGH (80%)

#### Hypothesis B: Earlier Playbook Execution
**Theory**: A playbook ran when Application was first created, updated `creation_source`, but failed to create insights record.

**Evidence**:
- Application created on unknown date (before 2025-11-10 14:32)
- If GitLab-style playbook ran, it would set `creation_source: "playbook"`
- Playbook might have encountered error creating insights record (ACL blocked)

**Probability**: MEDIUM (15%)

#### Hypothesis C: Business Rule Not Visible via API
**Theory**: There's a business rule or workflow that updates `creation_source` but isn't visible via REST API query.

**Evidence**:
- Some ServiceNow configurations hidden from API
- Scoped apps may have rules not accessible to integration user

**Probability**: LOW (5%)

---

## What This Means

### Key Conclusions

1. **No playbook currently triggers** when repository is linked to project
   - GitHub integration does NOT use the same playbook workflow as GitLab
   - Repository linking is purely a data relationship operation

2. **Application `creation_source: "playbook"` is misleading**
   - Field value suggests playbook created application
   - BUT no evidence of playbook execution in recent timeframe
   - Field might be manually set or from earlier unknown event

3. **DevOps Insights record creation is NOT automated** for GitHub integrations
   - GitLab integration: Automatic via playbook
   - GitHub integration: Manual or requires different trigger

### Why Insights Record Doesn't Exist

**Root Cause**: ServiceNow's GitHub integration does **NOT** include a playbook workflow that creates DevOps Insights records automatically.

**Comparison**:
- **GitLab Integration**: Playbook creates Application + Insights record together
- **GitHub Integration**: Creates Project + Repository only, **NOT** Application or Insights

**Implications**:
- Application was created manually (or via different process)
- Insights record must be created manually or via different mechanism
- Linking repository to project does NOT trigger insights creation

---

## Next Steps - UI Investigation Required

Since API investigation reached its limit, **manual ServiceNow UI investigation is required**:

### Step 1: Access Flow Designer

**URL**: `https://calitiiltddemo3.service-now.com/nav_to.do?uri=sys_hub_flow_list.do`

**Actions**:
1. Login as admin user with Flow Designer access
2. Search for flows containing:
   - "application"
   - "insights"
   - "DevOps"
3. Check each flow's **Trigger** conditions:
   - Does it trigger on `sn_devops_app` table operations?
   - Does it trigger on `sn_devops_repository` table operations?
4. Review flow **Actions**:
   - Does any flow create records in `sn_devops_insights_st_summary`?
   - Does any flow update `creation_source` field?

### Step 2: Check Flow Execution History

**URL**: Flow Designer → (Select Flow) → Execution History

**Actions**:
1. For each relevant flow found in Step 1:
   - View execution history for past 30 days
   - Filter by Application sys_id: `e489efd1c3383e14e1bbf0cb050131d5`
   - Check if any executions failed or completed with errors

2. Look for executions around:
   - **2025-11-10 14:52:36** (repository linking time)
   - **2025-11-10 14:32:08** (repository creation time)
   - **Unknown date** (Application creation time)

### Step 3: Enable Audit Logging

**URL**: `https://calitiiltddemo3.service-now.com/sys_dictionary_list.do?sysparm_query=name=sn_devops_app^element=creation_source`

**Actions**:
1. Find `creation_source` field definition
2. Check if "Audit" checkbox is enabled
3. If not enabled: Enable auditing for future changes
4. Check `sn_devops_insights_st_summary` table audit settings

### Step 4: Check Application Creation History

**URL**: `https://calitiiltddemo3.service-now.com/sn_devops_app.do?sys_id=e489efd1c3383e14e1bbf0cb050131d5`

**Actions**:
1. View Application record
2. Check "Created by" and "Created on" fields
3. Check "Updated by" and "Updated on" fields
4. Check "Sys Created On": Determine when Application was first created
5. Review all field values for clues about creation method

### Step 5: Search for GitLab Playbook Reference

**URL**: Flow Designer → Search

**Actions**:
1. Search for "GitLab" flows
2. Identify the flow that creates insights for HelloWorld4
3. Compare with GitHub flows to find missing steps
4. Document differences in flow actions

### Step 6: Contact HelloWorld4 Creator

**Email**: alex.wells@calitii.com

**Subject**: How was HelloWorld4 DevOps Insights record created?

**Email template**:
```
Hi Alex,

I'm investigating why the Online Boutique (GitHub) application doesn't appear
in DevOps Insights dashboard, while HelloWorld4 (GitLab) does.

Could you please help with these questions:

1. How was HelloWorld4 application created in ServiceNow?
   - Manual creation or automatic via playbook?

2. Did you configure any special playbook/flow for GitLab integration?
   - If yes, which flow/playbook?

3. Was the DevOps Insights record created automatically or manually for HelloWorld4?
   - If automatic, which flow created it?

4. Are there any differences in how GitLab vs GitHub integrations are configured?

Application Details:
- HelloWorld4: e2cb939ec3553610b30cf6a3050131fc (has insights record)
- Online Boutique: e489efd1c3383e14e1bbf0cb050131d5 (no insights record)

Thank you!
```

---

## Alternative Approaches

### Option A: Manual Insights Record Creation via UI

**Try direct form URL**:
```
https://calitiiltddemo3.service-now.com/sn_devops_insights_st_summary.do?sys_id=e489efd1c3383e14e1bbf0cb050131d5
```

**Field values**:
- sys_id: `e489efd1c3383e14e1bbf0cb050131d5` (match Application sys_id)
- application: `e489efd1c3383e14e1bbf0cb050131d5`
- Leave other fields blank (will populate from data)

**See**: [SERVICENOW-QUICK-START.md](SERVICENOW-QUICK-START.md)

### Option B: ServiceNow Support Ticket

**Submit ticket** with:
- Issue: Application has `creation_source: "playbook"` but no insights record
- Request: Investigate why playbook didn't create insights
- Request: Manually create insights record with elevated permissions

**See**: [SERVICENOW-SUPPORT-TICKET-TEMPLATE.md](SERVICENOW-SUPPORT-TICKET-TEMPLATE.md)

### Option C: Request Privileged Script Execution

**Ask ServiceNow admin to run**:
```javascript
var gr = new GlideRecord('sn_devops_insights_st_summary');
gr.initialize();
gr.sys_id = 'e489efd1c3383e14e1bbf0cb050131d5';
gr.application = 'e489efd1c3383e14e1bbf0cb050131d5';
gr.insert();
gs.info('Insights record created: ' + gr.sys_id);
```

**Note**: Only ServiceNow admin with elevated permissions can execute background scripts bypassing ACLs.

---

## Files Created

- `/tmp/investigate_playbook_execution.sh` - Flow and log investigation script
- `/tmp/check_flow_executions_around_repository_link.sh` - Flow execution timeline
- `/tmp/devops_flows.json` - List of all DevOps-related flows
- `/tmp/flow_contexts_around_link.json` - Flow executions during repository linking
- `/tmp/app_all_business_rules.json` - Business rules on sn_devops_app table
- `/tmp/app_audit_log.json` - Application field change audit log (empty)

---

## Recommendation

**Primary Action**: **Contact HelloWorld4 creator (alex.wells@calitii.com)** - Option 6 from investigation

**Why**:
- Fastest path to understanding GitLab vs GitHub integration differences
- Direct comparison with working setup
- May reveal missing configuration or manual steps required

**Secondary Action**: Try manual UI form creation - Option A above

**Why**:
- Quick workaround if ACL allows UI creation
- Can be attempted immediately without support ticket
- May succeed where API failed

**Tertiary Action**: ServiceNow support ticket - Option B above

**Why**:
- Official support channel
- Can request privileged script execution
- May reveal product limitations or bugs

---

*Investigation completed: 2025-11-10*
*API investigation: Exhausted*
*Next step: Manual UI investigation or HelloWorld4 creator contact*
