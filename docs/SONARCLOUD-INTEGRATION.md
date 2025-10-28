# SonarCloud Integration with ServiceNow DevOps

> **Version:** 1.0.0
> **Last Updated:** 2025-10-28
> **Status:** ✅ Production Ready

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [What Gets Analyzed](#what-gets-analyzed)
- [What Gets Uploaded to ServiceNow](#what-gets-uploaded-to-servicenow)
- [Setup Instructions](#setup-instructions)
- [Workflow Integration](#workflow-integration)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

This integration provides **continuous code quality analysis** using SonarCloud and automatically uploads the results to ServiceNow DevOps for tracking and compliance.

### Key Features

✅ **Multi-Language Analysis**: Supports 5 languages (Go, Python, Java, JavaScript, C#)
✅ **Security Scanning**: Detects vulnerabilities, code smells, and bugs
✅ **Quality Gates**: Enforces code quality standards before deployment
✅ **ServiceNow Integration**: Automatically uploads results to ServiceNow DevOps
✅ **Pull Request Decoration**: Comments on PRs with quality metrics
✅ **Branch Analysis**: Tracks quality evolution over time

### Architecture Flow

```
┌─────────────────┐
│  GitHub Actions │
│   (Push/PR)     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                 SonarCloud Workflow                      │
│  1. Checkout code                                        │
│  2. Setup build environments (Java, Go, Node, Python, .NET)│
│  3. Build services for analysis                          │
│  4. Run SonarCloud scan                                  │
│  5. Upload results to ServiceNow                         │
└────────┬───────────────────────────┬────────────────────┘
         │                           │
         ▼                           ▼
┌─────────────────┐         ┌──────────────────────┐
│   SonarCloud    │         │   ServiceNow DevOps  │
│  - Quality Gate │         │  - Quality Metrics   │
│  - Security     │         │  - Compliance        │
│  - Maintainability│       │  - Change Velocity   │
└─────────────────┘         └──────────────────────┘
```

---

## What Gets Analyzed

### 1. Code Quality Metrics

SonarCloud analyzes the following aspects of your code:

#### **Reliability** (Bugs)
- Runtime errors and logic flaws
- Null pointer exceptions
- Resource leaks
- Incorrect API usage

#### **Security** (Vulnerabilities)
- SQL injection
- Cross-site scripting (XSS)
- Hardcoded credentials
- Insecure cryptography
- Command injection

#### **Maintainability** (Code Smells)
- Duplicated code blocks
- Complex functions (cognitive complexity)
- Long methods/classes
- Poor naming conventions
- Dead code

#### **Coverage** (Test Coverage)
- Line coverage percentage
- Branch coverage percentage
- Uncovered code paths

#### **Duplication**
- Duplicated code blocks
- Token-based duplication detection

### 2. Languages Analyzed

| Language | Services | Scanner |
|----------|----------|---------|
| **Go** | frontend, checkoutservice, productcatalogservice, shippingservice | Built-in |
| **Python** | emailservice, recommendationservice, loadgenerator, shoppingassistantservice | Built-in |
| **Java** | adservice, shoppingassistantservice (Gradle builds) | Built-in |
| **JavaScript/Node.js** | currencyservice, paymentservice | Built-in |
| **C#** | cartservice (.NET) | Built-in |

### 3. Exclusions

The following are **excluded from analysis**:

```properties
# Generated code
**/*.pb.go              # Protocol buffer generated Go files
**/pb/**                # Protocol buffer directories

# Dependencies
**/node_modules/**      # Node.js dependencies
**/vendor/**            # Go vendor directory
**/build/**             # Build artifacts
**/dist/**              # Distribution files
**/bin/**               # Binary files
**/obj/**               # .NET object files

# Build tools
**/gradlew              # Gradle wrapper
**/gradlew.bat
**/gradle/wrapper/**

# Minified files
**/*.min.js             # Minified JavaScript

# Tests
**/test/**
**/tests/**
**/*_test.go
**/*Test.java
**/*Tests.cs
```

---

## What Gets Uploaded to ServiceNow

The **ServiceNow DevOps Sonar** action (`servicenow-devops-sonar@v3.1.0`) uploads the following data to your ServiceNow instance:

### 1. Quality Metrics

| Metric | Description | ServiceNow Table |
|--------|-------------|------------------|
| **Quality Gate Status** | Pass/Fail status | `sn_devops_sonar_scan` |
| **Lines of Code** | Total LOC analyzed | `sn_devops_sonar_scan` |
| **Coverage** | Test coverage % | `sn_devops_sonar_scan` |
| **Bugs** | Count of bugs | `sn_devops_sonar_scan` |
| **Vulnerabilities** | Security issues count | `sn_devops_sonar_scan` |
| **Code Smells** | Maintainability issues | `sn_devops_sonar_scan` |
| **Technical Debt** | Estimated remediation time | `sn_devops_sonar_scan` |
| **Duplications** | Duplicated code % | `sn_devops_sonar_scan` |

### 2. Scan Metadata

| Field | Description |
|-------|-------------|
| **Project Key** | `freundcloud_microservices-demo` |
| **Organization** | `freundcloud` |
| **Commit SHA** | Git commit hash |
| **Branch** | Branch name (main, develop, etc.) |
| **Workflow Run ID** | GitHub Actions run ID |
| **Job Name** | `SonarCloud Analysis` |
| **Timestamp** | Scan execution time |

### 3. ServiceNow Tables

The action creates/updates records in the following ServiceNow tables:

#### **sn_devops_sonar_scan**
Primary table for storing SonarQube scan results.

**Key Fields:**
- `sys_id` - Unique identifier
- `tool` - Reference to orchestration tool (`sn_orchestration_tool_id`)
- `project_key` - SonarCloud project key
- `scan_status` - Quality gate status (passed/failed)
- `lines_of_code` - Total LOC
- `coverage` - Test coverage percentage
- `bugs` - Number of bugs
- `vulnerabilities` - Number of vulnerabilities
- `code_smells` - Number of code smells
- `technical_debt` - Estimated remediation time
- `duplications` - Duplication percentage
- `commit_sha` - Git commit hash
- `branch_name` - Git branch name
- `scan_time` - Timestamp of scan

#### **sn_devops_change**
Links scan results to change requests for compliance.

**Relationship:**
```
Change Request → Scan Results → Quality Gate Decision
```

### 4. API Endpoints Used

The action communicates with ServiceNow via REST API:

```
POST https://{instance}.service-now.com/api/sn_devops/v1/devops/tool/sonar
```

**Request Payload:**
```json
{
  "toolId": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "projectKey": "freundcloud_microservices-demo",
  "organization": "freundcloud",
  "sonarUrl": "https://sonarcloud.io",
  "commit": "e620ecf6...",
  "branch": "main",
  "workflowRunId": "18875241322",
  "jobName": "SonarCloud Analysis",
  "metrics": {
    "qualityGateStatus": "passed",
    "bugs": 0,
    "vulnerabilities": 5,
    "codeSmells": 123,
    "coverage": 67.5,
    "duplications": 2.3,
    "technicalDebt": "2d 4h"
  }
}
```

---

## Setup Instructions

### 1. SonarCloud Setup

#### A. Create SonarCloud Account
1. Go to [sonarcloud.io](https://sonarcloud.io)
2. Sign in with GitHub
3. Grant access to your repository

#### B. Import Project
1. Click **+** → **Analyze new project**
2. Select `Freundcloud/microservices-demo`
3. Choose **GitHub Actions** as the analysis method
4. Copy the **SONAR_TOKEN** (you'll need this for GitHub Secrets)

#### C. Configure Organization
- Organization Key: `freundcloud` (already set in `sonar-project.properties`)
- Project Key: `freundcloud_microservices-demo` (already set)

### 2. GitHub Secrets Setup

Add the following secrets to your GitHub repository:

| Secret Name | Value | Required | Purpose |
|-------------|-------|----------|---------|
| `SONAR_TOKEN` | SonarCloud authentication token | ✅ Yes | SonarCloud API access |
| `SN_DEVOPS_INTEGRATION_TOKEN` | ServiceNow DevOps integration token | ✅ Yes | ServiceNow API access (preferred) |
| `SN_DEVOPS_USER` | ServiceNow username | ⚠️ Fallback | ServiceNow API access (basic auth) |
| `SN_DEVOPS_PASSWORD` | ServiceNow password | ⚠️ Fallback | ServiceNow API access (basic auth) |
| `SN_INSTANCE_URL` | `https://calitiiltddemo3.service-now.com` | ✅ Yes | ServiceNow instance URL |
| `SN_ORCHESTRATION_TOOL_ID` | `f62c4e49c3fcf614e1bbf0cb050131ef` | ✅ Yes | GitHub tool ID in ServiceNow |

#### How to Get SONAR_TOKEN:
1. Go to [sonarcloud.io/account/security](https://sonarcloud.io/account/security)
2. Click **Generate Token**
3. Name: `GitHub Actions`
4. Type: **Global Analysis Token** or **Project Analysis Token**
5. Expiration: 90 days (or custom)
6. Copy the token immediately (it won't be shown again)

#### How to Get SN_DEVOPS_INTEGRATION_TOKEN:
1. Log into ServiceNow instance
2. Navigate to **DevOps → GitHub Tools**
3. Find your GitHub tool record (`f62c4e49c3fcf614e1bbf0cb050131ef`)
4. Generate API token from the tool configuration
5. Copy the token

#### Add Secrets to GitHub:
```bash
# Via GitHub UI
Repository → Settings → Secrets and variables → Actions → New repository secret

# Via GitHub CLI
gh secret set SONAR_TOKEN --body "<your-token>"
gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "<your-token>"
gh secret set SN_INSTANCE_URL --body "https://calitiiltddemo3.service-now.com"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "f62c4e49c3fcf614e1bbf0cb050131ef"
```

### 3. ServiceNow DevOps Setup

#### A. Create GitHub Tool (Already Done)
The orchestration tool is already configured:
- **Tool ID:** `f62c4e49c3fcf614e1bbf0cb050131ef`
- **Tool Name:** GitHub (configured in ServiceNow)

#### B. Enable SonarQube Integration
1. Navigate to **DevOps → Configuration**
2. Enable **SonarQube Integration**
3. Configure SonarCloud URL: `https://sonarcloud.io`

#### C. Configure Quality Gates
1. Navigate to **DevOps → Quality Gates**
2. Create quality gate rules:
   - Minimum coverage: 70%
   - Maximum bugs: 0 (critical)
   - Maximum vulnerabilities: 0 (critical)
   - Maximum code smells: 50

---

## Workflow Integration

### Current Implementation

The SonarCloud scan is integrated into the Master CI/CD Pipeline:

```yaml
# .github/workflows/MASTER-PIPELINE.yaml
jobs:
  sonarcloud-scan:
    name: "☁️ SonarCloud Quality"
    needs: pipeline-init
    if: ${{ !inputs.skip_security }}
    uses: ./.github/workflows/sonarcloud-scan.yaml
    secrets: inherit
```

### When It Runs

| Event | Branch | ServiceNow Upload |
|-------|--------|-------------------|
| Push | `main` | ✅ Yes |
| Push | `develop` | ✅ Yes |
| Pull Request | Any | ❌ No (preview only) |
| Manual Dispatch | Any | ✅ Yes (if not skipped) |

### Execution Order

```
1. Pipeline Initialization
2. Code Validation
3. Security Scanning (CodeQL, Trivy, etc.)
4. 🔹 SonarCloud Scan ← NEW
5. Infrastructure Changes Detection
6. Build Docker Images
7. Deploy
```

### Skipping SonarCloud Scan

To skip the scan during manual workflow dispatch:

```bash
gh workflow run MASTER-PIPELINE.yaml \
  --ref main \
  -f skip_security=true
```

---

## Configuration

### sonar-project.properties

The configuration file is located at the repository root:

```properties
# Organization and Project
sonar.organization=freundcloud
sonar.projectKey=freundcloud_microservices-demo
sonar.projectName=Microservices Demo (AWS EKS)
sonar.projectVersion=1.2.4

# Source directories
sonar.sources=src

# Exclusions (generated code, dependencies)
sonar.exclusions=\
  **/node_modules/**,\
  **/vendor/**,\
  **/*.pb.go,\
  **/pb/**,\
  **/build/**,\
  **/dist/**

# Language-specific settings
sonar.go.coverage.reportPaths=**/coverage.out
sonar.python.coverage.reportPaths=**/coverage.xml
sonar.javascript.lcov.reportPaths=**/coverage/lcov.info
sonar.java.source=21
sonar.cs.dotcover.reportsPaths=**/dotCover.html
```

### Customizing Analysis

To modify the analysis configuration:

1. **Edit sonar-project.properties**
   ```properties
   # Add custom exclusions
   sonar.exclusions=\
     existing_exclusions,\
     **/new_pattern/**

   # Change language versions
   sonar.java.source=17
   sonar.python.version=3.11
   ```

2. **Edit workflow arguments**
   ```yaml
   # .github/workflows/sonarcloud-scan.yaml
   - name: SonarCloud Scan
     uses: SonarSource/sonarqube-scan-action@v6
     with:
       args: >
         -Dsonar.organization=freundcloud
         -Dsonar.projectKey=freundcloud_microservices-demo
         -Dsonar.verbose=true  # Enable debug logging
   ```

---

## Testing

### 1. Manual Workflow Run

Test the integration manually:

```bash
# Trigger SonarCloud scan workflow directly
gh workflow run sonarcloud-scan.yaml

# Or via master pipeline
gh workflow run MASTER-PIPELINE.yaml \
  --ref main \
  -f environment=dev \
  -f skip_terraform=true
```

### 2. Verify SonarCloud Results

1. Go to [sonarcloud.io/dashboard?id=freundcloud_microservices-demo](https://sonarcloud.io/dashboard?id=freundcloud_microservices-demo)
2. Check the latest scan results
3. Verify quality gate status

### 3. Verify ServiceNow Upload

1. Log into ServiceNow: `https://calitiiltddemo3.service-now.com`
2. Navigate to **DevOps → SonarQube Scans**
3. Find the scan record by commit SHA or workflow run ID
4. Verify metrics are populated

### 4. Check GitHub Actions Logs

```bash
# View latest workflow run
gh run list --workflow=MASTER-PIPELINE.yaml --limit 1

# View logs for SonarCloud job
gh run view <run-id> --log | grep -A 20 "SonarCloud Analysis"
```

---

## Troubleshooting

### Issue 1: SonarCloud Authentication Failed

**Error:**
```
Error: Invalid authentication token
```

**Solution:**
1. Verify `SONAR_TOKEN` secret is set correctly
2. Check token hasn't expired (90-day expiration)
3. Regenerate token at [sonarcloud.io/account/security](https://sonarcloud.io/account/security)

---

### Issue 2: ServiceNow Upload Failed

**Error:**
```
Error: Failed to upload results to ServiceNow
HTTP 401 Unauthorized
```

**Solutions:**

**A. Token Authentication (Preferred)**
1. Verify `SN_DEVOPS_INTEGRATION_TOKEN` is set
2. Check token is valid in ServiceNow
3. Verify tool ID is correct: `f62c4e49c3fcf614e1bbf0cb050131ef`

**B. Basic Authentication (Fallback)**
1. Verify `SN_DEVOPS_USER` and `SN_DEVOPS_PASSWORD` are set
2. Check user has DevOps permissions in ServiceNow

**C. Check ServiceNow Logs**
1. Navigate to **System Logs → Application Logs**
2. Filter by `devops` or `sonar`
3. Look for API errors

---

### Issue 3: Build Failures

**Error:**
```
Error: Build failed for Java service
```

**Solution:**
1. Check Java version (required: 21)
2. Verify Gradle wrapper permissions:
   ```bash
   chmod +x src/*/gradlew
   ```
3. Check build logs for dependency issues

---

### Issue 4: Quality Gate Failed

**Error:**
```
Quality Gate Status: FAILED
Coverage below 70%
```

**Solution:**
1. Review coverage reports in SonarCloud
2. Add missing unit tests
3. Or adjust quality gate thresholds in SonarCloud

---

### Issue 5: Project Not Found

**Error:**
```
Project freundcloud_microservices-demo not found
```

**Solution:**
1. Verify project exists in SonarCloud
2. Check organization key: `freundcloud`
3. Ensure project key matches: `freundcloud_microservices-demo`

---

## Best Practices

### 1. Quality Gate Configuration

**Recommended Quality Gates:**

| Metric | Threshold | Severity |
|--------|-----------|----------|
| **Coverage** | ≥ 70% | 🔴 Critical |
| **Bugs** | 0 (new code) | 🔴 Critical |
| **Vulnerabilities** | 0 (new code) | 🔴 Critical |
| **Security Hotspots** | 0 (new code) | 🟡 Warning |
| **Code Smells** | ≤ 10 (new code) | 🟡 Warning |
| **Duplications** | ≤ 3% | 🟡 Warning |

### 2. Pull Request Analysis

Enable SonarCloud PR decoration:

1. Go to SonarCloud → Administration → Pull Requests
2. Enable **Decorate Pull Requests**
3. Configure GitHub integration

**Benefits:**
- Automatic PR comments with quality metrics
- Inline code annotations for issues
- Quality gate status checks

### 3. Branch Analysis

Configure long-lived branches:

1. SonarCloud → Administration → Branches
2. Set `main` and `develop` as long-lived branches
3. Other branches analyzed as short-lived (compared to main)

### 4. Security Hotspots

Review security hotspots regularly:

1. Navigate to **Security Hotspots** tab in SonarCloud
2. Mark as **Safe**, **Fixed**, or **To Review**
3. Provide justification for "Safe" classification

### 5. Technical Debt Management

Track technical debt:

1. Monitor **Technical Debt** metric
2. Plan remediation sprints
3. Set debt reduction goals

### 6. Coverage Goals

Improve test coverage:

1. Focus on critical paths first
2. Aim for 80%+ coverage on new code
3. Run coverage reports locally:
   ```bash
   # Go
   go test -coverprofile=coverage.out ./...

   # Python
   pytest --cov=src --cov-report=xml

   # Java
   ./gradlew test jacocoTestReport
   ```

### 7. Exclusion Management

Maintain clean exclusions:

1. **Only exclude** generated code and dependencies
2. **Never exclude** business logic to hide issues
3. Document exclusion reasons in `sonar-project.properties`

### 8. ServiceNow Integration

Use ServiceNow data for:

1. **Change Approvals**: Block deployments if quality gate fails
2. **Compliance Reports**: Track quality trends over time
3. **Risk Assessment**: Correlate code quality with incidents

---

## Additional Resources

### SonarCloud Documentation
- [SonarCloud Docs](https://docs.sonarcloud.io/)
- [GitHub Actions Integration](https://docs.sonarsource.com/sonarqube-cloud/advanced-setup/ci-based-analysis/github-actions-for-sonarcloud)
- [Quality Gates](https://docs.sonarcloud.io/improving/quality-gates/)

### ServiceNow DevOps
- [ServiceNow DevOps Sonar Action](https://github.com/marketplace/actions/servicenow-devops-sonar)
- [ServiceNow DevOps Documentation](https://docs.servicenow.com/en-US/bundle/utah-devops/page/product/enterprise-dev-ops/concept/github-actions-integration-with-devops.html)

### Repository Files
- Workflow: [`.github/workflows/sonarcloud-scan.yaml`](../.github/workflows/sonarcloud-scan.yaml)
- Configuration: [`sonar-project.properties`](../sonar-project.properties)
- Master Pipeline: [`.github/workflows/MASTER-PIPELINE.yaml`](../.github/workflows/MASTER-PIPELINE.yaml)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review SonarCloud logs at [sonarcloud.io](https://sonarcloud.io/dashboard?id=freundcloud_microservices-demo)
3. Check ServiceNow logs in the instance
4. Open GitHub issue in the repository

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-28
**Maintained By:** DevOps Team
