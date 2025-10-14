# EKS Cluster Setup Complete ✅

## Deployment Summary

**Date**: October 14, 2025
**Cluster Name**: microservices
**Region**: eu-west-2 (London, UK)
**Kubernetes Version**: 1.30.14

---

## ✅ Infrastructure Components

### EKS Cluster
- **Control Plane**: Active (v1.30.14)
- **Node Groups**: 4 (system, dev, qa, prod)
- **Total Nodes**: 12
- **All Nodes Status**: Ready

### Node Groups Configuration
1. **System** (2x t3.small) - Cluster infrastructure
   - No taints - allows system pods to schedule
   - Running: CoreDNS, EBS CSI Driver, ALB Controller, etc.

2. **Dev** (2x t3.medium) - Development workloads
   - Taint: `environment=dev:NoSchedule`

3. **QA** (3x t3.large) - QA/Testing workloads
   - Taint: `environment=qa:NoSchedule`

4. **Prod** (5x t3.xlarge) - Production workloads
   - Taint: `environment=prod:NoSchedule`

---

## ✅ EKS Add-ons (All ACTIVE)

1. **CoreDNS** (v1.11.4-eksbuild.24)
2. **AWS EBS CSI Driver** (v1.50.1-eksbuild.1)
3. **kube-proxy** (v1.30.14-eksbuild.8)
4. **vpc-cni** (v1.20.3-eksbuild.1)

---

## ✅ Installed Helm Charts

1. **aws-load-balancer-controller** (v2.6.2) - kube-system
2. **metrics-server** (v0.6.4) - kube-system
3. **cluster-autoscaler** (v1.27.2) - kube-system
4. **istio-base** (v1.23.0) - istio-system
5. **istiod** (v1.23.0) - istio-system

---

## ✅ Istio Service Mesh

### Core Components
- **Istiod**: Running (control plane)
- **Istio Ingress Gateway**: Running (2 replicas)
  - External URL: `k8s-istiosys-istioing-feed220fe8-a07b69cad97917cc.elb.eu-west-2.amazonaws.com`
  - Type: AWS Network Load Balancer (NLB)
  - Ports: 80 (HTTP), 443 (HTTPS), 15021 (health)

### Observability Stack
- **Prometheus**: Running (metrics collection)
- **Grafana**: Running (dashboards)
- **Jaeger**: Running (distributed tracing)
- **Kiali**: Running (service mesh visualization)

### Security Configuration
- **Strict mTLS**: Enabled globally
- **Istio Injection**: Enabled on default namespace
- **PeerAuthentication**: STRICT mode enforced

---

## ✅ Redis (ElastiCache)

- **Endpoint**: `microservices-redis.injaha.0001.euw2.cache.amazonaws.com:6379`
- **Kubernetes Secret**: redis-connection (created)
- **Kubernetes ConfigMap**: redis-config (created)

---

## ✅ IAM & Access Control

### IAM Roles (IRSA)
- ALB Controller Role
- Cluster Autoscaler Role
- EBS CSI Driver Role
- Node Group Roles (system, dev, qa, prod)

### EKS Access Entries
- IAM User: `arn:aws:iam::533267307120:user/Olaf.Freund`
- Policy: `AmazonEKSClusterAdminPolicy` (cluster-wide admin)

---

## 📊 Cluster Status

- **Total Pods**: 51
- **Running Pods**: 51 (100%)
- **Failed Pods**: 0

---

## 🔧 Key Fixes Applied

### 1. System Node Group
**Problem**: EKS add-ons (CoreDNS, EBS CSI) stuck in DEGRADED state
**Cause**: All node groups had taints, preventing system pods from scheduling
**Solution**: Added untainted system node group (2x t3.small)
**Cost**: ~£12/month

### 2. Istiod Resource Constraints
**Problem**: Istiod pod stuck in Pending state
**Cause**: Default resource request (2Gi memory) exceeded t3.small capacity
**Solution**: Reduced istiod memory request to 512Mi
**Result**: Istiod successfully running

### 3. kubectl Authentication
**Problem**: kubectl couldn't authenticate to EKS cluster
**Cause**: IAM user not in EKS access entries
**Solution**: Created EKS access entry with cluster admin policy
**Result**: Full kubectl access restored

### 4. Istio Ingress Gateway Helm Issues
**Problem**: Helm chart schema validation errors
**Cause**: Incorrect parameter structure for gateway chart
**Solution**: Deployed ingress gateway using kubectl manifests
**Result**: Ingress gateway running with AWS NLB

---

## 🚀 Next Steps

### 1. Deploy Microservices Application

```bash
# Traditional deployment
kubectl apply -f release/kubernetes-manifests.yaml

# Or using Kustomize for multi-environment
kubectl apply -k kustomize/overlays/dev    # Deploy to dev
kubectl apply -k kustomize/overlays/qa     # Deploy to qa
kubectl apply -k kustomize/overlays/prod   # Deploy to prod
```

### 2. Configure Application Gateway

Apply Istio Gateway and VirtualService:
```bash
kubectl apply -f istio-manifests/frontend-gateway.yaml
kubectl apply -f istio-manifests/frontend.yaml
```

### 3. Access Application

Get the external URL:
```bash
kubectl get svc -n istio-system istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 4. Monitor with Istio Dashboards

```bash
# Kiali - Service mesh topology
kubectl port-forward svc/kiali -n istio-system 20001:20001

# Grafana - Metrics and dashboards
kubectl port-forward svc/grafana -n istio-system 3000:3000

# Jaeger - Distributed tracing
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686

# Prometheus - Raw metrics
kubectl port-forward svc/prometheus -n istio-system 9090:9090
```

### 5. (Optional) Upgrade to Kubernetes 1.31

Once stable on 1.30, optionally upgrade:
```bash
# Update terraform.tfvars
cluster_version = "1.31"

# Apply
terraform apply -auto-approve
```

---

## 📁 Important Files

### Configuration
- **Environment Variables**: `.envrc` (AWS credentials)
- **Terraform State**: `terraform-aws/terraform.tfstate`
- **Kubeconfig**: `~/.kube/config`

### Scripts
- **post-install.sh**: Helm chart installation script
- **run-post-install.sh**: Wrapper with embedded credentials
- **continue-install.sh**: Resume installation from failure
- **fix-istiod.sh**: Fix istiod resource constraints
- **check-status.sh**: Comprehensive cluster status check
- **final-check.sh**: Final verification script

### Documentation
- **CLAUDE.md**: Project overview and commands
- **README.md**: Complete project documentation
- **SINGLE-CLUSTER-MIGRATION.md**: Single-cluster architecture rationale
- **MIGRATION-SUMMARY.md**: GCP to AWS migration details

---

## 💰 Cost Summary (GBP)

### Monthly Costs
- **EKS Control Plane**: £60
- **System Nodes** (2x t3.small): £12
- **Dev Nodes** (2x t3.medium): £37
- **QA Nodes** (3x t3.large): £74
- **Prod Nodes** (5x t3.xlarge): £205
- **NAT Gateway**: £27
- **Load Balancer**: £15
- **ElastiCache Redis**: £8
- **ECR + CloudWatch**: £5

**Total**: ~£443/month

### Savings
- **Before** (3 separate clusters): ~£549/month
- **After** (1 cluster with 4 node groups): ~£482/month
- **Monthly Savings**: ~£67 (~12% reduction)

---

## ✅ Verification Commands

```bash
# Check all pods
kubectl get pods -A

# Check nodes
kubectl get nodes -o wide

# Check EKS add-ons
aws eks list-addons --cluster-name microservices --region eu-west-2

# Check Istio components
kubectl get pods -n istio-system

# Check Helm releases
helm list -A

# Get Ingress Gateway URL
kubectl get svc -n istio-system istio-ingressgateway
```

---

## 🎉 Cluster is Ready!

All infrastructure components are deployed and operational. The cluster is ready for application deployment and production workloads.

**Ingress Gateway External URL**:
`k8s-istiosys-istioing-feed220fe8-a07b69cad97917cc.elb.eu-west-2.amazonaws.com`

---

*Setup completed on: October 14, 2025*
*Cluster Version: Kubernetes 1.30.14*
*Istio Version: 1.23.0*
