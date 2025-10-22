# ServiceNow GitHub Spoke Use Cases for DevOps Workflows

**Plugin**: GitHub Spoke (sn_github_spoke v3.3.0)
**Category**: Integration Hub Spokes, DevOps Tool Integrations & APIs
**Status**: ✅ Installed

---

## Overview

The **GitHub Spoke** enables bi-directional automation between ServiceNow and GitHub using Flow Designer, providing powerful workflow capabilities without writing code.

### What the GitHub Spoke Provides

**Core Capabilities**:
- Branch management (create, delete, list, merge)
- Pull request automation (create, merge, comment)
- Issue management (create, update, close, comment)
- Repository management (create repos, manage collaborators)
- Organization management (teams, licenses, user activity)

**Integration Methods**:
- **Flow Designer** - Drag-and-drop visual automation
- **Workflow Studio** - Low-code workflow builder
- **Integration Hub** - Advanced integration development

---

## Practical Use Cases for Your DevOps Workflow

### Use Case 1: Auto-Create GitHub Issues from ServiceNow Incidents

**Business Value**: When production incidents occur, automatically create GitHub issues for dev team tracking.

**Workflow**:
1. Incident created in ServiceNow (Priority 1 or 2)
2. Flow triggers automatically
3. GitHub Spoke creates issue in repository
4. Issue includes incident details, priority, affected services
5. Issue number recorded in ServiceNow incident

**Flow Designer Steps**:
```
Trigger: Record Created or Updated (Incident table)
Condition: Priority is 1 or 2
Action: GitHub Spoke - Create Issue
  - Repository: Freundcloud/microservices-demo
  - Title: [P{priority}] {short_description}
  - Body:
      Incident: {number}
      Description: {description}
      Affected Service: {cmdb_ci}
      URL: {instance_url}/incident.do?sys_id={sys_id}
  - Labels: incident, priority-{priority}
Action: Update Incident
  - Set field: u_github_issue = {issue_number}
```

**Benefits**:
- ✅ Dev team notified immediately via GitHub
- ✅ Traceability between incidents and code fixes
- ✅ No manual issue creation required
- ✅ Consistent issue formatting

---

### Use Case 2: Auto-Merge PRs When Change Request Approved

**Business Value**: Accelerate deployments by automatically merging approved pull requests.

**Workflow**:
1. Change request approved in ServiceNow
2. Flow triggers on approval
3. GitHub Spoke merges associated pull request
4. Deployment workflow automatically starts
5. Change request updated with merge details

**Flow Designer Steps**:
```
Trigger: Record Updated (Change Request table)
Condition:
  - State changed to "Approved"
  - u_github_pr_number is not empty
Action: GitHub Spoke - Merge Pull Request
  - Repository: Freundcloud/microservices-demo
  - PR Number: {u_github_pr_number}
  - Merge Method: squash
  - Commit Message: Approved via ServiceNow CR {number}
Action: Update Change Request
  - Add work note: "PR #{u_github_pr_number} merged automatically"
  - Set field: u_merge_timestamp = {now}
```

**Benefits**:
- ✅ No manual PR merging required
- ✅ Faster deployment cycle
- ✅ Audit trail maintained
- ✅ Enforces approval before merge

---

### Use Case 3: Auto-Create Feature Branches from ServiceNow Stories

**Business Value**: Standardize branch naming and automatically create feature branches when work starts.

**Workflow**:
1. User story moved to "In Progress" in ServiceNow
2. Flow triggers automatically
3. GitHub Spoke creates feature branch from main
4. Branch name follows standard: `feature/{story_number}-{short_desc}`
5. Story updated with branch name

**Flow Designer Steps**:
```
Trigger: Record Updated (Story table)
Condition:
  - State changed to "In Progress"
  - u_github_branch is empty
Action: GitHub Spoke - Create Branch
  - Repository: Freundcloud/microservices-demo
  - Branch Name: feature/{number}-{sanitized_short_description}
  - From Branch: main
Action: Update Story
  - Set field: u_github_branch = {branch_name}
  - Add work note: "Feature branch created: {branch_name}"
```

**Benefits**:
- ✅ Consistent branch naming
- ✅ No manual branch creation
- ✅ Traceability: story ↔ branch
- ✅ Ready to start coding immediately

---

### Use Case 4: Auto-Comment on PRs When Deployment Fails

**Business Value**: Keep developers informed of deployment status directly in GitHub.

**Workflow**:
1. Deployment workflow fails in GitHub Actions
2. ServiceNow change request marked as "Failed"
3. Flow triggers on status change
4. GitHub Spoke adds comment to associated PR
5. Comment includes failure details and rollback info

**Flow Designer Steps**:
```
Trigger: Record Updated (Change Request table)
Condition:
  - State changed to "Failed"
  - u_github_pr_number is not empty
Action: GitHub Spoke - Add Comment to Pull Request
  - Repository: Freundcloud/microservices-demo
  - PR Number: {u_github_pr_number}
  - Comment: |
      ⚠️ **Deployment Failed**

      Change Request: {number}
      Environment: {u_environment}
      Failure Reason: {close_notes}

      Action Required:
      - Review failure logs
      - Fix issues
      - Re-deploy via ServiceNow

      Rollback: Automatically initiated
Action: Update Change Request
  - Add work note: "Failure notification posted to PR #{u_github_pr_number}"
```

**Benefits**:
- ✅ Developers notified in their workflow (GitHub)
- ✅ Clear failure context
- ✅ Actionable information
- ✅ Audit trail

---

### Use Case 5: Auto-Request Review from Team When PR Created

**Business Value**: Ensure PRs get timely reviews by automatically assigning reviewers based on changed files.

**Workflow**:
1. Pull request created in GitHub
2. Webhook triggers ServiceNow Flow
3. Flow analyzes changed files
4. GitHub Spoke requests review from appropriate team
5. ServiceNow tracks review status

**Flow Designer Steps**:
```
Trigger: Webhook (GitHub PR created event)
Action: Script - Analyze Changed Files
  - Parse files from webhook payload
  - Determine owning team (e.g., terraform/* → DevOps team)
Action: GitHub Spoke - Request PR Review
  - Repository: Freundcloud/microservices-demo
  - PR Number: {pr_number}
  - Reviewers: {team_members}
Action: Create Record (PR Review Tracking table)
  - PR Number: {pr_number}
  - Assigned Team: {team_name}
  - Status: Pending Review
```

**Benefits**:
- ✅ Automatic reviewer assignment
- ✅ Faster PR review cycle
- ✅ Load balancing across team
- ✅ ServiceNow visibility of PR status

---

### Use Case 6: Reclaim Unused GitHub Licenses

**Business Value**: Save costs by identifying and reclaiming GitHub licenses from inactive users.

**Workflow**:
1. Scheduled Flow runs weekly
2. GitHub Spoke queries user activity
3. Identifies users with no commits in 90 days
4. Creates ServiceNow Approval Request
5. On approval, removes users from organization

**Flow Designer Steps**:
```
Trigger: Scheduled (Weekly, Sundays 1 AM)
Action: GitHub Spoke - Get User Activity
  - Organization: Freundcloud
  - Time Range: Last 90 days
Action: Script - Filter Inactive Users
  - Filter users with 0 commits, 0 PRs, 0 reviews
Action: Create Approval Request
  - Approver: License Administrator
  - Description: Remove {count} inactive users
  - Users List: {inactive_users}
Action: GitHub Spoke - Remove Organization Member
  - Execute only if approved
  - Remove users from organization
Action: Create Report
  - Potential Savings: ${count} × $21/month
```

**Benefits**:
- ✅ Cost savings (reclaim unused licenses)
- ✅ Audit trail of removals
- ✅ Approval process enforced
- ✅ Automated license management

---

### Use Case 7: Auto-Close Issues When Change Request Deployed

**Business Value**: Keep GitHub issues in sync with ServiceNow change management status.

**Workflow**:
1. Change request deployment completes successfully
2. Flow triggers on state change to "Closed"
3. GitHub Spoke closes all linked GitHub issues
4. Issues tagged with change request number

**Flow Designer Steps**:
```
Trigger: Record Updated (Change Request table)
Condition:
  - State changed to "Closed"
  - Close Code = "Successful"
  - u_github_issues is not empty (comma-separated list)
Action: Script - Parse Issue Numbers
  - Split u_github_issues by comma
Action: GitHub Spoke - Update Issue (for each issue)
  - Repository: Freundcloud/microservices-demo
  - Issue Number: {issue_number}
  - State: closed
  - Comment: |
      ✅ Deployed successfully via ServiceNow CR {number}
      Deployment Date: {closed_at}
      Environment: {u_environment}
Action: Update Change Request
  - Add work note: "Closed {count} GitHub issues"
```

**Benefits**:
- ✅ GitHub issues auto-close on deployment
- ✅ No manual issue cleanup
- ✅ Traceability: issue → change → deployment
- ✅ Accurate GitHub backlog

---

## Implementation Guide

### Step 1: Access Flow Designer

1. Navigate to: **All → Process Automation → Flow Designer**
2. Click **New → Flow**
3. Name your flow (e.g., "Auto-Create GitHub Issues from Incidents")
4. Select trigger type (Record Created, Scheduled, Webhook, etc.)

### Step 2: Add GitHub Spoke Actions

1. Click **Add an Action, Flow Logic, or Subflow**
2. Search for "GitHub" in the action picker
3. Select appropriate GitHub Spoke action:
   - **Create Issue**
   - **Merge Pull Request**
   - **Create Branch**
   - **Add Comment**
   - **Request Review**
   - **Get User Activity**
   - etc.

### Step 3: Configure Action Parameters

For each GitHub Spoke action, configure:

**Connection**:
- Uses the GitHub tool configured in ServiceNow DevOps
- Tool ID: `4c5e482cc3383214e1bbf0cb05013196`
- Authentication: github_integration user credentials

**Action Parameters**:
- **Repository**: `Freundcloud/microservices-demo` (owner/repo format)
- **Branch Name**: Dynamic or static branch name
- **PR Number**: From trigger data or ServiceNow field
- **Issue Number**: From ServiceNow field
- **Labels**: Array of labels (e.g., `["bug", "priority-high"]`)
- **Assignees**: GitHub usernames
- **Body/Comment**: Markdown-formatted text with dynamic data

### Step 4: Map ServiceNow Fields to GitHub Data

**Common Mappings**:
```
ServiceNow Field              → GitHub Field
─────────────────────────────────────────────────────
number                        → Issue/PR title prefix
short_description             → Issue title
description                   → Issue body
priority                      → Issue label
assigned_to                   → Issue assignee
cmdb_ci                       → Issue label (component)
u_github_pr_number            → PR number
u_github_branch               → Branch name
u_environment                 → Issue/PR label
```

### Step 5: Test the Flow

1. Click **Test** button in Flow Designer
2. Provide test data (select a ServiceNow record)
3. Click **Run Test**
4. Verify GitHub action executed:
   - Check GitHub for created issue/PR/branch
   - Review Flow execution log
   - Verify ServiceNow record updated

### Step 6: Activate the Flow

1. Click **Activate** in top right
2. Flow now runs automatically on trigger
3. Monitor executions: **All → Process Automation → Flow Execution History**

---

## Required ServiceNow Configuration

### 1. Add Custom Fields to ServiceNow Tables

**Change Request Table** (change_request):
```
Field Name: u_github_pr_number
Type: Integer
Label: GitHub PR Number

Field Name: u_github_branch
Type: String (100)
Label: GitHub Branch

Field Name: u_github_issues
Type: String (255)
Label: GitHub Issue Numbers (comma-separated)

Field Name: u_merge_timestamp
Type: Date/Time
Label: PR Merge Timestamp
```

**Incident Table** (incident):
```
Field Name: u_github_issue
Type: String (50)
Label: GitHub Issue Number
```

**Story Table** (rm_story):
```
Field Name: u_github_branch
Type: String (100)
Label: Feature Branch Name

Field Name: u_github_pr_number
Type: Integer
Label: Pull Request Number
```

### 2. Configure GitHub Tool Connection

The GitHub Spoke uses the existing GitHub tool:
- Tool ID: `4c5e482cc3383214e1bbf0cb05013196`
- Configured in: ServiceNow DevOps
- Authentication: github_integration user
- Already configured ✅

### 3. Grant Flow Designer Permissions

Users creating flows need:
- **Role**: `flow_designer` or `admin`
- **Access**: GitHub Spoke actions
- **Permissions**: Read/Write on target ServiceNow tables

---

## Monitoring and Troubleshooting

### View Flow Executions

Navigate to: **All → Process Automation → Flow Execution History**

Filter by:
- Flow name
- Status (Success, Failed, Waiting)
- Date range

### Common Issues

**Issue**: "GitHub tool not found"
- **Fix**: Verify tool ID `4c5e482cc3383214e1bbf0cb05013196` exists
- **Check**: Navigate to DevOps → Tools → GitHub tool

**Issue**: "Authentication failed"
- **Fix**: Verify github_integration user credentials are valid
- **Test**: Run API test from GitHub tool configuration

**Issue**: "Repository not found"
- **Fix**: Use `owner/repo` format (e.g., `Freundcloud/microservices-demo`)
- **Verify**: GitHub tool has access to repository

**Issue**: "Branch already exists"
- **Fix**: Add condition to check if branch exists first
- **Alternative**: Delete branch if exists, then create new

---

## Best Practices

### 1. Error Handling

Always add error handling to flows:
```
If GitHub action fails:
  - Log error to ServiceNow
  - Create incident for review
  - Notify admin
  - Don't block main workflow
```

### 2. Naming Conventions

**Branches**: `{type}/{ticket-number}-{short-desc}`
- Examples: `feature/CHG0030063-add-istio`, `bugfix/INC0001234-fix-auth`

**Issues**: `[{priority}] {ServiceNow-number}: {description}`
- Examples: `[P1] INC0001234: Production API down`, `[P3] STRY0005678: Add dark mode`

**PR Titles**: `{ServiceNow-number}: {description}`
- Examples: `CHG0030063: Deploy microservices v2.1.0`, `STRY0005678: Implement user preferences`

### 3. Audit Trail

Always update ServiceNow records with GitHub action results:
- Add work notes with action taken
- Store GitHub URLs
- Record timestamps
- Track status changes

### 4. Security

- **Don't expose sensitive data** in GitHub issues/comments (credentials, internal IPs, etc.)
- **Use ServiceNow fields for sensitive info**, link to ServiceNow from GitHub
- **Limit GitHub Spoke permissions** to minimum required
- **Review flow execution logs** regularly for security issues

---

## Advanced Use Cases

### Multi-Repository Management

Create subflow for repository selection:
```
Input: ServiceNow CMDB CI (application)
Logic:
  - Look up CMDB CI
  - Get u_github_repository field
  - Return repository name
Output: Repository (owner/repo)

Use in flows:
  - Dynamically select correct repository based on application
  - No hardcoding repository names
```

### Automatic Rollback

When deployment fails:
```
Trigger: Change Request state = Failed
Actions:
  1. GitHub Spoke - Create Branch (rollback/{cr_number})
  2. GitHub Spoke - Revert Merge Commit
  3. GitHub Spoke - Create PR (rollback)
  4. GitHub Spoke - Request Review (from change approvers)
  5. Update Change Request with rollback details
```

### Release Automation

End-to-end release flow:
```
Trigger: Release record state = Ready
Actions:
  1. GitHub Spoke - Create Tag (v{version})
  2. GitHub Spoke - Create Release
  3. Upload release artifacts
  4. Post release notes (from ServiceNow release record)
  5. Update ServiceNow release with GitHub release URL
  6. Send notifications (email, Slack, etc.)
```

---

## Integration with Current Workflow

Your existing GitHub Actions workflow can trigger ServiceNow flows:

**In GitHub Actions** (after deployment):
```yaml
- name: Notify ServiceNow Flow
  run: |
    curl -X POST \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -d '{
        "change_request": "${{ needs.create-change-request.outputs.change_request_number }}",
        "deployment_status": "success",
        "environment": "dev",
        "github_run_id": "${{ github.run_id }}"
      }' \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/u_deployment_webhook"
```

**In ServiceNow Flow Designer**:
```
Trigger: Record Created (u_deployment_webhook table)
Actions:
  1. Lookup Change Request by number
  2. GitHub Spoke - Close related issues
  3. GitHub Spoke - Add comment to PR (deployment success)
  4. Update Change Request (add deployment evidence)
  5. Delete webhook record (cleanup)
```

---

## Metrics and Reporting

Track GitHub Spoke automation impact:

**Metrics to Capture**:
- Number of issues auto-created
- Number of PRs auto-merged
- Time saved (manual actions vs automated)
- License cost savings
- Deployment cycle time reduction

**Create ServiceNow Dashboard**:
- GitHub automation activity (line chart)
- Top automated workflows (bar chart)
- Cost savings from license reclamation (single score)
- Failed automations requiring review (list)

---

## Next Steps

1. **Start with Use Case 1** (Auto-create GitHub issues from incidents)
   - Simple implementation
   - Immediate value
   - Low risk

2. **Expand to Use Case 2** (Auto-merge approved PRs)
   - Accelerates deployments
   - Maintains approval control
   - Medium complexity

3. **Implement Use Case 3** (Auto-create feature branches)
   - Standardizes workflow
   - Reduces manual work
   - Low complexity

4. **Advanced**: Use Cases 4-7 after initial success

---

## Resources

- **ServiceNow Store**: [GitHub Spoke](https://store.servicenow.com/store/app/bc8923221b246a50a85b16db234bcbb4)
- **Documentation**: Flow Designer User Guide
- **Training**: Integration Hub Fundamentals
- **Support**: ServiceNow Community DevOps Forum

---

**Last Updated**: 2025-10-22
**Status**: Ready for Implementation
**Priority Use Cases**: 1, 2, 3 (High Value, Low Complexity)
