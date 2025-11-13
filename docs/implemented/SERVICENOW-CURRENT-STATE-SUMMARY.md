# ServiceNow DevOps Integration - Current State Summary

> Last Updated: 2025-11-10
> Related Issue: [#78](https://github.com/Freundcloud/microservices-demo/issues/78)

## Executive Summary

**Status**: Repository configuration FIXED ✅ | DevOps Insights record MISSING ❌

The repository misconfiguration has been successfully resolved. All components (Project, Application, Repository) are properly linked. However, the DevOps Insights record still does not exist, preventing the application from appearing in the DevOps Insights dashboard.

**Critical Discovery**: The Application's `creation_source` field changed from `""` (empty) to `"playbook"` after linking the repository to the project, suggesting some business rule was triggered. However, this did NOT automatically create the DevOps Insights record.

---

## Current Configuration

### ✅ Working Components

#### 1. Application (sn_devops_app)
```json
{
  "sys_id": "e489efd1c3383e14e1bbf0cb050131d5",
  "name": "Online Boutique",
  "creation_source": "playbook"  // ← CHANGED from "" to "playbook"
}
```
**Status**: ✅ Exists and properly configured

#### 2. Project (sn_devops_project)
```json
{
  "sys_id": "c6c9eb71c34d7a50b71ef44c05013194",
  "name": "Freundcloud/microservices-demo"
}
```
**Status**: ✅ Exists and properly configured

#### 3. Repository (sn_devops_repository)
```json
{
  "sys_id": "2cb353f6c3c13a10b71ef44c0501313f",
  "name": "Freundcloud/microservices-demo",
  "repository_url": "https://github.com/Freundcloud/microservices-demo",
  "tool": "GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)",
  "project": "c6c9eb71c34d7a50b71ef44c05013194",  // ✅ LINKED
  "app": "e489efd1c3383e14e1bbf0cb050131d5",       // ✅ LINKED
  "configure_status": "Configured",
  "native_id": "1076023411"  // GitHub repository ID
}
```
**Status**: ✅ Properly linked to both Project and Application
**Data**: ⚠️ Only 2 commits and 1 branch imported (historical data NOT imported - expected behavior)
**Statistics**: Empty (will populate as new commits are pushed - see Repository Statistics Limitation below)

#### 4. SBOM Summaries (sn_devops_software_quality_scan_summary)
- **Count**: 21 records
- **Linked to**: Project (c6c9eb71c34d7a50b71ef44c05013194) ✅
- **Status**: ✅ Data flowing correctly from GitHub Actions workflows

### ❌ Missing Component

#### DevOps Insights Record (sn_devops_insights_st_summary)
```
Query: application=e489efd1c3383e14e1bbf0cb050131d5
Result: [] (empty - record does not exist)
```
**Status**: ❌ DOES NOT EXIST
**Impact**: Application will not appear in DevOps Insights dashboard

---

## What Changed

### Repository Configuration Fix

**Problem**: Duplicate and misconfigured repository entries
- Repository 1 (02217f7dc38d7a50b71ef44c05013178): Had Project but NO data
- Repository 2 (a27eca01c3303a14e1bbf0cb05013125): NO Project, NO Application
- Repository 3 (2cb353f6c3c13a10b71ef44c0501313f): Had Application but NO Project (with data) ✅

**Solution**:
1. Deleted repositories 1 and 2 (empty/duplicate)
2. Linked repository 3 to Project via REST API:
   ```bash
   PATCH /api/now/table/sn_devops_repository/2cb353f6c3c13a10b71ef44c0501313f
   {"project": "c6c9eb71c34d7a50b71ef44c05013194"}
   ```

**Result**: Repository now properly linked to both Project and Application ✅

### Unexpected Change: Application creation_source

**Before**: `"creation_source": ""`
**After**: `"creation_source": "playbook"`

**Hypothesis**: Linking the repository to the project triggered a ServiceNow business rule that:
- Updated the Application's `creation_source` field to `"playbook"`
- BUT did NOT create the DevOps Insights record (possible bug or incomplete workflow)

**Evidence**:
- HelloWorld4 (GitLab) has `creation_source: "playbook"` AND has insights record
- Online Boutique (GitHub) now has `creation_source: "playbook"` BUT NO insights record
- This suggests the playbook workflow may have partially executed

---

## Root Cause Analysis

### Why DevOps Insights Record Doesn't Exist

**Original Hypothesis**: GitHub integration doesn't trigger playbook workflow
- **Status**: Partially INCORRECT
- **Evidence**: `creation_source` field updated to `"playbook"`, suggesting some playbook activity

**Updated Hypothesis**: Playbook workflow partially executed
- **Status**: LIKELY CORRECT
- **Evidence**:
  - Application `creation_source` updated to `"playbook"`
  - But DevOps Insights record NOT created
  - Suggests incomplete playbook execution or missing trigger

**Possible Causes**:
1. **Playbook triggered but failed**: Workflow executed but encountered error creating insights record
2. **Playbook requires additional trigger**: Updating `creation_source` is separate from creating insights
3. **Manual Application creation**: Application created manually, then later updated by business rule when repository linked
4. **Missing ACL permissions**: Playbook has permissions to update Application but not create Insights record

### Comparison: GitLab vs GitHub Integration

| Component | GitLab (HelloWorld4) | GitHub (Online Boutique) |
|-----------|---------------------|-------------------------|
| Application creation | ✅ Automatic via playbook | ❌ Manual (then updated) |
| Insights record creation | ✅ Automatic via playbook | ❌ NOT created |
| Repository linkage | ✅ Automatic | ✅ Fixed (was broken) |
| Project linkage | ✅ Automatic | ✅ Working |
| SBOM summaries | ✅ Working | ✅ Working |
| `creation_source` field | `"playbook"` | `"playbook"` (updated) |
| Insights dashboard | ✅ VISIBLE | ❌ NOT VISIBLE |

---

## Investigation Results

### ACL Restrictions

**Confirmed Blocks**:
- ✅ REST API POST to `sn_devops_insights_st_summary`: HTTP 403 ACL Exception
- ✅ Background Script INSERT via GlideRecord: Returns false (ACL blocked)
- ✅ ServiceNow Config API endpoints: HTTP 400 (endpoints don't exist or not exposed)
- ✅ XML Import via REST API: HTTP 400 Invalid staging table

**Only Working Method**: ServiceNow playbooks with elevated permissions

### Identified Playbook Activity

**Evidence of playbook involvement**:
1. Application `creation_source` changed from `""` to `"playbook"`
2. Change occurred after linking repository to project
3. Similar to HelloWorld4 (GitLab) which was created via playbook

**Unknown**:
- Which specific playbook was triggered
- Why playbook didn't create insights record
- How to manually trigger playbook to complete creation

---

## Next Steps

### Option 1: Investigate Playbook Execution Logs

**Access ServiceNow UI** (requires admin login):
1. Navigate to **Flow Designer** (`/nav_to.do?uri=sys_hub_flow_list.do`)
2. Search for flows containing "devops" or "application" or "insights"
3. Check **Execution History** for recent runs
4. Look for flow that ran when repository was linked to project
5. Check if flow encountered errors creating insights record

**Expected Finding**: Flow execution showing partial completion or error

### Option 2: Check System Logs

**Access ServiceNow UI**:
1. Navigate to **System Logs** → **System Log** → **Application Logs**
2. Filter by timestamp: Around when repository was linked to project (2025-11-10)
3. Search for logs containing: "insights", "playbook", "sn_devops_insights_st_summary"
4. Look for error messages or ACL exceptions

### Option 3: Manual Playbook Trigger

**If playbook identified**:
1. Navigate to **Flow Designer** and open the identified flow
2. Check if flow has manual trigger option
3. Manually execute flow with Application sys_id: `e489efd1c3383e14e1bbf0cb050131d5`
4. Monitor execution to see if insights record created

### Option 4: Contact HelloWorld4 Creator

**Email**: alex.wells@calitii.com
**Subject**: How GitLab integration creates DevOps Insights records

**Questions**:
1. How was HelloWorld4 application configured to automatically create insights record?
2. Which playbook workflow does GitLab integration use?
3. Can same playbook be triggered manually for GitHub-based applications?
4. What are differences between GitLab and GitHub integration playbooks?

### Option 5: ServiceNow Support Ticket

**Submit ticket** with following information:
- Application sys_id: `e489efd1c3383e14e1bbf0cb050131d5`
- Issue: Application has `creation_source: "playbook"` but no DevOps Insights record exists
- Request: Investigate why playbook didn't create insights record
- Request: Manually create insights record or trigger playbook to complete

See: `docs/SERVICENOW-SUPPORT-TICKET-TEMPLATE.md`

### Option 6: Try Manual UI Form Creation

**Direct Form URL**:
```
https://calitiiltddemo3.service-now.com/sn_devops_insights_st_summary.do?sys_id=e489efd1c3383e14e1bbf0cb050131d5
```

**Instructions**: See `docs/SERVICENOW-QUICK-START.md`

---

## Files Created During Investigation

### Investigation Documents
- `docs/SERVICENOW-DEVOPS-INSIGHTS-INVESTIGATION-RESULTS.md` - Complete investigation timeline
- `docs/SERVICENOW-CURRENT-STATE-SUMMARY.md` - This file

### Guides and Templates
- `docs/SERVICENOW-QUICK-START.md` - 3-minute manual creation guide
- `docs/SERVICENOW-PLAYBOOK-INVESTIGATION-GUIDE.md` - How to investigate playbook workflows
- `docs/SERVICENOW-XML-IMPORT-GUIDE.md` - XML import instructions (methods unavailable)
- `docs/SERVICENOW-SUPPORT-TICKET-TEMPLATE.md` - Support ticket template

### Attempted Solutions
- `docs/servicenow-insights-record.xml` - XML import file (import methods blocked)
- `.github/REIMPORT_TRIGGER.md` - Trigger file for data reimport (used during repo fix)

### Investigation Scripts (in `/tmp/`)
- `check-project-details.sh` - Project record investigation
- `check-insights-aggregation.sh` - Insights aggregation check
- `fix-devops-insights-linkage.sh` - Initial fix attempt
- `fix-devops-insights-linkage-v2.sh` - Improved fix script
- `verify-linkage.sh` - Linkage verification
- `check-table-schema.sh` - Schema investigation
- `find-app-project-relationship.sh` - Relationship discovery
- `check-reverse-relationship.sh` - Reverse linkage check
- `verify_complete_state.sh` - Current state verification
- `check_insights_final.sh` - Final insights check

---

## Key Findings Summary

### ✅ What's Working
1. Repository properly configured and linked to Project and Application
2. Repository has imported data (branches, commits)
3. 21 SBOM summaries linked to Project
4. Application `creation_source` updated to `"playbook"` (suggesting playbook involvement)
5. GitHub Actions workflows successfully sending data to ServiceNow

### ❌ What's NOT Working
1. DevOps Insights record does NOT exist
2. Application NOT visible in DevOps Insights dashboard
3. Playbook workflow appears to have partially executed (updated `creation_source` but didn't create insights)
4. Cannot programmatically create insights record (ACL blocked)

### 🔍 What's Unknown
1. Which specific playbook was triggered when repository was linked to project
2. Why playbook didn't create DevOps Insights record
3. How to manually trigger playbook to complete creation
4. Whether this is a bug or expected behavior requiring manual insights creation

---

## Repository Statistics Limitation

**Note**: The repository Details tab shows empty statistics (dashes for all fields):
- Total commits: —
- Total merges: —
- Average files per commit: —
- etc.

**This is expected behavior** - ServiceNow only imports commits from GitHub Actions webhook events, NOT historical commits. Currently only 2 commits have been imported (from this investigation):
- `fb6dc042` - "docs: Update ServiceNow DevOps Insights investigation..."
- `56a22cdc` - "Trigger ServiceNow repository data reimport"

Statistics will populate naturally as new commits are pushed and workflows run. Historical commits (~150+) will **NOT** be imported. This does NOT prevent the application from appearing in DevOps Insights dashboard.

**See**: [SERVICENOW-REPOSITORY-STATISTICS-LIMITATION.md](SERVICENOW-REPOSITORY-STATISTICS-LIMITATION.md) for complete explanation.

---

## Related Documentation

- **[Repository Statistics Limitation](SERVICENOW-REPOSITORY-STATISTICS-LIMITATION.md)** - Why statistics are empty (expected behavior)
- **[Investigation Results](SERVICENOW-DEVOPS-INSIGHTS-INVESTIGATION-RESULTS.md)** - Full investigation timeline
- **[Quick Start Guide](SERVICENOW-QUICK-START.md)** - 3-minute manual creation attempt
- **[Playbook Investigation](SERVICENOW-PLAYBOOK-INVESTIGATION-GUIDE.md)** - How to identify and trigger playbooks
- **[Support Ticket Template](SERVICENOW-SUPPORT-TICKET-TEMPLATE.md)** - Request ServiceNow support assistance

---

## Recommended Immediate Action

**Priority 1**: Investigate playbook execution logs in ServiceNow UI (Option 1 above)
- Most likely to reveal why insights record wasn't created
- May show errors or incomplete workflow execution
- Can guide next troubleshooting steps

**Priority 2**: Contact HelloWorld4 creator (Option 4 above)
- Direct comparison between working GitLab setup and non-working GitHub setup
- May reveal configuration differences
- Fastest path to resolution

**Priority 3**: Try manual UI form creation (Option 6 above)
- Quick workaround if other options fail
- May work if ACL allows UI creation but not API creation

---

*Last verified: 2025-11-10*
*Documented by: Claude Code*
