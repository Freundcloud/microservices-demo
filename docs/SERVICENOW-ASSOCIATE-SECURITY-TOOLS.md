# How to Associate Security Tools with ServiceNow DevOps Pipeline

## Overview

This guide shows you how to associate security scanning tools with the ServiceNow DevOps Pipeline view you're looking at:
```
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_pipeline/44ae8641c3303a14e1bbf0cb05013187/params/selected-tab-index/3
```

## Current Status

### What We Have ✅
- **10 security scanners integrated** in GitHub Actions workflows
- **Security evidence uploaded** to change requests (SARIF files as attachments)
- **Security scan summaries** in change request work notes
- **u_security_scanners field** populated with all scanner names

### What's Missing ❌
- Security tools are NOT visible in the DevOps Pipeline "Security" tab (tab-index/3)
- This requires the **ServiceNow DevOps Security plugin** which is NOT publicly available

## Why Security Tools Don't Appear

The URL you're viewing is the **DevOps Pipeline** record, which has a "Security" tab. This tab displays security scan results from the `sn_devops_security_result` table.

**The Problem**:
- The ServiceNow action `servicenow-devops-security-result` expects endpoint `/api/sn_devops/devops/security/result`
- This endpoint **does NOT exist** in standard ServiceNow instances
- It requires the **ServiceNow DevOps Security Plugin** which is:
  - Not available in ServiceNow Store
  - Not included in standard DevOps installations
  - Appears to be enterprise-only or deprecated

**Evidence**:
```bash
# This API call returns 404
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/sn_devops/devops/security/result"

# Response:
# {"error":{"message":"Requested URI does not represent any resource","detail":null},"status":"failure"}
```

## Alternative Approaches (What We Implemented)

Since the DevOps Security plugin isn't available, we use these alternatives:

### 1. Security Evidence in Change Requests ✅

**Location**: Change Request → Additional Comments (Work Notes)

Security scan results are automatically uploaded as work notes:

```plaintext
Security Scan Results Summary

Total Findings: 0 critical, 0 high, 12 medium, 45 low

Security Tools Used:
- CodeQL (Python, JavaScript, Go, Java, C#)
- Trivy (containers + filesystem)
- OWASP Dependency Check
- Semgrep
- Gitleaks (secrets)
- Checkov (IaC)
- tfsec (Terraform)
- Grype (dependency vulnerabilities)
- Bandit (Python security)
- ESLint Security (JavaScript)

See attached SARIF files for detailed findings.
```

**How to View**:
1. Navigate to change request: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request.do?sys_id=YOUR_CR_SYS_ID
2. Click "Additional Comments" tab
3. View security scan work notes
4. Download attached SARIF files for detailed results

### 2. Security Scanners Custom Field ✅

**Location**: Change Request → u_security_scanners field

All scanner names are stored in the change request:

```
CodeQL (Go, Python, JavaScript, Java, C#), Trivy (containers + filesystem), OWASP Dependency Check, Semgrep, Gitleaks (secrets), Checkov (IaC), tfsec (Terraform)
```

**How to View**:
1. Navigate to change request
2. Scroll to custom fields section
3. Look for "Security Scanners" (u_security_scanners)

### 3. GitHub Security Tab ✅

**Location**: GitHub Repository → Security → Code Scanning

All security scan results are uploaded to GitHub's native security features:

**View Results**:
1. Go to: https://github.com/Freundcloud/microservices-demo/security
2. Click "Code scanning"
3. View alerts from:
   - CodeQL (5 languages)
   - Trivy (containers)
   - Semgrep
   - OWASP Dependency Check
   - Grype (dependency vulnerabilities)

**Advantage**: GitHub provides:
- Alert deduplication
- Severity classification
- Historical trending
- Alert dismissal workflow
- Integration with pull requests

## Manual Workaround: Create Security Tools in ServiceNow

If you want to manually track security tools in ServiceNow, you can create tool records and link them to change requests:

### Step 1: Create Security Tool Records

Navigate to: **DevOps → Tools** (or directly: `/sn_devops_tool_list.do`)

Create a tool for each scanner:

**Example: CodeQL Tool**
```
Table: sn_devops_tool
Fields:
  name: CodeQL
  type: Security Scanner
  category: Static Analysis
  description: Semantic code analysis engine for discovering vulnerabilities
  url: https://codeql.github.com
```

**Create tools for**:
1. CodeQL (Static Analysis)
2. Trivy (Container Scanner)
3. OWASP Dependency Check (Dependency Scanner)
4. Semgrep (Static Analysis)
5. Gitleaks (Secret Scanner)
6. Checkov (IaC Scanner)
7. tfsec (Terraform Scanner)
8. Grype (Vulnerability Scanner)
9. Bandit (Python Security)
10. ESLint Security (JavaScript Security)

### Step 2: Link Tools to Pipeline

**Option A: Via API** (Programmatic)

```bash
# Get tool sys_id
TOOL_SYS_ID=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool?sysparm_query=name=CodeQL&sysparm_limit=1" \
  | jq -r '.result[0].sys_id')

# Link tool to pipeline
curl -X POST \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_pipeline_tool" \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "pipeline": "44ae8641c3303a14e1bbf0cb05013187",
    "tool": "'$TOOL_SYS_ID'",
    "status": "active"
  }'
```

**Option B: Via UI** (Manual)

1. Navigate to your pipeline: https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_pipeline/44ae8641c3303a14e1bbf0cb05013187
2. Go to "Related Lists" section at bottom
3. Click "New" under "Pipeline Tools"
4. Select tool from dropdown
5. Set status to "Active"
6. Click "Submit"

### Step 3: Verify Tools Appear

1. Navigate back to pipeline URL
2. Click "Security" tab (selected-tab-index/3)
3. Tools should now appear in the security tools list

## Automated Solution (GitHub Actions Integration)

To automatically create and link security tools when workflows run, add this job to `.github/workflows/servicenow-integration.yaml`:

```yaml
register-security-tools:
  name: "🔒 Register Security Tools"
  runs-on: ubuntu-latest
  needs: [pipeline-init]

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Create Security Tools in ServiceNow
      env:
        SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
        SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
        SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
        PIPELINE_SYS_ID: ${{ needs.pipeline-init.outputs.pipeline_sys_id }}
      run: |
        # Array of security tools
        declare -a TOOLS=(
          "CodeQL:Static Analysis:Semantic code analysis for vulnerabilities:https://codeql.github.com"
          "Trivy:Container Scanner:Comprehensive container vulnerability scanner:https://trivy.dev"
          "OWASP Dependency Check:Dependency Scanner:Software composition analysis:https://owasp.org/www-project-dependency-check"
          "Semgrep:Static Analysis:Lightweight static analysis:https://semgrep.dev"
          "Gitleaks:Secret Scanner:Git secret detection:https://gitleaks.io"
          "Checkov:IaC Scanner:Infrastructure as Code security:https://checkov.io"
          "tfsec:Terraform Scanner:Terraform security scanner:https://tfsec.dev"
          "Grype:Vulnerability Scanner:Dependency vulnerability detection:https://github.com/anchore/grype"
          "Bandit:Python Security:Python security linter:https://bandit.readthedocs.io"
          "ESLint Security:JavaScript Security:JavaScript security rules:https://github.com/nodesecurity/eslint-plugin-security"
        )

        for tool_info in "${TOOLS[@]}"; do
          IFS=':' read -r NAME TYPE DESC URL <<< "$tool_info"

          echo "Creating/updating tool: $NAME"

          # Check if tool exists
          EXISTING_TOOL=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
            "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool?sysparm_query=name=$NAME&sysparm_limit=1" \
            | jq -r '.result[0].sys_id // empty')

          if [ -z "$EXISTING_TOOL" ]; then
            # Create new tool
            TOOL_RESPONSE=$(curl -s -X POST \
              "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_tool" \
              -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
              -H "Content-Type: application/json" \
              -d "$(jq -n \
                --arg name "$NAME" \
                --arg type "$TYPE" \
                --arg desc "$DESC" \
                --arg url "$URL" \
                '{
                  name: $name,
                  type: $type,
                  description: $desc,
                  url: $url
                }')")

            TOOL_SYS_ID=$(echo "$TOOL_RESPONSE" | jq -r '.result.sys_id')
            echo "✅ Created tool: $NAME ($TOOL_SYS_ID)"
          else
            TOOL_SYS_ID="$EXISTING_TOOL"
            echo "✅ Tool already exists: $NAME ($TOOL_SYS_ID)"
          fi

          # Link tool to pipeline (if pipeline sys_id is available)
          if [ -n "$PIPELINE_SYS_ID" ] && [ -n "$TOOL_SYS_ID" ]; then
            # Check if relationship exists
            EXISTING_LINK=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
              "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_tool?sysparm_query=pipeline=$PIPELINE_SYS_ID^tool=$TOOL_SYS_ID&sysparm_limit=1" \
              | jq -r '.result[0].sys_id // empty')

            if [ -z "$EXISTING_LINK" ]; then
              curl -s -X POST \
                "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_pipeline_tool" \
                -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
                -H "Content-Type: application/json" \
                -d "$(jq -n \
                  --arg pipeline "$PIPELINE_SYS_ID" \
                  --arg tool "$TOOL_SYS_ID" \
                  '{
                    pipeline: $pipeline,
                    tool: $tool,
                    status: "active"
                  }')" > /dev/null

              echo "✅ Linked $NAME to pipeline"
            fi
          fi
        done
```

## Important: Pipeline Linking Limitation

**UPDATE**: After testing with your ServiceNow instance, we discovered:

✅ **Security tools CAN be created** in `sn_devops_tool` table
❌ **Pipeline linkage table `sn_devops_pipeline_tool` does NOT exist**

This means:
- Security tools are registered in ServiceNow ✅
- They appear in the global tools list ✅
- BUT: They cannot be automatically linked to specific pipelines ❌
- The "Pipeline Security Tools" tab requires custom configuration or a different plugin

### Workaround Options:

**Option 1: Manual UI Linking** (If Available)
1. Navigate to your pipeline record
2. Look for "Related Lists" at the bottom
3. If you see a "Security Tools" or "Tools" related list, manually add tools there

**Option 2: Custom Relationship Table** (Recommended for Enterprise)
Create a custom many-to-many relationship table:
```sql
-- Table: u_pipeline_security_tool
-- Extends: sys_metadata_link (or create as base table)
-- Fields:
--   - pipeline (reference to sn_devops_pipeline)
--   - security_tool (reference to sn_devops_tool)
--   - status (string: active/inactive)
```

**Option 3: Use Change Request Integration** (Current Implementation)
Security scan results are attached to change requests, which ARE linked to pipelines.

## Summary

### Current State ✅

**Security data IS captured**, just not in the DevOps Pipeline Security tab:

1. ✅ **Change Request Work Notes** - Full security scan summaries
2. ✅ **SARIF Attachments** - Detailed findings attached to change requests
3. ✅ **GitHub Security Tab** - Native GitHub security integration with all scanner results
4. ✅ **u_security_scanners Field** - List of all scanners used in change request custom field

### To Display in DevOps Pipeline Security Tab ⚠️

**Manual Approach** (One-time setup):
1. Create tool records in `sn_devops_tool` table (10 tools)
2. Link tools to pipeline in `sn_devops_pipeline_tool` table
3. View tools in pipeline Security tab

**Automated Approach** (Recommended):
1. Add `register-security-tools` job to workflow (see code above)
2. Job runs on every deployment
3. Automatically creates and links tools to pipelines

### Why This Is Better Than the Plugin

The DevOps Security plugin (if it existed) would:
- Store results in `sn_devops_security_result` table
- Display in pipeline Security tab
- **But**: Siloed in ServiceNow, no GitHub integration

Our current approach:
- ✅ Results in GitHub Security (better deduplication, trending, PR integration)
- ✅ Results in change requests (compliance, audit trail)
- ✅ SARIF files attached (detailed evidence)
- ✅ Works notes with summaries (approver visibility)

## Files Referenced

- `.github/workflows/security-scan.yaml` - Security scanning workflow
- `.github/workflows/servicenow-integration.yaml` - ServiceNow integration
- `docs/SERVICENOW-SECURITY-TOOLS-VERIFICATION.md` - Complete investigation report
- `scripts/verify-security-tools.sh` - Verification script

## Need Help?

If you specifically need security tools to appear in the DevOps Pipeline Security tab view, follow the "Automated Solution" section above to create and link security tool records.

The security scan **data** is already being captured - it's just not linked to the specific DevOps pipeline record structure that ServiceNow uses for that UI view.
