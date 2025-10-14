# Developer Onboarding Guide

Welcome to the Online Boutique AWS project! This guide will help you set up your development environment and get started with the project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Required Tools](#required-tools)
- [Optional Tools](#optional-tools)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Verify Your Setup](#verify-your-setup)
- [First Deployment](#first-deployment)
- [Development Workflow](#development-workflow)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Prerequisites

Before you begin, ensure you have:

### System Requirements

- **Operating System**: macOS, Linux, or Windows with WSL2
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: At least 20GB free space
- **Network**: Stable internet connection for downloading tools and images

### Accounts Required

1. **AWS Account** with administrative access
   - Free tier is sufficient for dev environment
   - See [AWS Setup Guide](setup/AWS-SETUP.md) for details

2. **GitHub Account** (if using CI/CD)
   - Access to the repository
   - Permission to create branches and PRs

3. **Optional**: Docker Hub account for container registry

## Required Tools

The following tools must be installed on your system:

### 1. Git
Version control system.

**Installation:**
```bash
# macOS
brew install git

# Linux (Ubuntu/Debian)
sudo apt-get install git

# Linux (CentOS/RHEL)
sudo yum install git
```

**Verify:**
```bash
git --version
# Should show: git version 2.x.x or higher
```

### 2. Docker
Container runtime for building and running images.

**Installation:**
- macOS/Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

**Verify:**
```bash
docker --version
# Should show: Docker version 20.x.x or higher

docker ps
# Should show running containers (or empty list)
```

**Post-install (Linux only):**
```bash
# Add user to docker group to run without sudo
sudo usermod -aG docker $USER
newgrp docker
```

### 3. kubectl
Kubernetes command-line tool.

**Installation:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Verify:**
```bash
kubectl version --client
# Should show client version 1.27 or higher
```

### 4. Terraform
Infrastructure as Code tool.

**Installation:**
```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Verify:**
```bash
terraform version
# Should show Terraform v1.5.0 or higher
```

### 5. AWS CLI
AWS command-line interface.

**Installation:**
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Verify:**
```bash
aws --version
# Should show aws-cli/2.x.x or higher
```

### 6. Just
Task runner (command runner).

**Installation:**
```bash
# macOS
brew install just

# Linux
cargo install just
# Or download from: https://github.com/casey/just/releases
```

**Verify:**
```bash
just --version
# Should show just 1.x.x or higher
```

## Optional Tools

These tools enhance the development experience but are not required:

### istioctl
Istio command-line tool for debugging service mesh.

**Installation:**
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
sudo cp bin/istioctl /usr/local/bin/
```

**Verify:**
```bash
istioctl version
```

### k9s
Terminal UI for Kubernetes.

**Installation:**
```bash
# macOS
brew install k9s

# Linux
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_x86_64.tar.gz
tar -xzf k9s_Linux_x86_64.tar.gz
sudo mv k9s /usr/local/bin/
```

**Verify:**
```bash
k9s version
```

### Helm
Kubernetes package manager.

**Installation:**
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Verify:**
```bash
helm version
```

### grpcurl
Command-line tool for interacting with gRPC services.

**Installation:**
```bash
# macOS
brew install grpcurl

# Linux
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

**Verify:**
```bash
grpcurl --version
```

### Security Tools

**Trivy** (Container vulnerability scanner):
```bash
# macOS
brew install trivy

# Linux
wget https://github.com/aquasecurity/trivy/releases/download/v0.49.0/trivy_0.49.0_Linux-64bit.tar.gz
tar -xzf trivy_0.49.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/
```

**tfsec** (Terraform security scanner):
```bash
# macOS
brew install tfsec

# Linux
go install github.com/aquasecurity/tfsec/cmd/tfsec@latest
```

**gitleaks** (Secret scanner):
```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.1/gitleaks_8.18.1_linux_x64.tar.gz
tar -xzf gitleaks_8.18.1_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

## Quick Start

For developers who want to get started quickly:

### 1. Clone Repository

```bash
git clone <repository-url>
cd microservices-demo
```

### 2. Run Automated Onboarding

```bash
just onboard
```

This will:
- Check all required tools are installed
- Set up AWS credentials template
- Configure git hooks
- Verify your environment

### 3. Configure AWS Credentials

Edit `.envrc` with your AWS credentials:

```bash
# Copy the example file (done by just onboard)
cp .envrc.example .envrc

# Edit with your credentials
vim .envrc
```

Add your AWS credentials:
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="eu-west-2"
```

Load credentials:
```bash
source .envrc
```

### 4. Deploy to Dev Environment

```bash
# Initialize Terraform
just tf-init dev

# Review infrastructure plan
just tf-plan dev

# Deploy infrastructure (takes ~15 minutes)
just tf-apply dev

# Configure kubectl
just k8s-config dev

# Deploy application
just k8s-deploy

# Get application URL
just k8s-url
```

### 5. Access Dashboards

```bash
# Service mesh visualization
just istio-kiali

# Metrics and monitoring
just istio-grafana

# Distributed tracing
just istio-jaeger
```

## Detailed Setup

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd microservices-demo
```

### Step 2: Verify Tools Installation

```bash
just check-requirements
```

If any tool is missing, install it following the [Required Tools](#required-tools) section.

### Step 3: Configure AWS Credentials

#### Option 1: Using .envrc (Recommended for Development)

```bash
# Create .envrc from template
cp .envrc.example .envrc

# Edit with your credentials
nano .envrc
```

Add:
```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-2"
```

Load credentials:
```bash
source .envrc
```

**Note**: `.envrc` is gitignored and will not be committed.

#### Option 2: Using AWS CLI Configuration

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: eu-west-2
- Default output format: json

#### Option 3: Using AWS SSO (For Organization Accounts)

```bash
aws configure sso
```

Follow the prompts to configure SSO.

### Step 4: Verify AWS Access

```bash
aws sts get-caller-identity
```

Should output your account ID, user ARN, and user ID.

### Step 5: Initialize Git Hooks (Optional)

```bash
# Install pre-commit
pip install pre-commit

# Setup hooks
pre-commit install
```

This will run linters and formatters before each commit.

### Step 6: Review Documentation

Familiarize yourself with:
- [Repository Structure](architecture/REPOSITORY-STRUCTURE.md) - Understand the codebase
- [AWS Deployment Guide](README-AWS.md) - Complete deployment guide
- [Development Guide](development/development-guide.md) - Development workflows

## Verify Your Setup

Run the comprehensive verification:

```bash
just verify-setup
```

This checks:
- ✅ AWS credentials are loaded and valid
- ✅ kubectl is configured
- ✅ Terraform is initialized
- ✅ Docker daemon is running

Expected output:
```
🔍 Verifying development environment...
Checking AWS credentials...
✅ AWS credentials loaded
✅ AWS credentials valid
Checking kubectl...
✅ kubectl working
Checking terraform...
✅ terraform working
Checking docker...
✅ docker daemon running
```

## First Deployment

### Deploy Dev Environment

```bash
# 1. Initialize Terraform
just tf-init dev

# 2. Review what will be created
just tf-plan dev

# 3. Apply infrastructure (takes ~15 minutes)
just tf-apply dev
```

**What gets created:**
- VPC with 3 availability zones
- EKS cluster with 2-3 nodes
- ElastiCache Redis cluster
- 12 ECR repositories
- Istio service mesh
- IAM roles and policies

**Approximate cost**: $150/month for dev environment

### Configure kubectl

```bash
just k8s-config dev
```

Verify connection:
```bash
kubectl get nodes
# Should show 2-3 nodes in Ready state
```

### Deploy Application

```bash
# Deploy all microservices
just k8s-deploy

# Wait for pods to be ready (takes 2-3 minutes)
kubectl get pods -w

# All pods should show 2/2 (app + istio-proxy)
```

### Access Application

```bash
# Get the load balancer URL
just k8s-url

# Copy the URL and open in browser
```

You should see the Online Boutique store homepage!

## Development Workflow

### Making Changes

1. **Create Feature Branch**
```bash
git checkout -b feature/my-feature
```

2. **Make Code Changes**
- Edit service code in `src/<service-name>/`
- Update Kubernetes manifests if needed
- Update Protocol Buffers if changing service interfaces

3. **Build and Test Locally**
```bash
# Build specific service
just docker-build frontend

# Or build all services
just docker-build-all
```

4. **Push to ECR**
```bash
# Login to ECR
just ecr-login

# Push image
just ecr-push frontend dev
```

5. **Deploy to Dev**
```bash
# Restart deployment to pull new image
just k8s-restart frontend
```

6. **Test Changes**
```bash
# Check logs
just k8s-logs frontend

# Access application
just k8s-url
```

7. **Commit and Push**
```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

8. **Create Pull Request**
- Open PR on GitHub
- CI will run security scans and Terraform validation
- Review feedback and make changes
- Merge when approved

### Working with Multiple Environments

```bash
# Dev environment
just tf-apply dev
just k8s-config dev

# QA environment
just tf-apply qa
just k8s-config qa

# Production environment
just tf-apply prod
just k8s-config prod
```

Each environment has:
- Separate VPC (different CIDR)
- Separate EKS cluster
- Separate namespaces
- Different resource configurations

## Common Tasks

### View Logs

```bash
# View logs for a service
just k8s-logs frontend

# Follow logs in real-time
kubectl logs -l app=frontend -f --tail=100
```

### Debug Issues

```bash
# Check pod status
kubectl get pods -n default

# Describe problematic pod
kubectl describe pod <pod-name>

# Check service endpoints
kubectl get endpoints

# Analyze Istio configuration
just istio-analyze
```

### Access Dashboards

```bash
# Kiali (service mesh visualization)
just istio-kiali
# Open: http://localhost:20001

# Grafana (metrics)
just istio-grafana
# Open: http://localhost:3000

# Jaeger (distributed tracing)
just istio-jaeger
# Open: http://localhost:16686
```

### Scale Services

```bash
# Scale up
just k8s-scale frontend 5

# Scale down
just k8s-scale frontend 2
```

### Restart Deployment

```bash
just k8s-restart frontend
```

### Run Security Scans

```bash
# Scan all infrastructure
just security-scan-all

# Scan specific service container
trivy image frontend:local

# Check for secrets
just security-scan-secrets
```

### Update Infrastructure

```bash
# Edit Terraform variables
vim terraform-aws/environments/dev.tfvars

# Plan changes
just tf-plan dev

# Apply changes
just tf-apply dev
```

## Troubleshooting

### AWS Credentials Not Working

```bash
# Check if credentials are loaded
echo $AWS_ACCESS_KEY_ID

# If empty, load credentials
source .envrc

# Verify credentials
aws sts get-caller-identity
```

### kubectl Cannot Connect

```bash
# Reconfigure kubectl
just k8s-config dev

# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name> -c server

# Common issues:
# - Image pull errors: Check ECR permissions
# - Resource limits: Increase in deployment
# - Missing dependencies: Check ConfigMap/Secret
```

### Terraform Errors

```bash
# Validate configuration
just tf-validate

# Format code
just tf-fmt

# Re-initialize
rm -rf terraform-aws/.terraform
just tf-init dev
```

### Docker Build Fails

```bash
# Check Docker daemon
docker ps

# Clean up
docker system prune -f

# Rebuild
just docker-build <service>
```

### Port Forward Fails

```bash
# Kill existing port forward
lsof -ti:20001 | xargs kill -9

# Retry
just istio-kiali
```

## Next Steps

Now that you're onboarded, explore:

### Learn the Codebase
- [Repository Structure](architecture/REPOSITORY-STRUCTURE.md)
- [Service Communication Patterns](architecture/REPOSITORY-STRUCTURE.md#service-communication)
- [Adding New Services](development/adding-new-microservice.md)

### Understand the Infrastructure
- [Terraform Configuration](../terraform-aws/README.md)
- [EKS Setup](architecture/REPOSITORY-STRUCTURE.md#terraform-aws---aws-infrastructure)
- [Multi-Environment Strategy](../terraform-aws/environments/)

### Master Istio
- [Istio Deployment Guide](architecture/ISTIO-DEPLOYMENT.md)
- [Traffic Management Examples](architecture/ISTIO-DEPLOYMENT.md#traffic-management-examples)
- [Observability Tools](architecture/ISTIO-DEPLOYMENT.md#observability-dashboards)

### Contribute
- Read the [Development Guide](development/development-guide.md)
- Follow code style and best practices
- Run security scans before submitting PRs
- Update documentation when adding features

### Get Help
- Check [Documentation Index](README.md)
- Search existing GitHub issues
- Ask questions in team chat
- Open new issues for bugs or features

## Quick Reference

### Essential Commands

```bash
# Onboarding
just onboard                 # Complete onboarding
just verify-setup            # Check environment

# Infrastructure
just tf-plan dev             # Plan changes
just tf-apply dev            # Deploy infrastructure
just tf-destroy dev          # Destroy infrastructure

# Kubernetes
just k8s-config dev          # Configure kubectl
just k8s-deploy              # Deploy application
just k8s-status              # Check status
just k8s-logs <service>      # View logs

# Istio
just istio-kiali             # Open dashboard
just istio-analyze           # Check configuration

# Development
just docker-build <service>  # Build image
just ecr-push <service> dev  # Push to ECR
just k8s-restart <service>   # Restart deployment

# Validation
just validate                # Run all checks
just security-scan-all       # Security scans
```

### Important Files

```
microservices-demo/
├── justfile                 # Task definitions
├── .envrc                   # AWS credentials (local)
├── terraform-aws/
│   ├── environments/        # Environment configs
│   │   ├── dev.tfvars
│   │   ├── qa.tfvars
│   │   └── prod.tfvars
│   └── tests/               # Terraform tests
├── src/                     # Service source code
├── kubernetes-manifests/    # K8s deployments
├── istio-manifests/         # Istio configs
└── docs/                    # Documentation
```

## Welcome to the Team!

You're all set! If you have questions, don't hesitate to reach out to the team.

**Happy coding!** 🚀
