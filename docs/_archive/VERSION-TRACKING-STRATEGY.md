# Enterprise Version Tracking Strategy

> **Purpose**: Track deployed versions across ECR and Kubernetes for security scanning, compliance, audit, and rollback capabilities.

## Overview

This document defines the enterprise-grade version tracking strategy for the microservices demo application, ensuring full traceability from source code to production deployment.

## Requirements

### Business Requirements
- **Compliance**: Track which code version is running in each environment
- **Security**: Enable vulnerability scanning of deployed images
- **Audit**: Provide evidence of what was deployed when and by whom
- **Rollback**: Quick identification of previous working versions
- **Change Management**: Link deployments to ServiceNow change requests

### Technical Requirements
- **ECR Image Tags**: Multiple tags per image for different use cases
- **Kubernetes Labels**: Version metadata on deployments and pods
- **Immutability**: Production versions must be immutable
- **Automation**: Version tagging integrated into CI/CD pipeline

---

## ECR Image Tagging Strategy

### Tag Types

Each container image in ECR should have **multiple tags** to support different use cases:

#### 1. **Git Commit SHA Tag** (Immutable, Primary)
- **Format**: `git-<short-sha>` (e.g., `git-e48fda1`)
- **Purpose**: Immutable reference to exact source code version
- **Usage**:
  - Security scanning with Trivy/Snyk
  - Audit trail and compliance
  - Exact version identification
- **Lifecycle**: Never deleted, kept for audit

**Example**:
```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:git-e48fda1
```

#### 2. **Semantic Version Tag** (Immutable, Release)
- **Format**: `v<major>.<minor>.<patch>` (e.g., `v1.2.3`)
- **Purpose**: Human-readable release version
- **Usage**:
  - Production deployments
  - Customer-facing version numbers
  - Release notes and changelogs
- **Lifecycle**: Permanent, follows SemVer

**Example**:
```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.3
```

#### 3. **Environment Tag** (Mutable, Latest)
- **Format**: `<env>` or `<env>-latest` (e.g., `dev`, `qa-latest`, `prod-latest`)
- **Purpose**: Current version deployed in environment
- **Usage**:
  - Quick environment deployments
  - Always points to latest tested version
  - Development and QA workflows
- **Lifecycle**: Mutable, updated on each deployment

**Examples**:
```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:qa-latest
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:prod-latest
```

#### 4. **Build Timestamp Tag** (Immutable, Audit)
- **Format**: `build-<YYYYMMDD-HHMMSS>` (e.g., `build-20251022-083045`)
- **Purpose**: Build time for audit and debugging
- **Usage**:
  - Troubleshooting build issues
  - Audit trail
  - Build history
- **Lifecycle**: Retained per ECR lifecycle policy (90 days)

**Example**:
```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:build-20251022-083045
```

#### 5. **Branch Tag** (Mutable, Development)
- **Format**: `branch-<branch-name>` (e.g., `branch-feature-auth`)
- **Purpose**: Feature branch testing
- **Usage**:
  - Feature branch deployments
  - PR review environments
  - Integration testing
- **Lifecycle**: Deleted after branch merge/deletion

**Example**:
```
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:branch-feature-auth
```

### Complete Tag Example

A single image build should result in **multiple tags**:

```bash
# Same image, multiple tags
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:git-e48fda1          # Immutable SHA
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.3               # Semantic version
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev                  # Environment
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:build-20251022-083045 # Build time
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:branch-main          # Branch
```

---

## Kubernetes Version Labels

### Deployment Labels

Every Kubernetes deployment should include version metadata as **labels**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservices-dev
  labels:
    app: frontend
    version: v1.2.3                    # Semantic version
    app.version: v1.2.3                # Standard label
    git.commit.sha: e48fda1b           # Git commit (short)
    git.commit.sha.full: e48fda1b6bb73e2827e85fc0c03a0c1c8947a9be  # Full SHA
    build.timestamp: "20251022-083045" # Build time
    deployed.by: github-actions        # Deployment method
    deployed.at: "2025-10-22T08:30:45Z" # Deployment time
    environment: dev                   # Environment name
spec:
  template:
    metadata:
      labels:
        app: frontend
        version: v1.2.3
        git.commit.sha: e48fda1b
```

### Benefits

1. **Observability**:
   ```bash
   # Find all pods running specific version
   kubectl get pods -l version=v1.2.3 -A

   # Find all pods from specific commit
   kubectl get pods -l git.commit.sha=e48fda1b -A
   ```

2. **Istio Traffic Management**:
   ```yaml
   # Route traffic based on version
   apiVersion: networking.istio.io/v1beta1
   kind: VirtualService
   spec:
     http:
     - match:
       - headers:
           x-version:
             exact: v1.2.3
       route:
       - destination:
           host: frontend
           subset: v1.2.3
   ```

3. **Monitoring & Alerting**:
   - Prometheus metrics labeled by version
   - Grafana dashboards showing version distribution
   - Alerts for version mismatches

---

## CI/CD Integration

### GitHub Actions Workflow

The `build-and-push-images.yaml` workflow should implement multi-tag strategy:

```yaml
- name: Build and Push with Multiple Tags
  env:
    COMMIT_SHA: ${{ github.sha }}
    SHORT_SHA: ${{ github.sha | substring(0, 7) }}
    BUILD_TIME: ${{ steps.timestamp.outputs.time }}
    ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
  run: |
    IMAGE_NAME="533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend"

    # Build image once
    docker build -t "${IMAGE_NAME}:build" src/frontend

    # Apply all tags
    docker tag "${IMAGE_NAME}:build" "${IMAGE_NAME}:git-${SHORT_SHA}"
    docker tag "${IMAGE_NAME}:build" "${IMAGE_NAME}:${ENVIRONMENT}"
    docker tag "${IMAGE_NAME}:build" "${IMAGE_NAME}:build-${BUILD_TIME}"

    # Push all tags
    docker push "${IMAGE_NAME}:git-${SHORT_SHA}"
    docker push "${IMAGE_NAME}:${ENVIRONMENT}"
    docker push "${IMAGE_NAME}:build-${BUILD_TIME}"

    # If release tag exists, add semantic version
    if [[ "${GITHUB_REF}" == refs/tags/v* ]]; then
      VERSION="${GITHUB_REF#refs/tags/}"
      docker tag "${IMAGE_NAME}:build" "${IMAGE_NAME}:${VERSION}"
      docker push "${IMAGE_NAME}:${VERSION}"
    fi
```

### Kustomize Integration

Update `kustomization.yaml` to reference immutable tags:

```yaml
# Development: Use mutable 'dev' tag
images:
- name: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
  newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
  newTag: dev  # Points to latest dev build

# Production: Use immutable semantic version
images:
- name: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
  newName: 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend
  newTag: v1.2.3  # Immutable release version
```

---

## Version Tracking Queries

### ECR: Find All Tags for Image

```bash
# List all tags for frontend image
aws ecr describe-images \
  --repository-name frontend \
  --region eu-west-2 \
  --query 'imageDetails[*].[imageTags,imagePushedAt]' \
  --output table

# Find image by commit SHA
aws ecr describe-images \
  --repository-name frontend \
  --region eu-west-2 \
  --image-ids imageTag=git-e48fda1 \
  --query 'imageDetails[0].[imageDigest,imagePushedAt,imageTags]'
```

### Kubernetes: Find Deployed Versions

```bash
# Get all deployed versions across environments
kubectl get deployments -A \
  -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
VERSION:.metadata.labels.version,\
GIT_SHA:.metadata.labels.'git\.commit\.sha',\
DEPLOYED:.metadata.labels.'deployed\.at'

# Find which environment has specific version
kubectl get deployments -A -l version=v1.2.3

# Get version distribution
kubectl get pods -A \
  -o jsonpath='{range .items[*]}{.metadata.labels.version}{"\n"}{end}' | \
  sort | uniq -c
```

### ServiceNow Change Request Tracking

Link version to change request in deployment workflow:

```yaml
- name: Create ServiceNow Change Request
  env:
    VERSION: v1.2.3
    GIT_SHA: e48fda1b
  run: |
    PAYLOAD=$(cat <<EOF
    {
      "short_description": "Deploy ${VERSION} to production",
      "description": "Deploying version ${VERSION} (git SHA: ${GIT_SHA})",
      "u_version": "${VERSION}",
      "u_git_sha": "${GIT_SHA}",
      "u_ecr_image": "533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:${VERSION}"
    }
    EOF
    )
```

---

## Security Scanning Integration

### Scan Specific Versions

```bash
# Scan production version
trivy image 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.3

# Scan by commit SHA
trivy image 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:git-e48fda1

# Scan current dev environment
trivy image 533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev
```

### ECR Vulnerability Scanning

ECR automatically scans images on push. Track vulnerabilities by version:

```bash
# Get scan findings for specific version
aws ecr describe-image-scan-findings \
  --repository-name frontend \
  --image-id imageTag=v1.2.3 \
  --region eu-west-2
```

---

## Rollback Procedures

### Identify Previous Version

```bash
# List last 5 production versions
aws ecr describe-images \
  --repository-name frontend \
  --region eu-west-2 \
  --filter "tagStatus=TAGGED" \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[?contains(imageTags, `v`)]|[:5].[imageTags[0],imagePushedAt]' \
  --output table
```

### Rollback Deployment

```bash
# Rollback to previous version
kubectl set image deployment/frontend \
  frontend=533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.2 \
  -n microservices-prod

# Verify rollback
kubectl rollout status deployment/frontend -n microservices-prod
kubectl get pods -n microservices-prod -l version=v1.2.2
```

---

## Best Practices

### DO ✅

1. **Always use immutable tags for production** (semantic versions, git SHAs)
2. **Apply multiple tags to same image** (don't rebuild for each tag)
3. **Include version labels on all Kubernetes resources**
4. **Link versions to ServiceNow change requests**
5. **Keep audit trail of all deployed versions**
6. **Use git commit SHA for exact traceability**
7. **Automate tagging in CI/CD pipeline**

### DON'T ❌

1. **Don't use mutable tags in production** (like `latest`, `dev`, `prod`)
2. **Don't deploy without version labels**
3. **Don't delete images referenced in audit logs**
4. **Don't skip security scans of deployed versions**
5. **Don't deploy untagged images**
6. **Don't manually tag images** (automate via CI/CD)

---

## Implementation Checklist

- [ ] Update GitHub Actions workflow for multi-tag strategy
- [ ] Add version labels to Kustomize base manifests
- [ ] Create ECR lifecycle policies for tag retention
- [ ] Update ServiceNow integration to include version metadata
- [ ] Configure Istio for version-based routing
- [ ] Set up Prometheus metrics by version
- [ ] Create Grafana dashboard for version tracking
- [ ] Document rollback procedures for operations team
- [ ] Train team on version tracking queries

---

## References

- **ECR Lifecycle Policies**: https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html
- **Semantic Versioning**: https://semver.org/
- **Kubernetes Labels Best Practices**: https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
- **Istio Version-Based Routing**: https://istio.io/latest/docs/concepts/traffic-management/
- **Container Image Immutability**: https://cloud.google.com/architecture/best-practices-for-building-containers#tag_using_semantic_versioning

---

## Recent Implementation Updates (2025-10-27)

### Semantic Versioning Pipeline Fixes

Three critical bugs were fixed in the semantic versioning implementation:

#### Bug #1: Version Parameter Not Passed from Script to Workflow
**Problem**: `scripts/promote-version.sh` captured the version in `$VERSION` variable and updated kustomization files, but wasn't passing the version to the GitHub Actions workflow triggers.

**Fix** (Commit 57192946):
```bash
# Added -f version=$VERSION to workflow triggers
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f force_build_all=true \
  -f version=$VERSION  # ← Added this parameter
```

#### Bug #2: Build Job Referenced Non-Existent Output
**Problem**: The `build-and-push` job in MASTER-PIPELINE.yaml was trying to use `needs.pipeline-init.outputs.version`, but this output doesn't exist. The `pipeline-init` job only outputs: `environment`, `should_deploy`, `is_production`, `policy_ok`, `policy_reason`.

**Fix** (Commit 4daa2012):
```yaml
build-and-push:
  needs: [pipeline-init, detect-service-changes, security-scans, get-deployed-version]  # Added get-deployed-version
  uses: ./.github/workflows/build-images.yaml
  with:
    version: ${{ needs.get-deployed-version.outputs.previous_version }}  # Changed from pipeline-init.outputs.version
```

**Impact**: Before these fixes, images were being tagged with `dev`, `dev-<commit-sha>`, `main` but NOT `v1.2.3`. After fixes, semantic version tags are correctly applied.

#### Bug #3: Circular Dependency in Version Detection
**Problem**: The workflow tried to read the currently deployed version from the cluster to determine what version to build next, creating a circular dependency on first deployment.

**Solution**: Added optional `version` input to `get-deployed-version` job:
```yaml
- name: Get Current Deployed Version
  run: |
    # Use input version if provided, otherwise read from cluster
    if [ -n "${{ github.event.inputs.version }}" ]; then
      VERSION="${{ github.event.inputs.version }}"
      echo "✅ Using provided version: $VERSION"
    else
      # Read from cluster...
    fi
```

**Result**: Manual version input breaks the circular dependency, enabling first-time deployments and version resets.

### Test Execution Quality Gates

#### Test Failures Now Properly Fail Workflows
**Problem**: All test execution steps had `continue-on-error: true`, hiding test failures. Tests could fail but workflows would still pass and deploy.

**Fix** (Commit 19b8ba8d): Removed `continue-on-error: true` from all test steps:
- Go tests (frontend, checkoutservice, productcatalogservice, shippingservice)
- C# tests (cartservice)
- Java tests (adservice)
- Python tests (emailservice, recommendationservice, shoppingassistantservice)

**Impact**: Workflows now FAIL immediately when tests fail. No more hidden problems.

### C# Test Logger Integration

#### JUnit XML Output for .NET Tests
**Problem**: C# tests configured to use `--logger "junit;LogFilePath=test-results.xml"` but .NET doesn't have built-in JUnit logger. Tests failed with: "Could not find a test logger... 'junit'"

**Fix** (Commit 3cd27b2c): Added `JunitXml.TestLogger` NuGet package to `cartservice.tests.csproj`:
```xml
<PackageReference Include="JunitXml.TestLogger" Version="3.1.11" />
```

**Benefit**: C# test results now publishable in JUnit XML format, consistent with other services.

### GitHub Actions Permissions for Reusable Workflows

#### Test Results Publishing
**Problem**: `build-images.yaml` reusable workflow declared `checks: write` permission but the caller workflow (MASTER-PIPELINE.yaml) didn't grant it. Result: "The workflow is requesting 'checks: write', but is only allowed 'checks: none'"

**Fix** (Commit 9b5d12b1): Added permissions block to build-and-push job:
```yaml
build-and-push:
  permissions:
    contents: read
    security-events: write
    id-token: write
    checks: write  # ← Required for test results publishing
  uses: ./.github/workflows/build-images.yaml
```

**Benefit**: Test results can now be published as GitHub Check Runs, visible in PR UI.

### Verification Commands

```bash
# Verify semantic version tags in ECR
aws ecr describe-images \
  --repository-name frontend \
  --region eu-west-2 \
  --query 'imageDetails[?contains(imageTags, `v1.2.3`)]'

# Verify deployment using semantic version
kubectl get deployment frontend -n microservices-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Expected output:
533267307120.dkr.ecr.eu-west-2.amazonaws.com/frontend:v1.2.3

# Check test results in GitHub Actions
gh run view <run-id> --log | grep -A5 "Run.*Tests"
```

---

**Last Updated**: 2025-10-27
**Owner**: DevOps Team
**Review Cycle**: Quarterly
