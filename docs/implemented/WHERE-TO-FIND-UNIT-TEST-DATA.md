# Where to Find Unit Test Data in ServiceNow

## Quick Answer

Your unit test data is stored in **custom fields on the Change Request record**, NOT in the ServiceNow DevOps plugin tables.

**Direct Link to View Your Test Data**:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request.do?sysparm_query=number=CHG0030349
```

Replace `CHG0030349` with your actual change request number.

---

## Why You Don't See Tests in DevOps Change View

The URL you're looking at:
```
https://calitiiltddemo3.service-now.com/now/devops-change/devops-list/...
```

This is the **ServiceNow DevOps plugin view**, which shows data from tables like:
- `sn_devops_test_result` - DevOps plugin test results table
- `sn_devops_change` - DevOps plugin change tracking

**We are NOT using the DevOps plugin tables**. Instead, we created **custom fields directly on the change_request table** for simpler integration.

---

## Where to Find Your Unit Test Data

### Option 1: View Change Request Record (Recommended)

**Steps**:
1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: **Change > All**
3. Search for your change request number (e.g., `CHG0030349`)
4. Click to open the change request
5. Scroll down to see custom fields section

**Custom Fields to Look For**:
- `u_unit_test_status` - passed/failed
- `u_unit_test_total` - Total tests (127)
- `u_unit_test_passed` - Passed tests (127)
- `u_unit_test_failed` - Failed tests (0)
- `u_unit_test_coverage` - Coverage % (85.2%)
- `u_unit_test_url` - Link to GitHub Actions run
- `u_sonarcloud_status` - passed/failed/warning
- `u_sonarcloud_bugs` - Bug count (7)
- `u_sonarcloud_vulnerabilities` - Vuln count (1)
- `u_sonarcloud_code_smells` - Code smell count (233)
- `u_sonarcloud_coverage` - Code coverage % (0.0%)
- `u_sonarcloud_duplications` - Duplication % (12.8%)
- `u_sonarcloud_url` - Link to SonarCloud dashboard

### Option 2: Create a Custom View

**Steps to Create a List View with Test Data**:

1. Go to: **Change > All**
2. Right-click the column headers → **Configure > List Layout**
3. Add the following fields to "Selected":
   - Number
   - Short Description
   - State
   - Unit Test Status (u_unit_test_status)
   - Unit Test Total (u_unit_test_total)
   - Unit Test Coverage (u_unit_test_coverage)
   - SonarCloud Status (u_sonarcloud_status)
   - SonarCloud Bugs (u_sonarcloud_bugs)
4. Click **Save**

Now you'll see all test data in the change request list view!

### Option 3: Query via API

```bash
# Get latest change request with test data
curl -s -u "$USER:$PASS" \
  "$INSTANCE/api/now/table/change_request?sysparm_query=short_descriptionLIKEDeploy microservices&sysparm_limit=1&sysparm_query=ORDERBYDESCsys_created_on&sysparm_fields=number,u_unit_test_status,u_unit_test_total,u_sonarcloud_status,u_sonarcloud_bugs" \
  | jq ".result[0]"
```

**Example Output**:
```json
{
  "number": "CHG0030349",
  "u_unit_test_status": "passed",
  "u_unit_test_total": "127",
  "u_sonarcloud_status": "failed",
  "u_sonarcloud_bugs": "7"
}
```

### Option 4: Create a Dashboard Widget

**Steps**:
1. Go to: **Self-Service > Dashboards**
2. Create new dashboard or edit existing
3. Add widget: **List**
4. Configure widget:
   - Table: `change_request`
   - Filter: `short_description LIKE Deploy microservices`
   - Columns: Include custom test fields
5. Save dashboard

---

## Understanding the Data Architecture

### What We Implemented (Current)

**Architecture**: Custom fields on `change_request` table

**Pros**:
- ✅ Simple implementation
- ✅ All data in one place (change request record)
- ✅ Easy to query and report
- ✅ No additional plugin dependencies
- ✅ Works with standard Change Management process

**Cons**:
- ❌ Not visible in DevOps plugin views
- ❌ Doesn't integrate with DevOps plugin features
- ❌ Need custom views/reports to visualize

### Alternative: ServiceNow DevOps Plugin (Not Implemented)

**Architecture**: Using `sn_devops_test_result` and `sn_devops_change` tables

**Pros**:
- ✅ Out-of-box DevOps Change views
- ✅ Built-in test result visualization
- ✅ Integration with DevOps pipeline tracking
- ✅ Advanced analytics and insights

**Cons**:
- ❌ Requires ServiceNow DevOps plugin license
- ❌ More complex integration
- ❌ Requires ServiceNow DevOps actions in workflows
- ❌ Steeper learning curve

---

## How to Switch to DevOps Plugin Tables (Optional)

If you want your test data to appear in the DevOps Change view, you need to:

### 1. Use ServiceNow DevOps GitHub Actions

Replace current workflows with official DevOps plugin actions:

**Current** (custom REST API):
```yaml
- name: Create Change Request via REST API
  run: |
    curl -X POST \
      -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
      "$SERVICENOW_INSTANCE_URL/api/now/table/change_request" \
      -d "$PAYLOAD"
```

**DevOps Plugin** (official action):
```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v4.0.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

### 2. Register Test Results with DevOps Plugin

```yaml
- name: ServiceNow DevOps Test Results
  uses: ServiceNow/servicenow-devops-test-report@v3.1.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Unit Tests'
    xml-report-filename: test-results.xml
```

### 3. Plugin Configuration

You'd need to:
1. Install/activate ServiceNow DevOps plugin
2. Configure GitHub integration in ServiceNow
3. Create DevOps integration user
4. Generate integration token
5. Configure tool registration

**Documentation**: See `docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md` for full setup guide.

---

## Current Implementation Summary

**What We Have**:
- ✅ 13 custom fields on `change_request` table
- ✅ Populated with actual test data from workflows
- ✅ Visible on change request form
- ✅ Queryable via API
- ✅ Can be added to list views and reports

**What We DON'T Have**:
- ❌ Integration with DevOps plugin views (like the URL you shared)
- ❌ Test results in `sn_devops_test_result` table
- ❌ Built-in DevOps analytics dashboards

---

## Recommended Next Steps

### For Quick Wins (No Code Changes)

1. **Create custom list view**:
   - Go to Change > All
   - Configure columns to show test fields
   - Save view as "Deployment Changes with Test Data"

2. **Create dashboard widget**:
   - Add list widget showing changes with test data
   - Filter to show only deployment changes
   - Display key test metrics

3. **Create report**:
   - Report on test pass/fail rates
   - Track SonarCloud quality over time
   - Show changes with failed tests

### For Long-Term (Code Changes)

If you want full DevOps plugin integration:
1. Review `docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md`
2. Decide if DevOps plugin license is worth the cost
3. Plan migration from custom fields to DevOps plugin tables
4. Update workflows to use official ServiceNow actions

---

## Quick Reference URLs

**View Change Request**:
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=short_descriptionLIKEDeploy microservices
```

**View Custom Fields Schema**:
```
https://calitiiltddemo3.service-now.com/sys_dictionary_list.do?sysparm_query=name=change_request^elementSTARTSWITHu_unit_test
```

**API Query Example**:
```bash
curl -s -u "$USER:$PASS" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=number=CHG0030349" \
  | jq ".result[0] | {number, u_unit_test_status, u_sonarcloud_status}"
```

---

## Support

- **Custom Fields Documentation**: `docs/SERVICENOW-CUSTOM-FIELDS-SETUP.md`
- **Integration Guide**: `docs/SERVICENOW-TEST-RESULTS-INTEGRATION.md`
- **Data Inventory**: `docs/SERVICENOW-DATA-INVENTORY.md`
- **GitHub Spoke Setup**: `docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md`
