# ServiceNow + GitHub DevOps Integration Demo

> **Primary Focus:** ServiceNow DevOps Change Management integration with GitHub Actions
>
> **Test Application:** Cloud-native microservices (Online Boutique) on AWS EKS

## 🎯 What is This Demo?

**This demonstrates ServiceNow + GitHub DevOps Change Management integration** with automated, compliant deployments across multiple environments.

### Primary Focus (The Demo Value!)

- ✅ **Automated Change Requests**: GitHub Actions automatically creates ServiceNow Change Requests
- ✅ **13 Custom Fields**: Complete GitHub context (repo, branch, commit, actor, environment)
- ✅ **Multi-Environment Approvals**: Dev auto-approved, QA/Prod require manual approval
- ✅ **Complete Audit Trail**: Full compliance evidence and traceability
- ✅ **Work Item Integration**: GitHub Issues tracked in ServiceNow
- ✅ **Test Results Upload**: Automated evidence for change approvals
- ✅ **Security Scanning**: 10+ scanners with results uploaded to ServiceNow

### Test Application (Supporting Infrastructure)

The **Online Boutique** e-commerce application serves as test infrastructure to demonstrate the integration:

- **12 Polyglot Microservices** (Go, Python, Java, Node.js, C#)
- **AWS EKS** (Kubernetes cluster for deployment)
- **Infrastructure as Code** (Terraform)
- **CI/CD Automation** (GitHub Actions orchestration)
- **Security Scanning** (Multi-tool security pipeline)

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

### Infrastructure (Test Environment Only!)

**Cloud Provider**: AWS
**Region**: eu-west-2 (London, UK)

**Ultra-Minimal Configuration** (~$134/month):

- **Kubernetes**: Amazon EKS (1 node, t3.large)
- **Networking**: AWS VPC with 3 availability zones
- **Ingress**: AWS ALB (Application Load Balancer)
- **Redis**: Amazon ElastiCache (cache.t3.micro)
- **Container Registry**: Amazon ECR

**3 Environments on 1 Node**:

- **microservices-dev**: 1 replica per service (10 pods)
- **microservices-qa**: 1 replica per service (10 pods)
- **microservices-prod**: 1 replica per service (10 pods)
- **Total**: ~38 pods (85-90% capacity)

**Configuration Options**:

- **Current (Ultra-Minimal)**: 1 node → ~$134/mo
- **Balanced**: 1 × t3.xlarge with observability → ~$195/mo
- **Safer Minimal**: 2 nodes with redundancy → ~$256/mo
- **Production**: Multi-node groups with HA → ~$400-600/mo

**See**: [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for all options

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

### 2. ServiceNow Integration (THE MAIN VALUE!)

**Automated Change Management**:

Every deployment automatically creates a ServiceNow Change Request with:

**13 Custom Fields on change_request table**:

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

**Multi-Environment Approval Workflows**:

- **Dev**: Auto-approved deployments (fast iteration)
- **QA**: QA Lead approval required (testing validation)
- **Prod**: CAB approval required (complete change documentation)

**Work Item Integration**:

- GitHub Issues automatically tracked in ServiceNow Work Items
- Linked to Change Requests
- Complete traceability from issue to deployment

**Test Results Upload**:

- Unit tests, integration tests, security scans
- Automated evidence generation
- Attached to Change Requests
- Enables risk-based approval decisions

**Compliance Benefits**:

- ✅ **SOC 2**: Complete audit trail
- ✅ **ISO 27001**: Change management evidence
- ✅ **NIST CSF**: Access control and monitoring
- ✅ **HIPAA/PCI DSS**: Deployment tracking

**Setup Guide**: [docs/3-SERVICENOW-INTEGRATION-GUIDE.md](docs/3-SERVICENOW-INTEGRATION-GUIDE.md)

### 3. Security Scanning

**10+ Integrated Security Tools**:

- **CodeQL**: Static analysis (Python, JavaScript, Go, Java, C#)
- **Trivy**: Container vulnerability scanning + SBOM generation
- **Grype**: Dependency vulnerability scanning
- **Gitleaks**: Secret detection in code and history
- **Semgrep**: SAST with custom security rules
- **tfsec**: Terraform security scanning
- **Checkov**: IaC security best practices
- **OWASP Dependency Check**: Known vulnerable dependencies
- **Bandit**: Python security linter
- **Gosec**: Go security scanner

**Security Results Integration**:

- ✅ GitHub Security tab (SARIF format)
- ✅ ServiceNow Change Requests (as approval evidence)
- ✅ Complete compliance audit trail
- ✅ Automated vulnerability tracking

### 4. Observability (Optional - Disabled for Cost)

**CloudWatch Integration**:

- Application logs automatically shipped to CloudWatch
- Structured logging with correlation IDs
- Query logs across all services

**Optional: Istio Observability** (disabled in ultra-minimal config):

- **Kiali**: Service topology visualization
- **Grafana**: Metrics dashboards
- **Jaeger**: Distributed tracing
- **Prometheus**: Metrics collection

Enable with `enable_istio_addons = true` in terraform.tfvars (adds ~$60/mo)

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

**Total Setup Time: 2-3 hours** (AWS + GitHub + ServiceNow)

### Follow These 3 Guides in Order

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

### Quick Commands Overview

```bash
# 1. Deploy Infrastructure
source .envrc
just tf-apply  # Takes ~15 minutes

# 2. Deploy Application
just k8s-config
kubectl apply -k kustomize/overlays/dev
kubectl apply -k kustomize/overlays/qa
kubectl apply -k kustomize/overlays/prod

# 3. Automated Version Promotion
just promote v1.0.0 all  # Promotes across all environments with ServiceNow approvals

# 4. Check Cluster Status
just cluster-status
kubectl get pods -n microservices-dev
```

**Complete Setup Guide**: [Documentation Hub](docs/README.md)

## Use Cases

This demo is designed for:

### 1. ServiceNow + GitHub Integration Demo (PRIMARY!)

**Perfect for demonstrating**:

- ✅ **Automated Change Requests** with complete GitHub context
- ✅ **Multi-Environment Approvals** (dev/qa/prod)
- ✅ **Complete Audit Trail** for compliance
- ✅ **Work Item Integration** (GitHub Issues → ServiceNow)
- ✅ **Security Evidence** attached to change requests
- ✅ **Risk-Based Approvals** with test results

**Target Audience**:

- ServiceNow administrators
- DevOps teams
- IT Governance/Compliance teams
- Change Advisory Board (CAB) members

### 2. DevOps Practice

**GitOps workflows**:

- All changes via Git + GitHub Actions
- Infrastructure as Code with Terraform
- Multi-environment promotion (dev → qa → prod)
- Security-first development

### 3. Compliance & Governance

**Complete Audit Trail**:

- Who deployed what, when, where, and why
- Automated evidence collection
- Security scan results for every deployment
- Approval workflows enforced programmatically

**Compliance Frameworks**:

- SOC 2 Type II (access controls + audit logs)
- ISO 27001 (change management)
- NIST Cybersecurity Framework
- HIPAA/PCI DSS (deployment tracking)

### 4. Learning Platform (Supporting Use Case)

**For teams learning**:

- Polyglot microservices architecture
- gRPC communication
- Kubernetes multi-environment deployments
- AWS EKS and managed services

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

## Limitations (Demo Configuration Only!)

This demo uses an **ultra-minimal cluster configuration** to reduce costs:

⚠️ **Not Production-Ready**:

- **Capacity**: 1x t3.large (2 vCPU, 8 GB RAM)
- **Max pods**: ~38 total (dev + qa + prod all on 1 node)
- **Replicas**: 1 per service (no redundancy)
- **Purpose**: **Demo and development only**
- **Cost**: ~$134/month (80% cheaper than production setup)

**For production deployments**, see [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) for:

- Multi-node configurations
- High availability setups
- Auto-scaling configurations
- Disaster recovery options

**Key Message**: *The infrastructure is minimal by design to demonstrate the ServiceNow + GitHub integration, not to showcase production Kubernetes architecture.*

## Common Tasks

```bash
# Infrastructure
just tf-init                     # Initialize Terraform
just tf-plan                     # Preview changes
just tf-apply                    # Deploy infrastructure (~15 min)

# Kubernetes Deployment
just k8s-config                  # Configure kubectl
kubectl apply -k kustomize/overlays/dev    # Deploy to dev
kubectl apply -k kustomize/overlays/qa     # Deploy to qa
kubectl apply -k kustomize/overlays/prod   # Deploy to prod

# Automated Promotion (ServiceNow Integration!)
just promote v1.2.3 all          # Automated version promotion
                                 # - Creates release branch
                                 # - Updates Kustomize overlays
                                 # - Creates PR and waits for CI
                                 # - Deploys to DEV (auto-approved)
                                 # - Prompts for QA (ServiceNow approval)
                                 # - Prompts for PROD (CAB approval)

# Cluster Management
just cluster-status              # Complete cluster overview
just k8s-logs frontend           # View service logs
kubectl get pods -n microservices-dev

# Development
just docker-build frontend       # Build single service
just docker-build-all            # Build all services

# Demo Workflows
just demo-run dev v1.0.0         # Run demo deployment with ServiceNow
```

**Full command reference**: Run `just` to see all 50+ commands

## Documentation

### 🚀 Essential Setup Guides (Start Here!)

1. **[AWS Deployment Guide](docs/1-AWS-DEPLOYMENT-GUIDE.md)** (30-45 min)
   - Deploy EKS cluster and infrastructure

2. **[GitHub Setup Guide](docs/2-GITHUB-SETUP-GUIDE.md)** (20-30 min)
   - Configure GitHub Actions and workflows

3. **[ServiceNow Integration Guide](docs/3-SERVICENOW-INTEGRATION-GUIDE.md)** (45-60 min)
   - Install DevOps plugin, create custom fields, configure approvals

### 🎯 Demo Materials

- **[Demo Script](docs/SERVICENOW-GITHUB-DEMO-GUIDE.md)** - Complete demo walkthrough
- **[Demo Slides](docs/SERVICENOW-GITHUB-DEMO-SLIDES.md)** - 18-slide presentation

### 📖 Complete Documentation

- **[Documentation Hub](docs/README.md)** - Navigation guide for all docs
- **[Cost Optimization](COST-OPTIMIZATION.md)** - Scaling and pricing options

**Additional documentation** (architecture, development, troubleshooting) available in [docs/_archive](docs/_archive/)

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
