# ServiceNow Security Scanning Verification Guide

> Step-by-step guide for verifying security scan results in ServiceNow CMDB

**Last Updated**: 2025-10-16
**Purpose**: Verify that security scanning workflows successfully upload results to ServiceNow
**Estimated Time**: 15-20 minutes

---

## Prerequisites

Before starting verification, ensure:

1. ✅ **ServiceNow tables created** via onboarding script ([SN_onboarding_Github.sh](../scripts/SN_onboarding_Github.sh))
   - `u_security_scan_result` table exists
   - `u_security_scan_summary` table exists

2. ✅ **GitHub Secrets configured**:
   ```bash
   gh secret list | grep SERVICENOW
   ```
   Should show:
   - `SERVICENOW_INSTANCE_URL`
   - `SERVICENOW_USERNAME`
   - `SERVICENOW_PASSWORD`

3. ✅ **Scripts are executable**:
   ```bash
   ls -l scripts/aggregate-security-results.sh scripts/upload-security-to-servicenow.sh
   ```
   Both should have `x` (executable) permission

---

## Step 1: Create ServiceNow Security Tables

If you haven't run the onboarding script yet, you need to manually create the security tables.

### 1.1 Create u_security_scan_result Table

1. **Navigate to**: System Definition → Tables → New

2. **Fill in**:
   - **Label**: `Security Scan Result`
   - **Name**: `u_security_scan_result`
   - **Extends table**: Base Table (or Task)
   - **Application**: Global
   - **Create access controls**: ✓
   - **Add module to menu**: ✓

3. **Click Submit**

4. **Add Custom Fields**:

Navigate to: System Definition → Tables → Search for "u_security_scan_result" → Click on table → Columns tab → New

Create these fields:

| Field Name | Type | Length | Mandatory | Default | Choices |
|------------|------|--------|-----------|---------|---------|
| u_scan_id | String | 100 | Yes | - | - |
| u_scan_type | Choice | - | Yes | - | CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP |
| u_scan_date | Date/Time | - | Yes | - | - |
| u_finding_id | String | 255 | Yes | - | - |
| u_severity | Choice | - | Yes | Open | CRITICAL, HIGH, MEDIUM, LOW, INFO |
| u_title | String | 255 | Yes | - | - |
| u_description | Text | 4000 | No | - | - |
| u_file_path | String | 512 | No | - | - |
| u_line_number | Integer | - | No | - | - |
| u_rule_id | String | 255 | No | - | - |
| u_cve_id | String | 100 | No | - | - |
| u_cvss_score | Decimal | - | No | - | - |
| u_status | Choice | - | Yes | Open | Open, In Progress, Resolved, False Positive |
| u_repository | String | 255 | Yes | - | - |
| u_branch | String | 100 | Yes | - | - |
| u_commit_sha | String | 40 | Yes | - | - |
| u_github_url | URL | 1024 | No | - | - |
| u_sarif_data | JSON | - | No | - | - |

### 1.2 Create u_security_scan_summary Table

1. **Navigate to**: System Definition → Tables → New

2. **Fill in**:
   - **Label**: `Security Scan Summary`
   - **Name**: `u_security_scan_summary`
   - **Extends table**: Base Table
   - **Application**: Global
   - **Create access controls**: ✓
   - **Add module to menu**: ✓

3. **Click Submit**

4. **Add Custom Fields**:

| Field Name | Type | Length | Mandatory | Default | Choices |
|------------|------|--------|-----------|---------|---------|
| u_scan_id | String | 100 | Yes | - | - |
| u_workflow_run_id | String | 100 | No | - | - |
| u_repository | String | 255 | Yes | - | - |
| u_branch | String | 100 | Yes | - | - |
| u_commit_sha | String | 40 | Yes | - | - |
| u_scan_date | Date/Time | - | Yes | - | - |
| u_total_findings | Integer | - | Yes | 0 | - |
| u_critical_count | Integer | - | No | 0 | - |
| u_high_count | Integer | - | No | 0 | - |
| u_medium_count | Integer | - | No | 0 | - |
| u_low_count | Integer | - | No | 0 | - |
| u_info_count | Integer | - | No | 0 | - |
| u_tools_run | String | 512 | No | - | - |
| u_status | Choice | - | Yes | Success | Success, Failed, In Progress |
| u_github_url | URL | 1024 | No | - | - |

---

## Step 2: Verify Table Creation

### 2.1 Check Tables Exist via API

```bash
# Set your ServiceNow credentials
SERVICENOW_INSTANCE_URL="https://yourinstance.service-now.com"
SERVICENOW_USERNAME="github_integration"
SERVICENOW_PASSWORD="your_password"

# Test u_security_scan_result table
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=1" \
  | jq -r '.result'

# Test u_security_scan_summary table
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_limit=1" \
  | jq -r '.result'
```

**Expected**: Both commands should return HTTP 200 and an empty result array `[]`

### 2.2 Verify in ServiceNow UI

Navigate to:
- Security Scan Results: `${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do`
- Security Scan Summaries: `${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do`

Both tables should be empty initially.

---

## Step 3: Trigger Security Scanning Workflow

### 3.1 Manual Workflow Trigger

```bash
# Trigger the security scanning workflow
gh workflow run security-scan-servicenow.yaml

# Wait 2-3 minutes for workflow to start
sleep 120

# Check workflow status
gh run list --workflow=security-scan-servicenow.yaml --limit 1
```

### 3.2 Monitor Workflow Execution

```bash
# Get the latest run ID
RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId')

# Watch the workflow execution
gh run watch $RUN_ID

# Alternative: view in browser
gh run view $RUN_ID --web
```

**Expected Workflow Steps**:
1. ✅ CodeQL Analysis (Python, JavaScript, Go, Java, C#)
2. ✅ Semgrep Scan
3. ✅ Trivy Filesystem Scan
4. ✅ IaC Security (Checkov, tfsec)
5. ✅ Kubernetes Manifest Scan (Kubesec, Polaris)
6. ✅ OWASP Dependency Check
7. ✅ Security Summary
8. ✅ **Upload to ServiceNow** ← This is the critical step

---

## Step 4: Verify Security Results Upload

### 4.1 Check Workflow Logs

```bash
# View the upload-to-servicenow job logs
gh run view $RUN_ID --log --job "Upload to ServiceNow"
```

**Look for these success indicators**:
```
[INFO] Starting ServiceNow security upload...
[SUCCESS] All prerequisites met
[SUCCESS] ServiceNow connectivity verified
[SUCCESS] Table 'u_security_scan_result' verified
[SUCCESS] Table 'u_security_scan_summary' verified
[SUCCESS] Summary uploaded successfully (sys_id: ...)
[INFO] Upload complete:
[SUCCESS]   - Created: XX
[SUCCESS]   - Updated: XX
[SUCCESS] Upload completed successfully!
```

### 4.2 Check for Errors

If the upload fails, look for:
- `[ERROR] SERVICENOW_INSTANCE_URL not set` → Check GitHub secrets
- `[ERROR] Authentication failed` → Verify username/password
- `[ERROR] Table 'u_security_scan_result' not accessible` → Create the table
- `HTTP 403` → Check user permissions (needs admin role)
- `HTTP 404` → Table doesn't exist

---

## Step 5: Verify Results in ServiceNow

### 5.1 Check Summary Record

Navigate to: `${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do`

You should see a new record with:
- **Scan ID**: Matches GitHub workflow run ID
- **Repository**: `Freundcloud/microservices-demo`
- **Branch**: `main`
- **Total Findings**: Count of all security findings
- **Severity Counts**: Breakdown by CRITICAL/HIGH/MEDIUM/LOW/INFO
- **Tools Run**: Comma-separated list of tools executed
- **Status**: `Success`
- **GitHub URL**: Link to workflow run

### 5.2 Check Individual Findings

Navigate to: `${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do`

You should see multiple records, one for each security finding:

**Example Finding Record**:
- **Finding ID**: `a1b2c3d4e5f6...` (MD5 hash)
- **Scan Type**: `CodeQL` or `Trivy` or `Checkov`, etc.
- **Severity**: `HIGH`
- **Title**: "SQL Injection vulnerability in user input"
- **File Path**: `src/frontend/handlers.go`
- **Line Number**: `142`
- **Rule ID**: `go/sql-injection`
- **Status**: `Open`
- **Repository**: `Freundcloud/microservices-demo`
- **Commit SHA**: `abc123...`

### 5.3 Filter Results by Scan

To view results for a specific scan run:

1. Go to Security Scan Results list
2. Add filter: `Scan ID` = `<workflow_run_id>`
3. Apply

Or use this direct URL:
```
${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do?sysparm_query=u_scan_id=<run_id>
```

### 5.4 Filter by Severity

To view critical/high severity findings:

1. Go to Security Scan Results list
2. Add filter: `Severity` = `CRITICAL` OR `Severity` = `HIGH`
3. Apply

Or use direct URL:
```
${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do?sysparm_query=u_severity=CRITICAL^ORu_severity=HIGH
```

---

## Step 6: Verify via API

### 6.1 Query Summary via API

```bash
RUN_ID="<your_workflow_run_id>"

curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_query=u_scan_id=${RUN_ID}" \
  | jq -r '.result[] | {scan_id: .u_scan_id, total: .u_total_findings, critical: .u_critical_count, high: .u_high_count, tools: .u_tools_run}'
```

**Expected Output**:
```json
{
  "scan_id": "12345678",
  "total": "42",
  "critical": "3",
  "high": "12",
  "tools": "CodeQL, Semgrep, Trivy, Checkov, tfsec"
}
```

### 6.2 Query Findings via API

```bash
# Get all HIGH severity findings
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_query=u_severity=HIGH&sysparm_limit=10" \
  | jq -r '.result[] | {tool: .u_scan_type, severity: .u_severity, title: .u_title, file: .u_file_path, line: .u_line_number}'
```

### 6.3 Query by Tool

```bash
# Get all CodeQL findings
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_query=u_scan_type=CodeQL" \
  | jq -r '.result | length'
```

---

## Step 7: Test Finding Deduplication

### 7.1 Trigger Workflow Again

```bash
# Trigger the same workflow again
gh workflow run security-scan-servicenow.yaml

# Wait for completion
sleep 300

# Check the new run
gh run list --workflow=security-scan-servicenow.yaml --limit 2
```

### 7.2 Verify Deduplication

Check the upload logs for the second run:

```bash
NEW_RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view $NEW_RUN_ID --log --job "Upload to ServiceNow"
```

**Look for**:
```
[INFO] Upload complete:
[SUCCESS]   - Created: 0
[SUCCESS]   - Updated: XX
```

This means all findings already existed and were updated (only scan_id and scan_date changed).

### 7.3 Verify in ServiceNow

1. Go to Security Scan Results
2. Count total records (should be same as first run)
3. Filter by `Scan ID` for both runs
4. Same findings should appear in both scans (deduplication working)

---

## Step 8: Create ServiceNow Dashboards (Optional)

### 8.1 Create Security Overview Dashboard

1. Navigate to: Performance Analytics → Dashboards → New

2. Create widgets:

**Widget 1: Total Findings by Severity**
- Type: Pie Chart
- Table: u_security_scan_result
- Group by: u_severity
- Metric: Count

**Widget 2: Findings by Tool**
- Type: Bar Chart
- Table: u_security_scan_result
- Group by: u_scan_type
- Metric: Count

**Widget 3: Top 10 Vulnerable Files**
- Type: List
- Table: u_security_scan_result
- Group by: u_file_path
- Metric: Count
- Limit: 10

**Widget 4: Scan Summary Over Time**
- Type: Line Chart
- Table: u_security_scan_summary
- X-axis: u_scan_date
- Y-axis: u_total_findings

### 8.2 Create Reports

**Critical/High Severity Report**:
1. Navigate to: Reports → View/Run → New
2. Table: u_security_scan_result
3. Conditions: `u_severity IN (CRITICAL, HIGH)`
4. Columns: u_scan_type, u_title, u_file_path, u_line_number, u_severity
5. Save as: "Critical and High Security Findings"

---

## Troubleshooting

### Issue: No results uploaded to ServiceNow

**Possible Causes**:
1. **Tables don't exist**
   - Solution: Run onboarding script or manually create tables

2. **GitHub Secrets not configured**
   - Check: `gh secret list | grep SERVICENOW`
   - Solution: Add secrets via `gh secret set`

3. **Authentication failed**
   - Check credentials in `.github_sn_credentials`
   - Test: `curl -u "user:pass" "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1"`

4. **User lacks permissions**
   - Verify user has admin role
   - Check: Navigate to System Security → Users → github_integration → Roles

### Issue: Workflow fails at "Fetch security findings from GitHub API"

**Cause**: GITHUB_TOKEN lacks permissions

**Solution**: Ensure workflow has `security-events: read` permission (already configured in workflow)

### Issue: Aggregation script fails

**Check**:
```bash
# Verify SARIF files exist in workflow
gh run view $RUN_ID --log | grep "sarif"
```

**Solution**: Ensure security scanning tools completed successfully before aggregation

### Issue: Deduplication not working (duplicates created)

**Cause**: `finding_id` generation inconsistent

**Check**:
```bash
# View finding IDs in ServiceNow
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=5" \
  | jq -r '.result[] | .u_finding_id'
```

**Solution**: Ensure `aggregate-security-results.sh` generates consistent MD5 hashes

---

## Success Criteria

Your security scanning integration is working correctly if:

✅ **Workflow completes successfully**
- All security scanning jobs pass
- upload-to-servicenow job completes without errors

✅ **Summary record created**
- One summary record per workflow run
- Contains accurate severity counts
- Lists all tools that ran

✅ **Findings uploaded**
- All security findings from all tools present
- Correct severity mapping (SARIF → ServiceNow)
- File paths and line numbers accurate

✅ **Deduplication works**
- Re-running workflow doesn't create duplicates
- Existing findings updated with new scan_id

✅ **Data accessible**
- ServiceNow UI shows all records
- API queries return expected results
- Filters work correctly

✅ **Links functional**
- GitHub URLs in ServiceNow link to correct workflow runs
- Direct links from workflow summary to ServiceNow work

---

## Next Steps

After successful verification:

1. **Schedule Regular Scans**:
   - Workflow runs on PR and push to main
   - Can also schedule: Add `schedule:` trigger to workflow

2. **Create ServiceNow Integrations**:
   - Set up email notifications for CRITICAL findings
   - Create incident records for HIGH severity issues
   - Integrate with change management

3. **Monitor Trends**:
   - Track findings over time
   - Measure security posture improvement
   - Identify most vulnerable components

4. **Customize**:
   - Add custom fields to security tables
   - Create custom views and filters
   - Build security metrics dashboards

---

## Additional Resources

- **Design Documentation**: [SERVICENOW-SECURITY-SCANNING.md](SERVICENOW-SECURITY-SCANNING.md)
- **Aggregation Script**: [aggregate-security-results.sh](../scripts/aggregate-security-results.sh)
- **Upload Script**: [upload-security-to-servicenow.sh](../scripts/upload-security-to-servicenow.sh)
- **GitHub Workflow**: [security-scan-servicenow.yaml](../.github/workflows/security-scan-servicenow.yaml)
- **Onboarding Script**: [SN_onboarding_Github.sh](../scripts/SN_onboarding_Github.sh)

---

**Questions or Issues?**
- Check troubleshooting section above
- Review workflow logs: `gh run view $RUN_ID --log`
- Verify ServiceNow table structure
- Test API access manually with curl
