# Documentation Index

> Complete documentation for the Microservices Demo project

**New to this project?** Start with **[DEMO-OVERVIEW.md](../DEMO-OVERVIEW.md)** to understand what this demo does.

**✨ Latest Updates**: See **[WHATS-NEW.md](WHATS-NEW.md)** for ServiceNow DevOps integration, dependency scanning, and enhanced security features.

## Quick Start Guides

### For Developers
- **[Onboarding Guide](ONBOARDING.md)** - Complete setup for new developers (30 minutes)
  - AWS credentials configuration
  - Terraform infrastructure deployment
  - Kubernetes cluster setup
  - First deployment

### For DevOps Engineers
- **[AWS Setup](setup/AWS-SETUP.md)** - AWS account and credentials
- **[GitHub Actions Setup](setup/GITHUB-ACTIONS-SETUP.md)** - CI/CD configuration
- **[Security Scanning](setup/SECURITY-SCANNING.md)** - Configure security tools

### For ServiceNow Integration
- **[ServiceNow Integration](servicenow-integration/SERVICENOW-INTEGRATION.md)** - Complete guide
  - Service account setup (5 min)
  - GitHub secrets configuration (2 min)
  - CMDB table creation (10 min)
  - Testing the integration (5 min)

## Documentation by Category

### 🏗️ Architecture

**Understanding the System**:
- **[Repository Structure](architecture/REPOSITORY-STRUCTURE.md)** - Complete codebase guide
  - Directory organization
  - Source code layout
  - Protocol Buffers
  - Kubernetes manifests
  - Terraform structure

- **[Istio Service Mesh](architecture/ISTIO-DEPLOYMENT.md)** - Service mesh configuration
  - Istio installation
  - mTLS security
  - Traffic management
  - Observability (Kiali, Grafana, Jaeger)
  - Troubleshooting

### 💻 Development

**Working with the Code**:
- **[Development Guide](development/development-guide.md)** - Daily development tasks
  - Local development setup
  - Building and testing services
  - Debugging techniques
  - Making changes to services

- **[Adding New Microservices](development/adding-new-microservice.md)** - Extending the application
  - Service creation template
  - Kubernetes integration
  - gRPC/Protocol Buffers
  - CI/CD integration

### 🚀 Deployment

**Getting to Production**:
- **[Complete AWS Deployment](README-AWS.md)** - Full deployment guide
  - Infrastructure setup
  - Multi-environment deployment (dev/qa/prod)
  - Cost estimation
  - Troubleshooting

- **[Terraform Backend](TERRAFORM-BACKEND-GUIDE.md)** - Remote state configuration
  - S3 backend setup
  - State locking with DynamoDB
  - Team collaboration

### 🔒 Security

**Security Tooling**:
- **[Security Scanning Setup](setup/SECURITY-SCANNING.md)** - Complete security pipeline
  - CodeQL (SAST for 5 languages)
  - Trivy (Container + SBOM)
  - Gitleaks (Secret detection)
  - Semgrep, Checkov, tfsec (IaC security)
  - GitHub Security integration

- **[Security Evidence](SECURITY-EVIDENCE-GUIDE.md)** - Evidence generation for compliance
  - SARIF format exports
  - ServiceNow attachment
  - Compliance reporting

### 🏢 ServiceNow Integration

**Change Management & CMDB**:
- **[ServiceNow Integration Guide](servicenow-integration/SERVICENOW-INTEGRATION.md)** ⭐ **START HERE**
  - Quick setup (15 minutes)
  - Two integration approaches (Table API vs DevOps Change)
  - Available workflows
  - Environment-specific approvals
  - CMDB automation
  - Testing and troubleshooting

**Additional ServiceNow Docs**:
- **[Quick Start](SERVICENOW-QUICK-START.md)** - 5-minute minimal setup
- **[Application Setup](SERVICENOW-APPLICATION-SETUP.md)** - Register "Online Boutique" app
- **[DevOps Change Velocity](SERVICENOW-DEVOPS-CHANGE-VELOCITY.md)** - Modern change management
- **[GitHub Spoke Configuration](SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md)** - IntegrationHub Spoke setup ⭐ **NEW**
- **[Best Practices](GITHUB-SERVICENOW-BEST-PRACTICES.md)** - Integration patterns
- **[Developer Onboarding](GITHUB-SERVICENOW-DEVELOPER-ONBOARDING.md)** - Team setup

### 📊 Operations

**Running in Production**:
- **[Cost Optimization](../COST-OPTIMIZATION.md)** - Scaling and pricing
  - Ultra-minimal config (~$134/month)
  - Balanced config (~$195/month)
  - Production config (~$442/month)
  - Node sizing recommendations

- **Monitoring** (via Istio dashboards):
  - Kiali: `just istio-kiali` (service topology)
  - Grafana: `just istio-grafana` (metrics)
  - Jaeger: `just istio-jaeger` (tracing)
  - Prometheus: `just istio-prometheus` (raw metrics)

### 🔧 Release Management

**Version Control & Releases**:
- **[Release Process](RELEASE-PROCESS.md)** - How to cut releases
- **[Release Automation](RELEASE-AUTOMATION.md)** - Automated release workflows

## Technology Stack

### Infrastructure
- **Cloud**: AWS (VPC, EKS, ElastiCache, ECR)
- **IaC**: Terraform 1.5+
- **Kubernetes**: Amazon EKS 1.28+
- **Service Mesh**: Istio 1.x

### Application
- **Languages**: Go, Python, Java, Node.js, C#
- **Communication**: gRPC (Protocol Buffers)
- **Caching**: Redis (ElastiCache)
- **Observability**: Prometheus, Grafana, Jaeger, Kiali

### CI/CD
- **Platform**: GitHub Actions
- **Security**: CodeQL, Trivy, Gitleaks, Semgrep, Checkov, tfsec
- **Change Management**: ServiceNow DevOps Change Velocity

## Project Structure

```
microservices-demo/
├── DEMO-OVERVIEW.md          # Start here - project overview
├── CLAUDE.md                  # Claude Code assistant instructions
├── justfile                   # 50+ automation commands
├── kustomize/                 # Multi-environment K8s configs
│   ├── base/                  # Shared manifests
│   ├── components/            # Reusable components
│   └── overlays/              # Environment overrides
│       ├── dev/
│       ├── qa/
│       └── prod/
├── src/                       # 12 microservice applications
├── terraform-aws/             # Infrastructure as Code
│   ├── environments/          # Per-environment configs
│   └── tests/                 # Terraform tests
├── .github/workflows/         # CI/CD pipelines
└── docs/                      # This documentation
    ├── ONBOARDING.md         # New developer setup
    ├── setup/                 # Setup guides
    ├── architecture/          # System design
    ├── development/           # Developer guides
    └── servicenow-integration/ # ServiceNow docs
```

## Common Commands

### Infrastructure
```bash
just tf-init                   # Initialize Terraform
just tf-plan                   # Preview changes
just tf-apply                  # Deploy infrastructure
```

### Kubernetes
```bash
just k8s-config                # Configure kubectl
kubectl apply -k overlays/dev  # Deploy to dev
kubectl get pods -n microservices-dev
```

### Observability
```bash
just istio-kiali               # Service mesh topology
just istio-grafana             # Metrics dashboards
just cluster-status            # Complete overview
```

### ServiceNow
```bash
gh workflow run deploy-with-servicenow-basic.yaml -f environment=dev
gh workflow run aws-infrastructure-discovery.yaml
```

**Full command reference**: Run `just` to see all commands

## Troubleshooting

### Quick Fixes

**Pods not starting**:
```bash
kubectl get pods -n microservices-dev
kubectl describe pod <pod-name> -n microservices-dev
kubectl logs <pod-name> -n microservices-dev
```

**Istio issues**:
```bash
just istio-analyze             # Check configuration
istioctl proxy-status          # Check proxy status
```

**Terraform errors**:
```bash
just tf-validate               # Validate syntax
just tf-test                   # Run tests
```

### Detailed Troubleshooting

- **[AWS Deployment Guide - Troubleshooting](README-AWS.md#troubleshooting)**
- **[Istio Troubleshooting](architecture/ISTIO-DEPLOYMENT.md#troubleshooting)**
- **[ServiceNow Integration Issues](servicenow-integration/SERVICENOW-INTEGRATION.md#common-issues)**

## Getting Help

1. **Check documentation** in this folder first
2. **Search** existing GitHub issues
3. **Ask in discussions** (GitHub Discussions)
4. **Open an issue** with:
   - Problem description
   - Steps to reproduce
   - Logs and error messages
   - Environment details

## Documentation Archive

Historical and detailed implementation documentation has been moved to `docs/_archive/`:
- Troubleshooting guides
- Implementation details
- Compliance analyses
- Antipattern guides

These are kept for reference but not needed for daily use.

## Contributing

See **[Development Guide](development/development-guide.md)** for contribution guidelines.

## License

Apache License 2.0 - Based on [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

---

**Quick Links**:
- **[Project Overview](../DEMO-OVERVIEW.md)** - Understand the demo
- **[Onboarding](ONBOARDING.md)** - Get started in 30 minutes
- **[ServiceNow Integration](servicenow-integration/SERVICENOW-INTEGRATION.md)** - Change management setup
- **[Cost Optimization](../COST-OPTIMIZATION.md)** - Scaling options
