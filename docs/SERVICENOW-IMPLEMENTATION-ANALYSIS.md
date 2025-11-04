# ServiceNow Implementation Status

> **Last Updated**: 2025-11-04
> **Status**: TESTING DevOps Change Control API
> **Current Workflow**: `servicenow-change-devops-api.yaml` (TEMPORARY)

---

## ⚠️ IMPORTANT: Temporary Testing Configuration

**MASTER-PIPELINE.yaml is currently configured to use the experimental DevOps API workflow.**

### What Changed

**File**: `.github/workflows/MASTER-PIPELINE.yaml` (Line 572)

```yaml
# BEFORE (Production - Table API):
uses: ./.github/workflows/servicenow-change-rest.yaml

# NOW (Testing - DevOps API):
uses: ./.github/workflows/servicenow-change-devops-api.yaml
```

### Why This Is Temporary

This configuration is for **TESTING ONLY** to compare:
- ✅ **Auto-close functionality** (DevOps API feature)
- ✅ **DevOps workspace visibility** (sn_devops_change_reference table)
- ❌ **Loss of custom fields** (40+ u_* fields not supported by DevOps API)
- ❌ **Loss of compliance data** (GitHub context, security scans, test results)

### Expected Behavior During Testing

**What Will Work**:
- ✅ Change requests created successfully
- ✅ Auto-close on deployment success
- ✅ Visible in ServiceNow DevOps workspace
- ✅ Records in `sn_devops_change_reference` table

**What Will NOT Work**:
- ❌ Custom fields (u_github_repo, u_environment, u_security_scan_status, etc.)
- ❌ Test results tracking (u_unit_test_*, u_sonarcloud_*)
- ❌ GitHub context (u_github_commit, u_github_actor, u_correlation_id)
- ❌ Compliance audit trail (missing critical data)

### How to Verify Testing

1. **Trigger a deployment**:
   ```bash
   git commit --allow-empty -m "test: DevOps API comparison test"
   git push origin main
   ```

2. **Check both tables in ServiceNow**:
   ```bash
   # Standard change_request table (basic fields only)
   ./scripts/check-servicenow-tables.sh

   # DevOps change reference table (should have new records)
   curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_reference?sysparm_limit=1" \
     | jq '.result[0]'
   ```

3. **Compare with previous Table API approach**:
   - See [SERVICENOW-API-COMPARISON.md](SERVICENOW-API-COMPARISON.md)
   - Use comparison checklist in [SERVICENOW-DEVOPS-API-TESTING.md](SERVICENOW-DEVOPS-API-TESTING.md)

### How to Revert to Production Configuration

**IMPORTANT**: After testing, revert to Table API for production use.

```bash
# Edit .github/workflows/MASTER-PIPELINE.yaml line 572
# Change FROM:
uses: ./.github/workflows/servicenow-change-devops-api.yaml

# Change TO:
uses: ./.github/workflows/servicenow-change-rest.yaml

# Also update job name (line 560):
name: "📝 ServiceNow Change Request"  # Remove "(TESTING DevOps API)"

# Remove testing comment (lines 570-583)

# Restore custom field inputs (lines 575-596 from previous version)
```

**Quick Revert Script**:
```bash
# Restore from git history
git show HEAD~1:.github/workflows/MASTER-PIPELINE.yaml > .github/workflows/MASTER-PIPELINE.yaml.backup

# Or manually edit and restore lines 559-597
```

---

## Current Implementation Details

### API Endpoint Being Tested

**DevOps Change Control API**:
- Endpoint: `/api/sn_devops/v1/devops/orchestration/changeControl?toolId={tool_id}`
- Method: POST
- Authentication: Basic Auth
- Required Headers: `sn_devops_orchestration_tool_id: {tool_id}`
- Required Query Parameter: `toolId={tool_id}` (CRITICAL - API returns 400 without this)
- Payload Structure:
  ```json
  {
    "autoCloseChange": true,
    "setCloseCode": true,
    "callbackURL": "https://github.com/{repo}/actions/runs/{run_id}",
    "orchestrationTaskURL": "https://github.com/{repo}/actions/runs/{run_id}",
    "attributes": {
      "short_description": "...",
      "description": "...",
      "implementation_plan": "...",
      "backout_plan": "...",
      "test_plan": "...",
      "assignment_group": "...",
      "assigned_to": "..."
    }
  }
  ```
  **Required Fields**:
  - `callbackURL` - URL for ServiceNow to callback (GitHub Actions run URL)
  - `orchestrationTaskURL` - URL to orchestration task (GitHub Actions run URL)

### Validation Against Official Documentation

**Sources**:
- ServiceNow GitHub Repository: https://github.com/ServiceNow/servicenow-devops-change
- ServiceNow Community Forums
- ServiceNow Product Documentation (Vancouver/Washington DC releases)

**Confirmed Implementation Details**:
1. ✅ **Endpoint Path**: `/api/sn_devops/v1/devops/orchestration/changeControl` - Correct
2. ✅ **Query Parameter**: `toolId` required - Correctly implemented
3. ✅ **Header**: `sn_devops_orchestration_tool_id` - Correctly implemented
4. ✅ **Callback URLs**: Both `callbackURL` and `orchestrationTaskURL` required - Correctly implemented
5. ✅ **Supported Fields**: All standard change_request fields except `risk`, `impact`, `risk_impact_analysis`
6. ✅ **Custom Fields**: NOT supported by DevOps API (as documented)

**Response Behavior Validation**:
- `changeControl: false` → Deployment Gate mode (immediate approval, no CR number)
  - Change payload stored in `sn_devops_callback` table with state "Ready to process"
  - Pipeline continues until deployment gate
  - Change information displayed in GitHub Actions console logs
- `changeControl: true` → Traditional Change Request mode
  - Returns `changeRequestNumber` and `changeRequestSysId`
  - Visible in `sn_devops_change_reference` table
  - Requires manual approval (unless auto-approval configured)

**Our Implementation Status**: ✅ **FULLY COMPLIANT** with ServiceNow DevOps Change Control API specification

### Features Being Tested

1. **Auto-Close Functionality**
   - Change requests automatically close when deployment succeeds
   - `close_code` set to "successful"
   - `close_notes` populated automatically

2. **DevOps Workspace Integration**
   - Changes visible in ServiceNow DevOps dashboard
   - Records created in `sn_devops_change_reference` table
   - Linked to other DevOps entities (artifacts, tests)

3. **Simplified Workflow**
   - No custom field management required
   - Fewer inputs to workflow
   - Cleaner payload structure

### Limitations Accepted During Testing

1. **No Custom Fields** - Cannot track:
   - GitHub repo, branch, commit, actor
   - Environment (dev/qa/prod)
   - Security scan results
   - Unit test results
   - SonarCloud metrics
   - Deployment metadata

2. **Limited Compliance Data**:
   - Missing correlation ID for traceability
   - No security scan status
   - No test coverage metrics
   - No code quality data

3. **Reduced Reporting Capability**:
   - Cannot filter by GitHub repo
   - Cannot track deployment patterns
   - Cannot measure test quality trends

---

## Testing Checklist

Use this checklist during testing period:

### Prerequisites
- [ ] ServiceNow DevOps plugin installed and active
- [ ] `SN_ORCHESTRATION_TOOL_ID` configured in GitHub Secrets
- [ ] Tool registration verified in ServiceNow

### Test Execution
- [ ] Triggered test deployment
- [ ] Change request created successfully
- [ ] Change number captured: __________
- [ ] Auto-close functionality worked: ☐ Yes ☐ No
- [ ] Visible in DevOps workspace: ☐ Yes ☐ No
- [ ] Record in sn_devops_change_reference: ☐ Yes ☐ No

### Comparison Analysis
- [ ] Compared with previous Table API change request
- [ ] Documented missing custom fields
- [ ] Evaluated impact on compliance reporting
- [ ] Assessed auto-close benefit vs. custom field loss

### Decision
- [ ] Keep DevOps API (auto-close priority)
- [ ] Revert to Table API (compliance priority)
- [ ] Hybrid approach (use both APIs)

**Decision Date**: __________
**Decided By**: __________
**Rationale**: __________

---

## Production Configuration (Table API)

### When to Use Table API

**Choose Table API if**:
- ✅ SOC 2 / ISO 27001 / NIST CSF compliance required
- ✅ Need complete GitHub context and audit trail
- ✅ Need security scan and test result tracking
- ✅ Custom reporting required
- ✅ Correlation between changes and deployments needed

### Table API Features

**Endpoint**: `/api/now/table/change_request`

**Custom Fields** (40+ fields):
- GitHub Context: repo, commit, branch, actor, workflow URL
- Environment: dev/qa/prod, deployed version, previous version
- Security: scan status, vulnerability counts, critical/high/medium
- Testing: unit test status/results/coverage, SonarCloud metrics
- Deployment: services updated, infrastructure changes, method

**Benefits**:
- Complete audit trail for compliance
- Rich reporting and filtering
- Correlation with GitHub Actions
- Test results linked to changes

**Limitations**:
- Manual close process required
- Not visible in DevOps workspace
- More complex workflow inputs

---

## Experimental Configuration (DevOps API)

### When to Use DevOps API

**Choose DevOps API if**:
- ✅ Auto-close functionality is critical
- ✅ DevOps workspace visibility important
- ✅ Integration with other DevOps tools needed
- ❌ Custom fields NOT required
- ❌ Basic change tracking sufficient

### DevOps API Features

**Endpoint**: `/api/sn_devops/v1/devops/orchestration/changeControl`

**Standard Fields Only**:
- Short description, description
- Implementation plan, backout plan, test plan
- Assignment group, assigned to
- Category, subcategory, justification

**Benefits**:
- Auto-close on deployment success
- Visible in DevOps workspace
- Simpler payload structure
- Integrated with DevOps tooling

**Limitations**:
- No custom fields support
- Limited GitHub context
- No security/test result tracking
- Reduced compliance data

---

## References

- **API Comparison**: [SERVICENOW-API-COMPARISON.md](SERVICENOW-API-COMPARISON.md)
- **Testing Guide**: [SERVICENOW-DEVOPS-API-TESTING.md](SERVICENOW-DEVOPS-API-TESTING.md)
- **Integration Fix**: [SERVICENOW-INTEGRATION-FIX.md](SERVICENOW-INTEGRATION-FIX.md)
- **DevOps API Workflow**: [.github/workflows/servicenow-change-devops-api.yaml](../.github/workflows/servicenow-change-devops-api.yaml)
- **Table API Workflow**: [.github/workflows/servicenow-change-rest.yaml](../.github/workflows/servicenow-change-rest.yaml)

---

**Document Version**: 1.0 (Testing Phase)
**Status**: DevOps API Testing In Progress
**Expected Completion**: After first test deployment analysis
**Next Review**: After decision made on which API to use
