# Next Steps - Actionable Roadmap

## 🎯 What's Been Completed

✅ **ServiceNow Security Integration** - Security scans now register with change request context
✅ **Workflow Consolidation Plan** - Complete architecture designed (22 → 7 workflows)
✅ **Implementation Guide** - Step-by-step instructions with code templates
✅ **Documentation** - 5 comprehensive guides created and committed

**All planning is complete. Ready to execute!**

---

## 🚀 Immediate Actions (Choose One Path)

### Path A: Start with POC (Recommended - 30 minutes)

**Why**: Validate the concept quickly before full implementation

**Steps**:
```bash
# 1. Create reusable workflows directory
mkdir -p .github/workflows/_reusable

# 2. Move security-scan to reusable folder
git mv .github/workflows/security-scan.yaml .github/workflows/_reusable/security-scan.yaml
git commit -m "refactor: Move security-scan to reusable workflows"
git push

# 3. Create MASTER-PIPELINE.yaml
# Copy the POC template from docs/WORKFLOW-IMPLEMENTATION-GUIDE.md
# (Search for "Quick Start: Build POC")

# 4. Commit and test
git add .github/workflows/MASTER-PIPELINE.yaml
git commit -m "feat: Add Master Pipeline POC (security + deploy)"
git push

# 5. Trigger the POC
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# 6. Watch it run
gh run watch
```

**Expected Outcome**:
- Security scans run (via reusable workflow)
- Deployment to dev succeeds
- Pods become healthy
- Entire flow completes in ~20 minutes

**Success Criteria**:
- ✅ Workflow completes successfully
- ✅ Dev environment updated
- ✅ Faster than running separate workflows
- ✅ Team comfortable with new approach

**If POC fails**: Review logs, fix issues, iterate
**If POC succeeds**: Proceed to Path B (full implementation)

---

### Path B: Full Implementation (After POC validation)

**Timeline**: 1-2 days (6-8 hours of work)

**Phase 1: Build Reusable Workflows** (2-3 hours)

Create these 5 files in `.github/workflows/_reusable/`:

1. **terraform-plan.yaml** (30 min)
   - Copy template from WORKFLOW-IMPLEMENTATION-GUIDE.md
   - Test: `gh workflow run _reusable/terraform-plan.yaml -f environment=dev`

2. **terraform-apply.yaml** (30 min)
   - Extract from existing terraform-apply.yaml
   - Make it accept environment parameter
   - Test with dev environment

3. **build-images.yaml** (45 min)
   - Implement path filtering for 12 services
   - Matrix build strategy
   - Test: Should only build changed services

4. **deploy-environment.yaml** (30 min)
   - Kustomize-based deployment
   - Environment-specific namespaces
   - Rollout waiting and verification

5. **servicenow-integration.yaml** (45 min)
   - Change request creation
   - Security result registration (12 tools)
   - Change request closing

**Phase 2: Build Master Pipeline** (2-3 hours)

Update `MASTER-PIPELINE.yaml` to include all 6 stages:

```yaml
# Stage 1: Security (already in POC)
# Stage 2: Infrastructure (new - conditional Terraform)
# Stage 3: Build images (new - smart filtering)
# Stage 4: ServiceNow (new - change management)
# Stage 5: Deploy (already in POC)
# Stage 6: Smoke tests (new - verification)
```

Copy complete template from WORKFLOW-IMPLEMENTATION-GUIDE.md

**Phase 3: Testing** (1-2 hours)

```bash
# Test each reusable workflow individually
gh workflow run _reusable/build-images.yaml -f environment=dev
gh workflow run _reusable/deploy-environment.yaml -f environment=dev

# Test full master pipeline
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Test with options
gh workflow run MASTER-PIPELINE.yaml \
  -f environment=dev \
  -f skip_terraform=true

# Test conditional execution
# (Make a change to one service, verify only that service builds)
```

**Phase 4: Parallel Running** (1 week)

Run new master pipeline **alongside** old workflows:
- Builds confidence
- Validates feature parity
- Allows rollback if needed

**Phase 5: Deprecation** (1 hour)

```bash
# Create deprecated folder
mkdir -p .github/workflows/DEPRECATED

# Move old workflows (keep the ones being used for now)
git mv .github/workflows/build-and-push-images.yaml .github/workflows/DEPRECATED/
git mv .github/workflows/deploy-application.yaml .github/workflows/DEPRECATED/
# ... (move 15+ old workflows)

# Commit
git commit -m "refactor: Deprecate old workflows in favor of Master Pipeline"
git push
```

---

## 📋 Detailed Checklist

### Reusable Workflows Creation
- [ ] Create `.github/workflows/_reusable/` directory
- [ ] Move `security-scan.yaml` to `_reusable/security-scan.yaml`
- [ ] Create `terraform-plan.yaml` (reusable)
- [ ] Create `terraform-apply.yaml` (reusable)
- [ ] Create `build-images.yaml` (with path filtering)
- [ ] Create `deploy-environment.yaml` (Kustomize-based)
- [ ] Create `servicenow-integration.yaml` (change + security registration)

### Master Pipeline Creation
- [ ] Create `MASTER-PIPELINE.yaml` skeleton
- [ ] Stage 1: Security scans (call reusable)
- [ ] Stage 2: Infrastructure (conditional Terraform)
- [ ] Stage 3: Build images (smart filtering)
- [ ] Stage 4: ServiceNow change management
- [ ] Stage 5: Deployment
- [ ] Stage 6: Post-deployment tests

### Testing & Validation
- [ ] Test security-scan as reusable workflow
- [ ] Test each reusable workflow individually
- [ ] Test master pipeline in dev environment
- [ ] Verify path filtering works (only builds changed services)
- [ ] Verify conditional Terraform works
- [ ] Verify ServiceNow integration works
- [ ] Verify security tools register properly
- [ ] Check execution time (should be ~25 min vs ~45 min)

### Cleanup & Documentation
- [ ] Run master pipeline parallel with old workflows (1 week)
- [ ] Validate feature parity
- [ ] Create `DEPRECATED/` directory
- [ ] Move old 15+ workflows to DEPRECATED
- [ ] Add deprecation notices to old workflows
- [ ] Update CLAUDE.md with new workflow
- [ ] Update docs/ONBOARDING.md
- [ ] Update justfile commands (if needed)
- [ ] Delete deprecated workflows after grace period
- [ ] Delete `.github/workflows/security-scan.yaml.backup`

---

## 🎯 Success Metrics

Track these to measure improvement:

### Execution Time
- [ ] **Baseline**: Measure current deployment time (~45 min)
- [ ] **Target**: Master pipeline completes in ≤25 min
- [ ] **Actual**: _____ minutes (to be measured)

### Developer Experience
- [ ] **Baseline**: 6 manual workflow runs
- [ ] **Target**: 1 automatic workflow run
- [ ] **Actual**: _____ workflow runs (to be measured)

### Code Maintainability
- [ ] **Baseline**: 22 workflow files
- [ ] **Target**: 7 workflow files
- [ ] **Actual**: _____ files (to be measured)

### Build Efficiency
- [ ] **Baseline**: Always builds all 12 services
- [ ] **Target**: Only builds changed services
- [ ] **Test**: Change frontend only → only frontend builds

### ServiceNow Integration
- [ ] Security Tools tab shows 12 tools
- [ ] Security results persist in ServiceNow
- [ ] Change requests link to security scans
- [ ] Change requests auto-close on success

---

## 🛠️ Troubleshooting Guide

### Issue: POC workflow fails

**Check**:
```bash
# View workflow run
gh run view <run-id> --log-failed

# Check if security-scan moved correctly
ls -la .github/workflows/_reusable/security-scan.yaml

# Validate YAML syntax
yamllint .github/workflows/MASTER-PIPELINE.yaml
```

**Common causes**:
- Security-scan.yaml not in correct location
- Secrets not configured
- YAML syntax error
- AWS credentials expired

### Issue: Path filtering not working

**Check**:
```bash
# Make sure dorny/paths-filter action is used
grep -A 10 "paths-filter" .github/workflows/_reusable/build-images.yaml

# Test by changing one service
echo "// test" >> src/frontend/main.go
git add . && git commit -m "test: trigger frontend build only"
git push

# Should only build frontend, not all 12 services
```

### Issue: ServiceNow integration fails

**Check**:
```bash
# Verify secrets are set
gh secret list

# Required secrets:
# - SN_DEVOPS_INTEGRATION_TOKEN
# - SERVICENOW_INSTANCE_URL
# - SN_ORCHESTRATION_TOOL_ID

# Test ServiceNow connectivity
curl -H "Authorization: Bearer $SN_DEVOPS_INTEGRATION_TOKEN" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"
```

### Issue: Reusable workflow not found

**Error**: `workflow_call event is not supported`

**Fix**: Ensure the workflow is in `_reusable/` folder and has:
```yaml
on:
  workflow_call:
    inputs:
      # ... parameters
```

---

## 📖 Documentation Reference

| Document | Use Case |
|----------|----------|
| [WORKFLOW-IMPLEMENTATION-GUIDE.md](WORKFLOW-IMPLEMENTATION-GUIDE.md) | **START HERE** - Step-by-step implementation |
| [WORKFLOW-CONSOLIDATION-PLAN.md](WORKFLOW-CONSOLIDATION-PLAN.md) | Technical architecture details |
| [WORKFLOW-CONSOLIDATION-SUMMARY.md](WORKFLOW-CONSOLIDATION-SUMMARY.md) | Executive summary & metrics |
| [SERVICENOW-SECURITY-SCAN-TROUBLESHOOTING.md](SERVICENOW-SECURITY-SCAN-TROUBLESHOOTING.md) | Security integration issues |

---

## 🎓 Decision Points

Before starting implementation, decide:

### 1. Timeline
- [ ] **Aggressive** (1 week) - POC + full implementation
- [ ] **Moderate** (2 weeks) - POC, testing, phased rollout
- [ ] **Conservative** (4 weeks) - POC, extended parallel running, gradual migration

### 2. Scope
- [ ] **Minimal** - POC only (security + deploy)
- [ ] **Standard** - All 6 stages with smart filtering
- [ ] **Advanced** - Include auto-rollback, canary deployments

### 3. ServiceNow Integration
- [ ] **Keep DevOps Change API** (current, feature-rich)
- [ ] **Simplify to Basic Table API** (simpler, fewer features)
- [ ] **Hybrid approach** (DevOps API for prod, Basic for dev/qa)

### 4. Approval Gates
- [ ] **Manual approval for prod** (safer, recommended)
- [ ] **Automatic with rollback** (faster, riskier)
- [ ] **Manual for qa and prod** (most conservative)

---

## 🚦 Go/No-Go Decision

**Ready to proceed when**:
- ✅ All planning documentation reviewed
- ✅ Team comfortable with approach
- ✅ Timeline agreed upon
- ✅ Resource allocation confirmed (1-2 devs for 1-2 weeks)
- ✅ Rollback plan established
- ✅ Stakeholders informed

**Hold if**:
- ❌ Major production deployment scheduled this week
- ❌ Team unavailable for testing/support
- ❌ Outstanding critical bugs in current workflows
- ❌ Infrastructure changes planned

---

## 🎯 Quick Commands

```bash
# Start POC implementation
cat docs/WORKFLOW-IMPLEMENTATION-GUIDE.md | grep -A 100 "Quick Start"

# Check current workflow count
ls .github/workflows/*.yaml | wc -l

# View all documentation
ls -lh docs/WORKFLOW-*.md docs/SERVICENOW-*.md

# Trigger POC (after creation)
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Monitor execution
gh run watch

# Check if POC succeeded
gh run list --workflow=MASTER-PIPELINE.yaml --limit 1
```

---

## 📞 Support

**Questions?**
- Review implementation guide: `docs/WORKFLOW-IMPLEMENTATION-GUIDE.md`
- Check troubleshooting: Look for similar issues in guides
- Test incrementally: Build POC first, then add features

**Issues during implementation?**
- Check workflow logs: `gh run view <run-id> --log-failed`
- Validate YAML: `yamllint .github/workflows/`
- Verify secrets: `gh secret list`

---

## 🎉 Success!

You'll know you're successful when:
1. ✅ `git push` triggers automatic deployment to dev
2. ✅ Only changed services are built (saves 60-80% build time)
3. ✅ Deployment completes in ~25 minutes (down from ~45)
4. ✅ ServiceNow Security Tools tab shows all 12 tools
5. ✅ Team prefers new workflow over old ones
6. ✅ Maintenance is easier (7 files vs 22)

---

**🚀 Ready when you are! Start with the 30-minute POC to validate the approach.**

**Last Updated**: 2025-10-21
**Status**: 📋 Planning complete, ready for implementation
**Recommended First Step**: Build POC following Quick Start guide
