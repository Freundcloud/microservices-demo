# ServiceNow Security Tools Registration Guide

## Problem

The **Security Tools** tab in ServiceNow DevOps Change (https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/.../params/selected-tab-index/6) is empty.

## Root Cause

Security scan results are being uploaded as **file attachments** to change requests, but ServiceNow DevOps Change Velocity requires **structured security scan data** registered via the ServiceNow DevOps Security Results API.

## Solution

Use the **ServiceNow DevOps Security Results** GitHub Action to register security scan results with proper tool metadata.

### GitHub Action: `ServiceNow/servicenow-devops-security-result@v3.1.0`

## Implementation Steps

### 1. Register Security Scan Results

Add the `servicenow-devops-security-result` action **after each security scan job** in `.github/workflows/security-scan.yaml`.

### Example: CodeQL Registration

```yaml
- name: Register CodeQL Security Results in ServiceNow
  if: always()
  uses: ServiceNow/servicenow-devops-security-result@v3.1.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'CodeQL Analysis (${{ matrix.language }})'
    security-result-attributes: '{
      "scanner": "CodeQL",
      "scannerVersion": "latest",
      "projectName": "${{ github.repository }}",
      "projectId": "${{ github.repository_id }}",
      "scanId": "${{ github.run_id }}-codeql-${{ matrix.language }}",
      "securityToolId": "codeql"
    }'
```

### 2. Supported Security Scanners

Based on our security-scan.yaml workflow, we need to register:

| Scanner | Tool ID | Scanner Name | Notes |
|---------|---------|--------------|-------|
| **CodeQL** | codeql | CodeQL | GitHub Advanced Security SAST |
| **Semgrep** | semgrep | Semgrep | SAST security patterns |
| **Trivy** | trivy | Trivy | Container vulnerability scanning |
| **OWASP Dependency Check** | owasp-dependency-check | OWASP Dependency Check | Dependency vulnerabilities |
| **Checkov** | checkov | Checkov | IaC security scanning |
| **tfsec** | tfsec | tfsec | Terraform security scanning |
| **Polaris** | polaris | Polaris | Kubernetes manifest security |
| **Kubesec** | kubesec | Kubesec | Kubernetes security hardening |

### 3. Required Parameters

- **devops-integration-token**: ServiceNow DevOps integration token
- **instance-url**: ServiceNow instance URL
- **tool-id**: GitHub tool sys_id from ServiceNow
- **context-github**: GitHub context (JSON)
- **job-name**: Name of the security scan job
- **security-result-attributes**: JSON with scanner metadata

### 4. Security Result Attributes Schema

```json
{
  "scanner": "Tool Name",
  "scannerVersion": "version or 'latest'",
  "projectName": "repository name",
  "projectId": "repository ID",
  "scanId": "unique scan identifier",
  "securityToolId": "tool-id-slug"
}
```

## Benefits

1. ✅ **Security Tools Tab Populated**: All security tools will appear in ServiceNow DevOps Change
2. ✅ **Structured Security Data**: Security scan results stored in ServiceNow database
3. ✅ **Change Policy Evaluation**: ServiceNow can evaluate security scan results for approval
4. ✅ **DORA Metrics**: Security scan data contributes to DevOps metrics
5. ✅ **Audit Trail**: Complete security scan history in ServiceNow
6. ✅ **Compliance**: Evidence for security compliance requirements

## Next Steps

1. **Modify `.github/workflows/security-scan.yaml`** to add security result registration
2. **Test workflow** to ensure security tools appear in ServiceNow
3. **Verify** Security Tools tab shows all 8 security scanners
4. **Configure** change policies based on security scan results (optional)

## References

- [ServiceNow DevOps Security Results Action](https://github.com/marketplace/actions/servicenow-devops-security-results)
- [ServiceNow DevOps Security Tool Framework](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/security-tool-framework.html)
- [ServiceNow DevOps Change Velocity](https://www.servicenow.com/products/devops.html)
