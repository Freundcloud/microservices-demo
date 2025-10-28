# ServiceNow Change Request Update Setup Checklist

> **Feature**: Automatic change request updates after deployment
> **Status**: Requires configuration
> **Estimated Setup Time**: 15-30 minutes

## Overview

This checklist guides you through enabling automatic ServiceNow change request updates. After setup, every deployment will automatically update the associated change request with deployment status, pod health, and detailed work notes.

## Prerequisites

- [ ] ServiceNow instance with DevOps Change Control plugin installed
- [ ] GitHub repository with workflows configured
- [ ] Existing ServiceNow change request creation workflow (already configured)
- [ ] ServiceNow user with appropriate permissions

## Setup Options

Choose **ONE** authentication method based on your ServiceNow version:

### Option A: Token-Based Authentication (v2.0+, Recommended) ✅

**Advantages**: More secure, easier to manage, supports modern ServiceNow features

**Required Secrets**:
- `SERVICENOW_DEVOPS_TOKEN`
- `SN_ORCHESTRATION_TOOL_ID`
- `SERVICENOW_INSTANCE_URL` (already exists)

**Setup Steps**:

1. **Create GitHub Tool in ServiceNow**:
   - [ ] Navigate to: **System DevOps > Tools > GitHub**
   - [ ] Click **New**
   - [ ] Fill in details:
     - Name: `GitHub Actions - microservices-demo`
     - Type: `GitHub`
     - Repository: `Freundcloud/microservices-demo`
     - Active: ✅ Checked
   - [ ] Click **Submit**
   - [ ] Copy the **sys_id** from the URL (it will look like: `f62c4e49c3fcf614e1bbf0cb050131ef`)

2. **Generate Integration Token**:
   - [ ] Open the GitHub tool you just created
   - [ ] Click **Generate Token** button
   - [ ] Copy the token (it will only be shown once!)
   - [ ] Save it securely

3. **Add GitHub Secrets**:
   - [ ] Navigate to: `https://github.com/Freundcloud/microservices-demo/settings/secrets/actions`
   - [ ] Click **New repository secret**
   - [ ] Add `SERVICENOW_DEVOPS_TOKEN`:
     - Name: `SERVICENOW_DEVOPS_TOKEN`
     - Value: `<paste token from step 2>`
   - [ ] Add `SN_ORCHESTRATION_TOOL_ID`:
     - Name: `SN_ORCHESTRATION_TOOL_ID`
     - Value: `<sys_id from step 1>`

4. **Verify Permissions**:
   - [ ] Integration user has `sn_devops.devops_user` role
   - [ ] Integration user has `itil` role (for change request updates)

### Option B: Basic Authentication (Legacy) ⚠️

**Use when**: ServiceNow version doesn't support token-based auth

**Required Secrets**:
- `SERVICENOW_USERNAME` (already exists)
- `SERVICENOW_PASSWORD` (already exists)
- `SERVICENOW_INSTANCE_URL` (already exists)

**Setup Steps**:

1. **Verify User Permissions**:
   - [ ] ServiceNow user has `sn_devops.devops_user` role
   - [ ] ServiceNow user has `itil` role
   - [ ] User can update change requests manually

2. **Update Workflow Configuration**:
   - [ ] Edit `.github/workflows/servicenow-update-change.yaml`
   - [ ] Change `use_token_auth: true` to `use_token_auth: false` in workflow calls
   - [ ] Commit and push changes

## Workflow Configuration

### deploy-environment.yaml

**Current Status**: ✅ Already integrated (no action needed)

The workflow already includes:
```yaml
update-servicenow-change:
  uses: ./.github/workflows/servicenow-update-change.yaml
  with:
    environment: ${{ inputs.environment }}
    change_request_number: ${{ needs.servicenow-change.outputs.change_number }}
    deployment_status: ${{ needs.deploy.result }}
```

### MASTER-PIPELINE.yaml

**Current Status**: ✅ Already integrated (no action needed)

The pipeline already includes Stage 8 for updating change requests.

## Validation

### Pre-Deployment Test

1. **Trigger a test deployment**:
   ```bash
   just promote 1.2.6 dev
   ```

2. **Monitor the workflow**:
   - [ ] Navigate to: `https://github.com/Freundcloud/microservices-demo/actions`
   - [ ] Find the running workflow
   - [ ] Watch for "Update ServiceNow Change" job

3. **Check for errors**:
   - [ ] Job completes without authentication errors
   - [ ] No 401 or 403 HTTP errors in logs
   - [ ] Success message shows: "✅ Successfully updated change request"

### Post-Deployment Verification

1. **Find the change request**:
   - [ ] Navigate to ServiceNow: **Change > Normal > All**
   - [ ] Search for change request number (shown in GitHub Actions logs)
   - [ ] Example: CHG0123456

2. **Verify work notes added**:
   - [ ] Open the change request
   - [ ] Scroll to **Work Notes** section
   - [ ] Verify entry with deployment details:
     ```
     ✅ Deployment completed successfully to dev environment

     Environment: dev
     Namespace: microservices-dev
     Status: success
     Running Pods: 10/10
     Frontend URL: http://...
     Commit: <sha>
     Triggered by: @<username>
     Workflow Run: <url>

     All services deployed and healthy.
     ```

3. **Verify state updated**:
   - [ ] State field shows: **Implement** (-1)
   - [ ] State was updated from previous value

4. **Test failure scenario** (optional):
   - [ ] Trigger a deployment that will fail (e.g., invalid image tag)
   - [ ] Verify change request updated with failure work notes
   - [ ] State remains: **Implement** (-1)

## Troubleshooting

### Authentication Errors

**Error**: `HTTP 401: Unauthorized`

**Solution**:
1. Token-based auth:
   - Verify `SERVICENOW_DEVOPS_TOKEN` is correct
   - Check token hasn't expired
   - Verify `SN_ORCHESTRATION_TOOL_ID` matches tool sys_id
2. Basic auth:
   - Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD` are correct
   - Check user account isn't locked

### Permission Errors

**Error**: `HTTP 403: Forbidden` or `Insufficient permissions`

**Solution**:
1. Verify user has required roles:
   ```sql
   -- In ServiceNow, run this script
   var user = gs.getUserByID('<user_sys_id>');
   gs.print('Roles: ' + user.getRoles());
   ```
2. Required roles:
   - `sn_devops.devops_user`
   - `itil`

### Change Request Not Found

**Error**: `Change request CHG0123456 not found`

**Solution**:
1. Check change request actually exists in ServiceNow
2. Verify change number passed correctly from servicenow-change job
3. Check workflow logs for servicenow-change outputs

### Update Skipped

**Behavior**: update-servicenow-change job doesn't run

**Causes**:
1. `servicenow-change` job didn't create a change request
2. Change number output is empty
3. Job condition not met: `needs.servicenow-change.outputs.change_number != ''`

**Solution**:
1. Check servicenow-change job logs
2. Verify change request was created successfully
3. Check outputs in workflow run

### Fallback REST API Update

If the ServiceNow DevOps GitHub Action fails, the workflow automatically attempts a fallback REST API update (work notes only).

**Check logs** for:
```
⚠️ Attempting fallback update via REST API...
✅ Fallback update successful via REST API
```

## Configuration Options

### Auto-Close on Success

**Default**: Disabled (change requests remain in "Implement" state)

**To enable**:
1. Edit workflow calls in `deploy-environment.yaml` and `MASTER-PIPELINE.yaml`
2. Change `auto_close: false` to `auto_close: true`
3. Successful deployments will close change requests automatically

**Example**:
```yaml
update-servicenow-change:
  with:
    auto_close: true  # Enable auto-close
```

### Environment-Specific Behavior

| Environment | Update Behavior | Work Notes Detail |
|-------------|----------------|-------------------|
| dev | Update only | Basic (status + pods) |
| qa | Update only | Detailed (all info) |
| prod | Update only | Comprehensive (all info + URL) |

## Success Criteria

- [ ] Token or basic auth configured and working
- [ ] GitHub secrets added and verified
- [ ] Test deployment creates change request
- [ ] Change request automatically updated after deployment
- [ ] Work notes include deployment details
- [ ] State transitions correctly
- [ ] Failed deployments update change request with errors
- [ ] No authentication or permission errors

## Next Steps

After successful setup:

1. **Monitor first few deployments** to ensure updates work correctly
2. **Review work notes format** and adjust if needed
3. **Consider enabling auto-close** for dev environment
4. **Document any custom fields** you want to update
5. **Train team** on new automated workflow

## Related Documentation

- [ServiceNow Change Lifecycle](../SERVICENOW-CHANGE-LIFECYCLE.md) - Complete lifecycle management guide
- [ServiceNow Change Creation](../../.github/workflows/servicenow-change-rest.yaml) - Change request creation workflow
- [Update Change Workflow](../../.github/workflows/servicenow-update-change.yaml) - Update workflow implementation

## Support

### ServiceNow Issues
- ServiceNow customers: Use [Now Support portal](https://support.servicenow.com/)
- Check [DevOps Change Control documentation](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/concept/devops-change-control.html)

### GitHub Actions Issues
- Review [ServiceNow DevOps GitHub Actions](https://github.com/ServiceNow/servicenow-devops-update-change)
- Check workflow logs in GitHub Actions tab

---

**Questions?** See the [troubleshooting section](#troubleshooting) above or consult the main [SERVICENOW-CHANGE-LIFECYCLE.md](../SERVICENOW-CHANGE-LIFECYCLE.md) documentation.
