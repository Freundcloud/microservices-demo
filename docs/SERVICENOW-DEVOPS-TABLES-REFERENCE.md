# ServiceNow DevOps Tables - Complete Reference

> **Instance**: calitiiltddemo3.service-now.com
> **Plugin Version**: ServiceNow DevOps (activated)
> **Last Verified**: 2025-11-04
> **Tables Available**: 11 of 19 checked

## Summary

**✅ Available Tables (11)**:
1. `sn_devops_tool` - Tool registry (GitHub, Jenkins, etc.)
2. `sn_devops_package` - Artifact/package tracking
3. `sn_devops_test_result` - Test results
4. `sn_devops_test_execution` - Test execution parent records
5. `sn_devops_performance_test_summary` - Performance/smoke tests
6. `sn_devops_work_item` - Work items (GitHub issues/PRs)
7. `sn_devops_artifact` - Artifact metadata
8. `sn_devops_change_reference` - Change request linkages
9. `sn_devops_commit` - Git commit tracking
10. `sn_devops_pull_request` - Pull request tracking
11. `sn_devops_pipeline_execution` - Pipeline execution tracking ⭐ NEW

**❌ Not Available Tables (8)**:
1. `sn_devops_pipeline_info` - Legacy pipeline table (replaced by pipeline_execution)
2. `sn_devops_security_result` - Security scan results
3. `sn_devops_change` - DevOps change records
4. `sn_devops_deployment` - Deployment tracking
5. `sn_devops_sonar_result` - SonarQube/SonarCloud results
6. `sn_devops_sonar_scan` - SonarQube scan metadata
7. `sn_devops_quality_result` - Code quality results
8. `sn_devops_build` - Build execution tracking

---

## Available Tables - Detailed Reference

### 1. sn_devops_tool

**Purpose**: Master registry for all orchestration tools

**Status**: ✅ Available (1 record)

**Key Fields**:
- `sys_id` (string) - Unique identifier
- `name` (string) - Tool name (e.g., "GitHub")
- `type` (string) - Tool type
- `url` (string) - Tool URL
- `credential` (reference) - Authentication credential

**Our Usage**:
- Tool ID: `f76a57c9c3307a14e1bbf0cb05013135`
- Used as `tool` field in all other DevOps tables
- Found via: `scripts/find-servicenow-tool-id.sh`

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_tool_list.do
```

---

### 2. sn_devops_package

**Purpose**: Track deployment packages and container images

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool ✅
- `name` (string) - Package/image name
- `artifact_name` (string) - Full artifact name
- `version` (string) - Version/tag
- `package_url` (string) - URL to package

**Our Usage**:
- Workflow: `.github/workflows/MASTER-PIPELINE.yaml` (register-packages job)
- Integration: GitHub Action `servicenow-devops-register-package`
- Uploads: All 12 service container images

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_package_list.do
```

---

### 3. sn_devops_test_result

**Purpose**: Store individual test results

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool ✅
- `test_execution` (reference) - Parent test execution
- `label` (string) - Test suite name
- `result` (string) - "passed" or "failed"
- `value` (number) - Duration or metric
- `units` (string) - Units (e.g., "seconds")

**Our Usage**:
- Workflow: `.github/workflows/upload-test-results-servicenow.yaml`
- Called by: MASTER-PIPELINE.yaml (upload-unit-test-results job)
- Uploads: Unit test results after tests complete

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_test_result_list.do
```

---

### 4. sn_devops_test_execution

**Purpose**: Parent record grouping related test results

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool ✅
- `test_url` (string) - Link to test run
- `test_execution_duration` (number) - Total duration
- `results_import_state` (string) - "imported"

**Our Usage**:
- Created automatically when uploading test results
- One execution can have multiple test_result children

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_test_execution_list.do
```

---

### 5. sn_devops_performance_test_summary

**Purpose**: Store performance and smoke test summaries

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool ✅
- `test_name` (string) - Test name
- `duration` (number) - Duration in seconds
- `pass_count` (number) - Tests passed
- `fail_count` (number) - Tests failed
- `test_url` (string) - Link to test run

**Our Usage**:
- Workflow: `.github/workflows/MASTER-PIPELINE.yaml` (smoke-tests job)
- Script: Custom upload in smoke-tests job
- Uploads: Smoke test results after deployment

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_performance_test_summary_list.do
```

---

### 6. sn_devops_work_item

**Purpose**: Link GitHub issues and PRs to change requests

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool ✅
- `change_request` (reference) - Links to change request
- `title` (string) - Issue/PR title
- `type` (string) - "Issue", "Story", "Defect", "Task"
- `source` (string) - "GitHub"
- `external_id` (string) - GitHub issue number
- `url` (string) - Link to GitHub issue
- `state` (string) - "Open" or "Closed"
- `priority` (string) - 1-4

**Our Usage**:
- Workflow: `.github/workflows/servicenow-register-work-items.yaml`
- Called by: MASTER-PIPELINE.yaml (register-work-items job)
- Extracts: Issues from commit messages (Fixes #123, etc.)

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do
```

---

### 7. sn_devops_artifact

**Purpose**: Artifact metadata and tracking

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool
- `name` (string) - Artifact name
- `version` (string) - Version
- `artifact_url` (string) - URL to artifact

**Our Usage**:
- May be created automatically with package registration
- Alternative to sn_devops_package

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_artifact_list.do
```

---

### 8. sn_devops_change_reference

**Purpose**: Link DevOps records to change requests

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool
- `change_request` (reference) - Links to change request
- `pipeline_name` (string) - Pipeline/workflow name
- `run_id` (string) - Run identifier

**Our Usage**:
- Created automatically by ServiceNow DevOps plugin
- Links GitHub Actions runs to change requests

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_change_reference_list.do
```

---

### 9. sn_devops_commit

**Purpose**: Track Git commits

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool
- `commit_id` (string) - Git commit SHA
- `message` (string) - Commit message
- `author` (string) - Commit author
- `timestamp` (datetime) - Commit time

**Our Usage**:
- May be created automatically by GitHub integration
- Tracks commits associated with deployments

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_commit_list.do
```

---

### 10. sn_devops_pull_request

**Purpose**: Track GitHub pull requests

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool
- `pr_number` (string) - GitHub PR number
- `title` (string) - PR title
- `state` (string) - "open", "closed", "merged"
- `url` (string) - Link to GitHub PR

**Our Usage**:
- May be created automatically by GitHub integration
- Links PRs to change requests and deployments

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_pull_request_list.do
```

---

### 11. sn_devops_pipeline_execution

**Purpose**: Track pipeline/workflow executions with detailed metadata

**Status**: ✅ Available (1 record)

**Key Fields**:
- `tool` (reference) - Links to sn_devops_tool
- `change_request` (reference) - Links to change request
- `pipeline_name` (string) - Name of pipeline/workflow
- `pipeline_id` (string) - Unique pipeline run ID
- `pipeline_url` (string) - Link to pipeline run
- `execution_number` (string) - Build/run number
- `execution_status` (string) - "success", "failed", "cancelled"
- `start_time` (datetime) - Execution start time
- `environment` (string) - Target environment
- `triggered_by` (string) - User who triggered execution
- `branch` (string) - Git branch
- `commit_sha` (string) - Git commit SHA

**Our Usage**:
- Workflow: `.github/workflows/servicenow-change-rest.yaml` (register-pipeline-execution step)
- Created automatically when change request is created
- Links pipeline run to change request with complete execution context

**View**:
```
https://calitiiltddemo3.service-now.com/sn_devops_pipeline_execution_list.do
```

**Note**: This replaces the legacy `sn_devops_pipeline_info` table

---

## Not Available Tables

The following tables are **NOT available** in this ServiceNow instance. Attempts to use them will result in "Invalid table" errors.

### sn_devops_pipeline_info

**Status**: ❌ Not Available

**Workaround**: Use sn_devops_change_reference for pipeline linking

---

### sn_devops_security_result

**Status**: ❌ Not Available

**Workaround**:
- Security results added to change request work notes
- Script: `scripts/upload-security-results-servicenow.sh` handles gracefully
- See: `.github/workflows/MASTER-PIPELINE.yaml` (upload-security-scan-results job)

---

### sn_devops_sonar_result / sn_devops_sonar_scan / sn_devops_quality_result

**Status**: ❌ Not Available (all 3)

**Workaround**:
- SonarCloud results added to change request custom fields
- Fields: `sonarcloud_status`, `sonarcloud_bugs`, `sonarcloud_vulnerabilities`, `sonarcloud_code_smells`, `sonarcloud_coverage`
- See: `.github/workflows/servicenow-change-rest.yaml`

---

### sn_devops_change / sn_devops_deployment / sn_devops_build

**Status**: ❌ Not Available (all 3)

**Workaround**:
- Use standard change_request table with custom fields
- Use sn_devops_change_reference for linking
- Use sn_devops_package for build/deployment artifacts

---

## Integration Strategy

### ✅ What Works (Use These)

| Purpose | Table | Integration Method |
|---------|-------|-------------------|
| Tool registry | `sn_devops_tool` | Manual/script creation |
| Packages/Images | `sn_devops_package` | GitHub Action + link script |
| Test results | `sn_devops_test_result` | Reusable workflow |
| Test executions | `sn_devops_test_execution` | Auto-created with test results |
| Smoke tests | `sn_devops_performance_test_summary` | Custom script |
| Work items | `sn_devops_work_item` | Reusable workflow |
| Change linking | `sn_devops_change_reference` | Auto-created |
| Commits | `sn_devops_commit` | Auto-created |
| Pull requests | `sn_devops_pull_request` | Auto-created |
| Pipeline tracking | `sn_devops_pipeline_execution` | Auto-created with change request |

### ⚠️ What Doesn't Work (Use Workarounds)

| Purpose | Missing Table | Workaround |
|---------|---------------|------------|
| Legacy pipeline info | `sn_devops_pipeline_info` | Use sn_devops_pipeline_execution |
| Security results | `sn_devops_security_result` | Change request work notes |
| Code quality | `sn_devops_sonar_result` | Custom fields on change request |
| Deployments | `sn_devops_deployment` | Track via packages + change request |
| Builds | `sn_devops_build` | Track via packages |

---

## Verification Commands

### Check All Tables
```bash
./scripts/check-servicenow-devops-plugin.sh
```

### Check Specific Table
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sn_devops_test_result?sysparm_limit=5" \
  | jq '.result[] | {number, label, result}'
```

### View in ServiceNow UI
Navigate to:
```
System Definition > Tables
Filter: Name starts with "sn_devops"
```

Or direct link:
```
https://calitiiltddemo3.service-now.com/sys_db_object_list.do?sysparm_query=nameLIKEsn_devops
```

---

## Complete URLs

### Available Tables
```
sn_devops_tool:                     https://calitiiltddemo3.service-now.com/sn_devops_tool_list.do
sn_devops_package:                  https://calitiiltddemo3.service-now.com/sn_devops_package_list.do
sn_devops_test_result:              https://calitiiltddemo3.service-now.com/sn_devops_test_result_list.do
sn_devops_test_execution:           https://calitiiltddemo3.service-now.com/sn_devops_test_execution_list.do
sn_devops_performance_test_summary: https://calitiiltddemo3.service-now.com/sn_devops_performance_test_summary_list.do
sn_devops_work_item:                https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do
sn_devops_artifact:                 https://calitiiltddemo3.service-now.com/sn_devops_artifact_list.do
sn_devops_change_reference:         https://calitiiltddemo3.service-now.com/sn_devops_change_reference_list.do
sn_devops_commit:                   https://calitiiltddemo3.service-now.com/sn_devops_commit_list.do
sn_devops_pull_request:             https://calitiiltddemo3.service-now.com/sn_devops_pull_request_list.do
sn_devops_pipeline_execution:       https://calitiiltddemo3.service-now.com/sn_devops_pipeline_execution_list.do
```

---

## Related Documentation

- [ServiceNow DevOps Tables Complete Guide](./SERVICENOW-DEVOPS-TABLES-COMPLETE.md)
- [ServiceNow Hybrid Approach](./SERVICENOW-HYBRID-APPROACH.md)
- [ServiceNow Data Inventory](./SERVICENOW-DATA-INVENTORY.md)

---

**Last Updated**: 2025-11-04
**Verification**: Tested against calitiiltddemo3.service-now.com
**Status**: ✅ 11 tables available and working
