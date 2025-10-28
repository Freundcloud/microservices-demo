# ServiceNow + GitHub DevOps Integration Demo

<p align="center">
<img src="/src/frontend/static/icons/Hipster_HeroLogoMaroon.svg" width="300" alt="Online Boutique" />
</p>

![ServiceNow](https://img.shields.io/badge/ServiceNow-DevOps%20Change-green)
![GitHub Actions](https://img.shields.io/badge/GitHub-Actions-blue)
![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-Automated-brightgreen)
![AWS](https://img.shields.io/badge/Cloud-AWS-orange)

## 🎯 What This Demo Showcases

**This is a ServiceNow + GitHub DevOps Change Management integration demo** that demonstrates automated, compliant deployments across multiple environments.

**Primary Focus:**

- ✅ **Automated Change Requests**: GitHub Actions automatically creates ServiceNow Change Requests
- ✅ **13 Custom Fields**: Complete GitHub context (repo, branch, commit, actor, environment)
- ✅ **Multi-Environment Approvals**: Dev auto-approved, QA/Prod require manual approval
- ✅ **Complete Audit Trail**: Full compliance evidence and traceability
- ✅ **Work Item Integration**: GitHub Issues tracked in ServiceNow
- ✅ **Test Results Upload**: Automated evidence for change approvals
- ✅ **Security Scanning**: 10+ scanners with results uploaded to ServiceNow

**Test Application:**
The **Online Boutique** microservices application (12 services on AWS EKS) serves as the test infrastructure to demonstrate the integration value. Kubernetes/AWS are tools to show the integration—not the focus of the demo.

## 🚀 Quick Start

**Total Setup Time: 2-3 hours** (AWS + GitHub + ServiceNow)

### Step-by-Step Setup

Follow these guides in order:

1. **[AWS Deployment Guide](docs/1-AWS-DEPLOYMENT-GUIDE.md)** (30-45 min)
   - Deploy EKS cluster and infrastructure
   - Configure AWS credentials
   - Run Terraform deployment

2. **[GitHub Setup Guide](docs/2-GITHUB-SETUP-GUIDE.md)** (20-30 min)
   - Configure GitHub Actions workflows
   - Set up AWS and ServiceNow secrets
   - Build and push container images

3. **[ServiceNow Integration Guide](docs/3-SERVICENOW-INTEGRATION-GUIDE.md)** (45-60 min)
   - Install ServiceNow DevOps plugin
   - Create 13 custom fields on change_request table
   - Configure approval workflows
   - Test the integration

**See:** [Documentation Hub](docs/README.md) for complete navigation

### Quick Deploy (For Experienced Users)

```bash
# 1. Deploy infrastructure
source .envrc  # Load AWS credentials
just tf-apply  # Deploy EKS cluster (~15 min)

# 2. Configure kubectl
just k8s-config

# 3. Deploy to environments
kubectl apply -k kustomize/overlays/dev
kubectl apply -k kustomize/overlays/qa
kubectl apply -k kustomize/overlays/prod

# 4. Automated promotion pipeline
just promote v1.0.0 all  # Promotes version across all environments
```

## 📚 Documentation

### 🚀 Getting Started

**Follow these 3 guides to get the demo running** (Total: 2-3 hours):

1. **[AWS Deployment Guide](docs/1-AWS-DEPLOYMENT-GUIDE.md)** (30-45 min)
   - Deploy EKS cluster and infrastructure to AWS
   - Prerequisites, AWS setup, Terraform deployment

2. **[GitHub Setup Guide](docs/2-GITHUB-SETUP-GUIDE.md)** (20-30 min)
   - Configure GitHub Actions and workflows
   - Set up secrets, build and deploy images

3. **[ServiceNow Integration Guide](docs/3-SERVICENOW-INTEGRATION-GUIDE.md)** (45-60 min)
   - Install ServiceNow DevOps plugin
   - Create custom fields, configure change automation
   - Set up approval workflows

### 🎯 Demo Materials

**This is a ServiceNow + GitHub DevOps integration demo** (Kubernetes/AWS are just test infrastructure):

- **[Demo Script](docs/SERVICENOW-GITHUB-DEMO-GUIDE.md)** - Complete demo walkthrough with 5 scenarios
- **[Demo Slides](docs/SERVICENOW-GITHUB-DEMO-SLIDES.md)** - 18-slide presentation deck

### 📖 Complete Documentation

- **[Documentation Hub](docs/README.md)** - Navigation guide for all documentation
- **[🔧 Justfile Reference](justfile)** - All 50+ automation commands
- **[💰 Cost Optimization](COST-OPTIMIZATION.md)** - Scaling and pricing options

**Additional documentation** (architecture, development, troubleshooting) is available in [docs/_archive](docs/_archive/)

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

### AWS Infrastructure (Test Environment)

**Ultra-Minimal Configuration** (~$134/month):

- **Amazon EKS**: Single managed Kubernetes cluster (1 node, t3.large)
- **VPC**: Multi-AZ networking in eu-west-2 (London)
- **ElastiCache**: Redis for session storage (cache.t3.micro)
- **ECR**: Container registry with vulnerability scanning
- **ALB**: Application Load Balancer for ingress
- **IAM**: IRSA for secure AWS access

**3 Environments on 1 Node**:

- **microservices-dev**: 1 replica per service (10 pods)
- **microservices-qa**: 1 replica per service (10 pods)
- **microservices-prod**: 1 replica per service (10 pods)

**Region**: eu-west-2 (London, UK)

**See:** [Cost Optimization Guide](COST-OPTIMIZATION.md) for configuration options

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

## 🔄 ServiceNow DevOps Integration

**The core value proposition of this demo!**

### Automated Change Management

Every deployment automatically creates a ServiceNow Change Request with complete GitHub context:

**13 Custom Fields on change_request table:**

- `u_source` - "GitHub Actions"
- `u_correlation_id` - Workflow run ID for traceability
- `u_repository` - Git repository name
- `u_branch` - Git branch name
- `u_commit_sha` - Git commit hash
- `u_actor` - GitHub user who triggered deployment
- `u_environment` - Target environment (dev/qa/prod)
- `u_github_run_id` - Workflow run ID
- `u_github_run_url` - Link to workflow run
- `u_github_repo_url` - Link to repository
- `u_github_commit_url` - Link to commit
- `u_version` - Application version
- `u_deployment_type` - Type of deployment

### Multi-Environment Approval Workflows

**Development (Auto-Approved)**:

- Changes automatically approved
- Deployed immediately
- Fast iteration for developers

**QA (Manual Approval)**:

- QA Lead approval required
- ServiceNow Change Request created
- Tests must pass before deployment

**Production (CAB Approval)**:

- Change Advisory Board (CAB) approval required
- Complete change documentation
- Test evidence attached
- Security scan results included

### Work Item Integration

- GitHub Issues automatically tracked in ServiceNow Work Items
- Linked to Change Requests
- Complete traceability from issue to deployment

### Test Results Upload

- Unit tests, integration tests, security scans
- Automated evidence generation
- Attached to Change Requests
- Enables risk-based approval decisions

### Compliance Benefits

- ✅ **SOC 2**: Complete audit trail
- ✅ **ISO 27001**: Change management evidence
- ✅ **NIST CSF**: Access control and monitoring
- ✅ **HIPAA/PCI DSS**: Deployment tracking

**See:** [ServiceNow Integration Guide](docs/3-SERVICENOW-INTEGRATION-GUIDE.md) for setup

## 🌍 Multi-Environment Architecture

**Ultra-Minimal Demo Configuration** - One cluster, one node, three environments:

### Single Node Configuration

- **Node**: 1 × t3.large (2 vCPU, 8GB RAM)
- **Total Capacity**: ~38 pods (85-90% utilized)
- **Purpose**: Demo/development only (not production-ready)
- **Cost**: ~$134/month (80% cheaper than multi-node setup)

### Three Namespaces (Namespace Isolation)

**Development Environment** (`microservices-dev`):

- **Replicas**: 1 per service (10 pods total)
- **Purpose**: Fast iteration, auto-approved changes
- **Resources**: Minimal CPU/memory requests
- **ServiceNow**: Auto-approved deployments

**QA Environment** (`microservices-qa`):

- **Replicas**: 1 per service (10 pods total)
- **Purpose**: Testing and validation
- **Resources**: Moderate CPU/memory requests
- **ServiceNow**: QA Lead approval required

**Production Environment** (`microservices-prod`):

- **Replicas**: 1 per service (10 pods total)
- **Purpose**: Production-like deployment
- **Resources**: Higher CPU/memory requests
- **ServiceNow**: CAB approval required

### Resource Quotas & LimitRanges

Each namespace has:

- **ResourceQuota**: Prevents overconsumption
- **LimitRange**: Enforces min/max resource limits
- **Network Policies**: Namespace isolation

### Deployment Strategy

```bash
just tf-apply           # Creates single cluster
just k8s-config         # Configure kubectl
kubectl apply -k kustomize/overlays/dev    # Deploy to dev namespace
kubectl apply -k kustomize/overlays/qa     # Deploy to qa namespace
kubectl apply -k kustomize/overlays/prod   # Deploy to prod namespace
```

**Alternative Configurations:**

- **Balanced**: 1 × t3.xlarge with full observability (~$195/month)
- **Safer Minimal**: 2 nodes with redundancy (~$256/month)
- **Production**: Multi-node groups with HA (see [Cost Optimization](COST-OPTIMIZATION.md))

**See:** [Cost Optimization Guide](COST-OPTIMIZATION.md) for all configuration options

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
- **Trivy**: Container vulnerability scanning + SBOM generation
- **Grype**: Dependency vulnerability scanning
- **Gitleaks**: Secret detection
- **Semgrep**: Pattern-based code analysis
- **Checkov/tfsec**: Terraform security scanning
- **OWASP Dependency Check**: Known vulnerable dependencies

**Security Results Integration:**

- All results appear in GitHub Security tab
- SARIF format reports uploaded to GitHub Code Scanning
- Vulnerability data uploaded to ServiceNow for approval evidence
- Complete compliance audit trail

**See:** [GitHub Setup Guide - Security Scanning](docs/2-GITHUB-SETUP-GUIDE.md#security-scanning)

## 📊 Cost Estimation

**Ultra-Minimal Demo Configuration** (~$134/month):

| Component | Monthly Cost |
|-----------|--------------|
| EKS Control Plane | $73 |
| EC2 Nodes (1 × t3.large) | $32 |
| NAT Gateway | $15 |
| Load Balancer (ALB) | $8 |
| ElastiCache Redis (cache.t3.micro) | $4 |
| ECR + Logs | $2 |
| **Total** | **~$134/month** |

**Cost Optimization Options:**

- **Current (Ultra-Minimal)**: 1 node, minimal resources → ~$134/mo
- **Balanced**: 1 × t3.xlarge, full observability → ~$195/mo
- **Safer Minimal**: 2 nodes, redundancy → ~$256/mo
- **Production-Ready**: Multi-node groups, HA → ~$400-600/mo

**See:** [Complete Cost Optimization Guide](COST-OPTIMIZATION.md)

## 🚢 CI/CD Pipeline

**Complete GitHub Actions automation with ServiceNow integration:**

### Main Workflows

- **[MASTER-PIPELINE.yaml](.github/workflows/MASTER-PIPELINE.yaml)** - Orchestrates entire deployment pipeline
  - Calls security scan, build, deploy, and ServiceNow workflows
  - Manages multi-environment promotion
  - Handles approval gates

- **[build-images.yaml](.github/workflows/build-images.yaml)** - Smart container builds
  - Only rebuilds changed services
  - Multi-arch support (amd64/arm64)
  - Vulnerability scanning with Trivy
  - SBOM generation for compliance

- **[security-scan.yaml](.github/workflows/security-scan.yaml)** - Comprehensive security
  - CodeQL, Trivy, Grype, Gitleaks, Semgrep, Checkov, tfsec
  - SARIF upload to GitHub Security tab
  - Vulnerability upload to ServiceNow

- **[deploy-environment.yaml](.github/workflows/deploy-environment.yaml)** - Kubernetes deployment
  - Environment-specific deployment (dev/qa/prod)
  - Health check verification
  - Rollback on failure

- **[servicenow-integration.yaml](.github/workflows/servicenow-integration.yaml)** - Change automation
  - Creates ServiceNow Change Requests
  - Populates 13 custom fields
  - Registers work items and test results
  - Updates change state after deployment

### Automated Promotion Pipeline

```bash
just promote v1.2.3 all  # Automated version promotion across environments
```

The promotion script:

1. Creates release branch
2. Updates all Kustomize overlays
3. Creates PR and waits for CI checks
4. Prompts for merge approval
5. Deploys to DEV (auto-approved)
6. Prompts for QA deployment (requires ServiceNow approval)
7. Prompts for PROD deployment (requires CAB approval)

**Setup:** [GitHub Setup Guide](docs/2-GITHUB-SETUP-GUIDE.md)

## 📸 Screenshots

| Home Page | Checkout Screen |
|-----------|-----------------|
| [![Screenshot of store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Screenshot of checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

## 🤝 Contributing

Contributions welcome! Please:

1. Read the [Documentation Hub](docs/README.md)
2. Follow existing code patterns
3. Run security scans: `just security-scan-all`
4. Update documentation as needed
5. Test your changes in dev environment first
6. Submit pull request with clear description

## 📝 License

This project is licensed under the Apache License 2.0 - see individual files for details.

Original Google Cloud version: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

## 🆘 Support

### Getting Help

1. **Start with the guides**: [Documentation Hub](docs/README.md)
   - [AWS Deployment Guide](docs/1-AWS-DEPLOYMENT-GUIDE.md#troubleshooting)
   - [GitHub Setup Guide](docs/2-GITHUB-SETUP-GUIDE.md#troubleshooting)
   - [ServiceNow Integration Guide](docs/3-SERVICENOW-INTEGRATION-GUIDE.md#troubleshooting)
2. Search existing GitHub issues
3. Open new issue with:
   - Problem description
   - Steps to reproduce
   - Logs and error messages
   - Environment details (AWS region, ServiceNow instance, etc.)

### Additional Resources

- [ServiceNow DevOps Documentation](https://docs.servicenow.com/bundle/tokyo-devops/page/product/enterprise-dev-ops/concept/dev-ops-home.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**⭐ Star this repository if you find it useful!**

**Perfect for demonstrating:**
- **ServiceNow + GitHub DevOps Change Management** (Primary focus!)
- Automated change requests with custom GitHub context fields
- Multi-environment approval workflows (dev/qa/prod)
- Complete audit trail and compliance evidence
- GitOps workflows with GitHub Actions
- Comprehensive security scanning pipeline
- Multi-language microservices on AWS EKS (test application)
- Infrastructure as Code with Terraform
