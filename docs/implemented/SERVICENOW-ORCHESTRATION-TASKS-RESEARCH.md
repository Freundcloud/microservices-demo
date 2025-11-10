# ServiceNow Orchestration Tasks Research & Implementation

> **Created**: 2025-11-07
> **Status**: Research Complete, Ready for Implementation
> **Related Issue**: #79

## Executive Summary

**Goal**: Track GitHub Actions job executions in ServiceNow as orchestration tasks, providing visibility into CI/CD job-level execution details within the ServiceNow DevOps platform.

**Current State**:
- ❌ 0 orchestration tasks for `Freundcloud/microservices-demo`
- ✅ Table exists (`sn_devops_orchestration_task`)
- ✅ Example task found from another repo (scaling-spoon)
- ✅ Tool ID: `f62c4e49c3fcf614e1bbf0cb050131ef` (GithHubARC)
- ✅ Project ID: `c6c9eb71c34d7a50b71ef44c05013194` (PRJ0001001)

**Solution**: Create orchestration tasks via REST API for each GitHub Actions job execution.

---

## What Are Orchestration Tasks?

**Definition**: Orchestration tasks represent individual CI/CD job executions (GitHub Actions jobs, Jenkins jobs, Azure DevOps tasks).

**Purpose**:
- Track job-level execution details (not just workflow-level)
- Link jobs to projects for visibility in ServiceNow
- Provide audit trail of automation execution
- Enable job-based change approval gates

**Example**: A workflow with 3 jobs creates 3 orchestration tasks:
- `Freundcloud/microservices-demo/security-scan#trivy-scan`
- `Freundcloud/microservices-demo/security-scan#semgrep-sast`
- `Freundcloud/microservices-demo/security-scan#dependency-review`

---

## Research Findings

### 1. Existing Orchestration Task Analysis

**Example from scaling-spoon repository**:
```json
{
  "native_id": "sncsenpai/scaling-spoon/build_and_sn#build",
  "name": "sncsenpai/scaling-spoon/build_and_sn#build",
  "task_url": "https://github.com/sncsenpai/scaling-spoon/actions/runs/19163218671/job/54777942354",
  "tool": "9509a4cdc30dfa10e1bbf0cb0501318c",  // Scaling Spoon tool
  "project": "",  // Empty (same issue we had!)
  "task_definition": "cc4bbe2fc7223300b8e302b827c26074",  // Pipeline-Stage
  "step": "629baab1c345b650e1bbf0cb05013197",  // build step
  "track": "true"
}
```

**Key Observations**:
- ✅ Format: `{owner}/{repo}/{workflow-name}#{job-name}`
- ✅ `task_url` points to specific GitHub Actions job
- ⚠️ `project` field is empty (similar to our previous issue)
- ✅ Links to `task_definition` (Pipeline-Stage)
- ✅ Links to `step` record

### 2. Table Schema

**Required Fields**:
| Field | Type | Mandatory | Description |
|-------|------|-----------|-------------|
| `name` | string | No | Orchestration task name |
| `native_id` | string | No | Native identifier (format: repo/workflow#job) |
| `task_url` | url | No | Link to GitHub Actions job |
| `tool` | reference | No | Tool sys_id (GithHubARC) |
| `project` | reference | No | Project sys_id (CRITICAL for visibility) |
| `task_definition` | reference | No | Task type (Pipeline-Stage) |
| `step` | reference | No | Step record |
| `track` | boolean | No | Whether to track (default: true) |

**All fields are optional**, but `project` is CRITICAL for visibility in ServiceNow project views.

### 3. Dependencies

**Required References**:
1. **Tool** (`sn_devops_tool`): ✅ We have this - `f62c4e49c3fcf614e1bbf0cb050131ef`
2. **Project** (`sn_devops_project`): ✅ We have this - `c6c9eb71c34d7a50b71ef44c05013194`
3. **Task Definition** (`sn_devops_orchestration_task_definition`): ⚠️ Need to find or create
4. **Step** (`sn_devops_step`): ⚠️ Need to create per job

### 4. GitHub Actions Job Information

**Available from GitHub Actions Context**:
```yaml
${{ github.repository }}      # Freundcloud/microservices-demo
${{ github.workflow }}         # Workflow name (e.g., "Security Scanning")
${{ github.job }}             # Job name (e.g., "trivy-scan")
${{ github.run_id }}          # Workflow run ID
${{ github.server_url }}      # https://github.com
${{ github.sha }}             # Commit SHA
${{ github.ref }}             # Branch/tag ref
```

**Constructed Job URL**:
```
https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}/job/${{ job_id }}
```

**Challenge**: `job_id` is NOT available in GitHub Actions context. We need to use GitHub API to get it.

---

## Implementation Strategy

### Option A: Manual Orchestration Task Creation (Recommended)

**Approach**: Create orchestration tasks via REST API in GitHub Actions workflows.

**Advantages**:
- ✅ Full control over data
- ✅ Can link to project immediately
- ✅ No dependency on ServiceNow DevOps plugin configuration
- ✅ Can customize task names and metadata

**Disadvantages**:
- ❌ Requires GitHub API call to get job ID
- ❌ Must be added to each workflow
- ❌ Manual maintenance

**Implementation**:
```yaml
- name: Register Orchestration Task
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  run: |
    # Get job ID from GitHub API
    JOB_ID=$(gh api "/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/jobs" \
      --jq '.jobs[] | select(.name == "${{ github.job }}") | .id')

    # Construct job URL
    JOB_URL="https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}/job/${JOB_ID}"

    # Create orchestration task
    curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      -H "Content-Type: application/json" \
      -X POST \
      -d '{
        "name": "${{ github.repository }}/${{ github.workflow }}#${{ github.job }}",
        "native_id": "${{ github.repository }}/${{ github.workflow }}#${{ github.job }}",
        "task_url": "'"$JOB_URL"'",
        "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
        "project": "c6c9eb71c34d7a50b71ef44c05013194",
        "track": true
      }' \
      "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_task"
```

### Option B: ServiceNow DevOps GitHub Integration (Future)

**Approach**: Configure ServiceNow DevOps GitHub App to auto-create orchestration tasks.

**Advantages**:
- ✅ Automatic task creation
- ✅ No workflow modifications needed
- ✅ Official ServiceNow approach

**Disadvantages**:
- ❌ Requires GitHub App installation
- ❌ Requires ServiceNow plugin configuration
- ❌ May have same issues as project auto-creation (not working)
- ❌ Less control over data

**Status**: Not currently working (same root cause as Issue #77)

---

## Proof of Concept

### Test Orchestration Task Creation

**Script**: Create a test orchestration task for the most recent workflow run.

```bash
#!/bin/bash
# Test: Create orchestration task for latest Security Scanning workflow

# Get latest workflow run
RUN_ID=$(gh run list --repo Freundcloud/microservices-demo \
  --workflow="Security Scanning" --limit 1 --json databaseId --jq '.[0].databaseId')

# Get first job from that run
JOB_DATA=$(gh api "/repos/Freundcloud/microservices-demo/actions/runs/$RUN_ID/jobs" \
  --jq '.jobs[0] | {id: .id, name: .name}')

JOB_ID=$(echo "$JOB_DATA" | jq -r '.id')
JOB_NAME=$(echo "$JOB_DATA" | jq -r '.name')
JOB_URL="https://github.com/Freundcloud/microservices-demo/actions/runs/$RUN_ID/job/$JOB_ID"

# Create orchestration task
RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "Freundcloud/microservices-demo/Security Scanning#'"$JOB_NAME"'",
    "native_id": "Freundcloud/microservices-demo/Security Scanning#'"$JOB_NAME"'",
    "task_url": "'"$JOB_URL"'",
    "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "project": "c6c9eb71c34d7a50b71ef44c05013194",
    "track": true
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_task")

# Check result
if echo "$RESPONSE" | jq -e '.result' > /dev/null 2>&1; then
  TASK_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')
  TASK_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number // "N/A"')
  echo "✅ Orchestration task created: $TASK_NUMBER (sys_id: $TASK_ID)"
else
  echo "❌ Failed to create orchestration task:"
  echo "$RESPONSE" | jq -r '.error.message // "Unknown error"'
fi
```

---

## Implementation Plan

### Phase 1: Proof of Concept (Immediate)

**Goal**: Create 1 orchestration task manually to verify approach.

**Steps**:
1. ✅ Research table schema and existing tasks (COMPLETE)
2. ⏳ Create test script to generate orchestration task
3. ⏳ Execute script and verify task appears in ServiceNow
4. ⏳ Verify task is linked to project
5. ⏳ Document findings

**Success Criteria**:
- Orchestration task created in ServiceNow
- Task linked to project (`c6c9eb71c34d7a50b71ef44c05013194`)
- Task visible in project related list
- Task has valid job URL

### Phase 2: Reusable Workflow Action (Short-term)

**Goal**: Create reusable GitHub Actions composite action for orchestration task registration.

**File**: `.github/actions/register-orchestration-task/action.yaml`

```yaml
name: Register ServiceNow Orchestration Task
description: Register GitHub Actions job as ServiceNow orchestration task
inputs:
  servicenow-username:
    required: true
  servicenow-password:
    required: true
  servicenow-instance-url:
    required: true
  project-id:
    required: false
    default: 'c6c9eb71c34d7a50b71ef44c05013194'
  tool-id:
    required: false
    default: 'f62c4e49c3fcf614e1bbf0cb050131ef'

runs:
  using: composite
  steps:
    - name: Get Job ID
      shell: bash
      id: job-id
      run: |
        JOB_ID=$(gh api "/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/jobs" \
          --jq '.jobs[] | select(.name == "${{ github.job }}") | .id')
        echo "job_id=$JOB_ID" >> $GITHUB_OUTPUT

    - name: Register Orchestration Task
      shell: bash
      env:
        SERVICENOW_USERNAME: ${{ inputs.servicenow-username }}
        SERVICENOW_PASSWORD: ${{ inputs.servicenow-password }}
        SERVICENOW_INSTANCE_URL: ${{ inputs.servicenow-instance-url }}
        JOB_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}/job/${{ steps.job-id.outputs.job_id }}
      run: |
        curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
          -H "Content-Type: application/json" \
          -X POST \
          -d '{
            "name": "${{ github.repository }}/${{ github.workflow }}#${{ github.job }}",
            "native_id": "${{ github.repository }}/${{ github.workflow }}#${{ github.job }}",
            "task_url": "'"$JOB_URL"'",
            "tool": "${{ inputs.tool-id }}",
            "project": "${{ inputs.project-id }}",
            "track": true
          }' \
          "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_orchestration_task"
```

**Usage in workflows**:
```yaml
- uses: ./.github/actions/register-orchestration-task
  with:
    servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
    servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
    servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
```

### Phase 3: Add to Key Workflows (Medium-term)

**Target Workflows**:
1. `.github/workflows/security-scan.yaml` - All security scanning jobs
2. `.github/workflows/build-images.yaml` - All service build jobs
3. `.github/workflows/deploy-environment.yaml` - Deployment jobs
4. `.github/workflows/terraform-apply.yaml` - Infrastructure jobs

**Implementation**:
- Add as first step in each job
- Captures job start time automatically
- Can add second step at end to update with completion status (future enhancement)

### Phase 4: Advanced Features (Future)

**Potential Enhancements**:
1. **Job Status Updates**: Update orchestration task with `success`/`failure` status
2. **Duration Tracking**: Record job start/end times
3. **Step-Level Tracking**: Create `sn_devops_step` records for individual steps
4. **Link to Pipeline Executions**: Associate tasks with pipeline execution records
5. **Change Request Linkage**: Auto-link orchestration tasks to change requests

---

## Expected Benefits

### For DevOps Teams:
- ✅ Job-level visibility in ServiceNow
- ✅ Complete CI/CD audit trail
- ✅ Job execution history per project
- ✅ Troubleshooting with direct links to GitHub Actions

### For Approvers:
- ✅ See which jobs ran for a deployment
- ✅ Verify security scans executed successfully
- ✅ Audit compliance of automation
- ✅ Risk assessment based on job outcomes

### For Compliance/Audit:
- ✅ Complete record of automation execution
- ✅ Job-level change evidence
- ✅ Searchable job execution history
- ✅ Integration with ServiceNow ITSM

---

## Risks and Mitigations

### Risk 1: GitHub API Rate Limiting

**Risk**: Calling GitHub API to get job ID may hit rate limits.

**Mitigation**:
- Use `GITHUB_TOKEN` (higher rate limits for authenticated requests)
- Cache job ID per run (only call once per run)
- Add retry logic with exponential backoff

### Risk 2: Task Definition and Step Records

**Risk**: We don't have `task_definition` or `step` records created.

**Mitigation**:
- These fields are optional (not mandatory)
- Create tasks without them initially
- Can create task definitions later if needed
- ServiceNow may auto-create them if properly configured

### Risk 3: Workflow Performance Impact

**Risk**: Adding API calls to every job may slow workflows.

**Mitigation**:
- API calls are fast (< 500ms typically)
- Run in parallel with actual job work
- Use `continue-on-error: true` to not block on failures

### Risk 4: Orphaned Tasks

**Risk**: Tasks created but jobs fail before completion.

**Mitigation**:
- Acceptable - still provides audit trail
- Can add cleanup job to remove orphaned tasks
- Future enhancement: Update status on completion

---

## Success Metrics

**Before Implementation**:
- Orchestration tasks: 0
- Job-level visibility: None
- CI/CD audit trail: Partial (pipeline-level only)

**After Phase 1** (POC):
- Orchestration tasks: 1 (test)
- Job-level visibility: Proof of concept ✅
- Linked to project: ✅

**After Phase 2** (Reusable Action):
- Orchestration tasks: Created per workflow run
- Reusable action: Available for all workflows ✅
- Developer experience: Simple 3-line addition to jobs ✅

**After Phase 3** (Key Workflows):
- Orchestration tasks: 10+ per deployment
- Coverage: Security, build, deploy, infrastructure ✅
- Complete CI/CD visibility: ✅

---

## Next Steps

1. ⏳ **Create POC script** - Test orchestration task creation
2. ⏳ **Verify in ServiceNow** - Confirm task appears and is linked to project
3. ⏳ **Document findings** - Update this document with POC results
4. ⏳ **Create composite action** - Build reusable workflow action
5. ⏳ **Test in one workflow** - Add to security-scan.yaml first
6. ⏳ **Roll out to other workflows** - Expand coverage gradually
7. ⏳ **Monitor and optimize** - Track API usage, performance, value

---

## Related Documentation

- [Issue #79](https://github.com/Freundcloud/microservices-demo/issues/79) - Orchestration tasks tracking
- [Issue #77](https://github.com/Freundcloud/microservices-demo/issues/77) - Project linkage implementation
- [docs/SERVICENOW-PROJECT-MISSING-PLANS-REPOS-ORCHESTRATION.md](SERVICENOW-PROJECT-MISSING-PLANS-REPOS-ORCHESTRATION.md) - Plans and repositories investigation
- [docs/SERVICENOW-SESSION-SUMMARY-2025-11-07.md](SERVICENOW-SESSION-SUMMARY-2025-11-07.md) - Complete session summary

---

**Created**: 2025-11-07
**Status**: Research Complete ✅
**Ready for**: Phase 1 POC Implementation
