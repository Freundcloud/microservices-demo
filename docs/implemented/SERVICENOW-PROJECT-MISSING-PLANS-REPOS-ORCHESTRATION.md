# ServiceNow Project: Missing Plans, Repositories, and Orchestration Tasks

> **Investigation Date**: 2025-11-07
> **Project**: Freundcloud/microservices-demo (c6c9eb71c34d7a50b71ef44c05013194)
> **Issue**: Plans, Repositories, and Orchestration tasks related lists are empty
> **Status**: Investigation Complete - Solution Identified

## Executive Summary

**Problem**: The ServiceNow project record for `Freundcloud/microservices-demo` is missing:
- **Plans**: Shows `-` (0 plans linked)
- **Repositories**: Shows `-` (0 repositories linked)
- **Orchestration tasks**: Empty related list

**Root Cause**: These are **separate tables** in ServiceNow that need to be populated with records linked to the project via `project` field. They are NOT automatically created when the project is created.

**Current Status**:
- ✅ Project exists: PRJ0001001 (c6c9eb71c34d7a50b71ef44c05013194)
- ✅ Pipelines: 25 pipelines linked to project
- ❌ Plans: 0 (need to create)
- ❌ Repositories: 0 (need to create)
- ❌ Orchestration tasks: 0 (need to create)

## Investigation Findings

### 1. Current Project Status

**Project Record** (c6c9eb71c34d7a50b71ef44c05013194):
```json
{
  "number": "PRJ0001001",
  "name": "Freundcloud/microservices-demo",
  "tool": "GithHubARC (f62c4e49c3fcf614e1bbf0cb050131ef)",
  "plan_count": "-",
  "repository_count": "-",
  "pipeline_count": "25"
}
```

**Related Lists Status**:
| Related List | Current Count | Expected |
|---|---|---|
| Software Quality Scan Summaries | 2 ✅ | Populated (SBOM scans) |
| Test Summaries | 1 ✅ | Populated |
| Performance Test Summaries | 1 ✅ | Populated |
| Pipelines | 25 ✅ | Populated |
| **Plans** | **0 ❌** | **Should have at least 1** |
| **Repositories** | **0 ❌** | **Should have 1 (GitHub repo)** |
| **Orchestration Tasks** | **0 ❌** | **Should populate with workflow jobs** |
| Packages | 0 ⏳ | Pending ServiceNow action |
| Work Items | 0 ⏳ | Pending implementation |

### 2. ServiceNow DevOps Plans (sn_devops_plan)

**What is a DevOps Plan?**
- Represents a deployment plan or release plan
- Links to a project
- Contains stages, gates, approvals
- Can be auto-created by ServiceNow DevOps GitHub integration

**Current State**:
- Table exists with 5 total plans in system
- None are for `Freundcloud/microservices-demo`
- Existing plans are for other repos:
  - `olafkfreund/ai_team_workshop`
  - `olafkfreund/3Dstack-hyrpland`
  - `olafkfreund/SOW-generator`
  - `sncsenpai/sn-notebook`
  - GitLab demo project
- **All existing plans have empty `project` field** ❌

**What's Needed**:
Create a DevOps Plan record for microservices-demo repository linked to project c6c9eb71c34d7a50b71ef44c05013194.

### 3. ServiceNow DevOps Repositories (sn_devops_repository)

**What is a DevOps Repository?**
- Represents a source code repository (GitHub, GitLab, Bitbucket)
- Links to a project
- Stores repository metadata (URL, default branch, etc.)
- Used by ServiceNow to track repository activity

**Current State**:
- Table exists with 5 total repositories in system
- None are for `Freundcloud/microservices-demo`
- Existing repositories are for:
  - `sncsenpai/open-source-faves`
  - `olafkfreund/aerogel`
  - GitLab demo projects
- **All existing repositories have empty `project` field** ❌
- **None have URLs populated** ❌

**What's Needed**:
Create a DevOps Repository record for:
- Name: `Freundcloud/microservices-demo`
- URL: `https://github.com/Freundcloud/microservices-demo`
- Project: c6c9eb71c34d7a50b71ef44c05013194
- Tool: f62c4e49c3fcf614e1bbf0cb050131ef

### 4. ServiceNow Orchestration Tasks (sn_devops_orchestration_task)

**What is an Orchestration Task?**
- Represents a CI/CD job execution (GitHub Actions job, Jenkins job, etc.)
- Links to a project
- Tracks job status, duration, outcome
- Part of pipeline execution tracking

**Current State**:
- Table exists with 1 total orchestration task in system
- Existing task: `sncsenpai/scaling-spoon/build_and_sn#build`
- None for `Freundcloud/microservices-demo`

**What's Needed**:
Orchestration tasks should be created automatically when:
- GitHub Actions workflows run
- ServiceNow DevOps GitHub integration is configured
- Pipeline executions are registered

## Why These Are Missing

### Root Cause Analysis

**1. Manual Project Creation**:
- We created the project manually via REST API in Issue #77 Phase 2
- Manual creation only creates the `sn_devops_project` record
- Does NOT auto-create related plans, repositories, or orchestration tasks

**2. ServiceNow DevOps Integration Not Fully Configured**:
- ServiceNow DevOps GitHub App/integration typically handles:
  - Repository discovery and registration
  - Plan creation (from deployment workflows)
  - Orchestration task tracking (from CI/CD jobs)
- Our integration is partial:
  - ✅ Tool exists (GithHubARC)
  - ✅ Pipelines are linked (25 pipelines)
  - ❌ Repository not registered
  - ❌ Plans not created
  - ❌ Orchestration tasks not tracked

**3. Missing Webhook/API Calls**:
The project webhook URL shows endpoints for:
```
https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/{endpoint}?toolId=...&projectId=...
```

Where `{endpoint}` can be:
- `code` - For repository registration
- `plan` - For plan creation
- `artifact` - For package/artifact registration
- `orchestration` - For job/task tracking
- `test` - For test results
- `softwarequality` - For quality scans (already working ✅)

**We're only using**:
- ✅ `test` - Test summaries (via ServiceNow actions)
- ✅ `softwarequality` - SBOM scans (via manual REST API)

**Not using**:
- ❌ `code` - Repository registration
- ❌ `plan` - Plan creation
- ❌ `orchestration` - Orchestration task tracking
- ❌ `artifact` - Package registration

## Solution Options

### Option A: Use ServiceNow DevOps Change API (Recommended)

**Approach**:
Use the official ServiceNow DevOps Change API webhook endpoints to register:
1. Repository via `/devops/tool/code`
2. Plan via `/devops/tool/plan`
3. Orchestration tasks via `/devops/tool/orchestration`

**Advantages**:
- ✅ Official ServiceNow approach
- ✅ Proper linkage to project
- ✅ Automatic count field updates
- ✅ Integrates with DevOps Insights

**Implementation**:
Add API calls to our workflows to register these entities.

### Option B: Use ServiceNow DevOps GitHub Action (Alternative)

**Approach**:
Configure and use the ServiceNow DevOps GitHub Actions:
- `ServiceNow/servicenow-devops-register-pipeline@v3`
- `ServiceNow/servicenow-devops-change@v3`
- `ServiceNow/servicenow-devops-register-artifact@v3`

**Advantages**:
- ✅ Handles everything automatically
- ✅ Official ServiceNow integration

**Disadvantages**:
- ❌ May require GitHub App installation (permissions issue)
- ❌ Already having issues with actions not creating projects (Issue #77)
- ❌ Less control over data

### Option C: Manual REST API Creation (Quick Fix)

**Approach**:
Create repository and plan records directly via REST API.

**Advantages**:
- ✅ Quick to implement
- ✅ Full control
- ✅ No dependency on ServiceNow actions

**Disadvantages**:
- ❌ Manual process
- ❌ Doesn't scale
- ❌ May not integrate as well with DevOps Insights

## Recommended Implementation Plan

### Phase 1: Register Repository (Immediate)

**Create Repository Record**:
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "Freundcloud/microservices-demo",
    "url": "https://github.com/Freundcloud/microservices-demo",
    "project": "c6c9eb71c34d7a50b71ef44c05013194",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "description": "Microservices demo application on AWS EKS",
    "default_branch": "main"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository"
```

**Expected Result**:
- Repository record created
- `repository_count` changes from `-` to `1`
- Repository appears in project related list

### Phase 2: Create DevOps Plan (Immediate)

**Create Plan Record**:
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "Freundcloud/microservices-demo - Deployment Plan",
    "project": "c6c9eb71c34d7a50b71ef44c05013194",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "description": "Automated deployment plan for microservices-demo",
    "state": "active"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_plan"
```

**Expected Result**:
- Plan record created
- `plan_count` changes from `-` to `1`
- Plan appears in project related list

### Phase 3: Investigate Orchestration Task Auto-Creation (Research)

**Questions to Answer**:
1. Does ServiceNow DevOps GitHub integration auto-create orchestration tasks?
2. Do we need to configure webhooks or GitHub App?
3. Can we manually create orchestration tasks via API?
4. Should orchestration tasks be created per-job or per-workflow?

**Research Needed**:
- Check ServiceNow DevOps plugin configuration
- Review GitHub Actions integration settings
- Test orchestration task creation via API
- Check if pipelines should auto-create orchestration tasks

### Phase 4: Automate Repository/Plan Registration (Future)

**Add to Workflows**:
1. Check if repository exists, create if not (idempotent)
2. Check if plan exists, create if not (idempotent)
3. Link to project sys_id
4. Run on first deployment or workflow dispatch

**Benefits**:
- Ensures these records always exist
- Self-healing if manually deleted
- Proper project linkage maintained

## Verification Steps

### Verify Repository Created

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_repository?sysparm_query=project=c6c9eb71c34d7a50b71ef44c05013194&sysparm_fields=name,number,url" \
  | jq .
```

**Expected Output**:
```json
{
  "result": [{
    "name": "Freundcloud/microservices-demo",
    "number": "REPO0001001",
    "url": "https://github.com/Freundcloud/microservices-demo"
  }]
}
```

### Verify Plan Created

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_plan?sysparm_query=project=c6c9eb71c34d7a50b71ef44c05013194&sysparm_fields=name,number,state" \
  | jq .
```

**Expected Output**:
```json
{
  "result": [{
    "name": "Freundcloud/microservices-demo - Deployment Plan",
    "number": "PLAN0001001",
    "state": "active"
  }]
}
```

### Verify Project Counts Updated

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_project/c6c9eb71c34d7a50b71ef44c05013194?sysparm_fields=name,plan_count,repository_count,pipeline_count" \
  | jq .
```

**Expected Output**:
```json
{
  "result": {
    "name": "Freundcloud/microservices-demo",
    "plan_count": "1",
    "repository_count": "1",
    "pipeline_count": "25"
  }
}
```

### View in ServiceNow UI

Navigate to project:
```
https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_project.do?sys_id=c6c9eb71c34d7a50b71ef44c05013194
```

**Expected**:
- ✅ Plans: 1 record
- ✅ Repositories: 1 record
- ✅ Pipelines: 25 records
- ⏳ Orchestration tasks: TBD (research needed)

## Impact on DevOps Insights

With Plans and Repositories linked:

**DevOps Insights Dashboard** will show:
```
Freundcloud/microservices-demo
  - Quality Scans: 2 ✅
  - Repositories: 1 ✅ (NEW)
  - Plans: 1 ✅ (NEW)
  - Pipelines: 25 ✅
  - Test Results: 1 ✅
  - Performance Tests: 1 ✅
```

## Related Documentation

- [docs/SERVICENOW-PROJECT-LINKAGE-INVESTIGATION.md](SERVICENOW-PROJECT-LINKAGE-INVESTIGATION.md) - Phase 1 investigation
- [docs/SERVICENOW-DEVOPS-INSIGHTS-MISSING-DATA-ANALYSIS.md](SERVICENOW-DEVOPS-INSIGHTS-MISSING-DATA-ANALYSIS.md) - DevOps Insights issue
- [Issue #77](https://github.com/Freundcloud/microservices-demo/issues/77) - Missing Software Quality Summaries and Test Summaries
- [Issue #78](https://github.com/Freundcloud/microservices-demo/issues/78) - DevOps Insights visibility

## Next Steps

1. ✅ **Documentation complete** (this file)
2. ⏳ **Create GitHub issue** to track implementation
3. ⏳ **Implement Phase 1**: Register repository via REST API
4. ⏳ **Implement Phase 2**: Create DevOps plan via REST API
5. ⏳ **Research Phase 3**: Orchestration tasks auto-creation
6. ⏳ **Automate Phase 4**: Add repository/plan checks to workflows

---

**Created**: 2025-11-07
**Last Updated**: 2025-11-07
**Status**: Ready for Implementation
