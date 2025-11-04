# ServiceNow Change Velocity Dashboard Setup

> **Dashboard URL**: `https://YOUR-INSTANCE.service-now.com/now/devops-change/insights-home`

## Overview

The **DevOps Change Velocity** dashboard provides insights into your deployment metrics, showing:
- **Deployment Frequency**: How often you deploy
- **Change Lead Time**: Time from commit to production
- **Change Failure Rate**: Percentage of deployments causing issues
- **Mean Time to Recovery (MTTR)**: Time to recover from failures

This dashboard is based on the **DORA (DevOps Research and Assessment) metrics**.

---

## Why the Dashboard is Empty

The Change Velocity dashboard requires several things to be in place:

### ✅ What We Already Have

1. **Tool Registration**: GitHub Actions tool registered in `sn_devops_tool` ✅
2. **Change Request Creation**: Workflows create CRs with full data ✅
3. **Pipeline Linking**: CRs linked via `sn_devops_change_reference` ✅
4. **Test Results**: Unit, security, SonarCloud, smoke tests tracked ✅
5. **Work Items**: GitHub issues linked to CRs ✅
6. **Artifacts**: Container images tracked ✅
7. **Pipeline Executions**: Full execution history ✅

### ⚠️ What Might Be Missing

1. **DevOps Change Velocity Plugin**: May not be installed (especially in PDIs)
2. **Change Control Configuration**: Tool may not be configured for Change Velocity
3. **Historical Data**: Dashboard shows trends - needs multiple deployments over time
4. **ServiceNow Edition**: Feature availability depends on your ServiceNow edition

---

## Step-by-Step Setup

### 1. Check Plugin Installation

**Personal Developer Instances (PDI)**:
- ❌ DevOps Change Velocity plugin **NOT available** in most PDIs
- ✅ You can still use individual DevOps tables (test results, artifacts, etc.)
- ✅ Change requests still track all data via custom fields

**Enterprise/Production Instances**:
1. Navigate to: **System Applications** → **All Available Applications**
2. Search: `DevOps Change Velocity`
3. If found, click **Install**
4. Wait for installation (~5-10 minutes)

**Verify Installation**:
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_plugins?sysparm_query=source=com.snc.devops.change.velocity&sysparm_fields=active,name,version" \
  | jq '.result'
```

Expected output (if installed):
```json
[
  {
    "active": "true",
    "name": "DevOps Change Velocity",
    "version": "..."
  }
]
```

### 2. Configure Change Control

**Run our configuration script**:
```bash
source .envrc  # Load credentials
./scripts/configure-change-velocity.sh
```

**Manual Configuration**:

Navigate to Change Control Config (try these methods in order):

**Method 1: Application Navigator**
1. Click **"All"** in top-left
2. Search: `change control config` or `change velocity`
3. Look for: **DevOps Change Control Config**

**Method 2: Direct URL**
```
https://YOUR-INSTANCE.service-now.com/sn_devops_change_control_config_list.do
```

**Method 3: Via API**
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config?sysparm_query=tool_id=$SN_ORCHESTRATION_TOOL_ID" \
  | jq '.result'
```

**Configuration Values**:

| Field | Value | Why |
|-------|-------|-----|
| **Tool** | GitHub Actions (your tool ID) | Links to your CI/CD tool |
| **Change Control Enabled** | ✅ `true` | Enables tracking |
| **Create Change Request** | ✅ `true` | Creates traditional CRs (not deployment gates) |
| **Change Type** | `standard` | Type of change requests to create |

**Create Configuration via API** (if not exists):
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "tool_id": "'"$SN_ORCHESTRATION_TOOL_ID"'",
    "change_control_enabled": "true",
    "create_change_request": "true",
    "change_type": "standard"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config" \
  | jq '.'
```

### 3. Verify Data is Being Collected

**Check Change References** (linking CRs to pipelines):
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=5" \
  | jq '.result[] | {change_request: .["change_request.number"], pipeline: .pipeline_name, created: .sys_created_on}'
```

**Check Pipeline Executions**:
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_execution?sysparm_limit=5" \
  | jq '.result[] | {pipeline: .pipeline_name, status: .execution_status, environment: .environment}'
```

**Check Test Results**:
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result?sysparm_limit=5" \
  | jq '.result[] | {suite: .test_suite_name, result: .test_result, type: .test_type}'
```

### 4. Generate Historical Data

The Change Velocity dashboard needs **multiple deployments over time** to show trends.

**Recommended Approach**:
1. Deploy to **dev** environment (creates CR, runs tests, links data)
2. Wait 1 hour
3. Deploy to **dev** again (simulate another change)
4. Wait 1 hour
5. Deploy to **qa** environment
6. Repeat over several days

**Quick Test** (generate multiple CRs):
```bash
# Deploy to dev
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Wait 5 minutes, deploy again
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Wait 5 minutes, deploy to qa
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
```

After 3-5 deployments, the dashboard should start showing data.

### 5. Alternative: Check Individual DevOps Tables

If the dashboard remains empty, you can still access all data via individual tables:

**Change Velocity Components**:

| Metric | ServiceNow Table | URL |
|--------|------------------|-----|
| **Deployment Frequency** | `sn_devops_pipeline_execution` | `/sn_devops_pipeline_execution_list.do` |
| **Change Lead Time** | `change_request` + `sn_devops_change_reference` | `/change_request_list.do` |
| **Test Pass Rate** | `sn_devops_test_result` | `/sn_devops_test_result_list.do` |
| **Work Items** | `sn_devops_work_item` | `/sn_devops_work_item_list.do` |
| **Artifacts** | `sn_devops_artifact` | `/sn_devops_artifact_list.do` |

**View Deployment History**:
```
https://YOUR-INSTANCE.service-now.com/sn_devops_pipeline_execution_list.do
```

**View Change Requests with DevOps Data**:
```
https://YOUR-INSTANCE.service-now.com/change_request_list.do?sysparm_query=u_github_repo=Freundcloud/microservices-demo
```

---

## Understanding DORA Metrics in ServiceNow

### 1. Deployment Frequency

**What it measures**: How often you successfully deploy to production

**Data source**:
- `sn_devops_pipeline_execution` table
- Filter: `environment=prod` + `execution_status=successful`

**How we populate it**:
- Every deployment runs `Register Pipeline Execution` step (Phase 7)
- Records: pipeline name, execution number, status, environment, timestamp

**Calculation**:
```
Deployments per day/week/month = COUNT(successful prod executions) / time period
```

### 2. Change Lead Time

**What it measures**: Time from code commit to production deployment

**Data source**:
- `change_request` table (created timestamp)
- `sn_devops_change_reference` table (links CR to pipeline)
- `sn_devops_pipeline_execution` table (deployment completion)

**How we populate it**:
- Change request created immediately after commit (Phase 0)
- Pipeline execution tracked with timestamps (Phase 7)
- Change reference links CR to execution (Phase 1)

**Calculation**:
```
Lead time = deployment_timestamp - change_request_created_timestamp
```

### 3. Change Failure Rate

**What it measures**: Percentage of deployments causing production issues

**Data source**:
- `change_request` table (close_code field)
- `sn_devops_pipeline_execution` table (execution_status)
- `sn_devops_test_result` table (test failures)

**How we populate it**:
- Close code set to "successful" or "unsuccessful" (update-servicenow-change job)
- Pipeline execution status tracked (successful/failed/cancelled)
- Test results indicate quality (passed/failed)

**Calculation**:
```
Failure rate = COUNT(unsuccessful changes) / COUNT(total changes) * 100
```

### 4. Mean Time to Recovery (MTTR)

**What it measures**: Average time to recover from a deployment failure

**Data source**:
- `change_request` table (failure timestamp, recovery timestamp)
- `sn_devops_pipeline_execution` table (failed execution → successful execution)

**How we populate it**:
- Failed deployments recorded with timestamp
- Recovery deployments linked to same CR or new CR
- Work notes track incident resolution

**Calculation**:
```
MTTR = AVG(recovery_timestamp - failure_timestamp)
```

---

## Troubleshooting

### Dashboard Shows "No Data Available"

**Possible causes**:

1. **Plugin not installed**
   ```bash
   # Check plugin
   ./scripts/configure-change-velocity.sh
   ```

2. **No change control configuration**
   ```bash
   # Create configuration
   ./scripts/configure-change-velocity.sh
   ```

3. **No deployments yet**
   ```bash
   # Run deployment
   gh workflow run MASTER-PIPELINE.yaml -f environment=dev
   ```

4. **Data not processed yet**
   - Wait 5-10 minutes after deployment
   - Refresh dashboard

5. **Personal Developer Instance limitations**
   - PDIs may not have Change Velocity plugin
   - Use individual DevOps tables instead

### Dashboard Shows Partial Data

**Check each metric individually**:

```bash
# Deployment frequency
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_execution?sysparm_query=environment=prod&sysparm_limit=10" \
  | jq '.result | length'

# Change lead time (requires multiple CRs)
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_query=u_github_repo=Freundcloud/microservices-demo&sysparm_limit=10" \
  | jq '.result | length'

# Test results
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_test_result?sysparm_limit=10" \
  | jq '.result | length'
```

### Change Velocity Plugin Not Available

If your instance doesn't have the plugin:

**Alternative 1: Build Custom Dashboard**
- Use ServiceNow Performance Analytics
- Create custom metrics from DevOps tables
- Build dashboards manually

**Alternative 2: Export Data and Visualize Externally**
```bash
# Export pipeline executions
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_execution?sysparm_query=sys_created_onONToday@javascript:gs.daysAgoStart(30)@javascript:gs.daysAgoEnd(0)" \
  | jq '.result' > deployments.json

# Analyze with Python, R, or BI tools
```

**Alternative 3: Use Individual Table Lists**
- Navigate directly to DevOps tables
- Apply filters for your repository/tool
- Export to Excel for manual analysis

---

## Best Practices

### 1. Consistent Deployment Patterns
- Deploy regularly (daily or more frequent)
- Use same workflow for all environments
- Tag production deployments clearly

### 2. Proper Change Request Lifecycle
- Create CR at start of deployment
- Update CR with deployment results
- Close CR with success/failure status

### 3. Comprehensive Test Tracking
- Upload all test types (unit, security, smoke, integration)
- Use consistent test suite naming
- Track test duration for performance insights

### 4. Work Item Linking
- Reference GitHub issues in commit messages
- Format: `Fixes #123`, `Closes #456`, etc.
- Enables requirement → deployment traceability

### 5. Monitor Data Quality
```bash
# Weekly check
./scripts/configure-change-velocity.sh

# Verify recent data
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_execution?sysparm_query=sys_created_onONToday@javascript:gs.daysAgoStart(7)@javascript:gs.daysAgoEnd(0)" \
  | jq '.result | length'
```

---

## Summary

To populate the Change Velocity dashboard:

1. ✅ **Install plugin** (if available in your ServiceNow edition)
2. ✅ **Configure change control** (`./scripts/configure-change-velocity.sh`)
3. ✅ **Run multiple deployments** to build historical data
4. ✅ **Wait for data processing** (5-10 minutes per deployment)
5. ✅ **Check dashboard** (`/now/devops-change/insights-home`)

If plugin not available:
- ✅ Access data via individual DevOps tables
- ✅ Export data for external analysis
- ✅ Build custom ServiceNow dashboards

---

## Related Documentation

- [SERVICENOW-IMPLEMENTATION-COMPLETE.md](SERVICENOW-IMPLEMENTATION-COMPLETE.md) - All 7 phases
- [SERVICENOW-HYBRID-APPROACH.md](SERVICENOW-HYBRID-APPROACH.md) - Table API + DevOps tables
- [SERVICENOW-ENABLE-TRADITIONAL-CRS.md](SERVICENOW-ENABLE-TRADITIONAL-CRS.md) - Change control setup

## Scripts

- `scripts/configure-change-velocity.sh` - Configure Change Velocity dashboard
- `scripts/check-servicenow-change-velocity.sh` - Check current configuration
- `scripts/find-servicenow-tool-id.sh` - Find/create orchestration tool

---

**Last Updated**: 2025-11-04
**Verified With**: ServiceNow Vancouver release (Personal Developer Instance)
