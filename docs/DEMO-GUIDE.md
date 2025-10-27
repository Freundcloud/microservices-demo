# Complete Demo Guide - Microservices CI/CD with ServiceNow

> **Quick Access**: Application URL: http://k8s-istiosys-istioing-96ccd20999-398bdeb804671745.elb.eu-west-2.amazonaws.com

This guide walks through demonstrating the complete CI/CD pipeline with ServiceNow DevOps integration, automated promotions, and security scanning.

## Table of Contents

1. [Pre-Demo Setup](#pre-demo-setup)
2. [Demo Scenario 1: Full Version Bump (All Services)](#demo-scenario-1-full-version-bump-all-services)
3. [Demo Scenario 2: Service-Specific Update](#demo-scenario-2-service-specific-update)
4. [Demo Scenario 3: Automated Promotion Pipeline](#demo-scenario-3-automated-promotion-pipeline)
5. [Observability & Monitoring](#observability--monitoring)
6. [Troubleshooting](#troubleshooting)

---

## Pre-Demo Setup

### 1. Verify Cluster Health

```bash
# Check all pods are running
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod

# Expected: All pods should be 2/2 Ready (except adservice/recommendationservice due to node affinity)

# Check application is accessible
curl -I http://k8s-istiosys-istioing-96ccd20999-398bdeb804671745.elb.eu-west-2.amazonaws.com
# Expected: HTTP 200 OK
```

### 2. Verify ServiceNow Integration (Optional)

**If you haven't set up ServiceNow secrets yet**, you can still run the demo! The workflows will:
- ✅ Build and deploy successfully
- ✅ Run all security scans
- ⚠️ Skip ServiceNow integration steps (with warnings)

**To enable ServiceNow integration**, add these secrets to GitHub:
- Go to: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions
- Add: `SN_DEVOPS_USER`, `SN_DEVOPS_PASSWORD`, `SN_INSTANCE_URL`, `SN_ORCHESTRATION_TOOL_ID`
- See: [docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md](SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md)

### 3. Open Browser Tabs

For the best demo experience, open these tabs:

1. **Application**: http://k8s-istiosys-istioing-96ccd20999-398bdeb804671745.elb.eu-west-2.amazonaws.com
2. **GitHub Actions**: https://github.com/Freundcloud/microservices-demo/actions
3. **GitHub Security**: https://github.com/Freundcloud/microservices-demo/security
4. **Kiali Dashboard** (optional): `just istio-kiali` or `kubectl port-forward svc/kiali -n istio-system 20001:20001`
5. **ServiceNow** (if configured): Your ServiceNow instance URL

---

## Demo Scenario 1: Full Version Bump (All Services)

**Use Case**: Demonstrating a coordinated release of all microservices with automated deployment across environments.

### Step 1: Check Current Version

```bash
# Check current version
cat VERSION
# Output: 1.1.6 (or current version)

# Check current service versions
just service-versions dev
```

### Step 2: Bump Version (All Services)

```bash
# Bump to next version (e.g., 1.1.6 → 1.1.7)
just demo-run dev 1.1.7
```

**What this does**:
1. ✅ Updates VERSION file
2. ✅ Updates all Kustomize overlays (dev/qa/prod)
3. ✅ Creates feature branch: `feat/version-bump-dev-1.1.7`
4. ✅ Commits changes
5. ✅ Creates Pull Request with detailed description
6. ✅ Adds `auto-merge` label

### Step 3: Watch the Automation

**GitHub Actions will automatically**:

1. **Pull Request Created** (< 1 min)
   - CI/CD validation starts
   - Security scans run (CodeQL, Trivy, Checkov, etc.)
   - Show GitHub Actions tab: https://github.com/Freundcloud/microservices-demo/actions

2. **Auto-Merge** (2-5 mins)
   - After all checks pass, PR auto-merges
   - Show: Auto-merge workflow in Actions

3. **Master Pipeline Triggered** (5-15 mins)
   - Builds all 12 Docker images
   - Pushes to ECR with version tags
   - Deploys to DEV environment
   - Show: Master CI/CD Pipeline workflow

4. **ServiceNow Integration** (if configured)
   - Creates Change Request automatically
   - Attaches build artifacts
   - Registers test results
   - Show: ServiceNow Change Request

### Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n microservices-dev

# Check image versions
kubectl get pods -n microservices-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Expected: All images should have :1.1.7 tag

# Test the application
curl http://k8s-istiosys-istioing-96ccd20999-398bdeb804671745.elb.eu-west-2.amazonaws.com
# Or open in browser
```

### Key Talking Points

1. **Automation**: "Notice how we only ran ONE command, and the entire pipeline automated everything else"
2. **Security**: "Every deployment goes through 10+ security scanners automatically"
3. **Traceability**: "Every change has a GitHub issue, PR, and ServiceNow Change Request"
4. **Velocity**: "From version bump to production deployment in minutes, not hours"

---

## Demo Scenario 2: Service-Specific Update

**Use Case**: Demonstrating independent microservice deployment (e.g., hotfix for payment service).

### Step 1: Update Single Service

```bash
# Bump just the payment service (1.1.7 → 1.1.7.1)
just service-deploy dev paymentservice 1.1.7.1
```

**What this does**:
1. ✅ Updates ONLY paymentservice in Kustomize overlays
2. ✅ Creates feature branch: `feat/service-paymentservice-1.1.7.1`
3. ✅ Creates GitHub issue for tracking
4. ✅ Creates Pull Request with issue reference
5. ✅ Auto-merge enabled

### Step 2: Watch Selective Build

**GitHub Actions intelligently**:
1. **Detects Changed Service**: Only `paymentservice` changed
2. **Builds Single Image**: Only rebuilds `paymentservice:1.1.7.1`
3. **Deploys to DEV**: Updates ONLY payment service pod
4. **ServiceNow**: Creates CR for single service update

```bash
# Verify only paymentservice was updated
kubectl get pods -n microservices-dev -l app=paymentservice -o jsonpath='{.items[0].spec.containers[0].image}'
# Expected: paymentservice:1.1.7.1

# Check other services unchanged
kubectl get pods -n microservices-dev -l app=frontend -o jsonpath='{.items[0].spec.containers[0].image}'
# Expected: frontend:1.1.7 (unchanged)
```

### Key Talking Points

1. **Independence**: "Each microservice can be deployed independently"
2. **Efficiency**: "Only builds what changed - saves time and resources"
3. **Risk Reduction**: "Smaller blast radius - only one service is updated"
4. **ServiceNow Integration**: "Separate Change Request for each service update"

---

## Demo Scenario 3: Automated Promotion Pipeline

**Use Case**: Demonstrating dev → qa → prod promotion with approval gates.

### Step 1: Promote to All Environments

```bash
# Start full promotion (dev → qa → prod)
just promote-all 1.1.8

# Confirm when prompted
```

**What this does**:
1. ✅ Creates version bump PR (auto-merges)
2. ✅ Deploys to DEV automatically
3. ✅ Waits for DEV success
4. ✅ Auto-promotes to QA
5. ⚠️ Waits for manual approval for PROD
6. ✅ Creates GitHub release tag

### Step 2: Monitor Progress

```bash
# Check deployment status across environments
just promotion-status 1.1.8

# Output shows:
# - DEV: ✅ Deployed
# - QA: ⏳ In Progress
# - PROD: ⏸️ Waiting for approval
```

**In GitHub Actions**:
- Show: "Full Promotion Pipeline" workflow
- Show: Each environment deployment in real-time
- Show: Manual approval step for production

### Step 3: Approve Production Deployment

**Option 1: GitHub UI**
1. Go to: https://github.com/Freundcloud/microservices-demo/actions
2. Find "Full Promotion Pipeline" workflow
3. Click on the run
4. Click "Review deployments"
5. Select "production" environment
6. Click "Approve and deploy"

**Option 2: ServiceNow** (if configured)
1. Open ServiceNow Change Request
2. Review test results and security scans
3. Approve the change
4. GitHub Actions continues automatically

### Step 4: Verify Production Deployment

```bash
# Check production pods
kubectl get pods -n microservices-prod

# Check image versions in prod
kubectl get pods -n microservices-prod -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' | grep -v istio
# Expected: All images tagged with :1.1.8
```

### Key Talking Points

1. **Progressive Delivery**: "Changes flow through environments automatically"
2. **Approval Gates**: "Production requires manual approval - safety first"
3. **Rollback Ready**: "Every deployment creates a GitHub release for easy rollback"
4. **Audit Trail**: "Complete history from commit to production in ServiceNow"

---

## Observability & Monitoring

### View Service Mesh Topology

```bash
# Open Kiali dashboard
just istio-kiali
# Opens at: http://localhost:20001

# Navigate to: Graph → Namespace: microservices-dev
# Select: Versioned app graph
```

**Show**:
- Real-time traffic flow between services
- Request rates and latencies
- Error rates
- mTLS status (all connections encrypted)

### View Metrics

```bash
# Open Grafana
just istio-grafana
# Opens at: http://localhost:3000

# Pre-configured dashboards:
# - Istio Mesh Dashboard
# - Istio Service Dashboard
# - Istio Workload Dashboard
```

### View Distributed Tracing

```bash
# Open Jaeger
just istio-jaeger
# Opens at: http://localhost:16686

# Search for: frontend service
# Show: Complete request trace across all 12 microservices
```

---

## Demonstrating Security Features

### 1. Show Security Scans

```bash
# Open GitHub Security tab
open https://github.com/Freundcloud/microservices-demo/security

# Show:
# - Code scanning alerts (CodeQL)
# - Dependency vulnerabilities (Grype)
# - Secret scanning
# - Infrastructure security (Checkov/tfsec)
```

### 2. View SBOM (Software Bill of Materials)

```bash
# Download SBOM artifact from latest workflow run
gh run list --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run download

# Show: Complete list of all dependencies with versions
cat sbom.cyclonedx.json | jq '.components[] | {name, version}' | head -20
```

### 3. Demonstrate Zero-Trust Security

**Show in Kiali**:
- All service-to-service traffic uses mTLS (padlock icons)
- No plaintext communication
- Strict authorization policies

```bash
# Show mTLS configuration
kubectl get peerauthentication -n istio-system

# Expected: STRICT mode enabled globally
```

---

## Troubleshooting Common Demo Issues

### Issue: Pods Pending or CrashLooping

**Symptoms**: Some pods stuck in Pending or CrashLoopBackOff state

**Common Causes**:
1. Node affinity issues (adservice, recommendationservice)
2. Resource constraints (insufficient CPU/memory)
3. Image pull errors

**Quick Fix**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n microservices-dev

# Common fix: Restart deployment
kubectl rollout restart deployment/<deployment-name> -n microservices-dev

# Nuclear option: Delete pending pods
kubectl delete pod <pod-name> -n microservices-dev --force --grace-period=0
```

### Issue: Application Not Accessible

**Check Load Balancer**:
```bash
# Get load balancer URL
kubectl get svc -n istio-system istio-ingressgateway

# Check if EXTERNAL-IP is pending (takes 2-3 minutes)
# If stuck, check AWS ELB console
```

**Check Gateway Configuration**:
```bash
# Verify Istio Gateway exists
kubectl get gateway -n microservices-dev

# Verify VirtualService routing
kubectl get virtualservice -n microservices-dev
```

### Issue: ServiceNow Integration Not Working

**Symptoms**: Workflows succeed but no Change Requests created

**Check Secrets**:
```bash
# Verify secrets exist
gh secret list --repo Freundcloud/microservices-demo

# Expected: SN_DEVOPS_USER, SN_DEVOPS_PASSWORD, SN_INSTANCE_URL, SN_ORCHESTRATION_TOOL_ID
```

**Quick Fix**:
- ServiceNow integration is optional
- Workflows work without it (just skip those steps)
- See: [docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md](SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md)

### Issue: Auto-Merge Not Working

**Check Labels**:
```bash
# PR must have 'auto-merge' label
gh pr list --label auto-merge

# Manually trigger:
gh pr merge <PR-number> --auto --merge
```

---

## Demo Script (5-Minute Version)

**Intro** (30 seconds):
"I'll show you our complete CI/CD pipeline with automated testing, security scanning, and ServiceNow integration. Watch how one command deploys across all environments."

**Demo** (3 minutes):
1. Run: `just demo-run dev 1.2.0`
2. Show GitHub Actions (workflows running in parallel)
3. Show Security tab (scans completing)
4. Show application updating (refresh browser)
5. Show ServiceNow Change Request (if configured)

**Key Points** (1 minute):
- "12 microservices, 10+ security scans, 3 environments - all automated"
- "From commit to production in minutes with approval gates"
- "Complete audit trail in ServiceNow for compliance"

**Outro** (30 seconds):
"Questions? Let me show you the observability with Istio/Kiali..."

---

## Advanced Demo Scenarios

### Scenario: Rollback Demo

```bash
# Show current version
kubectl get pods -n microservices-prod -o jsonpath='{.items[0].spec.containers[0].image}'

# Rollback to previous version
kubectl rollout undo deployment/frontend -n microservices-prod

# Or use specific version
kubectl set image deployment/frontend server=<ECR-URL>/frontend:1.1.6 -n microservices-prod
```

### Scenario: Chaos Engineering

```bash
# Delete a pod and show auto-healing
kubectl delete pod -n microservices-dev -l app=frontend

# Watch pod restart
kubectl get pods -n microservices-dev -l app=frontend -w

# Show in Kiali: Service continues working (1/2 pods still healthy)
```

### Scenario: Load Testing

```bash
# Deploy load generator to QA
kubectl apply -k kustomize/components/service-load-generator -n microservices-qa

# Watch traffic in Kiali
just istio-kiali

# Show: Request rates increase, latencies, error rates
```

---

## Quick Reference

### Essential Commands

| Task | Command |
|------|---------|
| Bump all services | `just demo-run dev 1.X.X` |
| Bump single service | `just service-deploy dev <service> 1.X.X.X` |
| Full promotion | `just promote-all 1.X.X` |
| Check versions | `just service-versions dev` |
| View application | http://k8s-istiosys-istioing-96ccd20999-398bdeb804671745.elb.eu-west-2.amazonaws.com |
| Kiali dashboard | `just istio-kiali` |
| GitHub Actions | https://github.com/Freundcloud/microservices-demo/actions |
| GitHub Security | https://github.com/Freundcloud/microservices-demo/security |

### Environment Namespaces

- **Dev**: `microservices-dev` (1 replica, minimal resources)
- **QA**: `microservices-qa` (1 replica, load generator enabled)
- **Prod**: `microservices-prod` (1 replica, no load generator)

### Service List

1. frontend
2. cartservice
3. productcatalogservice
4. currencyservice
5. paymentservice
6. shippingservice
7. emailservice
8. checkoutservice
9. recommendationservice
10. adservice
11. loadgenerator (optional)
12. shoppingassistantservice

---

## Post-Demo Cleanup (Optional)

```bash
# Scale down to save costs
kubectl scale deployment --all --replicas=0 -n microservices-qa
kubectl scale deployment --all --replicas=0 -n microservices-prod

# Keep dev running for next demo
# kubectl scale deployment --all --replicas=1 -n microservices-dev
```

---

## Resources

- **Complete Documentation**: [docs/README.md](README.md)
- **ServiceNow Setup**: [docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md](SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md)
- **Automated Promotion**: [docs/AUTOMATED-PROMOTION-PIPELINE.md](AUTOMATED-PROMOTION-PIPELINE.md)
- **Service Versioning**: [docs/SERVICE-SPECIFIC-VERSIONING.md](SERVICE-SPECIFIC-VERSIONING.md)
- **Cost Optimization**: [docs/COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)

---

**Ready to demo?** Start with: `just demo-run dev 1.2.0` 🚀
