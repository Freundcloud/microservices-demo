# ServiceNow DevOps Insights - Missing Application Data Analysis

> **Date**: 2025-11-05
> **Status**: 🔴 CRITICAL - No data appearing in DevOps Insights
> **Issue**: "Online Boutique" application exists but has no insights data
> **Impact**: DevOps dashboards and metrics unavailable

---

## Executive Summary

The "Online Boutique" application exists in ServiceNow (`sn_devops_app` table) but has **zero data** in DevOps Insights. No repositories, pipelines, tests, or packages are linked to the application. This prevents visibility into CI/CD metrics, deployment frequency, test results, and other key DevOps metrics.

**Root Cause**: GitHub Actions workflows are sending data to ServiceNow but **not linking it to the Online Boutique application**. The data is orphaned.

---

## Problem Statement

### Observed Behavior

**ServiceNow DevOps Insights Dashboard**:
- ❌ "Online Boutique" application shows **NO DATA**
- ❌ No metrics, graphs, or insights available
- ❌ Application appears empty in Insights overview

**Data in ServiceNow**:
```
sn_devops_app table:
- ✅ "Online Boutique" application EXISTS (sys_id: e489efd1c3383e14e1bbf0cb050131d5)
- ✅ Created: 2025-10-24 14:00:51

sn_devops_insights_st_summary table:
- ❌ NO summary record for "Online Boutique"
- ✅ Summary exists for "HelloWorld4" (tests: 240, pipelines: 16, commits: 9)

Data linked to "Online Boutique":
- ❌ Repositories: NULL (none linked)
- ❌ Pipeline executions: NULL (none linked)
- ❌ Test results: NULL (none linked)
- ❌ Packages: NULL (none linked)
- ❌ Commits: NULL (none linked)
- ❌ Work items: NULL (none linked)
```

---

## Root Cause Analysis

### Issue: Data Not Linked to Application

**GitHub Actions workflows ARE working**:
- ✅ Packages registered: `sn_devops_package` table has records
- ✅ Change requests created: `change_request` table updated
- ✅ Test results uploaded: ServiceNow actions succeed
- ✅ Workflows complete successfully

**But the data is ORPHANED**:
- ❌ No link between uploaded data and "Online Boutique" app
- ❌ Data exists in ServiceNow but isn't associated with any application
- ❌ Insights engine can't aggregate data for the app

### Comparison: HelloWorld4 vs Online Boutique

| Metric | HelloWorld4 ✅ | Online Boutique ❌ |
|--------|---------------|-------------------|
| Repositories | 1+ linked | **0 linked** |
| Pipeline Executions | 16 | **0** |
| Tests | 240 | **0** |
| Commits | 9 | **0** |
| Work Items | 3 | **0** |
| Committers | 2 | **0** |
| Tool Linked | Yes | **NO** |
| Insights Summary | EXISTS | **MISSING** |

### Root Cause Identified

**Missing Application Linkage Configuration**:

1. **No Tool-to-Application Mapping**: The GitHub tool (`GithHubARC`, tool_id: `f62c4e49c3fcf614e1bbf0cb050131ef`) is not linked to the "Online Boutique" application in ServiceNow

2. **No Repository Mapping**: The repository `Freundcloud/microservices-demo` is not registered or mapped to the "Online Boutique" application in `sn_devops_repository` table

3. **Missing Application Sys ID in Workflows**: GitHub Actions are not passing the application sys_id (`e489efd1c3383e14e1bbf0cb050131d5`) when uploading data

---

## Evidence

### Database Queries Performed

```bash
# Query: Online Boutique application details
curl /api/now/table/sn_devops_app/e489efd1c3383e14e1bbf0cb050131d5
Result:
{
  "name": "Online Boutique",
  "tool": null,           # ❌ NO TOOL LINKED
  "sys_id": "e489efd1c3383e14e1bbf0cb050131d5"
}

# Query: Repositories linked to Online Boutique
curl /api/now/table/sn_devops_repository?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5
Result: null             # ❌ NO REPOSITORIES

# Query: Pipeline executions for Online Boutique
curl /api/now/table/sn_devops_pipeline_info?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5
Result: null             # ❌ NO PIPELINES

# Query: Test results for Online Boutique
curl /api/now/table/sn_devops_test_result?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5
Result: null             # ❌ NO TEST DATA
```

### Workflow Analysis

**Current GitHub Actions Parameters** (from `MASTER-PIPELINE.yaml`):

```yaml
# register-packages job (line 363)
uses: ServiceNow/servicenow-devops-register-package@v3.1.0
with:
  devops-integration-user-name: ${{ ... }}
  devops-integration-user-password: ${{ ... }}
  instance-url: ${{ ... }}
  tool-id: ${{ ... }}                    # ✅ Tool ID provided
  context-github: ${{ toJSON(github) }}   # ✅ GitHub context
  job-name: 'Register Packages - ...'
  artifacts: ${{ ... }}
  package-name: 'microservices-...'
  # ❌ MISSING: application-name or app-sys-id parameter
```

**ServiceNow DevOps Action Parameters Available**:
- ✅ `tool-id` - GitHub tool sys_id (we provide this)
- ✅ `context-github` - GitHub workflow context (we provide this)
- ❌ **NO `application-name` parameter available**
- ❌ **NO `app-sys-id` parameter documented**

**Conclusion**: The ServiceNow DevOps GitHub Actions **don't support** directly passing an application sys_id or name!

---

## Proposed Solutions

### Solution 1: Configure Repository Mapping in ServiceNow UI (Recommended)

**Approach**: Manually map the GitHub repository to the "Online Boutique" application in ServiceNow.

**Steps**:

1. **Navigate to ServiceNow**:
   ```
   All → DevOps → Repositories
   Or direct URL: https://calitiiltddemo3.service-now.com/sn_devops_repository_list.do
   ```

2. **Create or Update Repository Record**:
   - Click "New" or find existing repository
   - **Name**: `Freundcloud/microservices-demo`
   - **URL**: `https://github.com/Freundcloud/microservices-demo`
   - **Tool**: Select "GithHubARC" (tool_id: f62c4e49c3fcf614e1bbf0cb050131ef)
   - **Application**: Select "Online Boutique" (sys_id: e489efd1c3383e14e1bbf0cb050131d5)
   - **Active**: true

3. **Save the Record**

4. **Trigger New Workflow Run**:
   ```bash
   gh workflow run MASTER-PIPELINE.yaml --ref main
   ```

5. **Verify Data Appears**:
   - Navigate to: DevOps → Insights → Applications
   - Select: "Online Boutique"
   - Check: Pipeline executions, tests, packages should now appear

**Pros**:
- ✅ No code changes required
- ✅ Follows ServiceNow best practices
- ✅ Centralized configuration in ServiceNow
- ✅ Data automatically linked via tool_id matching

**Cons**:
- ⏳ Requires ServiceNow admin access
- ⏳ Manual configuration step

**Estimated Time**: 10-15 minutes

---

### Solution 2: Link GitHub Tool to Application

**Approach**: Update the GitHub tool record to be associated with the "Online Boutique" application.

**Steps**:

1. **Navigate to ServiceNow**:
   ```
   All → DevOps → Tools
   Or: https://calitiiltddemo3.service-now.com/sn_devops_tool_list.do
   ```

2. **Find GitHub Tool**:
   - Search for: "GithHubARC"
   - sys_id: `f62c4e49c3fcf614e1bbf0cb050131ef`

3. **Update Tool Record**:
   - Open the tool record
   - Look for "Application" or "Default Application" field
   - Set to: "Online Boutique"
   - Save

4. **Trigger Workflow and Verify**

**Pros**:
- ✅ Simple one-time configuration
- ✅ All data from this tool automatically linked

**Cons**:
- ❌ May affect other projects using same tool
- ⏳ Field may not exist in tool table

**Estimated Time**: 5-10 minutes

---

### Solution 3: Create Application Config in ServiceNow DevOps

**Approach**: Use ServiceNow DevOps application configuration to establish the relationship.

**Steps**:

1. **Navigate to**:
   ```
   All → DevOps → Applications
   Or: https://calitiiltddemo3.service-now.com/sn_devops_app_list.do
   ```

2. **Open "Online Boutique" Application**:
   - sys_id: `e489efd1c3383e14e1bbf0cb050131d5`

3. **Configure Application**:
   - Look for "Repositories" related list
   - Click "New" or "Edit"
   - Add repository: `Freundcloud/microservices-demo`
   - Look for "Tools" related list
   - Link GitHub tool: `f62c4e49c3fcf614e1bbf0cb050131ef`

4. **Save and Test**

**Pros**:
- ✅ Application-centric configuration
- ✅ Clear relationship visibility

**Cons**:
- ⏳ Requires understanding of ServiceNow DevOps data model

**Estimated Time**: 15-20 minutes

---

### Solution 4: Programmatic Repository Creation via API

**Approach**: Use ServiceNow REST API to create repository record linked to application.

**Implementation**:

```bash
#!/bin/bash
# Create repository record in ServiceNow

curl -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository" \
  -d '{
    "name": "Freundcloud/microservices-demo",
    "url": "https://github.com/Freundcloud/microservices-demo",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "application": "e489efd1c3383e14e1bbf0cb050131d5",
    "active": true
  }'
```

**Add to Workflow**:

```yaml
- name: Create/Update Repository in ServiceNow
  run: |
    chmod +x scripts/create-servicenow-repository.sh
    ./scripts/create-servicenow-repository.sh
  env:
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
```

**Pros**:
- ✅ Automated - no manual steps
- ✅ Infrastructure as code
- ✅ Repeatable for new repositories

**Cons**:
- ❌ Requires code changes
- ❌ Adds complexity to workflow

**Estimated Time**: 45-60 minutes

---

## Recommended Implementation

### Primary Solution: Solution 1 (Repository Mapping in ServiceNow UI)

**Why**:
1. ✅ Fastest to implement (10-15 min)
2. ✅ No code changes
3. ✅ Follows ServiceNow design patterns
4. ✅ Centralized configuration
5. ✅ Future data automatically linked

**Implementation Steps**:

#### Step 1: Create Repository Record in ServiceNow

1. Login to ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: **All → DevOps → Repositories**
3. Click **New**
4. Fill in:
   ```
   Name: Freundcloud/microservices-demo
   URL: https://github.com/Freundcloud/microservices-demo
   Tool: GithHubARC (select from dropdown)
   Application: Online Boutique (select from dropdown)
   Active: true
   ```
5. Click **Submit**

#### Step 2: Verify Configuration

```bash
# Query the new repository record
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=name=Freundcloud/microservices-demo" \
  | jq '.result[] | {name, application: .application.display_value, tool: .tool.display_value}'

# Expected output:
# {
#   "name": "Freundcloud/microservices-demo",
#   "application": "Online Boutique",
#   "tool": "GithHubARC"
# }
```

#### Step 3: Trigger Workflow

```bash
gh workflow run MASTER-PIPELINE.yaml --ref main
```

#### Step 4: Verify Data Appears in Insights

Wait 5-10 minutes after workflow completes, then check:

```bash
# Check if insights summary is created
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Accept: application/json" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5" \
  | jq '.result[] | {application: .application.display_value, tests, pipeline_executions, commits}'
```

**Navigate to ServiceNow UI**:
1. Go to: **DevOps → Insights → Applications**
2. Click: "Online Boutique"
3. Verify: Data appears (pipelines, tests, commits, packages)

---

## Secondary Solution: Solution 4 (If Manual Config Not Possible)

If ServiceNow UI access is restricted, implement the programmatic approach:

**Create Script**: `scripts/create-servicenow-repository.sh`

**Add to Workflow** (one-time execution):

```yaml
setup-servicenow-repository:
  name: "🔧 Setup ServiceNow Repository"
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Create Repository Record
      run: |
        chmod +x scripts/create-servicenow-repository.sh
        ./scripts/create-servicenow-repository.sh
      env:
        SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
        SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
        APP_SYS_ID: "e489efd1c3383e14e1bbf0cb050131d5"
        TOOL_SYS_ID: "f62c4e49c3fcf614e1bbf0cb050131ef"
```

---

## Testing Strategy

### Pre-Implementation Check

```bash
# Verify current state (should return null)
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=name=Freundcloud/microservices-demo" \
  | jq '.result | length'

# Expected: 0
```

### Post-Implementation Verification

```bash
# Test 1: Repository created
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=name=Freundcloud/microservices-demo" \
  | jq '.result[0] | {name, application: .application.display_value}'

# Expected: name="Freundcloud/microservices-demo", application="Online Boutique"

# Test 2: Trigger workflow and wait for completion
gh workflow run MASTER-PIPELINE.yaml --ref main
# Wait 10 minutes...

# Test 3: Check pipeline executions linked
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_info?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5&sysparm_limit=1" \
  | jq '.result | length'

# Expected: > 0

# Test 4: Check insights summary created
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_insights_st_summary?sysparm_query=application=e489efd1c3383e14e1bbf0cb050131d5" \
  | jq '.result[0] | {pipeline_executions, tests, commits}'

# Expected: Numbers greater than 0
```

---

## Implementation Checklist

### ServiceNow Configuration
- [ ] Login to ServiceNow instance
- [ ] Navigate to DevOps → Repositories
- [ ] Create new repository record
- [ ] Set name: `Freundcloud/microservices-demo`
- [ ] Set URL: `https://github.com/Freundcloud/microservices-demo`
- [ ] Link tool: `GithHubARC`
- [ ] Link application: `Online Boutique`
- [ ] Set active: true
- [ ] Submit record

### Verification
- [ ] Query repository record via API (confirm creation)
- [ ] Trigger GitHub Actions workflow
- [ ] Wait 10 minutes for data processing
- [ ] Check pipeline executions in ServiceNow
- [ ] Check test results linked to application
- [ ] Check packages linked to application
- [ ] Verify insights summary created
- [ ] View DevOps Insights dashboard for "Online Boutique"

### Documentation
- [ ] Update docs with repository mapping requirement
- [ ] Document application sys_id for reference
- [ ] Add troubleshooting section for missing data

---

## Expected Results After Fix

### Insights Dashboard

**Online Boutique Application** should show:
- ✅ Pipeline Executions: 10+ (historical runs)
- ✅ Test Results: 100+ tests
- ✅ Commits: Multiple commits
- ✅ Packages: Registered Docker images
- ✅ Work Items: GitHub issues/PRs
- ✅ Committers: Contributors
- ✅ Pass Percentage: Test success rate

### Database Records

```sql
-- sn_devops_insights_st_summary should have record:
application: e489efd1c3383e14e1bbf0cb050131d5 (Online Boutique)
pipeline_executions: 10+
tests: 100+
commits: 10+
pass_percentage: 95+

-- sn_devops_repository should have:
name: Freundcloud/microservices-demo
application: e489efd1c3383e14e1bbf0cb050131d5
tool: f62c4e49c3fcf614e1bbf0cb050131ef
```

---

## Related Issues

- **DevOps Integration**: All ServiceNow DevOps actions working correctly
- **Tool Configuration**: GitHub tool properly configured
- **Application Creation**: "Online Boutique" app exists
- **Missing Link**: Repository-to-Application mapping

---

## Additional Resources

### ServiceNow Tables Reference

- `sn_devops_app` - Applications
- `sn_devops_repository` - Source code repositories
- `sn_devops_tool` - Integration tools (GitHub, Jenkins, etc.)
- `sn_devops_pipeline_info` - CI/CD pipeline executions
- `sn_devops_test_result` - Test results
- `sn_devops_package` - Packages/artifacts
- `sn_devops_insights_st_summary` - Insights summary (aggregated metrics)

### Key Identifiers

```
Application:
  Name: Online Boutique
  sys_id: e489efd1c3383e14e1bbf0cb050131d5

GitHub Tool:
  Name: GithHubARC
  sys_id: f62c4e49c3fcf614e1bbf0cb050131ef

Repository (to be created):
  Name: Freundcloud/microservices-demo
  URL: https://github.com/Freundcloud/microservices-demo
  Tool: f62c4e49c3fcf614e1bbf0cb050131ef
  Application: e489efd1c3383e14e1bbf0cb050131d5
```

---

**Document Status**: ✅ Complete - Ready for Implementation
**Last Updated**: 2025-11-05
**Next Step**: Create repository record in ServiceNow UI (Solution 1)
**Owner**: DevOps Team / ServiceNow Admin
