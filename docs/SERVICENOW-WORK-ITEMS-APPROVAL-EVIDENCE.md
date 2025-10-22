# ServiceNow Change Request Approval with Work Item Evidence

**Status**: Implementation Guide
**Last Updated**: 2025-10-22
**Purpose**: Add work items (stories, tasks, issues) as evidence in change request approval process

---

## Overview

This guide explains how to link work items (user stories, tasks, GitHub issues) to ServiceNow change requests so approvers can see **what work was completed** before approving deployments.

### Business Value

**For Approvers**:
- ✅ See exactly what features/fixes are included in the deployment
- ✅ Verify all work items are completed before approving
- ✅ Understand business impact of changes
- ✅ Make informed approval decisions

**For Compliance**:
- ✅ Complete audit trail of work items → change → deployment
- ✅ Proof that changes were planned and tracked
- ✅ Evidence for SOC 2, ISO 27001, ITIL compliance

**For Development Team**:
- ✅ Automatic linkage (no manual work)
- ✅ Visibility into deployment status
- ✅ Clear traceability from story to production

---

## Architecture

```
Work Items (Stories/Tasks/Issues)
           ↓
    GitHub Pull Request
           ↓
ServiceNow Change Request (with work item evidence)
           ↓
    Approval Decision
           ↓
      Deployment
```

### Data Flow

1. **Work starts**: Developer creates GitHub branch from story/task
2. **Code complete**: Developer opens pull request with work item references
3. **CI/CD triggers**: GitHub Actions workflow runs on PR merge
4. **Change created**: ServiceNow change request created with work item evidence
5. **Approval review**: Approver sees linked work items, security scans, test results
6. **Deployment proceeds**: Approved changes deploy automatically

---

## Implementation Options

### Option A: GitHub Issue References (Recommended)

Use GitHub issues as work items and link them to change requests.

**Advantages**:
- ✅ Native GitHub integration
- ✅ Developers already use GitHub issues
- ✅ No additional tools needed
- ✅ Free with GitHub

**How It Works**:
1. Create GitHub issues for each story/task
2. Reference issues in PR title/description (e.g., "Fixes #123")
3. GitHub Actions extracts issue numbers from PR
4. Issues linked to ServiceNow change request
5. Approvers see issue list with titles, descriptions, status

### Option B: ServiceNow Stories + GitHub Integration

Use ServiceNow Agile Development module for story tracking, sync with GitHub.

**Advantages**:
- ✅ Central ServiceNow source of truth
- ✅ Advanced sprint/release management
- ✅ Built-in approval workflows
- ✅ Native change request integration

**How It Works**:
1. Create stories in ServiceNow (rm_story table)
2. Link stories to change requests via relationship
3. Developers reference story numbers in GitHub commits/PRs
4. GitHub Actions updates ServiceNow with commit details
5. Approvers see linked stories in change request

### Option C: Azure DevOps Work Items

Use Azure DevOps for work item tracking, sync to ServiceNow.

**Advantages**:
- ✅ Robust work item management
- ✅ Advanced reporting and dashboards
- ✅ Integration with Azure pipelines

**Implementation**: Similar to Option B, requires Azure DevOps + ServiceNow integration

**For This Guide**: We'll focus on **Option A (GitHub Issues)** as it requires no additional licenses or tools.

---

## Implementation: GitHub Issues as Work Item Evidence

### Step 1: Configure GitHub Repository

**Enable Issues** (if not already enabled):
1. Navigate to GitHub repository settings
2. Features → Check "Issues"
3. Click "Save changes"

**Create Issue Templates** (optional but recommended):
```bash
# Create .github/ISSUE_TEMPLATE/feature.md
---
name: Feature Request
about: Propose a new feature
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Description
What feature do you want to add?

## Business Value
Why is this feature needed?

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes
Implementation details...
```

**Create Issue Labels**:
- `feature` - New functionality
- `bug` - Bug fixes
- `enhancement` - Improvements to existing features
- `deployment` - Ready for deployment
- `blocked` - Blocked waiting for dependencies

### Step 2: Add Work Item Fields to Change Request

**In ServiceNow**, add custom fields to `change_request` table:

```javascript
// Navigate to: System Definition → Tables → change_request → Columns (related list)
// Click "New" to create each field:

Field 1:
  Column label: GitHub Issues
  Column name: u_github_issues
  Type: String
  Max length: 1000
  Help text: Comma-separated list of GitHub issue numbers (e.g., 123,456,789)

Field 2:
  Column label: Work Items Summary
  Column name: u_work_items_summary
  Type: HTML
  Help text: Formatted summary of work items for approval review

Field 3:
  Column label: Total Work Items
  Column name: u_work_items_count
  Type: Integer
  Help text: Number of work items included in this change
```

**Add Fields to Change Request Form**:
1. Navigate to: Change → All
2. Open any change request
3. Right-click form header → Configure → Form Layout
4. Move new fields to "Approval Information" section
5. Click "Save"

### Step 3: Update GitHub Actions Workflow

**Extract GitHub Issues from Pull Request**:

Add this to `.github/workflows/servicenow-integration.yaml`:

```yaml
# Job 1: Extract Work Items from PR
extract-work-items:
  name: Extract Work Item Evidence
  runs-on: ubuntu-latest
  outputs:
    issue_numbers: ${{ steps.extract.outputs.issue_numbers }}
    issue_count: ${{ steps.extract.outputs.issue_count }}
    work_items_summary: ${{ steps.extract.outputs.work_items_summary }}

  steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Extract GitHub Issues from PR and Commits
      id: extract
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔍 EXTRACTING WORK ITEMS FROM PULL REQUESTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Get all merged PRs in this push
        MERGED_PRS=$(gh pr list --state merged --base main --json number,title,body,mergedAt \
          --jq '.[] | select(.mergedAt > (now - 86400)) | .number' | head -10)

        if [ -z "$MERGED_PRS" ]; then
          echo "ℹ️  No recently merged PRs found"
          echo "issue_numbers=" >> $GITHUB_OUTPUT
          echo "issue_count=0" >> $GITHUB_OUTPUT
          echo "work_items_summary=No work items linked" >> $GITHUB_OUTPUT
          exit 0
        fi

        # Extract issue numbers from PR titles and bodies
        ISSUE_NUMBERS=""
        WORK_ITEMS_HTML="<h3>Work Items Included in This Deployment:</h3><ul>"
        ISSUE_COUNT=0

        for pr_number in $MERGED_PRS; do
          echo "Processing PR #$pr_number..."

          # Get PR details
          PR_DATA=$(gh pr view $pr_number --json title,body,number,url,author)
          PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
          PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')
          PR_URL=$(echo "$PR_DATA" | jq -r '.url')
          PR_AUTHOR=$(echo "$PR_DATA" | jq -r '.author.login')

          # Extract issue numbers (matches: #123, Fixes #456, Closes #789, etc.)
          FOUND_ISSUES=$(echo "$PR_TITLE $PR_BODY" | grep -oE "(#|Fixes #|Closes #|Resolves #)[0-9]+" | grep -oE "[0-9]+" | sort -u)

          if [ ! -z "$FOUND_ISSUES" ]; then
            for issue_num in $FOUND_ISSUES; do
              # Get issue details
              ISSUE_DATA=$(gh issue view $issue_num --json title,state,labels,url 2>/dev/null || echo "{}")

              if [ "$ISSUE_DATA" != "{}" ]; then
                ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
                ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
                ISSUE_URL=$(echo "$ISSUE_DATA" | jq -r '.url')
                ISSUE_LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels[].name' | tr '\n' ', ' | sed 's/,$//')

                # Add to list
                ISSUE_NUMBERS="$ISSUE_NUMBERS,$issue_num"
                ISSUE_COUNT=$((ISSUE_COUNT + 1))

                # Add to HTML summary
                WORK_ITEMS_HTML="$WORK_ITEMS_HTML<li><strong>Issue #$issue_num</strong>: $ISSUE_TITLE<br>"
                WORK_ITEMS_HTML="$WORK_ITEMS_HTML<em>Status:</em> $ISSUE_STATE | <em>Labels:</em> $ISSUE_LABELS<br>"
                WORK_ITEMS_HTML="$WORK_ITEMS_HTML<em>PR:</em> <a href=\"$PR_URL\">#$pr_number</a> by @$PR_AUTHOR<br>"
                WORK_ITEMS_HTML="$WORK_ITEMS_HTML<em>Link:</em> <a href=\"$ISSUE_URL\">View Issue</a></li>"

                echo "  ✅ Found issue #$issue_num: $ISSUE_TITLE"
              fi
            done
          fi
        done

        WORK_ITEMS_HTML="$WORK_ITEMS_HTML</ul>"

        # Remove leading comma
        ISSUE_NUMBERS=$(echo "$ISSUE_NUMBERS" | sed 's/^,//')

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Extracted $ISSUE_COUNT work items"
        echo "Issue Numbers: $ISSUE_NUMBERS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Set outputs
        echo "issue_numbers=$ISSUE_NUMBERS" >> $GITHUB_OUTPUT
        echo "issue_count=$ISSUE_COUNT" >> $GITHUB_OUTPUT

        # Encode HTML for output (escape newlines)
        WORK_ITEMS_HTML_ENCODED=$(echo "$WORK_ITEMS_HTML" | tr '\n' ' ')
        echo "work_items_summary=$WORK_ITEMS_HTML_ENCODED" >> $GITHUB_OUTPUT
```

**Add Work Items to Change Request Creation**:

Update the `create-change-request` job:

```yaml
create-change-request:
  name: Create ServiceNow Change Request
  runs-on: ubuntu-latest
  needs: [extract-work-items, upload-security-evidence]
  outputs:
    change_request_number: ${{ steps.create-change.outputs.change_request_number }}
    change_request_sys_id: ${{ steps.create-change.outputs.change_request_sys_id }}

  steps:
    - name: Create Change Request with Work Item Evidence
      id: create-change
      run: |
        ISSUE_NUMBERS="${{ needs.extract-work-items.outputs.issue_numbers }}"
        ISSUE_COUNT="${{ needs.extract-work-items.outputs.issue_count }}"
        WORK_ITEMS_HTML="${{ needs.extract-work-items.outputs.work_items_summary }}"

        # Build change request payload
        PAYLOAD=$(jq -n \
          --arg short_desc "Deploy Online Boutique to ${{ inputs.environment }}" \
          --arg description "Automated deployment via GitHub Actions.\n\nWorkflow: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\nCommit: ${{ github.sha }}\nBranch: ${{ github.ref_name }}\nActor: ${{ github.actor }}" \
          --arg type "normal" \
          --arg model "adffaa9e4370211072b7f6be5bb8f2ed" \
          --arg service "1e7b938bc360b2d0e1bbf0cb050131da" \
          --arg tool_id "4c5e482cc3383214e1bbf0cb05013196" \
          --arg github_repo "${{ github.repository }}" \
          --arg github_commit "${{ github.sha }}" \
          --arg issues "$ISSUE_NUMBERS" \
          --arg issues_count "$ISSUE_COUNT" \
          --arg work_summary "$WORK_ITEMS_HTML" \
          '{
            "category": "DevOps",
            "devops_change": true,
            "type": $type,
            "chg_model": $model,
            "business_service": $service,
            "u_tool_id": $tool_id,
            "u_github_repo": $github_repo,
            "u_github_commit": $github_commit,
            "u_github_issues": $issues,
            "u_work_items_count": $issues_count,
            "u_work_items_summary": $work_summary,
            "short_description": $short_desc,
            "description": $description,
            "correlation_id": "${{ github.run_id }}",
            "requested_by": "cdbb6e2ec3a8fa90e1bbf0cb050131f9"
          }')

        # Create change request
        RESPONSE=$(curl -s -w "\n%{http_code}" \
          -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
          -H "Content-Type: application/json" \
          -H "Accept: application/json" \
          -d "$PAYLOAD" \
          "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

        HTTP_STATUS=$(echo "$RESPONSE" | tail -1)
        BODY=$(echo "$RESPONSE" | head -1)

        if [ "$HTTP_STATUS" = "201" ]; then
          CHG_NUMBER=$(echo "$BODY" | jq -r '.result.number')
          CHG_SYS_ID=$(echo "$BODY" | jq -r '.result.sys_id')

          echo "✅ Change request created: $CHG_NUMBER"
          echo "   Work items included: $ISSUE_COUNT"
          echo "   Issues: $ISSUE_NUMBERS"

          echo "change_request_number=$CHG_NUMBER" >> $GITHUB_OUTPUT
          echo "change_request_sys_id=$CHG_SYS_ID" >> $GITHUB_OUTPUT
        else
          echo "❌ Failed to create change request (HTTP $HTTP_STATUS)"
          echo "$BODY" | jq .
          exit 1
        fi
```

### Step 4: Configure Change Request Approval UI

**Make Work Items Visible to Approvers**:

1. **Add to Approval Form View**:
   - Navigate to: Change → All
   - Open any change request
   - Right-click form header → Configure → Form Layout
   - Create new section: "Work Items & Evidence"
   - Add fields:
     - `u_work_items_count` (read-only)
     - `u_work_items_summary` (read-only, HTML display)
     - `u_github_issues` (read-only)
   - Move section above "Approval" section
   - Click "Save"

2. **Create Related List for GitHub Issues** (optional advanced):
   ```javascript
   // Create Business Rule to populate related list
   // Navigate to: System Definition → Business Rules → New

   Name: Populate GitHub Issues Related List
   Table: Change Request [change_request]
   When: before, insert, update
   Condition: u_github_issues is not empty

   Script:
   (function executeRule(current, previous /*null when async*/) {
       var issueNumbers = current.u_github_issues.toString().split(',');
       var githubRepo = current.u_github_repo.toString();

       // Clear existing related records
       var gr = new GlideRecord('u_github_issue_link');
       gr.addQuery('change_request', current.sys_id);
       gr.deleteMultiple();

       // Create new related records
       for (var i = 0; i < issueNumbers.length; i++) {
           var issueNum = issueNumbers[i].trim();
           if (issueNum) {
               var issue = new GlideRecord('u_github_issue_link');
               issue.initialize();
               issue.change_request = current.sys_id;
               issue.issue_number = issueNum;
               issue.github_repo = githubRepo;
               issue.issue_url = 'https://github.com/' + githubRepo + '/issues/' + issueNum;
               issue.insert();
           }
       }
   })(current, previous);
   ```

### Step 5: Test the Implementation

**Create Test Scenario**:

1. **Create GitHub Issues**:
   ```bash
   # In GitHub UI or via gh CLI:
   gh issue create --title "[FEATURE] Add health check endpoint" --body "Add /health endpoint for monitoring"
   # Returns: Created issue #150

   gh issue create --title "[BUG] Fix authentication timeout" --body "Users timeout after 30 minutes"
   # Returns: Created issue #151
   ```

2. **Create Pull Request with Issue References**:
   ```bash
   git checkout -b feature/health-check
   # Make changes...
   git commit -m "Add health check endpoint

   Fixes #150"

   git push origin feature/health-check
   gh pr create --title "Add health check endpoint (Fixes #150)" --body "Resolves #150

   Changes:
   - Added /health endpoint
   - Returns 200 OK with service status
   - Includes database connection check"
   ```

3. **Merge PR and Watch Workflow**:
   ```bash
   gh pr merge <pr-number> --squash
   # Workflow triggers automatically
   ```

4. **Verify in ServiceNow**:
   - Navigate to: Change → All
   - Find newly created change request
   - Verify "Work Items & Evidence" section shows:
     - Work Items Count: 2
     - Work Items Summary: HTML list with issue #150, #151
     - GitHub Issues: "150,151"
   - Click issue links to view in GitHub

**Expected Result**:
```
╔════════════════════════════════════════════════════╗
║  Change Request: CHG0030064                        ║
║  Deploy Online Boutique to dev                     ║
╠════════════════════════════════════════════════════╣
║  Work Items & Evidence                             ║
║  ─────────────────────────────────────────────     ║
║  Total Work Items: 2                               ║
║                                                    ║
║  Work Items Included in This Deployment:           ║
║  • Issue #150: Add health check endpoint           ║
║    Status: closed | Labels: feature, deployment    ║
║    PR: #245 by @developer1                         ║
║    Link: View Issue →                              ║
║                                                    ║
║  • Issue #151: Fix authentication timeout          ║
║    Status: closed | Labels: bug, security          ║
║    PR: #246 by @developer2                         ║
║    Link: View Issue →                              ║
╚════════════════════════════════════════════════════╝
```

---

## Advanced: Approval Rules Based on Work Items

**Scenario**: Require additional approval if high-risk work items are included.

**Implementation**:

1. **Add Risk Assessment Script** to change request Business Rule:
   ```javascript
   // Navigate to: System Definition → Business Rules → New

   Name: Assess Work Item Risk
   Table: Change Request [change_request]
   When: before, insert, update
   Condition: u_github_issues is not empty

   Script:
   (function executeRule(current, previous) {
       var issueNumbers = current.u_github_issues.toString().split(',');
       var githubRepo = current.u_github_repo.toString();
       var highRiskCount = 0;

       // Query GitHub API for issue labels
       for (var i = 0; i < issueNumbers.length; i++) {
           var issueNum = issueNumbers[i].trim();
           if (issueNum) {
               // Call GitHub API (requires REST Message configuration)
               var response = callGitHubAPI('/repos/' + githubRepo + '/issues/' + issueNum);

               if (response) {
                   var labels = response.labels;
                   for (var j = 0; j < labels.length; j++) {
                       if (labels[j].name === 'breaking-change' ||
                           labels[j].name === 'database-migration' ||
                           labels[j].name === 'security') {
                           highRiskCount++;
                           break;
                       }
                   }
               }
           }
       }

       // Set risk level based on work item analysis
       if (highRiskCount > 0) {
           current.risk = 3; // High risk
           current.impact = 2; // Medium impact
           // Will trigger additional approval workflow
       }
   })(current, previous);
   ```

2. **Configure Approval Workflow**:
   - Navigate to: Change → Approval Rules
   - Create rule: "High Risk Work Items Require Security Approval"
   - Condition: Risk = High AND u_work_items_count > 0
   - Approver: Security team
   - Type: Serial (must approve before others)

---

## Monitoring & Metrics

**Track Work Item Velocity**:

Create ServiceNow Report:
- **Table**: Change Request [change_request]
- **Group By**: Closed Date (by week)
- **Aggregation**: AVG of u_work_items_count
- **Chart Type**: Line chart
- **Title**: "Average Work Items per Deployment"

**Track Approval Time by Work Item Count**:

Create Performance Analytics Widget:
- **Metric**: Average time from Created to Approved
- **Breakdown By**: u_work_items_count (buckets: 1-3, 4-6, 7+)
- **Insight**: Does more work items = longer approval time?

---

## Troubleshooting

**Issue**: Work items summary is empty
- **Fix**: Check PR title/body contains issue references (e.g., "Fixes #123")
- **Verify**: GitHub issues exist and are accessible

**Issue**: HTML summary not rendering
- **Fix**: Verify u_work_items_summary field type is "HTML" not "String"
- **Check**: Form layout has field configured to render HTML

**Issue**: Related list not showing issues
- **Fix**: Verify Business Rule executed (check System Logs)
- **Check**: u_github_issue_link table exists and has records

---

## Best Practices

1. **Consistent Issue References**: Train team to always reference issues in PR titles
2. **Issue Hygiene**: Close issues only when PRs merge (not before)
3. **Labels Matter**: Use labels for risk assessment, filtering, reporting
4. **Link Quality**: Ensure GitHub repo field is always populated correctly
5. **Approval Training**: Train approvers to review work items, not just code changes

---

## Next Steps

1. **Implement basic version** (GitHub issues + change request fields)
2. **Test with 2-3 deployments** to validate workflow
3. **Gather approver feedback** on usefulness
4. **Add advanced features** (risk assessment, related lists, etc.)
5. **Train team** on new process

---

**References**:
- ServiceNow Change Management Documentation
- GitHub Issues API: https://docs.github.com/en/rest/issues
- GitHub CLI: https://cli.github.com/manual/gh_issue

---

**Last Updated**: 2025-10-22
**Status**: Ready for Implementation
**Estimated Effort**: 4-6 hours (basic version)
