# ServiceNow Work Items Implementation Guide

**Last Updated:** 2025-10-28
**Purpose:** Complete guide to implement GitHub Issues → ServiceNow Work Items integration

## Overview

This guide shows how to extract GitHub Issue numbers from commits and link them to ServiceNow change requests for complete traceability.

**Goal:** When a deployment happens, automatically link related GitHub Issues to the ServiceNow Change Request so approvers can see what features/bugs are being deployed.

---

## What Are Work Items?

**Work Items** in ServiceNow DevOps Change Velocity represent the user stories, features, bugs, and tasks that are being deployed in a change request.

**Benefits:**
- Approvers see **what work** is being deployed (not just which code)
- Traceability from user story → commit → deployment
- Compliance evidence (link requirements to deployments)
- Better change risk assessment (AI can analyze work item history)

**ServiceNow Table:** `sn_devops_work_item`

**Fields:**
- `work_item_id` - GitHub Issue number (e.g., "123")
- `work_item_type` - Issue type ("feature", "bug", "enhancement")
- `work_item_title` - Issue title
- `work_item_url` - Link to GitHub Issue
- `change_request` - Link to ServiceNow Change Request
- `repository` - GitHub repository name
- `state` - Issue state (open, closed)

---

## Implementation Approaches

### Approach 1: Extract from Commit Messages (Recommended)

**How It Works:**
1. Developer commits code with message: `fix: Resolve cart bug (Fixes #123)`
2. Workflow parses commit messages for issue references
3. Extracts all unique issue numbers
4. Fetches issue details from GitHub API
5. Uploads work items to ServiceNow via REST API

**Pros:**
- ✅ Works with existing commit conventions
- ✅ Supports multiple patterns: `#123`, `GH-123`, `Fixes #123`, `Closes #456`
- ✅ No changes to developer workflow

**Cons:**
- ⚠️ Requires developers to reference issues in commits (already best practice)

---

### Approach 2: Extract from Pull Request

**How It Works:**
1. Deployment triggered by merge to main
2. Workflow gets PR number from merge commit
3. Fetches PR details and linked issues via GitHub API
4. Uploads work items to ServiceNow

**Pros:**
- ✅ More reliable (PRs always exist for main branch merges)
- ✅ Can get all commits in PR and aggregate issues

**Cons:**
- ⚠️ Only works for PR-based workflows
- ⚠️ May miss direct pushes to main

---

### Approach 3: Hybrid (Best Practice)

Combine both approaches:
1. Try to get PR number first (if merge commit)
2. Fall back to parsing commits if no PR
3. Aggregate all issue numbers from both sources

---

## Step-by-Step Implementation

### Step 1: Create Work Item Extraction Script

Create `.github/scripts/extract-work-items.sh`:

```bash
#!/bin/bash
set -e

# Extract work item references from commits and PRs
# Supports patterns: #123, GH-123, Fixes #123, Closes #456, etc.

COMMIT_RANGE="${1:-HEAD~10..HEAD}"
OUTPUT_FILE="${2:-work-items.json}"

echo "Extracting work items from commits: $COMMIT_RANGE"

# Get all commit messages in range
COMMITS=$(git log --pretty=format:"%s" "$COMMIT_RANGE")

# Extract issue numbers using various patterns
ISSUES=$(echo "$COMMITS" | grep -oP '(?:(?:fix(?:es|ed)?|close(?:s|d)?|resolve(?:s|d)?)\s+)?(?:#|GH-)(\d+)' | grep -oP '\d+' | sort -u)

if [ -z "$ISSUES" ]; then
  echo "No work items found in commits"
  echo "[]" > "$OUTPUT_FILE"
  exit 0
fi

echo "Found issues: $ISSUES"

# Fetch issue details from GitHub API
WORK_ITEMS="[]"

for ISSUE_NUM in $ISSUES; do
  echo "Fetching details for issue #$ISSUE_NUM..."

  ISSUE_DATA=$(gh issue view "$ISSUE_NUM" --json number,title,state,url,labels 2>/dev/null || echo "{}")

  if [ "$ISSUE_DATA" != "{}" ]; then
    # Determine work item type from labels
    WORK_ITEM_TYPE=$(echo "$ISSUE_DATA" | jq -r '
      if (.labels | map(.name) | any(. == "bug")) then "bug"
      elif (.labels | map(.name) | any(. == "enhancement")) then "enhancement"
      elif (.labels | map(.name) | any(. == "feature")) then "feature"
      else "task"
      end
    ')

    # Build work item object
    WORK_ITEM=$(echo "$ISSUE_DATA" | jq --arg type "$WORK_ITEM_TYPE" '{
      work_item_id: (.number | tostring),
      work_item_type: $type,
      work_item_title: .title,
      work_item_url: .url,
      state: .state,
      repository: env.GITHUB_REPOSITORY
    }')

    WORK_ITEMS=$(echo "$WORK_ITEMS" | jq --argjson item "$WORK_ITEM" '. + [$item]')
  fi
done

echo "$WORK_ITEMS" | jq '.' > "$OUTPUT_FILE"
echo "Extracted $(echo "$WORK_ITEMS" | jq 'length') work items"
cat "$OUTPUT_FILE"
```

### Step 2: Create ServiceNow Work Items Upload Script

Create `.github/scripts/upload-work-items-to-servicenow.sh`:

```bash
#!/bin/bash
set -e

# Upload work items to ServiceNow sn_devops_work_item table
# Links GitHub Issues to ServiceNow Change Request

WORK_ITEMS_FILE="${1:-work-items.json}"
CHANGE_REQUEST_SYSID="${2}"

if [ -z "$CHANGE_REQUEST_SYSID" ]; then
  echo "ERROR: Change request sys_id required"
  exit 1
fi

if [ ! -f "$WORK_ITEMS_FILE" ]; then
  echo "ERROR: Work items file not found: $WORK_ITEMS_FILE"
  exit 1
fi

WORK_ITEMS_COUNT=$(jq 'length' "$WORK_ITEMS_FILE")

if [ "$WORK_ITEMS_COUNT" -eq 0 ]; then
  echo "No work items to upload"
  exit 0
fi

echo "Uploading $WORK_ITEMS_COUNT work items to ServiceNow..."

# Upload each work item
jq -c '.[]' "$WORK_ITEMS_FILE" | while read -r WORK_ITEM; do
  ISSUE_NUM=$(echo "$WORK_ITEM" | jq -r '.work_item_id')

  echo "Uploading work item #$ISSUE_NUM..."

  # Build ServiceNow payload
  PAYLOAD=$(echo "$WORK_ITEM" | jq --arg cr_sysid "$CHANGE_REQUEST_SYSID" '{
    work_item_id: .work_item_id,
    work_item_type: .work_item_type,
    work_item_title: .work_item_title,
    work_item_url: .work_item_url,
    state: .state,
    repository: .repository,
    change_request: $cr_sysid
  }')

  # Upload to ServiceNow
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST \
    -d "$PAYLOAD" \
    "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item")

  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

  if [ "$HTTP_CODE" = "201" ]; then
    WORK_ITEM_SYSID=$(echo "$BODY" | jq -r '.result.sys_id')
    echo "✅ Work item #$ISSUE_NUM uploaded (sys_id: $WORK_ITEM_SYSID)"
  else
    echo "❌ Failed to upload work item #$ISSUE_NUM (HTTP $HTTP_CODE)"
    echo "$BODY" | jq '.' || echo "$BODY"
  fi
done

echo "Work items upload complete"
```

### Step 3: Add Work Items Extraction to Workflow

Add to `.github/workflows/servicenow-change-rest.yaml`:

```yaml
jobs:
  create-change:
    name: "Create Change Request (${{ inputs.environment }})"
    runs-on: ubuntu-latest
    outputs:
      change_number: ${{ steps.create-cr.outputs.change_number }}
      change_sys_id: ${{ steps.create-cr.outputs.change_sys_id }}
      work_items_count: ${{ steps.extract-work-items.outputs.count }}

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Fetch full history for commit parsing

      # NEW: Extract work items from commits
      - name: Extract Work Items from Commits
        id: extract-work-items
        run: |
          chmod +x .github/scripts/extract-work-items.sh

          # Determine commit range
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            # For PRs, get all commits in PR
            RANGE="${{ github.event.pull_request.base.sha }}..${{ github.sha }}"
          else
            # For push, get commits since last successful deployment
            # Or last 10 commits if can't determine
            RANGE="HEAD~10..HEAD"
          fi

          echo "Extracting work items from commit range: $RANGE"
          .github/scripts/extract-work-items.sh "$RANGE" work-items.json

          # Set output
          COUNT=$(jq 'length' work-items.json)
          echo "count=$COUNT" >> $GITHUB_OUTPUT

          # Display in summary
          echo "## 📋 Work Items Extracted" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Found **$COUNT** GitHub Issues referenced in commits:" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          if [ "$COUNT" -gt 0 ]; then
            jq -r '.[] | "- [#\(.work_item_id)](\(.work_item_url)) - \(.work_item_title) (\(.work_item_type))"' work-items.json >> $GITHUB_STEP_SUMMARY
          else
            echo "*No work items found*" >> $GITHUB_STEP_SUMMARY
          fi
        env:
          GH_TOKEN: ${{ github.token }}

      - name: Upload Work Items as Artifact
        if: steps.extract-work-items.outputs.count > 0
        uses: actions/upload-artifact@v4
        with:
          name: work-items-${{ github.run_id }}
          path: work-items.json
          retention-days: 30

      # Existing step: Create Change Request via REST API
      - name: Create Change Request via REST API
        id: create-cr
        # ... existing code ...

      # NEW: Upload work items to ServiceNow
      - name: Upload Work Items to ServiceNow
        if: steps.create-cr.outputs.change_sys_id != '' && steps.extract-work-items.outputs.count > 0
        run: |
          chmod +x .github/scripts/upload-work-items-to-servicenow.sh
          .github/scripts/upload-work-items-to-servicenow.sh \
            work-items.json \
            "${{ steps.create-cr.outputs.change_sys_id }}"
        env:
          SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
          SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
          SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        continue-on-error: true  # Don't block deployment if upload fails

      # Update job summary
      - name: Add Work Items to Summary
        if: steps.create-cr.outputs.change_number != '' && steps.extract-work-items.outputs.count > 0
        run: |
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "## 🔗 Work Items Linked to Change Request" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**${{ steps.extract-work-items.outputs.count }}** GitHub Issues linked to Change Request **${{ steps.create-cr.outputs.change_number }}**" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "View in ServiceNow: [${{ secrets.SERVICENOW_INSTANCE_URL }}/sn_devops_work_item_list.do?sysparm_query=change_request=${{ steps.create-cr.outputs.change_sys_id }}](${{ secrets.SERVICENOW_INSTANCE_URL }}/sn_devops_work_item_list.do?sysparm_query=change_request=${{ steps.create-cr.outputs.change_sys_id }})" >> $GITHUB_STEP_SUMMARY
```

### Step 4: Create ServiceNow Table (If Needed)

If `sn_devops_work_item` table doesn't exist, create it in ServiceNow:

**Navigate to:** System Definition > Tables

**Create Table:**
- **Name:** DevOps Work Items
- **Label:** DevOps Work Item
- **Table:** `sn_devops_work_item`
- **Extends:** None (or `sys_metadata`)

**Add Columns:**

| Column Label | Column Name | Type | Max Length |
|--------------|-------------|------|------------|
| Work Item ID | work_item_id | String | 100 |
| Work Item Type | work_item_type | String | 50 |
| Work Item Title | work_item_title | String | 255 |
| Work Item URL | work_item_url | URL | 500 |
| State | state | String | 50 |
| Repository | repository | String | 200 |
| Change Request | change_request | Reference (change_request) | 32 |

**Or via REST API:**

```bash
# Create table via ServiceNow REST API
curl -u "$SN_USER:$SN_PASS" \
  -H "Content-Type: application/json" \
  -X POST \
  "$SN_INSTANCE_URL/api/now/table/sys_db_object" \
  -d '{
    "name": "sn_devops_work_item",
    "label": "DevOps Work Item",
    "super_class": ""
  }'
```

### Step 5: Test the Integration

**Test Scenario 1: Commit with Issue Reference**

```bash
# Create test commit
git commit -m "fix: Resolve cart calculation bug (Fixes #123)"
git push origin main

# Expected result:
# - Workflow extracts issue #123
# - Fetches issue details from GitHub
# - Creates work item in ServiceNow
# - Links to change request
```

**Test Scenario 2: Multiple Issues**

```bash
# Create commit referencing multiple issues
git commit -m "feat: Add payment gateway integration

Implements new payment processor.
Fixes #123, Closes #456, Resolves #789"

git push origin main

# Expected result:
# - Extracts 3 issues: #123, #456, #789
# - Creates 3 work items in ServiceNow
# - All linked to same change request
```

**Test Scenario 3: PR-based Workflow**

```bash
# Create PR with issues in description
gh pr create --title "Add search feature" --body "Closes #100, Fixes #101"

# Merge PR
gh pr merge 42 --squash

# Expected result:
# - Extracts issues from PR body
# - Extracts issues from commits in PR
# - Deduplicates and uploads all unique issues
```

---

## Verification Steps

### 1. Check Extracted Work Items

In GitHub Actions logs, look for:

```
Extracting work items from commit range: HEAD~10..HEAD
Found issues: 123 456 789
Fetching details for issue #123...
Fetching details for issue #456...
Fetching details for issue #789...
Extracted 3 work items
[
  {
    "work_item_id": "123",
    "work_item_type": "bug",
    "work_item_title": "Cart calculation error",
    "work_item_url": "https://github.com/owner/repo/issues/123",
    "state": "open",
    "repository": "owner/repo"
  },
  ...
]
```

### 2. Check ServiceNow Upload

In GitHub Actions logs, look for:

```
Uploading 3 work items to ServiceNow...
Uploading work item #123...
✅ Work item #123 uploaded (sys_id: abc123...)
Uploading work item #456...
✅ Work item #456 uploaded (sys_id: def456...)
```

### 3. Verify in ServiceNow

**Navigate to:** DevOps > Work Items

**Or direct URL:**
```
https://your-instance.service-now.com/sn_devops_work_item_list.do
```

**Filter by Change Request:**
```
https://your-instance.service-now.com/sn_devops_work_item_list.do?sysparm_query=change_request=<sys_id>
```

**Expected Data:**
- Work Item ID: 123
- Type: bug
- Title: Cart calculation error
- URL: Link to GitHub Issue
- State: open
- Repository: owner/repo
- Change Request: CHG0030123 (linked)

### 4. Verify on Change Request Form

**Navigate to:** Change Management > Change Requests > Open

**Click on your change request**

**Related Lists section should show:**
- **DevOps Work Items (3)**
  - #123 - Cart calculation error (bug)
  - #456 - Payment validation issue (enhancement)
  - #789 - UI rendering bug (bug)

---

## Advanced Features

### Feature 1: Work Item Prioritization

Enhance risk assessment based on work item types:

```bash
# In servicenow-change-rest.yaml
- name: Calculate Risk Based on Work Items
  run: |
    WORK_ITEMS=$(cat work-items.json)

    # Count critical/bug work items
    CRITICAL_COUNT=$(echo "$WORK_ITEMS" | jq '[.[] | select(.work_item_type == "bug")] | length')

    # Adjust risk if many bugs
    if [ "$CRITICAL_COUNT" -gt 3 ]; then
      RISK="2"  # High risk
      echo "⚠️ High risk: $CRITICAL_COUNT bugs being deployed"
    else
      RISK="3"  # Medium risk
    fi

    echo "risk=$RISK" >> $GITHUB_OUTPUT
```

### Feature 2: Work Item Status Validation

Ensure all work items are closed before deployment to prod:

```yaml
- name: Validate Work Items for Production
  if: inputs.environment == 'prod'
  run: |
    OPEN_ITEMS=$(jq '[.[] | select(.state == "open")] | length' work-items.json)

    if [ "$OPEN_ITEMS" -gt 0 ]; then
      echo "❌ ERROR: Cannot deploy to production with $OPEN_ITEMS open work items"
      jq -r '.[] | select(.state == "open") | "  - #\(.work_item_id): \(.work_item_title)"' work-items.json
      exit 1
    fi

    echo "✅ All work items closed, safe to deploy"
```

### Feature 3: Automatic Issue Closing

Close GitHub Issues automatically after successful deployment:

```yaml
- name: Close Work Items After Deployment
  if: inputs.environment == 'prod' && job.status == 'success'
  run: |
    jq -r '.[].work_item_id' work-items.json | while read ISSUE_NUM; do
      echo "Closing issue #$ISSUE_NUM..."
      gh issue close "$ISSUE_NUM" --comment "Deployed to production in change request ${{ steps.create-cr.outputs.change_number }}"
    done
  env:
    GH_TOKEN: ${{ github.token }}
```

### Feature 4: Work Item Summary in Change Description

Add work items list to change request description:

```bash
# In Create Change Request step
WORK_ITEMS_SUMMARY=""
if [ -f work-items.json ]; then
  WORK_ITEMS_SUMMARY=$(jq -r '
    if length > 0 then
      "\n\nWork Items Being Deployed:\n" +
      (map("- #\(.work_item_id): \(.work_item_title) (\(.work_item_type))") | join("\n"))
    else
      ""
    end
  ' work-items.json)
fi

DESCRIPTION="$DESCRIPTION$WORK_ITEMS_SUMMARY"
```

---

## Troubleshooting

### Issue: No Work Items Extracted

**Symptoms:**
```
Extracting work items from commit range: HEAD~10..HEAD
No work items found in commits
```

**Causes:**
1. Commits don't reference GitHub Issues
2. Issue reference format not recognized
3. Commit range doesn't include relevant commits

**Solutions:**
1. Ensure commits follow convention: `fix: Description (Fixes #123)`
2. Supported patterns: `#123`, `GH-123`, `Fixes #123`, `Closes #456`, `Resolves #789`
3. Increase commit range: `HEAD~50..HEAD`
4. Check `fetch-depth: 0` in checkout action

### Issue: GitHub API Rate Limit

**Symptoms:**
```
Fetching details for issue #123...
API rate limit exceeded for user ...
```

**Solution:**
Use `GH_TOKEN` for higher rate limits:

```yaml
env:
  GH_TOKEN: ${{ github.token }}
```

Or use GitHub App token with higher limits.

### Issue: ServiceNow Upload Fails (404)

**Symptoms:**
```
❌ Failed to upload work item #123 (HTTP 404)
{
  "error": {
    "message": "No such table: sn_devops_work_item"
  }
}
```

**Solution:**
Table doesn't exist. Create it in ServiceNow (see Step 4).

### Issue: Work Items Not Visible on Change Request

**Symptoms:**
- Work items uploaded successfully
- But not visible on change request form

**Solutions:**
1. Add Related List to Change Request form:
   - Navigate to: Change Request form > Configure > Related Lists
   - Add: DevOps Work Items

2. Check relationship field:
   - Ensure `change_request` field in `sn_devops_work_item` is type "Reference" to `change_request` table

---

## Best Practices

### 1. Commit Message Conventions

Establish team convention:

```bash
# Good examples
fix: Resolve cart calculation bug (Fixes #123)
feat: Add payment gateway (Implements #456)
refactor: Optimize database queries (Related to #789)

# Bad examples (won't be detected)
Fixed a bug
Updated code
Commit message without issue reference
```

### 2. Label Your Issues

Use GitHub labels to classify work items:

- `bug` → work_item_type: "bug"
- `enhancement` → work_item_type: "enhancement"
- `feature` → work_item_type: "feature"

### 3. Close Issues via PR Merge

Use GitHub's auto-close feature:

```markdown
<!-- PR Description -->
This PR implements the new search feature.

Closes #123
Fixes #456
```

When PR is merged, issues are automatically closed.

### 4. Link Deployments Back to Issues

Add deployment comment to issues:

```bash
gh issue comment 123 --body "✅ Deployed to production in Change Request CHG0030123"
```

### 5. Monitor Work Item Coverage

Track percentage of deployments with work items:

```bash
# Calculate work item coverage
TOTAL_DEPLOYMENTS=100
DEPLOYMENTS_WITH_WORK_ITEMS=85
COVERAGE=$((DEPLOYMENTS_WITH_WORK_ITEMS * 100 / TOTAL_DEPLOYMENTS))
echo "Work item coverage: $COVERAGE%"
```

---

## Example Output

### GitHub Actions Summary

```markdown
## 📋 Work Items Extracted

Found **3** GitHub Issues referenced in commits:

- [#123](https://github.com/owner/repo/issues/123) - Cart calculation error (bug)
- [#456](https://github.com/owner/repo/issues/456) - Payment validation issue (enhancement)
- [#789](https://github.com/owner/repo/issues/789) - UI rendering bug (bug)

## 📝 ServiceNow Change Request Created

**Change Number:** CHG0030123
**Environment:** prod
**State:** assess

🔗 [View in ServiceNow](https://instance.service-now.com/change_request.do?sys_id=abc123)

## 🔗 Work Items Linked to Change Request

**3** GitHub Issues linked to Change Request **CHG0030123**

View in ServiceNow: [Work Items](https://instance.service-now.com/sn_devops_work_item_list.do?sysparm_query=change_request=abc123)
```

### ServiceNow Change Request View

**Related Lists:**

**DevOps Work Items (3)**

| Work Item ID | Type | Title | State | Repository | URL |
|--------------|------|-------|-------|------------|-----|
| 123 | bug | Cart calculation error | open | owner/repo | [View](https://github.com/owner/repo/issues/123) |
| 456 | enhancement | Payment validation issue | closed | owner/repo | [View](https://github.com/owner/repo/issues/456) |
| 789 | bug | UI rendering bug | open | owner/repo | [View](https://github.com/owner/repo/issues/789) |

---

## Next Steps

1. ✅ Create extraction script (`.github/scripts/extract-work-items.sh`)
2. ✅ Create upload script (`.github/scripts/upload-work-items-to-servicenow.sh`)
3. ✅ Add to workflow (`.github/workflows/servicenow-change-rest.yaml`)
4. ✅ Create ServiceNow table (`sn_devops_work_item`)
5. ✅ Test with sample commits
6. ✅ Verify in ServiceNow
7. ✅ Add to change request form (Related List)
8. ✅ Document team conventions
9. ✅ Monitor coverage metrics

---

## References

- **GitHub Issues API**: https://docs.github.com/en/rest/issues/issues
- **ServiceNow REST API**: https://developer.servicenow.com/dev.do#!/reference/api/vancouver/rest
- **Git Commit Conventions**: https://www.conventionalcommits.org/
- **GitHub Actions Context**: https://docs.github.com/en/actions/learn-github-actions/contexts#github-context

---

**Document Owner:** DevOps Team
**Last Review:** 2025-10-28
**Next Review:** 2025-11-28
