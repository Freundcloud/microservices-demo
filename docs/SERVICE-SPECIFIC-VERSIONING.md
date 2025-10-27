# Service-Specific Versioning and Deployment

> **Purpose**: Enable independent versioning and deployment of individual microservices for realistic ServiceNow change request demonstrations

## Overview

This feature allows you to deploy **individual services independently** with their own version numbers, rather than deploying all services together with a monolithic version.

**Benefits**:
- ✅ Demonstrate microservice-level change requests in ServiceNow
- ✅ Update one service without affecting others
- ✅ Realistic production deployment patterns
- ✅ Clear audit trail per service
- ✅ Independent service lifecycle management

---

## Versioning Strategies

### Strategy 1: Compound Versioning (Recommended for Demo)

**Format**: `<environment-version>.<service-patch>`

```yaml
# kustomize/overlays/dev/kustomization.yaml
images:
  - name: paymentservice
    newTag: 1.1.5.1  # Base 1.1.5 + service update .1
  - name: cartservice
    newTag: 1.1.5.0  # Base 1.1.5, no service updates
  - name: frontend
    newTag: 1.1.5.0  # Base 1.1.5, no service updates
```

**Example Timeline**:
1. Deploy all services to 1.1.5.0 (baseline)
2. Update paymentservice → 1.1.5.1
3. Update paymentservice again → 1.1.5.2
4. Update cartservice → 1.1.5.1
5. Baseline bump to 1.1.6.0 (all services)

**Benefits**:
- Shows which environment baseline (1.1.5)
- Shows service-specific updates (.1, .2, .3)
- Easy to explain in demos
- Clear relationship to environment version

---

### Strategy 2: Semantic Versioning per Service

**Format**: `v<major>.<minor>.<patch>` (independent per service)

```yaml
images:
  - name: paymentservice
    newTag: v2.1.0
  - name: cartservice
    newTag: v1.3.2
  - name: frontend
    newTag: v3.0.1
```

**Benefits**:
- True independent versioning
- Follows semantic versioning standards
- Production-ready approach
- Clear breaking change signals (major version)

---

## Quick Start Commands

### List Available Services
```bash
just service-list
```

**Output**:
```
📦 Available Services
====================

Core Services:
  • adservice              - Contextual ads service (Java)
  • cartservice            - Shopping cart service (C#)
  • checkoutservice        - Checkout orchestration (Go)
  • currencyservice        - Currency conversion (Node.js)
  • emailservice           - Email notifications (Python)
  • frontend               - Web UI (Go)
  • paymentservice         - Payment processing (Node.js)
  • productcatalogservice  - Product inventory (Go)
  • recommendationservice  - ML recommendations (Python)
  • shippingservice        - Shipping calculations (Go)
  • shoppingassistantservice - AI assistant (Python)

Supporting Services:
  • loadgenerator          - Traffic simulator (Python/Locust)
```

---

### Check Current Service Versions
```bash
just service-versions dev
```

**Output**:
```
📦 Service Versions in dev
==============================

  adservice                1.1.5
  cartservice              1.1.5
  checkoutservice          1.1.5
  currencyservice          1.1.5
  emailservice             1.1.5
  frontend                 1.1.5
  loadgenerator            1.1.5
  paymentservice           1.1.5
  productcatalogservice    1.1.5
  recommendationservice    1.1.5
  shippingservice          1.1.5
  shoppingassistantservice 1.1.5
```

---

### Deploy a Single Service

**Basic Command**:
```bash
just service-deploy <env> <service> <version>
```

**Examples**:
```bash
# Deploy paymentservice to dev
just service-deploy dev paymentservice 1.1.5.1

# Deploy cartservice to qa
just service-deploy qa cartservice 2.0.1

# Deploy frontend to prod
just service-deploy prod frontend 1.2.0
```

---

## Complete Workflow Example

### Scenario: Update paymentservice in dev environment

**Step 1: Check current version**
```bash
just service-versions dev
```
Output: `paymentservice  1.1.5`

**Step 2: Deploy new version**
```bash
just service-deploy dev paymentservice 1.1.5.1
```

**What happens**:
1. ✅ Creates feature branch: `feat/deploy-paymentservice-dev-1.1.5.1`
2. ✅ Creates GitHub issue as ServiceNow work item
3. ✅ Updates ONLY paymentservice in `kustomize/overlays/dev/kustomization.yaml`
4. ✅ Commits changes with reference to work item
5. ✅ Pushes branch to GitHub
6. ✅ Creates pull request with service details

**Output**:
```
📌 Creating service-specific branch: feat/deploy-paymentservice-dev-1.1.5.1
🧾 Creating GitHub issue (ServiceNow work item)
✅ Created work item #24
🔧 Bumping paymentservice to 1.1.5.1 in dev
✅ Updated paymentservice to version 1.1.5.1 in dev
📝 Committing changes
📤 Pushing branch
🔀 Creating pull request

✅ Service deployment PR created!
📋 Summary:
   Service: paymentservice
   Version: 1.1.5.1
   Environment: dev
   Work Item: #24

Next steps:
  1. Review the PR in GitHub
  2. Merge the PR to trigger deployment
  3. ServiceNow change request will be created automatically
  4. Approve change in ServiceNow to proceed with deployment
```

**Step 3: Merge PR**

When you merge the PR, the MASTER-PIPELINE workflow automatically:
1. Runs unit tests (only for paymentservice)
2. Builds new Docker image: `paymentservice:1.1.5.1`
3. Pushes to ECR
4. Creates ServiceNow change request
5. Waits for ServiceNow approval
6. Deploys ONLY paymentservice to dev namespace
7. Closes GitHub work item

---

## ServiceNow Integration

### Change Request Details

When deploying a single service, ServiceNow change request includes:

**Short Description**:
```
Deployment to dev environment - paymentservice v1.1.5.1
```

**Description**:
```
Service Deployment: paymentservice
Version: 1.1.5.1
Environment: dev

Automated deployment of single microservice via GitHub Actions.

Commit: abc123def
Branch: feat/deploy-paymentservice-dev-1.1.5.1
Triggered by: @username
Workflow: MASTER-PIPELINE
Run: 12345

Linked Work Items: #24
```

**Custom Fields**:
- `u_source`: GitHub Actions
- `u_repository`: Freundcloud/microservices-demo
- `u_branch`: feat/deploy-paymentservice-dev-1.1.5.1
- `u_commit_sha`: abc123def
- `u_environment`: dev
- `u_service`: paymentservice *(new field)*
- `u_service_version`: 1.1.5.1 *(new field)*

---

## Advanced Usage

### Manual Script Usage

If you prefer not to use justfile, you can call the script directly:

```bash
./scripts/bump-service-version.sh <env> <service> <version>
```

**Example**:
```bash
./scripts/bump-service-version.sh dev paymentservice 1.1.5.1
```

**What it does**:
- Updates ONLY the specified service's `newTag` in kustomization.yaml
- Validates service name against known services
- Shows diff of changes
- Does NOT create branches or PRs (manual workflow)

---

### Updating Multiple Services

To update multiple services, run commands sequentially:

```bash
# Update paymentservice
just service-deploy dev paymentservice 1.1.5.1

# Wait for PR to be created and merge it

# Update cartservice
just service-deploy dev cartservice 1.1.5.1

# Each service gets its own:
# - Feature branch
# - Work item
# - Pull request
# - ServiceNow change request
```

---

## Comparison: Monolithic vs Service-Specific

### Monolithic Version Bump (Old Way)

**Command**:
```bash
just demo-run dev 1.1.6
```

**Result**:
- ALL 12 services updated to 1.1.6
- Single change request for entire environment
- All services deployed together
- No granular control

**Use Case**: Major releases, baseline updates

---

### Service-Specific Deployment (New Way)

**Command**:
```bash
just service-deploy dev paymentservice 1.1.5.1
```

**Result**:
- ONLY paymentservice updated to 1.1.5.1
- Separate change request per service
- Independent deployment
- Granular change tracking

**Use Case**: Hotfixes, feature updates, independent service releases

---

## Version Number Guidelines

### Compound Versioning (1.1.5.1)

**Format**: `<major>.<minor>.<patch>.<service-patch>`

**When to bump**:
- **1.x.x.0** → New environment baseline (all services updated)
- **x.1.x.0** → New feature baseline
- **x.x.1.0** → Bug fix baseline
- **x.x.x.1** → Single service update (hotfix, patch, feature)

**Examples**:
- `1.1.5.0` → Environment baseline
- `1.1.5.1` → First service-specific update
- `1.1.5.2` → Second service-specific update
- `1.1.6.0` → Next baseline (reset service patches)

---

### Semantic Versioning (v2.1.0)

**Format**: `v<major>.<minor>.<patch>`

**When to bump**:
- **v2.0.0** → Breaking changes (API compatibility broken)
- **v1.1.0** → New features (backward compatible)
- **v1.0.1** → Bug fixes (backward compatible)

**Examples**:
- `v1.0.0` → Initial release
- `v1.1.0` → Added new payment method
- `v1.1.1` → Fixed currency calculation bug
- `v2.0.0` → Changed API contract (breaking)

---

## Troubleshooting

### Error: Service not found

**Symptom**:
```
❌ Invalid service: paymentsvc
Valid services: adservice cartservice checkoutservice...
```

**Solution**:
Check valid service names with `just service-list`

---

### Error: No changes made

**Symptom**:
```
⚠️  No changes made - service may not exist or version already set
```

**Possible causes**:
1. Service name typo
2. Version already set to specified value
3. Service not in kustomization.yaml

**Solution**:
```bash
# Check current version
just service-versions dev

# Verify service name
just service-list
```

---

### Error: Branch already exists

**Symptom**:
```
fatal: A branch named 'feat/deploy-paymentservice-dev-1.1.5.1' already exists
```

**Solution**:
```bash
# Delete old branch
git branch -D feat/deploy-paymentservice-dev-1.1.5.1
git push origin --delete feat/deploy-paymentservice-dev-1.1.5.1

# Try again
just service-deploy dev paymentservice 1.1.5.1
```

---

## Best Practices

### 1. Use Consistent Versioning Strategy

Choose ONE strategy (compound or semantic) and stick with it across all services.

### 2. Document Version Changes

Include clear commit messages:
```bash
feat(dev): deploy paymentservice 1.1.5.1

- Fixed currency conversion rounding issue
- Updated Stripe SDK to v12.3.0
- Improved error handling for declined cards
```

### 3. Test in Dev First

Always deploy to dev → qa → prod:
```bash
# Dev testing
just service-deploy dev paymentservice 1.1.5.1

# QA validation
just service-deploy qa paymentservice 1.1.5.1

# Production release
just service-deploy prod paymentservice 1.1.5.1
```

### 4. Link to Work Items

ServiceNow change requests automatically link to GitHub issues when created by `just service-deploy`.

### 5. Track Service Dependencies

If updating one service requires updating another:
```bash
# Update backend service first
just service-deploy dev paymentservice 1.1.5.1

# Then update dependent service
just service-deploy dev checkoutservice 1.1.5.1
```

---

## Files Modified

### New Files Created

1. **`scripts/bump-service-version.sh`**
   - Updates single service version in kustomization.yaml
   - Validates service name
   - Shows diff of changes

2. **`justfile`** (new recipes)
   - `service-deploy` - Deploy single service with PR workflow
   - `service-versions` - Show current versions
   - `service-list` - List all services

3. **`docs/SERVICE-SPECIFIC-VERSIONING.md`** (this file)
   - Complete documentation
   - Examples and use cases
   - Troubleshooting guide

---

## Related Documentation

- [GitHub-ServiceNow Integration](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [ServiceNow Change Automation](SERVICENOW-CHANGE-AUTOMATION.md)
- [Kustomize Multi-Environment](../kustomize/overlays/README.md)
- [Justfile Commands](../justfile)

---

## Summary

**Service-specific versioning enables**:
- ✅ Independent microservice deployments
- ✅ Granular ServiceNow change requests
- ✅ Realistic production patterns
- ✅ Clear audit trail per service
- ✅ Flexible versioning strategies

**Commands to remember**:
```bash
just service-list              # List all services
just service-versions dev      # Show current versions
just service-deploy dev paymentservice 1.1.5.1  # Deploy service
```

This feature is essential for demonstrating enterprise-grade DevOps and ServiceNow change management integration! 🚀
