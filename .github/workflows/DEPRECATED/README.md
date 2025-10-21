# Deprecated Workflows

This directory contains workflows that have been superseded by the new **Master CI/CD Pipeline** architecture.

## What Happened?

As part of the workflow consolidation effort, we've replaced 18+ individual workflows with a streamlined architecture:

- **1 Master Pipeline**: `MASTER-PIPELINE.yaml` (single entry point)
- **6 Reusable Workflows**: In `_reusable/` directory

## Benefits of New Architecture

### ✅ Reduced Complexity
- **Before**: 18 workflow files (~360KB YAML)
- **After**: 7 workflow files (~95KB YAML)
- **Reduction**: 73% fewer files, 74% less code

### ✅ Single Entry Point
```bash
# Deploy to any environment with one command
gh workflow run MASTER-PIPELINE.yaml -f environment=dev
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
gh workflow run MASTER-PIPELINE.yaml -f environment=prod
```

### ✅ Intelligent Execution
- **Smart Change Detection**: Only builds services that changed
- **Conditional Infrastructure**: Terraform runs only when infrastructure changes
- **Parallel Execution**: Security scans, builds, and validations run concurrently
- **Automatic Progression**: dev → qa → prod with approval gates

### ✅ Better Observability
- Unified pipeline summary shows all stages
- Clear dependency chain between jobs
- Comprehensive step summaries

## Deprecated Workflows

### ServiceNow Deployment Workflows (Consolidated)
- ❌ `deploy-with-servicenow.yaml` → ✅ `MASTER-PIPELINE.yaml` + `_reusable/servicenow-integration.yaml`
- ❌ `deploy-with-servicenow-basic.yaml` → ✅ `MASTER-PIPELINE.yaml`
- ❌ `deploy-with-servicenow-hybrid.yaml` → ✅ `MASTER-PIPELINE.yaml`
- ❌ `deploy-with-servicenow-devops.yaml` → ✅ `MASTER-PIPELINE.yaml` + `_reusable/servicenow-integration.yaml`

### Terraform Workflows (Consolidated)
- ❌ `terraform-validate.yaml` → ✅ `_reusable/terraform-plan.yaml`
- ❌ `terraform-plan.yaml` → ✅ `_reusable/terraform-plan.yaml`
- ❌ `terraform-apply.yaml` → ✅ `_reusable/terraform-apply.yaml`

### Build & Deploy Workflows (Consolidated)
- ❌ `build-and-push-images.yaml` → ✅ `_reusable/build-images.yaml`
- ❌ `deploy-application.yaml` → ✅ `_reusable/deploy-environment.yaml`
- ❌ `auto-deploy-dev.yaml` → ✅ `MASTER-PIPELINE.yaml` (auto-triggers on push to main)

### Discovery & Setup Workflows (Standalone - Keep if Needed)
- ⚠️ `eks-discovery.yaml` - Consider keeping for manual cluster discovery
- ⚠️ `aws-infrastructure-discovery.yaml` - Consider keeping for CMDB population
- ⚠️ `setup-servicenow-cmdb.yaml` - One-time setup, can keep

### CI Validation Workflows (Integrated)
- ❌ `kustomize-build-ci.yaml` → ✅ `MASTER-PIPELINE.yaml` (validate-code job)
- ❌ `helm-chart-ci.yaml` → ✅ `MASTER-PIPELINE.yaml` (validate-code job)
- ❌ `kubevious-manifests-ci.yaml` → ✅ `MASTER-PIPELINE.yaml`

### Security Workflows (Consolidated)
- ❌ `security-scan.yaml` → ✅ `_reusable/security-scan.yaml` (still works standalone)
- ❌ `security-scan-servicenow.yaml` → ✅ `_reusable/servicenow-integration.yaml`

## Migration Guide

### For Developers

**Old Way (Multiple Workflows)**:
```bash
# Had to run manually in sequence:
1. gh workflow run build-and-push-images.yaml
2. gh workflow run security-scan.yaml
3. gh workflow run terraform-apply.yaml
4. gh workflow run deploy-with-servicenow-devops.yaml
```

**New Way (Single Pipeline)**:
```bash
# Everything automatic on push to main:
git push origin main

# Or manually trigger for specific environment:
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
```

### For CI/CD Maintainers

If you need to modify the pipeline:

1. **Security Scans**: Edit `.github/workflows/_reusable/security-scan.yaml`
2. **Terraform**: Edit `.github/workflows/_reusable/terraform-*.yaml`
3. **Docker Builds**: Edit `.github/workflows/_reusable/build-images.yaml`
4. **Deployments**: Edit `.github/workflows/_reusable/deploy-environment.yaml`
5. **ServiceNow Integration**: Edit `.github/workflows/_reusable/servicenow-integration.yaml`
6. **Pipeline Orchestration**: Edit `.github/workflows/MASTER-PIPELINE.yaml`

## Rollback Plan

If you need to temporarily revert to old workflows:

1. Move desired workflow from `DEPRECATED/` back to `.github/workflows/`
2. Disable `MASTER-PIPELINE.yaml` by renaming it to `MASTER-PIPELINE.yaml.disabled`
3. Re-enable old workflow triggers

## Timeline

- **Created**: 2025-01-XX
- **Consolidation Completed**: 2025-01-XX
- **Scheduled for Deletion**: 2025-03-XX (after 2 months validation period)

## Questions?

See the main consolidation documentation:
- `docs/WORKFLOW-CONSOLIDATION-PLAN.md` - Complete consolidation strategy
- `docs/WORKFLOW-CONSOLIDATION-IMPLEMENTATION.md` - Implementation details
- `CLAUDE.md` - Updated project documentation

---

**Status**: ⚠️ These workflows are deprecated but retained for 2 months for safety.
**Recommendation**: Use `MASTER-PIPELINE.yaml` for all new deployments.
