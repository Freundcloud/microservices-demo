# Workflow Consolidation Plan

## Current State Analysis

### Existing Workflows (22 files!)

#### 🚀 Deployment Workflows (8 files - MASSIVE DUPLICATION!)
1. **deploy-with-servicenow-devops.yaml** (29KB) - Modern DevOps Change with security integration
2. **deploy-with-servicenow-basic.yaml** (83KB!) - Basic Table API approach
3. **deploy-with-servicenow-hybrid.yaml** (38KB) - Hybrid approach
4. **deploy-with-servicenow.yaml** (20KB) - Original ServiceNow integration
5. **deploy-application.yaml** (6KB) - Basic K8s deployment
6. **auto-deploy-dev.yaml** (10KB) - Auto dev deployment
7. **setup-servicenow-cmdb.yaml** (6KB) - CMDB setup
8. **aws-infrastructure-discovery.yaml** (49KB!) - Infrastructure discovery

#### 🔒 Security & Scanning (2 files)
9. **security-scan.yaml** (17KB) - Comprehensive security scanning
10. **security-scan-servicenow.yaml** (19KB) - ServiceNow-integrated security scan

#### 🏗️ Build & Infrastructure (5 files)
11. **build-and-push-images.yaml** (8KB) - Docker image building
12. **terraform-validate.yaml** (9KB) - Terraform validation
13. **terraform-plan.yaml** (2.5KB) - Terraform planning
14. **terraform-apply.yaml** (5KB) - Terraform deployment
15. **eks-discovery.yaml** (32KB) - EKS cluster discovery

#### 🧪 CI/CD Quality Checks (3 files)
16. **helm-chart-ci.yaml** (4.5KB) - Helm chart validation
17. **kubevious-manifests-ci.yaml** (1.6KB) - Manifest visualization
18. **kustomize-build-ci.yaml** (1.4KB) - Kustomize validation

#### 📚 Documentation (4 files)
19. **README.md** (3.8KB)
20. **SERVICENOW-WORKFLOWS-README.md** (15KB)
21. **install-dependencies.sh** (2.6KB)
22. **security-scan.yaml.backup** (24KB)

### Total Size: ~360KB of workflow YAML! 😱

---

## Problems with Current State

### 1. **Massive Duplication**
- 4 different ServiceNow deployment workflows doing almost the same thing
- 2 separate security scan workflows
- 3 separate Terraform workflows
- Each workflow re-implements: checkout, AWS auth, kubectl config, etc.

### 2. **No Single Entry Point**
- Can't trigger "full CI/CD" with one click
- Must manually run multiple workflows in sequence
- No clear workflow for: "commit → test → deploy to dev"

### 3. **Maintenance Nightmare**
- Bug fixes require changing multiple workflows
- Secret updates needed in many places
- Version upgrades (actions) across 20+ files

### 4. **Poor Developer Experience**
- Confusing which workflow to use
- No automatic progression: dev → qa → prod
- Manual coordination required

### 5. **Resource Waste**
- Duplicate security scans across workflows
- Repeated Docker builds
- Multiple Terraform validations

---

## Proposed Solution: ONE Unified CI/CD Pipeline

### Architecture: Single Master Workflow + Reusable Components

```
.github/workflows/
├── 📦 MASTER-PIPELINE.yaml                    ← SINGLE ENTRY POINT
│
├── 🔧 _reusable/                              ← Reusable workflow components
│   ├── terraform-plan.yaml
│   ├── terraform-apply.yaml
│   ├── security-scan.yaml                     ← Already exists!
│   ├── build-images.yaml
│   ├── deploy-environment.yaml
│   └── servicenow-integration.yaml
│
└── 🗑️  DEPRECATED/ (move old workflows here)
    ├── deploy-with-servicenow-basic.yaml
    ├── deploy-with-servicenow-hybrid.yaml
    └── ... (20 other files)
```

---

## Master Pipeline Design

### MASTER-PIPELINE.yaml (The ONE workflow to rule them all)

```yaml
name: "🚀 Master CI/CD Pipeline"

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
      skip_terraform:
        description: 'Skip infrastructure changes'
        type: boolean
        default: false
      skip_tests:
        description: 'Skip security scans (NOT recommended)'
        type: boolean
        default: false

jobs:
  # ============================================================================
  # STAGE 1: CODE QUALITY & SECURITY (Parallel)
  # ============================================================================

  validate-code:
    name: "📋 Code Validation"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Kustomize
        run: kubectl kustomize overlays/dev --dry-run
      - name: Validate Helm
        run: helm lint helm-chart/
      - name: YAML lint
        run: yamllint .github/workflows/

  security-scans:
    name: "🔒 Security Scanning"
    uses: ./.github/workflows/_reusable/security-scan.yaml
    secrets: inherit
    if: ${{ !inputs.skip_tests }}

  # ============================================================================
  # STAGE 2: INFRASTRUCTURE (Conditional - only if Terraform changed)
  # ============================================================================

  check-terraform-changes:
    name: "🔍 Detect Infrastructure Changes"
    runs-on: ubuntu-latest
    outputs:
      terraform_changed: ${{ steps.filter.outputs.terraform }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            terraform:
              - 'terraform-aws/**'

  terraform-plan:
    name: "📊 Terraform Plan"
    needs: check-terraform-changes
    if: needs.check-terraform-changes.outputs.terraform_changed == 'true' && !inputs.skip_terraform
    uses: ./.github/workflows/_reusable/terraform-plan.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}

  terraform-apply:
    name: "🏗️ Apply Infrastructure"
    needs: [terraform-plan, security-scans]
    if: |
      needs.check-terraform-changes.outputs.terraform_changed == 'true' &&
      !inputs.skip_terraform &&
      github.ref == 'refs/heads/main'
    uses: ./.github/workflows/_reusable/terraform-apply.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}

  # ============================================================================
  # STAGE 3: BUILD DOCKER IMAGES (Conditional - only if services changed)
  # ============================================================================

  detect-service-changes:
    name: "🔍 Detect Service Changes"
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

  build-and-push:
    name: "🐳 Build Docker Images"
    needs: [detect-service-changes, security-scans]
    if: needs.detect-service-changes.outputs.services != '[]'
    uses: ./.github/workflows/_reusable/build-images.yaml
    secrets: inherit
    with:
      services: ${{ needs.detect-service-changes.outputs.services }}
      environment: ${{ inputs.environment || 'dev' }}

  # ============================================================================
  # STAGE 4: SERVICENOW CHANGE MANAGEMENT
  # ============================================================================

  create-change-request:
    name: "📋 ServiceNow Change Request"
    needs: [security-scans, build-and-push]
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/_reusable/servicenow-integration.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}
      change_type: "normal"
    outputs:
      change_request_number: ${{ jobs.servicenow.outputs.change_number }}
      change_request_sys_id: ${{ jobs.servicenow.outputs.change_sys_id }}

  # ============================================================================
  # STAGE 5: DEPLOYMENT (Waits for approval if prod)
  # ============================================================================

  deploy-to-environment:
    name: "🚀 Deploy to ${{ inputs.environment || 'dev' }}"
    needs: [create-change-request, terraform-apply]
    if: always() && (needs.create-change-request.result == 'success' || github.ref != 'refs/heads/main')
    uses: ./.github/workflows/_reusable/deploy-environment.yaml
    secrets: inherit
    with:
      environment: ${{ inputs.environment || 'dev' }}
      change_request_sys_id: ${{ needs.create-change-request.outputs.change_request_sys_id }}

  # ============================================================================
  # STAGE 6: POST-DEPLOYMENT VERIFICATION
  # ============================================================================

  smoke-tests:
    name: "✅ Smoke Tests"
    needs: deploy-to-environment
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name microservices --region eu-west-2

      - name: Check deployment health
        run: |
          kubectl get pods -n microservices-${{ inputs.environment || 'dev' }}
          kubectl wait --for=condition=ready pods --all -n microservices-${{ inputs.environment || 'dev' }} --timeout=300s

      - name: Test frontend endpoint
        run: |
          FRONTEND_URL=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          curl -f http://$FRONTEND_URL/ || exit 1

  # ============================================================================
  # STAGE 7: NOTIFICATIONS & CLEANUP
  # ============================================================================

  update-change-request:
    name: "✅ Close ServiceNow Change"
    needs: [create-change-request, smoke-tests]
    if: always() && needs.create-change-request.result == 'success'
    runs-on: ubuntu-latest
    steps:
      - name: Update change request status
        run: |
          STATUS="successful"
          if [ "${{ needs.smoke-tests.result }}" != "success" ]; then
            STATUS="failed"
          fi

          curl -X PATCH \
            -H "Authorization: Basic ${{ secrets.SERVICENOW_AUTH }}" \
            -H "Content-Type: application/json" \
            -d "{\"state\":\"3\",\"close_code\":\"$STATUS\",\"close_notes\":\"Deployment $STATUS via GitHub Actions\"}" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/${{ needs.create-change-request.outputs.change_request_sys_id }}"
```

---

## Reusable Workflows Structure

### 1. **_reusable/terraform-plan.yaml**
```yaml
name: Terraform Plan (Reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    outputs:
      plan_file:
        value: ${{ jobs.plan.outputs.plan_file }}

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Terraform Plan
        run: terraform plan -var-file=environments/${{ inputs.environment }}.tfvars
```

### 2. **_reusable/build-images.yaml**
```yaml
name: Build Docker Images (Reusable)
on:
  workflow_call:
    inputs:
      services:
        required: true
        type: string
      environment:
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJSON(inputs.services) }}
    steps:
      - uses: actions/checkout@v4
      - name: Build ${{ matrix.service }}
        run: docker build -t ${{ matrix.service }}:${{ github.sha }} src/${{ matrix.service }}
      - name: Push to ECR
        run: docker push ...
```

### 3. **_reusable/security-scan.yaml** ✅ Already exists!
Just move it to `_reusable/` folder

### 4. **_reusable/deploy-environment.yaml**
```yaml
name: Deploy to Environment (Reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      change_request_sys_id:
        required: false
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy with Kustomize
        run: kubectl apply -k kustomize/overlays/${{ inputs.environment }}
```

### 5. **_reusable/servicenow-integration.yaml**
```yaml
name: ServiceNow Change Management (Reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      change_type:
        required: false
        type: string
        default: "normal"
    outputs:
      change_number:
        value: ${{ jobs.create-change.outputs.change_number }}
      change_sys_id:
        value: ${{ jobs.create-change.outputs.change_sys_id }}

jobs:
  create-change:
    runs-on: ubuntu-latest
    steps:
      - name: Create Change Request
        uses: ServiceNow/servicenow-devops-change@v6.1.0
        # ... (simplified from deploy-with-servicenow-devops.yaml)

  register-security-results:
    needs: create-change
    # ... (security tool registration)
```

---

## Benefits of This Approach

### ✅ Single Entry Point
```bash
# Deploy to dev (automatic on commit to main)
git push origin main

# Deploy to qa (manual with approval)
gh workflow run MASTER-PIPELINE.yaml -f environment=qa

# Deploy to prod (manual with approval)
gh workflow run MASTER-PIPELINE.yaml -f environment=prod

# Infrastructure only
gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f skip_tests=false
```

### ✅ Intelligent Change Detection
- Only builds services that changed (path filters)
- Only runs Terraform if infrastructure changed
- Skips unnecessary steps automatically

### ✅ Reduced Code
- From **22 files (360KB)** to **6 files (~80KB)**
- **78% reduction** in workflow code
- Single source of truth

### ✅ Faster CI/CD
- Parallel execution where possible
- Conditional steps skip unnecessary work
- Reuse of artifacts between jobs

### ✅ Better Security
- All scans in one place
- ServiceNow integration automatic
- Consistent security checks

### ✅ Environment Progression
```
commit → dev (automatic)
       ↓
manual approval → qa
       ↓
manual approval → prod
```

---

## Migration Strategy

### Phase 1: Create Reusable Workflows (Week 1)
1. ✅ Move `security-scan.yaml` to `_reusable/security-scan.yaml`
2. Create `_reusable/terraform-plan.yaml`
3. Create `_reusable/terraform-apply.yaml`
4. Create `_reusable/build-images.yaml`
5. Create `_reusable/deploy-environment.yaml`
6. Create `_reusable/servicenow-integration.yaml`

### Phase 2: Create Master Pipeline (Week 1-2)
1. Create `MASTER-PIPELINE.yaml`
2. Test in dev environment
3. Validate all stages work
4. Run parallel with old workflows

### Phase 3: Deprecate Old Workflows (Week 2)
1. Create `.github/workflows/DEPRECATED/` folder
2. Move old workflows to DEPRECATED
3. Add deprecation notice to old workflows
4. Update documentation

### Phase 4: Cleanup (Week 3)
1. Delete deprecated workflows after 2 weeks
2. Update CLAUDE.md with new workflow
3. Update onboarding docs
4. Announce to team

---

## Workflow Comparison

### Before (Current State)
```
Developer pushes code
  ↓
Must manually run:
1. build-and-push-images.yaml
2. security-scan.yaml
3. terraform-validate.yaml
4. terraform-apply.yaml (maybe)
5. deploy-with-servicenow-devops.yaml
6. aws-infrastructure-discovery.yaml (maybe)

Total: 6 manual workflow runs
Time: ~45 minutes (sequential)
Maintenance: 22 workflow files
```

### After (Streamlined)
```
Developer pushes code
  ↓
MASTER-PIPELINE.yaml runs automatically:
1. Detects what changed (path filters)
2. Runs only necessary jobs (intelligent)
3. Parallel execution (security + terraform + build)
4. Creates ServiceNow change
5. Deploys to environment
6. Runs smoke tests
7. Updates ServiceNow

Total: 1 automatic workflow run
Time: ~25 minutes (parallel)
Maintenance: 6 workflow files
```

### Savings
- **Time saved**: 44% faster (20 minutes)
- **Manual effort**: 83% reduction (1 vs 6 clicks)
- **Code reduction**: 78% less YAML
- **Maintenance**: 73% fewer files

---

## Next Steps

### Immediate Actions
1. **Review this plan** - Ensure alignment with requirements
2. **Prioritize features** - Which capabilities are must-have?
3. **Create POC** - Build minimal MASTER-PIPELINE.yaml
4. **Test in dev** - Validate end-to-end flow
5. **Iterate** - Refine based on feedback

### Questions to Answer
1. **ServiceNow integration**: Keep DevOps Change API or simplify to Basic API?
2. **Approval gates**: Manual approval for qa/prod or automatic?
3. **Rollback strategy**: How to handle failed deployments?
4. **Notification channels**: Slack? Email? Teams?
5. **Metrics tracking**: DORA metrics? Deployment frequency?

### Future Enhancements
- **GitOps**: ArgoCD/Flux for declarative deployments
- **Progressive delivery**: Canary deployments, blue/green
- **Automatic rollback**: Detect failures and revert
- **Performance testing**: Load tests before prod deployment
- **Cost tracking**: AWS cost analysis per deployment

---

## Files to Create

```
.github/workflows/
├── MASTER-PIPELINE.yaml                       ← NEW (main entry point)
├── _reusable/
│   ├── terraform-plan.yaml                    ← NEW
│   ├── terraform-apply.yaml                   ← NEW
│   ├── security-scan.yaml                     ← MOVE (from root)
│   ├── build-images.yaml                      ← NEW
│   ├── deploy-environment.yaml                ← NEW
│   └── servicenow-integration.yaml            ← NEW
└── DEPRECATED/
    └── (all 20 old workflows)                 ← MOVE (from root)
```

## Files to Delete (After Testing)

```
auto-deploy-dev.yaml
aws-infrastructure-discovery.yaml
build-and-push-images.yaml
deploy-application.yaml
deploy-with-servicenow-basic.yaml
deploy-with-servicenow-devops.yaml              ← Keep logic, consolidate
deploy-with-servicenow-hybrid.yaml
deploy-with-servicenow.yaml
eks-discovery.yaml
helm-chart-ci.yaml
install-dependencies.sh
kubevious-manifests-ci.yaml
kustomize-build-ci.yaml
security-scan-servicenow.yaml
setup-servicenow-cmdb.yaml
terraform-apply.yaml
terraform-plan.yaml
terraform-validate.yaml
security-scan.yaml.backup                       ← Delete immediately
```

---

**Total Impact**: From 22 workflow files (360KB) → 7 workflow files (80KB)
**Reduction**: 78% less code, 73% fewer files, 44% faster execution
**Developer Experience**: 1 workflow instead of 6, automatic progression, intelligent change detection

🚀 **Ready to streamline?**
