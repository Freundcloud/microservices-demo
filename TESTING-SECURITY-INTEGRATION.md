# Testing Security Scanning Integration - Quick Reference

> Step-by-step testing guide for ServiceNow security scanning integration

**Status**: Ready for testing
**Estimated Time**: 30-40 minutes
**Prerequisites**: ServiceNow credentials (github_integration user)

---

## 📋 Quick Testing Checklist

- [ ] Step 1: Test ServiceNow connectivity
- [ ] Step 2: Create security tables (if needed)
- [ ] Step 3: Verify table creation
- [ ] Step 4: Trigger security scan workflow
- [ ] Step 5: Monitor workflow execution
- [ ] Step 6: Verify results in ServiceNow
- [ ] Step 7: Test deduplication
- [ ] Step 8: Create dashboards (optional)

---

## Step 1: Test ServiceNow Connectivity

Run the connectivity test script:

```bash
cd /home/olafkfreund/Source/Calitti/ARC/microservices-demo

# Run test (will prompt for credentials)
bash scripts/test-servicenow-connectivity.sh
```

**What it checks:**
- ✓ Basic ServiceNow API connectivity
- ✓ Existing tables (u_eks_cluster, u_microservice)
- ✓ Security tables (u_security_scan_result, u_security_scan_summary)
- ✓ Write permissions

**Expected Output:**
```
[SUCCESS] ✓ Basic connectivity working (HTTP 200)
[SUCCESS] ✓ u_eks_cluster table exists
[SUCCESS] ✓ u_microservice table exists
[ERROR] ✗ u_security_scan_result table NOT FOUND (HTTP 404)
[ERROR] ✗ u_security_scan_summary table NOT FOUND (HTTP 404)
```

If security tables are **missing**, proceed to Step 2.
If security tables **exist**, skip to Step 4.

---

## Step 2: Create Security Tables

You have two options:

### Option A: Run Onboarding Script (Recommended)

```bash
bash scripts/SN_onboarding_Github.sh
```

This will:
1. Prompt for ServiceNow credentials
2. Test connectivity
3. Guide you through manual table creation in ServiceNow UI
4. Verify all tables are accessible
5. Test API access

**Follow the on-screen instructions carefully.**

### Option B: Manual Creation via ServiceNow UI

Follow detailed instructions in:
```bash
cat docs/SERVICENOW-SECURITY-VERIFICATION.md | less
# Jump to "Step 1: Create ServiceNow Security Tables"
```

**Manual steps summary:**

**Create u_security_scan_result table:**
1. Navigate to: **System Definition → Tables → New**
2. Fill in:
   - Label: `Security Scan Result`
   - Name: `u_security_scan_result`
   - Extends table: `Base Table`
3. Click Submit
4. Add **18 custom fields** (see verification guide for complete list)

**Create u_security_scan_summary table:**
1. Navigate to: **System Definition → Tables → New**
2. Fill in:
   - Label: `Security Scan Summary`
   - Name: `u_security_scan_summary`
   - Extends table: `Base Table`
3. Click Submit
4. Add **15 custom fields** (see verification guide for complete list)

**Field Creation Quick Reference:**

For **u_security_scan_result** (18 fields):
- Core: u_scan_id, u_scan_type, u_scan_date, u_finding_id
- Details: u_severity, u_title, u_description, u_file_path, u_line_number, u_rule_id
- Vuln: u_cve_id, u_cvss_score, u_status
- Meta: u_repository, u_branch, u_commit_sha, u_github_url, u_sarif_data

For **u_security_scan_summary** (15 fields):
- ID: u_scan_id, u_workflow_run_id, u_repository, u_branch, u_commit_sha
- Stats: u_scan_date, u_total_findings, u_critical_count, u_high_count, u_medium_count, u_low_count, u_info_count
- Meta: u_tools_run, u_status, u_github_url

**Full field specifications:** See `docs/SERVICENOW-SECURITY-VERIFICATION.md` Section 1.1 and 1.2

---

## Step 3: Verify Table Creation

Re-run the connectivity test:

```bash
bash scripts/test-servicenow-connectivity.sh
```

**Expected Output (if tables exist):**
```
[SUCCESS] ✓ u_security_scan_result table exists
  Records: 0
[SUCCESS] ✓ u_security_scan_summary table exists
  Records: 0
[SUCCESS] ✓ Write permissions working (HTTP 201)

════════════════════════════════════════════════════════════════
                    CONNECTIVITY TEST SUMMARY
════════════════════════════════════════════════════════════════

[SUCCESS] ✓ All security tables exist - READY FOR TESTING!
```

If you see errors, review table creation and field configuration.

---

## Step 4: Trigger Security Scan Workflow

Trigger the workflow via GitHub CLI:

```bash
# Trigger workflow
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo

# Wait a few seconds for workflow to start
sleep 5

# Get the run ID
RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)

echo "Workflow Run ID: $RUN_ID"
```

**Alternative: Trigger via GitHub UI**
1. Go to: https://github.com/Freundcloud/microservices-demo/actions/workflows/security-scan-servicenow.yaml
2. Click **"Run workflow"**
3. Select branch: `main`
4. Click **"Run workflow"**

---

## Step 5: Monitor Workflow Execution

Watch the workflow in real-time:

```bash
# Watch workflow progress
gh run watch $RUN_ID --repo Freundcloud/microservices-demo

# Or view in browser
gh run view $RUN_ID --web --repo Freundcloud/microservices-demo
```

**Expected Workflow Steps** (8-12 minutes total):
1. ✓ CodeQL Analysis (Python, JavaScript, Go, Java, C#) - ~4 min
2. ✓ Semgrep Scan - ~1 min
3. ✓ Trivy Filesystem Scan - ~1 min
4. ✓ IaC Security Scan (Checkov, tfsec) - ~2 min
5. ✓ Kubernetes Manifest Scan (Kubesec, Polaris) - ~1 min
6. ✓ OWASP Dependency Check - ~3 min
7. ✓ Security Summary - ~10 sec
8. ✓ **Upload to ServiceNow** - ~30 sec ← **CRITICAL STEP**

**Monitor the Upload Job:**

```bash
# View upload job logs
gh run view $RUN_ID --log --job "Upload to ServiceNow" --repo Freundcloud/microservices-demo
```

**Look for Success Indicators:**
```
[INFO] Starting ServiceNow security upload...
[SUCCESS] All prerequisites met
[SUCCESS] ServiceNow connectivity verified
[SUCCESS] Table 'u_security_scan_result' verified
[SUCCESS] Table 'u_security_scan_summary' verified
[SUCCESS] Summary uploaded successfully (sys_id: ...)
[INFO] Upload complete:
[SUCCESS]   - Created: XX
[SUCCESS]   - Updated: 0
[SUCCESS] Upload completed successfully!
```

**If you see errors:**
- Check the "Troubleshooting" section below
- Review workflow logs for specific error messages
- Verify table creation and API access

---

## Step 6: Verify Results in ServiceNow

### 6.1 Check Summary Record

Navigate to ServiceNow:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_summary_list.do
```

**Expected: 1 new record with:**
- Scan ID: `<workflow_run_id>`
- Repository: `Freundcloud/microservices-demo`
- Branch: `main`
- Total Findings: `XX` (varies by scan results)
- Critical Count, High Count, Medium Count, Low Count: `XX`
- Tools Run: `CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP`
- Status: `Success`
- GitHub URL: Link to workflow run

### 6.2 Check Individual Findings

Navigate to:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_result_list.do
```

**Expected: Multiple records (100+) with:**
- Finding ID: Unique hash
- Scan Type: Tool name
- Severity: CRITICAL/HIGH/MEDIUM/LOW/INFO
- Title: Finding description
- File Path: Source file location
- Line Number: Line in file
- Rule ID: Security rule identifier
- Status: Open

### 6.3 Filter Results

**View findings for this specific scan:**
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_result_list.do?sysparm_query=u_scan_id=$RUN_ID
```

**View only CRITICAL and HIGH severity:**
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_result_list.do?sysparm_query=u_severity=CRITICAL^ORu_severity=HIGH
```

**View findings by tool (e.g., CodeQL):**
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_result_list.do?sysparm_query=u_scan_type=CodeQL
```

### 6.4 Verify via API

```bash
# Set credentials
SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
SERVICENOW_USERNAME="github_integration"
read -sp "Password: " SERVICENOW_PASSWORD
echo

# Query summary
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_summary?sysparm_query=u_scan_id=${RUN_ID}" \
  | jq -r '.result[] | {scan_id: .u_scan_id, total: .u_total_findings, critical: .u_critical_count, high: .u_high_count, medium: .u_medium_count, low: .u_low_count, tools: .u_tools_run}'

# Query findings count
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_query=u_scan_id=${RUN_ID}" \
  | jq -r '.result | length'

# Query HIGH severity findings
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_query=u_severity=HIGH&sysparm_limit=5" \
  | jq -r '.result[] | {tool: .u_scan_type, severity: .u_severity, title: .u_title, file: .u_file_path}'
```

---

## Step 7: Test Deduplication

Re-run the workflow to verify deduplication works:

```bash
# Trigger workflow again
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo

# Wait for it to start
sleep 5

# Get new run ID
NEW_RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)

# Watch execution
gh run watch $NEW_RUN_ID --repo Freundcloud/microservices-demo
```

**Check Upload Logs:**

```bash
gh run view $NEW_RUN_ID --log --job "Upload to ServiceNow" --repo Freundcloud/microservices-demo
```

**Expected Output (deduplication working):**
```
[INFO] Upload complete:
[SUCCESS]   - Created: 0        ← No new findings
[SUCCESS]   - Updated: XX       ← All findings updated
```

**Verify in ServiceNow:**
1. Total finding count should be **same as first run**
2. Each finding should appear in **both scans** (filter by scan_id)
3. Only `u_scan_id` and `u_scan_date` should change

---

## Step 8: Create ServiceNow Dashboards (Optional)

### Dashboard 1: Security Overview

1. Navigate to: **Performance Analytics → Dashboards → New**
2. Name: `Security Scan Overview`
3. Add widgets:

**Widget 1: Findings by Severity (Pie Chart)**
- Table: `u_security_scan_result`
- Group by: `u_severity`
- Metric: Count

**Widget 2: Findings by Tool (Bar Chart)**
- Table: `u_security_scan_result`
- Group by: `u_scan_type`
- Metric: Count

**Widget 3: Top 10 Vulnerable Files (List)**
- Table: `u_security_scan_result`
- Group by: `u_file_path`
- Metric: Count
- Limit: 10

**Widget 4: Scan Trend (Line Chart)**
- Table: `u_security_scan_summary`
- X-axis: `u_scan_date`
- Y-axis: `u_total_findings`

### Report 1: Critical/High Findings

1. Navigate to: **Reports → View/Run → New**
2. Table: `u_security_scan_result`
3. Conditions: `u_severity IN (CRITICAL, HIGH)`
4. Columns: `u_scan_type`, `u_title`, `u_file_path`, `u_line_number`, `u_severity`
5. Save as: `Critical and High Security Findings`

---

## 🐛 Troubleshooting

### Issue: Workflow fails at "Upload to ServiceNow"

**Check logs:**
```bash
gh run view $RUN_ID --log --job "Upload to ServiceNow" --repo Freundcloud/microservices-demo
```

**Common errors:**

**Error: `Table 'u_security_scan_result' not accessible`**
- **Cause**: Table doesn't exist or wrong name
- **Solution**: Verify table creation in ServiceNow UI, check exact table name

**Error: `Authentication failed`**
- **Cause**: Wrong credentials in GitHub secrets
- **Solution**: Verify secrets: `gh secret list --repo Freundcloud/microservices-demo | grep SERVICENOW`

**Error: `HTTP 403 Forbidden`**
- **Cause**: User lacks permissions
- **Solution**: Verify `github_integration` user has admin role in ServiceNow

**Error: `No SARIF files found`**
- **Cause**: Security scan jobs failed
- **Solution**: Check earlier workflow steps, ensure security tools completed successfully

### Issue: No findings uploaded

**Verify aggregation step:**
```bash
gh run view $RUN_ID --log --job "Aggregate Security Results" --repo Freundcloud/microservices-demo
```

**Check if SARIF files exist:**
```bash
# Download workflow artifacts
gh run download $RUN_ID --repo Freundcloud/microservices-demo

# Check for aggregated results
ls -la aggregated-security-results.json security-scan-summary.json 2>/dev/null
```

### Issue: Deduplication not working (duplicates created)

**Check finding_id generation:**
```bash
# Query finding IDs from ServiceNow
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result?sysparm_limit=5" \
  | jq -r '.result[] | .u_finding_id'
```

**Verify MD5 hashes are consistent** across runs for same findings.

---

## ✅ Success Criteria

Your integration is working correctly if:

✅ **Workflow completes** without errors
✅ **Upload job succeeds** with "Created: XX" message
✅ **Summary record** created with accurate counts
✅ **Finding records** populated with details
✅ **Deduplication works** (second run shows "Updated: XX, Created: 0")
✅ **Links work** from ServiceNow to GitHub
✅ **Filters work** in ServiceNow UI
✅ **API queries** return expected data

---

## 📚 Additional Resources

**Complete Documentation:**
- [SERVICENOW-IMPLEMENTATION-STATUS.md](docs/SERVICENOW-IMPLEMENTATION-STATUS.md) - Overall status
- [SERVICENOW-SECURITY-SCANNING.md](docs/SERVICENOW-SECURITY-SCANNING.md) - Design docs
- [SERVICENOW-SECURITY-VERIFICATION.md](docs/SERVICENOW-SECURITY-VERIFICATION.md) - Detailed testing guide

**Scripts:**
- [aggregate-security-results.sh](scripts/aggregate-security-results.sh) - SARIF processing
- [upload-security-to-servicenow.sh](scripts/upload-security-to-servicenow.sh) - Upload logic
- [test-servicenow-connectivity.sh](scripts/test-servicenow-connectivity.sh) - Connectivity test

**Workflow:**
- [security-scan-servicenow.yaml](.github/workflows/security-scan-servicenow.yaml) - Complete workflow

---

## 🎯 Quick Commands Summary

```bash
# Test connectivity
bash scripts/test-servicenow-connectivity.sh

# Trigger workflow
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo

# Get run ID
RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)

# Watch workflow
gh run watch $RUN_ID --repo Freundcloud/microservices-demo

# View upload logs
gh run view $RUN_ID --log --job "Upload to ServiceNow" --repo Freundcloud/microservices-demo

# Check ServiceNow summary
open "https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_summary_list.do"

# Check ServiceNow findings
open "https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_security_scan_result_list.do"
```

---

**Ready to start testing!** Begin with Step 1 and work through each step sequentially.
