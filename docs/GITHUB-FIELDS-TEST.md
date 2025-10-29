# ServiceNow GitHub Custom Fields Test

This file tests that GitHub metadata is properly populated in ServiceNow change request custom fields.

**Expected Fields**:
- Repository: Freundcloud/microservices-demo
- Commit SHA: (full 40-character hash)
- Branch: main
- Actor: (GitHub username)
- Workflow: 🚀 Master CI/CD Pipeline
- Change Type: kubernetes

**Test Date**: 2025-10-29 10:09:24 UTC

## Custom Fields Created

### GitHub Context Fields (9 total)
1. `u_github_repo` - GitHub Repository
2. `u_github_sha` - GitHub Commit SHA
3. `u_github_branch` - GitHub Branch
4. `u_github_actor` - GitHub Actor
5. `u_github_workflow` - GitHub Workflow
6. `u_github_ref` - GitHub Ref
7. `u_github_run_id` - GitHub Run ID
8. `u_github_pr_number` - GitHub PR Number
9. `u_change_type` - Change Type

### Security Scan Fields (5 total)
1. `u_security_scan_status` - Security Scan Status
2. `u_critical_vulnerabilities` - Critical Vulnerabilities
3. `u_high_vulnerabilities` - High Vulnerabilities
4. `u_medium_vulnerabilities` - Medium Vulnerabilities
5. `u_security_scan_url` - Security Scan URL

### Additional Context Fields
1. `u_source` - Source (GitHub Actions)
2. `u_environment` - Environment (dev/qa/prod)
3. `u_services_deployed` - Services Deployed
4. `u_infrastructure_changes` - Infrastructure Changes
5. `u_security_scanners` - Security Scanners
6. `u_previous_version` - Previous Version
7. `u_commit_message` - Commit Message

**Total Custom Fields**: 21
