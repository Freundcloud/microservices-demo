# Phase 1 Testing Checklist

> **Status**: Ready for Testing
> **Date**: 2025-01-28

---

## Pre-Push Validation

✅ **Local Tests**
- [x] Composite actions YAML valid
- [x] Workflow YAML valid
- [x] service-list.json valid
- [x] All references correct (7 AWS, 3 kubectl)
- [x] Changes committed

---

## Push and Initial Verification

### 1. Push Changes

```bash
git push origin main
```

**Expected**: Push succeeds, no errors

---

### 2. Check GitHub Actions Tab

1. Go to: https://github.com/Freundcloud/microservices-demo/actions
2. Verify no immediate syntax errors
3. Check for yellow/red status indicators

**Expected**: No immediate failures

---

## Functional Testing

### Test 1: AWS Credentials Composite Action

**Workflow to Test**: `terraform-plan.yaml` (triggered on PR)

**How to Test**:
```bash
# Create a test branch
git checkout -b test/phase1-composite-actions

# Make a trivial change to trigger workflow
echo "# Test" >> terraform-aws/README.md
git add terraform-aws/README.md
git commit -m "test: Trigger terraform-plan workflow"
git push origin test/phase1-composite-actions

# Create PR
gh pr create --title "Test: Phase 1 Composite Actions" \
  --body "Testing new composite actions from Phase 1 refactoring"
```

**Expected Results**:
- ✅ Workflow runs successfully
- ✅ "Setup AWS Credentials" step succeeds
- ✅ No errors related to AWS credentials
- ✅ Terraform plan completes

**What to Check in Logs**:
```
Setup AWS Credentials
  with:
    aws-region: eu-west-2
  env:
    AWS_ACCESS_KEY_ID: ***
    AWS_SECRET_ACCESS_KEY: ***
✓ Complete
```

---

### Test 2: kubectl Composite Action

**Workflow to Test**: `deploy-environment.yaml`

**How to Test**:
```bash
# Trigger manual workflow
gh workflow run deploy-environment.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev
```

**Expected Results**:
- ✅ Workflow runs successfully
- ✅ "Configure kubectl" step succeeds
- ✅ kubectl commands work after configuration
- ✅ Deployment completes

**What to Check in Logs**:
```
Configure kubectl
  with:
    cluster-name: microservices
    aws-region: eu-west-2
Updated context arn:aws:eks:eu-west-2:...:cluster/microservices
✓ Verify kubectl connection
Client Version: ...
Server Version: ...
✓ Complete
```

---

### Test 3: npm Dependency Caching

**Workflow to Test**: `build-images.yaml` (build Node.js services)

**How to Test**:
```bash
# Trigger build for Node.js services
gh workflow run build-images.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev \
  -f services='["paymentservice","currencyservice"]'

# Wait for first run to complete (will create cache)
# Then trigger again to test cache hit
gh workflow run build-images.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev \
  -f services='["paymentservice","currencyservice"]'
```

**Expected Results**:

**First Run** (cache miss):
```
Setup Node.js (for Node services)
  cache: 'npm'
  cache-dependency-path: 'src/paymentservice/package-lock.json'
Cache not found for input keys: ...
✓ Complete
Run Node.js Tests
  npm install
  ... (downloads dependencies)
Time: ~2-3 minutes
```

**Second Run** (cache hit):
```
Setup Node.js (for Node services)
  cache: 'npm'
  cache-dependency-path: 'src/paymentservice/package-lock.json'
✓ Cache restored from key: ...
Run Node.js Tests
  npm install
  ... (uses cached dependencies)
Time: ~1-1.5 minutes (40-60% faster ✅)
```

**Success Criteria**:
- ✅ Second run is 40-60% faster
- ✅ Logs show "Cache restored"
- ✅ Build succeeds on both runs

---

### Test 4: Gradle Dependency Caching

**Workflow to Test**: `build-images.yaml` (build Java service)

**How to Test**:
```bash
# Trigger build for Java service (adservice)
gh workflow run build-images.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev \
  -f services='["adservice"]'

# Wait for first run, then trigger again
gh workflow run build-images.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev \
  -f services='["adservice"]'
```

**Expected Results**:

**First Run** (cache miss):
```
Setup Java (for adservice)
  cache: 'gradle'
  cache-dependency-path: 'src/adservice/*.gradle*'
Cache not found for input keys: ...
✓ Complete
Run Java Tests
  ./gradlew test
  ... (downloads dependencies from Maven Central)
Time: ~3-4 minutes
```

**Second Run** (cache hit):
```
Setup Java (for adservice)
  cache: 'gradle'
  cache-dependency-path: 'src/adservice/*.gradle*'
✓ Cache restored from key: ...
Run Java Tests
  ./gradlew test
  ... (uses cached dependencies)
Time: ~1.5-2 minutes (40-60% faster ✅)
```

**Success Criteria**:
- ✅ Second run is 40-60% faster
- ✅ Logs show "Cache restored"
- ✅ Build succeeds on both runs

---

### Test 5: Service List JSON

**Workflow to Test**: `build-images.yaml` (build all services)

**How to Test**:
```bash
# Trigger build for all services
gh workflow run build-images.yaml \
  --ref test/phase1-composite-actions \
  -f environment=dev \
  -f services=all
```

**Expected Results**:
```
Set Build Matrix
  # Load canonical service list from centralized JSON file
  ALL_SERVICES=$(jq -c '.services' scripts/service-list.json)

  🔨 Building ALL services from scripts/service-list.json

  matrix=["emailservice","productcatalogservice",...,"shoppingassistantservice"]
  has_services=true

✓ Complete
```

**What to Check**:
- ✅ All 12 services in matrix
- ✅ Logs show "Building ALL services from scripts/service-list.json"
- ✅ No hardcoded service list visible

---

## Performance Verification

### Build Time Comparison

**Baseline** (before Phase 1):
- Node.js service build: ~2-3 minutes
- Java service build: ~3-4 minutes
- Full build (all services): ~45 minutes

**Expected** (after Phase 1):
- Node.js service build: ~1-1.5 minutes (cache hit)
- Java service build: ~1.5-2 minutes (cache hit)
- Full build (all services): ~20-25 minutes (cache hit)

**How to Measure**:
1. Check workflow run times in GitHub Actions
2. Compare first run (cache miss) vs second run (cache hit)
3. Document improvements

**Success Criteria**:
- ✅ Second runs are 40-60% faster
- ✅ No regression in build success rate

---

## Rollback Plan

If any test fails:

### Option 1: Fix Forward
```bash
# Fix the issue
git checkout test/phase1-composite-actions
# Make fixes
git commit -m "fix: Address Phase 1 issue"
git push origin test/phase1-composite-actions
```

### Option 2: Revert
```bash
# Revert the refactoring commit
git revert 8affcbe5
git push origin main
```

**When to Rollback**:
- ❌ Workflows fail consistently
- ❌ Caching doesn't work (no performance improvement)
- ❌ Breaking changes to existing workflows

---

## Success Criteria

Phase 1 is successful when:

- ✅ All workflows run without errors
- ✅ Composite actions work correctly
- ✅ Dependency caching shows 40-60% improvement
- ✅ service-list.json generates correct matrix
- ✅ No regression in workflow behavior
- ✅ Documentation is clear and helpful

---

## Post-Testing

Once all tests pass:

1. **Merge Test PR**:
   ```bash
   gh pr merge test/phase1-composite-actions --squash
   ```

2. **Update Documentation**:
   - Mark Phase 1 as complete in WORKFLOW-REFACTORING-ANALYSIS.md
   - Update main README if needed

3. **Communicate Success**:
   - Share results with team
   - Document actual performance improvements

4. **Plan Phase 2**:
   - Review Phase 2 tasks
   - Estimate timeline
   - Begin implementation

---

## Troubleshooting

### Issue: "Composite action not found"

**Error**:
```
Error: ./.github/actions/setup-aws-credentials/action.yaml: No such file or directory
```

**Cause**: Checkout action didn't run or composite action not committed

**Fix**:
```bash
# Verify files exist
ls -la .github/actions/*/action.yaml

# If missing, ensure they're committed and pushed
git status
git push origin main
```

---

### Issue: "Cannot access secrets in composite action"

**Error**:
```
Error: secrets.AWS_ACCESS_KEY_ID is not available
```

**Cause**: Trying to access secrets directly in composite action

**Fix**: Secrets must be passed via environment variables (already implemented correctly)

---

### Issue: "Cache not restoring"

**Symptoms**: Second run not faster, logs show "Cache not found"

**Possible Causes**:
1. Cache key changed (package-lock.json or build files modified)
2. Cache expired (7-day retention)
3. Cache miss on different runner

**Fix**: This is expected if dependencies changed. Verify cache works when dependencies are stable.

---

### Issue: "service-list.json not found"

**Error**:
```
jq: error: scripts/service-list.json: No such file or directory
```

**Cause**: File not in repository

**Fix**:
```bash
# Verify file exists
ls -la scripts/service-list.json

# If missing, commit and push
git add scripts/service-list.json
git commit -m "fix: Add missing service-list.json"
git push origin main
```

---

## Notes

- **First runs will always be slower** (cache miss) - this is expected
- **Cache hits require stable dependencies** - changing package-lock.json invalidates cache
- **Monitor GitHub Actions minutes** - caching reduces consumption
- **Keep test branch** for additional testing if needed

---

**Generated**: 2025-01-28
**Author**: Claude Code
**Status**: Ready for execution
