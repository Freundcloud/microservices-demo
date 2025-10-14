# Repository Structure Guide

This document explains the complete structure of the microservices demo repository and how each directory is used.

## Directory Overview

```
microservices-demo/
├── src/                          # Microservice source code
├── protos/                       # gRPC Protocol Buffer definitions
├── kubernetes-manifests/         # Kubernetes deployment manifests
├── istio-manifests/             # Istio service mesh configurations
├── release/                     # Compiled/combined manifests
├── terraform-aws/               # AWS infrastructure as code
├── .github/workflows/           # CI/CD automation
├── helm-chart/                  # Helm chart for deployment
└── pb/                          # Compiled Protocol Buffers (generated)
```

## Core Directories

### src/ - Microservice Source Code

Contains the source code for all 12 microservices:

```
src/
├── emailservice/              # Go - Email notifications
├── productcatalogservice/     # Go - Product inventory
├── recommendationservice/     # Python - Product recommendations
├── shippingservice/           # Go - Shipping calculations
├── checkoutservice/           # Go - Order checkout
├── paymentservice/            # Node.js - Payment processing
├── currencyservice/           # Node.js - Currency conversion
├── cartservice/               # C# - Shopping cart
├── frontend/                  # Go - Web UI
├── adservice/                 # Java - Advertisement serving
├── loadgenerator/             # Python - Load testing
└── shoppingassistantservice/  # Java - AI shopping assistant
```

**Each microservice contains:**
- Application source code
- Dockerfile for containerization
- Dependencies/package management files
- Service-specific configuration

**Build Process:**
- GitHub Actions workflow ([build-and-push-images.yaml](.github/workflows/build-and-push-images.yaml)) detects changes
- Builds Docker images with multi-architecture support (amd64/arm64)
- Scans for vulnerabilities using Trivy
- Generates SBOM (Software Bill of Materials)
- Pushes to AWS ECR

### protos/ - gRPC Protocol Buffer Definitions

Contains the service interface definitions for inter-service communication:

```
protos/
└── demo.proto                 # Main Protocol Buffer definition
```

**Purpose:**
- Defines gRPC service contracts between microservices
- Language-agnostic service definitions
- Ensures type-safe communication

**Example from demo.proto:**

```protobuf
service CartService {
    rpc AddItem(AddItemRequest) returns (Empty) {}
    rpc GetCart(GetCartRequest) returns (Cart) {}
    rpc EmptyCart(EmptyCartRequest) returns (Empty) {}
}

service ProductCatalogService {
    rpc ListProducts(Empty) returns (ListProductsResponse) {}
    rpc GetProduct(GetProductRequest) returns (Product) {}
    rpc SearchProducts(SearchProductsRequest) returns (SearchProductsResponse) {}
}
```

**Usage:**
- Compiled into language-specific code (Go, Python, Java, etc.)
- Used by services to make type-safe gRPC calls
- Ensures consistent API contracts across services

**Compilation:**
Each microservice compiles these protos during build:
- Go services: Use `protoc-gen-go` and `protoc-gen-go-grpc`
- Python services: Use `grpc_tools.protoc`
- Java services: Use `protobuf-maven-plugin`
- Node.js services: Use `grpc-tools`

### kubernetes-manifests/ - Kubernetes Deployments

Contains raw Kubernetes YAML manifests for each service:

```
kubernetes-manifests/
├── adservice.yaml
├── cartservice.yaml
├── checkoutservice.yaml
├── currencyservice.yaml
├── emailservice.yaml
├── frontend.yaml
├── loadgenerator.yaml
├── paymentservice.yaml
├── productcatalogservice.yaml
├── recommendationservice.yaml
├── redis.yaml
├── shippingservice.yaml
└── shoppingassistantservice.yaml
```

**Each manifest includes:**
- Deployment: Pod specifications, replicas, resource limits
- Service: ClusterIP service for internal communication
- ConfigMap: Environment variables and configuration
- ServiceAccount: For IRSA (IAM Roles for Service Accounts)

**Example structure:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: server
        image: <ECR_URL>/frontend:latest
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
```

### istio-manifests/ - Service Mesh Configuration

Contains Istio-specific routing and traffic management:

```
istio-manifests/
├── frontend-gateway.yaml      # External traffic entry point
└── frontend.yaml              # Internal service routing
```

**frontend-gateway.yaml:**
- Defines Istio Gateway for external traffic
- VirtualService routes requests to frontend
- Works with Istio Ingress Gateway (NLB on AWS)

**frontend.yaml:**
- Internal VirtualService for service mesh routing
- Enables advanced traffic management
- Supports canary deployments, A/B testing

**Relationship with Terraform:**
- Terraform ([istio.tf](terraform-aws/istio.tf)) deploys Istio infrastructure
- These manifests define application-specific routing
- Applied after Terraform and application deployment

**See:** [ISTIO-DEPLOYMENT.md](ISTIO-DEPLOYMENT.md) for complete Istio guide

### release/ - Compiled Deployment Manifests

Contains combined, release-ready Kubernetes manifests:

```
release/
└── kubernetes-manifests.yaml  # All services in one file
```

**Purpose:**
- Single-file deployment for simplicity
- Combines all kubernetes-manifests/ into one YAML
- Generated automatically (do not edit manually)

**Generation:**
Typically created by combining all manifests:

```bash
# Example generation (if needed)
cat kubernetes-manifests/*.yaml > release/kubernetes-manifests.yaml
```

**Deployment:**
Used by GitHub Actions ([deploy-application.yaml](.github/workflows/deploy-application.yaml)):

```bash
kubectl apply -f release/kubernetes-manifests.yaml
```

**Note:** This file is autogenerated. Always edit source files in `kubernetes-manifests/` instead.

### terraform-aws/ - AWS Infrastructure

Contains Terraform code for AWS infrastructure:

```
terraform-aws/
├── versions.tf              # Provider versions
├── variables.tf             # Input variables
├── vpc.tf                   # VPC, subnets, NAT gateway
├── eks.tf                   # EKS cluster, node groups
├── elasticache.tf          # Redis for cart service
├── ecr.tf                   # Container registry
├── iam.tf                   # IAM roles and policies
├── istio.tf                 # Istio service mesh
├── outputs.tf               # Output values
├── terraform.tfvars.example # Example configuration
└── README.md                # Deployment guide
```

**Infrastructure Components:**

1. **Networking (vpc.tf):**
   - VPC with 3 availability zones
   - Public subnets for load balancers
   - Private subnets for EKS nodes
   - NAT Gateway for egress
   - VPC endpoints for ECR, S3, CloudWatch

2. **Kubernetes Cluster (eks.tf):**
   - EKS cluster with managed node groups
   - ALB controller for ingress
   - Cluster autoscaler
   - EBS CSI driver for persistent volumes
   - Metrics server for HPA

3. **Data Stores (elasticache.tf):**
   - ElastiCache Redis cluster
   - Replaces Google Memorystore
   - Used by cartservice for session storage

4. **Container Registry (ecr.tf):**
   - 12 ECR repositories (one per microservice)
   - Automated vulnerability scanning
   - Lifecycle policies for image cleanup
   - EventBridge integration for critical CVEs

5. **Service Mesh (istio.tf):**
   - Istio control plane (istiod)
   - Istio ingress gateway with NLB
   - Observability stack (Kiali, Prometheus, Jaeger, Grafana)
   - Strict mTLS enforcement

**Deployment:**
- Automated via GitHub Actions ([terraform-apply.yaml](.github/workflows/terraform-apply.yaml))
- Manual: `terraform init && terraform apply`
- See: [terraform-aws/README.md](terraform-aws/README.md)

### .github/workflows/ - CI/CD Automation

GitHub Actions workflows for complete automation:

```
.github/workflows/
├── terraform-plan.yaml          # Infrastructure preview on PRs
├── terraform-apply.yaml         # Infrastructure deployment
├── build-and-push-images.yaml   # Container builds and scans
├── security-scan.yaml           # Code security scanning
└── deploy-application.yaml      # Application deployment to EKS
```

**Workflow Triggers:**

1. **On Pull Request:**
   - `terraform-plan.yaml`: Shows infrastructure changes
   - `security-scan.yaml`: Runs all security scans
   - `build-and-push-images.yaml`: Builds changed services

2. **On Merge to Main:**
   - `terraform-apply.yaml`: Deploys infrastructure
   - `build-and-push-images.yaml`: Builds and pushes all images
   - `deploy-application.yaml`: Deploys to EKS

**See:**
- [GITHUB-ACTIONS-SETUP.md](GITHUB-ACTIONS-SETUP.md) for GitHub setup
- [SECURITY-SCANNING.md](SECURITY-SCANNING.md) for security tools

### helm-chart/ - Helm Package

Helm chart for alternative deployment method:

```
helm-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration
└── templates/              # Kubernetes templates
```

**Values Configuration:**
- Service-specific settings
- Resource limits
- Image repositories
- Feature flags

**Deployment:**

```bash
helm install online-boutique helm-chart/ \
  --set frontend.image.repository=<ECR_URL>/frontend \
  --set frontend.image.tag=latest
```

**vs. kubectl apply:**
- Helm: Template-based, easier upgrades, rollback support
- kubectl: Direct YAML, simpler for demos

### pb/ - Compiled Protocol Buffers

Auto-generated directory from protobuf compilation:

```
pb/                             # Do not edit manually
└── (generated Go code)
```

**Purpose:**
- Contains compiled protobuf code
- Generated during service builds
- Gitignored (recreated from protos/)

**Generation:**
Each service compiles protos/ into language-specific code:

```bash
# Example for Go services
protoc --go_out=. --go-grpc_out=. protos/demo.proto
```

## Development Workflow

### 1. Local Development

```bash
# 1. Clone repository
git clone <repo-url>
cd microservices-demo

# 2. Set up AWS credentials
cp .envrc.example .envrc
# Edit .envrc with your AWS credentials
source .envrc

# 3. Work on a specific microservice
cd src/frontend
# Make changes, test locally

# 4. Update protos if needed
cd ../../protos
# Edit demo.proto
# Recompile in each service
```

### 2. Build and Test Locally

```bash
# Build specific service
cd src/frontend
docker build -t frontend:local .

# Run with docker-compose (if available)
docker-compose up

# Or deploy to local Kubernetes (kind/minikube)
kubectl apply -f kubernetes-manifests/frontend.yaml
```

### 3. Deploy to AWS via CI/CD

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes to src/
# CI will run security scans on PR

# 3. Merge to main
# CI will:
#   - Build and push Docker images to ECR
#   - Deploy infrastructure (if changed)
#   - Deploy application to EKS
```

### 4. Manual Deployment

```bash
# 1. Deploy infrastructure
cd terraform-aws
terraform init
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name <cluster-name>

# 3. Build and push images (if not using CI)
./scripts/build-and-push.sh  # Create this script

# 4. Deploy application
kubectl apply -f release/kubernetes-manifests.yaml

# 5. Apply Istio routing (if enabled)
kubectl apply -f istio-manifests/

# 6. Get application URL
kubectl get svc istio-ingressgateway -n istio-system
```

## Service Communication

### gRPC Communication Flow

```
Frontend (Go)
  ├── → ProductCatalogService (Go) - ListProducts()
  ├── → CurrencyService (Node.js) - Convert()
  ├── → CartService (C#) - GetCart()
  ├── → RecommendationService (Python) - ListRecommendations()
  ├── → ShippingService (Go) - GetQuote()
  ├── → CheckoutService (Go) - PlaceOrder()
  │     ├── → EmailService (Go) - SendOrderConfirmation()
  │     ├── → PaymentService (Node.js) - Charge()
  │     ├── → ShippingService (Go) - ShipOrder()
  │     └── → CartService (C#) - EmptyCart()
  └── → AdService (Java) - GetAds()
```

**Protocol:**
- All inter-service communication uses gRPC
- Defined in `protos/demo.proto`
- Type-safe, efficient binary protocol

**Discovery:**
- Kubernetes DNS: `<service-name>.<namespace>.svc.cluster.local`
- Example: `productcatalogservice.default.svc.cluster.local:3550`

**Security:**
- Istio enforces mTLS between services
- No plaintext communication
- Automatic certificate rotation

## Configuration Management

### Environment Variables

Each service configures dependencies via environment variables:

```yaml
# Example from frontend deployment
env:
- name: PRODUCT_CATALOG_SERVICE_ADDR
  value: "productcatalogservice:3550"
- name: CURRENCY_SERVICE_ADDR
  value: "currencyservice:7000"
- name: CART_SERVICE_ADDR
  value: "cartservice:7070"
- name: RECOMMENDATION_SERVICE_ADDR
  value: "recommendationservice:8080"
```

### ConfigMaps and Secrets

```yaml
# Redis connection from ConfigMap
- name: REDIS_ADDR
  valueFrom:
    configMapKeyRef:
      name: redis-config
      key: redis-addr

# Sensitive data from Secrets
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: api-secrets
      key: payment-api-key
```

### Terraform Variables

Infrastructure is configured via `terraform.tfvars`:

```hcl
cluster_name     = "microservices-demo"
aws_region       = "eu-west-2"
environment      = "production"
enable_istio     = true
enable_redis     = true
instance_types   = ["t3.medium"]
```

## Monitoring and Observability

### Application Metrics

**Sources:**
- Istio sidecar proxies (automatic)
- Application-level metrics (custom)
- Infrastructure metrics (CloudWatch)

**Collection:**
- Prometheus scrapes Istio metrics
- CloudWatch receives EKS logs
- Jaeger collects distributed traces

**Visualization:**
- Grafana dashboards (Istio stack)
- Kiali service graph
- CloudWatch dashboards

### Logs

**Application logs:**
```bash
# View logs for a specific service
kubectl logs -l app=frontend -n default

# View Istio sidecar logs
kubectl logs -l app=frontend -c istio-proxy -n default
```

**Infrastructure logs:**
- EKS control plane: CloudWatch Logs
- Node logs: CloudWatch Logs
- Load balancer: Access logs to S3

### Tracing

**Distributed tracing with Jaeger:**
1. Request enters via Istio Ingress Gateway
2. Spans created for each service call
3. Propagated via headers (x-request-id, etc.)
4. Visualized in Jaeger UI

**Access Jaeger:**
```bash
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
# Open http://localhost:16686
```

## Security

### Image Scanning

**Tools:**
- Trivy: Container vulnerability scanning
- Grype: Additional CVE detection
- Snyk: Dependency scanning

**Process:**
1. GitHub Actions scans all images on build
2. Results posted to GitHub Security tab
3. Critical CVEs block deployment
4. ECR scans on push (additional layer)

### Code Scanning

**Static Analysis:**
- CodeQL (5 languages)
- Semgrep (SAST)
- Checkov (IaC)
- tfsec (Terraform)

**Secret Detection:**
- Gitleaks scans all commits
- Pre-commit hooks (optional)
- GitHub secret scanning

**See:** [SECURITY-SCANNING.md](SECURITY-SCANNING.md)

### Runtime Security

**Istio mTLS:**
- Automatic mutual TLS between services
- Certificate rotation
- Authorization policies

**Network Policies:**
- Istio enforces service-to-service rules
- AWS Security Groups for node isolation
- Private subnets for EKS nodes

## Disaster Recovery

### Backup Strategy

**Infrastructure:**
- Terraform state in S3 with versioning
- `terraform.tfstate.backup` locally
- Infrastructure as code = disaster recovery

**Data:**
- ElastiCache automatic backups (daily)
- Snapshot retention: 7 days
- Point-in-time recovery supported

**Kubernetes:**
- EKS control plane managed by AWS
- Node groups can be recreated
- Deployments defined in Git (source of truth)

### Recovery Procedures

**Complete cluster loss:**
```bash
# 1. Restore infrastructure
cd terraform-aws
terraform init
terraform apply

# 2. Restore application
kubectl apply -f release/kubernetes-manifests.yaml
kubectl apply -f istio-manifests/

# 3. Verify services
kubectl get pods -n default
```

**Single service failure:**
```bash
# Kubernetes will automatically restart
# Or manually scale:
kubectl scale deployment frontend --replicas=0
kubectl scale deployment frontend --replicas=2
```

## Cost Optimization

### Infrastructure Costs

**Major cost drivers:**
1. **EKS cluster:** $0.10/hour (~$73/month)
2. **EC2 nodes:** 3 × t3.medium (~$90/month)
3. **NAT Gateway:** $0.045/hour (~$33/month)
4. **ElastiCache:** cache.t3.micro (~$15/month)
5. **NLB (Istio):** $0.0225/hour (~$16/month)

**Total estimated:** ~$230/month

**Optimization tips:**
1. Use Spot instances for non-prod
2. Enable cluster autoscaler
3. Reduce observability stack (disable addons)
4. Use single NAT gateway
5. Smaller Redis instance for testing

### Reduce Observability Costs

```hcl
# In terraform.tfvars
enable_istio_addons = false  # Saves ~$30/month
```

## Troubleshooting

### Common Issues

**Issue: Pods not starting**
```bash
# Check pod status
kubectl get pods -n default

# Describe pod for events
kubectl describe pod <pod-name> -n default

# Check logs
kubectl logs <pod-name> -n default

# Common causes:
# - Image pull errors (ECR permissions)
# - Resource limits too low
# - Missing ConfigMap/Secret
```

**Issue: Services can't communicate**
```bash
# Verify service exists
kubectl get svc -n default

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup frontend.default.svc.cluster.local

# Verify Istio sidecar injection
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}' -n default
# Should show both 'server' and 'istio-proxy'
```

**Issue: Istio routing not working**
```bash
# Validate Istio configuration
istioctl analyze -n default

# Check gateway status
kubectl get gateway -n default

# Check virtual services
kubectl get virtualservice -n default

# View Envoy config
istioctl proxy-config route <pod-name> -n default
```

**Issue: Terraform apply fails**
```bash
# Check state lock
terraform force-unlock <lock-id>

# Re-initialize providers
rm -rf .terraform
terraform init

# Targeted apply
terraform apply -target=module.vpc
```

### Debug Tools

```bash
# Install debug utilities
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash

# Inside debug pod:
# - dig: DNS resolution
# - curl: HTTP requests
# - grpcurl: gRPC testing
# - tcpdump: Traffic capture
```

## Additional Documentation

- [AWS Setup Guide](AWS-SETUP.md)
- [GitHub Actions Setup](GITHUB-ACTIONS-SETUP.md)
- [Security Scanning Guide](SECURITY-SCANNING.md)
- [Istio Deployment Guide](ISTIO-DEPLOYMENT.md)
- [Terraform README](terraform-aws/README.md)

## Quick Reference

### Essential Commands

```bash
# Infrastructure
terraform -chdir=terraform-aws plan
terraform -chdir=terraform-aws apply
terraform -chdir=terraform-aws destroy

# Kubernetes
kubectl get pods -n default
kubectl get svc -n default
kubectl logs -l app=frontend -n default
kubectl describe pod <pod-name> -n default

# Istio
kubectl get gateway -n default
kubectl get virtualservice -n default
istioctl analyze -n default
istioctl proxy-status

# AWS
aws eks update-kubeconfig --region <region> --name <cluster>
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
```

### URLs and Endpoints

```bash
# Get application URL
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Access dashboards (port-forward required)
# Kiali: http://localhost:20001
# Grafana: http://localhost:3000
# Jaeger: http://localhost:16686
# Prometheus: http://localhost:9090
```

### Environment Setup

```bash
# AWS credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="eu-west-2"

# Or use .envrc
source .envrc

# Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name microservices-demo
```

## Contributing

When modifying this repository:

1. **Update source files, not generated files:**
   - Edit `kubernetes-manifests/*.yaml`, not `release/kubernetes-manifests.yaml`
   - Edit `protos/demo.proto`, not `pb/*`
   - Edit Terraform `*.tf`, not manual AWS resources

2. **Test changes locally:**
   - Run security scans before pushing
   - Test infrastructure changes in dev environment first
   - Validate Kubernetes manifests: `kubectl apply --dry-run=client`

3. **Follow CI/CD process:**
   - Create feature branch
   - Open PR (triggers scans and plan)
   - Review security findings
   - Merge to main (triggers deployment)

4. **Document changes:**
   - Update relevant documentation
   - Add comments to complex code
   - Update version numbers

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs
3. Check CloudWatch Logs
4. View Istio configuration with `istioctl analyze`
5. Open GitHub issue with details
