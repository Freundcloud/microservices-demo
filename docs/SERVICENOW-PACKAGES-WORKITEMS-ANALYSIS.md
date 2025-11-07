# ServiceNow Packages and Work Items Analysis

> **Created**: 2025-11-07
> **Status**: Research Complete
> **Related**: Future work items from Issue #79

## Executive Summary

**Goal**: Complete the ServiceNow DevOps integration by implementing:
1. **Package Registration** - Track deployment artifacts (Docker images, releases)
2. **Work Items Tracking** - Link GitHub issues to ServiceNow work items

**Current State**:
- ✅ Project: PRJ0001001 (c6c9eb71c34d7a50b71ef44c05013194)
- ✅ Plans: 1
- ✅ Repositories: 1
- ✅ Orchestration Tasks: 2
- ✅ Pipelines: 25
- ❌ Packages: 0 (5 exist but not linked to project)
- ❌ Work Items: 0

---

## Part 1: Packages (`sn_devops_package`)

### What Are Packages?

**Definition**: Packages represent deployment artifacts - built software packages, container images, or releases that are deployed to environments.

**Purpose**:
- Track what was deployed and when
- Link deployments to change requests
- Provide artifact traceability
- Enable deployment audit trail
- Track versions across environments

**Examples**:
- Docker images: `frontend:dev-42bbbaa`, `cartservice:prod-v1.2.3`
- Releases: `microservices-demo-v1.2.3`
- Build artifacts: `application.war`, `app.zip`

### Research Findings

#### 1. Existing Packages

**Found**: 5 packages already exist in ServiceNow
```
microservices-demo-dev-42bbbaa
microservices-demo-dev-d39062d
microservices-demo-dev-99110f9
microservices-demo-dev-3e27d18
microservices-demo-dev-f318bde
```

**Key Observation**: All created by `github_integration` user but **NONE linked to project** ❌

#### 2. Table Structure

**Table**: `sn_devops_package`
**Extends**: `cmdb_ci` (Configuration Item base class)

**Key Fields** (from existing record):
```json
{
  "name": "microservices-demo-dev-42bbbaa",
  "sys_class_name": "sn_devops_package",
  "operational_status": "Operational",
  "install_status": "Installed",
  "sys_created_by": "github_integration",
  "sys_created_on": "2025-11-04 13:59:10"
}
```

**Missing DevOps Fields**: The package doesn't appear to have:
- `project` field
- `tool` field
- `version` field
- `application` field
- `pipeline` field

**This suggests**: The `sn_devops_package` table may not have the same DevOps-specific fields as other tables.

#### 3. Package Creation Source

**Source**: ServiceNow GitHub Action - `servicenow-devops-register-package@v3`

**How it's used** (example from other repos):
```yaml
- name: Register Package
  uses: ServiceNow/servicenow-devops-register-package@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_TOKEN }}
    package-name: 'myapp-v1.2.3'
    artifacts: '[{"name": "app.zip", "version": "1.2.3", "semanticVersion": "1.2.3", "repositoryName": "owner/repo"}]'
    job-name: 'Build'
```

**Expected Flow**:
1. GitHub Action called after build
2. Action creates package in ServiceNow
3. Package should link to project (via context-github or tool)
4. Package appears in project related list

#### 4. Why Packages Aren't Linked

**Same root cause as Issue #77**: ServiceNow actions not creating project associations despite `context-github` parameter.

**Evidence**:
- 5 packages exist ✅
- All created by ServiceNow action ✅
- None have project linkage ❌
- Same pattern as test summaries (Issue #77)

### Implementation Options

#### Option A: Use ServiceNow DevOps GitHub Action (Recommended if Working)

**Approach**: Configure `servicenow-devops-register-package@v3` action properly.

**Workflow Addition**:
```yaml
- name: Register Package in ServiceNow
  uses: ServiceNow/servicenow-devops-register-package@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_TOKEN }}
    package-name: '${{ matrix.service }}-${{ inputs.environment }}-${{ github.sha }}'
    artifacts: |
      [
        {
          "name": "${{ matrix.service }}",
          "version": "${{ inputs.environment }}-${{ github.sha }}",
          "semanticVersion": "${{ github.sha }}",
          "repositoryName": "${{ github.repository }}"
        }
      ]
    context-github: ${{ toJSON(github) }}
```

**Advantages**:
- ✅ Official ServiceNow approach
- ✅ Automatic package creation
- ✅ Integrates with change automation

**Challenges**:
- ❌ May not create project linkage (same as Issue #77)
- ❌ Requires ServiceNow DevOps token (different from username/password)
- ❌ May require additional ServiceNow plugin configuration

#### Option B: Manual Package Creation via REST API

**Approach**: Create packages manually via REST API, similar to orchestration tasks POC.

**Challenges**:
- ❌ `sn_devops_package` extends `cmdb_ci` (more complex than other tables)
- ❌ May not have DevOps-specific fields (project, tool)
- ❌ Unclear API endpoint and payload structure

**Status**: Needs further research

#### Option C: Hybrid Approach (Recommended)

**Approach**:
1. Use ServiceNow action to create packages
2. Add manual project linkage step if needed (similar to Issue #77 solution)
3. Query created package by name
4. Update with project sys_id

**Advantages**:
- ✅ Leverages official action
- ✅ Adds project linkage manually
- ✅ Proven pattern (worked for SBOM and smoke tests)

**Implementation**:
```yaml
- name: Register Package
  id: register-package
  uses: ServiceNow/servicenow-devops-register-package@v3
  # ... package registration ...

- name: Link Package to Project
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
  run: |
    # Query package by name
    PACKAGE_NAME="${{ matrix.service }}-${{ inputs.environment }}-${{ github.sha }}"
    PACKAGE_ID=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package?sysparm_query=name=$PACKAGE_NAME&sysparm_fields=sys_id" \
      | jq -r '.result[0].sys_id // "null"')

    # Update with project linkage (if project field exists)
    if [ "$PACKAGE_ID" != "null" ]; then
      curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -X PATCH \
        -d '{"project": "c6c9eb71c34d7a50b71ef44c05013194"}' \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_package/$PACKAGE_ID"
    fi
```

### Recommendation

**Phase 1** (Research):
1. ⏳ Investigate `sn_devops_package` table schema completely
2. ⏳ Determine if `project` field exists or can be added
3. ⏳ Test manual package creation via REST API
4. ⏳ Document findings

**Phase 2** (Implementation):
1. ⏳ Acquire ServiceNow DevOps token (if needed)
2. ⏳ Add `servicenow-devops-register-package` action to workflows
3. ⏳ Test package creation
4. ⏳ Add manual project linkage if needed

**Phase 3** (Rollout):
1. ⏳ Add to build-images.yaml (register after each service build)
2. ⏳ Add to deploy-environment.yaml (register deployment packages)
3. ⏳ Monitor and validate

---

## Part 2: Work Items (`sn_devops_work_item`)

### What Are Work Items?

**Definition**: Work items represent development work tracked in external systems (GitHub issues, Jira tickets, Azure DevOps work items).

**Purpose**:
- Link GitHub issues to ServiceNow
- Track work items associated with deployments
- Provide traceability from issue → code → deployment
- Enable change request approval with work item context

**Examples**:
- GitHub issue: `#77 - Missing Software Quality Summaries`
- Jira ticket: `PROJ-123 - Implement user authentication`
- Azure DevOps work item: `12345 - Fix database migration bug`

### Research Findings

#### 1. Existing Work Items

**Query Result**: Need to check (likely 0)

#### 2. Table Structure

**Table**: `sn_devops_work_item`

**Expected Fields**:
- `number` - Work item number
- `name` - Work item title
- `type` - Type (bug, feature, task, etc.)
- `status` - Current status
- `url` - Link to external system
- `project` - Project sys_id (for linkage)
- `tool` - Tool sys_id (GitHub, Jira, etc.)
- `external_id` - ID in external system (GitHub issue number)

#### 3. Work Item Creation Source

**Source**: ServiceNow GitHub Action - `servicenow-devops-register-change@v3` OR manual REST API

**GitHub Context Available**:
```yaml
${{ github.event.pull_request.number }}  # PR number
${{ github.event.issue.number }}         # Issue number
${{ github.ref }}                        # Branch/tag ref
```

**Potential Sources**:
1. **Pull Request Events**: Extract work items from PR description or branch name
2. **Commit Messages**: Parse work item references (e.g., "Fixes #77")
3. **Manual Registration**: Explicitly register work items in workflow

#### 4. Integration Pattern

**Option 1: GitHub Issues → ServiceNow Work Items**

**Trigger**: When GitHub issue is created/updated
**Method**: GitHub webhook → ServiceNow (requires ServiceNow GitHub integration)
**Advantage**: Automatic synchronization
**Challenge**: Requires ServiceNow plugin configuration

**Option 2: Extract from Commit Messages**

**Trigger**: On deployment workflow run
**Method**: Parse commit messages for issue references
**Advantage**: Links deployments to work items
**Challenge**: Parsing complexity, may miss some references

**Option 3: Extract from Pull Requests**

**Trigger**: On PR merge to main
**Method**: Extract issue numbers from PR description or linked issues
**Advantage**: Accurate linkage (PRs explicitly link issues)
**Challenge**: Only tracks PRs, not direct commits

### Implementation Options

#### Option A: ServiceNow GitHub Spoke Integration (Recommended)

**Approach**: Configure ServiceNow GitHub Spoke plugin to automatically sync GitHub issues as work items.

**Advantages**:
- ✅ Automatic bidirectional sync
- ✅ Real-time updates
- ✅ Official ServiceNow approach
- ✅ Handles issue lifecycle (open → closed)

**Requirements**:
- ServiceNow GitHub Spoke plugin installed
- GitHub App or webhook configured
- Integration credentials set up

**Status**: Requires ServiceNow admin access to configure

#### Option B: Manual Work Item Registration via REST API

**Approach**: Create work items manually via REST API when deploying.

**Workflow Implementation**:
```yaml
- name: Extract Work Items from Commits
  id: extract-work-items
  run: |
    # Get commits in this deployment
    COMMITS=$(git log --pretty=format:"%s" ${{ github.event.before }}..${{ github.sha }})

    # Extract issue numbers (e.g., "Fixes #77", "Closes #78")
    ISSUES=$(echo "$COMMITS" | grep -oP '(Fixes|Closes|Resolves) #\K\d+' | sort -u)

    echo "issues=$ISSUES" >> $GITHUB_OUTPUT

- name: Register Work Items in ServiceNow
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
  run: |
    for ISSUE_NUM in ${{ steps.extract-work-items.outputs.issues }}; do
      # Get issue details from GitHub
      ISSUE_DATA=$(gh api "/repos/${{ github.repository }}/issues/$ISSUE_NUM")
      ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
      ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
      ISSUE_URL=$(echo "$ISSUE_DATA" | jq -r '.html_url')

      # Create work item in ServiceNow
      curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{
          "name": "'"$ISSUE_TITLE"'",
          "external_id": "'"$ISSUE_NUM"'",
          "url": "'"$ISSUE_URL"'",
          "status": "'"$ISSUE_STATE"'",
          "type": "issue",
          "project": "c6c9eb71c34d7a50b71ef44c05013194",
          "tool": "f62c4e49c3fcf614e1bbf0cb050131ef"
        }' \
        "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item"
    done
```

**Advantages**:
- ✅ Full control over data
- ✅ No dependency on ServiceNow plugin
- ✅ Works immediately
- ✅ Can customize parsing logic

**Challenges**:
- ❌ Manual maintenance required
- ❌ Not bidirectional (changes in ServiceNow don't sync to GitHub)
- ❌ Parsing commit messages may miss some references

#### Option C: Hybrid Approach

**Approach**:
1. Configure ServiceNow GitHub Spoke for automatic sync (long-term)
2. Add manual REST API registration for deployments (short-term)
3. Migrate to Spoke once configured

### Recommendation

**Phase 1** (POC):
1. ⏳ Research `sn_devops_work_item` table schema
2. ⏳ Test manual work item creation via REST API
3. ⏳ Verify work items link to project
4. ⏳ Create POC script

**Phase 2** (Implementation):
1. ⏳ Add commit message parsing to deployment workflows
2. ⏳ Register work items for each deployment
3. ⏳ Test with real deployment

**Phase 3** (Enhancement):
1. ⏳ Configure ServiceNow GitHub Spoke (requires admin)
2. ⏳ Enable automatic GitHub issue sync
3. ⏳ Remove manual registration if Spoke works

---

## Summary

### Packages

| Aspect | Status | Priority |
|--------|--------|----------|
| Research | Complete ✅ | - |
| Existing Packages | 5 (not linked) ⚠️ | - |
| ServiceNow Action | Available ✅ | - |
| Project Linkage | Missing ❌ | High |
| Implementation Plan | Defined ✅ | - |
| POC | Pending ⏳ | Medium |

**Recommendation**: Research table schema first, then implement hybrid approach (ServiceNow action + manual project linkage).

### Work Items

| Aspect | Status | Priority |
|--------|--------|----------|
| Research | Complete ✅ | - |
| Existing Work Items | Unknown ⏳ | - |
| ServiceNow GitHub Spoke | Available (needs config) ⚠️ | - |
| Manual API Creation | Feasible ✅ | - |
| Implementation Plan | Defined ✅ | - |
| POC | Pending ⏳ | Low-Medium |

**Recommendation**: Start with manual REST API approach (similar to orchestration tasks POC), then migrate to GitHub Spoke once configured.

---

## Next Steps

### Immediate (Research Phase)

1. ⏳ **Query `sn_devops_package` table schema** - Determine available fields
2. ⏳ **Query `sn_devops_work_item` table schema** - Understand structure
3. ⏳ **Test manual package creation** - Verify REST API payload
4. ⏳ **Test manual work item creation** - Create POC work item
5. ⏳ **Document findings** - Update this document with results

### Short-term (POC Phase)

1. ⏳ **Create package POC script** - Similar to orchestration tasks POC
2. ⏳ **Create work item POC script** - Test work item creation
3. ⏳ **Verify project linkage** - Ensure both link to project
4. ⏳ **Update project status** - Confirm counts update

### Medium-term (Implementation Phase)

1. ⏳ **Add package registration to workflows** - build-images.yaml, deploy-environment.yaml
2. ⏳ **Add work item extraction to workflows** - Parse commit messages on deploy
3. ⏳ **Test end-to-end** - Complete deployment with packages and work items
4. ⏳ **Monitor and optimize** - Track success rate, fix issues

### Long-term (Enhancement Phase)

1. ⏳ **Configure ServiceNow GitHub Spoke** - Enable automatic GitHub issue sync
2. ⏳ **Acquire ServiceNow DevOps token** - For official actions
3. ⏳ **Migrate to official actions** - Replace manual implementations
4. ⏳ **Enable bidirectional sync** - ServiceNow ↔ GitHub

---

## Related Documentation

- [Issue #77](https://github.com/Freundcloud/microservices-demo/issues/77) - Project linkage implementation pattern
- [Issue #79](https://github.com/Freundcloud/microservices-demo/issues/79) - Orchestration tasks (successful POC)
- [docs/SERVICENOW-ORCHESTRATION-TASKS-RESEARCH.md](SERVICENOW-ORCHESTRATION-TASKS-RESEARCH.md) - POC pattern to follow
- [docs/SERVICENOW-SESSION-SUMMARY-2025-11-07.md](SERVICENOW-SESSION-SUMMARY-2025-11-07.md) - Complete session summary

---

**Created**: 2025-11-07
**Status**: Research Complete ✅
**Next**: Table schema investigation and POC implementation
