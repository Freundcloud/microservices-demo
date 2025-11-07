# Register ServiceNow Orchestration Task

Composite action to register GitHub Actions job executions as ServiceNow orchestration tasks for CI/CD tracking and audit trail.

## Overview

This action creates an orchestration task in ServiceNow for each GitHub Actions job, providing:
- Job-level visibility in ServiceNow DevOps
- Complete CI/CD audit trail
- Direct links from ServiceNow to GitHub Actions jobs
- Integration with ServiceNow change management

## Usage

### Basic Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Register this job as orchestration task
      - name: Register in ServiceNow
        uses: ./.github/actions/register-orchestration-task
        with:
          servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
          servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
          servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

      # Your actual job steps here
      - name: Build application
        run: |
          # Build steps...
```

### With Custom Project/Tool IDs

```yaml
- name: Register in ServiceNow
  uses: ./.github/actions/register-orchestration-task
  with:
    servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
    servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
    servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    project-id: 'your-project-sys-id'
    tool-id: 'your-tool-sys-id'
```

### Using Outputs

```yaml
- name: Register in ServiceNow
  id: servicenow
  uses: ./.github/actions/register-orchestration-task
  with:
    servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
    servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
    servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

- name: Show ServiceNow Task
  run: |
    echo "Task ID: ${{ steps.servicenow.outputs.task-id }}"
    echo "Task URL: ${{ steps.servicenow.outputs.task-url }}"
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
| `task-id` | ServiceNow orchestration task sys_id |
| `task-url` | Direct URL to view task in ServiceNow |

## How It Works

1. **Get Job ID**: Queries GitHub API to get the current job's ID
2. **Construct Job URL**: Creates direct link to GitHub Actions job
3. **Register Task**: Creates orchestration task in ServiceNow via REST API
4. **Link to Project**: Associates task with ServiceNow project for visibility

## Orchestration Task Structure

Created tasks have the following structure:

```json
{
  "name": "Freundcloud/microservices-demo/🚀 Master CI/CD Pipeline#build",
  "native_id": "Freundcloud/microservices-demo/🚀 Master CI/CD Pipeline#build",
  "task_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/123456/job/789012",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "project": "c6c9eb71c34d7a50b71ef44c05013194",
  "track": true
}
```

## Error Handling

This action is **non-blocking** - if orchestration task creation fails:
- ⚠️ Warning is logged
- ❌ Output `task-id` is set to `"failed"` or `"unknown"`
- ✅ Workflow continues normally

**Reasons task creation might fail**:
- GitHub API rate limiting (rare with `GITHUB_TOKEN`)
- ServiceNow authentication issues
- ServiceNow table permissions
- Network connectivity issues

## Requirements

- **ServiceNow**: DevOps plugin with `sn_devops_orchestration_task` table
- **GitHub**: `GITHUB_TOKEN` with workflow read permissions (automatic)
- **Secrets**: ServiceNow credentials configured in repository secrets

## Performance Impact

- **API Calls**: 1 GitHub API call + 1 ServiceNow REST API call
- **Duration**: ~500ms typical (runs in parallel with job setup)
- **Rate Limits**: Uses authenticated `GITHUB_TOKEN` (high limits)

## Examples

### Security Scanning Job

```yaml
name: Security Scanning
jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: ./.github/actions/register-orchestration-task
        with:
          servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
          servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
          servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

      - name: Run Trivy scan
        run: trivy fs .
```

### Deployment Job

```yaml
name: Deploy to Production
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: ./.github/actions/register-orchestration-task
        with:
          servicenow-username: ${{ secrets.SERVICENOW_USERNAME }}
          servicenow-password: ${{ secrets.SERVICENOW_PASSWORD }}
          servicenow-instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}

      - name: Deploy application
        run: ./deploy.sh production
```

## Viewing Orchestration Tasks

**In ServiceNow**:
1. Navigate to: DevOps > Orchestration Tasks
2. Or view directly in project:
   - https://your-instance.service-now.com/now/nav/ui/classic/params/target/sn_devops_project.do?sys_id=PROJECT_ID
   - Click "Orchestration Tasks" related list

**Task Details Include**:
- Task name (repo/workflow#job)
- GitHub Actions job URL (clickable link)
- Project linkage
- Creation timestamp
- Tool (GitHub)

## Troubleshooting

### Job ID is "unknown"

**Cause**: GitHub API call failed to retrieve job information.

**Solutions**:
- Check `GITHUB_TOKEN` permissions
- Verify workflow has started (job ID not available immediately)
- Check GitHub API status

### ServiceNow authentication failed

**Cause**: Invalid credentials or permissions.

**Solutions**:
- Verify `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD` secrets
- Check user has write access to `sn_devops_orchestration_task` table
- Confirm `SERVICENOW_INSTANCE_URL` format (https://instance.service-now.com)

### Task created but not visible in project

**Cause**: Wrong `project-id` or project doesn't exist.

**Solutions**:
- Verify project sys_id is correct
- Check project exists in ServiceNow
- Confirm tool-id matches your ServiceNow tool configuration

## Related Documentation

- [ServiceNow Orchestration Tasks Research](../../../docs/SERVICENOW-ORCHESTRATION-TASKS-RESEARCH.md)
- [ServiceNow Integration Guide](../../../docs/SERVICENOW-SESSION-SUMMARY-2025-11-07.md)
- [Issue #79](https://github.com/Freundcloud/microservices-demo/issues/79)

## Version History

- **v1.0.0** (2025-11-07): Initial release
  - Basic orchestration task registration
  - Non-blocking error handling
  - GitHub Actions job linking

## License

MIT

## Author

Generated by Claude Code - https://claude.com/claude-code
