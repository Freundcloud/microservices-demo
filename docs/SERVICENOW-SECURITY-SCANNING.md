# ServiceNow Security Scanning Integration

> Complete guide for integrating GitHub security scan results with ServiceNow

**Last Updated**: 2025-10-16
**ServiceNow Version**: Zurich v6.1.0
**Status**: 🚧 Implementation Guide

---

## Overview

This guide explains how to upload security scan results from GitHub Actions workflows to ServiceNow CMDB for centralized security reporting and tracking.

## Security Scan Tools

Our workflows use the following security scanning tools:

| Tool | Category | What It Scans | Output Format |
|------|----------|---------------|---------------|
| **CodeQL** | SAST | Python, JavaScript, Go, Java, C# code | SARIF |
| **Semgrep** | SAST | Multi-language static analysis | SARIF |
| **Trivy** | Vulnerability | Filesystem, containers, dependencies | SARIF |
| **Checkov** | IaC Security | Terraform configurations | SARIF |
| **tfsec** | IaC Security | Terraform configurations | SARIF |
| **Kubesec** | K8s Security | Kubernetes manifests | JSON |
| **Polaris** | K8s Best Practices | Kubernetes manifests | JSON |
| **OWASP Dependency Check** | Dependency | All dependencies | SARIF |
| **License Checker** | Compliance | Python, Node.js licenses | Text |

## ServiceNow Table Design

### u_security_scan_result Table

**Purpose**: Store individual security findings from all scan tools

**Extends**: Task (or create standalone table)

**Fields**:

| Field Name | Type | Length | Description | Mandatory |
|------------|------|--------|-------------|-----------|
| u_scan_id | String | 100 | Unique scan identifier (workflow run ID) | Yes |
| u_scan_type | Choice | - | CodeQL, Semgrep, Trivy, Checkov, etc. | Yes |
| u_scan_date | Date/Time | - | When the scan was performed | Yes |
| u_finding_id | String | 255 | Unique finding identifier | Yes |
| u_severity | Choice | - | CRITICAL, HIGH, MEDIUM, LOW, INFO | Yes |
| u_title | String | 255 | Finding title/summary | Yes |
| u_description | Text | 4000 | Detailed finding description | No |
| u_file_path | String | 512 | File path where issue found | No |
| u_line_number | Integer | - | Line number in file | No |
| u_rule_id | String | 255 | Rule/check ID that triggered | No |
| u_cve_id | String | 100 | CVE ID if applicable | No |
| u_cvss_score | Decimal | - | CVSS score if applicable | No |
| u_status | Choice | - | Open, In Progress, Resolved, False Positive | Yes |
| u_repository | String | 255 | GitHub repository name | Yes |
| u_branch | String | 100 | Git branch | Yes |
| u_commit_sha | String | 40 | Git commit SHA | Yes |
| u_github_url | URL | 1024 | Link to GitHub finding | No |
| u_sarif_data | JSON | - | Raw SARIF data | No |
| u_assigned_to | Reference | - | User assigned to fix | No |
| u_cmdb_ci | Reference | - | Related CI (microservice/cluster) | No |
| u_remediation_notes | Text | 4000 | Notes on how to fix | No |
| u_false_positive | Boolean | - | Mark as false positive | No |
| u_suppressed | Boolean | - | Suppressed finding | No |
| u_fixed_in_commit | String | 40 | Commit SHA that fixed it | No |

**Choice Field Values**:

```javascript
// u_scan_type
["CodeQL-Python", "CodeQL-JavaScript", "CodeQL-Go", "CodeQL-Java", "CodeQL-CSharp",
 "Semgrep", "Trivy-Filesystem", "Checkov", "tfsec", "Kubesec", "Polaris", "OWASP"]

// u_severity
["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO", "WARNING", "NOTE"]

// u_status
["Open", "In Progress", "Resolved", "False Positive", "Suppressed", "Risk Accepted"]
```

### u_security_scan_summary Table

**Purpose**: Store summary of each scan run

**Fields**:

| Field Name | Type | Length | Description |
|------------|------|--------|-------------|
| u_scan_id | String | 100 | Unique scan identifier |
| u_workflow_run_id | String | 100 | GitHub Actions run ID |
| u_scan_date | Date/Time | - | When scan was performed |
| u_repository | String | 255 | GitHub repository |
| u_branch | String | 100 | Git branch |
| u_commit_sha | String | 40 | Git commit SHA |
| u_total_findings | Integer | - | Total findings count |
| u_critical_count | Integer | - | Critical severity count |
| u_high_count | Integer | - | High severity count |
| u_medium_count | Integer | - | Medium severity count |
| u_low_count | Integer | - | Low severity count |
| u_info_count | Integer | - | Info severity count |
| u_tools_run | String | 1000 | Comma-separated list of tools |
| u_duration_seconds | Integer | - | Scan duration |
| u_github_url | URL | 1024 | Link to workflow run |
| u_status | Choice | - | Success, Failed, Partial |

## Workflow Integration

### Modified Security Workflow

Add these steps to `.github/workflows/security-scan-servicenow.yaml`:

```yaml
# New job after security-summary
upload-to-servicenow:
  name: Upload Security Results to ServiceNow
  needs: [codeql-analysis, semgrep-scan, trivy-fs-scan, iac-scan, k8s-manifest-scan]
  if: always() && secrets.SERVICENOW_PASSWORD != ''
  runs-on: ubuntu-latest

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Download all SARIF files
      uses: actions/download-artifact@v4
      with:
        path: sarif-results

    - name: Aggregate Security Findings
      run: |
        # Install jq for JSON processing
        sudo apt-get update && sudo apt-get install -y jq

        # Create aggregated results
        bash scripts/aggregate-security-results.sh

    - name: Upload to ServiceNow
      env:
        SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
        SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
        GITHUB_REPOSITORY: ${{ github.repository }}
        GITHUB_RUN_ID: ${{ github.run_id }}
        GITHUB_SHA: ${{ github.sha }}
        GITHUB_REF_NAME: ${{ github.ref_name }}
      run: |
        bash scripts/upload-security-to-servicenow.sh

    - name: Create ServiceNow Summary
      run: |
        echo "## ServiceNow Security Upload" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "✅ Security findings uploaded to ServiceNow" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "**View in ServiceNow**:" >> $GITHUB_STEP_SUMMARY
        echo "- [Security Scan Results](${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_result_list.do)" >> $GITHUB_STEP_SUMMARY
        echo "- [Scan Summaries](${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=u_security_scan_summary_list.do)" >> $GITHUB_STEP_SUMMARY
```

## SARIF to ServiceNow Mapping

SARIF (Static Analysis Results Interchange Format) is the standard output from most security tools. Here's how we map it:

### SARIF Structure
```json
{
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "CodeQL",
          "version": "2.15.0"
        }
      },
      "results": [
        {
          "ruleId": "js/sql-injection",
          "level": "error",
          "message": {
            "text": "SQL injection vulnerability"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "src/api/users.js"
                },
                "region": {
                  "startLine": 42,
                  "startColumn": 10
                }
              }
            }
          ],
          "properties": {
            "security-severity": "8.1"
          }
        }
      ]
    }
  ]
}
```

### Mapping to ServiceNow

| SARIF Field | ServiceNow Field | Transformation |
|-------------|------------------|----------------|
| `tool.driver.name` | `u_scan_type` | Direct |
| `run.invocations[0].startTimeUtc` | `u_scan_date` | Parse datetime |
| `result.ruleId` | `u_rule_id` + `u_finding_id` | Combine with location |
| `result.level` | `u_severity` | Map: error→HIGH, warning→MEDIUM, note→LOW |
| `result.message.text` | `u_title` | First 255 chars |
| `result.message.text` | `u_description` | Full text |
| `locations[0].physicalLocation.artifactLocation.uri` | `u_file_path` | Direct |
| `locations[0].physicalLocation.region.startLine` | `u_line_number` | Direct |
| `properties.security-severity` | `u_cvss_score` | Parse float |
| `properties.tags` (cve-*) | `u_cve_id` | Extract CVE ID |
| Full `result` object | `u_sarif_data` | JSON stringify |

### Severity Mapping

```javascript
const severityMap = {
  // SARIF levels
  "error": "HIGH",
  "warning": "MEDIUM",
  "note": "LOW",
  "none": "INFO",

  // Tool-specific
  "CRITICAL": "CRITICAL",
  "HIGH": "HIGH",
  "MEDIUM": "MEDIUM",
  "LOW": "LOW",

  // CVSS Score ranges
  "9.0-10.0": "CRITICAL",
  "7.0-8.9": "HIGH",
  "4.0-6.9": "MEDIUM",
  "0.1-3.9": "LOW",
  "0.0": "INFO"
};
```

## Scripts

### aggregate-security-results.sh

Creates a consolidated JSON file with all findings:

```bash
#!/bin/bash
# Aggregates all SARIF files into a single JSON structure

SCAN_ID="${GITHUB_RUN_ID}-$(date +%s)"
OUTPUT_FILE="aggregated-security-results.json"

# Initialize output
echo '{"scan_id": "'$SCAN_ID'", "findings": []}' > $OUTPUT_FILE

# Process each SARIF file
for sarif in sarif-results/**/*.sarif; do
  if [ -f "$sarif" ]; then
    # Extract findings and add to aggregated file
    # (Implementation details in actual script)
  fi
done
```

### upload-security-to-servicenow.sh

Uploads findings to ServiceNow via REST API:

```bash
#!/bin/bash
# Uploads aggregated security results to ServiceNow

BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# Upload each finding
jq -c '.findings[]' aggregated-security-results.json | while read -r finding; do
  curl -s -X POST \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_security_scan_result" \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    -H "Content-Type: application/json" \
    -d "$finding"
done
```

## ServiceNow Dashboard

### Create Security Dashboard

1. **Navigate to**: Performance Analytics → Dashboards → Create New

2. **Add Widgets**:
   - **Security Findings by Severity** (Pie Chart)
     - Table: u_security_scan_result
     - Group by: u_severity
     - Filter: u_status=Open

   - **Findings Over Time** (Line Chart)
     - Table: u_security_scan_result
     - Group by: u_scan_date
     - Series: u_severity

   - **Top 10 Vulnerable Files** (Bar Chart)
     - Table: u_security_scan_result
     - Group by: u_file_path
     - Count: u_finding_id

   - **Scan Tool Coverage** (Donut Chart)
     - Table: u_security_scan_summary
     - Group by: u_tools_run

   - **Open Critical/High Findings** (Scorecard)
     - Table: u_security_scan_result
     - Metric: Count
     - Filter: u_severity IN (CRITICAL, HIGH) AND u_status=Open

3. **Add Filters**:
   - Repository dropdown
   - Branch dropdown
   - Date range picker
   - Severity multiselect

## Viewing Results in ServiceNow

### Security Scan Results List

**URL**: `https://your-instance.service-now.com/nav_to.do?uri=u_security_scan_result_list.do`

**Columns to Show**:
- Scan Type
- Severity
- Title
- File Path
- Status
- Scan Date
- Assigned To

**Filters**:
- Status = Open
- Severity IN (CRITICAL, HIGH)
- Repository = microservices-demo

### Drill-Down View

Click any finding to see:
- Full description
- Source code context (file path + line)
- SARIF raw data
- Remediation notes
- Related CI (microservice/cluster)
- Assignment and workflow

## Automated Workflows

### Auto-Assignment Rules

Create Business Rules in ServiceNow:

```javascript
// When new finding created, assign based on file path
(function executeRule(current, previous /*null when async*/) {

  var filePath = current.u_file_path;

  // Map file paths to teams/users
  if (filePath.indexOf('src/frontend') >= 0) {
    current.u_assigned_to = 'frontend_team_lead';
  } else if (filePath.indexOf('src/cartservice') >= 0) {
    current.u_assigned_to = 'backend_team_lead';
  } else if (filePath.indexOf('terraform-aws') >= 0) {
    current.u_assigned_to = 'infrastructure_team_lead';
  }

  // Set priority based on severity
  if (current.u_severity == 'CRITICAL') {
    current.priority = 1;
  } else if (current.u_severity == 'HIGH') {
    current.priority = 2;
  }

})(current, previous);
```

### Notifications

Create Notification Rules:

1. **Critical Finding Notification**
   - When: Record inserted or updated
   - Conditions: Severity = CRITICAL AND Status = Open
   - Send to: Security team + assigned user
   - Template: Critical security finding email

2. **SLA Breach Warning**
   - When: TTR (Time to Remediate) approaching
   - Send to: Assigned user + manager
   - Template: Security SLA warning

## Metrics and Reporting

### Key Metrics

1. **Mean Time to Remediate (MTTR)**
   ```sql
   AVG(DATEDIFF(u_scan_date, sys_updated_on))
   WHERE u_status = 'Resolved'
   ```

2. **Security Debt**
   ```sql
   COUNT(*) WHERE u_status = 'Open'
   GROUP BY u_severity
   ```

3. **False Positive Rate**
   ```sql
   COUNT(*) WHERE u_status = 'False Positive'
   / COUNT(*) * 100
   ```

4. **Trend Analysis**
   ```sql
   COUNT(*)
   GROUP BY MONTH(u_scan_date), u_severity
   ```

### Reports

Create Scheduled Reports:

1. **Weekly Security Summary**
   - New findings this week
   - Resolved findings
   - Open critical/high count
   - Top vulnerable files

2. **Monthly Executive Dashboard**
   - Security posture trend
   - MTTR by team
   - Compliance status
   - Investment in security

## Integration with Change Management

Link security findings to change requests:

```javascript
// When creating change for security fix
var gr = new GlideRecord('u_security_scan_result');
gr.addQuery('u_status', 'In Progress');
gr.addQuery('u_assigned_to', current.assigned_to);
gr.query();

while (gr.next()) {
  // Link finding to change request
  gr.u_related_change = current.sys_id;
  gr.update();
}
```

## Best Practices

1. **Deduplication**: Use `u_finding_id` to avoid duplicate findings across scans
2. **Historical Tracking**: Keep resolved findings for trend analysis
3. **Auto-Close**: Auto-resolve findings not present in latest scan
4. **Integration**: Link to CMDB CIs (microservices, clusters)
5. **Escalation**: Escalate unresolved critical findings after SLA breach

## Troubleshooting

### No Findings Uploaded

**Check**:
1. SARIF files generated in workflow
2. ServiceNow secrets configured
3. Table `u_security_scan_result` exists
4. GitHub user has write permissions

**Debug**:
```bash
# Test upload manually
curl -u "user:pass" \
  https://instance.service-now.com/api/now/table/u_security_scan_result \
  -H "Content-Type: application/json" \
  -d '{"u_scan_type": "Test", "u_severity": "LOW", ...}'
```

### Duplicate Findings

**Solution**: Implement finding hash:
```bash
FINDING_HASH=$(echo "${RULE_ID}:${FILE_PATH}:${LINE_NUMBER}" | md5sum | cut -d' ' -f1)
```

Check if hash exists before creating new record.

## Next Steps

1. **Create tables in ServiceNow** (via onboarding script or manual)
2. **Add aggregation script** to repository
3. **Add upload script** to repository
4. **Modify security workflow** to include upload step
5. **Create ServiceNow dashboard**
6. **Set up auto-assignment rules**
7. **Configure notifications**
8. **Train team on ServiceNow security views**

## References

- [SARIF Specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
- [ServiceNow Vulnerability Response](https://docs.servicenow.com/bundle/washingtondc-security-management/page/product/vulnerability-response/concept/c_VulnerabilityManagement.html)
- [GitHub Security Tab](https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts)

---

**Status**: 📋 Design Complete - Ready for Implementation
**Next**: Create tables and scripts
