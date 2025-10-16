# Documentation Index

Welcome to the Online Boutique AWS Deployment documentation. This guide will help you deploy, configure, and manage the microservices demo application on AWS EKS.

## Quick Start

**New to this project?** Start here:
1. [AWS Deployment Guide](README-AWS.md) - Complete guide for deploying to AWS
2. [AWS Setup](setup/AWS-SETUP.md) - Get your AWS credentials configured
3. [GitHub Actions Setup](setup/GITHUB-ACTIONS-SETUP.md) - Configure CI/CD automation

## Documentation Structure

### 📋 Setup Guides

Essential guides for getting started:

- **[AWS Setup](setup/AWS-SETUP.md)**
  - AWS account creation
  - IAM user and permissions setup
  - AWS CLI configuration
  - Access key management

- **[GitHub Actions Setup](setup/GITHUB-ACTIONS-SETUP.md)**
  - GitHub repository configuration
  - GitHub Secrets setup
  - Workflow triggers and usage
  - Manual workflow execution

- **[Security Scanning Setup](setup/SECURITY-SCANNING.md)**
  - Comprehensive security tooling
  - SAST, container scanning, secret detection
  - GitHub Security integration
  - Viewing and handling security alerts

- **[ServiceNow Integration Summary](SERVICENOW-INTEGRATION-SUMMARY.md)**
  - Quick overview of ServiceNow integration
  - Key changes required
  - Deployment workflow changes
  - Quick start guide
  - 4-week implementation timeline

- **[ServiceNow Integration Complete Plan](SERVICENOW-INTEGRATION-PLAN.md)**
  - Detailed project plan
  - Change management automation
  - Security scan integration (5 tools)
  - AWS EKS CMDB discovery
  - Complete workflow configurations
  - Troubleshooting guide

### 🏗️ Architecture Documentation

Understanding the system design:

- **[Repository Structure](architecture/REPOSITORY-STRUCTURE.md)**
  - Complete directory guide
  - Source code organization
  - Protocol Buffers (protos/)
  - Kubernetes manifests
  - Release artifacts
  - Development workflow

- **[Istio Service Mesh](architecture/ISTIO-DEPLOYMENT.md)**
  - Istio installation and configuration
  - mTLS security
  - Traffic management
  - Observability stack (Kiali, Prometheus, Jaeger, Grafana)
  - Troubleshooting Istio issues

- **[Product Purpose](architecture/purpose.md)**
  - Project goals and objectives
  - Target audience
  - Use cases

- **[Product Requirements](architecture/product-requirements.md)**
  - Functional requirements
  - Non-functional requirements
  - Service specifications

### 💻 Development Guides

For developers working on the codebase:

- **[Development Guide](development/development-guide.md)**
  - Local development setup
  - Building and testing services
  - Debugging techniques
  - Development best practices

- **[Adding New Microservices](development/adding-new-microservice.md)**
  - Step-by-step guide for new services
  - Kubernetes manifest templates
  - Protocol Buffer integration
  - CI/CD integration

### 🚀 Deployment

- **[Complete AWS Deployment Guide](README-AWS.md)**
  - Prerequisites and requirements
  - Step-by-step deployment
  - Multi-environment setup (dev, qa, prod)
  - Cost estimation
  - Troubleshooting

### 🔐 Security

- **[Security Scanning](setup/SECURITY-SCANNING.md)**
  - CodeQL (SAST)
  - Trivy (Container scanning)
  - Gitleaks (Secret detection)
  - Semgrep, Checkov, tfsec
  - OWASP Dependency Check
  - GitHub Security integration

### 🏢 ServiceNow Integration

Complete ServiceNow CMDB integration with automated discovery and security scanning:

- **[Implementation Status](SERVICENOW-IMPLEMENTATION-STATUS.md)** ⭐ **START HERE**
  - Overall implementation progress
  - Component status tracking
  - Testing checklist
  - Next steps guide

- **[Quick Start Guide](SERVICENOW-QUICK-START.md)**
  - Prerequisites and setup
  - Table creation
  - Workflow configuration
  - First deployment

- **[Setup Checklist](SERVICENOW-SETUP-CHECKLIST.md)**
  - Step-by-step setup validation
  - Configuration verification
  - Access testing
  - Troubleshooting common issues

**EKS Discovery & CMDB Population:**
- **[Node Discovery](SERVICENOW-NODE-DISCOVERY.md)**
  - EKS cluster discovery
  - Node metadata collection
  - Relationship mapping
- **[Viewing Nodes in ServiceNow](SERVICENOW-VIEWING-NODES.md)**
  - ServiceNow UI navigation
  - Filtering and searching
  - Custom views

**Security Scanning Integration:**
- **[Security Scanning Design](SERVICENOW-SECURITY-SCANNING.md)**
  - Architecture overview
  - SARIF aggregation from 8 security tools
  - Custom table schema
  - Upload automation
- **[Security Verification Guide](SERVICENOW-SECURITY-VERIFICATION.md)**
  - Testing connectivity
  - Verifying uploads
  - Troubleshooting issues

**Change Management & Approvals:**
- **[Approval Workflow Guide](SERVICENOW-APPROVALS.md)** ⭐ **COMPREHENSIVE GUIDE**
  - Multi-level approval configuration
  - Dev/QA/Prod approval policies
  - Approval groups setup
  - Email notifications
  - Best practices and metrics
- **[Approval Quick Start](SERVICENOW-APPROVALS-QUICKSTART.md)**
  - 15-minute setup guide
  - Step-by-step testing
  - Verification checklist
  - 8 security tools integrated
  - SARIF aggregation
  - Finding deduplication
  - Table schema design
- **[Security Verification Guide](SERVICENOW-SECURITY-VERIFICATION.md)**
  - Step-by-step testing
  - Table creation instructions
  - Results validation
  - Troubleshooting

**Additional Documentation:**
- **[Workflow Testing](SERVICENOW-WORKFLOW-TESTING.md)**
  - Workflow execution testing
  - API validation
  - Data verification
- **[Migration Summary](SERVICENOW-MIGRATION-SUMMARY.md)**
  - Implementation history
  - Key decisions
  - Lessons learned
- **[Zurich Compatibility](SERVICENOW-ZURICH-COMPATIBILITY.md)**
  - Version-specific notes
  - Compatibility issues
  - Workarounds

### 🔧 Workflow Troubleshooting

- **[OWASP Dependency-Check Troubleshooting](workflows/TROUBLESHOOTING-DEPENDENCY-CHECK.md)**
  - Fixing Maven Central connectivity issues
  - Handling missing node_modules errors
  - Configuring OSS Index authentication
  - Alternative dependency scanning approaches
  - Language-specific scanners (npm audit, govulncheck, pip-audit)
  - Performance optimization and best practices

- **[ServiceNow CMDB Discovery Troubleshooting](workflows/TROUBLESHOOTING-SERVICENOW-CMDB.md)**
  - Fixing shell heredoc syntax errors
  - Resolving ServiceNow API authentication issues
  - Handling JSON payload construction safely
  - Debugging rate limiting and permission errors
  - Best practices for CMDB updates
  - Data validation and verification

### 🌐 Service Mesh

- **[Istio Deployment](architecture/ISTIO-DEPLOYMENT.md)**
  - Istio architecture overview
  - Installation with Terraform
  - Traffic management examples
  - Observability dashboards
  - Security policies
  - Cost optimization

### 📊 Operations

Operational guides coming soon:

- Monitoring and alerting
- Incident response
- Backup and recovery
- Scaling strategies
- Cost optimization
- Performance tuning

## Key Features

### Infrastructure as Code (Terraform)

All infrastructure is defined in [terraform-aws/](../terraform-aws/):

- **VPC**: Multi-AZ networking with public/private subnets
- **EKS**: Managed Kubernetes with autoscaling
- **ElastiCache**: Redis for session storage
- **ECR**: Container registry with vulnerability scanning
- **Istio**: Service mesh with mTLS
- **IAM**: IRSA for secure AWS access

**Terraform Documentation:**
- [Terraform README](../terraform-aws/README.md)
- [Terraform Tests](../terraform-aws/tests/)
- Environment configs: [dev](../terraform-aws/environments/dev.tfvars), [qa](../terraform-aws/environments/qa.tfvars), [prod](../terraform-aws/environments/prod.tfvars)

### CI/CD Pipeline (GitHub Actions)

All workflows are in [.github/workflows/](../.github/workflows/):

- **[terraform-validate.yaml](../.github/workflows/terraform-validate.yaml)**: Multi-environment Terraform validation and testing
- **[terraform-plan.yaml](../.github/workflows/terraform-plan.yaml)**: Infrastructure change preview on PRs
- **[terraform-apply.yaml](../.github/workflows/terraform-apply.yaml)**: Automated infrastructure deployment
- **[build-and-push-images.yaml](../.github/workflows/build-and-push-images.yaml)**: Container builds with security scanning
- **[security-scan.yaml](../.github/workflows/security-scan.yaml)**: Comprehensive security scanning
- **[deploy-application.yaml](../.github/workflows/deploy-application.yaml)**: Application deployment to EKS

### Microservices Architecture

12 microservices in different languages:

| Service | Language | Purpose |
|---------|----------|---------|
| [frontend](../src/frontend) | Go | Web UI |
| [cartservice](../src/cartservice) | C# | Shopping cart |
| [productcatalogservice](../src/productcatalogservice) | Go | Product inventory |
| [currencyservice](../src/currencyservice) | Node.js | Currency conversion |
| [paymentservice](../src/paymentservice) | Node.js | Payment processing |
| [shippingservice](../src/shippingservice) | Go | Shipping calculations |
| [emailservice](../src/emailservice) | Python | Email notifications |
| [checkoutservice](../src/checkoutservice) | Go | Order orchestration |
| [recommendationservice](../src/recommendationservice) | Python | Product recommendations |
| [adservice](../src/adservice) | Java | Advertisement serving |
| [loadgenerator](../src/loadgenerator) | Python | Load testing |
| [shoppingassistantservice](../src/shoppingassistantservice) | Java | AI shopping assistant |

## Multi-Environment Support

The project supports three environments with different configurations:

### Development Environment
- **Cluster**: microservices-dev
- **Nodes**: 2-3 × t3.medium
- **VPC**: 10.0.0.0/16
- **Istio**: Enabled (no addons)
- **Redis**: cache.t3.micro
- **Cost**: ~$150/month

### QA Environment
- **Cluster**: microservices-qa
- **Nodes**: 3-5 × t3.medium
- **VPC**: 10.1.0.0/16
- **Istio**: Enabled (with observability)
- **Redis**: cache.t3.small
- **Cost**: ~$200/month

### Production Environment
- **Cluster**: microservices-prod
- **Nodes**: 5-10 × t3.large/xlarge
- **VPC**: 10.2.0.0/16
- **Istio**: Enabled (full stack)
- **Redis**: cache.t3.medium (multi-node)
- **Cost**: ~$500/month

**Deployment:**
```bash
# Deploy specific environment
cd terraform-aws
terraform apply -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/qa.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

## Common Tasks

### Deploy to AWS

```bash
# 1. Configure AWS credentials
source .envrc

# 2. Deploy infrastructure (choose environment)
cd terraform-aws
terraform init
terraform apply -var-file="environments/prod.tfvars"

# 3. Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name microservices-prod

# 4. Deploy application
kubectl apply -f release/kubernetes-manifests.yaml
kubectl apply -f istio-manifests/
```

### Access Observability Dashboards

```bash
# Kiali (Service mesh visualization)
kubectl port-forward svc/kiali-server -n istio-system 20001:20001
# Open: http://localhost:20001

# Grafana (Metrics dashboards)
kubectl port-forward svc/grafana -n istio-system 3000:80
# Open: http://localhost:3000

# Jaeger (Distributed tracing)
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
# Open: http://localhost:16686
```

### Run Security Scans Locally

```bash
# Container scanning with Trivy
trivy image <image-name>:latest

# Infrastructure scanning
cd terraform-aws
tfsec .
checkov -d .

# Secret detection
gitleaks detect --source . -v
```

### Add a New Microservice

See [Adding New Microservices](development/adding-new-microservice.md) for complete guide.

Basic steps:
1. Create service code in `src/<service-name>/`
2. Add Dockerfile
3. Create Kubernetes manifests in `kubernetes-manifests/<service-name>.yaml`
4. Add Protocol Buffers in `protos/demo.proto` (if needed)
5. Create ECR repository in `terraform-aws/ecr.tf`
6. Update release manifest

## Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

**Istio issues:**
```bash
istioctl analyze -n default
istioctl proxy-status
kubectl get gateway,virtualservice -n default
```

**Terraform errors:**
```bash
terraform -chdir=terraform-aws validate
terraform -chdir=terraform-aws fmt -check
terraform -chdir=terraform-aws test
```

### Getting Help

1. Check the [troubleshooting section](README-AWS.md#troubleshooting) in the AWS deployment guide
2. Review [Repository Structure](architecture/REPOSITORY-STRUCTURE.md#troubleshooting)
3. Check [Istio troubleshooting](architecture/ISTIO-DEPLOYMENT.md#troubleshooting)
4. Search existing GitHub issues
5. Open a new issue with:
   - Description of the problem
   - Steps to reproduce
   - Logs and error messages
   - Environment details

## Contributing

Contributions are welcome! When contributing:

1. Read the [Development Guide](development/development-guide.md)
2. Follow existing code patterns
3. Run security scans before submitting PR
4. Update documentation as needed
5. Add tests for new features

## Additional Resources

### Official Documentation
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### AWS Resources
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [VPC CNI Plugin](https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html)

### Service Mesh Resources
- [Istio on AWS](https://aws.github.io/aws-eks-best-practices/networking/service-mesh/istio/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)

## License

This project is licensed under the Apache License 2.0 - see individual files for details.

Original Google Cloud version: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

---

**Questions or feedback?** Open an issue on GitHub!
