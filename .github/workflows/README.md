# GitHub Actions Workflows

This page describes the CI/CD workflows for the Online Boutique app on AWS EKS.

## Infrastructure

The CI/CD pipelines run in GitHub Actions using GitHub-hosted runners. The workflows deploy to AWS EKS cluster with multi-environment support (dev/qa/prod) using Kustomize overlays and Istio service mesh.

## Workflows Overview

All workflows are reusable and called by the [MASTER-PIPELINE.yaml](MASTER-PIPELINE.yaml), which orchestrates the complete CI/CD process.

**Note**: AWS credentials must be configured as GitHub Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`) for workflows to function.

### Master Pipeline - [MASTER-PIPELINE.yaml](MASTER-PIPELINE.yaml)

The main orchestration workflow that runs on pushes to main/develop and pull requests. Executes all stages:

1. **Pipeline Initialization** - Determines environment, enforces branch policies
2. **Code Quality & Security** - Validates code, runs security scans, unit tests
3. **Infrastructure Management** - Terraform plan/apply (if infrastructure changed)
4. **Build Docker Images** - Smart change detection, multi-arch builds, Trivy scanning
5. **Deploy Application** - Environment-specific deployment with Kustomize
6. **Post-Deployment Validation** - Smoke tests, health checks
7. **Pipeline Summary** - Comprehensive results report

### Unit Tests - [unit-tests.yaml](unit-tests.yaml)

Runs unit tests for all 11 microservices across 5 programming languages:

- **Go Services** (4): frontend, productcatalog, shipping, checkout
- **Python Services** (2): email, recommendation
- **Java Services** (2): adservice, shoppingassistant
- **Node.js Services** (2): currency, payment
- **C# Services** (1): cartservice

Features:
- Parallel test execution by language (matrix strategy)
- Coverage reporting with artifacts (30-day retention)
- Creates placeholder tests if none exist (real tests should replace them)
- Fails pipeline if any tests fail
- Comprehensive test summary with pass/fail counts
- **ServiceNow Integration**: Automatically uploads test results to ServiceNow for approval evidence
  - Uses `ServiceNow/servicenow-devops-test-report@v6.0.0` action
  - Generates JUnit/TRX XML reports for each service
  - Test results visible in ServiceNow DevOps workspace
  - Linked to change requests for approval workflow

### Security Scanning - [security-scan.yaml](security-scan.yaml)

Comprehensive security scanning across multiple dimensions:

- **SAST**: CodeQL (5 languages) + Semgrep
- **Dependency Scanning**: GitHub Dependency Review + OWASP Dependency Check + Grype
- **Container Scanning**: Trivy filesystem scan
- **IaC Security**: Checkov + tfsec for Terraform
- **Kubernetes Manifests**: Kubesec + Polaris
- **License Compliance**: pip-licenses + license-checker
- **SBOM Generation**: CycloneDX format for compliance

All results uploaded to GitHub Security tab for centralized visibility.

### Build Images - [build-images.yaml](build-images.yaml)

Smart image building workflow with change detection:

1. **Change Detection** - Uses `dorny/paths-filter` to detect which services changed
2. **Multi-arch Builds** - Builds for amd64 and arm64
3. **Security Scanning** - Trivy scans before push (SARIF + table formats)
4. **ECR Push** - Pushes to AWS ECR with multiple tags (environment, commit SHA, branch)
5. **SBOM Generation** - Creates Software Bill of Materials per service
6. **ServiceNow Package Registration** - Registers Docker images as packages in ServiceNow
7. **Cache Optimization** - GitHub Actions cache for faster rebuilds

**ServiceNow Package Registration**:
- Uses `ServiceNow/servicenow-devops-register-package@v3.1.0` action
- Registers every Docker image pushed to ECR
- Package metadata includes:
  - Package name (service name)
  - Version (environment-commitSHA)
  - Semantic version (environment.0.buildNumber)
  - ECR repository URL
  - Image tag and digest
  - Commit SHA, branch, build number
  - Link to GitHub Actions build
- Packages visible in ServiceNow DevOps workspace
- Linked to change requests for deployment approval

Outputs: Services built, build success status

### Deploy Environment - [deploy-environment.yaml](deploy-environment.yaml)

Environment-specific deployment using Kustomize:

1. **Configure kubectl** - Connects to AWS EKS cluster
2. **Apply Kustomize Overlay** - Deploys to namespace (microservices-dev/qa/prod)
3. **Wait for Ready** - Monitors rollout status with configurable timeout
4. **Health Verification** - Checks all pods reach Ready state
5. **Deployment Summary** - Reports success/failure with details

Supports: wait_for_ready flag, configurable timeout (default: 10 min)

### Terraform Workflows

#### [terraform-plan.yaml](terraform-plan.yaml)
Runs on pull requests to preview infrastructure changes:
- Validates Terraform syntax
- Runs terraform plan
- Posts plan output as PR comment
- Runs Terraform tests
- Security scanning (Checkov, tfsec)

#### [terraform-apply.yaml](terraform-apply.yaml)
Applies infrastructure changes on merge to main:
- Validates configuration
- Applies changes with auto-approve
- Runs post-deployment verification
- Supports manual destroy action

### AWS Infrastructure Discovery - [aws-infrastructure-discovery.yaml](aws-infrastructure-discovery.yaml)

Discovers and documents existing AWS resources (currently disabled, manual trigger only).

## Environment Strategy

The pipeline supports three environments with namespace isolation:

| Environment | Namespace | Trigger | Purpose |
|-------------|-----------|---------|---------|
| **dev** | microservices-dev | Push to main/develop | Development and testing |
| **qa** | microservices-qa | Manual dispatch | QA validation |
| **prod** | microservices-prod | Manual dispatch from release/* branch | Production |

## Branch Policy

- **dev/qa**: Can deploy from any branch
- **prod**: Must deploy from `release/*` branches only

## Required GitHub Secrets

### AWS Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for authentication |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_ACCOUNT_ID` | AWS account ID for ECR |

### ServiceNow Secrets

| Secret | Description |
|--------|-------------|
| `SN_DEVOPS_USER` | ServiceNow DevOps integration username |
| `SN_DEVOPS_PASSWORD` | ServiceNow DevOps integration password |
| `SN_INSTANCE_URL` | ServiceNow instance URL (e.g., https://your-instance.service-now.com) |
| `SN_ORCHESTRATION_TOOL_ID` | ServiceNow orchestration tool sys_id (from sn_devops_tool table) |

**Note**: ServiceNow secrets are optional. If not configured, test results will not be uploaded to ServiceNow, but tests will still run and report in GitHub Actions.

## Testing Your Changes

To test workflows locally before pushing:

```bash
# Validate Kustomize configs
kubectl kustomize kustomize/overlays/dev

# Run Terraform validation
just tf-validate

# Run security scans locally
just security-scan-all

# Build images locally
just docker-build <service-name>

# Run unit tests locally
cd src/<service-name>
# Go: go test ./...
# Python: pytest
# Java: ./gradlew test
# Node.js: npm test
# C#: dotnet test
```

## Workflow Outputs

Key workflows provide outputs for downstream jobs:

- **unit-tests**: test_result, tests_run, tests_passed, tests_failed, summary
- **security-scans**: dependency scan results, vulnerability counts
- **build-images**: services_built, build_success, registered_packages (in ServiceNow)
- **deploy-environment**: deployment status, namespace info

### ServiceNow Outputs

Data registered in ServiceNow DevOps:

| Type | Description | Location in ServiceNow |
|------|-------------|------------------------|
| **Test Results** | Unit test execution results per service | DevOps → Testing → Test Results |
| **Packages** | Docker images with metadata (tags, digests, versions) | DevOps → Packages |
| **Artifacts** | Package artifacts with ECR links | Linked to packages |
| **Change Requests** | Test results and packages linked to CRs | Change Management → Change Requests |

## Adding New Tests

To add unit tests to a service:

1. **Go**: Create `*_test.go` files, tests will run automatically
2. **Python**: Create `tests/` directory with `test_*.py` files
3. **Java**: Add tests to `src/test/java/`, Gradle will discover them
4. **Node.js**: Add `test` script to package.json
5. **C#**: Create `*.Tests.csproj` test project

The workflow creates placeholder tests if none exist, but real tests should replace them.

## Troubleshooting

### Tests Failing

Check the test logs in the workflow run:
```
Actions → Unit Tests → <language>-services → Run Tests
```

View test artifacts:
```
Actions → Workflow Run → Artifacts → coverage-<service>
```

### Build Failures

1. Check if service code changed
2. Review Trivy scan results for vulnerabilities
3. Verify Dockerfile builds locally: `just docker-build <service>`

### Deployment Failures

1. Check kubectl rollout status
2. Review pod logs: `kubectl logs -l app=<service> -n microservices-<env>`
3. Verify resource quotas: `kubectl describe resourcequota -n microservices-<env>`
4. Check Istio sidecar injection: `kubectl get pods -n microservices-<env> -o jsonpath='{.items[*].spec.containers[*].name}'`

### Security Scan Failures

Review findings in GitHub Security tab:
```
Security → Code Scanning Alerts
```

Filter by tool (CodeQL, Trivy, Checkov, etc.) to investigate specific findings.

### Terraform Errors

1. Check Terraform state: `terraform state list`
2. Review plan output in workflow logs
3. Verify AWS credentials are valid
4. Check for resource conflicts or quota limits

## Workflow Inputs (Manual Dispatch)

When manually triggering the Master Pipeline:

| Input | Description | Default |
|-------|-------------|---------|
| `environment` | Target environment (dev/qa/prod) | dev |
| `skip_terraform` | Skip infrastructure deployment | false |
| `skip_security` | Skip security scans (NOT recommended for prod) | false |
| `skip_deploy` | Skip application deployment (infrastructure only) | false |
| `force_build_all` | Force build all services (ignore change detection) | false |

## Pipeline Stages Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Stage 0: Pipeline Initialization                       │
│  - Determine environment, branch policy checks          │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 1: Code Quality & Security (Parallel)            │
│  ├─ Code Validation (Kustomize, YAML lint)             │
│  ├─ Security Scans (CodeQL, Semgrep, Trivy, etc.)      │
│  └─ Unit Tests (Go, Python, Java, Node.js, C#)         │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 2: Infrastructure (Conditional)                  │
│  - Terraform Plan (on PR)                              │
│  - Terraform Apply (on merge to main)                  │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 3: Build Docker Images                           │
│  - Change detection (smart builds)                      │
│  - Multi-arch builds (amd64, arm64)                     │
│  - Trivy vulnerability scanning                         │
│  - Push to ECR with multiple tags                      │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 4: Deploy Application                            │
│  - Apply Kustomize overlay to namespace                │
│  - Wait for pods ready (timeout: 10-15 min)            │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 5: Post-Deployment Validation                    │
│  - Smoke tests (frontend health check)                 │
│  - Verify all pods running                             │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│  Stage 6: Pipeline Summary                              │
│  - Generate comprehensive results report                │
│  - Display success/failure for all stages               │
└─────────────────────────────────────────────────────────┘
```

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Project overview and commands
- [docs/COMPLETE-DEPLOYMENT-WORKFLOW.md](../../docs/COMPLETE-DEPLOYMENT-WORKFLOW.md) - Detailed deployment guide
- [kustomize/overlays/README.md](../../kustomize/overlays/README.md) - Multi-environment deployment with Kustomize
