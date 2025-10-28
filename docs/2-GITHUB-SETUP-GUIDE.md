# GitHub Setup Guide - CI/CD & Workflows

> **Purpose**: Configure GitHub Actions, secrets, and automated CI/CD workflows
> **Time**: 20-30 minutes
> **Prerequisites**: GitHub account, repository forked/cloned, AWS infrastructure deployed

## 📋 Table of Contents

1. [Fork or Clone Repository](#fork-or-clone-repository)
2. [Configure GitHub Secrets](#configure-github-secrets)
3. [Understand Workflows](#understand-workflows)
4. [Build and Push Container Images](#build-and-push-container-images)
5. [Deploy Application to Kubernetes](#deploy-application-to-kubernetes)
6. [Verify Deployment](#verify-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Fork or Clone Repository

### Option 1: Fork Repository (Recommended)

**Why**: Allows you to customize and push changes

1. Go to: https://github.com/Freundcloud/microservices-demo
2. Click "Fork" button (top right)
3. Select your account
4. Wait for fork to complete

Then clone your fork:

```bash
git clone https://github.com/YOUR-USERNAME/microservices-demo.git
cd microservices-demo
```

### Option 2: Clone Directly

**Why**: Quick start, read-only

```bash
git clone https://github.com/Freundcloud/microservices-demo.git
cd microservices-demo
```

---

## Configure GitHub Secrets

GitHub Actions workflows require secrets to access AWS and ServiceNow. Let's configure them.

### 1. Navigate to Secrets Settings

1. Open your repository on GitHub
2. Click "Settings" tab
3. Left sidebar → "Secrets and variables" → "Actions"
4. Click "New repository secret"

### 2. Add AWS Credentials

These allow GitHub Actions to push images to ECR and deploy to EKS.

**AWS_ACCESS_KEY_ID**:
- Name: `AWS_ACCESS_KEY_ID`
- Value: Your AWS access key (from [AWS Deployment Guide](1-AWS-DEPLOYMENT-GUIDE.md))
- Example: `AKIAIOSFODNN7EXAMPLE`

**AWS_SECRET_ACCESS_KEY**:
- Name: `AWS_SECRET_ACCESS_KEY`
- Value: Your AWS secret key
- Example: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

**AWS_REGION**:
- Name: `AWS_REGION`
- Value: `eu-west-2` (or your region)

**AWS_ACCOUNT_ID**:
- Name: `AWS_ACCOUNT_ID`
- Value: Your 12-digit AWS account ID
- Find it: `aws sts get-caller-identity --query Account --output text`
- Example: `123456789012`

### 3. Add Cluster Configuration

**EKS_CLUSTER_NAME**:
- Name: `EKS_CLUSTER_NAME`
- Value: `microservices`

### 4. Optional: Add ServiceNow Credentials

These are needed for ServiceNow integration (configured in [ServiceNow Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)):

**SERVICENOW_INSTANCE_URL**:
- Name: `SERVICENOW_INSTANCE_URL`
- Value: `https://your-instance.service-now.com`
- Skip for now if not using ServiceNow

**SERVICENOW_USERNAME**:
- Name: `SERVICENOW_USERNAME`
- Value: ServiceNow integration user
- Skip for now

**SERVICENOW_PASSWORD**:
- Name: `SERVICENOW_PASSWORD`
- Value: ServiceNow user password
- Skip for now

**SN_ORCHESTRATION_TOOL_ID**:
- Name: `SN_ORCHESTRATION_TOOL_ID`
- Value: Tool ID from ServiceNow (see ServiceNow guide)
- Skip for now

### 5. Verify Secrets

Your secrets page should show:

```
✅ AWS_ACCESS_KEY_ID         Updated X minutes ago
✅ AWS_SECRET_ACCESS_KEY     Updated X minutes ago
✅ AWS_REGION               Updated X minutes ago
✅ AWS_ACCOUNT_ID           Updated X minutes ago
✅ EKS_CLUSTER_NAME         Updated X minutes ago
```

ServiceNow secrets (optional):
```
⚠️ SERVICENOW_INSTANCE_URL  (add when ready)
⚠️ SERVICENOW_USERNAME       (add when ready)
⚠️ SERVICENOW_PASSWORD       (add when ready)
⚠️ SN_ORCHESTRATION_TOOL_ID  (add when ready)
```

---

## Understand Workflows

GitHub Actions workflows are defined in `.github/workflows/`. Here are the main ones:

### Master Pipeline (MASTER-PIPELINE.yaml)

**Purpose**: Complete CI/CD pipeline for all environments

**Triggers**:
- Push to `main` branch
- Manual trigger via workflow_dispatch
- Pull request merge

**What it does**:
1. Code validation (YAML lint, Kustomize validation)
2. Security scanning (10+ scanners)
3. Detect changed services (smart builds)
4. Build Docker images (only changed services)
5. Push to ECR
6. Deploy to Kubernetes
7. Create ServiceNow Change Request (if configured)
8. Update ServiceNow with results

**Environments**: dev, qa, prod

### Build Images Workflow (build-images.yaml)

**Purpose**: Build and push Docker images to ECR

**Triggers**:
- Called by MASTER-PIPELINE
- Manual trigger for specific services

**What it does**:
1. Detects which services changed
2. Builds only changed services (saves time!)
3. Multi-architecture builds (amd64, arm64)
4. Scans with Trivy for vulnerabilities
5. Generates SBOM
6. Pushes to ECR with version tags

### Security Scan Workflow (security-scan.yaml)

**Purpose**: Comprehensive security scanning

**Scanners**:
1. CodeQL (5 languages)
2. Grype (dependency vulnerabilities)
3. Trivy (container scanning)
4. Semgrep (SAST)
5. OWASP Dependency Check
6. Checkov (IaC security)
7. tfsec (Terraform security)
8. Kubesec (Kubernetes manifests)
9. Polaris (K8s best practices)
10. License compliance

**Results**: Uploaded to GitHub Security tab

### Deploy Environment Workflow (deploy-environment.yaml)

**Purpose**: Deploy to specific environment

**Parameters**:
- `environment`: dev, qa, or prod
- Deploys Kustomize overlays to target namespace

---

## Build and Push Container Images

### Option 1: Automatic Build (Recommended)

**Trigger**: Push to main branch

```bash
# Make any change
echo "# Test" >> README.md
git add README.md
git commit -m "test: Trigger build"
git push origin main
```

**Watch the workflow**:
1. Go to: https://github.com/YOUR-USERNAME/microservices-demo/actions
2. Click on "🚀 Master CI/CD Pipeline"
3. Watch build progress

### Option 2: Manual Build

**Trigger specific workflow**:

```bash
# Install GitHub CLI
gh auth login

# Trigger master pipeline for dev
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Watch progress
gh run watch
```

### Option 3: Local Build (For Testing)

Build images locally before pushing:

```bash
# Build single service
just docker-build frontend

# Build all services
just docker-build-all

# Login to ECR
just ecr-login

# Push single service
just ecr-push frontend dev

# Tag: 123456789012.dkr.ecr.eu-west-2.amazonaws.com/frontend:dev
```

### Build Progress

The build process:

1. **Smart Detection** (30 seconds)
   - Checks which services changed
   - Only rebuilds changed services
   - Saves time and GitHub Actions minutes

2. **Docker Build** (5-10 minutes per service)
   - Multi-stage builds for optimization
   - Compiles dependencies
   - Creates final image

3. **Security Scan** (1-2 minutes per service)
   - Trivy scans for vulnerabilities
   - Generates SBOM
   - Fails build if critical vulnerabilities found

4. **Push to ECR** (1-2 minutes per service)
   - Tags with version (dev/qa/prod or semantic version)
   - Pushes to AWS ECR
   - Updates image manifest

**Total Time**: 10-20 minutes (depending on which services changed)

---

## Deploy Application to Kubernetes

### Option 1: Automatic Deployment

After images are built, the master pipeline automatically deploys to the target environment.

**Monitor deployment**:

```bash
# Watch pods starting
kubectl get pods -n microservices-dev --watch

# Check deployment status
kubectl get deployments -n microservices-dev

# View logs
kubectl logs -l app=frontend -n microservices-dev --tail=50
```

### Option 2: Manual Deployment

Deploy using Kustomize overlays:

```bash
# Deploy to dev
kubectl apply -k kustomize/overlays/dev

# Deploy to qa
kubectl apply -k kustomize/overlays/qa

# Deploy to prod
kubectl apply -k kustomize/overlays/prod
```

### Option 3: Using Justfile

```bash
# Deploy using kubectl
just k8s-deploy

# Deploy specific environment with Kustomize
kubectl apply -k kustomize/overlays/dev
```

### Deployment Progress

Watch deployments roll out:

```bash
# Watch all pods in dev
kubectl get pods -n microservices-dev -w

# Check rollout status
kubectl rollout status deployment/frontend -n microservices-dev

# View deployment events
kubectl get events -n microservices-dev --sort-by='.metadata.creationTimestamp'
```

Expected pod states:
```
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-xxx                            1/1     Running   0          2m
cartservice-xxx                          1/1     Running   0          2m
checkoutservice-xxx                      1/1     Running   0          2m
currencyservice-xxx                      1/1     Running   0          2m
emailservice-xxx                         1/1     Running   0          2m
frontend-xxx                             1/1     Running   0          2m
loadgenerator-xxx                        1/1     Running   0          2m
paymentservice-xxx                       1/1     Running   0          2m
productcatalogservice-xxx                1/1     Running   0          2m
recommendationservice-xxx                1/1     Running   0          2m
redis-cart-xxx                           1/1     Running   0          2m
shippingservice-xxx                      1/1     Running   0          2m
```

---

## Verify Deployment

### 1. Check Pods

```bash
# All pods should be Running
kubectl get pods -n microservices-dev

# Check pod details
kubectl describe pod -n microservices-dev -l app=frontend
```

### 2. Check Services

```bash
# List all services
kubectl get svc -n microservices-dev

# Should see ClusterIP services for each microservice
```

### 3. Check Ingress

```bash
# Get ALB ingress URL
kubectl get ingress frontend-ingress -n microservices-dev

# Copy the ADDRESS (ALB hostname)
```

### 4. Access Application

```bash
# Get URL
FRONTEND_URL=$(kubectl get ingress frontend-ingress -n microservices-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://$FRONTEND_URL"

# Test in browser or curl
curl -I http://$FRONTEND_URL
```

Expected response:
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
...
```

### 5. Open in Browser

Visit: `http://<ALB-HOSTNAME>`

You should see the **Online Boutique** storefront!

---

## Workflow Customization

### Modify Build Behavior

Edit `.github/workflows/build-images.yaml`:

```yaml
# Change which services to build
- name: Detect Changed Services
  id: changes
  uses: dorny/paths-filter@v2
  with:
    filters: |
      frontend:
        - 'src/frontend/**'
      cartservice:
        - 'src/cartservice/**'
      # Add more services...
```

### Add Custom Environment

1. Create new Kustomize overlay:
   ```bash
   cp -r kustomize/overlays/dev kustomize/overlays/staging
   ```

2. Update `kustomize/overlays/staging/kustomization.yaml`:
   ```yaml
   namespace: microservices-staging
   nameSuffix: -staging
   commonLabels:
     environment: staging
   ```

3. Update workflow to support staging environment

### Customize Deployment

Edit `kustomize/overlays/dev/` (or qa/prod):

**Change replica counts**:
```yaml
# kustomize/overlays/dev/replica-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2  # Increase from 1
```

**Change resource limits**:
```yaml
# kustomize/overlays/dev/resource-limits.yaml
spec:
  template:
    spec:
      containers:
      - name: server
        resources:
          requests:
            cpu: 200m      # Increase from 100m
            memory: 128Mi  # Increase from 64Mi
```

---

## Troubleshooting

### Issue: Workflow fails with "AWS authentication failed"

**Error**: `Error: The security token included in the request is invalid`

**Solutions**:

```bash
# Verify secrets are set
gh secret list

# Check AWS credentials locally
aws sts get-caller-identity

# Re-add AWS secrets with correct values
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "wJalr..."
```

### Issue: "Permission denied" when pushing to ECR

**Error**: `denied: User: ... is not authorized to perform: ecr:PutImage`

**Solutions**:

```bash
# Verify AWS account ID is correct
gh secret set AWS_ACCOUNT_ID --body "$(aws sts get-caller-identity --query Account --output text)"

# Verify IAM user has ECR permissions
aws iam list-attached-user-policies --user-name terraform-deploy

# Should include: AmazonEC2ContainerRegistryFullAccess or custom policy
```

### Issue: Build fails with "No space left on device"

**Error**: `ERROR: failed to solve: ... no space left on device`

**Cause**: GitHub Actions runner out of disk space

**Solutions**:

Add cleanup step to workflow:

```yaml
- name: Clean up disk space
  run: |
    docker system prune -af
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
```

### Issue: Deployment stuck in "ContainerCreating"

**Error**: Pods remain in ContainerCreating state

**Solutions**:

```bash
# Check pod events
kubectl describe pod <pod-name> -n microservices-dev

# Common causes:
# 1. Image pull error
kubectl get events -n microservices-dev | grep Failed

# 2. Insufficient resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 3. Volume mount issues
kubectl get pv,pvc -n microservices-dev
```

### Issue: Image not found in ECR

**Error**: `Failed to pull image ... repository does not exist`

**Solutions**:

```bash
# List ECR repositories
aws ecr describe-repositories --region eu-west-2

# Verify image exists
aws ecr list-images --repository-name frontend --region eu-west-2

# If missing, trigger manual build
gh workflow run build-images.yaml
```

### Issue: Security scan failures blocking deployment

**Error**: `Critical vulnerability found: CVE-...`

**Solutions**:

```yaml
# Option 1: Fix vulnerability (update dependencies)
# Edit src/<service>/package.json or requirements.txt

# Option 2: Temporarily allow (not recommended for prod)
# Edit .github/workflows/build-images.yaml
- name: Run Trivy Scanner
  uses: aquasecurity/trivy-action@master
  with:
    exit-code: '0'  # Change from '1' to '0' (don't fail build)
```

### Issue: Workflow runs but does nothing

**Error**: Workflow succeeds but doesn't build/deploy

**Cause**: Smart detection thinks nothing changed

**Solutions**:

```bash
# Force rebuild all services
gh workflow run MASTER-PIPELINE.yaml -f environment=dev -f force_build_all=true

# Or manually rebuild specific service
gh workflow run build-images.yaml
```

---

## Advanced: GitHub Actions Best Practices

### Use Caching

Speed up builds by caching dependencies:

```yaml
- name: Cache npm dependencies
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

### Matrix Builds

Build multiple services in parallel:

```yaml
strategy:
  matrix:
    service: [frontend, cartservice, productcatalogservice]
steps:
  - name: Build ${{ matrix.service }}
    run: docker build -t ${{ matrix.service }} src/${{ matrix.service }}
```

### Conditional Execution

Run steps only when needed:

```yaml
- name: Deploy to Production
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: kubectl apply -k kustomize/overlays/prod
```

---

## Next Steps

✅ **GitHub CI/CD Configured!**

Now proceed to:

1. **[ServiceNow Integration Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)**
   - Install ServiceNow DevOps plugin
   - Configure automated change management
   - Link work items and test results

2. **Demo the Integration**
   - Use `just promote 1.0.0 all` for automated promotion
   - Show GitHub Actions + ServiceNow integration
   - Present to stakeholders

---

## Reference

### Useful GitHub CLI Commands

```bash
# List workflows
gh workflow list

# Run workflow manually
gh workflow run MASTER-PIPELINE.yaml

# Watch latest run
gh run watch

# List recent runs
gh run list --limit 10

# View run logs
gh run view <run-id> --log

# Re-run failed workflow
gh run rerun <run-id>
```

### Environment URLs

```bash
# Get ALB URLs for all environments
echo "DEV:  http://$(kubectl get ingress frontend-ingress -n microservices-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "QA:   http://$(kubectl get ingress frontend-ingress -n microservices-qa -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "PROD: http://$(kubectl get ingress frontend-ingress -n microservices-prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

---

**Estimated Time**: 20-30 minutes (including build time)

**Ready?** Start with [Configure GitHub Secrets](#configure-github-secrets)! 🚀
