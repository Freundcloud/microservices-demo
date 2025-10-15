# ServiceNow Integration Troubleshooting Guide

This guide helps diagnose and fix common issues with the ServiceNow integration.

## Table of Contents
- [Internal Server Error (500)](#internal-server-error-500)
- [Authentication Errors](#authentication-errors)
- [Change Request Creation Failures](#change-request-creation-failures)
- [CMDB Update Issues](#cmdb-update-issues)
- [Security Scan Upload Failures](#security-scan-upload-failures)
- [Debugging Tips](#debugging-tips)

---

## Internal Server Error (500)

### Error Message
```
Error: Internal server error. An unexpected error occurred while processing the request.
```

### Common Causes

#### 1. ServiceNow DevOps Plugin Not Installed or Configured
**Solution:**
1. Log into ServiceNow as admin
2. Go to **System Applications** > **All Available Applications** > **All**
3. Search for "DevOps Change"
4. Install **DevOps Change** plugin
5. Wait 5-10 minutes for installation to complete
6. Navigate to **DevOps Change** > **Configuration**
7. Verify the plugin is active

#### 2. GitHub Tool Not Configured in ServiceNow
**Solution:**
1. Navigate to **DevOps Change** > **Tool Configuration**
2. Click **New**
3. Fill in:
   - **Name**: GitHub
   - **Type**: Version Control
   - **Tool ID**: (copy from GitHub secret `SN_ORCHESTRATION_TOOL_ID`)
   - **URL**: https://github.com
4. Click **Submit**

#### 3. Invalid Integration Token
**Solution:**
1. In ServiceNow, go to **DevOps Change** > **Integration Users**
2. Find your integration user (e.g., `github_integration`)
3. Click on the user
4. Generate a new token
5. Copy the token
6. Update GitHub secret `SN_DEVOPS_INTEGRATION_TOKEN` with the new value

#### 4. Missing or Invalid Assignment Group
**Solution:**

Change requests require a valid assignment group. If the group doesn't exist in ServiceNow, the request fails.

**Option A: Remove Assignment Group from Workflow**
```yaml
# Remove this line from change-request attributes:
"assignment_group": "${{ steps.change-settings.outputs.assignment_group }}",
```

**Option B: Create Assignment Groups in ServiceNow**
1. Navigate to **User Administration** > **Groups**
2. Click **New**
3. Create these groups:
   - Name: `DevOps Team`
   - Name: `QA Team`
   - Name: `Change Advisory Board`
4. Add users to each group

**Option C: Use Existing Groups**
Update the workflow to use existing groups:
```yaml
# In deploy-with-servicenow.yaml, change the assignment_group values
echo "assignment_group=Service Desk" >> $GITHUB_OUTPUT  # Use your existing group
```

#### 5. Invalid Priority or Risk Values
**Solution:**

ServiceNow expects specific numeric values for priority and risk.

Check your ServiceNow instance for valid values:
```sql
-- In ServiceNow, run this script in Scripts - Background:
var gr = new GlideRecord('sys_choice');
gr.addQuery('name', 'change_request');
gr.addQuery('element', 'priority');
gr.query();
while(gr.next()) {
    gs.print(gr.label + ': ' + gr.value);
}
```

Update workflow if needed:
```yaml
# Standard values that usually work:
priority: 3  # 1=Critical, 2=High, 3=Moderate, 4=Low, 5=Planning
risk: 3      # 1=High, 2=Medium, 3=Low, 4=Very Low
```

#### 6. Simplified Change Request (Minimal Fields)
**Solution:**

Use only required fields to isolate the issue:

```yaml
change-request: |
  {
    "autoCloseChange": true,
    "attributes": {
      "short_description": "Deploy to ${{ github.event.inputs.environment }}",
      "description": "Automated deployment via GitHub Actions"
    }
  }
```

If this works, gradually add fields back one at a time to find the problematic field.

---

## Authentication Errors

### Error: 401 Unauthorized

**Causes:**
- Invalid or expired `SN_DEVOPS_INTEGRATION_TOKEN`
- Wrong `SN_INSTANCE_URL`
- Integration user doesn't have required roles

**Solution:**
1. Verify secrets in GitHub:
   ```bash
   # Secrets should be set at repository level
   SN_DEVOPS_INTEGRATION_TOKEN  # Integration token from ServiceNow
   SN_INSTANCE_URL              # https://your-instance.service-now.com
   SN_ORCHESTRATION_TOOL_ID     # Tool ID from ServiceNow
   SN_OAUTH_TOKEN               # OAuth token for CMDB updates (optional)
   ```

2. Verify integration user has roles:
   - `sn_devops.integration_user`
   - `x_snc_devops.integration_user`
   - `itil`

3. Regenerate token in ServiceNow:
   - **DevOps Change** > **Integration Users** > Select user > **Generate Token**

---

## Change Request Creation Failures

### Error: "Required field missing"

**Solution:**
Check ServiceNow change request mandatory fields:

1. Navigate to **System Definition** > **Tables**
2. Search for `change_request`
3. Click on table name
4. Go to **Columns** tab
5. Look for columns with **Mandatory** = true
6. Ensure all mandatory fields are in your `change-request` payload

Common mandatory fields:
- `short_description`
- `description`
- `assignment_group` (often mandatory)
- `category` (sometimes mandatory)
- `type` (sometimes mandatory)

### Error: "Invalid change type"

**Solution:**
ServiceNow has specific change types. Use one of:
- `Standard` - Pre-approved, low risk
- `Normal` - Requires approval
- `Emergency` - High priority, expedited approval

Update workflow:
```yaml
"type": "Standard"
```

---

## CMDB Update Issues

### Error: Cannot create CMDB records

**Cause:** Custom CMDB tables don't exist or OAuth token is invalid.

**Solution:**

#### Option 1: Create Custom CMDB Tables

Run this in ServiceNow **Scripts - Background**:

```javascript
// Create EKS Cluster table
var gr = new GlideRecord('sys_db_object');
gr.initialize();
gr.name = 'u_eks_cluster';
gr.label = 'EKS Cluster';
gr.super_class = 'cmdb_ci';
gr.insert();

// Add columns
var fields = [
  {name: 'u_name', type: 'string', label: 'Cluster Name'},
  {name: 'u_arn', type: 'string', label: 'ARN'},
  {name: 'u_version', type: 'string', label: 'Kubernetes Version'},
  {name: 'u_endpoint', type: 'url', label: 'API Endpoint'},
  {name: 'u_status', type: 'string', label: 'Status'},
  {name: 'u_region', type: 'string', label: 'AWS Region'},
  {name: 'u_vpc_id', type: 'string', label: 'VPC ID'},
  {name: 'u_provider', type: 'string', label: 'Provider'}
];

fields.forEach(function(field) {
  var dict = new GlideRecord('sys_dictionary');
  dict.initialize();
  dict.name = 'u_eks_cluster';
  dict.element = field.name;
  dict.internal_type = field.type;
  dict.column_label = field.label;
  dict.insert();
});

gs.print('EKS Cluster table created');
```

#### Option 2: Disable CMDB Updates

If you don't need CMDB updates, skip the step:

```yaml
# The workflow already has this condition:
if: ${{ env.SN_OAUTH_TOKEN != '' }}

# Simply don't set SN_OAUTH_TOKEN secret in GitHub
```

---

## Security Scan Upload Failures

### Error: Cannot upload SARIF file

**Causes:**
- Invalid SARIF format
- File size too large (>10MB)
- Security tool not registered in ServiceNow

**Solution:**

1. Validate SARIF file locally:
   ```bash
   # Check file size
   ls -lh codeql-results.sarif

   # Validate JSON
   jq . codeql-results.sarif > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
   ```

2. Register security tools in ServiceNow:
   - Navigate to **Vulnerability Response** > **Security Tools**
   - Add tools: CodeQL, Trivy, Checkov, Semgrep, Gitleaks

3. Check if SARIF upload is enabled:
   - **DevOps Change** > **Configuration**
   - Enable **Security Result Integration**

---

## Debugging Tips

### 1. Enable Debug Logging in ServiceNow

```javascript
// In ServiceNow Scripts - Background:
gs.setProperty('com.snc.devops.debug', 'true');
gs.print('DevOps debug logging enabled');
```

View logs:
- **System Logs** > **System Log** > **All**
- Filter by `source contains devops`

### 2. Test ServiceNow API Manually

```bash
# Test authentication
curl -X GET \
  "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN" \
  -H "Content-Type: application/json"

# Test change request creation
curl -X POST \
  "$SN_INSTANCE_URL/api/now/table/change_request" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "short_description": "Test change request",
    "description": "Testing API access"
  }'
```

### 3. Check GitHub Actions Logs

Enable debug logging in GitHub Actions:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add repository secret:
   - Name: `ACTIONS_STEP_DEBUG`
   - Value: `true`
3. Re-run the workflow

### 4. Validate Workflow Syntax Locally

```bash
# Install actionlint
brew install actionlint  # macOS
# or
sudo snap install actionlint  # Linux

# Validate workflows
actionlint .github/workflows/deploy-with-servicenow.yaml
actionlint .github/workflows/eks-discovery.yaml
actionlint .github/workflows/security-scan-servicenow.yaml
```

### 5. Test with Minimal Configuration

Create a test workflow with minimal configuration:

```yaml
name: Test ServiceNow Connection
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Test ServiceNow API
        run: |
          curl -f -X GET \
            "${{ secrets.SN_INSTANCE_URL }}/api/now/table/sys_user?sysparm_limit=1" \
            -H "Authorization: Bearer ${{ secrets.SN_OAUTH_TOKEN }}" \
            -H "Content-Type: application/json" \
            && echo "✅ API connection successful" \
            || echo "❌ API connection failed"
```

---

## Common Error Messages Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `Internal server error` | Plugin not configured, invalid fields | Simplify payload, check plugin |
| `401 Unauthorized` | Invalid token | Regenerate token |
| `403 Forbidden` | Missing roles | Add roles to integration user |
| `404 Not Found` | Wrong instance URL or table | Verify URL, create tables |
| `Required field missing` | Mandatory field not provided | Add required fields |
| `Invalid assignment group` | Group doesn't exist | Create group or remove field |
| `Change request already exists` | Duplicate request | Use existing CR or wait |
| `Timeout waiting for approval` | No approver assigned | Assign approvers to group |

---

## Getting Help

### ServiceNow Support
1. **Community**: https://community.servicenow.com
2. **Documentation**: https://docs.servicenow.com/bundle/vancouver-devops
3. **Support Portal**: https://support.servicenow.com (requires account)

### GitHub Actions Support
1. **GitHub Actions Docs**: https://docs.github.com/actions
2. **ServiceNow DevOps Actions**: https://github.com/ServiceNow

### Contact

If issues persist after following this guide:
1. Enable debug logging (see above)
2. Export ServiceNow logs
3. Export GitHub Actions logs
4. Create an issue in this repository with:
   - Error message
   - Workflow logs
   - ServiceNow configuration (sanitized)
   - Steps already attempted

---

## Quick Checklist

Before running workflows, verify:

- [ ] ServiceNow DevOps plugin installed and active
- [ ] Integration user created with correct roles
- [ ] GitHub tool configured in ServiceNow
- [ ] All GitHub secrets set correctly
- [ ] Assignment groups exist (if using)
- [ ] Change request mandatory fields configured
- [ ] Network connectivity between GitHub and ServiceNow
- [ ] API rate limits not exceeded
- [ ] CMDB tables created (if using CMDB updates)
- [ ] OAuth token valid (if using CMDB updates)

---

Last Updated: 2025-10-15
