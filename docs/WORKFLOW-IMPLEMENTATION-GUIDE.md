# Master Pipeline Implementation Guide

## 🎯 Goal
Build a unified CI/CD pipeline that replaces 22 workflows with 1 master workflow + 6 reusable components.

---

## 📋 Implementation Checklist

### Phase 1: Setup (15 minutes)
- [ ] Create `.github/workflows/_reusable/` directory
- [ ] Move `security-scan.yaml` to `_reusable/security-scan.yaml`
- [ ] Update references in other workflows (if any)
- [ ] Test security-scan as reusable workflow

### Phase 2: Build Reusable Workflows (2-3 hours)
- [ ] Create `_reusable/terraform-plan.yaml`
- [ ] Create `_reusable/terraform-apply.yaml`
- [ ] Create `_reusable/build-images.yaml`
- [ ] Create `_reusable/deploy-environment.yaml`
- [ ] Create `_reusable/servicenow-integration.yaml`

### Phase 3: Create Master Pipeline (2-3 hours)
- [ ] Create `MASTER-PIPELINE.yaml` skeleton
- [ ] Add Stage 1: Code quality & security
- [ ] Add Stage 2: Infrastructure (Terraform)
- [ ] Add Stage 3: Build Docker images
- [ ] Add Stage 4: ServiceNow change management
- [ ] Add Stage 5: Deployment
- [ ] Add Stage 6: Post-deployment verification

### Phase 4: Testing (1-2 hours)
- [ ] Test master pipeline in dev environment
- [ ] Validate all stages execute correctly
- [ ] Verify ServiceNow integration works
- [ ] Check security tools registration

### Phase 5: Cleanup (1 hour)
- [ ] Create `DEPRECATED/` directory
- [ ] Move old workflows to DEPRECATED
- [ ] Update documentation
- [ ] Announce to team

---

## 🚀 Quick Start: Build POC (30 minutes)

Let's start with a minimal proof-of-concept that combines build + security + deploy.

### Step 1: Create Reusable Directory
```bash
mkdir -p .github/workflows/_reusable
```

### Step 2: Move Security Scan Workflow
```bash
git mv .github/workflows/security-scan.yaml .github/workflows/_reusable/security-scan.yaml
git commit -m "refactor: Move security-scan to reusable workflows"
```

### Step 3: Create Minimal Master Pipeline

Create `.github/workflows/MASTER-PIPELINE.yaml`:

```yaml
name: "Master CI/CD Pipeline (POC)"

on:
  push:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, qa, prod]
        default: dev

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices

jobs:
  # Stage 1: Security Scans
  security-scans:
    name: "Security Scans"
    uses: ./.github/workflows/_reusable/security-scan.yaml
    secrets: inherit

  # Stage 2: Deploy to Environment (Simplified)
  deploy:
    name: "Deploy to ${{ inputs.environment || 'dev' }}"
    runs-on: ubuntu-latest
    needs: security-scans
    if: always() # Run even if security has warnings

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy with Kustomize
        run: |
          ENV=${{ inputs.environment || 'dev' }}
          kubectl apply -k kustomize/overlays/$ENV

      - name: Wait for rollout
        run: |
          ENV=${{ inputs.environment || 'dev' }}
          kubectl wait --for=condition=available --timeout=600s \
            deployment --all -n microservices-$ENV

      - name: Summary
        run: |
          ENV=${{ inputs.environment || 'dev' }}
          echo "## Deployment Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Environment**: $ENV" >> $GITHUB_STEP_SUMMARY
          echo "**Namespace**: microservices-$ENV" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Deployed Pods" >> $GITHUB_STEP_SUMMARY
          kubectl get pods -n microservices-$ENV >> $GITHUB_STEP_SUMMARY
```

### Step 4: Test POC
```bash
# Commit the POC
git add .github/workflows/MASTER-PIPELINE.yaml
git commit -m "feat: Add Master Pipeline POC (security + deploy)"
git push

# Trigger manually
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Or wait for automatic trigger on next commit
```

### Step 5: Verify POC Works
```bash
# Monitor the run
gh run watch --repo Freundcloud/microservices-demo

# Check if deployment succeeded
kubectl get pods -n microservices-dev
```

---

## 📚 Detailed Implementation: Reusable Workflows

### 1. _reusable/build-images.yaml

```yaml
name: Build Docker Images (Reusable)

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        description: 'Target environment (dev/qa/prod)'
      services:
        required: false
        type: string
        default: '[]'
        description: 'JSON array of services to build (empty = build all)'

jobs:
  detect-changes:
    name: Detect Changed Services
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.filter.outputs.changes }}
    steps:
      - uses: actions/checkout@v4

      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend: 'src/frontend/**'
            cartservice: 'src/cartservice/**'
            productcatalogservice: 'src/productcatalogservice/**'
            currencyservice: 'src/currencyservice/**'
            paymentservice: 'src/paymentservice/**'
            shippingservice: 'src/shippingservice/**'
            emailservice: 'src/emailservice/**'
            checkoutservice: 'src/checkoutservice/**'
            recommendationservice: 'src/recommendationservice/**'
            adservice: 'src/adservice/**'
            loadgenerator: 'src/loadgenerator/**'

  build:
    name: Build ${{ matrix.service }}
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.services != '[]'
    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJSON(needs.detect-changes.outputs.services) }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION || 'eu-west-2' }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ matrix.service }}
          IMAGE_TAG: ${{ inputs.environment }}-${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG src/${{ matrix.service }}
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:${{ inputs.environment }}
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:${{ inputs.environment }}

      - name: Summary
        run: |
          echo "Built ${{ matrix.service }}:${{ inputs.environment }}-${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
```

### 2. _reusable/terraform-plan.yaml

```yaml
name: Terraform Plan (Reusable)

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        description: 'Environment: dev, qa, or prod'
    outputs:
      has_changes:
        description: 'Whether Terraform has changes'
        value: ${{ jobs.plan.outputs.has_changes }}

jobs:
  plan:
    name: Plan Infrastructure Changes
    runs-on: ubuntu-latest
    outputs:
      has_changes: ${{ steps.plan.outputs.has_changes }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION || 'eu-west-2' }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Terraform Init
        run: |
          cd terraform-aws
          terraform init -upgrade

      - name: Terraform Validate
        run: |
          cd terraform-aws
          terraform validate

      - name: Terraform Plan
        id: plan
        run: |
          cd terraform-aws
          terraform plan -var-file=environments/${{ inputs.environment }}.tfvars -out=tfplan

          # Check if there are changes
          terraform show -json tfplan | jq -r '.resource_changes[]' > /tmp/changes.json
          if [ -s /tmp/changes.json ]; then
            echo "has_changes=true" >> $GITHUB_OUTPUT
          else
            echo "has_changes=false" >> $GITHUB_OUTPUT
          fi

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan-${{ inputs.environment }}
          path: terraform-aws/tfplan

      - name: Summary
        run: |
          echo "## Terraform Plan (${{ inputs.environment }})" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          cd terraform-aws
          terraform show -no-color tfplan >> $GITHUB_STEP_SUMMARY
```

### 3. _reusable/deploy-environment.yaml

```yaml
name: Deploy to Environment (Reusable)

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        description: 'Target environment (dev/qa/prod)'
      change_request_sys_id:
        required: false
        type: string
        description: 'ServiceNow change request sys_id'

jobs:
  deploy:
    name: Deploy to ${{ inputs.environment }}
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION || 'eu-west-2' }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name microservices --region eu-west-2

      - name: Deploy with Kustomize
        run: |
          kubectl apply -k kustomize/overlays/${{ inputs.environment }}

      - name: Wait for rollout completion
        run: |
          kubectl wait --for=condition=available --timeout=600s \
            deployment --all -n microservices-${{ inputs.environment }}

      - name: Verify deployment
        run: |
          echo "## Deployment Status" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Environment**: ${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "**Namespace**: microservices-${{ inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          echo "### Pods" >> $GITHUB_STEP_SUMMARY
          kubectl get pods -n microservices-${{ inputs.environment }} >> $GITHUB_STEP_SUMMARY

          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Services" >> $GITHUB_STEP_SUMMARY
          kubectl get svc -n microservices-${{ inputs.environment }} >> $GITHUB_STEP_SUMMARY
```

---

## 🎨 Full Master Pipeline (Complete Version)

Once reusable workflows are created, update `MASTER-PIPELINE.yaml`:

```yaml
name: "Master CI/CD Pipeline"

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, qa, prod]
        default: dev
      skip_terraform:
        description: 'Skip infrastructure changes'
        type: boolean
        default: false
      skip_security:
        description: 'Skip security scans (NOT recommended)'
        type: boolean
        default: false

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices

jobs:
  # ============================================================================
  # STAGE 1: CODE QUALITY & SECURITY
  # ============================================================================

  security-scans:
    name: "Security Scans"
    uses: ./.github/workflows/_reusable/security-scan.yaml
    secrets: inherit
    if: ${{ !inputs.skip_security }}

  # ============================================================================
  # STAGE 2: INFRASTRUCTURE (Conditional)
  # ============================================================================

  detect-terraform-changes:
    name: "Detect Infrastructure Changes"
    runs-on: ubuntu-latest
    outputs:
      terraform_changed: ${{ steps.filter.outputs.terraform }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            terraform: 'terraform-aws/**'

  terraform-plan:
    name: "Terraform Plan"
    needs: detect-terraform-changes
    if: |
      needs.detect-terraform-changes.outputs.terraform_changed == 'true' &&
      !inputs.skip_terraform
    uses: ./.github/workflows/_reusable/terraform-plan.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}

  # ============================================================================
  # STAGE 3: BUILD DOCKER IMAGES (Conditional)
  # ============================================================================

  build-images:
    name: "Build Docker Images"
    needs: security-scans
    if: always() && !cancelled()
    uses: ./.github/workflows/_reusable/build-images.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}

  # ============================================================================
  # STAGE 4: SERVICENOW CHANGE MANAGEMENT
  # ============================================================================

  create-change-request:
    name: "Create ServiceNow Change"
    needs: [security-scans, build-images]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    outputs:
      change_request_sys_id: ${{ steps.create.outputs.change_request_sys_id }}

    steps:
      - uses: actions/checkout@v4

      - name: Create Change Request
        id: create
        uses: ServiceNow/servicenow-devops-change@v6.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Create Change Request'
          change-request: |
            {
              "changeModel": {"sys_id": "e55d0bfec343101035ae3f52c1d3ae49"},
              "setCloseCode": "true",
              "autoCloseChange": true,
              "attributes": {
                "short_description": "Deploy to ${{ inputs.environment || 'dev' }}",
                "description": "Automated deployment via Master Pipeline"
              }
            }
          interval: '30'
          timeout: '3600'

  # ============================================================================
  # STAGE 5: DEPLOYMENT
  # ============================================================================

  deploy:
    name: "Deploy to ${{ inputs.environment || 'dev' }}"
    needs: [create-change-request, build-images]
    if: always() && !cancelled()
    uses: ./.github/workflows/_reusable/deploy-environment.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}
      change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}

  # ============================================================================
  # STAGE 6: POST-DEPLOYMENT VERIFICATION
  # ============================================================================

  smoke-tests:
    name: "Smoke Tests"
    needs: deploy
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS & kubectl
        run: |
          aws eks update-kubeconfig --name microservices --region eu-west-2

      - name: Check pod health
        run: |
          ENV=${{ inputs.environment || 'dev' }}
          kubectl get pods -n microservices-$ENV
          kubectl wait --for=condition=ready pods --all \
            -n microservices-$ENV --timeout=300s

      - name: Test frontend endpoint
        run: |
          FRONTEND_URL=$(kubectl get svc -n istio-system istio-ingressgateway \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          curl -f -m 10 http://$FRONTEND_URL/ || exit 1
```

---

## 🧪 Testing Strategy

### Test Each Stage Individually
```bash
# Test security scans
gh workflow run _reusable/security-scan.yaml

# Test build images
gh workflow run _reusable/build-images.yaml -f environment=dev

# Test deployment
gh workflow run _reusable/deploy-environment.yaml -f environment=dev
```

### Test Full Pipeline
```bash
# Dev deployment
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# QA deployment (manual trigger)
gh workflow run MASTER-PIPELINE.yaml -f environment=qa

# With options
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f skip_terraform=true \
  -f skip_security=false
```

---

## 📊 Success Metrics

Track these to measure improvement:

1. **Execution Time**
   - Before: ~45 minutes (sequential)
   - Target: ~25 minutes (parallel)

2. **Developer Actions**
   - Before: 6 manual workflow runs
   - Target: 1 automatic trigger

3. **Code Maintainability**
   - Before: 22 workflow files
   - Target: 7 workflow files

4. **Build Efficiency**
   - Before: Always build all 12 services
   - Target: Only build changed services

---

## 🎯 Next Actions

1. **Immediate** (Do this now):
   ```bash
   # Create POC
   mkdir -p .github/workflows/_reusable
   git mv .github/workflows/security-scan.yaml .github/workflows/_reusable/
   # Copy the POC MASTER-PIPELINE.yaml from above
   # Test it
   ```

2. **Short-term** (Next few days):
   - Build remaining reusable workflows
   - Test each component individually
   - Integrate into master pipeline

3. **Medium-term** (Next week):
   - Full testing in dev environment
   - Move old workflows to DEPRECATED/
   - Update documentation

---

**Ready to start? Begin with the POC above and test it in dev!** 🚀
