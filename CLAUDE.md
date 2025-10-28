# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Online Boutique** is a cloud-native microservices demo application migrated from Google Cloud (GKE) to AWS (EKS). It consists of 12 microservices written in different languages (Go, Python, Java, Node.js, C#) communicating via gRPC, demonstrating modern cloud-native practices on AWS with Istio service mesh.

**Purpose**: Cloud-native microservices demo on AWS
**Infrastructure**: Terraform-managed AWS EKS with Istio service mesh
**CI/CD**: GitHub Actions with comprehensive security scanning

## Essential Commands

### Developer Onboarding
```bash
# First time setup (automated)
just onboard

# Manual setup
source .envrc  # Load AWS credentials (edit .envrc first)
just verify-setup
```

### Infrastructure Management (Terraform)
```bash
# Working with specific environments (dev/qa/prod)
just tf-init              # Initialize Terraform
just tf-plan              # Preview changes
just tf-apply             # Deploy infrastructure (~15 minutes)
just tf-destroy dev           # Destroy infrastructure

# Quality checks
just tf-validate              # Validate configuration
just tf-fmt                   # Format Terraform code
just tf-test                  # Run Terraform tests (in terraform-aws/tests/)
just tf-check                 # Run all quality checks
```

### Kubernetes Operations
```bash
# Configure kubectl for environment
just k8s-config           # or qa, or prod

# Deploy application (traditional)
just k8s-deploy               # Applies release/ and istio-manifests/

# Deploy with Kustomize (multi-environment)
kubectl apply -k kustomize/overlays/dev    # Deploy to dev namespace
kubectl apply -k kustomize/overlays/qa     # Deploy to qa namespace
kubectl apply -k kustomize/overlays/prod   # Deploy to prod namespace

# Manage services
just k8s-status               # Get cluster status
just k8s-logs frontend        # View logs for service
just k8s-restart frontend     # Restart deployment
just k8s-scale frontend 5     # Scale to 5 replicas
just k8s-url                  # Get application URL
```

### Cluster Management & Monitoring
```bash
# Status & Health
just cluster-status          # Complete cluster overview
just health-check            # Quick health check
just nodes-info              # Detailed node information
just nodes-usage             # Node resource utilization
just pods-usage [NAMESPACE]  # Pod resource usage

# Istio Service Mesh
just istio-health            # Istio control plane status
just istio-ingress-info      # Gateway URL and configuration
just istio-kiali             # Open Kiali dashboard (port 20001)
just istio-grafana           # Open Grafana dashboard (port 3000)

# Logs & Events
just logs-tail DEPLOYMENT [NS]    # Stream deployment logs
just logs-proxy POD [NS]          # Istio sidecar logs
just events-watch [NAMESPACE]     # Watch events in real-time
just events-recent [NAMESPACE]    # Show recent events

# Node Management
just node-cordon NODE        # Mark node unschedulable
just node-drain NODE         # Safely evict all pods
just node-uncordon NODE      # Mark node schedulable

# Troubleshooting
just diagnostics [DIR]       # Generate diagnostic bundle
just pod-describe POD [NS]   # Full pod details
just pod-exec POD [NS]       # Shell access to pod
just port-forward SVC PORT   # Port forward to service

# Help
just cluster-help            # Show all cluster commands
```

### Kustomize Multi-Environment Deployment
```bash
# Preview changes before applying
kubectl kustomize overlays/dev    # Preview dev configuration
kubectl kustomize overlays/qa     # Preview qa configuration
kubectl kustomize overlays/prod   # Preview prod configuration

# Deploy to specific environment
kubectl apply -k overlays/dev     # Deploy to microservices-dev namespace
kubectl apply -k overlays/qa      # Deploy to microservices-qa namespace
kubectl apply -k overlays/prod    # Deploy to microservices-prod namespace

# Check deployment status
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod

# View resource quotas
kubectl describe resourcequota -n microservices-dev
kubectl describe resourcequota -n microservices-qa
kubectl describe resourcequota -n microservices-prod

# Delete environment
kubectl delete -k overlays/dev    # Remove entire dev environment
```

### Container Operations
```bash
# Build images
just docker-build frontend    # Build single service
just docker-build-all         # Build all 12 services

# Push to ECR
just ecr-login                # Login to AWS ECR
just ecr-push frontend dev    # Push to dev environment
```

### Istio Service Mesh Dashboards
```bash
just istio-kiali              # Service mesh visualization (port 20001)
just istio-grafana            # Metrics dashboards (port 3000)
just istio-jaeger             # Distributed tracing (port 16686)
just istio-prometheus         # Metrics database (port 9090)
just istio-analyze            # Analyze Istio configuration
just istio-status             # Check proxy status
```

### Security & Validation
```bash
just validate                 # Run all validations
just security-scan-all        # All security scans
just security-scan-terraform  # Scan IaC (tfsec, checkov)
just security-scan-secrets    # Detect secrets (gitleaks)
just security-scan-containers # Scan images (trivy)
```

### Development
```bash
just dev-help                 # Show quick reference
just info                     # Show environment info
just clean-all                # Clean Docker and Terraform artifacts
```

## Architecture Overview

## Ultra-Minimal Demo Architecture 💰

**This project uses a SINGLE EKS cluster with ONE shared node** to minimize costs for demo purposes.

### Cost Optimization
- **Current Cost**: ~$134/month (80% reduction from original $378/month)
- **Savings**: ~$244/month ($2,928/year)
- **Configuration**: Ultra-minimal for demo/development only
- **See**: [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for complete details

### Cluster Configuration
- **Cluster Name**: `microservices`
- **Region**: eu-west-2 (London, UK)
- **Availability Zones**: eu-west-2a, eu-west-2b, eu-west-2c

### Node Group (Ultra-Minimal)
**Single "all-in-one" Node Group**:
- **Instance**: 1x t3.large (2 vCPU, 8 GB RAM)
- **Min/Max/Desired**: 1/2/1
- **Labels**: `role=all-in-one`, `workload=shared`
- **Taints**: None (all pods can schedule)
- **Purpose**: Runs EVERYTHING on single node
  - System pods (CoreDNS, EBS CSI, metrics-server)
  - Istio control plane (istiod + ingress gateway only)
  - All workloads (dev/qa/prod @ 1 replica each)
- **Capacity**: ~38 pods total (~85-90% capacity)

### Namespaces
- `microservices-dev` → 1 replica per service (10 pods)
- `microservices-qa` → 1 replica per service (10 pods)
- `microservices-prod` → 1 replica per service (10 pods)

### Istio Configuration
**Minimal Istio** (saves ~2GB RAM):
- ✅ **Enabled**: istiod (control plane) + ingress gateway
- ✅ **Enabled**: mTLS, traffic routing, service mesh core features
- ❌ **Disabled**: Observability addons (Grafana, Prometheus, Jaeger, Kiali)
- **Reason**: RAM conservation on single small node

To enable observability dashboards:
```bash
# Edit terraform-aws/variables.tf
enable_istio_addons = true

# Apply changes
just tf-apply
```

### Limitations (Demo Only)
⚠️ This configuration is optimized for **cost savings** and is suitable for:
- ✅ Demos and presentations
- ✅ Development and testing
- ✅ CI/CD pipeline validation

**NOT suitable for**:
- ❌ Production workloads
- ❌ High availability requirements
- ❌ Load testing at scale
- ❌ Long-term stable environments

### Alternative Configurations
See [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for:
- **Option B (Balanced)**: 1x t3.xlarge with full Istio observability ($195/mo)
- **Option C (Safer Minimal)**: 2 nodes with redundancy ($256/mo)
- **Production Setup**: Multi-node groups with HA (see SINGLE-CLUSTER-MIGRATION.md)


### Core Components

**12 Microservices** (in `src/`):
- **frontend** (Go) - Web UI, serves HTTP
- **cartservice** (C#) - Shopping cart with Redis
- **productcatalogservice** (Go) - Product inventory from JSON
- **currencyservice** (Node.js) - Currency conversion (highest QPS)
- **paymentservice** (Node.js) - Payment processing (mock)
- **shippingservice** (Go) - Shipping cost estimation
- **emailservice** (Python) - Order confirmation emails (mock)
- **checkoutservice** (Go) - Order orchestration, calls payment/shipping/email
- **recommendationservice** (Python) - Product recommendations
- **adservice** (Java) - Contextual advertisements
- **loadgenerator** (Python/Locust) - Realistic load generation
- **shoppingassistantservice** (Java) - AI shopping assistant

**Service Communication**:
- All inter-service communication uses **gRPC**
- Service definitions in `protos/demo.proto`
- Services discover each other via Kubernetes DNS (e.g., `productcatalogservice:3550`)
- **Istio enforces strict mTLS** between all services (no plaintext)

### Directory Structure

```
microservices-demo/
├── src/                          # Service source code (12 services)
├── protos/                       # gRPC Protocol Buffer definitions
│   └── demo.proto               # Service contracts (CartService, ProductCatalogService, etc.)
├── kubernetes-manifests/         # Individual K8s manifests per service
├── kustomize/                   # Kustomize-based multi-environment deployment
│   ├── base/                   # Base Kubernetes manifests (shared)
│   ├── components/             # Reusable components (Istio, load generator)
│   └── overlays/               # Environment-specific configs
│       ├── dev/               # Development (1 replica, minimal resources)
│       ├── qa/                # QA/Testing (1 replica, cost-optimized)
│       └── prod/              # Production (1 replica, cost-optimized)
├── istio-manifests/             # Istio Gateway and VirtualService configs
│   ├── frontend-gateway.yaml   # External traffic entry point
│   └── frontend.yaml            # Internal routing
├── release/                     # Combined manifests (autogenerated)
│   └── kubernetes-manifests.yaml
├── terraform-aws/               # AWS infrastructure as code
│   ├── versions.tf             # Provider versions
│   ├── vpc.tf                  # VPC with 3 AZs, NAT, VPC endpoints
│   ├── eks.tf                  # EKS cluster, node groups, addons
│   ├── elasticache.tf          # Redis for cartservice
│   ├── ecr.tf                  # 12 ECR repositories
│   ├── iam.tf                  # IRSA roles
│   ├── istio.tf                # Istio via Helm (istiod, ingress, observability)
│   ├── environments/           # Environment-specific configs
│   │   ├── dev.tfvars         # Dev: 2-3 nodes, t3.medium
│   │   ├── qa.tfvars          # QA: 3-5 nodes, t3.medium
│   │   └── prod.tfvars        # Prod: 5-10 nodes, t3.large/xlarge
│   └── tests/                  # Terraform tests
│       ├── vpc_test.tftest.hcl
│       ├── eks_test.tftest.hcl
│       ├── redis_test.tftest.hcl
│       └── istio_test.tftest.hcl
├── .github/workflows/           # CI/CD automation
│   ├── terraform-validate.yaml  # Multi-env validation, tests, security
│   ├── terraform-plan.yaml      # PR previews
│   ├── terraform-apply.yaml     # Automated deployment
│   ├── build-and-push-images.yaml  # Smart builds, Trivy, SBOM
│   ├── security-scan.yaml       # CodeQL, Gitleaks, Semgrep, etc.
│   └── deploy-application.yaml  # Deploy to EKS
├── docs/                        # Comprehensive documentation
│   ├── README.md               # Documentation index
│   ├── ONBOARDING.md           # New developer setup
│   ├── README-AWS.md           # Complete AWS deployment guide
│   ├── setup/                  # AWS, GitHub Actions, Security setup
│   ├── architecture/           # Repository structure, Istio, requirements
│   └── development/            # Dev guide, adding services
├── justfile                     # Task automation (50+ commands)
└── MIGRATION-SUMMARY.md        # GCP→AWS migration details
```

### Infrastructure (AWS)

**Deployed by Terraform** (`terraform-aws/`):
- **VPC**: 3 availability zones, public/private subnets, NAT gateway, VPC endpoints (ECR, S3, CloudWatch)
- **EKS**: Managed node groups, cluster autoscaler, metrics server, ALB controller, EBS CSI driver
- **ElastiCache Redis**: Replaces Google Memorystore, used by cartservice
- **ECR**: 12 repositories (one per service), vulnerability scanning, lifecycle policies
- **Istio**: Helm-installed (base, istiod, ingress gateway with NLB, Kiali, Prometheus, Jaeger, Grafana)
- **IAM**: IRSA (IAM Roles for Service Accounts) for secure AWS access, no long-lived credentials
- **Security**: Strict mTLS via PeerAuthentication, Security Groups, private subnets

**Multi-Environment Support**:
- **Dev** (dev.tfvars): 2-3 nodes, cache.t3.micro Redis, no Istio addons (~$185/month)
- **QA** (qa.tfvars): 3-5 nodes, cache.t3.small Redis, full observability (~$235/month)
- **Prod** (prod.tfvars): 5-10 nodes, cache.t3.medium Redis (multi-node), full stack (~$442/month)

## Critical Patterns

### Protocol Buffers (gRPC)
- **Service contracts defined in** `protos/demo.proto`
- Each service compiles protos during build:
  - Go: `protoc-gen-go`, `protoc-gen-go-grpc`
  - Python: `grpc_tools.protoc`
  - Java: `protobuf-maven-plugin`
  - Node.js: `grpc-tools`
- When modifying service interfaces, update `demo.proto` first, then recompile in all affected services
- Services call each other by name (e.g., `productcatalogservice:3550`) via Kubernetes DNS

### Kubernetes Manifests
- **Source of truth**: `kubernetes-manifests/` (individual files per service)
- **Deployment artifact**: `release/kubernetes-manifests.yaml` (combined, autogenerated)
- Always edit `kubernetes-manifests/`, never edit `release/` directly
- Each manifest includes: Deployment, Service (ClusterIP), ConfigMap, ServiceAccount (for IRSA)

### Kustomize Multi-Environment Pattern
- **Base manifests**: `kustomize/base/` contains shared configuration for all environments
- **Environment overlays**: `kustomize/overlays/{dev,qa,prod}/` contain environment-specific customizations
- **Components**: `kustomize/components/` contain reusable features (Istio, load generator)
- **Namespace isolation**: Each environment deploys to separate namespace:
  - Dev: `microservices-dev` (1 replica, no load generator, minimal resources)
  - QA: `microservices-qa` (2 replicas, with load generator for testing, moderate resources)
  - Prod: `microservices-prod` (3 replicas, no load generator, HA configuration, high resources)
- **Resource quotas**: Each namespace has ResourceQuota and LimitRange to prevent overconsumption
- **Image tagging strategy**:
  - Dev uses `dev` tag for latest development builds
  - QA uses `qa` tag for tested builds
  - Prod uses `prod` tag or semantic versions (v1.2.3) for stable releases
- **Istio injection**: All namespaces have `istio-injection=enabled` label for automatic sidecar injection
- **When to use**: Use Kustomize overlays for multi-environment deployments on the same cluster or different clusters
- **Complete documentation**: See `kustomize/overlays/README.md` for comprehensive deployment guide

### Istio Service Mesh
- **Deployed by Terraform** in `terraform-aws/istio.tf` (Helm-based)
- **Application routing** in `istio-manifests/`
- **Strict mTLS enforced globally** via PeerAuthentication in istio-system namespace
- All pods get Istio sidecar (istio-proxy) automatically via namespace label `istio-injection=enabled`
- Ingress via Istio Gateway with AWS NLB (not ALB)
- Observability stack: Kiali (topology), Prometheus (metrics), Jaeger (tracing), Grafana (viz)

### Terraform Structure
- **Environment-specific configs**: Use `terraform-aws/environments/{dev,qa,prod}.tfvars`
- **Tests**: Located in `terraform-aws/tests/`, run via `terraform test`
- **Modules**: Using official AWS modules (VPC, EKS)
- **State**: Configure backend in `versions.tf` for team collaboration (currently local)
- **IRSA pattern**: IAM roles created for services (ALB controller, cluster autoscaler, EBS CSI) with trust policy for EKS OIDC provider

### CI/CD (GitHub Actions)
- **Smart builds**: `build-and-push-images.yaml` uses `dorny/paths-filter` to only rebuild changed services
- **Multi-arch**: Builds for amd64 and arm64
- **Security scanning**: Every PR triggers CodeQL, Gitleaks, Semgrep, Trivy, Checkov
- **Terraform workflows**: `terraform-plan.yaml` on PR, `terraform-apply.yaml` on merge to main
- **Environment deployment**: Workflows accept environment parameter (dev/qa/prod)

## Development Workflow

### Making Changes to a Service

**Traditional Deployment:**
1. **Edit service code** in `src/<service-name>/`
2. **Build locally**: `just docker-build <service-name>`
3. **Push to ECR**: `just ecr-login && just ecr-push <service-name> dev`
4. **Restart deployment**: `just k8s-restart <service-name>`
5. **Check logs**: `just k8s-logs <service-name>`

**Kustomize-based Deployment:**
1. **Edit service code** in `src/<service-name>/`
2. **Build and tag**: `just docker-build <service-name> && docker tag <service-name>:latest <ECR-URL>/<service-name>:dev`
3. **Push to ECR**: `docker push <ECR-URL>/<service-name>:dev`
4. **Deploy to dev**: `kubectl apply -k kustomize/overlays/dev`
5. **Check status**: `kubectl get pods -n microservices-dev`
6. **Check logs**: `kubectl logs -l app=<service-name> -n microservices-dev --tail=50`

### Changing Service Interfaces (gRPC)

1. **Edit** `protos/demo.proto`
2. **Recompile protos** in all affected services (during Docker build)
3. **Update service implementations** to match new interface
4. **Test locally** before deploying
5. **Update all callers** of the changed service

### Adding a New Microservice

1. **Create service code** in `src/<service-name>/`
2. **Add Dockerfile**
3. **Define service in** `protos/demo.proto` (if exposing gRPC)
4. **Create Kubernetes manifest** in `kubernetes-manifests/<service-name>.yaml`
5. **Add ECR repository** in `terraform-aws/ecr.tf`:
   ```hcl
   # Add to locals.microservices list
   microservices = [
     "emailservice", "productcatalogservice", ..., "newservice"
   ]
   ```
6. **Update** `release/kubernetes-manifests.yaml`
7. **Add to CI/CD** in `.github/workflows/build-and-push-images.yaml` (paths-filter)

### Infrastructure Changes

1. **Edit Terraform files** in `terraform-aws/`
2. **Validate**: `just tf-validate`
3. **Test**: `just tf-test` (if adding tests in `tests/`)
4. **Plan**: `just tf-plan`
5. **Apply**: `just tf-apply`
6. **Update tests** if modifying resources

### Adding Terraform Tests

Create `.tftest.hcl` files in `terraform-aws/tests/`:
```hcl
run "test_name" {
  command = plan
  variables {
    cluster_name = "test-cluster"
  }
  assert {
    condition     = <expression>
    error_message = "..."
  }
}
```

## Important Files

### AWS Credentials
- `.envrc` - Local AWS credentials (gitignored)
- `.envrc.example` - Template for credentials
- Load with `source .envrc` before running Terraform or AWS CLI commands

### Environment Configuration
- `terraform-aws/environments/dev.tfvars` - Development settings
- `terraform-aws/environments/qa.tfvars` - QA settings
- `terraform-aws/environments/prod.tfvars` - Production settings
- Override any variable in `terraform-aws/variables.tf`

### Generated Files (Do Not Edit)
- `release/kubernetes-manifests.yaml` - Combined from kubernetes-manifests/
- `pb/` - Compiled Protocol Buffers (recreated during builds)

### Documentation
- `docs/ONBOARDING.md` - Complete new developer guide
- `docs/README.md` - Documentation index
- `docs/architecture/REPOSITORY-STRUCTURE.md` - Detailed codebase explanation
- `docs/architecture/ISTIO-DEPLOYMENT.md` - Istio usage and troubleshooting
- `MIGRATION-SUMMARY.md` - GCP to AWS migration details

## Testing

### Run Terraform Tests
```bash
just tf-test
# Or directly:
cd terraform-aws && terraform test
```

### Run Security Scans Locally
```bash
# All scans
just security-scan-all

# Individual scans
trivy image <image-name>:latest           # Container vulnerabilities
tfsec terraform-aws/                      # Terraform security
checkov -d terraform-aws/                 # IaC security
gitleaks detect --source . -v             # Secret detection
```

### Test Service Locally
Each service has its own test commands (varies by language):
```bash
cd src/frontend && make test              # Go services
cd src/emailservice && python -m pytest   # Python services
cd src/adservice && mvn test              # Java services
cd src/paymentservice && npm test         # Node.js services
cd src/cartservice && dotnet test         # C# services
```

### Test gRPC Services
```bash
# Using grpcurl
grpcurl -plaintext localhost:3550 hipstershop.ProductCatalogService/ListProducts

# Via Istio (with mTLS)
kubectl run -it --rm grpcurl --image=fullstorydev/grpcurl --restart=Never -- \
  -insecure productcatalogservice:3550 hipstershop.ProductCatalogService/ListProducts
```

## Troubleshooting

### Pods Not Starting
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -c server -n default
kubectl logs <pod-name> -c istio-proxy -n default  # Check sidecar
```

**Common causes**:
- Image pull errors: Check ECR permissions, verify image exists
- Resource limits: Increase in deployment manifest
- Missing ConfigMap/Secret: Check Redis config created by Terraform

### Istio Issues
```bash
just istio-analyze                         # Validate configuration
istioctl proxy-status                      # Check all proxies
istioctl proxy-config route <pod> -n default  # View routing
kubectl get peerauthentication -n istio-system  # Check mTLS
kubectl get gateway,virtualservice -n default   # Check routing resources
```

### Terraform Errors
```bash
just tf-validate                           # Check syntax
terraform -chdir=terraform-aws state list  # View state
terraform -chdir=terraform-aws state show <resource>  # Inspect resource
```

### AWS Credentials
```bash
aws sts get-caller-identity                # Verify credentials
echo $AWS_ACCESS_KEY_ID                    # Check if loaded
source .envrc                              # Reload credentials
```

## Security Notes

- **No hardcoded credentials**: Use IRSA for AWS access, Kubernetes Secrets for sensitive data
- **mTLS enforced**: All service-to-service communication encrypted via Istio
- **Private nodes**: EKS nodes in private subnets, egress via NAT gateway
- **Vulnerability scanning**: Every image scanned by Trivy before push
- **SAST**: CodeQL scans 5 languages on every PR
- **Secret detection**: Gitleaks scans all commits
- **IaC security**: Checkov and tfsec validate Terraform
- **SBOM generation**: Software Bill of Materials for compliance

## Multi-Environment Strategy

### Infrastructure-Level Isolation (Separate Clusters)
**Promote changes through environments**:
1. Deploy to **dev** first: `just tf-apply && just k8s-deploy`
2. Test in dev environment
3. Deploy to **qa**: `just tf-apply qa && just k8s-deploy`
4. Run QA tests, manual testing
5. Deploy to **prod**: `just tf-apply prod && just k8s-deploy`
6. Monitor via Istio dashboards

**Environment isolation**:
- Each environment has separate VPC (different CIDR)
- Separate EKS clusters
- Separate ECR image tags (can use environment-specific tags)
- Separate namespaces (via `namespace` variable)

### Namespace-Level Isolation (Same Cluster with Kustomize)
**Promote changes through environments using Kustomize**:
1. **Dev Testing**:
   ```bash
   kubectl apply -k kustomize/overlays/dev
   kubectl get pods -n microservices-dev
   ```
2. **Promote to QA** (update image tags in `kustomize/overlays/qa/kustomization.yaml`):
   ```bash
   cd kustomize/overlays/qa
   # Update newTag values from 'dev' to tested commit SHA or 'qa'
   kubectl apply -k .
   kubectl get pods -n microservices-qa
   ```
3. **QA Testing**: Run load tests, manual testing in qa namespace
4. **Promote to Prod** (update image tags in `kustomize/overlays/prod/kustomization.yaml`):
   ```bash
   cd kustomize/overlays/prod
   # Update newTag values to semantic version (v1.2.3) or 'prod'
   kubectl diff -k .  # Review changes
   kubectl apply -k .
   kubectl rollout status deployment/frontend -n microservices-prod
   ```
5. **Monitor**: Use Istio dashboards and check metrics per namespace

**Kustomize environment isolation**:
- Same EKS cluster, separate namespaces (microservices-dev, microservices-qa, microservices-prod)
- Resource quotas prevent environment overconsumption
- Different replica counts and resource allocations per environment
- Istio policies can be scoped per namespace
- Cost-effective for smaller deployments or testing
- See `kustomize/overlays/README.md` for detailed promotion workflow

## GitHub Actions Best Practices & Antipatterns

### Security Best Practices

**✅ DO:**

1. **Pin Actions to Full Commit SHA**
   ```yaml
   # Good - Pinned to specific commit SHA
   - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # v3.5.2

   # Bad - Uses mutable tag
   - uses: actions/checkout@v3
   ```
   - Only way to use an action as an immutable release
   - Prevents bad actors from adding backdoors via tag updates
   - Include version comment for human readability

2. **Limit Token Permissions (Principle of Least Privilege)**
   ```yaml
   # Good - Minimal permissions
   permissions:
     contents: read
     pull-requests: write

   # Bad - Overly permissive
   permissions: write-all
   ```
   - Set default GITHUB_TOKEN to read-only
   - Grant write permissions only where needed
   - Use job-level permissions for fine-grained control

3. **Use Environment Secrets with Protection Rules**
   ```yaml
   environment:
     name: production
     url: ${{ steps.deploy.outputs.url }}
   ```
   - Environment secrets enforce mandatory reviews before access
   - Implement approval gates for sensitive environments (prod)
   - Use environment-specific secrets instead of repository-level

4. **Pass Secrets Explicitly to Steps**
   ```yaml
   # Good - Only expose needed secret
   - name: Deploy
     env:
       API_KEY: ${{ secrets.DEPLOY_API_KEY }}
     run: ./deploy.sh

   # Bad - Exposes all secrets
   - name: Deploy
     env: ${{ toJson(secrets) }}
     run: ./deploy.sh
   ```

5. **Use Verified Actions from Trusted Publishers**
   - Prefer actions from GitHub (`actions/*`) or verified publishers
   - Audit third-party actions before use
   - Only 4.8% of marketplace actions are from verified creators
   - 18% of actions have known vulnerable dependencies

6. **Implement Branch Protection Rules**
   ```yaml
   # In repository settings
   - Require pull request reviews
   - Require status checks to pass
   - Enforce for administrators
   - Restrict who can push to main
   ```

**❌ DON'T:**

1. **Avoid `workflow_run` Without Caution**
   - Can lead to privilege escalation attacks
   - Carefully validate inputs from fork PRs
   - Use `pull_request_target` with explicit checkout of PR code

2. **Don't Log Secrets or Sensitive Data**
   ```yaml
   # Bad
   - run: echo "API_KEY=${{ secrets.API_KEY }}"

   # Good
   - run: ./deploy.sh
     env:
       API_KEY: ${{ secrets.API_KEY }}
   ```

3. **Don't Trust Fork PR Code in Sensitive Workflows**
   - Use `pull_request` (not `pull_request_target`) for untrusted code
   - Never expose secrets to fork PRs without approval
   - Review code before merging to trigger sensitive workflows

### Performance & Maintainability Best Practices

**✅ DO:**

1. **Use Dependency Caching**
   ```yaml
   - name: Cache dependencies
     uses: actions/cache@704facf57e6136b1bc63b828d79edcd491f0ee84  # v3.3.2
     with:
       path: |
         ~/.npm
         ~/.cache/pip
         ~/.m2/repository
       key: ${{ runner.os }}-deps-${{ hashFiles('**/package-lock.json', '**/requirements.txt', '**/pom.xml') }}
       restore-keys: |
         ${{ runner.os }}-deps-
   ```
   - Cache npm, pip, Maven, Gradle dependencies
   - Use hash of dependency files in cache key
   - Provide restore-keys for fallback
   - Can reduce build time by 40-60%

2. **Create Reusable Workflows for Common Patterns**
   ```yaml
   # .github/workflows/reusable-build.yaml
   name: Reusable Build
   on:
     workflow_call:
       inputs:
         service-name:
           required: true
           type: string
       secrets:
         AWS_ACCESS_KEY_ID:
           required: true

   # Caller workflow
   jobs:
     build-frontend:
       uses: ./.github/workflows/reusable-build.yaml
       with:
         service-name: frontend
       secrets: inherit
   ```
   - Reduces duplication across workflows
   - Centralizes maintenance
   - Use for: builds, deployments, security scans

3. **Use Composite Actions for Repeated Steps**
   ```yaml
   # .github/actions/setup-environment/action.yaml
   name: Setup Environment
   description: Setup common build environment
   runs:
     using: composite
     steps:
       - uses: actions/setup-node@1a4442cacd436585916779262731d5b162bc6ec7  # v3
       - uses: actions/setup-python@d27e3f3d7c64b4bbf8e4abfb9b63b83e846e0435  # v4
       - name: Install dependencies
         shell: bash
         run: |
           npm ci
           pip install -r requirements.txt

   # Use in workflows
   - uses: ./.github/actions/setup-environment
   ```

4. **Implement Matrix Builds for Multi-Environment Testing**
   ```yaml
   strategy:
     matrix:
       environment: [dev, qa, prod]
       node-version: [16, 18, 20]
   steps:
     - uses: actions/setup-node@v3
       with:
         node-version: ${{ matrix.node-version }}
   ```

5. **Use Job Outputs for Data Sharing**
   ```yaml
   jobs:
     build:
       outputs:
         image-tag: ${{ steps.build.outputs.tag }}
       steps:
         - id: build
           run: echo "tag=v1.2.3" >> $GITHUB_OUTPUT

     deploy:
       needs: build
       steps:
         - run: deploy.sh ${{ needs.build.outputs.image-tag }}
   ```

6. **Organize Workflows by Purpose**
   - One workflow = one primary purpose (test, build, deploy, security)
   - Use workflow_dispatch for manual triggers
   - Use workflow_call for reusable components
   - Separate fast checks (lint, unit tests) from slow ones (e2e, deploy)

**❌ DON'T:**

1. **Avoid Monolithic Workflows**
   ```yaml
   # Bad - Everything in one workflow
   - Lint, test, build, security scan, deploy all in one file
   - Hard to debug, slow to run, difficult to maintain

   # Good - Separate workflows
   - lint.yaml (runs on every PR, fast feedback)
   - test.yaml (unit + integration tests)
   - security.yaml (SAST, dependency scan)
   - deploy.yaml (triggered by merge or manual)
   ```

2. **Don't Cache Large, Frequently Changing Files**
   - Avoid caching node_modules directly (cache npm cache instead)
   - Don't cache build artifacts that change every run
   - Cache restoration can be slower than rebuilding for volatile data

3. **Don't Repeat Setup Steps Across Jobs**
   ```yaml
   # Bad - Repeated in every job
   jobs:
     test:
       steps:
         - uses: actions/checkout@v3
         - uses: actions/setup-node@v3
         - run: npm ci
         - run: npm test

     lint:
       steps:
         - uses: actions/checkout@v3
         - uses: actions/setup-node@v3
         - run: npm ci
         - run: npm run lint

   # Good - Use composite action or reusable workflow
   ```

4. **Don't Hard-Code Values**
   ```yaml
   # Bad
   - run: docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

   # Good - Use inputs, secrets, or variables
   - run: docker tag ${{ inputs.service }}:latest ${{ secrets.ECR_REGISTRY }}/${{ inputs.service }}:latest
   ```

### Workflow Design Patterns

**When to Use Reusable Workflows:**

- Need to reuse entire job with multiple steps
- Different runner types needed (Linux vs Windows)
- Complex multi-job workflows
- Environment-specific deployments

**When to Use Composite Actions:**

- Reusing a set of steps within a job
- Steps run on the same runner
- Logic packaged as custom action
- Setup/teardown patterns

**When to Use Matrix Builds:**

- Testing across multiple versions (Node 16, 18, 20)
- Multi-environment deployments (dev, qa, prod)
- Cross-platform builds (Linux, macOS, Windows)

### Current Project Opportunities

Based on analysis in [docs/_archive/WORKFLOW-REFACTORING-ANALYSIS.md](docs/_archive/WORKFLOW-REFACTORING-ANALYSIS.md):

**Identified Issues:**

- 100+ duplicated code blocks across 12 workflows
- Missing dependency caching (40-60% faster builds possible)
- No composite actions for setup steps
- Hardcoded values in multiple places
- Monolithic workflows mixing concerns

**Recommended Actions:**

1. Create composite actions for:
   - AWS authentication setup
   - Docker/ECR login
   - Terraform setup
   - Kubernetes config
2. Implement dependency caching for:
   - npm (frontend, currencyservice, paymentservice)
   - pip (emailservice, recommendationservice, loadgenerator)
   - Maven (adservice, shoppingassistantservice)
   - Go modules (checkout, product catalog, shipping)
   - NuGet (cartservice)
3. Extract reusable workflows for:
   - Multi-service builds
   - Environment deployments
   - Security scanning
4. Use matrix strategy for:
   - Building 12 services
   - Deploying to 3 environments

## Common Pitfalls

1. **Forgetting to source .envrc**: AWS commands fail with "credentials not found"
2. **Editing release/kubernetes-manifests.yaml**: Changes will be overwritten, edit kubernetes-manifests/ instead
3. **Not configuring kubectl**: Run `just k8s-config <env>` before kubectl commands
4. **Terraform state conflicts**: Don't run Terraform from multiple terminals simultaneously
5. **Not waiting for Istio**: After deploying Istio, wait ~2 minutes for control plane to be ready
6. **Ignoring security scan failures**: Fix vulnerabilities before merging PRs
7. **Not testing in dev first**: Always test in dev before deploying to qa/prod
8. **Editing Kustomize base files directly**: Always use overlays for environment-specific changes
9. **Forgetting to update image tags**: When promoting between environments, update `newTag` values in kustomization.yaml
10. **Not checking resource quotas**: Deployments fail if namespace quota is exceeded, check with `kubectl describe resourcequota -n <namespace>`

---

## Quick Reference Card

| Task | Command |
|------|---------|
| First time setup | `just onboard` |
| Deploy infrastructure | `just tf-apply` |
| Configure kubectl | `just k8s-config` |
| Deploy application | `just k8s-deploy` |
| Deploy with Kustomize (dev) | `kubectl apply -k kustomize/overlays/dev` |
| Deploy with Kustomize (qa) | `kubectl apply -k kustomize/overlays/qa` |
| Deploy with Kustomize (prod) | `kubectl apply -k kustomize/overlays/prod` |
| Preview Kustomize changes | `kubectl kustomize overlays/dev` |
| Check namespace status | `kubectl get pods -n microservices-dev` |
| View application | `just k8s-url` |
| View service mesh | `just istio-kiali` |
| Build container | `just docker-build frontend` |
| View logs | `just k8s-logs frontend` |
| View logs (Kustomize) | `kubectl logs -l app=frontend -n microservices-dev` |
| Restart service | `just k8s-restart frontend` |
| Check resource quota | `kubectl describe resourcequota -n microservices-dev` |
| Run all validations | `just validate` |
| Security scans | `just security-scan-all` |
| Help | `just dev-help` |

For detailed information, see:
- General documentation: `docs/README.md`
- Kustomize multi-environment guide: `kustomize/overlays/README.md`
- All justfile commands: run `just`
