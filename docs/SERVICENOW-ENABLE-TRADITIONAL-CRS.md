# How to Enable Traditional Change Requests (changeControl: true)

> **Problem**: DevOps Change Control API returns `changeControl: false` (deployment gates)
> **Solution**: Configure ServiceNow DevOps Change Velocity or use Table API
> **Date**: 2025-11-04

---

## Understanding the Problem

When you call the ServiceNow DevOps Change Control API, you're getting:

```json
{
  "result": {
    "changeControl": false,
    "status": "Success"
  }
}
```

**What this means**:
- ✅ The API call is **working correctly**
- ℹ️ ServiceNow created a **Deployment Gate** instead of a traditional Change Request
- ⚠️ No CR number is returned because no CR was created
- ✅ The deployment is **automatically approved** (fast deployment mode)

**Why this happens**:
- Your ServiceNow instance is configured for **deployment gates** (fast deployments)
- DevOps Change Velocity settings control this behavior
- Default configuration is `changeControl: false` (deployment gates)

---

## Solution 1: Configure ServiceNow for Traditional CRs ⚙️

### Prerequisites

- ServiceNow administrator access
- DevOps Change Velocity plugin installed and active
- GitHub tool registered in ServiceNow DevOps

### Step-by-Step Configuration

#### 1. Check Current Configuration

Run the diagnostic script:

```bash
# Load ServiceNow credentials
source .envrc

# Run diagnostic
./scripts/check-servicenow-change-velocity.sh
```

This will show:
- Plugin status
- Tool registration
- Current change control configuration
- Recent API calls

#### 2. Install DevOps Change Velocity Plugin (If Not Active)

**In ServiceNow**:

1. Navigate to: `System Applications` → `All Available Applications`
2. Search: `DevOps Change Velocity`
3. Click `Install` button
4. Wait for installation to complete (~5-10 minutes)
5. Verify installation: Search for `DevOps` in Application Navigator

#### 3. Configure Change Control Settings

**Navigation Paths** (try in order until you find one that works):

**Method 1: Application Navigator Search** (Most Reliable):
1. Click **"All"** in the top-left navigation
2. Search for one of these terms:
   - `change velocity`
   - `change control config`
   - `devops config`
   - `tool configuration`
3. Look for: `DevOps Change Control Config` or similar

**Method 2: Try These Direct URLs**:
```
# Option 1: Direct table list (most common)
https://YOUR-INSTANCE.service-now.com/sn_devops_change_control_config_list.do

# Option 2: Modern DevOps UI
https://YOUR-INSTANCE.service-now.com/$devops.do

# Option 3: Navigation redirect
https://YOUR-INSTANCE.service-now.com/nav_to.do?uri=sn_devops_change_control_config_list.do
```

**Method 3: Via API** (check if feature exists):
```bash
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_change_control_config" \
  | jq .
```

**Note**: The exact navigation path varies by ServiceNow version and edition. Some instances (especially Personal Developer Instances) may not have this table/feature.

**Settings to Configure**:

Find your tool (GitHub Actions) and set:

| Field | Value | Description |
|-------|-------|-------------|
| **Change Control Enabled** | ✅ `true` | Enable traditional change requests |
| **Create Change Request** | ✅ `true` | Always create CRs (not deployment gates) |
| **Change Type** | `Normal` or `Standard` | Type of change request to create |
| **Auto Approve** | `false` (for qa/prod) | Require manual approval |
| **Auto Close** | `true` | Auto-close on deployment success |

**Screenshot of Expected Configuration**:
```
┌─────────────────────────────────────────────────────────┐
│ Change Control Configuration                            │
├─────────────────────────────────────────────────────────┤
│ Tool:                    GitHub Actions                  │
│ Change Control Enabled:  ☑ true                         │
│ Create Change Request:   ☑ true                         │
│ Change Type:             Normal                          │
│ Auto Approve:            ☐ false (qa/prod)              │
│                          ☑ true  (dev)                   │
│ Auto Close:              ☑ true                          │
└─────────────────────────────────────────────────────────┘
```

#### 4. Configure Environment-Specific Rules (Optional)

Create different rules for different environments:

**Dev Environment**:
- Change Control Enabled: `true`
- Create Change Request: `true`
- Auto Approve: `true` (fast deployments)
- Change Type: `Standard`

**QA Environment**:
- Change Control Enabled: `true`
- Create Change Request: `true`
- Auto Approve: `false` (manual approval)
- Change Type: `Normal`

**Prod Environment**:
- Change Control Enabled: `true`
- Create Change Request: `true`
- Auto Approve: `false` (manual approval)
- Change Type: `Normal`
- CAB Required: `true`

#### 5. Test the Configuration

Trigger a deployment and check the API response:

**Expected Response (After Configuration)**:
```json
{
  "result": {
    "changeControl": true,
    "status": "Success",
    "changeRequestNumber": "CHG0030123",
    "changeRequestSysId": "abc123def456..."
  }
}
```

**Verification Steps**:

1. **Trigger deployment**:
   ```bash
   git commit --allow-empty -m "test: Verify changeControl: true"
   git push origin main
   ```

2. **Check workflow output**:
   - Look for: `"changeControl": true`
   - Look for: `changeRequestNumber: CHG0030XXX`

3. **Verify in ServiceNow**:
   - Standard change_request table: Should have new CR
   - sn_devops_change_reference table: Should have matching record
   - DevOps workspace: Should show the change

---

## Solution 2: Use Table API Instead (Immediate) 🚀

**Recommended for production** because:
- ✅ **Always creates traditional CRs** with CR numbers
- ✅ **Supports 40+ custom fields** for compliance
- ✅ **No ServiceNow configuration required**
- ✅ **Complete audit trail** (SOC 2, ISO 27001, NIST CSF)

### Quick Revert to Table API

Edit `.github/workflows/MASTER-PIPELINE.yaml` line 572:

```yaml
# Change FROM (DevOps API with deployment gates):
uses: ./.github/workflows/servicenow-change-devops-api.yaml

# Change TO (Table API with traditional CRs):
uses: ./.github/workflows/servicenow-change-rest.yaml
```

**Also revert lines 575-583** to restore custom field inputs:

```yaml
with:
  environment: ${{ needs.pipeline-init.outputs.environment }}
  short_description: 'Deploy microservices to ${{ needs.pipeline-init.outputs.environment }}'
  # Custom fields (supported by Table API)
  services_deployed: ${{ needs.detect-service-changes.outputs.changed_services_json }}
  infrastructure_changes: ${{ needs.detect-terraform-changes.outputs.has_changes }}
  security_scan_status: ${{ needs.security-scans.outputs.overall_status }}
  critical_vulnerabilities: ${{ needs.security-scans.outputs.critical_count }}
  high_vulnerabilities: ${{ needs.security-scans.outputs.high_count }}
  medium_vulnerabilities: ${{ needs.security-scans.outputs.medium_count }}
  unit_test_status: ${{ needs.unit-test-summary.outputs.status }}
  unit_test_total: ${{ needs.unit-test-summary.outputs.total }}
  unit_test_passed: ${{ needs.unit-test-summary.outputs.passed }}
  unit_test_failed: ${{ needs.unit-test-summary.outputs.failed }}
  unit_test_coverage: ${{ needs.unit-test-summary.outputs.coverage }}
  sonarcloud_status: ${{ needs.sonarcloud-scan.outputs.quality_gate }}
  sonarcloud_bugs: ${{ needs.sonarcloud-scan.outputs.bugs }}
  sonarcloud_vulnerabilities: ${{ needs.sonarcloud-scan.outputs.vulnerabilities }}
  sonarcloud_code_smells: ${{ needs.sonarcloud-scan.outputs.code_smells }}
  sonarcloud_coverage: ${{ needs.sonarcloud-scan.outputs.coverage }}
  previous_version: ${{ needs.get-deployed-version.outputs.version }}
```

**Commit and test**:
```bash
git add .github/workflows/MASTER-PIPELINE.yaml
git commit -m "revert: Switch back to Table API for traditional change requests"
git push origin main
```

---

## Solution 3: Hybrid Approach (Best of Both Worlds) 🎯

Use **different APIs for different environments**:

- **Dev**: DevOps API with deployment gates (fast, automated)
- **QA/Prod**: Table API with custom fields (compliance, approval)

### Implementation

Edit `.github/workflows/MASTER-PIPELINE.yaml`:

```yaml
servicenow-change:
  name: "📝 ServiceNow Change Request"
  needs: [pipeline-init, ...]
  uses: ${{ needs.pipeline-init.outputs.environment == 'dev' && './.github/workflows/servicenow-change-devops-api.yaml' || './.github/workflows/servicenow-change-rest.yaml' }}
  secrets: inherit
  with:
    environment: ${{ needs.pipeline-init.outputs.environment }}
    # ... rest of inputs
```

**Benefits**:
- ✅ **Dev**: Fast deployments with deployment gates (no manual approval)
- ✅ **QA/Prod**: Traditional CRs with complete audit trail
- ✅ **Flexibility**: Best API for each environment's needs

---

## Comparison: Deployment Gates vs Traditional CRs

| Feature | Deployment Gates (changeControl: false) | Traditional CRs (changeControl: true) |
|---------|----------------------------------------|--------------------------------------|
| **Speed** | ⚡ Immediate approval | ⏱️ Manual approval (qa/prod) |
| **CR Number** | ❌ None | ✅ CHG0030XXX |
| **Custom Fields** | ❌ Not supported | ✅ 40+ fields (Table API only) |
| **Audit Trail** | ⚠️ Limited | ✅ Complete |
| **Compliance** | ⚠️ Basic | ✅ SOC 2, ISO 27001, NIST CSF |
| **Use Case** | Dev/test environments | QA/Prod environments |
| **Visibility** | ✅ DevOps workspace | ✅ Change Management + DevOps |

---

## Troubleshooting

### Issue: Plugin Not Found

**Symptom**: DevOps Change Velocity menu not visible

**Solutions**:
1. Check ServiceNow edition (requires ITSM Professional or higher)
2. Install plugin: `System Applications` → `All Available Applications` → `DevOps Change Velocity`
3. Activate plugin: `System Plugins` → Search `DevOps` → Activate

### Issue: Configuration Not Taking Effect

**Symptom**: Still getting `changeControl: false` after configuration

**Solutions**:

1. **Clear ServiceNow cache**:
   ```
   Navigate: System Diagnostics → Cache Statistics → Clear Cache
   ```

2. **Verify tool ID is correct**:
   ```bash
   ./scripts/check-servicenow-change-velocity.sh
   ```

3. **Check if configuration is saved**:
   ```
   Navigate: DevOps → Change Velocity → Configuration
   Verify: Change Control Enabled = true
   Verify: Create Change Request = true
   ```

4. **Test with direct API call**:
   ```bash
   curl -X POST \
     -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     -H "Content-Type: application/json" \
     -H "sn_devops_orchestration_tool_id: $SN_ORCHESTRATION_TOOL_ID" \
     -d '{
       "autoCloseChange": false,
       "setCloseCode": false,
       "callbackURL": "https://github.com/test",
       "orchestrationTaskURL": "https://github.com/test",
       "attributes": {
         "short_description": "Test CR creation"
       }
     }' \
     "$SERVICENOW_INSTANCE_URL/api/sn_devops/v1/devops/orchestration/changeControl?toolId=$SN_ORCHESTRATION_TOOL_ID"
   ```

### Issue: Access Denied / 403 Error

**Symptom**: API returns 403 Forbidden

**Solutions**:

1. **Check user permissions**:
   - User needs: `sn_devops.devops_user` role
   - User needs: `itil` role for change management

2. **Verify tool registration**:
   - Tool must be registered in ServiceNow DevOps
   - Tool ID must match `SN_ORCHESTRATION_TOOL_ID`

3. **Check ACLs (Access Control Lists)**:
   ```
   Navigate: System Security → Access Control (ACL)
   Search: sn_devops_change_control_config
   Verify: Read/Write permissions for devops_user role
   ```

---

## Recommendation Summary

### For Testing/Development
✅ **Use Deployment Gates** (changeControl: false)
- Fast deployments
- No manual approval needed
- Suitable for dev environment

### For Production/Compliance
✅ **Use Table API** (always traditional CRs)
- Complete audit trail
- 40+ custom fields
- SOC 2, ISO 27001, NIST CSF compliance
- Manual approval for qa/prod

### Best Practice
✅ **Hybrid Approach**
- Dev: DevOps API with deployment gates
- QA/Prod: Table API with custom fields

---

## Next Steps

1. **Check current configuration**:
   ```bash
   ./scripts/check-servicenow-change-velocity.sh
   ```

2. **Choose your solution**:
   - **Option A**: Configure ServiceNow for traditional CRs (DevOps API)
   - **Option B**: Revert to Table API (immediate solution)
   - **Option C**: Hybrid approach (best of both)

3. **Test your choice**:
   ```bash
   git commit --allow-empty -m "test: Verify changeControl configuration"
   git push origin main
   ```

4. **Verify results**:
   - Check GitHub Actions output
   - Verify CR created in ServiceNow
   - Confirm custom fields populated (if using Table API)

---

## References

- [SERVICENOW-DEVOPS-API-VALIDATION.md](SERVICENOW-DEVOPS-API-VALIDATION.md) - Complete API validation
- [SERVICENOW-API-COMPARISON.md](SERVICENOW-API-COMPARISON.md) - Table API vs DevOps API
- [SERVICENOW-DEVOPS-API-TESTING.md](SERVICENOW-DEVOPS-API-TESTING.md) - Testing guide
- [ServiceNow GitHub Repository](https://github.com/ServiceNow/servicenow-devops-change) - Official documentation

---

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Status**: Ready for implementation
