# Release Process - Online Boutique

**Version**: 1.0
**Created**: 2025-10-17
**Release Model**: GitFlow-inspired with release branches

---

## Release Versioning

We use **Semantic Versioning** (SemVer):

```
MAJOR.MINOR.PATCH
  1  .  0  .  0
```

- **MAJOR**: Incompatible API changes, major features
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

### Examples:
- `v1.0.0` - Initial production release
- `v1.0.1` - Hotfix for v1.0.0
- `v1.1.0` - New features added to v1.0
- `v2.0.0` - Major breaking changes

---

## Branch Strategy

### Main Branches

```
main                    # Stable, production-ready code
  ├── release/1.0      # v1.0.x releases (v1.0.0, v1.0.1, etc.)
  ├── release/2.0      # v2.0.x releases (future)
  └── develop          # (Optional) development branch
```

### Release Branch Naming

- **Format**: `release/MAJOR.MINOR`
- **Examples**: `release/1.0`, `release/1.1`, `release/2.0`

### Tag Naming

- **Format**: `vMAJOR.MINOR.PATCH`
- **Examples**: `v1.0.0`, `v1.0.1`, `v1.1.0`

---

## Release Process

### Phase 1: Create Release Branch

```bash
# From main branch
git checkout main
git pull origin main

# Create release branch
git checkout -b release/1.0

# Push to remote
git push -u origin release/1.0
```

### Phase 2: Update Version Information

Update version in relevant files:
- `VERSION` file (create if doesn't exist)
- Kubernetes manifests (labels, annotations)
- Documentation references

```bash
echo "1.0.0" > VERSION
git add VERSION
git commit -m "chore: Set version to 1.0.0"
```

### Phase 3: Create Git Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial Production Release

Features:
- 11 microservices (Go, Python, Java, Node.js, C#)
- AWS EKS deployment with Istio service mesh
- Multi-environment support (dev/qa/prod)
- ServiceNow change management integration
- Security scanning (8 tools)
- Kustomize-based deployments
- GitHub Actions CI/CD"

# Push tag
git push origin v1.0.0
```

### Phase 4: Build Release Images

```bash
# Build all services with v1.0.0 tag
just docker-build-all

# Tag images for ECR with version
for service in frontend cartservice productcatalogservice currencyservice \
               paymentservice shippingservice emailservice checkoutservice \
               recommendationservice adservice loadgenerator; do
  docker tag $service:latest \
    $ECR_REGISTRY/$service:v1.0.0
  docker tag $service:latest \
    $ECR_REGISTRY/$service:1.0.0
  docker tag $service:latest \
    $ECR_REGISTRY/$service:1.0
  docker tag $service:latest \
    $ECR_REGISTRY/$service:prod
done

# Push to ECR
just ecr-login
for service in ...; do
  docker push $ECR_REGISTRY/$service:v1.0.0
  docker push $ECR_REGISTRY/$service:1.0.0
  docker push $ECR_REGISTRY/$service:1.0
  docker push $ECR_REGISTRY/$service:prod
done
```

### Phase 5: Update Kustomize for Production

Update `kustomize/overlays/prod/kustomization.yaml`:

```yaml
images:
  - name: frontend
    newName: YOUR_ECR_REGISTRY/frontend
    newTag: v1.0.0
  - name: cartservice
    newName: YOUR_ECR_REGISTRY/cartservice
    newTag: v1.0.0
  # ... for all services
```

Commit changes:
```bash
git add kustomize/overlays/prod/kustomization.yaml
git commit -m "chore(prod): Update images to v1.0.0"
git push
```

### Phase 6: Create GitHub Release

1. Go to: https://github.com/Freundcloud/microservices-demo/releases
2. Click: **Draft a new release**
3. Choose tag: `v1.0.0`
4. Release title: `v1.0.0 - Initial Production Release`
5. Add release notes (see template below)
6. Mark as "latest release"
7. Publish release

### Phase 7: Deploy to Production

```bash
# Using ServiceNow change management
gh workflow run deploy-with-servicenow-hybrid.yaml \
  --field environment=prod

# Or using Kustomize directly
kubectl apply -k kustomize/overlays/prod
```

---

## Release Notes Template

```markdown
# v1.0.0 - Initial Production Release

**Release Date**: 2025-10-17
**Branch**: release/1.0
**Commit**: [SHA]

## 🎉 What's New

This is the initial production release of Online Boutique on AWS EKS.

## ✨ Features

### Microservices (11 services)
- **Frontend** (Go) - Web UI and HTTP server
- **CartService** (C#) - Shopping cart with Redis
- **ProductCatalogService** (Go) - Product inventory management
- **CurrencyService** (Node.js) - Multi-currency support
- **PaymentService** (Node.js) - Payment processing
- **ShippingService** (Go) - Shipping cost calculation
- **EmailService** (Python) - Order confirmation emails
- **CheckoutService** (Go) - Order orchestration
- **RecommendationService** (Python) - Product recommendations
- **AdService** (Java) - Contextual advertisements
- **LoadGenerator** (Python/Locust) - Load testing

### Infrastructure
- **AWS EKS**: Kubernetes cluster with 4 node groups (system/dev/qa/prod)
- **Istio Service Mesh**: mTLS, traffic management, observability
- **Amazon ElastiCache Redis**: Managed Redis for cart service
- **AWS ECR**: Container registry with vulnerability scanning
- **Multi-Environment**: Separate namespaces for dev/qa/prod

### CI/CD & DevOps
- **GitHub Actions**: Automated build and deployment pipelines
- **ServiceNow Integration**: Change management with approvals
- **Security Scanning**: 8-tool security suite (Trivy, CodeQL, Semgrep, etc.)
- **Kustomize Deployments**: Multi-environment configuration management
- **SBOM Generation**: Software Bill of Materials for compliance

### Observability
- **Istio Dashboards**: Kiali, Grafana, Prometheus, Jaeger
- **Service Mesh Metrics**: Request rates, latencies, error rates
- **Distributed Tracing**: Full request tracing across services

## 📦 Container Images

All images tagged with `v1.0.0`:
- `frontend:v1.0.0`
- `cartservice:v1.0.0`
- `productcatalogservice:v1.0.0`
- `currencyservice:v1.0.0`
- `paymentservice:v1.0.0`
- `shippingservice:v1.0.0`
- `emailservice:v1.0.0`
- `checkoutservice:v1.0.0`
- `recommendationservice:v1.0.0`
- `adservice:v1.0.0`
- `loadgenerator:v1.0.0`

## 🛠️ Infrastructure

### Terraform Modules
- VPC with 3 availability zones
- EKS cluster with managed node groups
- ElastiCache Redis cluster
- ECR repositories with lifecycle policies
- Istio service mesh via Helm

### Environments
- **Dev**: 1 replica per service, t3.xlarge nodes
- **QA**: 2 replicas per service, t3.2xlarge nodes
- **Prod**: 3 replicas per service, m5.4xlarge nodes

## 📚 Documentation

Complete documentation available in `docs/`:
- Architecture overview
- Deployment guides
- ServiceNow integration
- Development workflows
- Troubleshooting guides

## 🔐 Security

- **mTLS**: All inter-service communication encrypted
- **Network Policies**: Istio authorization policies
- **Image Scanning**: Trivy vulnerability scanning
- **SAST**: CodeQL, Semgrep analysis
- **Secret Detection**: Gitleaks scanning
- **IaC Security**: Checkov, tfsec validation

## 🧪 Testing

- Unit tests for all services
- Integration tests
- Load testing with Locust
- End-to-end validation

## 📊 Deployment

### Kustomize Overlays
```bash
# Production deployment
kubectl apply -k kustomize/overlays/prod
```

### ServiceNow Change Management
```bash
# With change approval workflow
gh workflow run deploy-with-servicenow-hybrid.yaml \
  --field environment=prod
```

## 🐛 Known Issues

None at this time.

## 📝 Breaking Changes

None (initial release).

## ⬆️ Upgrade Notes

Initial release - no upgrades needed.

## 🙏 Contributors

- @olafkfreund
- Claude Code (AI Assistant)

## 📄 License

[Your License]

---

**Full Changelog**: Initial release
```

---

## Hotfix Process (v1.0.1, v1.0.2, etc.)

### When a Bug is Found in Production

1. **Create hotfix branch from release branch**:
   ```bash
   git checkout release/1.0
   git pull origin release/1.0
   git checkout -b hotfix/1.0.1
   ```

2. **Fix the bug**:
   ```bash
   # Make fixes
   git add .
   git commit -m "fix: Critical bug in checkout service"
   ```

3. **Merge to release branch**:
   ```bash
   git checkout release/1.0
   git merge hotfix/1.0.1
   git push origin release/1.0
   ```

4. **Create new tag**:
   ```bash
   git tag -a v1.0.1 -m "Release v1.0.1 - Hotfix for checkout bug"
   git push origin v1.0.1
   ```

5. **Build and deploy**:
   ```bash
   # Build with v1.0.1 tag
   # Update Kustomize to v1.0.1
   # Deploy to production
   ```

6. **Merge back to main**:
   ```bash
   git checkout main
   git merge release/1.0
   git push origin main
   ```

---

## Minor Release Process (v1.1.0)

### When Adding New Features

1. **Develop on main** (or develop branch)
2. **Create new release branch when ready**:
   ```bash
   git checkout main
   git checkout -b release/1.1
   ```
3. **Follow release process** (tag v1.1.0, build, deploy)

---

## Image Tagging Strategy

### Prod Environment

For production, we use **multiple tags** for flexibility:

```bash
# Specific version (most precise)
$ECR_REGISTRY/$service:v1.0.0
$ECR_REGISTRY/$service:1.0.0

# Minor version (gets updates for patches)
$ECR_REGISTRY/$service:1.0

# Environment tag (always latest for prod)
$ECR_REGISTRY/$service:prod

# Latest tag (optional, use with caution)
$ECR_REGISTRY/$service:latest
```

**Recommendation**: Always use specific version tags (v1.0.0) in production Kustomize overlays.

---

## Rollback Strategy

### Rollback to Previous Version

```bash
# Update Kustomize to previous version
cd kustomize/overlays/prod

# Edit kustomization.yaml - change v1.0.1 → v1.0.0
# Then apply
kubectl apply -k .

# Or use kubectl rollout
kubectl rollout undo deployment/frontend -n microservices-prod
```

---

## Release Checklist

Use this checklist for every release:

### Pre-Release
- [ ] All tests passing
- [ ] Security scans clean
- [ ] Documentation updated
- [ ] VERSION file updated
- [ ] CHANGELOG.md updated

### Release Creation
- [ ] Release branch created (`release/X.Y`)
- [ ] Git tag created (`vX.Y.Z`)
- [ ] Images built with version tag
- [ ] Images pushed to ECR
- [ ] Kustomize updated for prod
- [ ] GitHub Release created with notes

### Deployment
- [ ] ServiceNow change request created
- [ ] Change approved (for prod)
- [ ] Deployed to prod
- [ ] All pods running
- [ ] Health checks passing
- [ ] ServiceNow change closed

### Post-Release
- [ ] Release notes published
- [ ] Stakeholders notified
- [ ] Monitoring dashboard checked
- [ ] Release branch merged to main (if needed)

---

## Environment Promotion

```
dev (dev tag)
  ↓ Test & validate
qa (qa tag)
  ↓ QA approval
prod (v1.0.0 tag)
```

### Promotion Process

1. **Dev → QA**:
   ```bash
   # Update kustomize/overlays/qa to use tested commit SHA
   # Or use qa tag
   ```

2. **QA → Prod**:
   ```bash
   # Create release from tested QA deployment
   # Use semantic version tag (v1.0.0)
   # Update kustomize/overlays/prod to use v1.0.0
   ```

---

**Last Updated**: 2025-10-17
**Next Release**: v1.0.0 (target: 2025-10-17)
