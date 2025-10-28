# ServiceNow Test Trend Analysis Dashboards

## Overview

This guide explains how to create comprehensive test trend analysis dashboards in ServiceNow to visualize test results, track quality metrics, and identify trends over time.

**Purpose**: Enable data-driven decision making for change approvals and quality gates

**Date**: 2025-10-28

---

## Prerequisites

- ServiceNow DevOps plugin installed
- Test results being uploaded via GitHub Actions
- Access to ServiceNow Platform (admin or report creator role)
- Code coverage custom table created (u_code_coverage)

---

## Dashboard Architecture

### Data Sources

**1. Test Results** (`sn_devops_test_result`)
- Test execution data from all services
- Pass/fail counts
- Test framework information
- Linked to commits and workflows

**2. Code Coverage** (`u_code_coverage`)
- Coverage percentage per service
- Lines covered vs total lines
- Historical coverage trends

**3. Change Requests** (`change_request`)
- Deployment tracking
- Approval decisions
- Link to test evidence

---

## Step 1: Create Custom Code Coverage Table

### Create Table in ServiceNow

Navigate to: **System Definition → Tables**

Click **New** and configure:

| Field | Value |
|-------|-------|
| Label | Code Coverage |
| Name | u_code_coverage |
| Extends table | (none - create from scratch) |
| Add module to menu | Checked |
| Create access controls | Checked |

**Table Fields**:

| Column Label | Column Name | Type | Max Length | Mandatory |
|--------------|-------------|------|------------|-----------|
| Service | u_service | String | 100 | Yes |
| Coverage Percent | u_coverage_percent | Decimal | - | Yes |
| Lines Covered | u_lines_covered | Integer | - | No |
| Lines Total | u_lines_total | Integer | - | No |
| Commit SHA | u_commit_sha | String | 50 | Yes |
| Workflow Run ID | u_workflow_run_id | String | 100 | No |
| Repository | u_repository | String | 200 | Yes |
| Coverage File | u_coverage_file | String | 500 | No |

### Create Table via Script

Alternatively, run this in **System Definition → Scripts - Background**:

```javascript
// Create Code Coverage table
var grTable = new GlideRecord('sys_db_object');
grTable.initialize();
grTable.setValue('name', 'u_code_coverage');
grTable.setValue('label', 'Code Coverage');
grTable.setValue('super_class', '');
grTable.setValue('sys_scope', 'global'); // or your app scope
grTable.insert();

// Create fields
var fields = [
  {name: 'u_service', label: 'Service', type: 'string', max_length: 100, mandatory: true},
  {name: 'u_coverage_percent', label: 'Coverage Percent', type: 'decimal', mandatory: true},
  {name: 'u_lines_covered', label: 'Lines Covered', type: 'integer'},
  {name: 'u_lines_total', label: 'Lines Total', type: 'integer'},
  {name: 'u_commit_sha', label: 'Commit SHA', type: 'string', max_length: 50, mandatory: true},
  {name: 'u_workflow_run_id', label: 'Workflow Run ID', type: 'string', max_length: 100},
  {name: 'u_repository', label: 'Repository', type: 'string', max_length: 200, mandatory: true},
  {name: 'u_coverage_file', label: 'Coverage File', type: 'string', max_length: 500}
];

fields.forEach(function(field) {
  var grField = new GlideRecord('sys_dictionary');
  grField.initialize();
  grField.setValue('name', 'u_code_coverage');
  grField.setValue('element', field.name);
  grField.setValue('column_label', field.label);
  grField.setValue('internal_type', field.type);
  if (field.max_length) grField.setValue('max_length', field.max_length);
  if (field.mandatory) grField.setValue('mandatory', true);
  grField.insert();
});

gs.info('Code Coverage table created successfully');
```

---

## Step 2: Create Test Trend Reports

### Report 1: Test Pass Rate Over Time

**Navigate to**: Reports → View/Run

Click **New** and configure:

| Field | Value |
|-------|-------|
| Type | Line Chart |
| Table | Test Result [sn_devops_test_result] |
| Group by | Created (Date) |
| Trend by | (leave empty) |

**Metrics**:
- Add Metric: `Aggregate: Average`, `Field: Tests Passed`, `Label: Pass Rate`
- Add Metric: `Aggregate: Count`, `Field: Sys ID`, `Label: Total Test Runs`

**Conditions**:
- `Created` `is` `Last 30 days`
- `Repository` `is` `Freundcloud/microservices-demo` (optional filter)

**Chart Settings**:
- Chart Type: Line
- Display: Show data labels
- Color scheme: Blue/Green

**Save as**: `Test Pass Rate - Last 30 Days`

---

### Report 2: Test Results by Service

**Navigate to**: Reports → View/Run

Click **New**:

| Field | Value |
|-------|-------|
| Type | Bar Chart |
| Table | Test Result [sn_devops_test_result] |
| Group by | Service Name |

**Metrics**:
- `Aggregate: Sum`, `Field: Tests Passed`, `Label: Passed`
- `Aggregate: Sum`, `Field: Tests Failed`, `Label: Failed`
- `Aggregate: Sum`, `Field: Tests Skipped`, `Label: Skipped`

**Conditions**:
- `Created` `is` `Today`

**Save as**: `Test Results by Service - Today`

---

### Report 3: Code Coverage Trends

**Navigate to**: Reports → View/Run

Click **New**:

| Field | Value |
|-------|-------|
| Type | Line Chart |
| Table | Code Coverage [u_code_coverage] |
| Group by | Created (Date) |

**Metrics**:
- `Aggregate: Average`, `Field: Coverage Percent`, `Label: Avg Coverage`

**Conditions**:
- `Created` `is` `Last 90 days`
- `Repository` `is` `Freundcloud/microservices-demo`

**Save as**: `Code Coverage Trend - 90 Days`

---

### Report 4: Code Coverage by Service

**Navigate to**: Reports → View/Run

Click **New**:

| Field | Value |
|-------|-------|
| Type | Bar Chart (Horizontal) |
| Table | Code Coverage [u_code_coverage] |
| Group by | Service |

**Metrics**:
- `Aggregate: Average`, `Field: Coverage Percent`, `Label: Coverage %`

**Conditions**:
- `Created` `is` `Last 7 days`

**Sort**: Descending by Coverage %

**Save as**: `Code Coverage by Service - Last 7 Days`

---

### Report 5: Test Failure Rate

**Navigate to**: Reports → View/Run

Click **New**:

| Field | Value |
|-------|-------|
| Type | Pie Chart |
| Table | Test Result [sn_devops_test_result] |
| Group by | Service Name |

**Metrics**:
- `Aggregate: Sum`, `Field: Tests Failed`, `Label: Failures`

**Conditions**:
- `Created` `is` `Last 30 days`
- `Tests Failed` `>` `0` (only show services with failures)

**Save as**: `Test Failures by Service - Last 30 Days`

---

## Step 3: Create Dashboard

### Create New Dashboard

**Navigate to**: Self-Service → Dashboards

Click **New Dashboard**:

| Field | Value |
|-------|-------|
| Title | Test Quality Dashboard |
| Description | Real-time test results and coverage trends |
| Layout | 2-Column Layout |
| Visibility | Public (or restrict to specific groups) |

---

### Add Reports to Dashboard

**Left Column**:

1. **Test Pass Rate - Last 30 Days** (Line Chart)
   - Shows trend of test success over time
   - Size: Large

2. **Code Coverage Trend - 90 Days** (Line Chart)
   - Shows coverage improvement over time
   - Size: Large

3. **Test Failures by Service - Last 30 Days** (Pie Chart)
   - Highlights problematic services
   - Size: Medium

**Right Column**:

1. **Test Results by Service - Today** (Bar Chart)
   - Today's test execution summary
   - Size: Large

2. **Code Coverage by Service - Last 7 Days** (Horizontal Bar)
   - Current coverage status per service
   - Size: Large

3. **Recent Test Executions** (List)
   - Table: sn_devops_test_result
   - Columns: Service, Tests Passed, Tests Failed, Created
   - Limit: 10 most recent
   - Size: Medium

---

## Step 4: Add KPI Indicators

### Create KPI for Overall Pass Rate

**Navigate to**: Performance Analytics → Indicators → Automated Indicators

Click **New**:

| Field | Value |
|-------|-------|
| Name | Test Pass Rate (Overall) |
| Table | Test Result [sn_devops_test_result] |
| Aggregate | Average |
| Field | Tests Passed |
| Frequency | Daily |

**Goal**: 95% (threshold for quality gate)

**Add to Dashboard**: Yes (top of dashboard)

---

### Create KPI for Coverage

**Navigate to**: Performance Analytics → Indicators → Automated Indicators

Click **New**:

| Field | Value |
|-------|-------|
| Name | Code Coverage (Overall) |
| Table | Code Coverage [u_code_coverage] |
| Aggregate | Average |
| Field | Coverage Percent |
| Frequency | Daily |

**Goal**: 80% (target coverage)

**Add to Dashboard**: Yes

---

## Step 5: Create Scheduled Reports

### Email Report: Weekly Test Summary

**Navigate to**: Reports → Scheduled Reports

Click **New**:

| Field | Value |
|-------|-------|
| Report | Test Pass Rate - Last 30 Days |
| Schedule | Weekly (Monday 9 AM) |
| Recipients | DevOps Team, QA Team |
| Format | PDF |
| Subject | Weekly Test Quality Report |

**Body Template**:
```
Test Quality Summary for Week Ending [DATE]

Overall Pass Rate: [METRIC]
Total Test Executions: [COUNT]
Services with Failures: [LIST]

View full dashboard: [DASHBOARD_URL]
```

---

### Email Report: Coverage Alert (Low Coverage)

**Navigate to**: Reports → Scheduled Reports

Click **New**:

| Field | Value |
|-------|-------|
| Report | Code Coverage by Service - Last 7 Days |
| Schedule | Daily (8 AM) |
| Recipients | Development Leads |
| Condition | Average Coverage < 70% |
| Format | HTML |
| Subject | 🚨 Low Code Coverage Alert |

---

## Step 6: Add to Change Request Form

### Embed Test Results in Change Request

**Navigate to**: System Definition → Tables → Change Request

**Form Layout**:

Add new Related List section:

| Field | Value |
|-------|-------|
| Name | Test Results |
| Table | Test Result [sn_devops_test_result] |
| Filter | Commit SHA = Change Request.Commit SHA |

Add new Related List section:

| Field | Value |
|-------|-------|
| Name | Code Coverage |
| Table | Code Coverage [u_code_coverage] |
| Filter | Commit SHA = Change Request.Commit SHA |

**Add Calculated Field**:

Navigate to: **Change Request → Form Design**

Add Calculated Field:

| Field | Value |
|-------|-------|
| Label | Test Pass Rate |
| Script | ```javascript<br>var gr = new GlideAggregate('sn_devops_test_result');<br>gr.addQuery('commit_sha', current.u_commit_sha);<br>gr.addAggregate('SUM', 'tests_passed');<br>gr.addAggregate('SUM', 'tests_total');<br>gr.query();<br>if (gr.next()) {<br>  var passed = gr.getAggregate('SUM', 'tests_passed');<br>  var total = gr.getAggregate('SUM', 'tests_total');<br>  answer = (passed / total * 100).toFixed(2) + '%';<br>}<br>``` |

---

## Step 7: Quality Gate Automation

### Create Business Rule: Block Deployment if Tests Failed

**Navigate to**: System Definition → Business Rules

Click **New**:

| Field | Value |
|-------|-------|
| Name | Quality Gate: Block if Tests Failed |
| Table | Change Request |
| When | before |
| Insert | false |
| Update | true |
| Active | true |

**Condition**:
```javascript
current.state.changes() && current.state == 'implement' && current.u_environment == 'prod'
```

**Script**:
```javascript
(function executeRule(current, previous /*null when async*/) {
  // Get test results for this change request
  var gr = new GlideAggregate('sn_devops_test_result');
  gr.addQuery('commit_sha', current.u_commit_sha);
  gr.addAggregate('SUM', 'tests_failed');
  gr.query();

  if (gr.next()) {
    var failedCount = parseInt(gr.getAggregate('SUM', 'tests_failed') || 0);

    if (failedCount > 0) {
      gs.addErrorMessage('Cannot deploy to production: ' + failedCount + ' test(s) failed. Fix tests before deployment.');
      current.setAbortAction(true);
      return;
    }
  }

  // Check code coverage
  var covGr = new GlideAggregate('u_code_coverage');
  covGr.addQuery('commit_sha', current.u_commit_sha);
  covGr.addAggregate('AVG', 'u_coverage_percent');
  covGr.query();

  if (covGr.next()) {
    var avgCoverage = parseFloat(covGr.getAggregate('AVG', 'u_coverage_percent') || 0);

    if (avgCoverage < 70) {
      gs.addInfoMessage('Warning: Code coverage is ' + avgCoverage.toFixed(2) + '% (target: 80%)');
    }
  }

})(current, previous);
```

---

## Dashboard Examples

### Example 1: Test Quality Dashboard (Home Page)

```
┌─────────────────────────────────────────────────────────────────┐
│  Test Quality Dashboard                          [Refresh] [⋮]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 KPIs                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐│
│  │ Test Pass Rate  │  │ Code Coverage   │  │ Failed Tests     ││
│  │    98.5% ✅     │  │     82% ✅      │  │      3 ⚠️        ││
│  │  Goal: 95%      │  │   Goal: 80%     │  │   Goal: 0        ││
│  └─────────────────┘  └─────────────────┘  └──────────────────┘│
│                                                                  │
│  📈 Test Pass Rate Trend (Last 30 Days)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │     100%  ●─●─●───●─●─●─●                                  │ │
│  │      95%  ─────────────●───●                                │ │
│  │      90%                                                    │ │
│  │           [............Last 30 days............]            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  📊 Code Coverage by Service                                    │
│  frontend        ████████████████████ 85%                       │
│  cartservice     ███████████████ 75%                            │
│  checkoutservice ██████████████████ 80%                         │
│  adservice       ██████████████████████ 90%                     │
│                                                                  │
│  🚨 Recent Test Failures                                        │
│  - cartservice: 2 failures (2024-10-27)                        │
│  - frontend: 1 failure (2024-10-26)                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Dashboard Design
- ✅ Keep dashboards focused on specific audiences
- ✅ Use color coding (green = good, red = bad)
- ✅ Update frequency: Real-time or every 15 minutes
- ✅ Limit to 6-8 visualizations per dashboard

### 2. Report Scheduling
- ✅ Daily reports: Send early morning (8 AM)
- ✅ Weekly summaries: Monday morning
- ✅ Alert reports: Immediate on threshold breach

### 3. KPI Thresholds
- ✅ Test pass rate: >= 95% (green), 90-95% (yellow), < 90% (red)
- ✅ Code coverage: >= 80% (green), 70-80% (yellow), < 70% (red)
- ✅ Failed tests: 0 (green), 1-3 (yellow), > 3 (red)

### 4. Data Retention
- ✅ Test results: Keep 90 days
- ✅ Coverage data: Keep 1 year
- ✅ Aggregated metrics: Keep indefinitely

---

## Troubleshooting

### Dashboard Not Showing Data

**Symptom**: Dashboard is blank or shows "No data available"

**Solutions**:
1. Verify test results are being uploaded from GitHub Actions
2. Check table permissions (user can read sn_devops_test_result)
3. Review report conditions (date range might be too restrictive)
4. Check ServiceNow instance timezone settings

---

### Coverage Data Not Appearing

**Symptom**: Coverage reports empty despite tests running

**Solutions**:
1. Verify u_code_coverage table exists
2. Check coverage upload script runs successfully in GitHub Actions
3. Review coverage.xml file format (must be Cobertura format)
4. Check API permissions for table write access

---

### Quality Gate Not Blocking Deployments

**Symptom**: Business rule allows deployment despite failed tests

**Solutions**:
1. Verify business rule is active
2. Check commit SHA field is populated in change request
3. Review business rule condition (state == 'implement')
4. Check test results are linked to correct commit SHA

---

## Related Documentation

- [ServiceNow Test Integration](SERVICENOW-TEST-INTEGRATION.md)
- [Code Coverage Upload Script](../scripts/upload-coverage-to-servicenow.sh)
- [Build Workflow](../.github/workflows/build-images.yaml)
- [ServiceNow DevOps Integration](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)

---

**Last Updated**: 2025-10-28
**Maintained By**: DevOps Team
