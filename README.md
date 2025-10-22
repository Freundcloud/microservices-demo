# Online Boutique - AWS Deployment

<p align="center">
<img src="/src/frontend/static/icons/Hipster_HeroLogoMaroon.svg" width="300" alt="Online Boutique" />
</p>

![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-brightgreen)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)
![AWS](https://img.shields.io/badge/Cloud-AWS-orange)
![Istio](https://img.shields.io/badge/Service%20Mesh-Istio-blue)

**Online Boutique** is a cloud-native microservices demo application deployed on AWS. The application is a web-based e-commerce platform where users can browse items, add them to the cart, and purchase them.

This AWS-focused version demonstrates modern cloud-native practices perfect for **GitHub + AWS + ServiceNow** collaboration workflows.

## 🚀 Quick Start

### For New Developers

```bash
# 1. Clone repository
git clone <repository-url>
cd microservices-demo

# 2. Run automated onboarding
just onboard

# 3. Configure AWS credentials
cp .envrc.example .envrc
# Edit .envrc with your AWS credentials
source .envrc

# 4. Deploy single cluster (contains dev, qa, prod node groups)
just tf-apply

# 5. Install Helm charts and Istio components
./post-install.sh

# 6. Configure kubectl and deploy to environments
just k8s-config
kubectl apply -k kustomize/overlays/dev
kubectl apply -k kustomize/overlays/qa
kubectl apply -k kustomize/overlays/prod

# 6. Access application
just k8s-url
```

**See:** [Complete Onboarding Guide](docs/ONBOARDING.md) for detailed setup instructions.

### For Experienced Users

```bash
# Deploy infrastructure (single cluster with dev, qa, prod node groups)
cd terraform-aws
source ../.envrc  # Load AWS credentials
terraform apply
cd ..

# Install Helm charts and Istio service mesh
./post-install.sh

# Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name microservices

# Deploy to each environment namespace
kubectl apply -k ../kustomize/overlays/dev
kubectl apply -k ../kustomize/overlays/qa
kubectl apply -k ../kustomize/overlays/prod
```

## 📚 Documentation

**Complete documentation is available in the [docs/](docs/) directory.**

### Essential Guides

- **[🎓 Developer Onboarding](docs/ONBOARDING.md)** - Start here! Complete setup guide for new developers
- **[📖 Documentation Index](docs/README.md)** - Complete documentation overview
- **[✨ What's New](docs/WHATS-NEW.md)** - Latest features: ServiceNow integration, dependency scanning, enhanced security
- **[☁️  AWS Deployment Guide](docs/README-AWS.md)** - Comprehensive AWS deployment instructions
- **[🔧 Justfile Reference](justfile)** - All available automation commands

### Setup & Configuration

- [AWS Setup Guide](docs/setup/AWS-SETUP.md) - AWS credentials and permissions
- [GitHub Actions Setup](docs/setup/GITHUB-ACTIONS-SETUP.md) - CI/CD configuration
- [Security Scanning](docs/setup/SECURITY-SCANNING.md) - Security tools and processes

### Architecture & Design

- [Repository Structure](docs/architecture/REPOSITORY-STRUCTURE.md) - Complete codebase guide
- [Istio Service Mesh](docs/architecture/ISTIO-DEPLOYMENT.md) - Service mesh implementation
- [Product Requirements](docs/architecture/product-requirements.md) - System specifications

### Development

- [Development Guide](docs/development/development-guide.md) - Development workflows
- [Adding Microservices](docs/development/adding-new-microservice.md) - Service creation guide

## 🏗️ Architecture

**Online Boutique** consists of 12 microservices written in different languages communicating over gRPC:

| Service | Language | Description |
|---------|----------|-------------|
| [frontend](src/frontend) | Go | Web UI server |
| [cartservice](src/cartservice) | C# | Shopping cart with Redis |
| [productcatalogservice](src/productcatalogservice) | Go | Product inventory |
| [currencyservice](src/currencyservice) | Node.js | Currency conversion |
| [paymentservice](src/paymentservice) | Node.js | Payment processing |
| [shippingservice](src/shippingservice) | Go | Shipping calculations |
| [emailservice](src/emailservice) | Python | Email notifications |
| [checkoutservice](src/checkoutservice) | Go | Order orchestration |
| [recommendationservice](src/recommendationservice) | Python | Product recommendations |
| [adservice](src/adservice) | Java | Advertisement serving |
| [loadgenerator](src/loadgenerator) | Python | Load testing |
| [shoppingassistantservice](src/shoppingassistantservice) | Java | AI shopping assistant |

### AWS Infrastructure

- **Amazon EKS**: Single managed Kubernetes cluster with 3 dedicated node groups
- **VPC**: Multi-AZ networking in eu-west-2 (London) across 3 availability zones
- **ElastiCache**: Redis for session storage (shared across all environments)
- **ECR**: Container registry with vulnerability scanning
- **Istio**: Service mesh with mTLS, observability (shared control plane)
- **IAM**: IRSA for secure AWS access
- **NLB**: Network Load Balancer for ingress

**Region**: eu-west-2 (London, UK)

**See:** [Complete Architecture Guide](docs/architecture/REPOSITORY-STRUCTURE.md) | [Single-Cluster Migration](SINGLE-CLUSTER-MIGRATION.md)

## ✨ Features

### Production-Ready
- ✅ Multi-language microservices (Go, Python, Java, Node.js, C#)
- ✅ gRPC communication with Protocol Buffers
- ✅ Service mesh with Istio for security and observability
- ✅ Autoscaling with Cluster Autoscaler and HPA
- ✅ Health checks and readiness probes
- ✅ Resource limits configured
- ✅ Structured logging to CloudWatch

### Security
- ✅ Container scanning with Trivy
- ✅ SAST with CodeQL (5 languages) and Semgrep
- ✅ Secret detection with Gitleaks
- ✅ IaC security with Checkov and tfsec
- ✅ mTLS enforced between all services
- ✅ IRSA for secure AWS credentials
- ✅ Network isolation with Security Groups
- ✅ SBOM generation for compliance

### Observability
- ✅ Distributed tracing with Jaeger
- ✅ Metrics with Prometheus
- ✅ Visualization with Grafana dashboards
- ✅ Service topology with Kiali
- ✅ CloudWatch integration for logs

### Developer Experience
- ✅ One-command deployment with `just`
- ✅ Infrastructure as Code with Terraform
- ✅ Smart build detection (only rebuild changed services)
- ✅ Multi-environment support (dev, qa, prod)
- ✅ Comprehensive documentation
- ✅ Automated onboarding

## 🌍 Single-Cluster Multi-Environment Architecture

**One EKS cluster** hosting **three environments** with four dedicated node groups:

### System Node Group (Cluster Infrastructure)

- **Node Group**: 2-3 × t3.small (2 vCPU, 2GB RAM)
- **Purpose**: Hosts cluster add-ons (CoreDNS, EBS CSI driver, metrics-server, etc.)
- **Node Labels**: `role=system`, `workload=cluster-addons`
- **Taints**: None (allows system pods to schedule)
- **Cost**: ~£12/month

### Development Environment

- **Namespace**: `microservices-dev`
- **Node Group**: 2-4 × t3.medium (2 vCPU, 4GB RAM)
- **Replicas**: 1 per service
- **Features**: Basic Istio, no load generator
- **Node Labels**: `environment=dev`, `workload=microservices-dev`

### QA Environment

- **Namespace**: `microservices-qa`
- **Node Group**: 3-6 × t3.large (2 vCPU, 8GB RAM)
- **Replicas**: 2 per service
- **Features**: Full Istio observability stack, load generator enabled
- **Node Labels**: `environment=qa`, `workload=microservices-qa`

### Production Environment

- **Namespace**: `microservices-prod`
- **Node Group**: 5-10 × t3.xlarge (4 vCPU, 16GB RAM)
- **Replicas**: 3 per service (High Availability)
- **Features**: Full Istio stack, no load generator
- **Node Labels**: `environment=prod`, `workload=microservices-prod`

**Node Isolation**: Each environment has dedicated nodes via taints/tolerations - dev pods can't run on prod nodes!

**Total Cost**: ~£470/month (vs ~£549/month for 3 separate clusters) - **14% savings**

**Deploy the cluster:**

```bash
just tf-apply           # Creates single cluster with all 3 node groups
just k8s-config         # Configure kubectl
kubectl apply -k kustomize/overlays/dev    # Deploy to dev
kubectl apply -k kustomize/overlays/qa     # Deploy to qa
kubectl apply -k kustomize/overlays/prod   # Deploy to prod
```

**See:** [Single-Cluster Migration Guide](SINGLE-CLUSTER-MIGRATION.md) | [Kustomize Overlays](kustomize/overlays/README.md)

## 🛠️ Common Tasks

All tasks are available via the `justfile`. Run `just` to see all commands.

### Infrastructure

```bash
just tf-plan                  # Preview infrastructure changes
just tf-apply                 # Deploy single cluster with 3 node groups
just tf-destroy               # Destroy cluster (WARNING: all environments!)
just tf-validate              # Validate Terraform code
just tf-test                  # Run Terraform tests
```

### Kubernetes

```bash
just k8s-config               # Configure kubectl for microservices cluster
kubectl apply -k kustomize/overlays/dev   # Deploy to dev namespace
kubectl apply -k kustomize/overlays/qa    # Deploy to qa namespace
kubectl apply -k kustomize/overlays/prod  # Deploy to prod namespace
just k8s-status               # Check cluster status
just k8s-logs frontend        # View service logs
just k8s-restart frontend     # Restart deployment
just k8s-scale frontend 5     # Scale deployment
just k8s-url                  # Get application URL
```

### Istio Observability

```bash
just istio-kiali              # Service mesh dashboard
just istio-grafana            # Metrics visualization
just istio-jaeger             # Distributed tracing
just istio-prometheus         # Metrics database
just istio-analyze            # Analyze configuration
```

### Development

```bash
just docker-build frontend    # Build container image
just docker-build-all         # Build all images
just ecr-login                # Login to AWS ECR
just ecr-push frontend dev    # Push image to ECR
```

### Security & Validation

```bash
just validate                 # Run all validations
just security-scan-all        # Run all security scans
just security-scan-terraform  # Scan IaC
just security-scan-secrets    # Detect secrets
```

## 🔐 Security

Comprehensive security scanning on every commit:

- **CodeQL**: Static analysis for Python, JavaScript, Go, Java, C#
- **Trivy**: Container vulnerability scanning
- **Gitleaks**: Secret detection
- **Semgrep**: Pattern-based code analysis
- **Checkov/tfsec**: Terraform security scanning
- **OWASP Dependency Check**: Known vulnerable dependencies

All results appear in GitHub Security tab.

**See:** [Security Scanning Guide](docs/setup/SECURITY-SCANNING.md)

## 📊 Cost Estimation

Monthly AWS costs by environment (eu-west-2):

| Component | Dev | QA | Prod |
|-----------|-----|-----|------|
| EKS Control Plane | £60 | £60 | £60 |
| EC2 Nodes | £37 | £74 | £205 |
| NAT Gateway | £27 | £27 | £37 |
| Load Balancer | £15 | £15 | £15 |
| ElastiCache Redis | £8 | £12 | £41 |
| ECR + Logs | £5 | £5 | £5 |
| **Total/month** | **~£152** | **~£193** | **~£363** |

**Optimization tips available in:** [Cost Optimization](docs/README-AWS.md#cost-optimization)

## 🚢 CI/CD Pipeline

Automated workflows with GitHub Actions:

- **[terraform-validate.yaml](.github/workflows/terraform-validate.yaml)** - Multi-environment validation and testing
- **[terraform-plan.yaml](.github/workflows/terraform-plan.yaml)** - Infrastructure preview on PRs
- **[terraform-apply.yaml](.github/workflows/terraform-apply.yaml)** - Automated deployment on merge
- **[build-and-push-images.yaml](.github/workflows/build-and-push-images.yaml)** - Container builds with security scans
- **[security-scan.yaml](.github/workflows/security-scan.yaml)** - Comprehensive security scanning
- **[deploy-application.yaml](.github/workflows/deploy-application.yaml)** - Application deployment to EKS

**Setup:** [GitHub Actions Configuration](docs/setup/GITHUB-ACTIONS-SETUP.md)

## 📸 Screenshots

| Home Page | Checkout Screen |
|-----------|-----------------|
| [![Screenshot of store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Screenshot of checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

## 🤝 Contributing

Contributions welcome! Please:

1. Read the [Development Guide](docs/development/development-guide.md)
2. Follow existing code patterns
3. Run security scans: `just security-scan-all`
4. Update documentation as needed
5. Submit pull request

## 📝 License

This project is licensed under the Apache License 2.0 - see individual files for details.

Original Google Cloud version: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

## 🆘 Support

### Getting Help

1. Check the [Troubleshooting Guide](docs/README-AWS.md#troubleshooting)
2. Review [Documentation Index](docs/README.md)
3. Search existing GitHub issues
4. Open new issue with:
   - Problem description
   - Steps to reproduce
   - Logs and error messages
   - Environment details

### Additional Resources

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

**⭐ Star this repository if you find it useful!**

**Perfect for demonstrating:**
- Microservices architecture on AWS EKS
- Istio service mesh with mTLS
- GitOps workflows with GitHub Actions
- Multi-language gRPC applications
- Comprehensive security scanning
- Infrastructure as Code with Terraform
- Cloud-native observability
