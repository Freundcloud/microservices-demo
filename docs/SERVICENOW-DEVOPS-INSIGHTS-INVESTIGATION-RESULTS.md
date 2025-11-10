# ServiceNow DevOps Insights Investigation Results

## Executive Summary

**Issue**: Online Boutique application not appearing in ServiceNow DevOps Insights dashboard
**Status**: **ROOT CAUSE IDENTIFIED** - Architectural limitation in ServiceNow schema
**Resolution**: **BLOCKED** - Requires ServiceNow configuration, module installation, or support

## Investigation Timeline

### 2025-11-10: Initial Investigation

#### Diagnostic Results

```bash
# Project exists with no number
Project: null (sys_id: c6c9eb71c34d7a50b71ef44c05013194)

# 21 SBOM summaries linked to project
SBOM summaries linked to project: 21

# Application exists but has no data
Application: "Online Boutique" (sys_id: e489efd1c3383e14e1bbf0cb050131d5)
  - SBOM summaries: 0
  - Test summaries: 0
  - Insights records: 0
```

#### Initial Hypothesis
Project and SBOM summaries need to be linked to the application for DevOps Insights aggregation to work.

### 2025-11-10: Fix Attempt

#### Actions Taken
1. Created fix script (`/tmp/fix-devops-insights-linkage-v2.sh`)
2. Attempted to update project record with `application` field
3. Attempted to update 21 SBOM summary records with `application` field

#### Results
```
✓ Project linked to application (HTTP 200)
✓ Updated SBOM summary: [21 records] (HTTP 200)
✓ Retroactive linking complete
  Success: 21
  Failed: 0
```

#### Verification
```bash
# All updates appeared successful but...
Project application link: null
SBOM summaries linked to application: 0
```

**Conclusion**: All API calls returned HTTP 200, but **zero fields were actually updated**.

### 2025-11-10: Schema Investigation

#### Discovery: Fields Don't Exist

**Checked table schemas:**

```bash
# sn_devops_project schema check
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_project^element=application"
# Result: [] (no results - field doesn't exist)

# sn_devops_software_quality_scan_summary schema check
curl "$SERVICENOW_INSTANCE_URL/api/now/table/sys_dictionary?sysparm_query=name=sn_devops_software_quality_scan_summary^element=application"
# Result: [] (no results - field doesn't exist)
```

**Available fields on `sn_devops_software_quality_scan_summary`:**
- ✅ `tool` (reference to sn_devops_tool)
- ✅ `project` (reference to sn_devops_project)
- ✅ `initiated_by` (reference to sn_devops_participant)
- ❌ `application` (DOES NOT EXIST)

**Available fields on `sn_devops_project`:**
- ✅ `name`, `tool`, `webhook_url`, etc.
- ❌ `application` (DOES NOT EXIST)
- ❌ `app` (DOES NOT EXIST)
- ❌ `business_app` (DOES NOT EXIST)

**Available fields on `sn_devops_app`:**
- ✅ `name`, `owner`, `business_app`, etc.
- ❌ `project` (DOES NOT EXIST)
- ❌ `projects` (DOES NOT EXIST)

## Root Cause Analysis

### The Architectural Limitation

**ServiceNow's data flow expectation:**
```
GitHub Workflows
    ↓ uploads data
Quality Scan Summaries
    ↓ linked via 'application' field
Application (sn_devops_app)
    ↓ aggregated by
DevOps Insights (sn_devops_insights_st_summary)
    ↓ displayed in
DevOps Insights Dashboard
```

**What actually exists:**
```
GitHub Workflows
    ↓ uploads data with 'project' sys_id
Quality Scan Summaries
    ├─→ project: ✅ c6c9eb71c34d7a50b71ef44c05013194 (21 records)
    └─→ application: ❌ [FIELD DOESN'T EXIST]

Project (sn_devops_project)
    ├─→ name: "Freundcloud/microservices-demo"
    ├─→ tool: GitHub tool sys_id
    └─→ application: ❌ [FIELD DOESN'T EXIST]

Application (sn_devops_app)
    ├─→ name: "Online Boutique"
    ├─→ created manually (creation_source: "playbook")
    └─→ project: ❌ [FIELD DOESN'T EXIST]

DevOps Insights
    └─→ Cannot aggregate - no application linkage ❌
```

### Why ServiceNow Silently Accepted Updates

When PATCHing non-existent fields, ServiceNow:
1. Returns HTTP 200 (success)
2. Silently ignores the non-existent field
3. Doesn't return errors or warnings
4. Doesn't update anything

This is standard ServiceNow API behavior for unknown fields.

## Current State

### What's Working
- ✅ GitHub integration creating projects automatically
- ✅ Workflows uploading SBOM summaries with project linkage
- ✅ Project record exists with correct tool association
- ✅ 21 SBOM summaries linked to project
- ✅ Application record exists (manually created)

### What's NOT Working
- ❌ No schema fields to link projects ↔ applications
- ❌ No automatic application creation by GitHub integration
- ❌ SBOM summaries cannot link to application (field doesn't exist)
- ❌ DevOps Insights cannot aggregate (no application data)
- ❌ Application not visible in Insights dashboard

## Questions Requiring ServiceNow Expertise

### 1. Module/Version Configuration

**Questions:**
- What version of ServiceNow DevOps Change is installed?
- Is DevOps Insights a separate module/license?
- Are all required plugins activated?
- Is there a schema version mismatch?

**Check:**
```bash
# Check installed DevOps plugins
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=nameLIKEdevops^active=true&sysparm_fields=name,version,active" \
  | jq '.result[] | {name, version}'
```

### 2. Hidden Linking Mechanism

**Questions:**
- Is there a many-to-many (m2m) table linking projects and applications?
- Are there related lists in the UI that aren't exposed via API?
- Is there a ServiceNow business rule that should create these links?

**Check:**
```bash
# Search for m2m tables
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_db_object?sysparm_query=nameLIKEdevops^nameLIKEm2m&sysparm_fields=name,label"
```

### 3. Expected Configuration Steps

**Questions:**
- Is there a manual step in ServiceNow UI to associate projects with applications?
- Should the GitHub tool configuration include application mappings?
- Is there a playbook/flow that should run to create applications automatically?

**Investigate:**
- ServiceNow DevOps Change configuration settings
- GitHub tool record configuration
- Playbook/Flow builder for DevOps automation

### 4. API vs UI Differences

**Questions:**
- Can project-application linking be done in the ServiceNow UI but not via API?
- Are there custom fields that need to be added manually?
- Is this a security/ACL restriction preventing API updates?

**Test:**
- Login to ServiceNow UI
- Navigate to project record
- Check if there's an "Application" field or related list
- Attempt manual linking

## Recommended Next Steps

### Immediate Actions

1. **Review ServiceNow Instance Configuration**
   ```bash
   # Check DevOps plugins installed
   # Check module versions
   # Check activated features
   ```

2. **Check ServiceNow Documentation**
   - Search: "DevOps Insights project application linking"
   - Search: "DevOps Change application association"
   - Review: GitHub integration setup guide

3. **ServiceNow UI Investigation**
   - Login and navigate to Projects module
   - Check if Application field exists in form
   - Look for Related Lists linking to applications
   - Check Application record for project-related lists

### Medium-Term Actions

1. **ServiceNow Support Ticket**
   - Describe: Projects created but not linked to applications
   - Ask: Expected schema for project-application linking
   - Request: Configuration steps for DevOps Insights

2. **ServiceNow Community**
   - Post in DevOps forums
   - Search for similar issues
   - Ask about project-application linking

3. **Alternative Documentation**
   - Check release notes for schema changes
   - Review upgrade guides
   - Look for known issues/limitations

### Long-Term Solutions

1. **If Configuration Issue:**
   - Follow ServiceNow setup documentation
   - Enable missing features/modules
   - Configure proper tool associations

2. **If Custom Fields Needed:**
   - Create custom reference fields
   - Add to project and/or quality scan tables
   - Update workflows to populate

3. **If Architectural Limitation:**
   - Contact ServiceNow for roadmap
   - Request feature enhancement
   - Consider alternative reporting approach

## Workaround Options (If No Native Solution)

### Option A: Custom Application Field
```javascript
// Add custom field to sn_devops_project table
// Via ServiceNow Studio
table: sn_devops_project
field: u_application
type: Reference
reference: sn_devops_app
```

Then update workflows to populate `u_application` instead of `application`.

### Option B: Custom Aggregation Script
```javascript
// Create scheduled job to aggregate data
// Query projects
// For each project, find or create application
// Link quality scans to application
// Populate insights summary manually
```

### Option C: Custom Insights Dashboard
```javascript
// Build custom dashboard
// Query projects directly
// Aggregate quality scan data
// Display without using sn_devops_insights_st_summary
```

## Files Generated During Investigation

- `/tmp/check-project-details.sh` - Project record investigation
- `/tmp/check-insights-aggregation.sh` - Insights aggregation check
- `/tmp/fix-devops-insights-linkage.sh` - Initial fix attempt
- `/tmp/fix-devops-insights-linkage-v2.sh` - Improved fix script
- `/tmp/verify-linkage.sh` - Linkage verification
- `/tmp/check-table-schema.sh` - Schema investigation
- `/tmp/check-insights-linkage-model.sh` - Data model analysis
- `/tmp/find-app-project-relationship.sh` - Relationship discovery
- `/tmp/check-reverse-relationship.sh` - Reverse linkage check
- `/tmp/final-summary.md` - Investigation summary

## Repository Configuration Fix (2025-11-10)

### Issue: Duplicate Repository Entries

During investigation, discovered duplicate repository entries in GithHubARC tool:
- Repository sys_id `02217f7dc38d7a50b71ef44c05013178` - Had Project linked but NO imported data (branches, commits)
- Repository sys_id `a27eca01c3303a14e1bbf0cb05013125` - NO Project, NO Application
- Repository sys_id `2cb353f6c3c13a10b71ef44c0501313f` - **Original with imported data**, had Application but NO Project

### Resolution

1. **Deleted empty repositories** (02217f7dc38d7a50b71ef44c05013178 and a27eca01c3303a14e1bbf0cb05013125)
2. **Linked correct repository to Project**:
   ```bash
   PATCH /api/now/table/sn_devops_repository/2cb353f6c3c13a10b71ef44c0501313f
   {"project": "c6c9eb71c34d7a50b71ef44c05013194"}
   ```

### Final Configuration ✅

**Repository sys_id**: `2cb353f6c3c13a10b71ef44c0501313f`
- **Name**: Freundcloud/microservices-demo
- **URL**: https://github.com/Freundcloud/microservices-demo
- **Project**: Freundcloud/microservices-demo (c6c9eb71c34d7a50b71ef44c05013194) ✅
- **Application**: Online Boutique (e489efd1c3383e14e1bbf0cb050131d5) ✅
- **Native ID**: 1076023411 (GitHub repository ID)
- **Status**: Configured ✅
- **Imported Data**: Branches and commits present ✅

## Conclusion

**Issue Status**: **BLOCKED on ServiceNow playbook workflow**

The investigation has definitively proven that:
1. ✅ Repository properly configured and linked to both Project and Application
2. ✅ Repository has imported data (branches, commits)
3. ✅ SBOM summaries linked to Project (21 records)
4. ✅ Critical discovery: HelloWorld4 (GitLab) uses playbook workflow (`creation_source: "playbook"`) and HAS insights record
5. ❌ Online Boutique (GitHub) created manually (`creation_source: ""`) and NO insights record
6. ❌ DevOps Insights record creation is BLOCKED by ACLs - only playbooks with elevated permissions can create records

**Root Cause**: GitHub integration does NOT trigger the same playbook workflow that GitLab integration uses. GitLab automatically creates both Application and Insights records via playbook. GitHub only creates Projects and Repositories, leaving Application and Insights records to be created manually.

**Next Required Action**: ServiceNow administrator/support intervention to:
- Identify which playbook GitLab integration uses (Flow Designer UI access required)
- Configure GitHub integration to trigger same playbook workflow
- OR manually trigger playbook to create DevOps Insights record for Online Boutique
- OR provide privileged script to create insights record (bypassing ACLs)
- Verify correct modules and features are enabled for GitHub integration

**Alternative Approaches**:
1. **Manual UI Form Creation**: Try direct form URL with sys_id pre-populated (see SERVICENOW-QUICK-START.md)
2. **ServiceNow Support Ticket**: Request assistance creating insights record (see SERVICENOW-SUPPORT-TICKET-TEMPLATE.md)
3. **Contact HelloWorld4 Creator**: Ask alex.wells@calitii.com how GitLab integration was configured

---

## Related Documentation

- **[Current State Summary](SERVICENOW-CURRENT-STATE-SUMMARY.md)** - Complete current configuration and next steps
- **[Quick Start Guide](SERVICENOW-QUICK-START.md)** - 3-minute manual creation attempt
- **[Playbook Investigation](SERVICENOW-PLAYBOOK-INVESTIGATION-GUIDE.md)** - How to identify and trigger playbooks
- **[Support Ticket Template](SERVICENOW-SUPPORT-TICKET-TEMPLATE.md)** - Request ServiceNow support assistance

---

*Investigation completed: 2025-11-10*
*Repository configuration fixed: 2025-11-10*
*Documented by: Claude Code*
*Related Issue: [#78](https://github.com/Freundcloud/microservices-demo/issues/78)*
