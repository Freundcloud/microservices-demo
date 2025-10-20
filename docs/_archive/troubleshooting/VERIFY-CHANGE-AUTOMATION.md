# Verify ServiceNow Change Automation Integration

> **Guide**: How to verify the ServiceNow DevOps Change Automation is working
> **Date**: 2025-10-16
> **Workflow**: deploy-with-servicenow.yaml
> **Action**: ServiceNow/servicenow-devops-change@v4.0.0

## 📋 Prerequisites

Before testing, ensure you have:

### Required GitHub Secrets

```bash
# Check all ServiceNow secrets are configured
gh secret list | grep SN_
```

**Must have these 3 secrets** (minimum):
- ✅ `SN_INSTANCE_URL` - Your ServiceNow instance URL (e.g., https://dev12345.service-now.com)
- ✅ `SN_DEVOPS_INTEGRATION_TOKEN` - DevOps integration token from ServiceNow
- ✅ `SN_ORCHESTRATION_TOOL_ID` - Tool ID for GitHub (from ServiceNow tool configuration)

**Optional secrets**:
- `SN_OAUTH_TOKEN` - OAuth token for CMDB updates (used in Job 5)
- `SN_DEVOPS_USER` - ServiceNow username (alternative auth method)
- `SN_DEVOPS_PASSWORD` - ServiceNow password (alternative auth method)

### Required ServiceNow Configuration

1. **DevOps Change Velocity plugin installed**
   - Navigate to: `System Definition > Plugins`
   - Search for: "DevOps Change Velocity"
   - Status must be: **Active**

2. **GitHub tool registered in ServiceNow**
   - Tool must be configured in ServiceNow
   - Tool ID must match `SN_ORCHESTRATION_TOOL_ID` secret

3. **Integration token generated**
   - Token must be active and not expired
   - Must have proper permissions for change management

---

## 🧪 Step-by-Step Verification

### Step 1: Verify Secrets Are Set

```bash
# Check secrets exist
gh secret list | grep -E "SN_INSTANCE_URL|SN_DEVOPS_INTEGRATION_TOKEN|SN_ORCHESTRATION_TOOL_ID"
```

**Expected output** (with timestamps):
```
SN_DEVOPS_INTEGRATION_TOKEN	2025-10-15T11:05:00Z
SN_INSTANCE_URL	            2025-10-14T16:52:19Z
SN_ORCHESTRATION_TOOL_ID	2025-10-15T11:07:00Z
```

If any are missing, set them:
```bash
gh secret set SN_INSTANCE_URL
gh secret set SN_DEVOPS_INTEGRATION_TOKEN
gh secret set SN_ORCHESTRATION_TOOL_ID
```

---

### Step 2: Test ServiceNow API Connectivity

Before running the workflow, test if GitHub Actions can reach your ServiceNow instance:

```bash
# Test from your local machine (simulates GitHub Actions runner)
SN_INSTANCE_URL="https://your-instance.service-now.com"
SN_TOKEN="your-token-here"

# Test authentication
curl -X GET \
  "${SN_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer ${SN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Expected response**: JSON with user data (HTTP 200)

**Common failures**:
- **401 Unauthorized**: Token is invalid or expired
- **403 Forbidden**: Token lacks required permissions
- **Connection timeout**: Instance URL is incorrect or blocked by firewall
- **500 Internal Server Error**: ServiceNow plugin issue

---

### Step 3: Trigger Test Deployment (Dev Environment)

Run a test deployment to the **dev** environment (auto-approves, no manual intervention):

```bash
# Trigger the workflow manually
gh workflow run deploy-with-servicenow.yaml \
  -f environment=dev

# Monitor the run
gh run watch
```

**What should happen**:
1. ✅ **Create Change Request** job succeeds
   - ServiceNow change request created
   - Change request number returned (e.g., CHG0001234)
   - Change request sys_id returned

2. ⏭️ **Wait for Approval** job skipped (dev auto-approves)

3. ✅ **Pre-Deployment Checks** job succeeds
   - AWS credentials validated
   - EKS cluster accessible
   - Namespace exists/created

4. ✅ **Deploy** job succeeds
   - Kustomize deployment applied
   - All pods running
   - Smoke tests pass
   - Change request updated to "Successful"

5. ✅ **Update CMDB** job succeeds
   - Deployment info sent to ServiceNow CMDB

---

### Step 4: Check Workflow Logs

```bash
# Get the most recent run
gh run list --workflow=deploy-with-servicenow.yaml --limit 1

# View run details
gh run view <run-id>

# View full logs
gh run view <run-id> --log
```

#### What to Look For in Logs:

**Job 1: Create Change Request**
```
✅ Create ServiceNow Change Request
   Using ServiceNow/servicenow-devops-change@v4.0.0

   Output variables:
   - change-request-number: CHG0001234
   - change-request-sys-id: abc123def456...
```

**Common Errors**:
```
❌ Error: Internal server error. An unexpected error occurred while processing the request.
   → ServiceNow API issue or plugin misconfiguration

❌ Error: 401 Unauthorized
   → Token invalid or expired

❌ Error: Tool ID not found
   → SN_ORCHESTRATION_TOOL_ID doesn't match registered tool in ServiceNow

❌ Error: Change request creation failed
   → Check ServiceNow change management configuration
```

---

### Step 5: Verify in ServiceNow UI

#### Method 1: Direct Link (from workflow logs)

The workflow creates a direct link to the change request:
```
https://<instance>.service-now.com/nav_to.do?uri=change_request.do?sys_id=<sys_id>
```

#### Method 2: Search in ServiceNow

1. **Log into ServiceNow**

2. **Navigate to Change Requests**:
   - Search for: "change request" in Application Navigator
   - Or use direct URL: `https://<instance>.service-now.com/nav_to.do?uri=change_request_list.do`

3. **Filter for recent changes**:
   - Filter by: `Short description` contains "microservices-demo"
   - Filter by: `Created` > last 24 hours
   - Sort by: `Created` descending

4. **Open the change request** and verify:

   **Header Information**:
   - **Number**: CHG0001234 (example)
   - **State**: Closed (for dev) or Awaiting Approval (for qa/prod)
   - **Environment**: dev/qa/prod
   - **Triggered by**: GitHub Actions user

   **Description Tab**:
   ```
   Automated deployment via GitHub Actions.

   Environment: dev
   Commit: abc123def456...
   Repository: Freundcloud/microservices-demo
   Triggered by: <github-username>
   ```

   **Planning Tab**:
   - **Implementation Plan**: Step-by-step deployment process
   - **Backout Plan**: Rollback commands
   - **Test Plan**: Verification steps

   **Notes Tab**:
   - Should show workflow execution updates
   - Deployment success/failure messages

   **Related Records**:
   - May show CMDB CI records (if CMDB integration is active)
   - Pipeline execution records

---

### Step 6: Test QA/Prod Deployment (With Approval)

For QA or Prod, the workflow will **wait for manual approval** in ServiceNow:

```bash
# Trigger QA deployment
gh workflow run deploy-with-servicenow.yaml \
  -f environment=qa

# Workflow will pause at "Wait for Change Approval" job
```

**In ServiceNow**:

1. **Navigate to the change request** (created by workflow)

2. **Change state** from "New" to "Scheduled"

3. **Approve the change**:
   - Click "Approve" button
   - Or set State to "Implement"

4. **GitHub Actions continues**:
   - Polls ServiceNow every 30 seconds
   - Proceeds with deployment when approved
   - Times out after 1 hour if not approved

---

### Step 7: Test Rollback Scenario

Trigger a deployment that will fail to verify rollback works:

1. **Temporarily break the deployment**:
   ```bash
   # Edit a deployment to use invalid image
   # Commit and push
   ```

2. **Trigger deployment**:
   ```bash
   gh workflow run deploy-with-servicenow.yaml -f environment=dev
   ```

3. **Verify rollback job runs**:
   - Deployment fails
   - Rollback job automatically triggers
   - All services rolled back to previous version
   - Change request updated as "Unsuccessful"

---

## 🔧 Troubleshooting

### Issue 1: "Internal server error" from ServiceNow

**Possible causes**:
1. ServiceNow DevOps plugin not activated
2. Plugin version incompatible with action version
3. ServiceNow instance under maintenance
4. API rate limiting

**Solution**:

```bash
# Check ServiceNow system status
curl -s "${SN_INSTANCE_URL}/api/now/table/sys_properties?sysparm_query=name=instance.status" \
  -H "Authorization: Bearer ${SN_TOKEN}"

# Verify DevOps plugin is active
# In ServiceNow: System Definition > Plugins > Search "DevOps"
```

---

### Issue 2: "401 Unauthorized" Error

**Possible causes**:
- Token expired
- Token revoked
- Token doesn't have required permissions

**Solution**:

1. **Regenerate token in ServiceNow**:
   - Search for "DevOps Integration Token" in Application Navigator
   - Create new token
   - Copy token value

2. **Update GitHub secret**:
   ```bash
   gh secret set SN_DEVOPS_INTEGRATION_TOKEN
   # Paste the new token when prompted
   ```

3. **Retry workflow**:
   ```bash
   gh run rerun <run-id>
   ```

---

### Issue 3: "Tool ID not found"

**Possible causes**:
- GitHub tool not registered in ServiceNow
- Tool ID in secret doesn't match ServiceNow configuration

**Solution**:

1. **Find your tool ID in ServiceNow**:
   - Search for "DevOps Tool" in Application Navigator
   - Find the GitHub tool record
   - Copy the "Tool ID" field value

2. **Update GitHub secret**:
   ```bash
   gh secret set SN_ORCHESTRATION_TOOL_ID
   # Paste the Tool ID from ServiceNow
   ```

---

### Issue 4: Workflow Hangs on "Wait for Approval"

**Possible causes**:
- Change request not approved in ServiceNow
- Change request in wrong state
- Polling timeout (1 hour)

**Solution**:

1. **Check change request state** in ServiceNow
2. **Approve the change** or set state to "Implement"
3. **Workflow will continue** within 30 seconds
4. **If timeout occurs**, manually re-run the workflow

---

### Issue 5: CMDB Updates Not Working

**Symptom**: Job 5 (Update CMDB) is skipped or fails

**Possible causes**:
- `SN_OAUTH_TOKEN` secret not set
- OAuth token invalid
- CMDB table permissions missing

**Solution**:

```bash
# Check if OAuth token is set
gh secret list | grep SN_OAUTH_TOKEN

# If missing, set it
gh secret set SN_OAUTH_TOKEN
```

**Note**: CMDB updates are optional. The workflow will succeed even if this step fails.

---

## 📊 Expected Workflow Behavior

### Dev Environment Deployment

| Job | Status | Duration | Notes |
|-----|--------|----------|-------|
| Create Change Request | ✅ Success | ~5s | Auto-created in ServiceNow |
| Wait for Approval | ⏭️ Skipped | 0s | Dev auto-approves |
| Pre-Deployment Checks | ✅ Success | ~15s | Validates EKS access |
| Deploy | ✅ Success | ~2-3min | Deploys via Kustomize |
| Update CMDB | ✅ Success | ~10s | Updates service records |
| Rollback | ⏭️ Skipped | 0s | Only runs on failure |

**Total time**: ~3-4 minutes

---

### QA/Prod Environment Deployment

| Job | Status | Duration | Notes |
|-----|--------|----------|-------|
| Create Change Request | ✅ Success | ~5s | Created in ServiceNow |
| Wait for Approval | ⏸️ Waiting | 0-60min | Waits for manual approval |
| Pre-Deployment Checks | ✅ Success | ~15s | Runs after approval |
| Deploy | ✅ Success | ~3-5min | Deploys via Kustomize |
| Update CMDB | ✅ Success | ~10s | Updates service records |
| Rollback | ⏭️ Skipped | 0s | Only runs on failure |

**Total time**: Depends on approval time (typically 5-30 minutes with approval)

---

## ✅ Verification Checklist

Use this checklist to confirm everything is working:

### GitHub Configuration
- [ ] All required secrets are set (SN_INSTANCE_URL, SN_DEVOPS_INTEGRATION_TOKEN, SN_ORCHESTRATION_TOOL_ID)
- [ ] Workflow file exists at `.github/workflows/deploy-with-servicenow.yaml`
- [ ] Workflow uses `ServiceNow/servicenow-devops-change@v4.0.0` action

### ServiceNow Configuration
- [ ] DevOps Change Velocity plugin is installed and active
- [ ] GitHub tool is registered in ServiceNow
- [ ] Tool ID matches the GitHub secret
- [ ] Integration token is active and has proper permissions
- [ ] Change management is configured

### Test Execution
- [ ] Dev deployment workflow runs successfully
- [ ] Change request is created in ServiceNow
- [ ] Change request contains correct information
- [ ] Deployment executes and completes
- [ ] Change request is updated to "Successful" or "Unsuccessful"
- [ ] CMDB is updated (if OAuth token is configured)

### QA/Prod Testing
- [ ] QA/Prod deployment waits for approval
- [ ] Approving change in ServiceNow resumes workflow
- [ ] Deployment proceeds after approval
- [ ] Change request is properly closed

### Rollback Testing
- [ ] Failed deployment triggers rollback job
- [ ] Services are rolled back successfully
- [ ] Change request is marked as "Unsuccessful"

---

## 🔗 Additional Resources

### ServiceNow Documentation
- [DevOps Change Automation](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-change-automation.html)
- [Change Management](https://docs.servicenow.com/bundle/vancouver-it-service-management/page/product/change-management/concept/c_ITILChangeManagement.html)

### GitHub Actions
- [ServiceNow DevOps Change Action](https://github.com/ServiceNow/servicenow-devops-change)
- [GitHub Marketplace - ServiceNow DevOps Change Automation](https://github.com/marketplace/actions/servicenow-devops-change-automation)

### Project Documentation
- [ServiceNow Setup Checklist](../SERVICENOW-SETUP-CHECKLIST.md)
- [ServiceNow Integration Plan](../SERVICENOW-INTEGRATION-PLAN.md)
- [Deploy with ServiceNow Workflow](/.github/workflows/deploy-with-servicenow.yaml)

---

## 🆘 Getting Help

If you encounter issues:

1. **Check workflow logs**:
   ```bash
   gh run view <run-id> --log-failed
   ```

2. **Test ServiceNow connectivity**:
   ```bash
   curl -v "${SN_INSTANCE_URL}/api/now/table/sys_user?sysparm_limit=1" \
     -H "Authorization: Bearer ${SN_DEVOPS_INTEGRATION_TOKEN}"
   ```

3. **Verify ServiceNow configuration**:
   - Check plugin status
   - Verify tool registration
   - Check token permissions

4. **Review ServiceNow logs**:
   - Navigate to: `System Logs > System Log > All`
   - Filter by: `Source` = DevOps
   - Look for errors related to change automation

5. **Common error messages and solutions**:
   - See Troubleshooting section above

---

**Last Updated**: 2025-10-16
**Maintained By**: DevOps Team
**Revision**: 1.0 - Initial verification guide
