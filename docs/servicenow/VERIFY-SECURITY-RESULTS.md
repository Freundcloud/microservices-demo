# Verify ServiceNow Security Results Integration

> **Guide**: How to verify security scan results are being uploaded to ServiceNow
> **Date**: 2025-10-16
> **Workflow**: security-scan-servicenow.yaml

## 📋 Prerequisites

Before verifying, ensure you have:
- ✅ ServiceNow instance access with appropriate permissions
- ✅ DevOps plugin installed (`com.snc.devops`)
- ✅ GitHub Actions secrets configured:
  - `SN_INSTANCE_URL`
  - `SN_DEVOPS_INTEGRATION_TOKEN`
  - `SN_ORCHESTRATION_TOOL_ID`

## 🔍 Step-by-Step Verification

### Step 1: Trigger a Security Scan

First, trigger the security scan workflow to generate fresh results:

```bash
# From your repository
gh workflow run security-scan-servicenow.yaml

# Monitor the run
gh run list --workflow=security-scan-servicenow.yaml --limit 1
```

Wait for the workflow to complete (~5-10 minutes depending on codebase size).

---

### Step 2: Navigate to Security Results in ServiceNow

**⚠️ Important**: The exact navigation path varies by your ServiceNow version, installed plugins, and license type. Security scan results location depends on whether you have:
- **DevOps Change Velocity** (full product)
- **Standalone DevOps plugin**
- **Custom DevOps configuration**

#### Method 1: Find Tables Using Application Navigator (Most Reliable)

1. **Log into ServiceNow** with your credentials

2. **Open Application Navigator** (left sidebar search)

3. **Search for DevOps-related tables**:
   ```
   Type any of these in the filter navigator:
   - "devops"
   - "security scan"
   - "security result"
   - "pipeline execution"
   - "vulnerability scan"
   ```

4. **Look for relevant tables** such as:
   - `sn_devops_*` (DevOps Change Velocity tables)
   - Pipeline execution tables
   - Security scan/result tables
   - Vulnerability tables

5. **Click on the table** that seems most relevant to view records

#### Method 2: Check Your ServiceNow Instance's Table Structure

Since table names vary, use ServiceNow's built-in table explorer:

1. **Navigate to Tables**:
   - Search for: `sys_db_object.list` in Application Navigator
   - Or type: "Tables" in the filter

2. **Filter for DevOps tables**:
   - In the "Name" column filter, enter: `devops`
   - Look for tables related to security, scans, or pipelines

3. **Common table prefixes to look for**:
   - `sn_devops_*` - DevOps Change Velocity
   - `u_*` - Custom tables (if your org created them)
   - `sn_vul_*` - Vulnerability-related tables

4. **Open the table** by clicking the "Name" link to view records

#### Method 3: API Query (If UI Access is Limited)

You can query the ServiceNow API to find where data is stored:

```bash
# List all DevOps-related tables
curl -X GET \
  "${SN_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=nameLIKEdevops" \
  -H "Authorization: Bearer ${SN_DEVOPS_TOKEN}" \
  -H "Content-Type: application/json"
```

#### Method 4: Contact Your ServiceNow Administrator

If you're unable to locate security results:

1. **Ask your ServiceNow admin** for:
   - The exact table name for security scan results
   - The navigation path to DevOps security data
   - Required permissions/roles to view the data

2. **Provide them with context**:
   - You're using the `servicenow-devops-security-result` GitHub Action
   - Security tool IDs: `codeql`, `semgrep`, `trivy`, `checkov`
   - Application name: `microservices-demo`

---

### Step 3: Verify GitHub Action Successfully Uploaded Results

Before searching in ServiceNow, confirm the GitHub Action actually succeeded:

#### Check Workflow Run Logs

```bash
# View most recent security scan run
gh run list --workflow=security-scan-servicenow.yaml --limit 1

# View detailed logs
gh run view <run-id> --log
```

#### Verify Upload Steps Succeeded

Look for these specific steps in the workflow logs:

```
✅ Upload CodeQL results to ServiceNow
✅ Upload Semgrep results to ServiceNow
✅ Upload Trivy results to ServiceNow
✅ Upload Checkov results to ServiceNow
```

**Each upload step should show**:
- Action: `ServiceNow/servicenow-devops-security-result@v3.1.0`
- Status: Success (green checkmark)
- No error messages

#### Common Upload Failures

If uploads are failing, check for:

1. **Missing Secrets**:
   ```bash
   gh secret list | grep SN_
   ```
   Should show: `SN_INSTANCE_URL`, `SN_DEVOPS_INTEGRATION_TOKEN`, `SN_ORCHESTRATION_TOOL_ID`

2. **Invalid Token**:
   ```
   Error: Authentication failed
   ```
   Solution: Regenerate token in ServiceNow

3. **Network Issues**:
   ```
   Error: Connection timeout
   ```
   Solution: Check if ServiceNow instance is accessible from GitHub Actions runners

4. **Missing SARIF Files**:
   ```
   Error: security-result-file not found
   ```
   Solution: Check if the scanner step succeeded and generated the SARIF file

---

### Step 4: Search for Results in ServiceNow

Once you've confirmed the GitHub Actions successfully uploaded results, search in ServiceNow using the methods from Step 2.

When you find the security results table, you should see records for:

#### Expected Security Tools

| Scanner | Tool ID | Scan Type | Languages/Areas |
|---------|---------|-----------|-----------------|
| **CodeQL** | `codeql` | SAST | Python, JavaScript, Go, Java, C# |
| **Semgrep** | `semgrep` | SAST | Multi-language |
| **Trivy** | `trivy` | Container/FS | Filesystem vulnerabilities |
| **Checkov** | `checkov` | IaC | Terraform |

#### What to Look For

Each security result record should contain:

1. **Scanner Name**: The tool that performed the scan (e.g., "CodeQL", "Trivy")
2. **Application Name**: `microservices-demo`
3. **Scan Date/Time**: Recent timestamp
4. **Number of Findings**: Count of vulnerabilities/issues found
5. **Severity Breakdown**: Critical, High, Medium, Low counts
6. **Status**: Completed/Success
7. **Source**: GitHub Actions workflow

---

### Step 5: Inspect Individual Security Results

Click on any security result record to see details:

#### Key Fields to Verify

```
Record Details:
  - Application Name: microservices-demo
  - Scanner: [CodeQL/Semgrep/Trivy/Checkov]
  - Security Tool ID: [codeql/semgrep/trivy/checkov]
  - Scan Type: [SAST/Container/IaC]
  - Created: [Recent date/time]
  - Number: [Auto-generated record number]

Findings:
  - Critical: [count]
  - High: [count]
  - Medium: [count]
  - Low: [count]
  - Total: [count]

Source Information:
  - Repository: Freundcloud/microservices-demo
  - Branch: main
  - Commit SHA: [latest commit]
  - Workflow: Security Scanning with ServiceNow Integration
```

---

### Step 6: Review Security Findings

To see the actual vulnerabilities found:

1. **Open a Security Result** record
2. **Navigate to the "Findings" related list** (usually at the bottom)
3. **Each finding shows**:
   - Vulnerability ID/CVE
   - Severity level
   - File/Location
   - Description
   - Remediation guidance

---

### Step 7: Verify All Tools Uploaded Results

Check that all 4 security tools uploaded results:

#### Quick Verification Query

In the Security Results list view:

1. **Group by Scanner**:
   - Right-click column header "Scanner"
   - Select "Group by Scanner"

2. **Expected Results**:
   ```
   Scanner: CodeQL
     ├─ Python scan
     ├─ JavaScript scan
     ├─ Go scan
     ├─ Java scan
     └─ C# scan

   Scanner: Semgrep
     └─ SAST scan

   Scanner: Trivy
     └─ Filesystem scan

   Scanner: Checkov
     └─ Terraform IaC scan
   ```

#### Filter Examples

**See only CodeQL results**:
```
Scanner = CodeQL
```

**See results from last 24 hours**:
```
Created > javascript:gs.daysAgoStart(1)
```

**See only high/critical findings**:
```
Number of critical findings > 0 OR Number of high findings > 0
```

---

### Step 8: Verify Integration Configuration (Optional)

If available in your ServiceNow instance, check that the GitHub tool is properly configured:

1. **Navigate to Tool Configuration**:
   - **Option 1**: Use Application Navigator search
     - Type: `sn_devops_tool.list` or "DevOps Tool"
     - Select "Tools [sn_devops_tool]"

   - **Option 2**: Direct URL
     ```
     https://<instance>.service-now.com/nav_to.do?uri=sn_devops_tool_list.do
     ```

2. **Look for GitHub tool**:
   - Name: "GitHub" or "GitHub Actions"
   - Type: Source Control / Orchestration
   - Status: Active
   - Tool ID: [matches your SN_ORCHESTRATION_TOOL_ID secret]

3. **Verify connection**:
   - Click on the tool record
   - Check "Last Sync" timestamp (if available)
   - Verify URL points to your repository

---

## 🔧 Troubleshooting

### Issue 1: No Security Results Appearing

**Possible Causes**:

1. **Secrets not configured**:
   ```bash
   # Check if secrets exist in GitHub
   gh secret list
   ```

   Should show:
   - `SN_INSTANCE_URL`
   - `SN_DEVOPS_INTEGRATION_TOKEN`
   - `SN_ORCHESTRATION_TOOL_ID`

2. **DevOps plugin not installed**:
   - Navigate to: **System Definition > Plugins**
   - Search for: `DevOps (com.snc.devops)`
   - Status should be: **Active**

3. **Workflow failed**:
   ```bash
   # Check workflow status
   gh run view <run-id> --log-failed
   ```

   Look for errors in the "Upload to ServiceNow" steps

4. **Network/Firewall issues**:
   - GitHub Actions runners must be able to reach your ServiceNow instance
   - Check if your instance is behind a firewall

**Solution Steps**:

```bash
# 1. Verify secrets are set
gh secret list

# 2. Trigger test run
gh workflow run security-scan-servicenow.yaml

# 3. Watch for errors
gh run watch

# 4. Check specific upload steps
gh run view <run-id> --log | grep -A 10 "Upload.*ServiceNow"
```

---

### Issue 2: Old Results But No New Ones

**Possible Causes**:
- Token expired
- Tool ID changed
- Instance URL changed

**Solution**:

1. **Regenerate integration token** in ServiceNow:
   - **Option 1**: Use Application Navigator
     - Search for: `sn_devops_integration_token.list` or "DevOps Integration Token"
     - Select "Integration Tokens [sn_devops_integration_token]"

   - **Option 2**: Direct URL
     ```
     https://<instance>.service-now.com/nav_to.do?uri=sn_devops_integration_token_list.do
     ```

2. **Update GitHub secret**:
   ```bash
   gh secret set SN_DEVOPS_INTEGRATION_TOKEN
   ```

3. **Trigger new scan**:
   ```bash
   gh workflow run security-scan-servicenow.yaml
   ```

---

### Issue 3: Partial Results (Some Tools Missing)

**Check individual tool uploads**:

```bash
# View full workflow log
gh run view <run-id> --log > workflow.log

# Search for each tool's upload status
grep -A 5 "Upload CodeQL" workflow.log
grep -A 5 "Upload Semgrep" workflow.log
grep -A 5 "Upload Trivy" workflow.log
grep -A 5 "Upload Checkov" workflow.log
```

**Common Issues**:
- SARIF file not generated (scan failed)
- File path incorrect
- Scanner error (check scanner-specific steps)

---

## 📊 Expected Behavior

### Successful Upload

When a security scan completes successfully, you should see:

1. **In GitHub Actions**:
   ```
   ✅ Upload CodeQL results to ServiceNow
   ✅ Upload Semgrep results to ServiceNow
   ✅ Upload Trivy results to ServiceNow
   ✅ Upload Checkov results to ServiceNow
   ```

2. **In ServiceNow**:
   - New records in `sn_devops_security_result` table
   - Records linked to your application
   - Findings populated
   - Recent timestamps

3. **In GitHub Security Tab**:
   - SARIF files uploaded
   - Vulnerabilities visible in Security > Code scanning alerts

---

## 🔗 Useful ServiceNow URLs

**⚠️ Note**: These URLs may not work on your instance depending on your ServiceNow version, plugins, and configuration. Use the table exploration methods in Step 2 to find the correct paths for your instance.

Replace `<instance>` with your ServiceNow instance name:

| Purpose | Example URL Pattern | Notes |
|---------|---------------------|-------|
| Tables List | `https://<instance>.service-now.com/sys_db_object_list.do` | View all tables |
| Filter for DevOps Tables | `https://<instance>.service-now.com/sys_db_object_list.do?sysparm_query=nameLIKEdevops` | Find DevOps-related tables |
| Application Navigator | `https://<instance>.service-now.com/now/nav/ui/classic/params/target/%24navpage.do` | Main navigation |
| API Explorer | `https://<instance>.service-now.com/api_explorer.do` | Test API queries |

---

## 📝 Manual Testing

To manually test the integration:

### 1. Create a Simple Vulnerability

Add a vulnerable dependency to test detection:

```bash
# Add an old version with known vulnerabilities
echo "lodash==4.17.0" >> src/emailservice/requirements.txt

git add .
git commit -m "test: Add vulnerable dependency for testing"
git push
```

### 2. Trigger Security Scan

```bash
gh workflow run security-scan-servicenow.yaml
```

### 3. Check Results in ServiceNow

Within 5-10 minutes, you should see:
- New security result record
- Vulnerability detected by Trivy or OWASP Dependency Check
- Severity marked as High or Critical

### 4. Clean Up

```bash
# Remove test vulnerability
git revert HEAD
git push
```

---

## ✅ Verification Checklist

Use this checklist to confirm everything is working:

- [ ] ServiceNow DevOps plugin is installed and active
- [ ] GitHub secrets are configured (3 secrets)
- [ ] Tool configuration exists for GitHub in ServiceNow
- [ ] Security scan workflow runs successfully
- [ ] CodeQL results appear in ServiceNow (5 languages)
- [ ] Semgrep results appear in ServiceNow
- [ ] Trivy results appear in ServiceNow
- [ ] Checkov results appear in ServiceNow
- [ ] Results show application name "microservices-demo"
- [ ] Results show correct repository and branch
- [ ] Findings are populated with severity levels
- [ ] Recent timestamp on all results
- [ ] GitHub Security tab shows SARIF uploads
- [ ] Security summary step shows ServiceNow integration status

---

## 🎓 Additional Resources

### ServiceNow Documentation

- [DevOps Security Scan Framework](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/security-tool-framework.html)
- [DevOps Integration](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-integration.html)

### GitHub Actions

- [ServiceNow DevOps Security Result Action](https://github.com/ServiceNow/servicenow-devops-security-result)
- [SARIF Format Specification](https://sarifweb.azurewebsites.net/)

### Security Tools

- [CodeQL Documentation](https://codeql.github.com/docs/)
- [Semgrep Rules](https://semgrep.dev/explore)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Checkov Documentation](https://www.checkov.io/documentation.html)

---

## 🆘 Support

If you encounter issues:

1. **Check workflow logs**:
   ```bash
   gh run view <run-id> --log-failed
   ```

2. **Verify ServiceNow configuration**:
   - DevOps plugin active
   - Integration token valid
   - Tool configuration correct

3. **Test connection manually**:
   ```bash
   # Test ServiceNow API connectivity
   curl -X GET \
     "${SN_INSTANCE_URL}/api/now/table/sn_devops_security_result?sysparm_limit=1" \
     -H "Authorization: Bearer ${SN_DEVOPS_TOKEN}"
   ```

4. **Review documentation**:
   - [SERVICENOW-SETUP-CHECKLIST.md](../SERVICENOW-SETUP-CHECKLIST.md)
   - [ServiceNow GitHub Actions Integration](https://github.com/ServiceNow/servicenow-devops-security-result#readme)

---

## 📝 Documentation Notes

**Important**: This guide has been updated to reflect the reality that ServiceNow navigation paths and table names vary significantly by:
- ServiceNow version (Vancouver, Washington, Xanadu, etc.)
- Installed plugins and license type
- Custom organizational configurations

The guide now focuses on **practical methods to discover** where security results are stored in your specific ServiceNow instance, rather than providing potentially incorrect specific menu paths.

**Key Recommendation**: Work with your ServiceNow administrator to identify the correct table names and navigation paths for your organization's specific configuration.

---

**Last Updated**: 2025-10-16
**Maintained By**: DevOps Team
**Revision**: 2.0 - Updated with accurate navigation guidance
