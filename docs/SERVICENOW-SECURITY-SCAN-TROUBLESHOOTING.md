# ServiceNow Security Scan Registration - Troubleshooting Guide

## Current Status

### ✅ What's Working

**All 12 security scanners successfully registered** in ServiceNow DevOps (confirmed in workflow run 18677602300):

1. ✅ **Polaris** - Kubernetes manifest security
2. ✅ **Kubesec** - Kubernetes security hardening
3. ✅ **CodeQL (JavaScript)** - SAST for JavaScript/TypeScript
4. ✅ **CodeQL (Go)** - SAST for Go
5. ✅ **CodeQL (C#)** - SAST for C#/.NET
6. ✅ **CodeQL (Java)** - SAST for Java
7. ✅ **CodeQL (Python)** - SAST for Python
8. ✅ **Checkov** - IaC security (Terraform, Kubernetes)
9. ✅ **tfsec** - Terraform security scanning
10. ✅ **OWASP Dependency Check** - Dependency vulnerability scanning
11. ✅ **Semgrep** - SAST security patterns
12. ✅ **Trivy** - Container/filesystem vulnerability scanning

**Evidence**: Each scanner shows `SUCCESS: Security Scan registration was successful` in GitHub Actions logs.

### ❓ Current Issue

**Security Tools tab appears empty** at:
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/2fe9c38bc36c72d0e1bbf0cb050131cc/params/selected-tab-index/6

## Possible Causes

### 1. **Change Request Context Missing**

The Security Tools tab may show tools **only when associated with a specific change request**.

**Investigation**:
- The URL shows `/record/sn_devops_tool/2fe9c38bc36c72d0e1bbf0cb050131cc` (the GitHub tool record)
- Security scan results are registered at the **workflow run level**, not the tool level
- Security Tools may only appear when viewing a **specific change request**

**Solution**: Check security tools in an actual change request:
1. Navigate to a change request created by the deploy workflow
2. Look for "Security Scan Results" or "Security Tools" section
3. Expected: Should show all 12 security scanners with their latest results

### 2. **ServiceNow Plugin or Version Issue**

The Security Tools tab functionality may require:
- Specific ServiceNow DevOps plugin version
- Additional ServiceNow plugins to be activated
- ServiceNow Change Management 2.0 or newer

**Verification**:
```bash
# Check installed plugins
curl -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_plugins?sysparm_query=idLIKEsn_devops&sysparm_fields=id,name,active,version"
```

**Required Plugins**:
- `com.snc.devops` - ServiceNow DevOps Core
- `com.snc.devops.change` - DevOps Change Management
- `com.snc.devops.security` - DevOps Security Integration (if available)

### 3. **UI Permissions or Configuration**

The Security Tools tab might be:
- Restricted by user role (requires `sn_devops_user` or `admin` role)
- Hidden by UI policy or client script
- Available only in specific views/modes

**Check**:
1. Verify user has `sn_devops_user` or `sn_devops_admin` role
2. Try accessing from different menu: **DevOps > Security Scan Results**
3. Check in change request detail view instead of tool record

### 4. **Data Not Linked to Tool Record**

Security scan results might be stored but not linked to the orchestration tool.

**Investigation Queries**:

```bash
# Find all DevOps security-related tables
curl -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_db_object?sysparm_query=nameLIKEsn_devops^nameLIKEsecurity&sysparm_fields=name,label"

# Check security scan summary relations
curl -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_security_scan_summary_relations?sysparm_limit=20"
```

### 5. **Viewing the Wrong Tab/Page**

The URL shows `selected-tab-index/6` which may be the wrong tab.

**Try Different Views**:
- **Change Requests**: Navigate to Change > Normal > Open
- **DevOps Workspace**: DevOps > Change Management > Change Requests
- **Security Scan Results**: DevOps > Security > Scan Results (if menu exists)

## Recommended Troubleshooting Steps

### Step 1: Verify in Change Request Context

1. Trigger the deploy workflow to create a new change request:
   ```bash
   gh workflow run deploy-with-servicenow-devops.yaml --repo Freundcloud/microservices-demo -f environment=dev
   ```

2. Get the change request number from the workflow run

3. Navigate to the change request in ServiceNow

4. Look for "Security Scan Results" tab or section

### Step 2: Check ServiceNow Plugins

```bash
# Verify required plugins are active
PASSWORD='<your-password>' bash -c 'BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64); curl -s -H "Authorization: Basic ${BASIC_AUTH}" "https://calitiiltddemo3.service-now.com/api/now/table/sys_plugins?sysparm_query=idLIKEsn_devops&sysparm_fields=id,name,active,version" | jq .'
```

Expected plugins:
- `com.snc.devops` - Active
- `sn_devops_change` - Active
- `com.glide.hub.integrations` - Active

### Step 3: Check User Permissions

In ServiceNow UI:
1. Navigate to **User Administration > Users**
2. Search for the integration user or your user account
3. Verify roles include:
   - `sn_devops_user`
   - `sn_devops_admin` (recommended)
   - `itil` (for change management)

### Step 4: Alternative Navigation Paths

Try accessing security scan data via:

**Navigation Path 1 - DevOps Dashboard**:
```
DevOps > Dashboard > Security Scan Results
```

**Navigation Path 2 - Change Request Related Lists**:
```
Change > Normal > [Select a Change Request] > Related Lists > Security Scan Results
```

**Navigation Path 3 - DevOps Change Velocity**:
```
DevOps > Change Velocity > [Filter by repository] > Security
```

### Step 5: API Verification

Check if security scan data exists in ServiceNow:

```bash
# Method 1: Check via tool relation
PASSWORD='<your-password>' bash -c 'BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64); curl -s -H "Authorization: Basic ${BASIC_AUTH}" "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_security_orchestration_relation?sysparm_limit=20" | jq .'

# Method 2: Check security scan summaries
PASSWORD='<your-password>' bash -c 'BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64); curl -s -H "Authorization: Basic ${BASIC_AUTH}" "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_security_scan_summary?sysparm_limit=20&sysparm_display_value=true" | jq .'
```

## Expected Outcome

When properly configured, you should see:

### In Change Request View:
- **Security Scan Results** tab showing all 12 scanners
- Pass/Fail status for each scanner
- Link to detailed scan results
- Summary of vulnerabilities found

### In Security Tools Tab:
- List of all registered security tools
- Last scan date/time for each tool
- Total findings count per tool
- Trend data (if multiple scans)

## Next Steps if Still Empty

If security tools still don't appear after troubleshooting:

1. **Contact ServiceNow Support**:
   - Provide workflow run ID: 18677602300
   - Show successful registration logs
   - Ask about Security Tools tab configuration requirements

2. **Check ServiceNow Documentation**:
   - Search for "DevOps Security Scan Results" in ServiceNow docs
   - Review version-specific features (Vancouver, Washington, Xanadu releases)

3. **Alternative: Use ServiceNow System Logs**:
   ```
   System Logs > System Log > Application Logs
   Filter by: "devops" OR "security scan"
   ```

4. **Create ServiceNow Support Case**:
   - Title: "DevOps Security Scan Results Not Displaying in UI"
   - Include: GitHub Action version, ServiceNow instance version, workflow logs
   - Attach: Screenshots of empty Security Tools tab

## Documentation

- **Implementation Guide**: [SERVICENOW-SECURITY-TOOLS-REGISTRATION.md](SERVICENOW-SECURITY-TOOLS-REGISTRATION.md)
- **Security Workflow**: [.github/workflows/security-scan.yaml](../.github/workflows/security-scan.yaml)
- **ServiceNow Action Documentation**: https://github.com/marketplace/actions/servicenow-devops-security-results

---

**Last Updated**: 2025-10-21
**Workflow Run**: 18677602300 (successful security scan registration)
**Status**: ✅ All 12 scanners registered, ❓ UI display issue under investigation
