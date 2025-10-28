# AWS Deployment Guide - Microservices Demo

> **Purpose**: Deploy the complete infrastructure (EKS cluster, networking, storage) to AWS
> **Time**: 30-45 minutes
> **Prerequisites**: AWS account with admin access, AWS CLI installed

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Account Setup](#aws-account-setup)
3. [Configure AWS Credentials](#configure-aws-credentials)
4. [Deploy Infrastructure with Terraform](#deploy-infrastructure-with-terraform)
5. [Verify Deployment](#verify-deployment)
6. [Configure kubectl](#configure-kubectl)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install these tools on your local machine:

```bash
# Check if tools are installed
git --version          # Git (any recent version)
docker --version       # Docker 20.10+
kubectl version        # kubectl 1.28+
terraform --version    # Terraform 1.5+
aws --version          # AWS CLI 2.x
```

### Install Missing Tools

**macOS (using Homebrew)**:
```bash
brew install git docker kubectl terraform awscli
```

**Linux (Ubuntu/Debian)**:
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

---

## AWS Account Setup

### 1. Create AWS Account

If you don't have an AWS account:
1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. Add payment method (required for EKS, but you'll stay within free tier limits for testing)

### 2. Create IAM User for Terraform

**Why**: Best practice to use IAM user instead of root credentials

**Steps**:

1. **Login to AWS Console**: https://console.aws.amazon.com/
2. **Navigate to IAM**: Services → IAM
3. **Create User**:
   - Click "Users" → "Add users"
   - Username: `terraform-deploy`
   - Access type: ✅ Programmatic access
   - Click "Next: Permissions"

4. **Attach Policies**:
   - Click "Attach existing policies directly"
   - Select these policies:
     - ✅ `AdministratorAccess` (for initial setup)
     - Or create custom policy (production-ready, see below)
   - Click "Next: Tags" → "Next: Review" → "Create user"

5. **Save Credentials**:
   - ⚠️ **IMPORTANT**: Download CSV or copy credentials immediately
   - Access Key ID: `AKIA...`
   - Secret Access Key: `wJalrXUtn...`
   - You won't see the secret key again!

### Custom IAM Policy (Production)

For production, use this least-privilege policy instead of `AdministratorAccess`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "elasticache:*",
        "ecr:*",
        "iam:*",
        "logs:*",
        "s3:*",
        "dynamodb:*",
        "autoscaling:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Configure AWS Credentials

### Method 1: Using .envrc (Recommended for local development)

1. **Copy the example file**:
   ```bash
   cp .envrc.example .envrc
   ```

2. **Edit .envrc** with your credentials:
   ```bash
   nano .envrc
   ```

   ```bash
   # AWS Credentials (from IAM user creation)
   export AWS_ACCESS_KEY_ID="AKIA..."
   export AWS_SECRET_ACCESS_KEY="wJalrXUtn..."
   export AWS_DEFAULT_REGION="eu-west-2"  # London
   export AWS_REGION="eu-west-2"

   # Terraform Backend (optional - see step 5)
   export TF_VAR_backend_bucket="microservices-terraform-state-YOURACCOUNTID"
   export TF_VAR_backend_dynamodb_table="microservices-terraform-locks"
   ```

3. **Load credentials**:
   ```bash
   source .envrc
   ```

4. **Verify**:
   ```bash
   aws sts get-caller-identity
   ```

   Expected output:
   ```json
   {
       "UserId": "AIDA...",
       "Account": "123456789012",
       "Arn": "arn:aws:iam::123456789012:user/terraform-deploy"
   }
   ```

### Method 2: Using AWS CLI Configure

```bash
aws configure
```

Enter when prompted:
- AWS Access Key ID: `AKIA...`
- AWS Secret Access Key: `wJalrXUtn...`
- Default region name: `eu-west-2`
- Default output format: `json`

---

## Deploy Infrastructure with Terraform

### Architecture Overview

What Terraform will create:

- **VPC**: 3 availability zones, public/private subnets, NAT gateway
- **EKS Cluster**: Kubernetes 1.28, single node group
- **Node Group**: 4x t3.large nodes (can be reduced for cost savings)
- **ElastiCache**: Redis cluster for cartservice
- **ECR**: 12 container registries (one per microservice)
- **IAM Roles**: IRSA for ALB controller, cluster autoscaler, EBS CSI
- **VPC Endpoints**: For ECR, S3, CloudWatch (cost optimization)

**Estimated Cost**: ~$300-400/month (can be reduced to $134/month with optimizations)

### Step 1: Initialize Terraform

```bash
cd terraform-aws
terraform init
```

Expected output:
```
Initializing modules...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 2: Review the Plan

```bash
terraform plan
```

This shows what will be created. Review carefully:
- ✅ VPC with 3 AZs
- ✅ EKS cluster named "microservices"
- ✅ Node group with 4 nodes
- ✅ ElastiCache Redis cluster
- ✅ 12 ECR repositories
- ✅ IAM roles and policies

### Step 3: Apply (Create Infrastructure)

```bash
terraform apply
```

Type `yes` when prompted.

**Time**: ~15-20 minutes

Progress indicators:
- VPC creation: ~2 minutes
- EKS cluster: ~10-12 minutes
- Node group: ~5 minutes
- ElastiCache: ~3 minutes

### Step 4: Wait for Completion

You'll see output like:
```
Apply complete! Resources: 87 added, 0 changed, 0 destroyed.

Outputs:

cluster_endpoint = "https://ABC123.gr7.eu-west-2.eks.amazonaws.com"
cluster_name = "microservices"
ecr_repositories = {
  adservice = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/adservice"
  cartservice = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/cartservice"
  ...
}
redis_endpoint = "microservices-redis.abc123.0001.euw2.cache.amazonaws.com:6379"
```

**Save these outputs** - you'll need them later!

---

## Verify Deployment

### 1. Check AWS Console

**EKS Cluster**:
1. Open: https://console.aws.amazon.com/eks/
2. Region: eu-west-2 (London)
3. Should see: Cluster "microservices" - Status: Active
4. Click cluster → Compute → Should see node group with 4 nodes

**ECR Repositories**:
1. Open: https://console.aws.amazon.com/ecr/
2. Should see 12 repositories: adservice, cartservice, checkoutservice, etc.

**ElastiCache**:
1. Open: https://console.aws.amazon.com/elasticache/
2. Should see: Redis cluster "microservices-redis" - Status: Available

### 2. Verify via CLI

```bash
# Check EKS cluster
aws eks describe-cluster --name microservices --region eu-west-2

# Check node group
aws eks describe-nodegroup \
  --cluster-name microservices \
  --nodegroup-name all-in-one \
  --region eu-west-2

# List ECR repositories
aws ecr describe-repositories --region eu-west-2 | grep repositoryName
```

---

## Configure kubectl

### 1. Update kubeconfig

```bash
aws eks update-kubeconfig --region eu-west-2 --name microservices
```

Output:
```
Added new context arn:aws:eks:eu-west-2:123456789012:cluster/microservices to /home/user/.kube/config
```

### 2. Verify Connection

```bash
kubectl get nodes
```

Expected output:
```
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-1-123.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.3-eks-...
ip-10-0-2-456.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.3-eks-...
ip-10-0-3-789.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.3-eks-...
ip-10-0-4-012.eu-west-2.compute.internal     Ready    <none>   5m    v1.28.3-eks-...
```

### 3. Check System Pods

```bash
kubectl get pods -n kube-system
```

All pods should be Running:
- coredns
- aws-node (VPC CNI)
- kube-proxy
- aws-load-balancer-controller
- cluster-autoscaler
- ebs-csi-controller

---

## Troubleshooting

### Issue: "terraform init" fails

**Error**: `Error: Failed to install provider`

**Solution**:
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init
```

### Issue: "terraform apply" fails with permission denied

**Error**: `Error creating EKS Cluster: AccessDeniedException`

**Causes**:
- AWS credentials not configured
- IAM user lacks permissions

**Solutions**:
```bash
# Verify credentials are loaded
aws sts get-caller-identity

# Re-load .envrc
source .envrc

# Check IAM user has AdministratorAccess or EKS permissions
aws iam list-attached-user-policies --user-name terraform-deploy
```

### Issue: Cluster creation times out

**Error**: `Error: timeout while waiting for state to become 'ACTIVE'`

**Cause**: AWS API rate limiting or transient issue

**Solution**:
```bash
# Check cluster status in console
aws eks describe-cluster --name microservices --region eu-west-2

# If cluster exists but Terraform timed out, import it
terraform import 'module.eks.aws_eks_cluster.this[0]' microservices

# Re-run apply
terraform apply
```

### Issue: Node group fails to create

**Error**: `Error: error waiting for EKS Node Group ... to be created`

**Causes**:
- Insufficient EC2 capacity in region
- Service quotas exceeded

**Solutions**:
```bash
# Check service quotas
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --region eu-west-2 | grep -i "Running On-Demand"

# Request quota increase if needed (AWS Console → Service Quotas)

# Or use smaller instance type (terraform-aws/eks.tf):
# Change: instance_types = ["t3.large"]
# To:     instance_types = ["t3.medium"]
```

### Issue: kubectl cannot connect

**Error**: `The connection to the server ... was refused`

**Solutions**:
```bash
# Re-configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name microservices

# Verify cluster is active
aws eks describe-cluster --name microservices --region eu-west-2 | grep status

# Check network connectivity
curl -I https://$(terraform output -raw cluster_endpoint | sed 's|https://||')
```

### Issue: Nodes not joining cluster

**Error**: Nodes show in EC2 but not in `kubectl get nodes`

**Causes**:
- IAM role trust policy incorrect
- Security group blocking kubelet

**Solutions**:
```bash
# Check node IAM role
aws eks describe-nodegroup \
  --cluster-name microservices \
  --nodegroup-name all-in-one \
  --region eu-west-2 | grep nodeRole

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=microservices" \
  --region eu-west-2

# Check CloudWatch logs (if nodes exist but don't join)
# AWS Console → CloudWatch → Log Groups → /aws/eks/microservices/cluster
```

---

## Cost Optimization (Optional)

### Reduce to Ultra-Minimal Setup ($134/month)

If you want to minimize costs for demo purposes:

1. **Edit** `terraform-aws/eks.tf`:
   ```hcl
   # Change node group size
   desired_size = 1  # was 4
   min_size     = 1  # was 3
   max_size     = 2  # was 5

   instance_types = ["t3.large"]  # single instance type
   ```

2. **Edit** `terraform-aws/elasticache.tf`:
   ```hcl
   # Use smallest instance
   node_type = "cache.t3.micro"  # was cache.t3.small

   # Single node (no replication)
   num_cache_nodes = 1  # was 2
   ```

3. **Apply changes**:
   ```bash
   terraform apply
   ```

**New cost**: ~$134/month (vs $300-400/month)

**Trade-offs**:
- No high availability (single node)
- Limited capacity (can't run all 3 environments with full replicas)
- Good for: demos, testing, dev environments
- NOT for: production

---

## Next Steps

✅ **Infrastructure Deployed!**

Now proceed to:

1. **[GitHub Setup Guide](2-GITHUB-SETUP-GUIDE.md)**
   - Configure GitHub Actions
   - Set up secrets
   - Build and push container images
   - Deploy application

2. **[ServiceNow Integration Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)**
   - Install ServiceNow DevOps plugin
   - Configure GitHub integration
   - Set up automated change management

---

## Cleanup (Destroy Infrastructure)

⚠️ **WARNING**: This deletes everything and cannot be undone!

```bash
cd terraform-aws
terraform destroy
```

Type `yes` when prompted.

**Time**: ~10-15 minutes

This removes:
- EKS cluster and nodes
- ElastiCache Redis
- VPC and all networking
- ECR repositories (images will be deleted!)
- All data

---

## Reference

### Terraform Outputs

After successful deployment, these outputs are available:

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_endpoint
terraform output cluster_name
terraform output redis_endpoint

# Get ECR URL for specific service
terraform output -json ecr_repositories | jq -r '.adservice'
```

### Important ARNs and IDs

Save these for troubleshooting:

```bash
# Cluster ARN
aws eks describe-cluster --name microservices --region eu-west-2 --query 'cluster.arn'

# Node group ARN
aws eks describe-nodegroup \
  --cluster-name microservices \
  --nodegroup-name all-in-one \
  --region eu-west-2 \
  --query 'nodegroup.nodegroupArn'

# VPC ID
terraform output vpc_id
```

---

## Support

**Issues?**
- Check [Troubleshooting](#troubleshooting) section above
- Review Terraform logs: `terraform apply 2>&1 | tee apply.log`
- Check AWS Console for resource status
- Open GitHub issue: https://github.com/Freundcloud/microservices-demo/issues

**Documentation**:
- AWS EKS: https://docs.aws.amazon.com/eks/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

**Estimated Total Time**: 30-45 minutes (mostly waiting for AWS resources)

**Estimated Cost**: $300-400/month (standard) or $134/month (ultra-minimal)

**Ready?** Start with [AWS Account Setup](#aws-account-setup) above! 🚀
