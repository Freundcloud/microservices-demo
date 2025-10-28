# Getting Started

> **Complete onboarding guide for new developers**
>
> Last Updated: 2025-10-28

This guide will take you from zero to deploying the complete microservices demo on AWS EKS.

---

## Prerequisites

### Required Tools

Install these tools on your local machine:

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# just (task runner)
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# GitHub CLI (optional but recommended)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### AWS Account

- AWS account with admin access
- Configured AWS credentials
- Sufficient quota for:
  - VPC (1)
  - EKS Cluster (1)
  - EC2 instances (4 t3.large)
  - ElastiCache (1 cache.t3.micro)
  - ECR repositories (12)

### GitHub Account

- GitHub account with repository access
- Ability to manage repository secrets
- GitHub Actions enabled

---

## Quick Start (Automated)

The fastest way to get started:

```bash
# Clone repository
git clone https://github.com/Freundcloud/microservices-demo.git
cd microservices-demo

# Run automated onboarding
just onboard
```

This will:
1. ✅ Verify all tools are installed
2. ✅ Configure AWS credentials
3. ✅ Initialize Terraform
4. ✅ Display next steps

---

## Step-by-Step Setup

### Step 1: Clone and Configure

```bash
# Clone repository
git clone https://github.com/Freundcloud/microservices-demo.git
cd microservices-demo

# Copy environment template
cp .envrc.example .envrc

# Edit with your AWS credentials
nano .envrc
```

Add your AWS credentials:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="eu-west-2"
```

Load credentials:
```bash
source .envrc
```

### Step 2: Deploy Infrastructure

```bash
# Initialize Terraform
just tf-init

# Plan infrastructure changes
just tf-plan

# Deploy infrastructure (takes ~15 minutes)
just tf-apply
```

This creates:
- ✅ VPC with 3 availability zones
- ✅ EKS cluster with 4 nodes
- ✅ ElastiCache Redis
- ✅ 12 ECR repositories
- ✅ Istio service mesh
- ✅ All IAM roles and policies

### Step 3: Configure kubectl

```bash
# Configure kubectl to access EKS cluster
just k8s-config

# Verify cluster access
kubectl get nodes
```

Expected output:
```
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-1-123.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.x
ip-10-0-2-234.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.x
ip-10-0-3-345.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.x
ip-10-0-4-456.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.x
```

### Step 4: Build and Push Container Images

```bash
# Login to ECR
just ecr-login

# Build all 12 microservices
just docker-build-all

# Push to ECR (tags with 'dev' by default)
for service in emailservice productcatalogservice recommendationservice shippingservice checkoutservice paymentservice currencyservice cartservice frontend adservice loadgenerator shoppingassistantservice; do
  just ecr-push $service dev
done
```

### Step 5: Deploy Application

```bash
# Deploy using traditional manifests
just k8s-deploy

# OR deploy using Kustomize (multi-environment)
kubectl apply -k kustomize/overlays/dev
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n microservices-dev

# Get application URL
just k8s-url

# Open in browser
just k8s-url | xargs open  # macOS
just k8s-url | xargs xdg-open  # Linux
```

---

## Understanding the Architecture

### 12 Microservices

| Service | Language | Purpose |
|---------|----------|---------|
| **frontend** | Go | Web UI (HTTP) |
| **cartservice** | C# | Shopping cart with Redis |
| **productcatalogservice** | Go | Product inventory |
| **currencyservice** | Node.js | Currency conversion |
| **paymentservice** | Node.js | Payment processing |
| **shippingservice** | Go | Shipping cost calculation |
| **emailservice** | Python | Order confirmation emails |
| **checkoutservice** | Go | Order orchestration |
| **recommendationservice** | Python | Product recommendations |
| **adservice** | Java | Contextual ads |
| **loadgenerator** | Python | Traffic generation |
| **shoppingassistantservice** | Java | AI assistant |

### Communication

- **Inter-service**: gRPC with Protocol Buffers
- **Service Discovery**: Kubernetes DNS
- **Security**: Istio mTLS (strict)
- **External Access**: Istio Ingress Gateway (NLB)

### Infrastructure

```
┌─────────────────────────────────────────────┐
│              AWS Cloud                       │
│  ┌───────────────────────────────────────┐  │
│  │         VPC (eu-west-2)               │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │      EKS Cluster                 │  │  │
│  │  │  ┌───────────────────────────┐   │  │  │
│  │  │  │    Istio Service Mesh     │   │  │  │
│  │  │  │  ┌─────────────────────┐  │   │  │  │
│  │  │  │  │  12 Microservices   │  │   │  │  │
│  │  │  │  └─────────────────────┘  │   │  │  │
│  │  │  └───────────────────────────┘   │  │  │
│  │  └─────────────────────────────────┘  │  │
│  │                                        │  │
│  │  ┌─────────────┐  ┌──────────────┐   │  │
│  │  │ ElastiCache │  │ ECR (12 repos)│  │  │
│  │  └─────────────┘  └──────────────┘   │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## Common Commands

### Daily Development

```bash
# View cluster status
just cluster-status

# Check pod health
just health-check

# View logs
just k8s-logs frontend

# Restart service
just k8s-restart frontend

# Scale service
just k8s-scale frontend 5
```

### Istio Service Mesh

```bash
# Open Kiali dashboard (service mesh topology)
just istio-kiali

# Open Grafana (metrics)
just istio-grafana

# Check Istio health
just istio-health
```

### CI/CD

```bash
# Validate all workflows
just validate

# Run security scans
just security-scan-all

# Run Terraform tests
just tf-test
```

---

## Multi-Environment Deployment

The project supports three environments:

### Development (dev)

```bash
# Deploy to dev namespace
kubectl apply -k kustomize/overlays/dev

# Check status
kubectl get pods -n microservices-dev
```

**Configuration:**
- 1 replica per service
- Minimal resources
- No load generator
- Fast iteration

### QA (qa)

```bash
# Deploy to qa namespace
kubectl apply -k kustomize/overlays/qa

# Check status
kubectl get pods -n microservices-qa
```

**Configuration:**
- 2 replicas per service
- Moderate resources
- Load generator enabled
- Testing environment

### Production (prod)

```bash
# Deploy to prod namespace
kubectl apply -k kustomize/overlays/prod

# Check status
kubectl get pods -n microservices-prod
```

**Configuration:**
- 3 replicas per service
- High resources
- No load generator
- HA configuration

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n microservices-dev

# Describe pod for details
kubectl describe pod <pod-name> -n microservices-dev

# Check logs
kubectl logs <pod-name> -c server -n microservices-dev
kubectl logs <pod-name> -c istio-proxy -n microservices-dev
```

**Common Causes:**
- Image pull errors → Check ECR login and image exists
- Resource limits → Increase in deployment manifest
- Missing config → Check Redis created by Terraform

### Istio Issues

```bash
# Validate Istio configuration
just istio-analyze

# Check proxy status
istioctl proxy-status

# View routing rules
istioctl proxy-config route <pod> -n microservices-dev
```

### Terraform Errors

```bash
# Validate syntax
just tf-validate

# Check state
terraform -chdir=terraform-aws state list

# Inspect resource
terraform -chdir=terraform-aws state show <resource>
```

### AWS Credentials

```bash
# Verify credentials
aws sts get-caller-identity

# Check if loaded
echo $AWS_ACCESS_KEY_ID

# Reload credentials
source .envrc
```

---

## Next Steps

After completing initial setup:

1. 📚 **Learn the Workflows**: Read [Workflow Overview](../workflows/OVERVIEW.md)
2. 🔐 **Setup Security Scanning**: Follow [Security Setup](../setup/SECURITY-SCANNING.md)
3. 🔄 **Configure ServiceNow**: See [ServiceNow Overview](../servicenow/OVERVIEW.md)
4. 🛠️ **Start Developing**: Check [Development Guide](DEVELOPMENT.md)
5. 🎯 **Run a Demo**: Use [Demo Guide](DEMO-GUIDE.md)

---

## Getting Help

- **Documentation Issues**: Check [Troubleshooting Guide](../reference/TROUBLESHOOTING.md)
- **Workflow Questions**: Review [Workflow Documentation](../workflows/OVERVIEW.md)
- **Architecture Questions**: See [System Architecture](../architecture/SYSTEM-ARCHITECTURE.md)

---

## Quick Reference Card

| Task | Command |
|------|---------|
| First time setup | `just onboard` |
| Deploy infrastructure | `just tf-apply` |
| Configure kubectl | `just k8s-config` |
| Deploy application | `just k8s-deploy` |
| Deploy with Kustomize | `kubectl apply -k kustomize/overlays/dev` |
| View application | `just k8s-url` |
| Check cluster status | `just cluster-status` |
| View service mesh | `just istio-kiali` |
| Build container | `just docker-build frontend` |
| View logs | `just k8s-logs frontend` |
| Restart service | `just k8s-restart frontend` |
| Run validations | `just validate` |
| Security scans | `just security-scan-all` |

---

*Ready to deploy? Start with `just onboard` and follow the prompts!*
