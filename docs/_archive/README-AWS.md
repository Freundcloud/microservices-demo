# Online Boutique - AWS Deployment

<p align="center">
<img src="/src/frontend/static/icons/Hipster_HeroLogoMaroon.svg" width="300" alt="Online Boutique" />
</p>

**Online Boutique** is a cloud-native microservices demo application deployed on AWS.  The application is a web-based e-commerce app where users can browse items, add them to the cart, and purchase them.

This AWS-focused version demonstrates modern cloud-native practices including:
- **Amazon EKS** (Elastic Kubernetes Service) - Managed Kubernetes
- **AWS ECR** (Elastic Container Registry) - Container image storage
- **ElastiCache for Redis** - Session and cart storage
- **Istio Service Mesh** - Service-to-service communication with mTLS
- **GitHub Actions CI/CD** - Automated build, security scan, and deployment
- **Terraform IaC** - Infrastructure as Code for complete reproducibility

Perfect for demonstrating **GitHub + AWS + ServiceNow** collaboration workflows!

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
- [Accessing the Application](#accessing-the-application)
- [Monitoring and Observability](#monitoring-and-observability)
- [Security](#security)
- [Cost Estimation](#cost-estimation)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Architecture

**Online Boutique** consists of 12 microservices written in different languages that communicate over gRPC:

[![Architecture of microservices](/docs/img/architecture-diagram.png)](/docs/img/architecture-diagram.png)

### Microservices

| Service | Language | Description |
|---------|----------|-------------|
| [frontend](/src/frontend) | Go | Web UI - HTTP server serving the website |
| [cartservice](/src/cartservice) | C# | Shopping cart management with Redis |
| [productcatalogservice](/src/productcatalogservice) | Go | Product inventory from JSON |
| [currencyservice](/src/currencyservice) | Node.js | Currency conversion (highest QPS service) |
| [paymentservice](/src/paymentservice) | Node.js | Payment processing (mock) |
| [shippingservice](/src/shippingservice) | Go | Shipping cost calculation |
| [emailservice](/src/emailservice) | Python | Order confirmation emails (mock) |
| [checkoutservice](/src/checkoutservice) | Go | Order orchestration |
| [recommendationservice](/src/recommendationservice) | Python | Product recommendations |
| [adservice](/src/adservice) | Java | Contextual advertisements |
| [loadgenerator](/src/loadgenerator) | Python/Locust | Realistic load generation |
| [shoppingassistantservice](/src/shoppingassistantservice) | Java | AI shopping assistant |

### AWS Infrastructure

- **VPC**: 3 availability zones with public/private subnets
- **EKS**: Managed Kubernetes cluster with autoscaling node groups
- **ElastiCache**: Redis cluster for cart service
- **ECR**: 12 container repositories with vulnerability scanning
- **NLB**: Network Load Balancer for Istio Ingress Gateway
- **IAM**: IRSA (IAM Roles for Service Accounts) for secure AWS access
- **CloudWatch**: Centralized logging and monitoring

### Service Mesh (Istio)

- **mTLS**: Automatic mutual TLS between all services
- **Traffic Management**: Intelligent routing, canary deployments
- **Observability**: Kiali, Prometheus, Jaeger, Grafana
- **Security**: Authorization policies, network isolation

### CI/CD Pipeline

- **Build**: Multi-architecture Docker images (amd64/arm64)
- **Security Scanning**: Trivy, CodeQL, Gitleaks, Semgrep, Checkov
- **Infrastructure**: Terraform with GitHub Actions
- **Deployment**: Automated EKS deployment on merge to main

## Features

### Production-Ready

- ✅ **Multi-language microservices** (Go, Python, Java, Node.js, C#)
- ✅ **gRPC communication** with Protocol Buffers
- ✅ **Service mesh** with Istio for security and observability
- ✅ **Autoscaling** with Cluster Autoscaler and HPA
- ✅ **Health checks** and readiness probes
- ✅ **Resource limits** and requests configured
- ✅ **Structured logging** to CloudWatch

### Security

- ✅ **Container scanning** with Trivy on every build
- ✅ **SAST** with CodeQL (5 languages) and Semgrep
- ✅ **Secret detection** with Gitleaks
- ✅ **IaC security** with Checkov and tfsec
- ✅ **mTLS** enforced between all services
- ✅ **IRSA** for secure AWS credential management
- ✅ **Network isolation** with Security Groups
- ✅ **SBOM generation** for compliance

### Observability

- ✅ **Distributed tracing** with Jaeger
- ✅ **Metrics** with Prometheus
- ✅ **Visualization** with Grafana dashboards
- ✅ **Service topology** with Kiali
- ✅ **CloudWatch integration** for logs
- ✅ **Request/response logging** via Istio

### Developer Experience

- ✅ **One-command deployment** via GitHub Actions
- ✅ **Infrastructure as Code** with Terraform
- ✅ **Smart build detection** (only rebuild changed services)
- ✅ **Pull request previews** (terraform plan comments)
- ✅ **Comprehensive documentation**
- ✅ **Local development support**

## Quick Start

### Option 1: Automated CI/CD (Recommended)

1. **Fork this repository** to your GitHub account

2. **Configure GitHub Secrets** ([detailed guide](GITHUB-ACTIONS-SETUP.md)):
   ```
   AWS_ACCESS_KEY_ID
   AWS_SECRET_ACCESS_KEY
   AWS_REGION
   ```

3. **Merge to main branch** - CI/CD handles everything:
   - Terraform deploys infrastructure
   - Docker images built and pushed to ECR
   - Application deployed to EKS
   - Istio service mesh configured

4. **Get application URL**:
   ```bash
   # From Terraform outputs
   terraform -chdir=terraform-aws output istio_ingress_gateway_url
   ```

### Option 2: Manual Deployment

```bash
# 1. Set up AWS credentials
cp .envrc.example .envrc
# Edit .envrc with your AWS credentials
source .envrc

# 2. Deploy infrastructure
cd terraform-aws
terraform init
terraform apply

# 3. Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name microservices-demo

# 4. Build and push images (see GITHUB-ACTIONS-SETUP.md for ECR login)
# Or trigger GitHub Actions workflow manually

# 5. Deploy application
kubectl apply -f release/kubernetes-manifests.yaml
kubectl apply -f istio-manifests/

# 6. Get application URL
kubectl get svc istio-ingressgateway -n istio-system
```

## Prerequisites

### Required Tools

- **AWS Account** with administrative access ([setup guide](AWS-SETUP.md))
- **Terraform** >= 1.5.0 ([install](https://developer.hashicorp.com/terraform/install))
- **kubectl** >= 1.27 ([install](https://kubernetes.io/docs/tasks/tools/))
- **AWS CLI** v2 ([install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Git** for repository operations

### Optional Tools

- **istioctl** for Istio debugging ([install](https://istio.io/latest/docs/setup/getting-started/#download))
- **Docker** for local image builds
- **Helm** for alternative deployments

### AWS Permissions Required

Your IAM user/role needs permissions for:
- VPC, Subnets, NAT Gateway, Internet Gateway
- EKS cluster and node group management
- EC2 instances and Security Groups
- ElastiCache clusters
- ECR repositories
- IAM roles and policies
- CloudWatch Logs
- Elastic Load Balancing

See [AWS-SETUP.md](AWS-SETUP.md) for detailed permission setup.

## Deployment Guide

### Step 1: Clone Repository

```bash
git clone <your-fork-url>
cd microservices-demo
```

### Step 2: Configure AWS Credentials

**For Local Development:**
```bash
cp .envrc.example .envrc
# Edit .envrc with your credentials
source .envrc
```

**For GitHub Actions:**
Follow [GITHUB-ACTIONS-SETUP.md](GITHUB-ACTIONS-SETUP.md) to configure secrets.

### Step 3: Configure Terraform Variables

```bash
cd terraform-aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
cluster_name        = "microservices-demo"
aws_region          = "eu-west-2"
environment         = "production"
enable_istio        = true
enable_redis        = true
instance_types      = ["t3.medium"]
desired_size        = 3
min_size            = 2
max_size            = 5
```

### Step 4: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure (takes ~15 minutes)
terraform apply

# Save outputs
terraform output > ../terraform-outputs.txt
```

### Step 5: Configure kubectl

```bash
aws eks update-kubeconfig \
  --region $(terraform output -raw region) \
  --name $(terraform output -raw cluster_name)

# Verify connection
kubectl get nodes
```

### Step 6: Build and Push Container Images

**Option A: GitHub Actions (Recommended)**
- Push code to GitHub
- Workflow [build-and-push-images.yaml](.github/workflows/build-and-push-images.yaml) runs automatically

**Option B: Manual Build**
```bash
# Login to ECR
aws ecr get-login-password --region eu-west-2 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw ecr_registry_url)

# Build and push each service
cd ../src/frontend
docker build -t frontend:latest .
docker tag frontend:latest $(terraform output -raw ecr_registry_url)/frontend:latest
docker push $(terraform output -raw ecr_registry_url)/frontend:latest
# Repeat for all 12 services...
```

### Step 7: Deploy Application

```bash
cd ../

# Update image references in manifests (if needed)
# Or use Helm with values

# Deploy microservices
kubectl apply -f release/kubernetes-manifests.yaml

# Deploy Istio routing
kubectl apply -f istio-manifests/

# Wait for pods to be ready
kubectl get pods -n default -w
```

### Step 8: Verify Deployment

```bash
# Check all pods are running (2/2 containers due to Istio sidecar)
kubectl get pods -n default

# Check Istio components
kubectl get pods -n istio-system

# Get application URL
kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Accessing the Application

### Web UI

Get the Istio Ingress Gateway URL:

```bash
# Method 1: kubectl
export INGRESS_URL=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://$INGRESS_URL"

# Method 2: Terraform output
terraform -chdir=terraform-aws output istio_ingress_gateway_url
```

Open the URL in your browser to access the Online Boutique store.

### Load Generator

The load generator continuously sends traffic to simulate real users:

```bash
# Check load generator logs
kubectl logs -l app=loadgenerator -f

# Adjust load intensity
kubectl scale deployment loadgenerator --replicas=3
```

## Monitoring and Observability

### Kiali - Service Mesh Dashboard

Visualize service topology and traffic:

```bash
kubectl port-forward svc/kiali-server -n istio-system 20001:20001
```

Open: http://localhost:20001

**Features:**
- Real-time service graph
- Traffic rates and protocols
- Health indicators
- Configuration validation

### Grafana - Metrics Dashboard

View performance metrics:

```bash
kubectl port-forward svc/grafana -n istio-system 3000:80
```

Open: http://localhost:3000

**Dashboards:**
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard
- Istio Performance Dashboard

### Jaeger - Distributed Tracing

Trace requests across services:

```bash
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
```

Open: http://localhost:16686

**Use Cases:**
- Debug slow requests
- Identify bottlenecks
- Analyze error paths
- Understand service dependencies

### Prometheus - Raw Metrics

Query metrics directly:

```bash
kubectl port-forward svc/prometheus-server -n istio-system 9090:80
```

Open: http://localhost:9090

### CloudWatch Logs

View centralized logs:

```bash
# View logs for a specific service
aws logs tail /aws/eks/microservices-demo/cluster --follow

# Or via kubectl
kubectl logs -l app=frontend -f --tail=100
```

## Security

### Automated Security Scanning

Every code push triggers comprehensive security scanning:

- **CodeQL**: SAST for Python, JavaScript, Go, Java, C#
- **Trivy**: Container vulnerability scanning
- **Gitleaks**: Secret detection in commits
- **Semgrep**: Pattern-based code analysis
- **Checkov**: Terraform security scanning
- **tfsec**: Additional Terraform checks
- **Polaris**: Kubernetes best practices
- **OWASP Dependency Check**: Known vulnerable dependencies

Results appear in:
- GitHub Security tab
- Pull request comments
- GitHub Actions workflow logs

See [SECURITY-SCANNING.md](SECURITY-SCANNING.md) for details.

### Runtime Security

- **mTLS**: All service-to-service communication encrypted
- **IRSA**: No long-lived AWS credentials in pods
- **Network Policies**: Istio enforces service-to-service rules
- **Security Groups**: EC2 instances isolated
- **Private Subnets**: EKS nodes not directly internet-accessible
- **VPC Endpoints**: Private AWS service access

### Compliance

- **SBOM**: Software Bill of Materials generated for all images
- **CVE Tracking**: Automatic vulnerability monitoring
- **Audit Logs**: CloudWatch captures all API calls
- **Image Signing**: Optional with Cosign/Notation

## Cost Estimation

### Monthly AWS Costs (eu-west-2)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 Nodes | 3 × t3.medium | $90 |
| NAT Gateway | 1 gateway + data transfer | $45 |
| Network Load Balancer | Istio ingress | $18 |
| ElastiCache | cache.t3.micro | $15 |
| ECR Storage | 12 repositories (~10GB) | $1 |
| CloudWatch Logs | ~10GB/month | $5 |
| **Total** | | **~$247/month** |

### Cost Optimization Tips

1. **Use Spot Instances** for non-production:
   ```hcl
   capacity_type = "SPOT"
   ```

2. **Disable Istio Add-ons** for testing:
   ```hcl
   enable_istio_addons = false  # Saves ~$30/month
   ```

3. **Single NAT Gateway**:
   ```hcl
   single_nat_gateway = true
   ```

4. **Smaller Redis Instance**:
   ```hcl
   redis_node_type = "cache.t3.micro"
   ```

5. **Enable Cluster Autoscaler** (included):
   - Scales down nodes during low usage
   - Can save 30-50% during off-hours

## Documentation

### Getting Started
- [AWS Setup Guide](AWS-SETUP.md) - AWS credentials and permissions
- [GitHub Actions Setup](GITHUB-ACTIONS-SETUP.md) - CI/CD configuration
- [Terraform README](terraform-aws/README.md) - Infrastructure details

### Architecture and Operations
- [Repository Structure](REPOSITORY-STRUCTURE.md) - Complete directory guide
- [Istio Deployment Guide](ISTIO-DEPLOYMENT.md) - Service mesh details
- [Security Scanning](SECURITY-SCANNING.md) - Security tools and processes

### Service Details
- [Protocol Buffers](protos/) - gRPC service definitions
- [Kubernetes Manifests](kubernetes-manifests/) - Service deployments
- [Istio Manifests](istio-manifests/) - Traffic routing rules
- [Source Code](src/) - Individual microservice documentation

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n default

# Describe problematic pod
kubectl describe pod <pod-name> -n default

# Check logs
kubectl logs <pod-name> -n default -c server

# Common issues:
# - Image pull errors: Check ECR permissions
# - Resource limits: Increase in deployment
# - Missing ConfigMap: Verify Redis config created
```

### Services Can't Communicate

```bash
# Verify Istio sidecar injection
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'
# Should show both 'server' and 'istio-proxy'

# Check mTLS configuration
kubectl get peerauthentication -n istio-system

# Test service DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup frontend.default.svc.cluster.local
```

### Istio Issues

```bash
# Analyze configuration
istioctl analyze -n default

# Check proxy status
istioctl proxy-status

# View Envoy configuration
istioctl proxy-config route <pod-name> -n default

# Check gateway
kubectl get gateway -n default
kubectl describe gateway frontend-gateway -n default
```

### Infrastructure Issues

```bash
# Check Terraform state
terraform -chdir=terraform-aws show

# Validate configuration
terraform -chdir=terraform-aws validate

# Re-apply specific resource
terraform -chdir=terraform-aws apply -target=module.eks
```

### Load Balancer Not Working

```bash
# Check NLB status
kubectl describe svc istio-ingressgateway -n istio-system

# Verify AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check AWS console
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `istio`)].DNSName'
```

### Performance Issues

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n default

# View Grafana dashboards for detailed metrics
kubectl port-forward svc/grafana -n istio-system 3000:80

# Scale services if needed
kubectl scale deployment frontend --replicas=5
```

See [REPOSITORY-STRUCTURE.md](REPOSITORY-STRUCTURE.md#troubleshooting) for more troubleshooting guides.

## Cleanup

### Option 1: Terraform Destroy (Complete Cleanup)

```bash
cd terraform-aws
terraform destroy
```

This removes:
- EKS cluster and node groups
- VPC and networking components
- ElastiCache Redis cluster
- IAM roles and policies
- CloudWatch log groups
- All Istio components

**Note:** ECR repositories are retained by default. To delete:

```bash
# List repositories
aws ecr describe-repositories --query 'repositories[].repositoryName'

# Delete each repository
aws ecr delete-repository --repository-name frontend --force
# Repeat for all 12 repositories
```

### Option 2: Partial Cleanup (Keep Infrastructure)

```bash
# Just delete application
kubectl delete -f release/kubernetes-manifests.yaml
kubectl delete -f istio-manifests/

# Scale down nodes
kubectl scale deployment --all --replicas=0 -n default
```

### Cost During Idle

If keeping infrastructure but not using:
- EKS control plane: $73/month (unavoidable)
- Nodes: Scale to 0 with cluster autoscaler
- NAT Gateway: $33/month (unavoidable if kept)
- Redis: $15/month (can be stopped via Terraform)

**Recommendation**: Destroy everything when not in use, redeploy when needed (~15 minutes).

## Additional Resources

### Official Documentation
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Related Projects
- [EKS Blueprints](https://aws-ia.github.io/terraform-aws-eks-blueprints/) - AWS EKS patterns
- [Istio on AWS](https://aws.github.io/aws-eks-best-practices/networking/service-mesh/istio/)
- [gRPC Documentation](https://grpc.io/docs/)

### Community
- [AWS Containers Roadmap](https://github.com/aws/containers-roadmap)
- [Istio Community](https://istio.io/latest/get-involved/)
- [CNCF Slack](https://slack.cncf.io/) - #istio, #kubernetes

## Screenshots

| Home Page | Checkout Screen |
|-----------|-----------------|
| [![Screenshot of store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Screenshot of checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run security scans locally
5. Submit a pull request

See [REPOSITORY-STRUCTURE.md](REPOSITORY-STRUCTURE.md#contributing) for guidelines.

## License

This project is licensed under the Apache License 2.0 - see individual files for details.

Original Google Cloud version: [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

## Support

For issues and questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review the [documentation](#documentation)
3. Search existing GitHub issues
4. Open a new issue with:
   - Description of the problem
   - Steps to reproduce
   - Logs and error messages
   - Environment details (region, versions, etc.)

---

**Star this repository** if you find it useful! ⭐

**Perfect for demonstrating:**
- Microservices architecture on AWS
- Istio service mesh capabilities
- GitOps workflows with GitHub Actions
- Multi-language gRPC applications
- Comprehensive security scanning
- Cloud-native observability
- Infrastructure as Code with Terraform
