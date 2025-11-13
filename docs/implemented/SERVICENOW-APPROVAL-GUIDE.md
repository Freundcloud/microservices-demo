# ServiceNow Change Request Approval Guide

> **Important**: ServiceNow Change Requests in this demo environment don't have a simple "Approve" button in the UI. You must use the automated approval script.

## Quick Start

### Automated Approval (Recommended)

QA/PROD deployments now **auto-approve** Change Requests automatically:

```bash
# Deploys to QA with automatic CR approval
just demo-run qa 1.5.5

# Deploys to PROD with automatic CR approval
just demo-run prod 1.5.5
```

The workflow will:
1. Create the Change Request in ServiceNow
2. Wait for CR creation (up to 5 minutes)
3. **Automatically approve** the CR using the script
4. Continue with deployment

### Manual Approval (When Needed)

If auto-approval fails or you need to approve manually:

```bash
# 1. Load ServiceNow credentials
source .envrc

# 2. Approve the Change Request
just sn-approve-cr CHG0030568
```

## Understanding ServiceNow Approvals

### Why No "Approve" Button?

ServiceNow's Change Management system uses workflow-based approvals through the `sysapproval_approver` table. However, in our demo configuration:

- The UI doesn't display a simple "Approve" button
- Approvers need to be added via the REST API
- The approval workflow requires specific state transitions

### Manual Approval Process

The approval script automates these steps:

1. **Set Approval Status**: Changes the CR's `approval` field from `requested` to `approved`
2. **Transition States**: Moves the CR through proper states:
   - `-4` (Assess) → `-3` (Authorize) → `-2` (Scheduled)
3. **Verify**: Confirms the CR is in `approved` and `scheduled` state

### State Definitions

| State Value | State Name | Description |
|-------------|------------|-------------|
| `-5` | New | Newly created CR |
| `-4` | Assess | Pending approval |
| `-3` | Authorize | Approved, planning deployment |
| `-2` | Scheduled | Ready for deployment |
| `-1` | Implement | Deployment in progress |
| `0` | Review | Post-deployment review |
| `3` | Closed | Completed successfully |
| `4` | Canceled | Canceled/rejected |

### Approval Status Values

| Value | Description |
|-------|-------------|
| `not requested` | Approval not yet requested |
| `requested` | Waiting for approval |
| `approved` | Approved and ready |
| `rejected` | Rejected |

## Using the Approval Script

### Basic Usage

```bash
# Approve CHG0030568
just sn-approve-cr CHG0030568
```

### Direct Script Usage

```bash
source .envrc
./scripts/approve-servicenow-cr.sh CHG0030568
```

### Script Output

```
╔════════════════════════════════════════════════════════════════╗
║         ServiceNow Change Request Approval Script              ║
╚════════════════════════════════════════════════════════════════╝

📋 Looking up Change Request: CHG0030568...
   ✅ Found: CHG0030568 (sys_id: ab726823...)
   Current State: -4
   Current Approval: requested

✅ Approving Change Request...
   Approval status: approved

🔄 Transitioning Change Request states...
   Current state: -4
   Transitioning: Assess → Authorize...
   Transitioning: Authorize → Scheduled...
   Final state: -2 (Scheduled)

📊 Verifying final state...
   State: -2
   Approval: approved

╔════════════════════════════════════════════════════════════════╗
║                       ✅ SUCCESS!                               ║
╚════════════════════════════════════════════════════════════════╝

Change Request CHG0030568 is now:
  • Approved
  • Scheduled (ready for deployment)

The GitHub Actions workflow can now proceed with deployment.

🔗 View in ServiceNow:
   https://calitiiltddemo3.service-now.com/change_request.do?sys_id=ab726823...
```

## Automated Approval in Workflows

### Current Workflow Behavior

The `.github/workflows/servicenow-change-rest.yaml` workflow:

1. **Creates Change Request**: Automatically creates CR when deploying to QA/PROD
2. **Adds Approvers**: Automatically adds two approvers:
   - Individual: Olaf Krasicki-Freund
   - Group: GitHubARC DevOps Admin
3. **Waits for Approval**: Polls every 60 seconds checking for `approval=approved` and `state=-2` (Scheduled)

### Approver Configuration

The workflow hardcodes these approver sys_ids:

```yaml
OLAF_USER_SYS_ID="220ab6a6c34a2e10e1bbf0cb0501314c"  # Olaf Krasicki-Freund
DEVOPS_GROUP_SYS_ID="9825d52ec3e8ba90e1bbf0cb0501315b"  # GitHubARC DevOps Admin
```

### Wait for Approval Step

The workflow includes a wait loop:

```yaml
- name: Wait for Change Approval
  timeout-minutes: 60  # Wait up to 1 hour
  run: |
    while true; do
      APPROVAL=$(curl -s ... | jq -r '.result.approval')
      STATE=$(curl -s ... | jq -r '.result.state')

      if [ "$APPROVAL" = "approved" ] && [ "$STATE" = "-2" ]; then
        echo "✅ Change Request approved!"
        break
      fi

      sleep 60
    done
```

## Deployment Workflow

### Dev Environment

```bash
just demo-run dev 1.5.4
```

- **Auto-approved**: No manual approval needed
- CR state set directly to `scheduled` (-2)
- Deployment proceeds immediately

### QA/PROD Environments (Auto-Approval)

```bash
just demo-run qa 1.5.4
just demo-run prod 1.5.4
```

**Automated Flow:**
1. **CR Created**: State set to `assess` (-4), approval set to `requested`
2. **Approvers Added**: Olaf and GitHubARC DevOps Admin added automatically
3. **Workflow Detects CR**: Searches logs for CR number (waits up to 5 minutes)
4. **Auto-Approval**: Script automatically approves and transitions to `scheduled`
5. **Deployment Proceeds**: Deployment continues without manual intervention

**Fallback:**
- If auto-approval fails, workflow displays manual approval command
- Use `just sn-approve-cr CHG0030XXX` to approve manually
- Workflow continues to poll for approval

## ServiceNow UI Access

### Viewing Change Requests

1. Navigate to: https://calitiiltddemo3.service-now.com
2. Go to: **Change Management → My Changes**
3. Find your CR by number (e.g., CHG0030568)

### Change Request Details

The CR includes comprehensive deployment metadata:

- **Environment**: dev/qa/prod
- **Version**: Deployment version (e.g., 1.5.4)
- **GitHub Info**: Commit SHA, branch, PR number, workflow run
- **Security Scans**: Critical/high/medium vulnerabilities
- **Unit Tests**: Total, passed, failed, coverage
- **SonarCloud**: Bugs, vulnerabilities, code smells
- **Services**: List of microservices being deployed
- **Application URL**: Load balancer endpoint (after deployment)

### Related Lists

Each CR has these related lists:

- **Approvals**: Shows approval records (may be empty in demo)
- **Work Items**: Linked GitHub issues/PRs
- **Packages**: Docker images being deployed
- **Pipeline Executions**: GitHub Actions workflow runs
- **Test Results**: Unit test summaries

## Troubleshooting

### CR Not Found

```bash
❌ Error: Change Request not found: CHG0030568
```

**Solution**: Verify the CR number:

```bash
# List recent CRs
gh run list --workflow=MASTER-PIPELINE.yaml --limit 5
```

### Credentials Not Found

```bash
❌ Error: ServiceNow credentials not found
```

**Solution**: Load credentials:

```bash
source .envrc
echo $SERVICENOW_USERNAME  # Should show: github_integration
```

### jq Not Installed

```bash
❌ Error: jq is not installed
```

**Solution**: Install jq:

```bash
sudo apt-get install jq
```

### Approval Already Set

If the CR is already approved, the script will skip re-approval:

```
✅ Already approved
```

This is normal and the script will continue to verify the state.

### State Transition Blocked

If ServiceNow business rules block state transitions, you may see:

```
⚠️  Warning: Unexpected final state
```

**Solution**: Check ServiceNow logs or contact ServiceNow admin.

## API Reference

### Approve Change Request

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d '{"approval": "approved"}' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID"
```

### Transition State

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X PATCH \
  -d '{"state": "-2"}' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CR_SYSID"
```

### Add Approver

```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "source_table": "change_request",
    "sysapproval": "'"$CR_SYSID"'",
    "approver": "'"$USER_SYS_ID"'",
    "state": "requested"
  }' \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sysapproval_approver"
```

## Future Improvements

### Enable UI Approval Button

To enable the "Approve" button in ServiceNow UI:

1. **Configure Approval Workflows**: Set up proper approval workflows in ServiceNow
2. **Assign Approval Roles**: Give users the `approver_user` role
3. **Configure Approval Groups**: Set up approval groups with proper members
4. **Update Workflow**: Modify `.github/workflows/servicenow-change-rest.yaml` to use ServiceNow's approval workflow

### Alternative Approval Methods

1. **Email Approval**: Configure ServiceNow to send approval emails
2. **Mobile App**: Use ServiceNow mobile app for approvals
3. **Slack Integration**: Approve from Slack using ServiceNow integration
4. **Auto-Approval Rules**: Set up rules for automatic approval based on criteria

## Additional Resources

- [ServiceNow Change Management](https://docs.servicenow.com/bundle/utah-it-service-management/page/product/change-management/concept/c_ITILChangeManagement.html)
- [ServiceNow REST API](https://docs.servicenow.com/bundle/utah-api-reference/page/integrate/inbound-rest/concept/c_RESTAPI.html)
- [GitHub Actions ServiceNow Integration](docs/SERVICENOW-INTEGRATION.md)
- [Automated Release Guide](docs/AUTOMATED-RELEASE-GUIDE.md)

## Summary

**TL;DR**: ServiceNow's demo configuration doesn't provide a UI "Approve" button. Use the automated script:

```bash
source .envrc
just sn-approve-cr CHG0030568
```

This will approve the Change Request and transition it to the `Scheduled` state, allowing the GitHub Actions deployment workflow to proceed.
