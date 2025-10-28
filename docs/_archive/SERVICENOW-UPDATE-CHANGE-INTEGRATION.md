# ServiceNow Change Request Update Integration

> Last Updated: 2025-01-28
> Status: ✅ Active
> Version: v3.1.0 (ServiceNow/servicenow-devops-update-change)

## Overview

Automatic change request status updates in ServiceNow when deployments complete. This closes the deployment lifecycle loop by informing ServiceNow whether deployments succeeded or failed, enabling proper change management tracking.

---

## How It Works

### Workflow Sequence

```
1. Create Change Request (servicenow-change job)
   ↓
2. Deploy Application (deploy-to-environment job)
   ↓
3. Run Smoke Tests (smoke-tests job)
   ↓
4. Update Change Request (update-servicenow-change job) ← NEW
   ↓
5. Pipeline Summary
```

### Workflow File

**Location:** `.github/workflows/servicenow-update-change.yaml`

**Trigger:** Called from master pipeline after deployment completes

**Action Used:** `ServiceNow/servicenow-devops-update-change@v3.1.0`

---

## Authentication

### Method: Basic Authentication

As requested, this integration uses **Basic Authentication** (not token-based):

```yaml
- name: Update Change Request in ServiceNow
  uses: ServiceNow/servicenow-devops-update-change@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
```

**Required Secrets:**
- `SERVICENOW_USERNAME` - Integration user account
- `SERVICENOW_PASSWORD` - User password
- `SERVICENOW_INSTANCE_URL` - ServiceNow instance URL

These are the **same secrets** used by other ServiceNow integrations in the pipeline.

---

## Change Request States

The workflow automatically updates the change request state based on deployment result:

| Deployment Result | ServiceNow State | State Value | Close Code | Description |
|-------------------|------------------|-------------|------------|-------------|
| ✅ Success | Implemented/Closed Complete | `3` | `successful` | Deployment completed successfully |
| ❌ Failure | Closed Incomplete | `4` | `unsuccessful` | Deployment failed |

**ServiceNow State Reference:**
- `-5` = New
- `0` = Assess
- `1` = Authorize
- `2` = Scheduled
- `3` = Implement (or Closed Complete)
- `4` = Review (or Closed Incomplete)
- `7` = Closed

---

## Work Notes Added

When the change request is updated, detailed work notes are automatically added:

```
Deployment to dev environment completed at 2025-01-28 16:30:45 UTC

**Deployment Result:** ✅ Successful

**Services Status:**
- Running Pods: 12
- Total Pods: 12
- Pod Health: ✅ All healthy

**Application Access:**
- Frontend URL: http://abc123.elb.amazonaws.com

**GitHub Workflow:**
- Run ID: 18880996498
- Run URL: https://github.com/Freundcloud/microservices-demo/actions/runs/18880996498
- Actor: olafkfreund
- Commit: abc123def456
- Branch: main

**Next Steps:**
- Verify application functionality
- Monitor application metrics
- Close change request if validation passes
```

For **failed deployments**, the next steps change to:
```
**Next Steps:**
- Review deployment logs: [GitHub workflow URL]
- Investigate failure cause
- Plan remediation or rollback
```

---

## Inputs

The workflow accepts these inputs from the master pipeline:

| Input | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `environment` | string | ✅ | Target environment | `dev`, `qa`, `prod` |
| `change_request_number` | string | ✅ | Change request ID | `CHG0030001` |
| `deployment_status` | string | ✅ | Deployment result | `success`, `failure` |
| `running_pods` | string | ❌ | Number of running pods | `12` |
| `total_pods` | string | ❌ | Total expected pods | `12` |
| `frontend_url` | string | ❌ | Frontend URL | `http://...` |

---

## Master Pipeline Integration

### Job Configuration

**Location:** `.github/workflows/MASTER-PIPELINE.yaml` lines 661-677

```yaml
update-servicenow-change:
  name: "📝 Update ServiceNow Change"
  needs: [pipeline-init, servicenow-change, deploy-to-environment, smoke-tests]
  if: |
    always() &&
    needs.servicenow-change.result == 'success' &&
    needs.servicenow-change.outputs.change_request_number != '' &&
    (needs.deploy-to-environment.result == 'success' || needs.deploy-to-environment.result == 'failure')
  uses: ./.github/workflows/servicenow-update-change.yaml
  secrets: inherit
  with:
    environment: ${{ needs.pipeline-init.outputs.environment }}
    change_request_number: ${{ needs.servicenow-change.outputs.change_request_number }}
    deployment_status: ${{ needs.deploy-to-environment.result }}
    running_pods: ${{ needs.deploy-to-environment.outputs.running_pods || '0' }}
    total_pods: ${{ needs.deploy-to-environment.outputs.total_pods || '0' }}
    frontend_url: ${{ needs.deploy-to-environment.outputs.frontend_url || '' }}
```

### Conditions for Execution

The job runs when **ALL** of these conditions are met:

1. ✅ `always()` - Run even if previous jobs failed
2. ✅ `servicenow-change.result == 'success'` - Change request was created
3. ✅ `change_request_number != ''` - Change request number is available
4. ✅ Deployment completed (either success OR failure) - Don't run if skipped

This ensures:
- ✅ Only updates if a change request exists
- ✅ Updates on both success and failure
- ✅ Doesn't run if deployment was skipped
- ✅ Doesn't fail the pipeline if update fails

---

## Important: Field Ordering

**Critical Requirement:** The `state` field **MUST BE LAST** in the JSON object.

From ServiceNow documentation:
> "State transitions require placing the state parameter last in the JSON object."

### Correct Example ✅

```yaml
change-request-details: |
  {
    "work_notes": "Deployment completed",
    "close_code": "successful",
    "close_notes": "All services running",
    "state": "3"
  }
```

### Incorrect Example ❌

```yaml
change-request-details: |
  {
    "state": "3",
    "work_notes": "Deployment completed",
    "close_code": "successful"
  }
```

**Why:** ServiceNow processes fields sequentially. State transitions have validation logic that depends on other fields being set first.

---

## Benefits

### For DevOps Teams
- ✅ **Automated closure** - No manual update needed
- ✅ **Complete lifecycle** - From creation to closure in one pipeline
- ✅ **Audit trail** - Every deployment tracked in ServiceNow
- ✅ **Time saved** - No context switching to ServiceNow UI

### For Change Managers
- ✅ **Real-time status** - Know deployment outcome immediately
- ✅ **Traceability** - Direct link to GitHub workflow
- ✅ **Compliance** - SOC 2, ISO 27001 audit evidence
- ✅ **Metrics** - Success/failure rates trackable

### For Approvers
- ✅ **Risk assessment** - See deployment health metrics
- ✅ **Evidence** - Pod counts, URLs, timestamps
- ✅ **Next steps** - Clear actions based on result
- ✅ **Confidence** - Know what happened without asking

---

## Viewing in ServiceNow

### Direct URL

The workflow generates a direct link to the change request:

```
https://calitiiltddemo3.service-now.com/change_request.do?sysparm_query=number=CHG0030001
```

Replace `CHG0030001` with your change request number.

### Navigation

1. Log into ServiceNow
2. Navigate to: **Change → All**
3. Search for change request number
4. Click to open
5. Check **Work Notes** tab for deployment details

### Fields Updated

- **State** - Updated to 3 (success) or 4 (failure)
- **Close Code** - Set to "successful" or "unsuccessful"
- **Close Notes** - Summary of deployment result
- **Work Notes** - Detailed deployment information

---

## Troubleshooting

### Change Request Not Updated

**Check:**
1. Was a change request created?
   ```bash
   # Check workflow logs for servicenow-change job
   gh run view <run-id> --log | grep "Change Request Number"
   ```

2. Did deployment complete?
   ```bash
   # Check deploy-to-environment job status
   gh run view <run-id> --json jobs --jq '.jobs[] | select(.name | contains("Deploy")) | {name, conclusion}'
   ```

3. Did update job run?
   ```bash
   # Check for update-servicenow-change job
   gh run view <run-id> --json jobs --jq '.jobs[] | select(.name | contains("Update")) | {name, conclusion}'
   ```

### Authentication Failed

**Error:** `401 Unauthorized` or `403 Forbidden`

**Solutions:**
1. Verify credentials are set:
   ```bash
   gh secret list --repo Freundcloud/microservices-demo | grep SERVICENOW
   ```

2. Test authentication manually:
   ```bash
   source .envrc
   curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
     "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_query=user_name=$SERVICENOW_USERNAME&sysparm_limit=1"
   ```

3. Check user has change management permissions in ServiceNow

### State Not Updated

**Error:** State field didn't change despite successful workflow

**Possible Causes:**
1. **Field order wrong** - State must be last (fixed in current implementation)
2. **Invalid state transition** - ServiceNow workflow may restrict certain transitions
3. **Missing required fields** - close_code and close_notes required for closure

**Solution:** Check ServiceNow system logs for validation errors

### State Transition Error

**Error:** `change cannot be moved to state : 3 for change request number : CHG0030258`

**Root Cause:** ServiceNow state machine doesn't allow direct transition from New (-5) to Closed (3)

**Solution:** ✅ **FIXED** - Workflow now automatically transitions through Implement state first

**How it works:**
1. Query current state of change request
2. If state = -5 (New), move to -1 (Implement) first
3. Then proceed with normal close to state 3

**Documentation:** See [ServiceNow State Transition Fix](SERVICENOW-STATE-TRANSITION-FIX.md) for complete details

### Work Notes Not Visible

**Issue:** Deployment completed but no work notes

**Causes:**
1. **Permissions** - User may not have write access to work_notes field
2. **Business Rules** - ServiceNow business rule may be stripping notes
3. **JSON escaping** - Special characters in notes breaking JSON

**Solution:** Check workflow logs for JSON payload sent to ServiceNow

---

## Testing

### Manual Test

1. **Trigger a deployment:**
   ```bash
   gh workflow run "🚀 Master CI/CD Pipeline" \
     --repo Freundcloud/microservices-demo \
     --ref main
   ```

2. **Wait for deployment** to complete (~5-10 minutes)

3. **Check change request** in ServiceNow:
   - Should show state = 3 (if successful)
   - Should have work notes with deployment details
   - Should link to GitHub workflow

4. **Verify workflow logs:**
   ```bash
   gh run list --repo Freundcloud/microservices-demo --limit 1
   gh run view <run-id> --log | grep "Update Change Request"
   ```

### Expected Output

**Successful Deployment:**
```
Update Change Request in ServiceNow
  ✓ State updated to: 3
  ✓ Close code: successful
  ✓ Close notes: Deployment completed successfully
  ✓ Work notes added with deployment details
```

**Failed Deployment:**
```
Update Change Request in ServiceNow
  ✓ State updated to: 4
  ✓ Close code: unsuccessful
  ✓ Close notes: Deployment failed
  ✓ Work notes added with failure details
```

---

## Comparison: Before vs After

### Before This Feature

**Manual Process:**
1. Deployment completes
2. DevOps engineer manually logs into ServiceNow
3. Finds change request by number
4. Manually updates state, adds notes
5. Closes change request
6. **Time:** 5-10 minutes per deployment
7. **Risk:** Forgetting to update, incorrect status

### After This Feature

**Automated Process:**
1. Deployment completes
2. ✅ Workflow automatically updates ServiceNow
3. ✅ State, notes, links all added automatically
4. ✅ Change request closed if successful
5. **Time:** 0 seconds (automated)
6. **Risk:** None (always accurate)

**Time Saved:** 5-10 minutes × deployments per week × teams

---

## Future Enhancements

Potential improvements (not implemented):

1. **Approval Requirement:**
   - Wait for ServiceNow approval before deploying
   - Block prod deployments until approved

2. **Custom State Mapping:**
   - Different states per environment
   - Allow configuration via inputs

3. **Attachment Support:**
   - Attach deployment logs to change request
   - Upload test results as files

4. **Advanced Metrics:**
   - Deployment duration
   - Resource utilization
   - Cost estimates

5. **Rollback Detection:**
   - Detect if deployment is a rollback
   - Update change request accordingly

---

## Related Documentation

- [ServiceNow Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [ServiceNow Change Request REST API](SERVICENOW-CHANGE-REQUEST-REST-API.md)
- [ServiceNow Custom Fields Setup](SERVICENOW-CUSTOM-FIELDS-SETUP.md)
- [Session Summary 2025-01-28](SESSION-SUMMARY-2025-01-28.md)

---

## References

- **GitHub Action:** https://github.com/marketplace/actions/servicenow-devops-update-change
- **ServiceNow DevOps Docs:** https://docs.servicenow.com/bundle/utah-devops/page/product/enterprise-dev-ops/concept/devops-integration-overview.html
- **Change Request States:** ServiceNow Change Management documentation

---

*Implemented and documented on 2025-01-28 using Basic Authentication as requested*
