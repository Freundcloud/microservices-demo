# Create ServiceNow Security Tables - 5 Minute Guide

**Time Required**: 5 minutes
**ServiceNow Instance**: https://calitiiltddemo3.service-now.com

---

## Table 1: u_security_scan_result (3 minutes)

### Step 1: Create the Table (30 seconds)

1. **Open**: https://calitiiltddemo3.service-now.com/sys_db_object.do?sys_id=-1
2. **Fill in**:
   - **Label**: `Security Scan Result`
   - **Name**: `u_security_scan_result`
   - **Extends table**: Leave blank or select "Base Table"
   - Check: ✓ **Create module**
   - Check: ✓ **Add module to menu**
3. **Click**: Submit button (bottom right)

### Step 2: Add Fields (2.5 minutes)

After clicking Submit, you'll be on the table details page. Click the **Columns** tab, then click **New** for each field:

**Quick Copy-Paste Fields** (18 fields):

```
Field 1:
Column label: Scan ID
Column name: u_scan_id
Type: String
Max length: 100
Mandatory: ✓

Field 2:
Column label: Scan Type
Column name: u_scan_type
Type: Choice
Mandatory: ✓
(After creating, add choices: CodeQL, Semgrep, Trivy, Checkov, tfsec, Kubesec, Polaris, OWASP)

Field 3:
Column label: Scan Date
Column name: u_scan_date
Type: Date/Time
Mandatory: ✓

Field 4:
Column label: Finding ID
Column name: u_finding_id
Type: String
Max length: 255
Mandatory: ✓

Field 5:
Column label: Severity
Column name: u_severity
Type: Choice
Mandatory: ✓
(After creating, add choices: CRITICAL, HIGH, MEDIUM, LOW, INFO)

Field 6:
Column label: Title
Column name: u_title
Type: String
Max length: 255
Mandatory: ✓

Field 7:
Column label: Description
Column name: u_description
Type: String
Max length: 4000

Field 8:
Column label: File Path
Column name: u_file_path
Type: String
Max length: 512

Field 9:
Column label: Line Number
Column name: u_line_number
Type: Integer

Field 10:
Column label: Rule ID
Column name: u_rule_id
Type: String
Max length: 255

Field 11:
Column label: CVE ID
Column name: u_cve_id
Type: String
Max length: 100

Field 12:
Column label: CVSS Score
Column name: u_cvss_score
Type: Decimal

Field 13:
Column label: Status
Column name: u_status
Type: Choice
Mandatory: ✓
Default value: Open
(After creating, add choices: Open, In Progress, Resolved, False Positive)

Field 14:
Column label: Repository
Column name: u_repository
Type: String
Max length: 255
Mandatory: ✓

Field 15:
Column label: Branch
Column name: u_branch
Type: String
Max length: 100
Mandatory: ✓

Field 16:
Column label: Commit SHA
Column name: u_commit_sha
Type: String
Max length: 40
Mandatory: ✓

Field 17:
Column label: GitHub URL
Column name: u_github_url
Type: URL
Max length: 1024

Field 18:
Column label: SARIF Data
Column name: u_sarif_data
Type: String
Max length: 65000
```

---

## Table 2: u_security_scan_summary (2 minutes)

### Step 1: Create the Table (30 seconds)

1. **Open**: https://calitiiltddemo3.service-now.com/sys_db_object.do?sys_id=-1
2. **Fill in**:
   - **Label**: `Security Scan Summary`
   - **Name**: `u_security_scan_summary`
   - **Extends table**: Leave blank or select "Base Table"
   - Check: ✓ **Create module**
   - Check: ✓ **Add module to menu**
3. **Click**: Submit

### Step 2: Add Fields (1.5 minutes)

Click **Columns** tab, then **New** for each field:

```
Field 1:
Column label: Scan ID
Column name: u_scan_id
Type: String
Max length: 100
Mandatory: ✓

Field 2:
Column label: Workflow Run ID
Column name: u_workflow_run_id
Type: String
Max length: 100

Field 3:
Column label: Repository
Column name: u_repository
Type: String
Max length: 255
Mandatory: ✓

Field 4:
Column label: Branch
Column name: u_branch
Type: String
Max length: 100
Mandatory: ✓

Field 5:
Column label: Commit SHA
Column name: u_commit_sha
Type: String
Max length: 40
Mandatory: ✓

Field 6:
Column label: Scan Date
Column name: u_scan_date
Type: Date/Time
Mandatory: ✓

Field 7:
Column label: Total Findings
Column name: u_total_findings
Type: Integer
Mandatory: ✓
Default value: 0

Field 8:
Column label: Critical Count
Column name: u_critical_count
Type: Integer
Default value: 0

Field 9:
Column label: High Count
Column name: u_high_count
Type: Integer
Default value: 0

Field 10:
Column label: Medium Count
Column name: u_medium_count
Type: Integer
Default value: 0

Field 11:
Column label: Low Count
Column name: u_low_count
Type: Integer
Default value: 0

Field 12:
Column label: Info Count
Column name: u_info_count
Type: Integer
Default value: 0

Field 13:
Column label: Tools Run
Column name: u_tools_run
Type: String
Max length: 512

Field 14:
Column label: Status
Column name: u_status
Type: Choice
Mandatory: ✓
Default value: Success
(After creating, add choices: Success, Failed, In Progress)

Field 15:
Column label: GitHub URL
Column name: u_github_url
Type: URL
Max length: 1024
```

---

## ✅ Verify Tables Created

Run this command to verify:

```bash
bash scripts/test-servicenow-connectivity.sh
```

Should show:
```
[SUCCESS] ✓ u_security_scan_result table exists
[SUCCESS] ✓ u_security_scan_summary table exists
```

---

## 🚀 Re-Run Workflow

```bash
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo
```

---

## ⚡ Even Faster: Import via Script

If you have update set privileges, you can import table definitions via XML, but manual creation is usually faster for 2 tables.

---

**That's it! 5 minutes and you're done.**
