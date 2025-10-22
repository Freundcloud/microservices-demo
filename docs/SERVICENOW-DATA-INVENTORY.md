# ServiceNow Data Inventory

This document provides a complete inventory of all data being sent from GitHub Actions to ServiceNow, including direct URLs for verification.

## Quick Access URLs

**ServiceNow Instance**: `https://calitiiltddemo3.service-now.com`

### Primary Dashboards

| Dashboard | URL | Description |
|-----------|-----|-------------|
| **DevOps Changes** | [View](https://calitiiltddemo3.service-now.com/now/devops-change/changes) | Modern change management view |
| **Change Requests (Classic)** | [View](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/change_request_list.do) | Traditional change request list |
| **All Apps / DevOps** | [View](https://calitiiltddemo3.service-now.com/$pa_dashboard.do) | ServiceNow home - navigate to DevOps app |

## Data Being Sent to ServiceNow

### 1. Change Requests

**Table**: `change_request`
**View URL**: [Change Request List](https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do)

**Data Fields**:
- `short_description` - Auto-generated from commit/workflow
- `description` - Detailed deployment information
- `u_source` - "GitHub Actions"
- `u_correlation_id` - GitHub Run ID for traceability
- `u_repository` - Repository name
- `u_branch` - Git branch name
- `u_commit_sha` - Git commit SHA
- `u_commit_message` - Commit message
- `u_actor` - GitHub user who triggered deployment
- `u_workflow_url` - Direct link to GitHub Actions workflow
- `u_environment` - Target environment (dev/qa/prod)
- `u_risk_level` - Calculated risk (Low/Medium/High)
- `u_business_service` - "Microservices Demo Application"
- `state` - Change state (New, Assessment, Approved, etc.)

**Example Query**:
```bash
# Filter by source
https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do?sysparm_query=u_source=GitHub%20Actions
```

**Created By**: `servicenow-integration.yaml` workflow

---

### 2. Test Results

**Table**: `sn_devops_test_result`
**View URL**: [Test Results List](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_test_result_list.do)

**Test Suites Registered**:

| Test Suite | Description | Workflow |
|------------|-------------|----------|
| Security Scans | 10 security scanners | `security-scan.yaml` |
| Trivy Container Scan | Container vulnerability scanning | `security-scan.yaml` |
| CodeQL (JavaScript) | SAST for JavaScript/TypeScript | `security-scan.yaml` |
| CodeQL (Python) | SAST for Python | `security-scan.yaml` |
| CodeQL (Go) | SAST for Go | `security-scan.yaml` |
| CodeQL (Java) | SAST for Java | `security-scan.yaml` |
| CodeQL (C#) | SAST for C# | `security-scan.yaml` |
| Semgrep | Pattern-based security | `security-scan.yaml` |
| Checkov | IaC security | `security-scan.yaml` |
| tfsec | Terraform security | `security-scan.yaml` |
| Polaris | Kubernetes security | `security-scan.yaml` |
| Dependency Scan | Grype/SBOM vulnerability scan | `security-scan.yaml` |

**Data Fields**:
- `test_suite_name` - Name of test suite
- `test_result` - "passed" or "failed"
- `test_duration` - Duration in seconds
- `test_url` - Link to test results
- `correlation_id` - Links to change request
- `change_request_number` - CR number
- `work_notes` - Detailed results

**Created By**: `upload-test-results-servicenow.yaml` workflow

---

### 3. Security Scan Results

**Table**: `sn_devops_security_result`
**View URL**: [Security Results List](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_security_result_list.do)

**Security Tools**:
- **Trivy** - Container image scanning
- **CodeQL** - Static application security testing (5 languages)
- **Semgrep** - Custom pattern matching
- **Checkov** - Infrastructure as Code security
- **tfsec** - Terraform-specific security
- **Kubesec** - Kubernetes manifest security
- **Polaris** - Kubernetes best practices
- **Gitleaks** - Secret detection
- **OWASP Dependency Check** - Known vulnerabilities
- **Grype** - SBOM-based vulnerability scanning

**Data Fields**:
- `security_tool` - Tool name (e.g., "trivy", "codeql")
- `security_result_state` - State (e.g., "passed", "failed")
- `critical_count` - Number of critical vulnerabilities
- `high_count` - Number of high severity vulnerabilities
- `medium_count` - Number of medium severity vulnerabilities
- `low_count` - Number of low severity vulnerabilities
- `total_count` - Total vulnerabilities found
- `correlation_id` - Links to change request

**Created By**: `security-scan.yaml` workflow uploads SARIF results

---

### 4. Work Items

**Table**: `sn_devops_work_item`
**View URL**: [Work Items List](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_work_item_list.do)

**Work Item Types**:
- Deployment preparation
- Security scan execution
- Test result registration
- Infrastructure changes
- Application deployment

**Data Fields**:
- `name` - Work item name
- `type` - Type of work
- `state` - Current state
- `correlation_id` - Links to change request
- `description` - Detailed information

**Created By**: Various workflows throughout the pipeline

---

### 5. EKS Cluster Information (CMDB)

**Table**: `u_eks_cluster`
**View URL**: [EKS Clusters List](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/u_eks_cluster_list.do)

**Data Fields**:
- `name` - EKS cluster name ("microservices")
- `cluster_arn` - AWS ARN
- `cluster_version` - Kubernetes version (e.g., "1.30")
- `cluster_endpoint` - API server endpoint
- `cluster_status` - Status (ACTIVE, etc.)
- `vpc_id` - VPC ID
- `node_group_count` - Number of node groups
- `total_nodes` - Total nodes across all node groups
- `region` - AWS region (eu-west-2)

**Created By**: `eks-discovery.yaml` workflow (runs every 6 hours + after deployments)

---

### 6. Microservices Information (CMDB)

**Table**: `u_microservice`
**View URL**: [Microservices List](https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/u_microservice_list.do)

**Services Tracked** (12 total):
1. frontend
2. cartservice
3. productcatalogservice
4. currencyservice
5. paymentservice
6. shippingservice
7. emailservice
8. checkoutservice
9. recommendationservice
10. adservice
11. loadgenerator (qa/prod only)
12. redis-cart

**Data Fields (per service)**:
- `name` - Service name
- `namespace` - Kubernetes namespace
- `replicas` - Current replica count
- `image` - Container image
- `cluster` - Reference to EKS cluster CI
- `ready_replicas` - Number of ready replicas
- `cpu_request` - CPU resource request
- `memory_request` - Memory resource request
- `environment` - Environment (dev/qa/prod)

**Created By**: `eks-discovery.yaml` workflow

---

## Verification Script

Use the provided verification script to pull all data:

```bash
# Set credentials
export SERVICENOW_USERNAME="your-username"
export SERVICENOW_PASSWORD="your-password"

# Run verification
./scripts/verify-servicenow-integration.sh
```

The script will:
1. Query all relevant ServiceNow tables
2. Display the data in human-readable format
3. Provide direct URLs to each record
4. Show statistics and verify integration health

---

## Data Flow Diagram

```
GitHub Actions Workflow
       ↓
[1] Create Change Request → change_request table
       ↓
[2] Run Security Scans → sn_devops_security_result table
       ↓
[3] Upload Test Results → sn_devops_test_result table
       ↓
[4] Register Work Items → sn_devops_work_item table
       ↓
[5] Deploy Application
       ↓
[6] Discover EKS Cluster → u_eks_cluster table
       ↓
[7] Discover Microservices → u_microservice table
       ↓
[8] Update Change Request → change_request (state updated)
```

---

## Custom Fields Required

To support all this data, the following custom fields must be created in ServiceNow:

### On `change_request` table:
- `u_source` (String)
- `u_correlation_id` (String)
- `u_repository` (String)
- `u_branch` (String)
- `u_commit_sha` (String)
- `u_commit_message` (String)
- `u_actor` (String)
- `u_workflow_url` (URL)
- `u_environment` (Choice: dev/qa/prod)
- `u_risk_level` (Choice: Low/Medium/High)
- `u_business_service` (String)

### Custom Tables (CMDB):
- `u_eks_cluster` - For EKS cluster CIs
- `u_microservice` - For microservice CIs

---

## API Endpoints Used

| Endpoint | Purpose | HTTP Method |
|----------|---------|-------------|
| `/api/now/table/change_request` | Create/update change requests | POST, PATCH |
| `/api/sn_devops/devops/orchestration/changeControl` | DevOps change control | POST |
| `/api/sn_devops/v1/devops/tool/test` | Register test results | POST |
| `/api/sn_devops/v1/devops/artifact/registration` | Register artifacts | POST |
| `/api/sn_devops/v1/devops/security/result` | Upload security results | POST |
| `/api/now/table/u_eks_cluster` | EKS cluster discovery | POST, PATCH |
| `/api/now/table/u_microservice` | Microservice discovery | POST, PATCH |

---

## Troubleshooting

### No Data Appearing?

1. **Check credentials**: Run verification script to test API access
2. **Check custom fields**: Ensure all custom fields exist in ServiceNow
3. **Check workflow runs**: View GitHub Actions to confirm workflows executed
4. **Check ServiceNow logs**: System Logs > REST API Logs
5. **Verify URL accessibility**: Some tables may require specific roles or plugins

### URL Not Found Errors?

If you get "Page not found" or empty lists, try these alternatives:

**General Navigation**:
1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Click "All" in the top left corner (Application Navigator)
3. Type "DevOps" in the search box
4. Browse available DevOps modules

**For DevOps Features**:
- Type "DevOps Change" in navigator → Click "Changes"
- Type "Test Results" in navigator → Navigate to DevOps > Testing
- Type "Security Results" in navigator → Navigate to DevOps > Security

**For Work Items** (if empty or not accessible):
- Use the API directly: `GET /api/now/table/sn_devops_work_item`
- Check if sn_devops plugin is fully activated
- Work items might be attached to change requests instead of separate table
- Alternative: View work notes on change requests
- Try: https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do (without /now/nav/ prefix)

**For Test Results**:
- Alternative URL: https://calitiiltddemo3.service-now.com/sn_devops_test_result_list.do
- Or use Application Navigator: DevOps > Testing > Test Results
- Or direct table access: /api/now/table/sn_devops_test_result

**For Security Results**:
- Alternative URL: https://calitiiltddemo3.service-now.com/sn_devops_security_result_list.do
- Or use Application Navigator: DevOps > Security > Security Results
- Or direct table access: /api/now/table/sn_devops_security_result

**For Custom CMDB Tables**:
- If u_eks_cluster or u_microservice don't exist, they need to be created
- See setup documentation for CMDB CI class creation
- Alternative: Use standard `cmdb_ci` table and filter by class
- Try simple URLs: /u_eks_cluster_list.do or /u_microservice_list.do

### Data is Incomplete?

1. **Check workflow logs**: Look for API errors in GitHub Actions output
2. **Verify permissions**: ServiceNow user needs proper roles
3. **Check correlation IDs**: Use to link records across tables

### Need to Manually Verify?

1. Find the GitHub Run ID from workflow
2. Use as correlation_id in ServiceNow searches
3. Example query: `u_correlation_id=18715511857`

---

## Related Documentation

- [ServiceNow Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [ServiceNow Test Results Integration](SERVICENOW-TEST-RESULTS-INTEGRATION.md)
- [ServiceNow Work Items Guide](SERVICENOW-WORK-ITEMS-APPROVAL-EVIDENCE.md)
- [What's New](WHATS-NEW.md) - Latest features and changes
