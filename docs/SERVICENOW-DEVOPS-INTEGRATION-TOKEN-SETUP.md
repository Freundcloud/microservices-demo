# ServiceNow DevOps Integration Token and Tool ID Setup

**Created**: 2025-10-21
**Status**: Research-Based Documentation
**Purpose**: Guide for configuring ServiceNow DevOps GitHub integration secrets

## Overview

This guide documents how to find and configure the required ServiceNow DevOps integration credentials for GitHub Actions workflows, based on official ServiceNow DevOps documentation and GitHub Actions marketplace resources.

## Required GitHub Secrets

Your GitHub Actions workflows require three secrets to integrate with ServiceNow DevOps:

1. **`SN_INSTANCE_URL`** - Your ServiceNow instance URL
   - Example: `https://calitiiltddemo3.service-now.com`
   - Format: Full HTTPS URL without trailing slash

2. **`SN_ORCHESTRATION_TOOL_ID`** - The sys_id of your GitHub tool in ServiceNow
   - This is the unique identifier for the GitHub orchestration tool record
   - Format: ServiceNow sys_id (32-character alphanumeric)
   - Example from your instance: `2fe9c38bc36c72d0e1bbf0cb050131cc`

3. **`SN_DEVOPS_INTEGRATION_TOKEN`** - Integration token for authentication
   - Token-based authentication credential
   - Associated with the GitHub tool created in ServiceNow
   - Alternative to username/password authentication

## Finding the Tool ID (sys_id)

### Method 1: ServiceNow Table Access

The tool ID is the sys_id from the `sn_devops_orchestration_tool` table:

1. **In ServiceNow**, navigate to the application navigator (left sidebar)
2. **Type**: `sn_devops_orchestration_tool.list` in the filter navigator
3. **Find** your GitHub tool entry
4. **Open** the record to view details
5. **Copy** the sys_id value from the URL or the form

**URL Pattern**:
```
https://YOUR-INSTANCE.service-now.com/sn_devops_orchestration_tool.do?sys_id=TOOL_ID_HERE
```

The `sys_id` parameter in the URL is your `SN_ORCHESTRATION_TOOL_ID`.

### Method 2: Alternative Table Access

You may also find the tool in the `sn_devops_tool` table:

1. Navigate to: `sn_devops_tool.list`
2. Find your GitHub tool
3. Copy the sys_id

**Note**: According to ServiceNow documentation, there's no individual "ID" column other than the SysID in the DevOps tool tables.

## Finding the Integration Token

### Token Location

The integration token is associated with the GitHub tool record created in ServiceNow. Based on documentation:

1. **Navigate** to your GitHub tool record (see "Finding the Tool ID" above)
2. **Look for** a field named:
   - "Integration Token" or
   - "DevOps Integration Token" or
   - "Token" or
   - "Credential"
3. **Copy** the token value

### Token Purpose

The DevOps Integration Token:
- Enables token-based authentication (available from v2.0.0+)
- Replaces the need for username/password authentication
- Provides more secure authentication for GitHub Actions
- Is specific to the GitHub tool created in your ServiceNow instance

### Authentication Options

ServiceNow DevOps GitHub Actions support **two authentication methods**:

#### Option A: Token-Based Authentication (Recommended)
```yaml
devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
instance-url: ${{ secrets.SN_INSTANCE_URL }}
tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

#### Option B: Basic Authentication (Alternative)
```yaml
instance-url: ${{ secrets.SN_INSTANCE_URL }}
devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
```

Your workflows currently use **Token-Based Authentication**.

## Alternative Navigation Approaches

If you cannot find the table directly, try these approaches:

### Approach 1: Using Application Navigator

1. Open ServiceNow instance
2. In the left sidebar navigation, type "DevOps" or "Orchestration"
3. Look for menu options like:
   - **DevOps > Tools**
   - **DevOps > Orchestration Tools**
   - **DevOps > Configuration > Tools**
4. Find your GitHub tool entry

### Approach 2: Using Filter Navigator Search

1. Click in the **filter navigator** (search box at top left)
2. Type one of these search terms:
   - `GitHub`
   - `Orchestration Tools`
   - `DevOps Tools`
   - `sn_devops_orchestration_tool`
3. Click on the matching table or module

### Approach 3: Direct URL Access

Try navigating directly to the table by appending to your instance URL:
```
https://YOUR-INSTANCE.service-now.com/sn_devops_orchestration_tool_list.do
```

Or for a specific tool if you know the sys_id:
```
https://YOUR-INSTANCE.service-now.com/sn_devops_orchestration_tool.do?sys_id=YOUR_TOOL_ID
```

## Configuring GitHub Secrets

Once you have the values, add them to your GitHub repository:

### Using GitHub Web UI

1. Go to your repository: `https://github.com/Freundcloud/microservices-demo`
2. Click **Settings** tab
3. Navigate to **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret:
   - Name: `SN_INSTANCE_URL`
     Value: `https://calitiiltddemo3.service-now.com`
   - Name: `SN_ORCHESTRATION_TOOL_ID`
     Value: (the sys_id you found)
   - Name: `SN_DEVOPS_INTEGRATION_TOKEN`
     Value: (the token you found)

### Using GitHub CLI

```bash
# Set instance URL
gh secret set SN_INSTANCE_URL --body "https://calitiiltddemo3.service-now.com"

# Set tool ID (replace with actual sys_id)
gh secret set SN_ORCHESTRATION_TOOL_ID --body "YOUR_TOOL_SYS_ID_HERE"

# Set integration token (replace with actual token)
gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "YOUR_TOKEN_HERE"
```

## Verification

After configuring secrets, verify they're set correctly:

### Check Secrets Exist
```bash
gh secret list
```

Expected output should include:
```
SN_DEVOPS_INTEGRATION_TOKEN   Updated 2025-10-21
SN_INSTANCE_URL               Updated 2025-10-21
SN_ORCHESTRATION_TOOL_ID      Updated 2025-10-21
```

### Test with Workflow

Trigger a new workflow run:
```bash
gh workflow run MASTER-PIPELINE.yaml
```

Monitor for authentication errors:
```bash
gh run watch
```

**Expected**: "Register Artifacts in ServiceNow" job should succeed without authentication errors.

## Troubleshooting

### Error: "Invalid username and password or Invalid token and toolid"

**Causes**:
1. Secrets not configured in GitHub
2. Token value is incorrect
3. Tool ID (sys_id) is incorrect
4. Token has expired or been revoked

**Fix**:
1. Verify secrets exist: `gh secret list`
2. Double-check values in ServiceNow
3. Ensure you copied the complete sys_id (32 characters)
4. Verify token hasn't expired

### Error: "Tool not found"

**Causes**:
1. Tool ID doesn't match any record in ServiceNow
2. Tool was deleted or deactivated

**Fix**:
1. Navigate to `sn_devops_orchestration_tool.list` and verify tool exists
2. Ensure GitHub tool is active
3. Verify you're using the correct sys_id

### Cannot Find Orchestration Tools Table

**Possible Reasons**:
1. ServiceNow DevOps plugin not installed
2. User lacks permissions to view DevOps tables
3. Different ServiceNow version uses different table names

**Fix**:
1. Contact your ServiceNow administrator
2. Request access to DevOps tables
3. Ask admin to verify ServiceNow DevOps plugin installation

## Known Tool ID from Your Instance

Based on previous documentation and workflow configurations, your tool ID is:

```
SN_ORCHESTRATION_TOOL_ID: 2fe9c38bc36c72d0e1bbf0cb050131cc
```

This value appears in multiple places:
- `docs/SERVICENOW-SECURITY-INTEGRATION.md`
- `docs/SERVICENOW-SECURITY-WEBHOOK-FIX.md`
- Workflow files referencing the tool

You can verify this is correct by checking the ServiceNow table.

## ServiceNow DevOps Documentation References

- **GitHub Actions Integration**: ServiceNow DevOps supports GitHub Actions from v2.0.0+
- **Token Authentication**: Available from v4.0.0 for Change Automation, v2.0.0 for other actions
- **Supported Actions**:
  - ServiceNow DevOps Change Automation
  - ServiceNow DevOps Register Artifact
  - ServiceNow DevOps Register Package
  - ServiceNow DevOps Security Result
  - ServiceNow DevOps Get Change
  - ServiceNow DevOps Update Change

## Next Steps

1. **Find the integration token** using the methods above
2. **Configure GitHub secrets** with the three required values
3. **Trigger a test workflow** to verify authentication works
4. **Monitor workflow logs** for successful ServiceNow integration

## Support

If you're unable to locate the integration token after trying these approaches:

1. **Contact your ServiceNow administrator** - They can:
   - Verify the GitHub tool exists
   - Provide the integration token
   - Check your user permissions

2. **Check ServiceNow community forums** - Search for:
   - "GitHub tool integration token"
   - "sn_devops_orchestration_tool"

3. **ServiceNow Support** - If administrator access is unavailable:
   - Open a support case
   - Reference: GitHub Actions integration setup
   - Provide: Instance URL, tool name

## Related Documentation

- [ServiceNow Security Integration](SERVICENOW-SECURITY-INTEGRATION.md)
- [ServiceNow Security Webhook Fix](SERVICENOW-SECURITY-WEBHOOK-FIX.md)
- [GitHub Actions Workflows](.github/workflows/)
- ServiceNow official docs: [GitHub Actions integration with DevOps](https://docs.servicenow.com/bundle/washingtondc-devops/page/product/enterprise-dev-ops/concept/github-actions-integration-with-devops.html)

---

**Last Updated**: 2025-10-21
**Status**: Awaiting integration token discovery
**Next**: Configure secrets and test workflow
