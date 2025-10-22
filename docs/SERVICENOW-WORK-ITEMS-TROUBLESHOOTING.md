# ServiceNow Work Items Troubleshooting Guide

> Created: 2025-10-22
> Issue: Work items not showing in ServiceNow DevOps workspace

## Problem Statement

**Symptom**: When viewing the ServiceNow DevOps workspace, the work items tab shows 0 items:
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
→ Select change request
→ Work Items tab: (empty)
```

## Root Cause

The workflow only extracted work items from **merged Pull Requests** within the last 24 hours:

```yaml
# Original code (line 114)
MERGED_PRS=$(gh pr list --state merged --base main --json number,mergedAt \
  --jq '.[] | select(.mergedAt > (now - 86400)) | .number' | head -10)

if [ -z "$MERGED_PRS" ]; then
  # No PRs = No work items
  WORK_ITEMS_HTML="<li><em>No work items linked</em></li>"
fi
```

**Your development workflow:**
- ✅ Direct pushes to `main` branch
- ❌ No pull requests
- ❌ No work items extracted
- Result: Empty work items in ServiceNow

## Solution Implemented

Enhanced the workflow to extract work items from **commit messages** when no PRs exist.

### New Logic Flow

```
1. Check for merged PRs (last 24 hours)
   ↓
2. If PRs found → Extract from PR titles/bodies
   ↓
3. If NO PRs → NEW: Extract from git log (last 10 commits)
   ↓
4. Parse commit messages for issue references
   ↓
5. Fetch issue details from GitHub API
   ↓
6. Add to ServiceNow work items
```

### Code Changes

**File**: `.github/workflows/servicenow-integration.yaml` (lines 122-169)

**Added**:
```yaml
# If no PRs, extract from recent commits (last 10)
if [ -z "$MERGED_PRS" ]; then
  COMMIT_MESSAGES=$(git log --pretty=format:"%s %b" -10)

  # Extract issue numbers from commits
  FOUND_ISSUES=$(echo "$COMMIT_MESSAGES" | grep -oE "(#|Fixes #|Closes #|Resolves #)[0-9]+")

  for issue_num in $FOUND_ISSUES; do
    # Fetch issue details from GitHub
    ISSUE_DATA=$(gh issue view $issue_num --json title,state,labels,url)
    # Add to work items list
  done
fi
```

## How to Use

### Method 1: Reference Issues in Commit Messages

**Step 1: Create a GitHub Issue**
```bash
gh issue create \
  --title "Add ServiceNow custom fields" \
  --body "Need to create u_source, u_correlation_id fields"

# Returns: Created issue #6
```

**Step 2: Commit with Issue Reference**
```bash
git commit -m "feat: Add custom fields (Fixes #6)"
git push origin main
```

**Supported Patterns**:
- `#6` - Simple reference
- `Fixes #6` - Indicates fix (closes issue)
- `Closes #6` - Closes issue
- `Resolves #6` - Resolves issue

**Step 3: Deploy**
- Workflow runs automatically on push to main
- Extracts Issue #6 from commit message
- Fetches issue details from GitHub API
- Adds to ServiceNow work items

### Method 2: Use Pull Requests (Original Method)

```bash
# Create feature branch
git checkout -b feature/add-fields

# Make changes
git add .
git commit -m "feat: Add custom fields"

# Push and create PR
git push origin feature/add-fields
gh pr create \
  --title "feat: Add custom fields (Fixes #6)" \
  --body "This PR adds ServiceNow custom fields. Fixes #6"

# Merge PR
gh pr merge --squash
```

### Method 3: Multiple Issues in One Commit

```bash
git commit -m "feat: Major refactor (Fixes #6, Closes #7, Resolves #8)"
```

All three issues (#6, #7, #8) will be extracted and added to work items.

## Expected Results

### In GitHub Actions Workflow Summary

```
## 📋 Extracting Work Item Evidence

✅ Found Issue #6 from commits: Add ServiceNow custom fields

**Total Work Items Found:** 1
**Issue Numbers:** 6
```

### In ServiceNow DevOps Workspace

1. Navigate to: https://calitiiltddemo3.service-now.com/now/devops-change/home
2. Select your change request (e.g., CHG0030078)
3. Click **Work Items** tab
4. You should see:
   ```
   Issue #6: Add ServiceNow custom fields
   Status: open
   Labels: enhancement
   Source: Direct commit
   ```

### In ServiceNow Change Request

Custom field `u_github_issues` will contain: `6`

```json
{
  "u_github_issues": "6",
  "u_work_items_count": "1",
  "u_work_items_summary": "<h3>Work Items:</h3><ul><li><strong><a href='...'>Issue #6</a>: Add ServiceNow custom fields</strong><br><em>Status:</em> open | <em>Labels:</em> enhancement | <em>Source:</em> Direct commit</li></ul>"
}
```

## Verification

### Step 1: Check Workflow Ran Successfully

```bash
gh run list --repo Freundcloud/microservices-demo --limit 1
```

Expected output:
```
✓  docs: Add work items integration summary (Fixes #6)  Master CI/CD Pipeline  main  74320582
```

### Step 2: View Workflow Logs

```bash
gh run view <run-id> --repo Freundcloud/microservices-demo --log | grep "Work Item"
```

Expected output:
```
📋 Extracting Work Item Evidence
✅ Found Issue #6 from commits: Add ServiceNow custom fields
Total Work Items Found: 1
```

### Step 3: Query ServiceNow API

```bash
export SERVICENOW_USERNAME="your-username"
export SERVICENOW_PASSWORD="your-password"

curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=u_correlation_id=<workflow-run-id>&sysparm_fields=number,u_github_issues,u_work_items_count" \
  | jq '.result[0] | {number, issues: .u_github_issues, count: .u_work_items_count}'
```

Expected output:
```json
{
  "number": "CHG0030078",
  "issues": "6",
  "count": "1"
}
```

### Step 4: Check ServiceNow UI

1. Go to: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do
2. Find your change request
3. Open it
4. Look for custom fields:
   - `u_github_issues`: 6
   - `u_work_items_count`: 1
   - `u_work_items_summary`: (HTML with issue details)

## Troubleshooting

### Issue 1: Still No Work Items After Fix

**Check**:
```bash
# View recent commits
git log --oneline -10

# Look for issue references (#N)
```

**Fix**: Commits must contain issue references (`#6`, `Fixes #6`, etc.)

### Issue 2: Workflow Doesn't Find Issue

**Error**:
```
⚠️ Issue #6 not found
```

**Possible causes**:
1. Issue doesn't exist in repository
2. Issue is in different repository
3. GitHub API token doesn't have permission

**Fix**:
```bash
# Verify issue exists
gh issue view 6 --repo Freundcloud/microservices-demo

# Check repository in workflow
```

### Issue 3: Issue Found But Not in ServiceNow

**Check workflow logs**:
```bash
gh run view <run-id> --log | grep -A 20 "Create Change Request"
```

**Verify payload**:
Look for `u_github_issues` in the JSON payload.

**Common fix**: Field might not be in change request payload. Check line 247 of `servicenow-integration.yaml`:
```json
{
  "u_github_issues": "WORK_ITEM_NUMBERS_PLACEHOLDER"
}
```

### Issue 4: ServiceNow Shows Wrong Issue Number

**Cause**: Work items from previous deployments

**Fix**: Each deployment creates a new change request with its own work items. Check the correlation_id matches your workflow run ID.

## Best Practices

### 1. Always Create Issues First

```bash
# Good workflow
gh issue create --title "Feature X"
git commit -m "feat: Add feature X (Fixes #6)"

# Avoid
git commit -m "feat: Add feature X"  # No issue reference
```

### 2. Use Descriptive Issue Titles

```bash
# Good
"Add ServiceNow custom fields for GitHub integration"

# Avoid
"Fix bug"  # Too vague
```

### 3. Link Multiple Related Issues

```bash
git commit -m "refactor: Major cleanup (Fixes #6, Closes #7, Resolves #8)"
```

### 4. Close Issues When Deployed

Use `Fixes`, `Closes`, or `Resolves` to automatically close issues:
```bash
git commit -m "feat: Complete feature (Fixes #6)"
```

GitHub will automatically close Issue #6 when this commit is pushed.

### 5. For Urgent Changes Without Issues

```bash
# Create issue inline
gh issue create --title "Hotfix: Production bug" --body "..."
# Returns: Created issue #9

# Immediate commit
git commit -m "fix: Production hotfix (Fixes #9)"
git push origin main
```

## Compliance Benefits

### For Approvers
- ✅ See exactly what GitHub issues were deployed
- ✅ Click through to issue details for context
- ✅ Understand business justification for change

### For Auditors
- ✅ Complete traceability: Change Request ↔ GitHub Issue
- ✅ Audit trail: Who created issue, when, why
- ✅ Evidence of review and approval process

### For Developers
- ✅ Link code changes to business requirements
- ✅ Track progress across GitHub and ServiceNow
- ✅ Automatic issue closure on deployment

## Related Documentation

- [ServiceNow Work Items Guide](SERVICENOW-WORK-ITEMS-APPROVAL-EVIDENCE.md) - Complete work items documentation
- [GitHub ServiceNow Integration](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) - Full integration overview
- [Custom Fields Setup](SERVICENOW-CUSTOM-FIELDS-SETUP.md) - Custom fields implementation

## Files Modified

- `.github/workflows/servicenow-integration.yaml` - Enhanced work item extraction (lines 122-169)
- Commit: `74320582` - fix: Extract work items from commit messages

---

**Status**: ✅ Fixed
**Testing**: Create issue #6, commit with "Fixes #6", verify in ServiceNow
**Next Deployment**: Will include work items automatically
