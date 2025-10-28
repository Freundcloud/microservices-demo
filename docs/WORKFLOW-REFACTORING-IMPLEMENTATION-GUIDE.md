# GitHub Actions Workflows - Refactoring Implementation Guide

> **Guide Version**: 1.0
> **Date**: 2025-01-28
> **Prerequisites**: Review [WORKFLOW-REFACTORING-ANALYSIS.md](WORKFLOW-REFACTORING-ANALYSIS.md) first

---

## Quick Start

This guide provides **step-by-step instructions** to refactor the GitHub Actions workflows following the analysis in `WORKFLOW-REFACTORING-ANALYSIS.md`.

### Phased Approach

We'll implement improvements in **3 phases**:
- **Phase 1** (Week 1): Quick wins - composite actions and caching
- **Phase 2** (Week 2): Environment setup standardization
- **Phase 3** (Week 3-4): Advanced refactoring

---

## Phase 1: Quick Wins (Week 1)

### Task 1.1: Create AWS Credentials Composite Action

**Effort**: 1 hour
**Impact**: Reduces 49 lines across 7 files

#### Step 1: Create directory structure

```bash
mkdir -p .github/actions/setup-aws-credentials
```

#### Step 2: Create the composite action

**File**: `.github/actions/setup-aws-credentials/action.yaml`

```yaml
name: 'Setup AWS Credentials'
description: 'Configure AWS credentials for accessing EKS, ECR, and other AWS services'
author: 'DevOps Team'

inputs:
  aws-region:
    description: 'AWS region to use'
    required: false
    default: 'eu-west-2'

runs:
  using: 'composite'
  steps:
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ inputs.aws-region }}
      shell: bash

    - name: Verify AWS Credentials
      shell: bash
      run: |
        echo "✅ AWS credentials configured for region: ${{ inputs.aws-region }}"
        aws sts get-caller-identity
```

#### Step 3: Update workflows to use the composite action

**Before** (in `terraform-plan.yaml`, `terraform-apply.yaml`, etc.):
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

**After**:
```yaml
- name: Setup AWS Credentials
  uses: ./.github/actions/setup-aws-credentials
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  with:
    aws-region: ${{ env.AWS_REGION }}
```

#### Step 4: Files to update
- [ ] `.github/workflows/terraform-plan.yaml`
- [ ] `.github/workflows/terraform-apply.yaml`
- [ ] `.github/workflows/build-images.yaml`
- [ ] `.github/workflows/deploy-environment.yaml`
- [ ] `.github/workflows/MASTER-PIPELINE.yaml` (2 occurrences)
- [ ] `.github/workflows/aws-infrastructure-discovery.yaml`

#### Step 5: Test the change
```bash
# Trigger a workflow that uses AWS credentials
git add .github/actions/setup-aws-credentials/
git commit -m "feat: Add AWS credentials composite action"
git push origin main

# Monitor workflow run
gh run watch
```

---

### Task 1.2: Create kubectl Configuration Composite Action

**Effort**: 30 minutes
**Impact**: Reduces 12 lines across 4 files

#### Step 1: Create the composite action

**File**: `.github/actions/configure-kubectl/action.yaml`

```yaml
name: 'Configure kubectl'
description: 'Configure kubectl to connect to EKS cluster'
author: 'DevOps Team'

inputs:
  cluster-name:
    description: 'EKS cluster name'
    required: false
    default: 'microservices'
  aws-region:
    description: 'AWS region'
    required: false
    default: 'eu-west-2'
  namespace:
    description: 'Kubernetes namespace to use (optional)'
    required: false
    default: ''

runs:
  using: 'composite'
  steps:
    - name: Update kubeconfig for EKS
      shell: bash
      run: |
        aws eks update-kubeconfig --name ${{ inputs.cluster-name }} --region ${{ inputs.aws-region }}
        echo "✅ kubectl configured for cluster: ${{ inputs.cluster-name }}"

    - name: Set default namespace
      if: inputs.namespace != ''
      shell: bash
      run: |
        kubectl config set-context --current --namespace=${{ inputs.namespace }}
        echo "✅ Default namespace set to: ${{ inputs.namespace }}"

    - name: Verify cluster connection
      shell: bash
      run: |
        kubectl cluster-info
        kubectl get nodes
```

#### Step 2: Update workflows to use the action

**Before**:
```yaml
- name: Configure kubectl
  run: |
    aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}
```

**After**:
```yaml
- name: Configure kubectl
  uses: ./.github/actions/configure-kubectl
  with:
    cluster-name: ${{ env.CLUSTER_NAME }}
    aws-region: ${{ env.AWS_REGION }}
```

#### Step 3: Files to update
- [ ] `.github/workflows/deploy-environment.yaml`
- [ ] `.github/workflows/MASTER-PIPELINE.yaml` (3 occurrences)

---

### Task 1.3: Add npm Dependency Caching

**Effort**: 30 minutes
**Impact**: 40-60% faster builds for Node.js services

#### Step 1: Create npm caching composite action (optional)

**File**: `.github/actions/setup-node-with-cache/action.yaml`

```yaml
name: 'Setup Node.js with Cache'
description: 'Setup Node.js environment with npm dependency caching'
author: 'DevOps Team'

inputs:
  node-version:
    description: 'Node.js version to use'
    required: false
    default: '22'

runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
        cache-dependency-path: '**/package-lock.json'

    - name: Cache npm dependencies
      uses: actions/cache@v4
      with:
        path: ~/.npm
        key: ${{ runner.os }}-node-${{ inputs.node-version }}-${{ hashFiles('**/package-lock.json') }}
        restore-keys: |
          ${{ runner.os }}-node-${{ inputs.node-version }}-
          ${{ runner.os }}-node-

    - name: Verify Node.js setup
      shell: bash
      run: |
        echo "✅ Node.js version: $(node --version)"
        echo "✅ npm version: $(npm --version)"
```

#### Step 2: Update workflows to use caching

**File**: `.github/workflows/build-images.yaml` (paymentservice, currencyservice builds)

**Before**:
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '22'

- name: Install dependencies
  run: npm ci
```

**After**:
```yaml
- name: Setup Node.js with Cache
  uses: ./.github/actions/setup-node-with-cache
  with:
    node-version: '22'

- name: Install dependencies
  run: npm ci
```

#### Step 3: Files to update
- [ ] `.github/workflows/build-images.yaml` (paymentservice, currencyservice)
- [ ] `.github/workflows/security-scan.yaml` (OWASP Dependency Check)
- [ ] `.github/workflows/run-unit-tests.yaml` (Node.js tests)

---

### Task 1.4: Add Maven/Gradle Dependency Caching

**Effort**: 1 hour
**Impact**: 40-60% faster builds for Java services

#### Step 1: Create Java caching composite action

**File**: `.github/actions/setup-java-with-cache/action.yaml`

```yaml
name: 'Setup Java with Cache'
description: 'Setup Java environment with Maven and Gradle dependency caching'
author: 'DevOps Team'

inputs:
  java-version:
    description: 'Java version to use'
    required: false
    default: '21'
  distribution:
    description: 'Java distribution'
    required: false
    default: 'temurin'
  build-tool:
    description: 'Build tool to cache (maven, gradle, or both)'
    required: false
    default: 'both'

runs:
  using: 'composite'
  steps:
    - name: Setup Java
      uses: actions/setup-java@v4
      with:
        distribution: ${{ inputs.distribution }}
        java-version: ${{ inputs.java-version }}

    - name: Cache Maven dependencies
      if: inputs.build-tool == 'maven' || inputs.build-tool == 'both'
      uses: actions/cache@v4
      with:
        path: ~/.m2/repository
        key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
        restore-keys: |
          ${{ runner.os }}-maven-

    - name: Cache Gradle dependencies
      if: inputs.build-tool == 'gradle' || inputs.build-tool == 'both'
      uses: actions/cache@v4
      with:
        path: |
          ~/.gradle/caches
          ~/.gradle/wrapper
        key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
        restore-keys: |
          ${{ runner.os }}-gradle-

    - name: Verify Java setup
      shell: bash
      run: |
        echo "✅ Java version: $(java -version 2>&1 | head -n 1)"
```

#### Step 2: Update workflows

**File**: `.github/workflows/build-images.yaml` (adservice build)

**Before**:
```yaml
- name: Setup Java 21
  uses: actions/setup-java@v4
  with:
    distribution: 'temurin'
    java-version: '21'

- name: Build adservice
  run: |
    cd src/adservice
    ./gradlew build -x test
```

**After**:
```yaml
- name: Setup Java with Cache
  uses: ./.github/actions/setup-java-with-cache
  with:
    java-version: '21'
    build-tool: 'gradle'

- name: Build adservice
  run: |
    cd src/adservice
    ./gradlew build -x test
```

#### Step 3: Files to update
- [ ] `.github/workflows/build-images.yaml` (adservice, shoppingassistantservice)
- [ ] `.github/workflows/security-scan.yaml` (CodeQL Java build)
- [ ] `.github/workflows/run-unit-tests.yaml` (Java tests)

---

### Task 1.5: Consolidate Service List Definition

**Effort**: 1 hour
**Impact**: Single source of truth for 12 microservices

#### Step 1: Create central service definition

**File**: `scripts/service-list.json`

```json
{
  "services": [
    {
      "name": "emailservice",
      "path": "src/emailservice",
      "language": "python",
      "buildTool": "pip",
      "port": 8080
    },
    {
      "name": "productcatalogservice",
      "path": "src/productcatalogservice",
      "language": "go",
      "buildTool": "go",
      "port": 3550
    },
    {
      "name": "recommendationservice",
      "path": "src/recommendationservice",
      "language": "python",
      "buildTool": "pip",
      "port": 8080
    },
    {
      "name": "shippingservice",
      "path": "src/shippingservice",
      "language": "go",
      "buildTool": "go",
      "port": 50051
    },
    {
      "name": "checkoutservice",
      "path": "src/checkoutservice",
      "language": "go",
      "buildTool": "go",
      "port": 5050
    },
    {
      "name": "paymentservice",
      "path": "src/paymentservice",
      "language": "nodejs",
      "buildTool": "npm",
      "port": 50051
    },
    {
      "name": "currencyservice",
      "path": "src/currencyservice",
      "language": "nodejs",
      "buildTool": "npm",
      "port": 7000
    },
    {
      "name": "cartservice",
      "path": "src/cartservice",
      "language": "csharp",
      "buildTool": "dotnet",
      "port": 7070
    },
    {
      "name": "frontend",
      "path": "src/frontend",
      "language": "go",
      "buildTool": "go",
      "port": 8080
    },
    {
      "name": "adservice",
      "path": "src/adservice",
      "language": "java",
      "buildTool": "gradle",
      "port": 9555
    },
    {
      "name": "loadgenerator",
      "path": "src/loadgenerator",
      "language": "python",
      "buildTool": "pip",
      "port": 8089
    },
    {
      "name": "shoppingassistantservice",
      "path": "src/shoppingassistantservice",
      "language": "java",
      "buildTool": "gradle",
      "port": 8080
    }
  ]
}
```

#### Step 2: Create helper script to extract service names

**File**: `scripts/get-service-list.sh`

```bash
#!/bin/bash
set -euo pipefail

# Extract service names as JSON array for GitHub Actions
jq -r '.services[].name' scripts/service-list.json | jq -R -s -c 'split("\n")[:-1]'
```

```bash
chmod +x scripts/get-service-list.sh
```

#### Step 3: Update workflows to use central definition

**File**: `.github/workflows/build-images.yaml`

**Before**:
```yaml
- name: Set Build Matrix
  run: |
    echo 'matrix=["emailservice","productcatalogservice",...]' >> $GITHUB_OUTPUT
```

**After**:
```yaml
- name: Set Build Matrix
  run: |
    chmod +x scripts/get-service-list.sh
    SERVICES=$(./scripts/get-service-list.sh)
    echo "matrix=$SERVICES" >> $GITHUB_OUTPUT
```

#### Step 4: Files to update
- [ ] `.github/workflows/build-images.yaml` (matrix generation)
- [ ] `.github/workflows/build-images.yaml` (paths-filter section - can be generated from JSON)
- [ ] Update documentation to reference `scripts/service-list.json`

---

## Phase 2: Environment Setup (Week 2)

### Task 2.1: Create Terraform Setup Composite Action

**Effort**: 30 minutes

**File**: `.github/actions/setup-terraform/action.yaml`

```yaml
name: 'Setup Terraform'
description: 'Setup Terraform with specified version'
author: 'DevOps Team'

inputs:
  terraform-version:
    description: 'Terraform version to install'
    required: false
    default: '1.6.0'

runs:
  using: 'composite'
  steps:
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ inputs.terraform-version }}

    - name: Verify Terraform installation
      shell: bash
      run: |
        terraform version
        echo "✅ Terraform ${{ inputs.terraform-version }} installed"
```

**Files to update**:
- [ ] `.github/workflows/terraform-plan.yaml`
- [ ] `.github/workflows/terraform-apply.yaml`
- [ ] `.github/workflows/aws-infrastructure-discovery.yaml`

---

### Task 2.2: Create SARIF URI Fixing Composite Action

**Effort**: 30 minutes

**File**: `.github/actions/fix-sarif-uris/action.yaml`

```yaml
name: 'Fix SARIF URI Schemes'
description: 'Fix git:// URIs in SARIF files to file:// for GitHub Code Scanning compatibility'
author: 'DevOps Team'

inputs:
  sarif-file:
    description: 'Path to SARIF file to fix'
    required: true

runs:
  using: 'composite'
  steps:
    - name: Fix SARIF URI schemes
      shell: bash
      run: |
        if [ -f "${{ inputs.sarif-file }}" ]; then
          echo "🔧 Fixing URI schemes in ${{ inputs.sarif-file }}"
          chmod +x scripts/fix-sarif-uris.sh
          ./scripts/fix-sarif-uris.sh "${{ inputs.sarif-file }}"
          echo "✅ SARIF file fixed successfully"
        else
          echo "⚠️ SARIF file not found: ${{ inputs.sarif-file }}"
          exit 1
        fi
```

**Usage**:
```yaml
- name: Fix SARIF URIs
  uses: ./.github/actions/fix-sarif-uris
  with:
    sarif-file: results.sarif
```

**Files to update**:
- [ ] `.github/workflows/security-scan.yaml` (Grype, OWASP, Semgrep)

---

### Task 2.3: Create ServiceNow Authentication Composite Action

**Effort**: 2 hours

**File**: `.github/actions/servicenow-auth/action.yaml`

```yaml
name: 'ServiceNow Authentication'
description: 'Setup ServiceNow authentication environment variables'
author: 'DevOps Team'

inputs:
  mode:
    description: 'Authentication mode (env or export)'
    required: false
    default: 'env'

outputs:
  instance-url:
    description: 'ServiceNow instance URL'
    value: ${{ env.SERVICENOW_INSTANCE_URL }}

runs:
  using: 'composite'
  steps:
    - name: Verify ServiceNow Credentials
      shell: bash
      run: |
        if [ -z "$SERVICENOW_USERNAME" ] || [ -z "$SERVICENOW_PASSWORD" ]; then
          echo "❌ ServiceNow credentials not found in environment"
          echo "Required: SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL"
          exit 1
        fi
        echo "✅ ServiceNow credentials verified"
        echo "Instance: $SERVICENOW_INSTANCE_URL"
        echo "User: $SERVICENOW_USERNAME"

    - name: Test ServiceNow API Connection
      shell: bash
      run: |
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
          -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
          "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1")

        if [ "$HTTP_CODE" == "200" ]; then
          echo "✅ ServiceNow API connection successful"
        else
          echo "❌ ServiceNow API connection failed (HTTP $HTTP_CODE)"
          exit 1
        fi
```

**Usage**:
```yaml
- name: Setup ServiceNow Authentication
  uses: ./.github/actions/servicenow-auth
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
```

---

## Phase 3: Advanced Refactoring (Week 3-4)

### Task 3.1: Implement Matrix Strategy for Service Builds

**Effort**: 3 hours
**Complexity**: Medium

#### Current approach (sequential):
```yaml
- name: Build emailservice
  run: docker build -t emailservice src/emailservice

- name: Build productcatalogservice
  run: docker build -t productcatalogservice src/productcatalogservice

# ... 10 more services (total 12)
```

#### New approach (parallel matrix):

**File**: `.github/workflows/build-images.yaml`

```yaml
build-and-push:
  name: Build ${{ matrix.service }}
  runs-on: ubuntu-latest
  if: needs.detect-changes.outputs.has_services == 'true'
  needs: detect-changes

  strategy:
    fail-fast: false
    matrix:
      service: ${{ fromJson(needs.detect-changes.outputs.matrix) }}

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Setup AWS Credentials
      uses: ./.github/actions/setup-aws-credentials
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

    - name: Login to Amazon ECR
      uses: aws-actions/amazon-ecr-login@v2

    - name: Get Service Metadata
      id: metadata
      run: |
        SERVICE='${{ matrix.service }}'
        LANGUAGE=$(jq -r --arg name "$SERVICE" '.services[] | select(.name == $name) | .language' scripts/service-list.json)
        BUILD_TOOL=$(jq -r --arg name "$SERVICE" '.services[] | select(.name == $name) | .buildTool' scripts/service-list.json)

        echo "language=$LANGUAGE" >> $GITHUB_OUTPUT
        echo "build_tool=$BUILD_TOOL" >> $GITHUB_OUTPUT

    - name: Setup Language Environment
      if: steps.metadata.outputs.language == 'nodejs'
      uses: ./.github/actions/setup-node-with-cache

    - name: Setup Language Environment
      if: steps.metadata.outputs.language == 'java'
      uses: ./.github/actions/setup-java-with-cache
      with:
        build-tool: ${{ steps.metadata.outputs.build_tool }}

    - name: Build and Push Image
      run: |
        SERVICE='${{ matrix.service }}'
        TAG='${{ needs.detect-changes.outputs.tag }}'

        docker build -t $ECR_REGISTRY/$SERVICE:$TAG src/$SERVICE
        docker push $ECR_REGISTRY/$SERVICE:$TAG
```

**Benefits**:
- 12 services build in parallel (on separate runners)
- ~75% reduction in total build time
- Cleaner workflow definition
- Easy to add new services

---

### Task 3.2: Refactor aws-infrastructure-discovery.yaml

**Effort**: 8 hours
**Complexity**: High

**Current size**: 1,140 lines (single monolithic file)

**Proposed structure**:
```
.github/
├── actions/
│   └── register-servicenow-ci/
│       └── action.yaml                  # Composite action for CI registration
├── workflows/
│   ├── discover-eks.yaml                # ~150 lines
│   ├── discover-vpc.yaml                # ~150 lines
│   ├── discover-elasticache.yaml        # ~150 lines
│   ├── discover-ecr.yaml                # ~100 lines
│   ├── discover-iam.yaml                # ~100 lines
│   └── aws-infrastructure-discovery.yaml # ~100 lines (orchestrator)
```

#### Step 1: Create ServiceNow CI Registration Composite Action

**File**: `.github/actions/register-servicenow-ci/action.yaml`

```yaml
name: 'Register CI in ServiceNow CMDB'
description: 'Register a Configuration Item in ServiceNow CMDB'
author: 'DevOps Team'

inputs:
  ci-type:
    description: 'CI type (eks_cluster, vpc, elasticache_cluster, etc.)'
    required: true
  ci-name:
    description: 'CI name'
    required: true
  ci-data:
    description: 'CI data as JSON object'
    required: true
  table-name:
    description: 'ServiceNow table name (e.g., u_eks_cluster)'
    required: true

outputs:
  sys-id:
    description: 'ServiceNow sys_id of created/updated CI'
    value: ${{ steps.register.outputs.sys_id }}

runs:
  using: 'composite'
  steps:
    - name: Register CI in ServiceNow
      id: register
      shell: bash
      run: |
        echo "📝 Registering ${{ inputs.ci-type }}: ${{ inputs.ci-name }}"

        # Call ServiceNow REST API
        RESPONSE=$(curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
          -H "Content-Type: application/json" \
          -H "Accept: application/json" \
          -X POST \
          "$SERVICENOW_INSTANCE_URL/api/now/table/${{ inputs.table-name }}" \
          -d '${{ inputs.ci-data }}')

        SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')

        if [ "$SYS_ID" != "null" ] && [ -n "$SYS_ID" ]; then
          echo "✅ CI registered successfully (sys_id: $SYS_ID)"
          echo "sys_id=$SYS_ID" >> $GITHUB_OUTPUT
        else
          echo "❌ Failed to register CI"
          echo "Response: $RESPONSE"
          exit 1
        fi
```

#### Step 2: Create modular discovery workflows

**File**: `.github/workflows/discover-eks.yaml`

```yaml
name: "Discover EKS Clusters (Reusable)"

on:
  workflow_call:
    inputs:
      aws-region:
        required: false
        type: string
        default: 'eu-west-2'
    outputs:
      clusters-found:
        description: "Number of EKS clusters discovered"
        value: ${{ jobs.discover-eks.outputs.count }}

jobs:
  discover-eks:
    name: Discover EKS Clusters
    runs-on: ubuntu-latest
    outputs:
      count: ${{ steps.discover.outputs.count }}

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup AWS Credentials
        uses: ./.github/actions/setup-aws-credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        with:
          aws-region: ${{ inputs.aws-region }}

      - name: Setup ServiceNow Auth
        uses: ./.github/actions/servicenow-auth
        env:
          SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
          SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
          SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}

      - name: Discover EKS Clusters
        id: discover
        run: |
          # Discover clusters
          CLUSTERS=$(aws eks list-clusters --region ${{ inputs.aws-region }} --output json)
          COUNT=$(echo "$CLUSTERS" | jq '.clusters | length')

          echo "count=$COUNT" >> $GITHUB_OUTPUT
          echo "clusters=$CLUSTERS" >> $GITHUB_OUTPUT

      - name: Register Clusters in ServiceNow
        if: steps.discover.outputs.count > 0
        run: |
          CLUSTERS='${{ steps.discover.outputs.clusters }}'

          for CLUSTER in $(echo "$CLUSTERS" | jq -r '.clusters[]'); do
            # Get cluster details
            CLUSTER_INFO=$(aws eks describe-cluster --name "$CLUSTER" --region ${{ inputs.aws-region }})

            # Prepare CI data
            CI_DATA=$(echo "$CLUSTER_INFO" | jq '{
              name: .cluster.name,
              u_arn: .cluster.arn,
              u_region: "${{ inputs.aws-region }}",
              u_version: .cluster.version,
              u_status: .cluster.status,
              u_endpoint: .cluster.endpoint
            }')

            # Register in ServiceNow using composite action
            echo "CI_DATA=$CI_DATA" > /tmp/ci_data.json
          done

      - name: Register Each Cluster
        if: steps.discover.outputs.count > 0
        uses: ./.github/actions/register-servicenow-ci
        with:
          ci-type: 'EKS Cluster'
          ci-name: ${{ steps.discover.outputs.cluster_name }}
          ci-data: ${{ steps.register-prep.outputs.ci_data }}
          table-name: 'u_eks_cluster'
```

#### Step 3: Create orchestrator workflow

**File**: `.github/workflows/aws-infrastructure-discovery.yaml` (new, smaller version)

```yaml
name: "🔍 AWS Infrastructure Discovery & ServiceNow Sync"

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:

jobs:
  discover-eks:
    uses: ./.github/workflows/discover-eks.yaml
    secrets: inherit

  discover-vpc:
    uses: ./.github/workflows/discover-vpc.yaml
    secrets: inherit

  discover-elasticache:
    uses: ./.github/workflows/discover-elasticache.yaml
    secrets: inherit

  discover-ecr:
    uses: ./.github/workflows/discover-ecr.yaml
    secrets: inherit

  discover-iam:
    uses: ./.github/workflows/discover-iam.yaml
    secrets: inherit

  summary:
    name: Discovery Summary
    needs: [discover-eks, discover-vpc, discover-elasticache, discover-ecr, discover-iam]
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Generate Summary
        run: |
          echo "### 🔍 Infrastructure Discovery Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Resource Type | Count |" >> $GITHUB_STEP_SUMMARY
          echo "|---------------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| EKS Clusters | ${{ needs.discover-eks.outputs.clusters-found }} |" >> $GITHUB_STEP_SUMMARY
          echo "| VPCs | ${{ needs.discover-vpc.outputs.vpcs-found }} |" >> $GITHUB_STEP_SUMMARY
          echo "| ElastiCache | ${{ needs.discover-elasticache.outputs.clusters-found }} |" >> $GITHUB_STEP_SUMMARY
          echo "| ECR Repos | ${{ needs.discover-ecr.outputs.repos-found }} |" >> $GITHUB_STEP_SUMMARY
          echo "| IAM Roles | ${{ needs.discover-iam.outputs.roles-found }} |" >> $GITHUB_STEP_SUMMARY
```

**Benefits**:
- Reduces main file from 1,140 lines to ~100 lines
- Each discovery type in separate, focused workflow (~150 lines each)
- Easier to maintain and debug
- Can run discovery types independently
- Parallel execution of discovery workflows

---

## Testing Strategy

### After each task:

1. **Syntax validation**:
   ```bash
   # Validate workflow syntax
   yamllint .github/workflows/*.yaml
   yamllint .github/actions/**/*.yaml
   ```

2. **Test locally with act** (if possible):
   ```bash
   # Install act
   brew install act  # macOS

   # Test workflow locally
   act -W .github/workflows/build-images.yaml
   ```

3. **Commit and test in CI**:
   ```bash
   git add .github/
   git commit -m "refactor: Add AWS credentials composite action"
   git push origin main

   # Monitor workflow run
   gh run watch
   ```

4. **Rollback if issues**:
   ```bash
   git revert HEAD
   git push origin main
   ```

---

## Measuring Success

### Before refactoring (baseline):

```bash
# Measure workflow execution times
gh run list --workflow="Build and Push Docker Images" --limit 10 \
  --json conclusion,createdAt,updatedAt \
  --jq '.[] | select(.conclusion=="success") | (.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)'
```

### After refactoring (compare):

Track improvements in:
- **Build time reduction**: Expected 40-60% with caching
- **Lines of code**: Expected 25-30% reduction
- **Maintainability**: Easier to understand and modify
- **Onboarding**: Faster for new developers to contribute

---

## Rollout Plan

### Week 1 - Phase 1: Quick Wins
- **Day 1**: Create AWS credentials composite action
- **Day 2**: Create kubectl composite action + Add npm caching
- **Day 3**: Add Maven/Gradle caching
- **Day 4**: Consolidate service list definition
- **Day 5**: Test all changes, measure improvements

### Week 2 - Phase 2: Environment Setup
- **Day 1**: Create Terraform setup composite action
- **Day 2**: Create SARIF fixing composite action
- **Day 3**: Create ServiceNow auth composite action
- **Day 4-5**: Update all workflows to use new actions

### Week 3-4 - Phase 3: Advanced Refactoring
- **Week 3**: Implement matrix strategy for service builds
- **Week 4**: Refactor aws-infrastructure-discovery.yaml into modular workflows

---

## Troubleshooting

### Issue: Composite action not found

**Error**: `Unable to resolve action ./.github/actions/my-action`

**Solution**: Ensure you've checked out code first:
```yaml
- name: Checkout Code
  uses: actions/checkout@v4

- name: Use composite action
  uses: ./.github/actions/my-action
```

---

### Issue: Secrets not accessible in composite action

**Error**: Composite actions cannot access `${{ secrets.MY_SECRET }}`

**Solution**: Pass secrets via environment variables:
```yaml
- name: Use composite action
  uses: ./.github/actions/my-action
  env:
    MY_SECRET: ${{ secrets.MY_SECRET }}
```

---

### Issue: Cache not being used

**Error**: Cache miss on every run

**Solution**: Verify cache key uses correct hash:
```yaml
key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

Check that `package-lock.json` path is correct relative to workspace root.

---

## Reference Documentation

- [GitHub Actions: Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [GitHub Actions: Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [GitHub Actions: Caching Dependencies](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [GitHub Actions: Matrix Strategy](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)

---

## Summary Checklist

### Phase 1 (Week 1):
- [ ] AWS credentials composite action created and tested
- [ ] kubectl configuration composite action created and tested
- [ ] npm dependency caching added
- [ ] Maven/Gradle dependency caching added
- [ ] Service list consolidated to `scripts/service-list.json`
- [ ] All workflows updated to use new actions
- [ ] Build time improvements measured and documented

### Phase 2 (Week 2):
- [ ] Terraform setup composite action created
- [ ] SARIF fixing composite action created
- [ ] ServiceNow auth composite action created
- [ ] All workflows updated to use environment setup actions

### Phase 3 (Week 3-4):
- [ ] Matrix strategy implemented for service builds
- [ ] aws-infrastructure-discovery.yaml split into modular workflows
- [ ] ServiceNow CI registration composite action created
- [ ] All discovery workflows tested and verified
- [ ] Documentation updated

---

**Generated**: 2025-01-28
**Next Review**: After Phase 1 completion
**Owner**: DevOps Team
