# Register ServiceNow Work Items

Composite action to extract GitHub issues from commit messages and register them as ServiceNow work items for traceability.

## Overview

This action automatically:
- Extracts issue references from commit messages (e.g., "Fixes #123", "Closes #456")
- Fetches issue details from GitHub API
- Creates work items in ServiceNow `sn_devops_work_item` table
- Links work items to ServiceNow project for visibility
- Skips duplicates if work item already exists

## Usage

### Basic Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for commit history

      - name: Register Work Items
        uses: ./.github/actions/register-work-items
        with:
          servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
          servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
          servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
```

### With Custom Project/Tool IDs

```yaml
- name: Register Work Items
  uses: ./.github/actions/register-work-items
  with:
    servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
    servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
    servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    project-id: 'your-project-sys-id'
    tool-id: 'your-tool-sys-id'
```

### Using Outputs

```yaml
- name: Register Work Items
  id: work-items
  uses: ./.github/actions/register-work-items
  with:
    servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
    servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
    servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

- name: Show Results
  run: |
    echo "Work items registered: ${{ steps.work-items.outputs.work-items-registered }}"
    echo "Work item IDs: ${{ steps.work-items.outputs.work-item-ids }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `servicenow-username` | ServiceNow username for authentication | Yes | - |
| `servicenow-password` | ServiceNow password for authentication | Yes | - |
| `servicenow-instance-url` | ServiceNow instance URL | Yes | - |
| `project-id` | ServiceNow project sys_id | No | `c6c9eb71c34d7a50b71ef44c05013194` |
| `tool-id` | ServiceNow tool sys_id | No | `f62c4e49c3fcf614e1bbf0cb050131ef` |

## Outputs

| Output | Description |
|--------|-------------|
| `work-items-registered` | Number of work items successfully registered |
| `work-item-ids` | Comma-separated list of work item sys_ids |

## How It Works

### Step 1: Extract Issue References

Scans commit messages in the push for issue references:

**Supported Patterns:**
- `Fixes #123`
- `Closes #456`
- `Resolves #789`
- `Issue #123`
- `#123` (standalone)

**Commit Range:**
- Uses `github.event.before..github.sha` for push events
- Falls back to last 10 commits if range not available

### Step 2: Fetch GitHub Issue Details

For each extracted issue number:
1. Calls GitHub API: `GET /repos/{owner}/{repo}/issues/{number}`
2. Extracts title, state, and URL
3. Skips if issue doesn't exist or API call fails

### Step 3: Check for Duplicates

Before creating, checks if work item already exists:
```
GET /api/now/table/sn_devops_work_item?sysparm_query=url={issue_url}
```

Skips creation if duplicate found.

### Step 4: Create Work Item

Creates work item in ServiceNow:

```json
{
  "name": "Issue title from GitHub",
  "external_id": "123",
  "url": "https://github.com/owner/repo/issues/123",
  "status": "open",
  "type": "issue",
  "project": "project_sys_id",
  "tool": "tool_sys_id"
}
```

## Commit Message Examples

### Good Examples (Will Extract)

```bash
git commit -m "Fixes #77 - Add SBOM support to security scanning"
git commit -m "Closes #78, #79 - Complete orchestration tasks and insights"
git commit -m "Resolves #80: Implement work items tracking"
git commit -m "Issue #81 - Refactor workflows for better performance"
git commit -m "Add caching support (#82)"
```

### Won't Extract

```bash
git commit -m "Update README"  # No issue reference
git commit -m "See issue 123"  # Missing # symbol
git commit -m "PR #123"        # PR, not issue (will try but may fail)
```

## Work Item Structure

Created work items have:

```json
{
  "number": "WI0001196",
  "name": "ServiceNow Orchestration Tasks - Track GitHub Actions Jobs",
  "external_id": "79",
  "url": "https://github.com/Freundcloud/microservices-demo/issues/79",
  "status": "closed",
  "type": "issue",
  "project": {
    "value": "c6c9eb71c34d7a50b71ef44c05013194",
    "display_value": "Freundcloud/microservices-demo"
  },
  "tool": {
    "value": "f62c4e49c3fcf614e1bbf0cb050131ef",
    "display_value": "GithHubARC"
  }
}
```

## Error Handling

This action is **non-blocking** by design:

- ⚠️ If no issues found: Logs info message, exits cleanly
- ⚠️ If GitHub API fails: Logs warning, skips that issue
- ⚠️ If ServiceNow API fails: Logs warning, continues to next issue
- ⚠️ If duplicate exists: Logs info, skips creation
- ✅ Workflow continues regardless of failures

**Reasons creation might fail:**
- GitHub issue doesn't exist or is inaccessible
- ServiceNow authentication issues
- ServiceNow table permissions
- Network connectivity issues
- Invalid project or tool sys_id

## Requirements

- **Checkout**: Must use `actions/checkout@v4` with `fetch-depth: 0` for commit history
- **ServiceNow**: DevOps plugin with `sn_devops_work_item` table
- **GitHub**: `GITHUB_TOKEN` with issues read permission (automatic)
- **Secrets**: ServiceNow credentials configured in repository secrets

## Performance Impact

- **Commit Parsing**: ~100ms (local git operation)
- **GitHub API Calls**: ~200ms per issue
- **ServiceNow API Calls**: ~300ms per issue (check + create)
- **Total**: ~500ms per issue referenced

**Example**: Commit message with 3 issues = ~1.5 seconds added to workflow

## Use Cases

### 1. Deployment Tracking

```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Register Work Items
        uses: ./.github/actions/register-work-items
        with:
          servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
          servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
          servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

      - name: Deploy
        run: ./deploy.sh
```

**Result**: All issues referenced in deployed commits tracked in ServiceNow

### 2. Change Request Linking

```yaml
jobs:
  create-change:
    steps:
      - name: Register Work Items
        id: work-items
        uses: ./.github/actions/register-work-items
        # ...

      - name: Create Change Request
        env:
          WORK_ITEMS: ${{ steps.work-items.outputs.work-item-ids }}
        run: |
          # Link work items to change request
          ./create-change-request.sh "$WORK_ITEMS"
```

**Result**: Change request automatically linked to relevant work items

### 3. Compliance Audit Trail

Link code changes → issues → work items → change requests:

```
Commit "Fixes #77"
  ↓
GitHub Issue #77
  ↓
ServiceNow Work Item WI0001196
  ↓
Change Request CHR0030462
```

## Viewing Work Items

**In ServiceNow:**
1. Navigate to: DevOps > Work Items
2. Or view in project:
   - https://your-instance.service-now.com/now/nav/ui/classic/params/target/sn_devops_project.do?sys_id=PROJECT_ID
   - Click "Work Items" related list

**Work Item Details Include:**
- Number (e.g., WI0001196)
- Name (GitHub issue title)
- External ID (GitHub issue number)
- URL (link to GitHub issue)
- Status (open/closed)
- Type (issue)
- Project linkage ✅
- Tool (GitHub) ✅

## Troubleshooting

### No work items created

**Check:**
- Commit messages contain issue references with `#` symbol
- `actions/checkout` has `fetch-depth: 0`
- GitHub issues exist and are accessible
- ServiceNow credentials are correct

### GitHub API failures

**Causes:**
- Issue doesn't exist
- Issue is in different repository
- `GITHUB_TOKEN` lacks permissions
- Rate limiting (rare)

**Solution:** Check GitHub Actions logs for specific error

### ServiceNow authentication failed

**Causes:**
- Invalid credentials
- User lacks write access to `sn_devops_work_item` table
- Wrong instance URL format

**Solution:**
- Verify secrets in repository settings
- Confirm user permissions in ServiceNow
- Use format: `https://instance.service-now.com` (no trailing slash)

### Duplicate work items

**Expected Behavior:** Action checks for existing work items by URL and skips duplicates.

**If duplicates appear:** Work items may have been created manually or by different mechanism.

## Related Documentation

- [ServiceNow Work Items Research](../../../docs/SERVICENOW-PACKAGES-WORKITEMS-ANALYSIS.md)
- [ServiceNow Integration Guide](../../../docs/SERVICENOW-SESSION-SUMMARY-2025-11-07.md)
- [Orchestration Tasks Action](../register-orchestration-task/README.md)

## Version History

- **v1.0.0** (2025-11-07): Initial release
  - Commit message parsing
  - GitHub API integration
  - Duplicate detection
  - Non-blocking error handling

## License

MIT

## Author

Generated by Claude Code - https://claude.com/claude-code
