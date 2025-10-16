# Create u_security_scan_summary Table - 2 Minutes

**Status**: u_security_scan_result ✅ DONE | u_security_scan_summary ⏳ NEEDED

You only need to create **ONE** more table!

---

## Quick Creation (2 minutes)

### Step 1: Create the Table (30 seconds)

**Open**: https://calitiiltddemo3.service-now.com/sys_db_object.do?sys_id=-1

**Fill in**:
- **Label**: `Security Scan Summary`
- **Name**: `u_security_scan_summary`
- **Extends table**: Leave blank (or select "Base Table")
- ✓ **Create module**
- ✓ **Add module to menu**

**Click**: Submit

### Step 2: Add 15 Fields (1.5 minutes)

Click **Columns** tab → Click **New** for each field:

```
1. Scan ID
   Column name: u_scan_id
   Type: String
   Max length: 100
   Mandatory: ✓

2. Workflow Run ID
   Column name: u_workflow_run_id
   Type: String
   Max length: 100

3. Repository
   Column name: u_repository
   Type: String
   Max length: 255
   Mandatory: ✓

4. Branch
   Column name: u_branch
   Type: String
   Max length: 100
   Mandatory: ✓

5. Commit SHA
   Column name: u_commit_sha
   Type: String
   Max length: 40
   Mandatory: ✓

6. Scan Date
   Column name: u_scan_date
   Type: Date/Time
   Mandatory: ✓

7. Total Findings
   Column name: u_total_findings
   Type: Integer
   Mandatory: ✓
   Default value: 0

8. Critical Count
   Column name: u_critical_count
   Type: Integer
   Default value: 0

9. High Count
   Column name: u_high_count
   Type: Integer
   Default value: 0

10. Medium Count
    Column name: u_medium_count
    Type: Integer
    Default value: 0

11. Low Count
    Column name: u_low_count
    Type: Integer
    Default value: 0

12. Info Count
    Column name: u_info_count
    Type: Integer
    Default value: 0

13. Tools Run
    Column name: u_tools_run
    Type: String
    Max length: 512

14. Status
    Column name: u_status
    Type: Choice
    Mandatory: ✓
    Default value: Success
    (Add choices: Success, Failed, In Progress)

15. GitHub URL
    Column name: u_github_url
    Type: URL
    Max length: 1024
```

---

## ✅ Verify

Run this:
```bash
bash scripts/test-servicenow-connectivity.sh
```

Should show:
```
[SUCCESS] ✓ u_security_scan_result table exists
[SUCCESS] ✓ u_security_scan_summary table exists
[SUCCESS] ✓ All security tables exist - READY FOR TESTING!
```

---

## 🚀 Then Trigger Workflow

```bash
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo
```

---

**That's it! Just one more table with 15 fields and you're done!**
