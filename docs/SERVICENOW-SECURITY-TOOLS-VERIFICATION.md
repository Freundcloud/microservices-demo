# ServiceNow Security Tools Integration - Verification Guide

## Overview

This document explains where security tools are registered in ServiceNow and how to verify they're working correctly.

## Current Status ✅

**All 10 security tools successfully registered** in workflow run 18710902046:
1. CodeQL-Python
2. CodeQL-JavaScript
3. CodeQL-Go
4. CodeQL-Java
5. CodeQL-CSharp
6. Semgrep (SAST)
7. Trivy (Container/Filesystem)
8. Checkov (IaC)
9. tfsec (Terraform)
10. Polaris (Kubernetes Manifest)

## Integration Architecture

### How Security Tools Are Registered

```
GitHub Actions Workflow
  └── servicenow-devops-security-result@v3.1.0 action
        └── Creates security result records in ServiceNow
              ├── Links to Change Request (changeRequestNumber, changeRequestSysId)
              ├── Links to DevOps Tool (tool-id: 4c5e482cc3383214e1bbf0cb05013196)
              └── Stores scan results with security attributes
```

### ServiceNow Tables

| Table | Purpose |
|-------|---------|
| `sn_devops_tool` | GitHub integration tool record |
| `sn_devops_app` | DevOps application (Online Boutique) |
| `sn_devops_test_result` | Where security scan results are stored |
| `change_request` | Change requests with linked security results |

### Key Configuration

**GitHub Workflow** (`.github/workflows/servicenow-integration.yaml`):
```yaml
- name: Register Security Results
  uses: ServiceNow/servicenow-devops-security-result@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}  # 4c5e482cc3383214e1bbf0cb05013196
    security-result-attributes: >
      {
        "scanner": "CodeQL-Python",
        "projectName": "Freundcloud/microservices-demo",
        "scanId": "${{ github.run_id }}-codeql-python",
        "securityToolId": "codeql-python",
        "changeRequestNumber": "${{ needs.create-change-request.outputs.change_request_number }}",
        "changeRequestSysId": "${{ needs.create-change-request.outputs.change_request_sys_id }}"
      }
```

## Where to View Security Tools

### Option 1: Via Change Request

1. **Open Change Request** in ServiceNow:
   - Go to: https://calitiiltddemo3.service-now.com/now/devops-change/changes/
   - Find your change request (e.g., CHG0030052)
   - Open the change request

2. **Look for Security Tab/Section**:
   - Security results should appear in a "Security" or "Test Results" tab
   - Each scanner (CodeQL, Trivy, etc.) should have an entry

### Option 2: Via DevOps Application

1. **Open DevOps Application**:
   - URL: https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120

2. **Navigate to Security Tools Tab**:
   - Look for tab labeled "Security Tools" or "Security Results"
   - May need to configure form layout to show this tab

### Option 3: Via REST API (Verification)

```bash
# Check if security results exist
curl -s --user 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_test_result?sysparm_query=u_tool_idLIKE4c5e482cc3383214e1bbf0cb05013196&sysparm_limit=10" \
  | jq '.result | length'

# Should return number > 0 if security results are registered
```

## Troubleshooting

### Issue: Security Tools Tab Empty

**Possible Causes**:
1. **Tab Not Configured** - Security tab may not be visible on the form
2. **Wrong Workspace** - Viewing wrong change workspace (standard vs DevOps)
3. **Permissions** - User may not have permission to view security results
4. **Plugin Not Activated** - ServiceNow DevOps Security plugin not fully activated

**Solution A: Configure Form Layout**
1. Open DevOps Application record
2. Right-click form header → Configure → Form Layout
3. Look for "Security" or "Test Results" related list
4. Add to form if not present

**Solution B: Check Via API**
Use REST API query above to verify security results exist in database

**Solution C: Check System Logs**
1. Navigate to: All → System Logs → System Log → All
2. Filter by: Source contains "DevOps" or "Security"
3. Look for any errors related to security tool registration

### Issue: Security Results Not Linking to Change Request

**Check**:
1. Verify `changeRequestNumber` and `changeRequestSysId` are correctly passed
2. Check GitHub Actions workflow logs for security result registration
3. Confirm change request was created BEFORE security tools registration

**From Workflow Logs**:
```
✅ Step: Register Security Results (CodeQL-Python, codeql-python) - SUCCESS
✅ Step: Register Security Results (Trivy, trivy) - SUCCESS
```

All 10 security tools showed SUCCESS in workflow 18710902046.

### Issue: 403 or 401 Errors

**Cause**: User permissions or incorrect credentials

**Solution**:
1. Verify ServiceNow user has these roles:
   - `sn_devops.devops_user`
   - `sn_devops.integration_user`
   - `x_snd_ci.automation`
2. Verify credentials in GitHub Secrets
3. Test auth with curl:
```bash
curl -u 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool/4c5e482cc3383214e1bbf0cb05013196"
```

## Verification Checklist

After deployment with security scans:

- [ ] GitHub Actions workflow completes successfully
- [ ] All 10 "Register Security Results" jobs show SUCCESS
- [ ] Change request created (CHG#######)
- [ ] Security SARIF files uploaded as attachments to change request
- [ ] Work note added to change request with security scan summary
- [ ] Security results visible in ServiceNow (UI or API)

## API Verification Script

Save as `scripts/verify-security-tools.sh`:

```bash
#!/bin/bash

SERVICENOW_INSTANCE="https://calitiiltddemo3.service-now.com"
TOOL_ID="4c5e482cc3383214e1bbf0cb05013196"
USERNAME="github_integration"
PASSWORD="YOUR_PASSWORD"

echo "═══════════════════════════════════════════════════════════"
echo "🔒 ServiceNow Security Tools Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Verify DevOps Tool exists
echo "1. Verifying DevOps Tool..."
TOOL_RESPONSE=$(curl -s --user "$USERNAME:$PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/sn_devops_tool/$TOOL_ID")

if echo "$TOOL_RESPONSE" | jq -e '.result.sys_id' > /dev/null; then
  echo "   ✅ DevOps Tool found"
  echo "$TOOL_RESPONSE" | jq -r '.result | "   Tool: \(.name)"'
else
  echo "   ❌ DevOps Tool not found"
  exit 1
fi

echo ""

# 2. Check for security results
echo "2. Checking for security results..."
RESULTS_RESPONSE=$(curl -s --user "$USERNAME:$PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/sn_devops_test_result?sysparm_query=u_tool_id=$TOOL_ID&sysparm_limit=50")

RESULTS_COUNT=$(echo "$RESULTS_RESPONSE" | jq '.result | length')
echo "   Found $RESULTS_COUNT security result records"

if [ "$RESULTS_COUNT" -gt 0 ]; then
  echo ""
  echo "   Recent security scans:"
  echo "$RESULTS_RESPONSE" | jq -r '.result[] | "   - \(.u_name) (\(.sys_created_on))"' | head -10
else
  echo "   ⚠️  No security results found"
  echo "   This may mean:"
  echo "   - Security tools haven't run yet"
  echo "   - Results are in a different table"
  echo "   - User lacks permissions to view results"
fi

echo ""

# 3. Check recent change requests
echo "3. Checking recent change requests..."
CHG_RESPONSE=$(curl -s --user "$USERNAME:$PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/change_request?sysparm_query=category=DevOps^devops_change=true&sysparm_fields=number,short_description,sys_created_on&sysparm_limit=5&sysparm_order_by=sys_created_on DESC")

CHG_COUNT=$(echo "$CHG_RESPONSE" | jq '.result | length')
echo "   Found $CHG_COUNT recent DevOps change requests:"
echo "$CHG_RESPONSE" | jq -r '.result[] | "   - \(.number): \(.short_description)"'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Verification Complete"
echo "═══════════════════════════════════════════════════════════"
```

## Next Steps

1. **Run verification script** to confirm security tools are registered
2. **Check ServiceNow UI** to see security results in change requests
3. **Configure form layout** if security tabs are not visible
4. **Review workflow logs** for any errors in security tool registration

## Related Documentation

- [SERVICENOW-DEVOPS-CHANGE-SERVICES-FIX.md](SERVICENOW-DEVOPS-CHANGE-SERVICES-FIX.md) - Services association
- [SERVICENOW-TEST-RESULTS-INTEGRATION.md](SERVICENOW-TEST-RESULTS-INTEGRATION.md) - Test results upload workflow
- [GITHUB-SERVICENOW-ONBOARDING.md](GITHUB-SERVICENOW-ONBOARDING.md) - Complete integration setup

---

**Last Updated**: 2025-10-22
**Workflow Run**: 18710902046 (all 10 security tools registered successfully)
**Status**: Integration working correctly - verifying visibility in UI
