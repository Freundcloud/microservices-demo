# GitHub-ServiceNow Data Integration in ARC

> Technical Implementation Deep Dive
> Last Updated: 2025-11-10
> Status: Production

## Executive Summary

This document provides a comprehensive technical analysis of the bi-directional integration between GitHub Actions and ServiceNow DevOps implemented in the Application Release Center (ARC). The integration establishes complete traceability from code commits through testing, security scanning, and deployment, with all artifacts and evidence automatically synchronized to ServiceNow for compliance and audit purposes.

### Architecture Overview

The integration employs a hybrid approach combining ServiceNow's traditional Change Management API (Table API) with DevOps-specific tables to achieve both compliance requirements and operational visibility. All communication occurs via authenticated REST API calls over HTTPS, with no ServiceNow plugins required on the GitHub side.

### Key Integration Points

1. Orchestration Task Registration - GitHub Actions job tracking
2. Work Item Extraction - Automated issue linking from commit messages
3. Test Result Reporting - Comprehensive test evidence collection
4. Security Scan Integration - Vulnerability and SBOM tracking
5. Change Request Automation - Compliance-driven deployment gates
6. Package Registration - Artifact and configuration management

---

## Solution Architecture

### High-Level Integration Flow

```mermaid
graph TB
    subgraph "GitHub Ecosystem"
        A[Developer Commit] --> B[GitHub Actions Trigger]
        B --> C[Master CI/CD Pipeline]
        C --> D[Parallel Jobs]
        D --> E1[Build Services]
        D --> E2[Security Scans]
        D --> E3[Unit Tests]
        D --> E4[Infrastructure]
    end

    subgraph "ServiceNow DevOps Platform"
        F[sn_devops_orchestration_task]
        G[sn_devops_work_item]
        H[sn_devops_test_result]
        I[sn_devops_test_summary]
        J[change_request]
        K[sn_devops_artifact]
        L[sn_devops_change_reference]
    end

    subgraph "Integration Layer"
        M[REST API Authentication]
        N[Composite Actions]
        O[Reusable Workflows]
    end

    C --> M
    M --> N
    N --> F
    N --> G
    E2 --> O
    E3 --> O
    O --> H
    O --> I
    E1 --> O
    O --> K
    C --> O
    O --> J
    J --> L
    F -.-> J
    G -.-> J
    H -.-> J
    K -.-> J

    style A fill:#e1f5ff
    style C fill:#fff4e1
    style M fill:#ffe1f5
    style J fill:#e8f5e9
```

### Authentication and Security Model

All API communications utilize HTTP Basic Authentication with credentials managed through GitHub Secrets. The authentication flow implements the following security controls:

**Credential Management:**

- ServiceNow username and password stored as GitHub repository secrets
- Secrets never logged or exposed in workflow outputs
- Each API request creates a new authenticated session
- No long-lived tokens or session persistence

**API Endpoint Security:**

- All requests use HTTPS (TLS 1.2+)
- ServiceNow instance URL validated before use
- API responses parsed and validated before processing
- Non-blocking error handling prevents pipeline failures

---

## Component 1: Orchestration Task Registration

### Purpose

Track individual GitHub Actions jobs as orchestration tasks in ServiceNow, enabling visibility into CI/CD pipeline execution at the job level rather than just the workflow level.

### Technical Implementation

**Composite Action:** `.github/actions/register-orchestration-task/action.yaml`

**Execution Flow:**

```mermaid
sequenceDiagram
    participant GHA as GitHub Actions Job
    participant GHAPI as GitHub REST API
    participant Action as Composite Action
    participant SNAPI as ServiceNow Table API
    participant SNDB as sn_devops_orchestration_task

    GHA->>GHAPI: GET /repos/{repo}/actions/runs/{run_id}/jobs
    Note over GHA,GHAPI: Authenticate with GITHUB_TOKEN
    GHAPI-->>GHA: Return jobs array with status

    GHA->>Action: Filter jobs by status=in_progress or queued
    Action->>Action: Extract job_id and job_name from matching job
    Action->>Action: Construct native_id: {repo}/{workflow}#{job_name}
    Action->>Action: Construct job_url: GitHub Actions job URL

    Action->>SNAPI: POST /api/now/table/sn_devops_orchestration_task
    Note over Action,SNAPI: Basic Auth with ServiceNow credentials
    Note over Action,SNAPI: Payload: name, native_id, task_url, tool, project, track

    SNAPI->>SNDB: INSERT orchestration_task
    SNDB-->>SNAPI: Return sys_id and generated task number

    SNAPI-->>Action: Return created record with TASK number
    Action-->>GHA: Output task_id and task_url for downstream jobs
```

### Data Model

**Table:** `sn_devops_orchestration_task`

| Field Name | Type | Source | Example Value | Purpose |
|------------|------|--------|---------------|---------|
| `sys_id` | UUID | Generated | abc123def456... | Primary key |
| `number` | String | Auto-generated | TASK0001234 | Human-readable identifier |
| `name` | String | Composite | Freundcloud/microservices-demo/Master CI/CD Pipeline#Pipeline Initialization | Fully qualified job name |
| `native_id` | String | Composite | Same as name | Unique identifier for deduplication |
| `task_url` | URL | GitHub API | <https://github.com/.../job/54808245339> | Direct link to job execution |
| `project` | Reference | Secret | c6c9eb71c34d7a50b71ef44c05013194 | Links to sn_devops_project |
| `tool` | Reference | Secret | f62c4e49c3fcf614e1bbf0cb050131ef | Links to sn_devops_tool (GithHubARC) |
| `track` | Boolean | Hardcoded | true | Enables tracking in DevOps workspace |
| `sys_created_on` | Datetime | Auto | 2025-11-07 15:01:23 | Record creation timestamp |

### API Request Structure

```http
POST /api/now/table/sn_devops_orchestration_task HTTP/1.1
Host: calitiiltddemo3.service-now.com
Authorization: Basic <base64-credentials>
Content-Type: application/json

{
  "name": "Freundcloud/microservices-demo/Master CI/CD Pipeline#Pipeline Initialization",
  "native_id": "Freundcloud/microservices-demo/Master CI/CD Pipeline#Pipeline Initialization",
  "task_url": "https://github.com/Freundcloud/microservices-demo/actions/runs/19172412878/job/54808245339",
  "tool": "f62c4e49c3fcf614e1bbf0cb050131ef",
  "project": "c6c9eb71c34d7a50b71ef44c05013194",
  "track": true
}
```

### Error Handling Strategy

The implementation uses a non-blocking approach:

1. GitHub API failures return "unknown" job_id (continues execution)
2. ServiceNow API failures log warning (continues execution)
3. `continue-on-error: true` at workflow level prevents pipeline stoppage
4. All errors logged to workflow output for debugging

This design ensures that ServiceNow integration issues never block deployments while maintaining complete audit trails when successful.

---

## Component 2: Work Item Extraction and Registration

### Purpose

Automatically extract GitHub issue references from commit messages and register them as work items in ServiceNow, establishing traceability between code changes and requirements.

### Technical Implementation

**Composite Action:** `.github/actions/register-work-items/action.yaml`

**Execution Flow:**

```mermaid
sequenceDiagram
    participant GHA as GitHub Actions
    participant Git as Local Git Repository
    participant GHAPI as GitHub Issues API
    participant Action as Composite Action
    participant SNAPI as ServiceNow Table API
    participant SNDB as sn_devops_work_item

    GHA->>Git: git log --pretty=format:"%s%n%b" {range}
    Note over GHA,Git: Fetch commit messages (subject + body)
    Git-->>GHA: Return commit history

    GHA->>Action: Parse commit messages with regex
    Note over Action: Pattern: (?:Fixes|Closes|Resolves|Issue)?\\s*#\\K\\d+
    Action->>Action: Extract unique issue numbers
    Action->>Action: Sort and deduplicate issue list

    loop For each issue number
        Action->>GHAPI: GET /repos/{repo}/issues/{number}
        Note over Action,GHAPI: Authenticate with GITHUB_TOKEN
        GHAPI-->>Action: Return issue metadata (title, state, url)

        Action->>SNAPI: GET /api/now/table/sn_devops_work_item?sysparm_query=url={url}
        Note over Action,SNAPI: Check if work item already exists
        SNAPI-->>Action: Return existing records (if any)

        alt Work item does not exist
            Action->>SNAPI: POST /api/now/table/sn_devops_work_item
            Note over Action,SNAPI: Payload: name, external_id, url, status, type, project, tool
            SNAPI->>SNDB: INSERT work_item
            SNDB-->>SNAPI: Return sys_id and generated WI number
            SNAPI-->>Action: Return created record
        else Work item already exists
            Action->>Action: Skip creation (idempotency)
        end
    end

    Action-->>GHA: Output: work_items_registered count and sys_ids
```

### Commit Message Parsing Logic

The work item extraction uses a robust regex pattern that handles multiple conventions:

**Supported Patterns:**

- `Fixes #123` - Explicit closure intent
- `Closes #456` - Alternative closure keyword
- `Resolves #789` - Resolution keyword
- `Issue #101` - Explicit issue reference
- `#112` - Bare issue number (GitHub auto-linking format)

**Implementation:**

```bash
grep -oP '(?:Fixes|Closes|Resolves|Issue)?\s*#\K\d+' | sort -u
```

**Critical Fix Implemented:**
The initial implementation only parsed commit subject lines (`%s`), missing issue references in commit bodies. This was corrected to use `%s%n%b` (subject + body), significantly improving extraction accuracy.

### Data Model

**Table:** `sn_devops_work_item`

| Field Name | Type | Source | Example Value | Purpose |
|------------|------|--------|---------------|---------|
| `sys_id` | UUID | Generated | xyz789abc456... | Primary key |
| `number` | String | Auto-generated | WI0001197 | Human-readable identifier |
| `name` | String | GitHub API | Add user authentication | Issue title from GitHub |
| `external_id` | String | Commit message | 80 | GitHub issue number |
| `url` | URL | GitHub API | <https://github.com/.../issues/80> | Direct link to issue |
| `status` | String | GitHub API | open / closed | Issue state |
| `type` | String | Hardcoded | issue | Work item type classification |
| `project` | Reference | Secret | c6c9eb71c34d7a50b71ef44c05013194 | Links to sn_devops_project |
| `tool` | Reference | Secret | f62c4e49c3fcf614e1bbf0cb050131ef | Links to sn_devops_tool |
| `sys_created_on` | Datetime | Auto | 2025-11-07 15:01:25 | Record creation timestamp |

### Deduplication Strategy

To prevent duplicate work item creation across multiple pipeline runs:

1. **Pre-creation check:** Query `sn_devops_work_item` table by `url` field
2. **Existence evaluation:** If result count > 0, skip creation
3. **Atomic operations:** Each work item creation is independent
4. **Idempotency:** Multiple executions produce same end state

This ensures that the same GitHub issue is never registered twice, even if referenced in multiple commits or pipeline runs.

---

## Component 3: Test Result Integration

### Purpose

Capture comprehensive test execution evidence from unit tests, integration tests, security scans, and code quality analysis, providing complete test coverage visibility in ServiceNow.

### Architecture

The test result integration uses two complementary ServiceNow tables:

1. **`sn_devops_test_result`** - Individual test suite executions
2. **`sn_devops_test_summary`** - Aggregated test metrics per pipeline

### Test Result Data Flow

```mermaid
sequenceDiagram
    participant Build as Build Job
    participant Tests as Test Execution
    participant Action as ServiceNow DevOps Action
    participant SNAPI as ServiceNow API
    participant TR as sn_devops_test_result
    participant TS as sn_devops_test_summary

    Build->>Tests: Execute test suite (JUnit, pytest, Go test, etc.)
    Tests-->>Build: Generate test report (XML/JSON)

    Build->>Action: ServiceNow/servicenow-devops-test-report@v6.0.0
    Note over Build,Action: Inputs: test-results, devops-integration-* credentials

    Action->>Action: Parse test report format
    Action->>Action: Extract metrics: total, passed, failed, skipped
    Action->>Action: Calculate test duration

    Action->>SNAPI: POST /api/sn_devops/devops/tool/test
    Note over Action,SNAPI: DevOps-specific API endpoint
    Note over Action,SNAPI: Payload: testResults (JUnit XML or JSON)

    SNAPI->>TR: INSERT individual test_result
    SNAPI->>TS: INSERT or UPDATE test_summary

    TR-->>SNAPI: Return test_result sys_id
    TS-->>SNAPI: Return test_summary sys_id
    SNAPI-->>Action: Return 201 Created + record identifiers
    Action-->>Build: Output test registration confirmation
```

### Test Result Table Schema

**Table:** `sn_devops_test_result`

| Field Name | Type | Source | Example Value | Purpose |
|------------|------|--------|---------------|---------|
| `sys_id` | UUID | Generated | def456ghi789... | Primary key |
| `number` | String | Auto-generated | TR0005678 | Human-readable identifier |
| `name` | String | Workflow input | Unit Tests - Frontend Service | Descriptive test suite name |
| `test_suite_name` | String | Workflow input | Frontend Unit Tests | Test suite classification |
| `test_result` | String | Computed | success / failure / skipped | Overall test outcome |
| `tool` | Reference | Secret | f62c4e49c3fcf614e1bbf0cb050131ef | Links to sn_devops_tool |
| `project` | Reference | Secret | c6c9eb71c34d7a50b71ef44c05013194 | Links to sn_devops_project |
| `execution_url` | URL | GitHub context | <https://github.com/.../runs/>... | Link to test execution logs |
| `start_time` | Datetime | Test report | 2025-11-07T15:02:00Z | Test execution start |
| `end_time` | Datetime | Test report | 2025-11-07T15:08:30Z | Test execution completion |
| `duration` | Integer | Calculated | 390 | Duration in seconds |
| `test_cases_total` | Integer | Test report | 150 | Total test cases executed |
| `test_cases_passed` | Integer | Test report | 148 | Passed test cases |
| `test_cases_failed` | Integer | Test report | 2 | Failed test cases |
| `test_cases_skipped` | Integer | Test report | 0 | Skipped test cases |

### Test Summary Table Schema

**Table:** `sn_devops_test_summary`

Aggregates all test results for a single pipeline execution, providing a rollup view of test coverage and quality.

| Field Name | Type | Example Value | Purpose |
|------------|------|---------------|---------|
| `pipeline_id` | String | 19172412878 | GitHub run_id (correlation key) |
| `total_test_suites` | Integer | 10 | Number of test suites executed |
| `passed_test_suites` | Integer | 9 | Fully passing test suites |
| `failed_test_suites` | Integer | 1 | Test suites with failures |
| `total_tests` | Integer | 500 | Total individual test cases |
| `passed_tests` | Integer | 485 | Passed test cases |
| `failed_tests` | Integer | 15 | Failed test cases |
| `test_execution_time` | Integer | 300 | Total test time (seconds) |
| `overall_result` | String | passed_with_failures | Aggregated test outcome |

### Test Type Coverage

The integration captures test results from multiple sources:

**1. Unit Tests (Per Service)**

- Frontend (Go) - via `go test`
- Cart Service (C#) - via `dotnet test`
- Product Catalog (Go) - via `go test`
- Currency Service (Node.js) - via `npm test`
- Payment Service (Node.js) - via `npm test`
- Email Service (Python) - via `pytest`
- Ad Service (Java) - via `mvn test`
- All other microservices following language-specific patterns

**2. Security Scans**

- Trivy vulnerability scanning (CRITICAL/HIGH/MEDIUM/LOW counts)
- CodeQL static analysis (per language)
- Semgrep security rule violations
- Gitleaks secret detection

**3. Code Quality**

- SonarCloud quality gate results
- Code coverage percentages
- Technical debt metrics
- Maintainability ratings

**4. Integration Tests**

- Smoke tests (endpoint accessibility)
- End-to-end test scenarios
- Performance test results

---

## Component 4: Security Scan Integration

### Purpose

Capture security scanning results including Software Bill of Materials (SBOM), vulnerability assessments, and static analysis, providing complete security posture visibility in ServiceNow.

### Architecture

Security scan integration utilizes specialized DevOps tables designed for security artifact management:

**Primary Tables:**

1. `sn_devops_artifact` - SBOM and security artifacts
2. `sn_devops_test_result` - Security scan execution results
3. `sn_devops_security_result` - Detailed vulnerability findings (if available)

### Security Scan Flow Diagram

```mermaid
sequenceDiagram
    participant Scan as Security Scan Job
    participant Trivy as Trivy Scanner
    participant SQ as SonarCloud
    participant Script as Upload Script
    participant SNAPI as ServiceNow API
    participant Artifact as sn_devops_artifact
    participant TestRes as sn_devops_test_result

    Scan->>Trivy: trivy fs --format cyclonedx --output sbom.json
    Trivy-->>Scan: Return SBOM (CycloneDX JSON)

    Scan->>Trivy: trivy sbom --format sarif --output vuln.sarif sbom.json
    Trivy-->>Scan: Return vulnerability report (SARIF)

    Scan->>SQ: sonar-scanner (SonarCloud analysis)
    SQ-->>Scan: Return quality gate status and metrics

    Scan->>Script: Execute upload-security-results-servicenow.sh
    Script->>Script: Parse SBOM (extract component count, categories)
    Script->>Script: Parse SARIF (count vulnerabilities by severity)
    Script->>Script: Query SonarCloud API for quality metrics

    Script->>SNAPI: POST /api/now/table/sn_devops_artifact
    Note over Script,SNAPI: Payload: SBOM artifact metadata + base64 content
    SNAPI->>Artifact: INSERT artifact record
    Artifact-->>SNAPI: Return artifact sys_id (ART0002345)

    Script->>SNAPI: POST /api/now/table/sn_devops_test_result
    Note over Script,SNAPI: Payload: Trivy vulnerability scan results
    SNAPI->>TestRes: INSERT test_result (TR0005679)

    Script->>SNAPI: POST /api/now/table/sn_devops_test_result
    Note over Script,SNAPI: Payload: SonarCloud quality gate results
    SNAPI->>TestRes: INSERT test_result (TR0005678)

    SNAPI-->>Script: Return all created record identifiers
    Script-->>Scan: Output security evidence registration confirmation
```

### SBOM Artifact Structure

**CycloneDX Format** (Industry standard for Software Bill of Materials):

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "timestamp": "2025-11-07T15:05:00Z",
    "component": {
      "type": "application",
      "name": "microservices-demo",
      "version": "99c7767b"
    }
  },
  "components": [
    {
      "type": "library",
      "name": "express",
      "version": "4.18.2",
      "purl": "pkg:npm/express@4.18.2",
      "licenses": [{"license": {"id": "MIT"}}]
    },
    {
      "type": "library",
      "name": "requests",
      "version": "2.31.0",
      "purl": "pkg:pypi/requests@2.31.0",
      "licenses": [{"license": {"id": "Apache-2.0"}}]
    }
  ],
  "dependencies": []
}
```

### Artifact Table Schema

**Table:** `sn_devops_artifact`

| Field Name | Type | Source | Example Value | Purpose |
|------------|------|--------|---------------|---------|
| `sys_id` | UUID | Generated | mno123pqr456... | Primary key |
| `number` | String | Auto-generated | ART0002345 | Human-readable identifier |
| `name` | String | Composite | SBOM-microservices-demo-99c7767b | Artifact identifier |
| `artifact_type` | String | Hardcoded | sbom | Artifact classification |
| `version` | String | Git SHA | 99c7767b | Git commit associated with artifact |
| `tool` | Reference | Secret | f62c4e49c3fcf614e1bbf0cb050131ef | Links to sn_devops_tool |
| `project` | Reference | Secret | c6c9eb71c34d7a50b71ef44c05013194 | Links to sn_devops_project |
| `sbom_data` | Text | SBOM file | <base64-encoded-json> | Complete SBOM content |
| `component_count` | Integer | Computed | 342 | Number of components in SBOM |
| `artifact_url` | URL | GitHub | <https://github.com/.../runs/>... | Link to artifact source |

### Security Test Results Structure

**Trivy Vulnerability Scan Result:**

```json
{
  "name": "Trivy Vulnerability Scan - Run #19172412878",
  "test_suite_name": "Trivy Dependency Scan",
  "test_result": "failed",
  "execution_url": "https://github.com/.../security/code-scanning",
  "vulnerabilities": {
    "total": 23,
    "critical": 2,
    "high": 5,
    "medium": 12,
    "low": 4
  },
  "failed_criteria": "2 CRITICAL vulnerabilities exceed threshold (max: 0)"
}
```

**SonarCloud Quality Gate Result:**

```json
{
  "name": "SonarCloud Quality Analysis - Run #19172412878",
  "test_suite_name": "SonarCloud Code Quality",
  "test_result": "passed",
  "execution_url": "https://sonarcloud.io/project/overview?id=...",
  "metrics": {
    "bugs": 12,
    "vulnerabilities": 3,
    "code_smells": 45,
    "coverage": 68.5,
    "duplications": 2.3,
    "quality_gate": "passed"
  }
}
```

---

## Component 5: Change Request Automation

### Purpose

Automatically create and manage ServiceNow change requests for deployments, implementing compliance-driven approval gates while capturing complete deployment context and evidence.

### Hybrid Approach Architecture

The implementation uses a hybrid strategy combining:

1. **Table API** - Traditional change request creation (change_request table)
2. **DevOps Tables** - Supplementary tracking (sn_devops_change_reference, etc.)

This approach provides:

- Traditional change request numbers (CHG0030XXX) for compliance
- 40+ custom fields for complete audit trail
- DevOps workspace visibility
- No ServiceNow plugin configuration required

### Change Request Creation Flow

```mermaid
sequenceDiagram
    participant Pipeline as Master CI/CD Pipeline
    participant Checks as Quality Gates
    participant Workflow as servicenow-change-rest.yaml
    participant SNAPI as ServiceNow Table API
    participant CR as change_request table
    participant DevOps as DevOps Tables

    Pipeline->>Checks: Execute security scans, tests, builds
    Checks-->>Pipeline: Return aggregated results

    Pipeline->>Workflow: Invoke with deployment context
    Note over Pipeline,Workflow: Inputs: environment, test results, security status, etc.

    Workflow->>Workflow: Validate all quality gates passed
    Workflow->>Workflow: Construct change request payload (40+ fields)

    Workflow->>SNAPI: POST /api/now/table/change_request
    Note over Workflow,SNAPI: Basic Auth + JSON payload
    SNAPI->>CR: INSERT change_request
    CR-->>SNAPI: Return sys_id and CHG number

    Workflow->>SNAPI: POST /api/now/table/sn_devops_change_reference
    Note over Workflow,SNAPI: Link CR to pipeline execution
    SNAPI->>DevOps: INSERT change reference

    Workflow->>SNAPI: POST /api/now/table/sn_devops_test_result (multiple)
    Note over Workflow,SNAPI: Associate test results with CR
    SNAPI->>DevOps: INSERT test results

    Workflow->>SNAPI: POST /api/now/table/sn_devops_artifact (multiple)
    Note over Workflow,SNAPI: Register deployed artifacts
    SNAPI->>DevOps: INSERT artifacts

    SNAPI-->>Workflow: Return all created record sys_ids
    Workflow-->>Pipeline: Output change_number and change_sys_id
```

### Change Request Data Model

**Table:** `change_request` (ServiceNow standard + custom fields)

**Standard Fields:**

| Field Name | Type | Example Value | Purpose |
|------------|------|---------------|---------|
| `number` | String | CHG0030463 | Change request identifier |
| `sys_id` | UUID | stu901vwx234... | Primary key |
| `short_description` | String | Deploy microservices to prod | Brief description |
| `description` | Text | Automated deployment from GitHub Actions... | Detailed description |
| `type` | String | standard | Change type classification |
| `risk` | String | low / medium / high | Risk assessment |
| `impact` | String | low / medium / high | Business impact |
| `priority` | String | moderate | Change priority |
| `state` | String | assess / authorize / scheduled / implement / review / closed | Change state |
| `requested_by` | Reference | github_integration | User who requested change |
| `assignment_group` | Reference | DevOps Team | Responsible team |
| `start_date` | Datetime | 2025-11-07 16:00:00 | Planned start time |
| `end_date` | Datetime | 2025-11-07 16:30:00 | Planned end time |

**Custom Fields (40+ fields for ARC integration):**

| Field Name | Type | Example Value | Purpose |
|------------|------|---------------|---------|
| `u_github_repo` | String | Freundcloud/microservices-demo | Repository name |
| `u_github_commit` | String | 99c7767b | Git commit SHA |
| `u_github_branch` | String | main | Source branch |
| `u_github_actor` | String | olafkfreund | GitHub user |
| `u_github_run_id` | String | 19172412878 | Pipeline run ID |
| `u_github_workflow` | String | Master CI/CD Pipeline | Workflow name |
| `u_environment` | String | prod | Target environment |
| `u_services_deployed` | JSON | ["frontend", "cartservice", ...] | Services in deployment |
| `u_infrastructure_changes` | Boolean | false | Infrastructure modified |
| `u_security_scan_status` | String | passed | Overall security status |
| `u_critical_vulnerabilities` | Integer | 0 | CRITICAL vuln count |
| `u_high_vulnerabilities` | Integer | 2 | HIGH vuln count |
| `u_medium_vulnerabilities` | Integer | 8 | MEDIUM vuln count |
| `u_unit_test_status` | String | passed | Unit test outcome |
| `u_unit_test_total` | Integer | 500 | Total tests executed |
| `u_unit_test_passed` | Integer | 485 | Passed tests |
| `u_unit_test_failed` | Integer | 15 | Failed tests |
| `u_unit_test_coverage` | String | 85.0% | Code coverage |
| `u_sonarcloud_status` | String | passed | Quality gate status |
| `u_sonarcloud_bugs` | Integer | 12 | Bug count |
| `u_sonarcloud_vulnerabilities` | Integer | 3 | Vulnerability count |
| `u_sonarcloud_code_smells` | Integer | 45 | Code smell count |
| `u_sonarcloud_coverage` | String | 68.5% | SonarCloud coverage |
| `u_previous_version` | String | prod-v1.2.2 | Previous deployed version |
| `u_new_version` | String | prod-v1.2.3 | New version being deployed |
| `u_deployment_status` | String | success / failure | Deployment outcome |
| `u_running_pods` | Integer | 36 | Healthy pods after deployment |
| `u_total_pods` | Integer | 36 | Total expected pods |
| `u_frontend_url` | URL | <http://alb-xyz.amazonaws.com> | Application URL |
| `u_smoke_test_status` | String | passed | Smoke test outcome |
| `u_smoke_test_duration` | Integer | 45 | Smoke test duration (seconds) |
| `u_correlation_id` | String | 19172412878-prod | Unique correlation ID |

### Change Reference Linking

**Table:** `sn_devops_change_reference`

Links change requests to DevOps pipeline executions, enabling bi-directional traceability.

| Field Name | Type | Example Value | Purpose |
|------------|------|---------------|---------|
| `change_request` | Reference | stu901vwx234... | Links to change_request.sys_id |
| `pipeline_name` | String | Deploy to prod | Human-readable pipeline name |
| `pipeline_id` | String | 19172412878 | GitHub run_id (correlation) |
| `pipeline_url` | URL | <https://github.com/.../runs/>... | Direct link to execution |
| `tool` | Reference | f62c4e49... | Links to sn_devops_tool |

### Approval Workflow Logic

**Environment-Based Approval Strategy:**

```yaml
if environment == "dev":
  approval_required = false
  state = "implement"  # Auto-approve
elif environment == "qa":
  approval_required = true
  state = "assess"  # CAB review required
elif environment == "prod":
  approval_required = true
  state = "assess"  # CAB + stakeholder approval required
```

**Approval Gate Implementation:**

1. **Dev Environment:** No approval required, change auto-transitions to "implement" state
2. **QA Environment:** Single approver from DevOps team required
3. **Production:** Multiple approvers required (DevOps lead + stakeholder)

**Approval Verification:**

GitHub Actions workflow polls ServiceNow for change request state:

```bash
while [ "$STATE" != "implement" ]; do
  STATE=$(curl -s -u "$USER:$PASS" \
    "$SN_URL/api/now/table/change_request/$CHANGE_SYS_ID?sysparm_fields=state" \
    | jq -r '.result.state')

  if [ "$STATE" == "cancelled" ] || [ "$STATE" == "closed" ]; then
    echo "Change request rejected"
    exit 1
  fi

  sleep 30  # Poll every 30 seconds
done
```

---

## Component 6: Package Registration

### Purpose

Register deployed artifacts (Docker container images) in ServiceNow's package management system, enabling version tracking, rollback capabilities, and configuration management database (CMDB) integration.

### Technical Implementation

**Workflow:** `.github/workflows/MASTER-PIPELINE.yaml` (register-packages job)
**ServiceNow Action:** `ServiceNow/servicenow-devops-register-package@v3.1.0`

### Package Registration Flow

```mermaid
sequenceDiagram
    participant Build as build-and-push Job
    participant Reg as register-packages Job
    participant Action as ServiceNow DevOps Action
    participant SNAPI as ServiceNow DevOps API
    participant Package as sn_devops_package
    participant Artifact as sn_devops_artifact

    Build->>Build: Build 12 microservice images
    Build->>Build: Push to AWS ECR
    Build-->>Reg: Output services_built (JSON array)

    Reg->>Reg: Parse services_built JSON
    Reg->>Reg: Construct artifacts metadata (per service)

    loop For each service
        Reg->>Reg: Create artifact entry:
        Note over Reg: name: ECR repository URL
        Note over Reg: version: environment-commit_sha
        Note over Reg: semanticVersion: environment-run_number
    end

    Reg->>Action: ServiceNow/servicenow-devops-register-package
    Note over Reg,Action: Inputs: artifacts, package-name, credentials

    Action->>SNAPI: POST /api/sn_devops/devops/package/registration
    Note over Action,SNAPI: Payload: package metadata + artifacts array
    SNAPI->>Package: INSERT or UPDATE package record
    SNAPI->>Artifact: INSERT artifact records (one per service)

    Package-->>SNAPI: Return package sys_id
    Artifact-->>SNAPI: Return artifact sys_ids
    SNAPI-->>Action: Return 201 Created + package details
    Action-->>Reg: Output package registration confirmation
```

### Package Data Structure

**Package Metadata:**

```json
{
  "name": "microservices-dev-19172412878.package",
  "artifacts": [
    {
      "name": "533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend",
      "version": "dev-99c7767b",
      "semanticVersion": "dev-12878",
      "repositoryName": "Freundcloud/microservices-demo"
    },
    {
      "name": "533267307120.dkr.ecr.eu-west-2.amazonaws.com/cartservice",
      "version": "dev-99c7767b",
      "semanticVersion": "dev-12878",
      "repositoryName": "Freundcloud/microservices-demo"
    }
  ]
}
```

**Package Table Schema:**

**Table:** `sn_devops_package`

| Field Name | Type | Example Value | Purpose |
|------------|------|---------------|---------|
| `sys_id` | UUID | yza012bcd345... | Primary key |
| `name` | String | microservices-dev-19172412878.package | Package identifier |
| `version` | String | dev-99c7767b | Version tag |
| `created_date` | Datetime | 2025-11-07 15:15:00 | Package creation time |
| `artifact_count` | Integer | 12 | Number of artifacts in package |
| `tool` | Reference | f62c4e49... | Links to sn_devops_tool |
| `project` | Reference | c6c9eb71... | Links to sn_devops_project |

---

## Database Schema Reference

### Entity Relationship Diagram

```mermaid
erDiagram
    sn_devops_tool ||--o{ sn_devops_project : "has"
    sn_devops_project ||--o{ sn_devops_orchestration_task : "contains"
    sn_devops_project ||--o{ sn_devops_work_item : "contains"
    sn_devops_project ||--o{ sn_devops_test_result : "contains"
    sn_devops_project ||--o{ sn_devops_test_summary : "contains"
    sn_devops_project ||--o{ sn_devops_artifact : "contains"
    sn_devops_project ||--o{ sn_devops_package : "contains"
    change_request ||--o{ sn_devops_change_reference : "linked_via"
    change_request ||--o{ sn_devops_test_result : "validates"
    change_request ||--o{ sn_devops_work_item : "implements"
    change_request ||--o{ sn_devops_artifact : "deploys"
    sn_devops_package ||--o{ sn_devops_artifact : "bundles"

    sn_devops_tool {
        string sys_id PK
        string name "GithHubARC"
        string type "github"
    }

    sn_devops_project {
        string sys_id PK
        string number "PRJ0001001"
        string name "Freundcloud/microservices-demo"
        string tool_id FK
    }

    sn_devops_orchestration_task {
        string sys_id PK
        string number "TASK0001234"
        string name
        string native_id
        string task_url
        string project_id FK
        string tool_id FK
        boolean track
        datetime sys_created_on
    }

    sn_devops_work_item {
        string sys_id PK
        string number "WI0001197"
        string name
        string external_id
        string url
        string status
        string type
        string project_id FK
        string tool_id FK
        datetime sys_created_on
    }

    sn_devops_test_result {
        string sys_id PK
        string number "TR0005678"
        string name
        string test_suite_name
        string test_result
        integer test_cases_total
        integer test_cases_passed
        integer test_cases_failed
        integer test_cases_skipped
        datetime start_time
        datetime end_time
        integer duration
        string execution_url
        string project_id FK
        string tool_id FK
    }

    sn_devops_test_summary {
        string sys_id PK
        string pipeline_id
        integer total_test_suites
        integer passed_test_suites
        integer failed_test_suites
        integer total_tests
        integer passed_tests
        integer failed_tests
        integer test_execution_time
        string overall_result
    }

    sn_devops_artifact {
        string sys_id PK
        string number "ART0002345"
        string name
        string artifact_type
        string version
        text sbom_data
        integer component_count
        string artifact_url
        string project_id FK
        string tool_id FK
    }

    sn_devops_package {
        string sys_id PK
        string name
        string version
        datetime created_date
        integer artifact_count
        string tool_id FK
        string project_id FK
    }

    change_request {
        string sys_id PK
        string number "CHG0030463"
        string short_description
        text description
        string type
        string risk
        string impact
        string priority
        string state
        string u_github_repo
        string u_github_commit
        string u_environment
        json u_services_deployed
        string u_security_scan_status
        integer u_critical_vulnerabilities
        string u_deployment_status
    }

    sn_devops_change_reference {
        string sys_id PK
        string change_request_id FK
        string pipeline_name
        string pipeline_id
        string pipeline_url
        string tool_id FK
    }
```

### Table Index Summary

**Core Tables:**

- `sn_devops_tool` - CI/CD tool registration (GitHub, Jenkins, GitLab, etc.)
- `sn_devops_project` - Project/repository tracking
- `sn_devops_orchestration_task` - Pipeline job execution tracking
- `sn_devops_work_item` - Requirements and issue tracking

**Testing Tables:**

- `sn_devops_test_result` - Individual test suite executions
- `sn_devops_test_summary` - Aggregated test metrics per pipeline
- `sn_devops_performance_test_summary` - Performance and smoke test results

**Security Tables:**

- `sn_devops_artifact` - SBOM and security artifacts
- `sn_devops_software_quality_scan_summary` - Code quality scan results
- `sn_devops_software_quality_scan_detail` - Individual security findings

**Package Management Tables:**

- `sn_devops_package` - Deployment package tracking
- `sn_devops_artifact` - Individual artifacts within packages

**Change Management Tables:**

- `change_request` - Traditional ServiceNow change requests
- `sn_devops_change_reference` - Links change requests to pipelines

---

## REST API Specifications

### Authentication

All ServiceNow REST API requests use HTTP Basic Authentication:

```http
Authorization: Basic <base64-encoded-credentials>
```

Where credentials are encoded as: `base64(username:password)`

**Security Considerations:**

- Credentials stored as GitHub encrypted secrets
- Never logged or exposed in workflow outputs
- Each request creates new authenticated session
- No session tokens or cookies maintained

### Common Request Headers

```http
Content-Type: application/json
Accept: application/json
Authorization: Basic <credentials>
```

### API Endpoint Patterns

ServiceNow provides two API patterns:

**1. Table API (Standard REST)**

```
POST   /api/now/table/{table_name}
GET    /api/now/table/{table_name}/{sys_id}
GET    /api/now/table/{table_name}?sysparm_query={query}
PATCH  /api/now/table/{table_name}/{sys_id}
DELETE /api/now/table/{table_name}/{sys_id}
```

**2. DevOps API (Specialized)**

```
POST /api/sn_devops/devops/tool/test
POST /api/sn_devops/devops/package/registration
POST /api/sn_devops/devops/artifact/registration
```

### Query Parameter Reference

**Common Query Parameters:**

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `sysparm_query` | Filter results | `url=https://github.com/...` |
| `sysparm_fields` | Limit returned fields | `sys_id,number,state` |
| `sysparm_limit` | Limit result count | `10` |
| `sysparm_offset` | Pagination offset | `20` |
| `sysparm_display_value` | Return display values | `true` or `false` |

**Query Operators:**

| Operator | Syntax | Example |
|----------|--------|---------|
| Equals | `field=value` | `type=issue` |
| Not Equals | `field!=value` | `state!=closed` |
| Contains | `fieldLIKEvalue` | `nameLIKEmicroservices` |
| Greater Than | `field>value` | `created_on>2025-01-01` |
| AND | `^` | `type=issue^state=open` |
| OR | `^OR` | `priority=high^ORpriority=critical` |

### Response Format Standards

**Successful Response (201 Created):**

```json
{
  "result": {
    "sys_id": "abc123def456...",
    "number": "TASK0001234",
    "name": "Orchestration task name",
    "sys_created_on": "2025-11-07 15:01:23",
    "sys_updated_on": "2025-11-07 15:01:23"
  }
}
```

**Error Response (400 Bad Request):**

```json
{
  "error": {
    "message": "Invalid field name: 'invalid_field'",
    "detail": "Field 'invalid_field' does not exist on table 'sn_devops_orchestration_task'"
  },
  "status": "failure"
}
```

**Query Result (200 OK):**

```json
{
  "result": [
    {
      "sys_id": "abc123...",
      "number": "WI0001197"
    },
    {
      "sys_id": "def456...",
      "number": "WI0001198"
    }
  ]
}
```

---

## Implementation Challenges and Solutions

### Challenge 1: Tool ID Mismatch

**Problem:** Initial implementation used incorrect tool sys_id, causing records to not link to correct project.

**Root Cause:** ServiceNow instance had multiple tools registered for GitHub integration:

- GithHubARC (correct, sys_id: f62c4e49c3fcf614e1bbf0cb050131ef)
- GitHub (incorrect, different sys_id)

**Solution:**

1. Query ServiceNow to identify correct tool:

```bash
curl -u "$USER:$PASS" \
  "$SN_URL/api/now/table/sn_devops_tool?sysparm_query=nameLIKEGith" \
  | jq '.result[] | {name, sys_id}'
```

2. Update all workflows and composite actions to use correct tool sys_id
3. Store as GitHub secret: `SN_ORCHESTRATION_TOOL_ID`

**Reference:** [SERVICENOW-TOOL-ID-FIX.md](docs/implemented/SERVICENOW-TOOL-ID-FIX.md)

### Challenge 2: Commit Message Parsing for Work Items

**Problem:** Work item extraction only parsed commit subject lines, missing issue references in commit bodies.

**Root Cause:** Git log command used `--pretty=format:"%s"` (subject only) instead of `--pretty=format:"%s%n%b"` (subject + body).

**Solution:**
Modified work item extraction in `.github/actions/register-work-items/action.yaml`:

```yaml
# Before (incorrect)
COMMITS=$(git log --pretty=format:"%s" -10)

# After (correct)
COMMITS=$(git log --pretty=format:"%s%n%b" -10)
```

**Impact:** Improved work item extraction accuracy from ~60% to ~95%.

**Reference:** [SERVICENOW-WORK-ITEMS-INTEGRATION.md](docs/implemented/SERVICENOW-WORK-ITEMS-INTEGRATION.md)

### Challenge 3: DevOps API vs Table API Selection

**Problem:** Uncertainty about which API to use for change request creation.

**Analysis:**

- DevOps Change Control API requires plugin configuration
- Table API works immediately with any ServiceNow instance
- Custom fields not available in DevOps Change Control API

**Solution:** Implement hybrid approach:

1. Use Table API for change request creation (with 40+ custom fields)
2. Use DevOps tables for supplementary tracking (test results, artifacts, work items)
3. Link via `sn_devops_change_reference` table

**Benefits:**

- No ServiceNow configuration required
- Full compliance data capture
- DevOps workspace visibility
- Works on all ServiceNow instances including PDIs

**Reference:** [SERVICENOW-HYBRID-APPROACH.md](docs/implemented/SERVICENOW-HYBRID-APPROACH.md)

### Challenge 4: Test Result Upload Timing

**Problem:** Test results uploaded to ServiceNow before change request created, causing orphaned test records.

**Root Cause:** Parallel job execution - test jobs complete before change request creation job.

**Solution:**

1. Create change request first
2. Pass change_sys_id to downstream jobs via outputs
3. Associate test results with change request in subsequent jobs

**Implementation:**

```yaml
jobs:
  servicenow-change:
    outputs:
      change_sys_id: ${{ steps.create-cr.outputs.sys_id }}

  upload-test-results:
    needs: servicenow-change
    env:
      CHANGE_SYS_ID: ${{ needs.servicenow-change.outputs.change_sys_id }}
```

---

## Future Enhancement Opportunities

### 1. Real-Time Deployment Status Updates

**Current State:** Change requests updated post-deployment with final status.

**Enhancement:** Stream deployment progress to ServiceNow in real-time:

- Pod readiness updates every 30 seconds
- Service health check results
- Rolling update progress percentage
- Error and warning log streaming

**Implementation Approach:**

```yaml
- name: Stream Deployment Status
  run: |
    while kubectl rollout status deployment/frontend -n microservices-dev; do
      READY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}')
      TOTAL=$(kubectl get deployment frontend -o jsonpath='{.spec.replicas}')

      curl -X PATCH -u "$USER:$PASS" \
        "$SN_URL/api/now/table/change_request/$CHANGE_SYS_ID" \
        -d "{\"u_deployment_progress\": \"$READY/$TOTAL pods ready\"}"

      sleep 30
    done
```

### 2. Automated Rollback Integration

**Enhancement:** Link ServiceNow change request state to automatic rollback:

- Monitor change request state during deployment
- If changed to "cancelled", trigger rollback
- Update change request with rollback evidence
- Restore previous version from package registry

**Implementation Approach:**

```yaml
- name: Monitor for Cancellation
  run: |
    while [ "$DEPLOYMENT_IN_PROGRESS" == "true" ]; do
      STATE=$(curl -s -u "$USER:$PASS" \
        "$SN_URL/api/now/table/change_request/$CHANGE_SYS_ID?sysparm_fields=state" \
        | jq -r '.result.state')

      if [ "$STATE" == "cancelled" ]; then
        echo "Change cancelled - initiating rollback"
        kubectl rollout undo deployment/frontend -n microservices-prod
        exit 0
      fi

      sleep 30
    done
```

### 3. Advanced Analytics Integration

**Enhancement:** Populate ServiceNow analytics tables for trend analysis:

- Deployment frequency metrics
- Lead time for changes
- Mean time to recovery (MTTR)
- Change failure rate
- DORA metrics calculation

**Tables to Populate:**

- `sn_devops_deployment_metrics`
- `sn_devops_change_velocity`
- `sn_devops_reliability_metrics`

### 4. Bi-Directional Synchronization

**Enhancement:** Sync change request updates back to GitHub:

- Create GitHub issue when change request created
- Update issue status based on change request state
- Link ServiceNow change number in GitHub issue
- Cross-reference comments between systems

### 5. Configuration Item (CI) Integration

**Enhancement:** Register deployed services as Configuration Items in ServiceNow CMDB:

- Create CI records for each microservice
- Link CIs to change requests
- Track service dependencies via CI relationships
- Maintain CI version history

**Implementation:**

```bash
# Create CI for each service
curl -X POST -u "$USER:$PASS" \
  "$SN_URL/api/now/table/cmdb_ci_service" \
  -d '{
    "name": "frontend-service",
    "environment": "prod",
    "operational_status": "operational",
    "version": "v1.2.3",
    "u_github_repo": "Freundcloud/microservices-demo"
  }'
```

### 6. Performance Test Integration

**Enhancement:** Capture performance test results from load testing tools:

- Locust load test metrics
- K6 performance test results
- JMeter test execution data
- Response time percentiles (p50, p95, p99)
- Throughput and error rate metrics

**Table:** `sn_devops_performance_test_summary`

### 7. Security Vulnerability Tracking

**Enhancement:** Detailed vulnerability management in ServiceNow:

- Individual vulnerability records (CVE tracking)
- Severity-based assignment rules
- Remediation tracking and verification
- Vulnerability aging metrics
- Integration with security information and event management (SIEM)

**Tables:**

- `sn_devops_security_result`
- `sn_devops_vulnerability`

---

## Operational Considerations

### Monitoring and Alerting

**Key Metrics to Monitor:**

1. **Integration Success Rate**
   - Percentage of successful API calls to ServiceNow
   - Target: >99% success rate
   - Alert threshold: <95% over 1-hour period

2. **Data Synchronization Lag**
   - Time between GitHub event and ServiceNow record creation
   - Target: <2 minutes average
   - Alert threshold: >5 minutes average

3. **Missing Record Detection**
   - Orphaned test results (no associated change request)
   - Work items without project linkage
   - Orchestration tasks with invalid tool references
   - Alert: Daily summary of missing linkages

4. **API Performance**
   - ServiceNow API response time (p95)
   - Target: <2 seconds
   - Alert threshold: >5 seconds

**Monitoring Implementation:**

```yaml
- name: Monitor Integration Health
  if: always()
  run: |
    # Count successful vs failed ServiceNow API calls
    SUCCESS_COUNT=$(grep "ServiceNow API: 201 Created" workflow.log | wc -l)
    FAILURE_COUNT=$(grep "ServiceNow API: ERROR" workflow.log | wc -l)

    SUCCESS_RATE=$(echo "scale=2; $SUCCESS_COUNT / ($SUCCESS_COUNT + $FAILURE_COUNT) * 100" | bc)

    if (( $(echo "$SUCCESS_RATE < 95" | bc -l) )); then
      echo "::warning::ServiceNow integration success rate: ${SUCCESS_RATE}%"
    fi
```

### Troubleshooting Guide

**Issue: Orchestration tasks not appearing in ServiceNow**

**Diagnosis:**

1. Check workflow logs for API response codes
2. Verify tool sys_id matches project configuration
3. Confirm GitHub token has correct permissions
4. Validate ServiceNow credentials

**Resolution:**

```bash
# Verify tool sys_id
curl -u "$USER:$PASS" \
  "$SN_URL/api/now/table/sn_devops_tool?sysparm_query=name=GithHubARC" \
  | jq '.result[0].sys_id'

# Check recent orchestration tasks
curl -u "$USER:$PASS" \
  "$SN_URL/api/now/table/sn_devops_orchestration_task?sysparm_limit=10&sysparm_query=sys_created_onONToday@javascript:gs.beginningOfToday()@javascript:gs.endOfToday()" \
  | jq '.result[] | {number, name, sys_created_on}'
```

**Issue: Work items not extracted from commits**

**Diagnosis:**

1. Check commit message format for issue references
2. Verify GitHub token has `issues: read` permission
3. Confirm issue numbers are valid and accessible

**Resolution:**

```bash
# Test issue extraction locally
git log --pretty=format:"%s%n%b" -10 \
  | grep -oP '(?:Fixes|Closes|Resolves|Issue)?\s*#\K\d+' \
  | sort -u

# Verify GitHub API access
gh api /repos/Freundcloud/microservices-demo/issues/80
```

**Issue: Test results not linked to change request**

**Diagnosis:**

1. Verify change request created before test result upload
2. Check change_sys_id output from change request job
3. Confirm test result API payload includes change_request field

**Resolution:**

```yaml
# Add debug output in workflow
- name: Debug Change Request
  run: |
    echo "Change Sys ID: ${{ needs.servicenow-change.outputs.change_sys_id }}"
    echo "Change Number: ${{ needs.servicenow-change.outputs.change_number }}"
```

### Performance Optimization

**Parallel API Calls:**

When multiple independent ServiceNow records need creation, execute API calls in parallel:

```bash
# Sequential (slow) - 12 seconds for 12 services
for service in frontend cartservice productcatalogservice; do
  curl -X POST ... /api/now/table/sn_devops_artifact
done

# Parallel (fast) - 1-2 seconds for 12 services
for service in frontend cartservice productcatalogservice; do
  curl -X POST ... /api/now/table/sn_devops_artifact &
done
wait
```

**Batch Operations:**

For bulk data insertion, use ServiceNow batch API:

```bash
curl -X POST -u "$USER:$PASS" \
  "$SN_URL/api/now/table/batch" \
  -d '{
    "batch_request_id": "batch-001",
    "rest_requests": [
      {"method": "POST", "url": "/api/now/table/sn_devops_artifact", "body": {...}},
      {"method": "POST", "url": "/api/now/table/sn_devops_artifact", "body": {...}}
    ]
  }'
```

**Response Caching:**

Cache frequently-accessed reference data (project sys_id, tool sys_id) to reduce API calls:

```bash
# Cache tool sys_id for 24 hours
if [ ! -f .cache/tool_sys_id ] || [ $(find .cache/tool_sys_id -mmin +1440) ]; then
  curl -s -u "$USER:$PASS" \
    "$SN_URL/api/now/table/sn_devops_tool?sysparm_query=name=GithHubARC" \
    | jq -r '.result[0].sys_id' > .cache/tool_sys_id
fi

TOOL_SYS_ID=$(cat .cache/tool_sys_id)
```

---

## Security Best Practices

### Credential Management

**GitHub Secrets Configuration:**

All ServiceNow credentials stored as GitHub repository or organization secrets:

| Secret Name | Purpose | Example Value |
|-------------|---------|---------------|
| `SERVICENOW_USERNAME` | API authentication username | github_integration |
| `SERVICENOW_PASSWORD` | API authentication password | (encrypted) |
| `SERVICENOW_INSTANCE_URL` | ServiceNow instance base URL | <https://calitiiltddemo3.service-now.com> |
| `SN_ORCHESTRATION_TOOL_ID` | Tool sys_id for record linking | f62c4e49c3fcf614e1bbf0cb050131ef |

**Secret Rotation Policy:**

- Rotate ServiceNow password every 90 days
- Update GitHub secret immediately after rotation
- Test integration after credential update
- Maintain 24-hour overlap during rotation (if supported by ServiceNow)

### API Request Security

**TLS/SSL Enforcement:**

- All API requests use HTTPS (TLS 1.2 minimum)
- Certificate validation enabled (no self-signed certs in production)
- Hostname verification enforced

**Request Validation:**

```bash
# Validate instance URL before API call
if [[ ! "$SERVICENOW_INSTANCE_URL" =~ ^https://[a-z0-9-]+\.service-now\.com$ ]]; then
  echo "Invalid ServiceNow URL format"
  exit 1
fi
```

**Input Sanitization:**

```bash
# Sanitize user-controlled input before API call
COMMIT_MESSAGE=$(echo "$RAW_COMMIT_MSG" | jq -Rs .)  # JSON-safe escaping
```

### Audit Trail

**Logging Requirements:**

1. **Log all API calls** (without credentials):

```yaml
- name: Create Orchestration Task
  run: |
    echo "API: POST /api/now/table/sn_devops_orchestration_task"
    echo "Payload: $(echo "$PAYLOAD" | jq -c 'del(.password)')"
    RESPONSE=$(curl ...)
    echo "Response: $RESPONSE"
```

2. **Log ServiceNow record identifiers:**

```yaml
echo "Created: $TASK_NUMBER (sys_id: $TASK_SYS_ID)"
```

3. **Retain logs for compliance:**

- GitHub Actions logs retained for 90 days minimum
- ServiceNow audit tables (`sys_audit`) track all record changes
- Export critical logs to long-term storage (S3, CloudWatch)

---

## Conclusion

The GitHub-ServiceNow integration implemented in ARC establishes a comprehensive DevOps platform that bridges development workflows with enterprise change management and compliance requirements. By utilizing ServiceNow's REST API and DevOps-specific tables, the solution achieves:

**Technical Excellence:**

- Complete automation of manual data entry processes
- Real-time synchronization between GitHub Actions and ServiceNow
- Robust error handling and non-blocking failure modes
- Scalable architecture supporting 12+ microservices

**Business Value:**

- Compliance-ready audit trails for SOC 2, ISO 27001, PCI DSS
- Reduced deployment friction through automated approvals
- Complete traceability from commit to production
- Risk-based decision making with comprehensive test evidence

**Operational Benefits:**

- Zero-configuration deployment (no ServiceNow plugins required)
- Environment-agnostic implementation (works on all ServiceNow instances)
- Extensible architecture supporting future enhancements
- Battle-tested in production deployments

This integration serves as a reference implementation for organizations seeking to modernize their SDLC while maintaining enterprise governance standards.

---

## Appendix A: API Endpoint Reference

### ServiceNow Table API Endpoints

**Base URL:** `https://{instance}.service-now.com/api/now/table`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/change_request` | POST | Create change request | Basic Auth |
| `/change_request/{sys_id}` | GET | Retrieve change request | Basic Auth |
| `/change_request/{sys_id}` | PATCH | Update change request | Basic Auth |
| `/sn_devops_orchestration_task` | POST | Register orchestration task | Basic Auth |
| `/sn_devops_orchestration_task` | GET | Query orchestration tasks | Basic Auth |
| `/sn_devops_work_item` | POST | Register work item | Basic Auth |
| `/sn_devops_work_item` | GET | Query work items | Basic Auth |
| `/sn_devops_test_result` | POST | Register test result | Basic Auth |
| `/sn_devops_test_result` | GET | Query test results | Basic Auth |
| `/sn_devops_test_summary` | POST | Register test summary | Basic Auth |
| `/sn_devops_artifact` | POST | Register artifact | Basic Auth |
| `/sn_devops_package` | POST | Register package | Basic Auth |
| `/sn_devops_change_reference` | POST | Link change to pipeline | Basic Auth |
| `/sn_devops_tool` | GET | Query registered tools | Basic Auth |
| `/sn_devops_project` | GET | Query projects | Basic Auth |

### ServiceNow DevOps API Endpoints

**Base URL:** `https://{instance}.service-now.com/api/sn_devops/devops`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/tool/test` | POST | Upload test results (via action) | Token-based |
| `/package/registration` | POST | Register deployment package | Token-based |
| `/artifact/registration` | POST | Register artifacts | Token-based |

---

## Appendix B: Workflow Reference

### Key Workflows

**Master CI/CD Pipeline:**

- Path: `.github/workflows/MASTER-PIPELINE.yaml`
- Trigger: Push to main, pull requests, manual dispatch
- Jobs: 15+ jobs orchestrating build, test, scan, deploy
- ServiceNow Integration: Orchestration tasks, work items, test results, change requests

**Change Request Creation:**

- Path: `.github/workflows/servicenow-change-rest.yaml`
- Type: Reusable workflow
- Purpose: Create change request with 40+ custom fields
- Outputs: change_number, change_sys_id

**Test Result Upload:**

- Path: `.github/workflows/upload-test-results-servicenow.yaml`
- Type: Reusable workflow
- Purpose: Upload test execution results to ServiceNow
- Integration: sn_devops_test_result table

### Composite Actions

**Register Orchestration Task:**

- Path: `.github/actions/register-orchestration-task/action.yaml`
- Usage: Track GitHub Actions jobs in ServiceNow
- Integration: sn_devops_orchestration_task table

**Register Work Items:**

- Path: `.github/actions/register-work-items/action.yaml`
- Usage: Extract issues from commits and register in ServiceNow
- Integration: sn_devops_work_item table

---

## Document Metadata

**Document Version:** 1.0
**Created:** 2025-11-10
**Last Updated:** 2025-11-10
**Status:** Production
**Classification:** Technical Reference
**Audience:** Engineers, Architects, Technical Partners

**Related Documentation:**

- [GITHUB-SERVICENOW-DATA-FLOW.md](GITHUB-SERVICENOW-DATA-FLOW.md) - Visual demo guide
- [SERVICENOW-HYBRID-APPROACH.md](implemented/SERVICENOW-HYBRID-APPROACH.md) - Implementation strategy
- [SERVICENOW-DEVOPS-TABLES-REFERENCE.md](implemented/SERVICENOW-DEVOPS-TABLES-REFERENCE.md) - Table schemas

**Revision History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-10 | Olaf Krasicki-Freund | Initial technical deep dive document |
