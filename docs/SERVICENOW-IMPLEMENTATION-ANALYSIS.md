# ServiceNow DevOps Integration - Implementation Analysis

> **Status**: 🔍 Investigation
> **Last Updated**: 2025-11-04
> **Issue**: Change Velocity dashboard not showing GitHub data despite tool registration

---

## Summary

The ServiceNow Change Velocity dashboard (https://calitiiltddemo3.service-now.com/now/devops/insights-home) shows data from GitLab (HelloWorkd4) but not from GitHub (GithHubARC), despite both tools being registered.

### Root Cause Discovered

**All `tool` fields in DevOps tables are NULL**, including:
- `sn_devops_change_reference.tool` = `null` (28 records)
- `sn_devops_pipeline_execution.tool` = `null` (805 records)

This explains why the Change Velocity dashboard cannot filter or display GitHub data - it has no way to associate the data with the GitHub tool.

---

## Investigation Findings

### 1. Tools Are Registered

✅ **Three tools exist** in `sn_devops_tool` table:
1. **GitLab Demo 2025 HelloWorld** (`HelloWorkd4`)
2. **SonarCloud**
3. **GithHubARC** (our GitHub Actions tool)

Tool ID: `f62c4e49c3fcf614e1bbf0cb050131ef`

### 2. DevOps Tables Have Data

✅ **Tables with data**:
- `sn_devops_tool` - 3 tools
- `sn_devops_change_reference` - 28 records (all tool=NULL)
- `sn_devops_pipeline_execution` - 805 records (all tool=NULL)
- `sn_devops_test_result` - Has data (tool field not checked yet)
- `sn_devops_test_summary` - Has data
- `sn_devops_performance_test_summary` - Has data (1 record created manually)
- `sn_devops_work_item` - Has data
- `sn_devops_artifact` - Has data
- `sn_devops_package` - Has data
- `sn_devops_pipeline` - Has data
- `sn_devops_repository` - Has data
- `sn_devops_app` - Has data
- `sn_devops_commit` - Has data
- `sn_devops_pull_request` - Has data

❌ **Tables with NO data**:
- `sn_devops_build_test_summary` - Empty

### 3. Workflow Sends Tool ID

✅ **Workflow code includes tool ID**:

```yaml
# In servicenow-change-rest.yaml
- name: Link Change Request to DevOps Pipeline
  run: |
    curl -s -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -X POST \
      -d '{
        "change_request": "'"$CHANGE_SYSID"'",
        "pipeline_name": "Deploy to ${{ inputs.environment }}",
        "pipeline_id": "${{ github.run_id }}",
        "pipeline_url": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}",
        "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
      }' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_change_reference"
```

### 4. Secret Exists But May Be Empty

✅ **Secret is configured**:
```bash
$ gh secret list --repo Freundcloud/microservices-demo | grep ORCHESTRATION
SN_ORCHESTRATION_TOOL_ID	2025-10-29T12:25:19Z
```

❓ **But the value might be empty or incorrect**

When the workflow runs with `"tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"` and the secret is empty, the JSON becomes:
```json
{
  "tool": ""  // Empty string, which ServiceNow stores as NULL
}
```

### 5. Change Velocity Dashboard Dependencies

The Change Velocity dashboard reads from:
- `sn_devops_change_reference` - Links change requests to pipelines **BY TOOL**
- `sn_devops_pipeline_execution` - Pipeline execution history **BY TOOL**
- `sn_devops_test_summary` - Test summaries (optional)
- `sn_devops_artifact` - Deployed artifacts (optional)

**Without `tool` field populated**, the dashboard cannot:
- Filter by tool (GitHub vs GitLab)
- Display GitHub-specific metrics
- Calculate DORA metrics for GitHub deployments

---

## Why GitLab Data Appears

🔍 **Paradox**: GitLab data appears in dashboard but:
- `sn_devops_change_reference` has NO change control configuration
- `sn_devops_change_control_config` table doesn't exist in this instance
- Yet GitLab data is visible

**Hypothesis**:
1. GitLab might be using a different integration method (webhook, plugin)
2. GitLab data might be populated manually or via different API
3. The dashboard might read from different tables for GitLab

---

## Fix Required

### Immediate Action: Verify and Set Tool ID Secret

1. **Check current secret value**:
   ```bash
   # In GitHub Actions workflow, add debug step:
   - name: Debug Tool ID
     run: |
       echo "Tool ID length: ${#SN_ORCHESTRATION_TOOL_ID}"
       echo "Tool ID (first 10 chars): ${SN_ORCHESTRATION_TOOL_ID:0:10}"
     env:
       SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
   ```

2. **Update secret with correct value**:
   ```bash
   gh secret set SN_ORCHESTRATION_TOOL_ID \
     --body "f62c4e49c3fcf614e1bbf0cb050131ef" \
     --repo Freundcloud/microservices-demo
   ```

3. **Verify tool ID is correct**:
   ```bash
   curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool/f62c4e49c3fcf614e1bbf0cb050131ef?sysparm_fields=name,type" \
     | jq '.result'
   ```

### Testing

After updating the secret:
1. Run a test deployment
2. Check if `tool` field is populated:
   ```bash
   curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=1&sysparm_display_value=true&sysparm_fields=tool,pipeline_name,sys_created_on" \
     | jq '.result'
   ```
3. Expected output:
   ```json
   {
     "tool": "GithHubARC",
     "pipeline_name": "Deploy to dev",
     "sys_created_on": "2025-11-04 14:00:00"
   }
   ```

---

## Smoke Test Table Fix

### Problem
Smoke tests were being sent to `sn_devops_test_result` (generic test table) instead of `sn_devops_performance_test_summary` (performance-specific table).

### Solution
Changed workflow to use `sn_devops_performance_test_summary` with proper fields:

**Parent table fields** (from `sn_devops_test_summary`):
- `name` - Test suite name
- `tool` - Orchestration tool ID
- `url` - Test results URL
- `start_time` - When test started
- `duration` - Test duration in seconds
- `total_tests`, `passed_tests`, `failed_tests`, `skipped_tests`, `blocked_tests`
- `passing_percent` - Percentage of tests passed

**Performance-specific fields**:
- `avg_time` - Average execution time (milliseconds)
- `min_time` - Minimum execution time (milliseconds)
- `max_time` - Maximum execution time (milliseconds)
- `ninety_percent` - 90th percentile time (milliseconds)
- `standard_deviation` - Standard deviation
- `throughput` - Requests per second (string)
- `maximum_virtual_users` - Concurrent users (integer)

**Implementation**:
```yaml
curl -s \
  -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "Smoke Tests - Post-Deployment (${{ inputs.environment }})",
    "tool": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}",
    "url": "${{ inputs.smoke_test_url }}",
    "start_time": "'"$START_TIME"'",
    "duration": '$DURATION',
    "total_tests": 1,
    "passed_tests": '$([[ "$SMOKE_STATUS" == "passed" ]] && echo "1" || echo "0")',
    "failed_tests": '$([[ "$SMOKE_STATUS" != "passed" ]] && echo "1" || echo "0")',
    "skipped_tests": 0,
    "blocked_tests": 0,
    "passing_percent": '$([[ "$SMOKE_STATUS" == "passed" ]] && echo "100" || echo "0")',
    "avg_time": '$DURATION_MS',
    "min_time": '$DURATION_MS',
    "max_time": '$DURATION_MS',
    "ninety_percent": '$DURATION_MS',
    "standard_deviation": 0.0,
    "throughput": "1",
    "maximum_virtual_users": 1
  }' \
  "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sn_devops_performance_test_summary"
```

---

## Next Steps

1. ✅ **Update SN_ORCHESTRATION_TOOL_ID secret** with correct value
2. ✅ **Run test deployment** to verify tool field is populated
3. ✅ **Check Change Velocity dashboard** after deployment
4. ✅ **Document findings** in this file
5. ✅ **Update SERVICENOW-CHANGE-VELOCITY-DASHBOARD.md** with actual fix

---

## Related Files

- `.github/workflows/servicenow-change-rest.yaml` - Main ServiceNow integration workflow
- `.github/workflows/MASTER-PIPELINE.yaml` - Master CI/CD pipeline
- `scripts/diagnose-change-velocity-dashboard.sh` - Diagnostic script
- `scripts/configure-change-velocity.sh` - Configuration script
- `docs/SERVICENOW-CHANGE-VELOCITY-DASHBOARD.md` - Dashboard setup guide
- `docs/SERVICENOW-IMPLEMENTATION-COMPLETE.md` - Complete implementation docs

---

## ServiceNow DevOps Tables Reference

| Table | Purpose | Records | Tool Field Status |
|-------|---------|---------|-------------------|
| `sn_devops_tool` | Orchestration tools | 3 | N/A (this IS the tools table) |
| `sn_devops_change_reference` | Links CRs to pipelines | 28 | ❌ All NULL |
| `sn_devops_pipeline_execution` | Pipeline execution history | 805 | ❌ All NULL |
| `sn_devops_test_result` | Individual test executions | Many | ❓ Not checked |
| `sn_devops_test_summary` | Aggregated test summaries | Many | ❓ Not checked |
| `sn_devops_performance_test_summary` | Performance test summaries | 1 | ✅ Should have tool ID now |
| `sn_devops_work_item` | Work items/issues | Many | ❓ Not checked |
| `sn_devops_artifact` | Deployment artifacts | Many | ❓ Not checked |
| `sn_devops_package` | Package versions | Many | ❓ Not checked |
| `sn_devops_pipeline` | Pipeline definitions | Many | ❓ Not checked |
| `sn_devops_repository` | Source repositories | Many | ❓ Not checked |
| `sn_devops_app` | Applications | Many | ❓ Not checked |
| `sn_devops_commit` | Git commits | Many | ❓ Not checked |
| `sn_devops_pull_request` | Pull requests | Many | ❓ Not checked |
| `sn_devops_build_test_summary` | Build test summaries | 0 | N/A (empty) |

---

**Last Analysis**: 2025-11-04 13:45 UTC
**Analyzer**: Claude Code Agent
