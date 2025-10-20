# Microservices Demo - Project Overview

> Cloud-native microservices application demonstrating modern DevOps practices with GitHub Actions, AWS EKS, Istio, and ServiceNow integration

## What is This Demo?

This repository demonstrates a complete, production-ready microservices architecture running on AWS EKS (Amazon Elastic Kubernetes Service) with full DevOps automation including:

- **12 Polyglot Microservices** (Go, Python, Java, Node.js, C#)
- **Service Mesh** (Istio for traffic management and observability)
- **Infrastructure as Code** (Terraform for AWS resources)
- **CI/CD Automation** (GitHub Actions)
- **Change Management** (ServiceNow DevOps integration)
- **Security Scanning** (Multi-tool security pipeline)
- **CMDB Integration** (Automated infrastructure discovery)

## Architecture

### Application: Online Boutique

A modern e-commerce application consisting of 12 microservices:

| Service | Language | Purpose |
|---------|----------|---------|
| **frontend** | Go | Web UI |
| **cartservice** | C# | Shopping cart with Redis |
| **productcatalogservice** | Go | Product inventory |
| **currencyservice** | Node.js | Currency conversion |
| **paymentservice** | Node.js | Payment processing |
| **shippingservice** | Go | Shipping cost calculator |
| **emailservice** | Python | Order confirmations |
| **checkoutservice** | Go | Order orchestration |
| **recommendationservice** | Python | Product recommendations |
| **adservice** | Java | Contextual ads |
| **shoppingassistantservice** | Java | AI shopping assistant |
| **loadgenerator** | Python/Locust | Realistic traffic simulation |

**Communication**: All inter-service calls use **gRPC** (Protocol Buffers)
**Security**: **Strict mTLS** enforced by Istio service mesh

### Infrastructure

**Cloud Provider**: AWS
**Region**: eu-west-2 (London, UK)

**Kubernetes**:
- **Cluster**: Amazon EKS (Managed Kubernetes)
- **Networking**: AWS VPC with 3 availability zones
- **Service Mesh**: Istio 1.x
- **Ingress**: Istio Gateway with AWS NLB

**Storage & Caching**:
- **Redis**: Amazon ElastiCache (for cart service)
- **Container Registry**: Amazon ECR

**Cost Optimization**:
- **Current**: ~$134/month (ultra-minimal demo configuration)
- **Configuration**: 1x t3.large node (2 vCPU, 8 GB RAM)
- **Capacity**: ~38 pods total across all environments
- **See**: [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for alternatives

## Multi-Environment Strategy

This demo supports three deployment environments using **Kustomize overlays**:

| Environment | Namespace | Replicas | Purpose |
|-------------|-----------|----------|---------|
| **dev** | microservices-dev | 1 | Development testing |
| **qa** | microservices-qa | 1 | QA validation |
| **prod** | microservices-prod | 1 | Production (demo) |

**Deployment**:
```bash
kubectl apply -k kustomize/overlays/dev    # Deploy to dev
kubectl apply -k kustomize/overlays/qa     # Deploy to qa
kubectl apply -k kustomize/overlays/prod   # Deploy to prod
```

## Key Features

### 1. Complete DevOps Automation

**GitHub Actions Workflows**:
- ✅ Multi-environment Terraform validation and deployment
- ✅ Smart container builds (only rebuild changed services)
- ✅ Comprehensive security scanning (SAST, containers, IaC, secrets)
- ✅ Automated deployment with approval gates
- ✅ ServiceNow change management integration

### 2. ServiceNow Integration

**Change Management**:
- Automated change requests for every deployment
- Environment-specific approval workflows (dev=auto, qa/prod=manual)
- Security scan evidence attached to changes
- Complete audit trail

**CMDB Automation**:
- Automatic EKS cluster discovery
- Microservice deployment tracking
- Real-time inventory updates

**See**: [docs/servicenow-integration/](docs/servicenow-integration/) for setup

### 3. Security Scanning

Integrated security tools:
- **CodeQL**: Static analysis (5 languages)
- **Trivy**: Container vulnerability scanning + SBOM generation
- **Gitleaks**: Secret detection
- **Semgrep**: SAST with custom rules
- **tfsec & Checkov**: Infrastructure security
- **Dependency-Check**: OWASP dependency analysis

Results available in:
- GitHub Security tab
- ServiceNow change requests (as evidence)

### 4. Observability

**Istio Service Mesh** provides:
- **Kiali**: Service topology visualization (port 20001)
- **Grafana**: Metrics dashboards (port 3000)
- **Jaeger**: Distributed tracing (port 16686)
- **Prometheus**: Metrics collection (port 9090)

**Access dashboards**:
```bash
just istio-kiali     # Service mesh topology
just istio-grafana   # Metrics and dashboards
```

### 5. Infrastructure as Code

**Terraform** manages all AWS resources:
- VPC with public/private subnets across 3 AZs
- EKS cluster with managed node groups
- ElastiCache Redis cluster
- ECR repositories (one per service)
- IAM roles using IRSA (IAM Roles for Service Accounts)
- Istio installation via Helm

**Multi-environment support** via tfvars files:
- `environments/dev.tfvars`
- `environments/qa.tfvars`
- `environments/prod.tfvars`

## Quick Start

### Prerequisites

- AWS account with admin access
- GitHub account
- `kubectl`, `terraform`, `docker`, `just`, `aws-cli` installed
- ServiceNow instance (optional, for change management)

### 1. Clone and Configure

```bash
git clone https://github.com/your-org/microservices-demo.git
cd microservices-demo

# Copy and edit AWS credentials
cp .envrc.example .envrc
edit .envrc  # Add your AWS credentials
source .envrc
```

### 2. Deploy Infrastructure

```bash
just tf-init
just tf-plan
just tf-apply  # Takes ~15 minutes
```

### 3. Deploy Application

```bash
# Configure kubectl
just k8s-config

# Deploy to dev environment
kubectl apply -k kustomize/overlays/dev

# Wait for pods to be ready
kubectl get pods -n microservices-dev --watch
```

### 4. Access the Application

```bash
# Get the Istio ingress URL
just k8s-url

# Or manually
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 5. Access Observability Dashboards

```bash
just istio-kiali     # Service mesh topology
just istio-grafana   # Metrics dashboards
```

**Full setup guide**: [docs/ONBOARDING.md](docs/ONBOARDING.md)

## Use Cases

This demo is designed for:

### 1. Learning Modern Microservices

- **Polyglot architecture**: See how 5 different programming languages work together
- **gRPC communication**: Learn Protocol Buffers and service contracts
- **Service mesh**: Understand Istio traffic management and mTLS
- **Cloud-native patterns**: Observe 12-factor app principles in action

### 2. DevOps Practice

- **GitOps workflows**: All changes via Git + GitHub Actions
- **Infrastructure as Code**: Terraform for complete AWS stack
- **Multi-environment**: Practice dev → qa → prod promotion
- **Security-first**: Integrated scanning at every stage

### 3. ServiceNow Integration Demo

- **Change automation**: See how GitHub integrates with ServiceNow
- **Approval workflows**: Environment-specific approval gates
- **CMDB automation**: Automatic infrastructure discovery
- **Compliance**: Complete audit trail for SOX/HIPAA requirements

### 4. Kubernetes Learning

- **Multi-namespace deployments**: Environment isolation
- **Kustomize**: Configuration management best practices
- **Istio**: Service mesh features (mTLS, traffic routing, observability)
- **AWS EKS**: Managed Kubernetes in production

## Project Structure

```
microservices-demo/
├── src/                          # 12 microservice source code
│   ├── frontend/                 # Go - Web UI
│   ├── cartservice/              # C# - Shopping cart
│   ├── productcatalogservice/    # Go - Products
│   └── .../                      # Other services
├── kustomize/                    # Multi-environment deployment
│   ├── base/                     # Shared Kubernetes manifests
│   ├── components/               # Istio, load generator
│   └── overlays/                 # Environment-specific configs
│       ├── dev/
│       ├── qa/
│       └── prod/
├── terraform-aws/                # Infrastructure as Code
│   ├── vpc.tf                    # Network configuration
│   ├── eks.tf                    # Kubernetes cluster
│   ├── elasticache.tf            # Redis cluster
│   ├── ecr.tf                    # Container registries
│   ├── istio.tf                  # Service mesh
│   └── environments/             # Per-environment configs
├── .github/workflows/            # CI/CD automation
│   ├── deploy-with-servicenow-basic.yaml
│   ├── deploy-with-servicenow-devops.yaml
│   ├── aws-infrastructure-discovery.yaml
│   └── security-scan.yaml
├── docs/                         # Documentation
│   ├── ONBOARDING.md            # New developer setup
│   ├── servicenow-integration/   # ServiceNow guides
│   └── architecture/             # Technical docs
└── justfile                      # Task automation (50+ commands)
```

## Technology Stack

### Languages & Frameworks

- **Go**: Frontend, product catalog, shipping, checkout (gRPC servers)
- **Python**: Email, recommendations, load generator (Flask, Locust)
- **Java**: Ads, shopping assistant (Spring Boot)
- **Node.js**: Currency, payment (Express)
- **C#**: Cart service (.NET Core)

### Infrastructure & Platform

- **Cloud**: AWS (VPC, EKS, ElastiCache, ECR, IAM)
- **Kubernetes**: Amazon EKS 1.28+
- **Service Mesh**: Istio 1.x (mTLS, traffic management, telemetry)
- **IaC**: Terraform 1.5+
- **CI/CD**: GitHub Actions

### Observability & Security

- **Metrics**: Prometheus, Grafana
- **Tracing**: Jaeger (OpenTelemetry)
- **Topology**: Kiali
- **Security**: CodeQL, Trivy, Gitleaks, Semgrep, tfsec, Checkov

### Change Management

- **ServiceNow**: DevOps Change Velocity v6.1.0
- **Table API**: Standard change management
- **DevOps Change API**: Modern change velocity
- **CMDB**: Automated infrastructure discovery

## Limitations

This demo uses an **ultra-minimal cluster configuration** to reduce costs:

⚠️ **Single Node Cluster**:
- **Capacity**: 1x t3.large (2 vCPU, 8 GB RAM)
- **Max pods**: ~38 total
- **Environments**: Can run dev OR qa OR prod (not all simultaneously)
- **Cost**: ~$134/month

**For production or multi-environment testing**, see [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for scaling options.

## Common Tasks

```bash
# Infrastructure
just tf-init                     # Initialize Terraform
just tf-plan                     # Preview changes
just tf-apply                    # Deploy infrastructure

# Kubernetes
just k8s-config                  # Configure kubectl
kubectl apply -k overlays/dev    # Deploy to dev
kubectl get pods -n microservices-dev

# Observability
just istio-kiali                 # Service topology
just istio-grafana               # Metrics dashboards
just cluster-status              # Complete cluster overview

# Development
just docker-build frontend       # Build single service
just docker-build-all            # Build all services
just k8s-logs frontend           # View service logs

# ServiceNow
gh workflow run deploy-with-servicenow-basic.yaml -f environment=dev
gh workflow run aws-infrastructure-discovery.yaml
```

**Full command reference**: Run `just` to see all 50+ commands

## Documentation

### Essential Guides

- **[ONBOARDING.md](docs/ONBOARDING.md)** - New developer complete setup
- **[ServiceNow Integration](docs/servicenow-integration/)** - Change management setup
- **[COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** - Scaling and cost options

### Architecture

- **[REPOSITORY-STRUCTURE.md](docs/architecture/REPOSITORY-STRUCTURE.md)** - Detailed codebase guide
- **[ISTIO-DEPLOYMENT.md](docs/architecture/ISTIO-DEPLOYMENT.md)** - Service mesh configuration

### Development

- **[development-guide.md](docs/development/development-guide.md)** - Making changes
- **[adding-new-microservice.md](docs/development/adding-new-microservice.md)** - Adding services

## Contributing

This is a demonstration repository showing integration patterns. For production use:

1. Fork this repository
2. Customize for your organization
3. Update ServiceNow instance URLs
4. Configure your AWS account
5. Adjust scaling based on your needs

## Support

- **Issues**: GitHub Issues for bugs and questions
- **ServiceNow**: Contact ServiceNow support for platform issues
- **AWS**: AWS Support for infrastructure questions

## Migration from GCP

This demo was originally from Google Cloud's microservices-demo and has been migrated to AWS. See [MIGRATION-SUMMARY.md](MIGRATION-SUMMARY.md) for details on the migration.

**Key changes**:
- GKE → Amazon EKS
- Google Memorystore → Amazon ElastiCache
- GCR → Amazon ECR
- Google Cloud Load Balancer → AWS NLB with Istio
- Complete Terraform rewrite for AWS

## Credits

- **Original Application**: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)
- **AWS Migration**: Calitti DevOps Team
- **ServiceNow Integration**: Custom implementation

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details

---

**Version**: 1.0.1
**Last Updated**: 2025-10-20
**AWS Region**: eu-west-2 (London)
**Cluster**: microservices
**Kubernetes**: 1.28+
**Istio**: 1.x
