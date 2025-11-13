# ServiceNow Playbook Investigation Guide

> **Objective**: Identify and configure GitHub integration to use ServiceNow playbook workflow like GitLab
> **Date**: 2025-11-10
> **Issue**: GitHub #78 - Online Boutique DevOps Insights Integration

---

## Executive Summary

**Finding**: HelloWorld4 (GitLab) successfully has DevOps Insights data because it was created via `"creation_source": "playbook"` automation workflow. Online Boutique (GitHub) was created manually/via API and lacks insights record.

**Goal**: Identify the GitLab playbook workflow and adapt it for GitHub integration, or manually trigger playbook for Online Boutique.

---

## Investigation Results

### Business Rules Analysis

**Query**: Business rules on `sn_devops_app` table

**BEFORE rules found** (7 total):
- `Fetch DevOps app records`
- `Block duplicate application name`
- `App - Objects association Check`
- `Set current user as owner`
- `Validate SDLC on update`
- `Populate SDLC`
- `Check user exists in Assigned group`

**AFTER rules found**: NONE

**Conclusion**: No business rule automatically creates insights records after application creation. The playbook must handle this.

### DevOps Flows Found

**Flows related to DevOps** (from earlier search):
1. `DevOps Associate Services` (sys_hub_flow: 02ebee3b5b210110ad4f9113a281c734)
2. `DevOps template subflow for connect` (sys_hub_flow: 0b5dea1447e8ca108ed390db416d4301)
3. `DevOps Notify Tool Change Event` (sys_hub_flow: 0bcc918d43e8b1105438d93dbfb8f2a3)

**Status**: These appear to be integration/connection flows, not application creation flows.

### HelloWorld4 Details

```json
{
  "sys_id": "aa2562a4c320b650e1bbf0cb050131c1",
  "name": "HelloWorld4",
  "sys_created_by": "alex.wells@calitii.com",
  "sys_created_on": "2025-10-09 15:51:07",
  "creation_source": "playbook",
  "sdlc_component": "e22562a4c320b650e1bbf0cb050131c0"
}
```

**Key Fields**:
- `creation_source`: `"playbook"` (indicates automated workflow)
- `sdlc_component`: Links to CMDB CI SDLC Component record
- Created by: `alex.wells@calitii.com` (not a service account)

### Online Boutique Details

```json
{
  "sys_id": "e489efd1c3383e14e1bbf0cb050131d5",
  "name": "Online Boutique",
  "sys_created_by": "github_integration",
  "sys_created_on": "2025-11-09 16:55:05",
  "creation_source": "",
  "sdlc_component": ""
}
```

**Differences**:
- ❌ No `creation_source` (empty)
- ❌ No `sdlc_component` linkage
- Created via: Manual/API (not playbook)

---

## Playbook Investigation Steps

### Step 1: Access ServiceNow Flow Designer

**URL**: `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/flow_designer.do`

**Login**: Use `github_integration` or admin account

**Navigation**:
1. Click "All" (hamburger menu)
2. Type: "Flow Designer"
3. Click: **Process Automation → Flow Designer**

### Step 2: Search for Application Creation Flows

**In Flow Designer**:
1. Click "Flows" tab
2. Search filters:
   - Name contains: "application", "app", "devops", "gitlab", "create"
   - Status: Published
   - Created by: alex.wells@calitii.com
3. Look for flows that:
   - Have "application" in name/description
   - Mention "sn_devops_app" table
   - Include "insights" creation steps

### Step 3: Identify Playbook Used by GitLab

**Queries to try**:

**A. Search by creation_source field**:
```javascript
// In Flow Designer, look for flows that set:
current.creation_source = "playbook";
```

**B. Search for insights table operations**:
```javascript
// Look for flows that insert into:
sn_devops_insights_st_summary
```

**C. Check GitLab-specific flows**:
```
Search for: "GitLab", "gitlab", "git lab"
Filter by: Active = true, Status = Published
```

### Step 4: Examine Flow Steps

**For each candidate flow, check for**:
1. **Trigger**: When does flow run?
   - Manual trigger?
   - Webhook from GitLab?
   - Scheduled?
   - On application creation?

2. **Steps**:
   - Create `sn_devops_app` record
   - Set `creation_source = "playbook"`
   - Create `sn_devops_insights_st_summary` record
   - Link project to application
   - Set SDLC component

3. **Permissions**:
   - Run as: System user?
   - Elevated privileges?
   - ACL bypass enabled?

---

## Alternative Investigation Methods

### Method 1: Check SDLC Component

HelloWorld4 has `sdlc_component` field populated. This might be the key linkage.

**Query SDLC Component**:
```bash
source .envrc
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/cmdb_ci_sdlc_component/e22562a4c320b650e1bbf0cb050131c0?sysparm_display_value=all"
```

**Check if SDLC Component has playbook linkage**:
- Look for related flows
- Check business rules on `cmdb_ci_sdlc_component` table
- See if creating SDLC component triggers insights creation

### Method 2: Contact ServiceNow Admin

**Questions for alex.wells@calitii.com** (HelloWorld4 creator):
1. How did you create HelloWorld4 application?
2. What UI steps did you follow?
3. Which playbook/flow was used?
4. Can you share screenshots of the creation process?
5. Can we repeat the process for Online Boutique?

### Method 3: ServiceNow Documentation

**Search ServiceNow Product Documentation**:
- Topic: "DevOps Insights application registration"
- Search: "playbook devops application"
- Check: GitLab integration setup guide
- Review: GitHub vs GitLab integration differences

**Documentation URLs** (check in ServiceNow docs):
```
https://docs.servicenow.com/bundle/
  vancouver-devops/page/product/devops/concept/devops-insights.html
```

### Method 4: System Logs

**Check System Logs for HelloWorld4 Creation**:

**URL**: `https://calitiiltddemo3.service-now.com/nav_to.do?uri=syslog_list.do`

**Query**:
```bash
source .envrc
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/syslog?sysparm_query=sys_created_on>2025-10-09^sys_created_on<2025-10-10^messageLIKEHelloWorld4^ORmessageLIKEaa2562a4c320b650e1bbf0cb050131c1&sysparm_display_value=all&sysparm_fields=sys_created_on,level,message" \
  | jq '.result[] | {created: .sys_created_on.value, level: .level.value, message: .message.value}'
```

**Look for**:
- Flow execution logs
- Table insert operations
- ACL bypass messages
- Playbook trigger events

### Method 5: Flow Execution History

**Check Flow Execution Context**:

**URL**: `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sys_flow_context_list.do`

**Query**:
```bash
source .envrc
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_flow_context?sysparm_query=sys_created_on>2025-10-09^sys_created_on<2025-10-10&sysparm_display_value=all&sysparm_fields=sys_created_on,flow,state,output" \
  | jq '.result[] | {created: .sys_created_on.value, flow: .flow.display_value, state: .state.value}'
```

**Filter by**:
- Created date: 2025-10-09 (HelloWorld4 creation date)
- Flow name: Contains "application" or "devops"
- State: Completed successfully

---

## Recommended Action Plan

### Immediate Actions (ServiceNow UI Investigation)

1. ✅ **Login to ServiceNow**
   - URL: https://calitiiltddemo3.service-now.com
   - User: `github_integration` or admin

2. ✅ **Access Flow Designer**
   - Navigation: All → Process Automation → Flow Designer
   - Search for: "application", "devops", "gitlab"

3. ✅ **Examine Candidate Flows**
   - Look for flows that create `sn_devops_app` records
   - Check for `sn_devops_insights_st_summary` creation steps
   - Note which flow sets `creation_source = "playbook"`

4. ✅ **Test Flow Manually**
   - If flow found, attempt manual execution
   - Input: Online Boutique application details
   - Expected: Insights record created automatically

### Medium-term Actions (Contact ServiceNow Users)

1. ✅ **Email alex.wells@calitii.com**
   - Subject: "HelloWorld4 DevOps Insights Creation Process"
   - Ask: How HelloWorld4 was created (playbook used)
   - Request: Guidance for creating insights for Online Boutique

2. ✅ **ServiceNow Support Ticket**
   - Topic: DevOps Insights application registration
   - Question: Difference between GitLab and GitHub integration
   - Request: Documentation for playbook-based application creation

### Long-term Actions (Workflow Configuration)

1. ✅ **Configure GitHub Integration Playbook**
   - Clone GitLab playbook for GitHub
   - Adapt tool type and webhook patterns
   - Test with new application

2. ✅ **Re-register Online Boutique**
   - Delete current application record
   - Create via playbook workflow
   - Verify insights record auto-created

3. ✅ **Document Process**
   - Create runbook for GitHub app registration
   - Include playbook trigger instructions
   - Add to onboarding docs

---

## Fallback Options

### If Playbook Not Found

**Option A: Manual Insights Creation**
- Navigate to direct form URL
- Fill with exact values (see SERVICENOW-QUICK-START.md)
- Requires sys_id field visibility

**Option B: ServiceNow Admin Request**
- Submit support ticket (see SERVICENOW-SUPPORT-TICKET-TEMPLATE.md)
- Request privileged script execution
- Provide exact field values

**Option C: Custom Application Field**
- Create `u_application` field on quality scan table
- Already completed (23 scans linked)
- Build custom dashboard (bypassing insights table)

### If Playbook Requires GitLab-Specific Data

**Adaptation Steps**:
1. Identify GitLab-specific fields in playbook
2. Map GitHub equivalents:
   - GitLab Project → GitHub Repository
   - GitLab Webhook → GitHub Actions webhook
   - GitLab CI/CD → GitHub Actions workflow
3. Update playbook inputs for GitHub compatibility
4. Test with staging application first

---

## Success Criteria

Playbook investigation successful when:

- [ ] Playbook identified that creates HelloWorld4
- [ ] Flow designer shows playbook workflow steps
- [ ] Playbook can be executed manually or via webhook
- [ ] Documentation explains when playbook triggers
- [ ] GitHub integration can use same/adapted playbook

**Verification**:
```bash
# After running playbook for Online Boutique
source .envrc
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary/e489efd1c3383e14e1bbf0cb050131d5" \
  | jq '.result | {sys_id, application, pipeline_executions}'

# Expected: Record exists with populated data (not HTTP 404)
```

---

## Technical Insights

### Why Playbooks Bypass ACLs

**ServiceNow Playbook Privileges**:
- Flows run with elevated system context
- ACL checks can be bypassed for automation
- `creation_source = "playbook"` marks records as system-created
- Prevents manual tampering with automated processes

**Implication**: This is BY DESIGN. ServiceNow expects applications to be registered via playbooks, not manual API calls.

### Playbook vs Manual Creation

| Aspect | Playbook Creation | Manual/API Creation |
|--------|-------------------|---------------------|
| **creation_source** | `"playbook"` | `""` (empty) |
| **Insights Record** | Auto-created ✅ | NOT created ❌ |
| **SDLC Component** | Linked ✅ | NOT linked ❌ |
| **ACL Bypass** | Yes ✅ | No ❌ |
| **Permissions** | System context | User context |
| **Recommended** | YES ✅ | NO ❌ |

### Expected Workflow

**Proper DevOps Integration Workflow**:
```
1. Configure Tool (GitLab/GitHub) in ServiceNow
2. Tool webhook triggers ServiceNow playbook
3. Playbook creates Application (sn_devops_app)
4. Playbook creates Insights (sn_devops_insights_st_summary)
5. Playbook links Project to Application
6. All subsequent scans auto-aggregate in Insights
```

**Our Current Workflow (Wrong)**:
```
1. Manual Application creation via API ❌
2. No insights record created ❌
3. No SDLC component linkage ❌
4. Scans upload to Project (not Application) ❌
5. No insights dashboard visibility ❌
```

---

## Next Steps

**User Action Required**:
1. Login to ServiceNow UI
2. Navigate to Flow Designer
3. Search for application creation playbooks
4. Identify GitLab playbook
5. Report findings (flow name, sys_id, description)

**After Playbook Identified**:
1. Test manual playbook execution for Online Boutique
2. Adapt playbook for GitHub integration
3. Re-register application via playbook
4. Verify insights record created
5. Update GitHub Actions workflow to trigger playbook

---

*Investigation Guide Created: 2025-11-10*
*Issue: GitHub #78*
*Status: Playbook investigation in progress*
