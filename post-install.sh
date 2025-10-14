#!/usr/bin/env bash
# Post-Install Script for EKS Cluster
# This script installs Helm charts and Kubernetes resources after Terraform creates the cluster
# Run this after: terraform apply

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-microservices}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
ISTIO_VERSION="${ISTIO_VERSION:-1.23.0}"

echo -e "${GREEN}=== EKS Cluster Post-Install Script ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}ERROR: aws CLI not found${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}ERROR: kubectl not found${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}ERROR: helm not found${NC}"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || {
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Please run: source .envrc"
    exit 1
}

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo -e "${GREEN}✓ Kubeconfig updated${NC}"
echo ""

# Get cluster info from Terraform
echo -e "${YELLOW}Getting cluster information...${NC}"
cd terraform-aws
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
ALB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
CLUSTER_AUTOSCALER_ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn 2>/dev/null || echo "")
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")
cd ..

if [ -z "$VPC_ID" ]; then
    echo -e "${RED}ERROR: Could not get VPC ID from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster info retrieved${NC}"
echo "  VPC ID: $VPC_ID"
echo "  Region: $AWS_REGION"
echo ""

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo add autoscaler https://kubernetes.github.io/autoscaler 2>/dev/null || true
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
helm repo update
echo -e "${GREEN}✓ Helm repositories added${NC}"
echo ""

# Install AWS Load Balancer Controller
if [ -n "$ALB_ROLE_ARN" ]; then
    echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --version 1.6.2 \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ALB_ROLE_ARN" \
        --set region="$AWS_REGION" \
        --set vpcId="$VPC_ID" \
        --wait
    echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"
else
    echo -e "${YELLOW}⊘ Skipping AWS Load Balancer Controller (role ARN not found)${NC}"
fi
echo ""

# Install Metrics Server
echo -e "${YELLOW}Installing Metrics Server...${NC}"
helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --version 3.11.0 \
    --set args[0]=--kubelet-preferred-address-types=InternalIP \
    --wait
echo -e "${GREEN}✓ Metrics Server installed${NC}"
echo ""

# Install Cluster Autoscaler
if [ -n "$CLUSTER_AUTOSCALER_ROLE_ARN" ]; then
    echo -e "${YELLOW}Installing Cluster Autoscaler...${NC}"
    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
        --namespace kube-system \
        --version 9.29.3 \
        --set autoDiscovery.clusterName="$CLUSTER_NAME" \
        --set awsRegion="$AWS_REGION" \
        --set rbac.serviceAccount.create=true \
        --set rbac.serviceAccount.name=cluster-autoscaler \
        --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CLUSTER_AUTOSCALER_ROLE_ARN" \
        --wait
    echo -e "${GREEN}✓ Cluster Autoscaler installed${NC}"
else
    echo -e "${YELLOW}⊘ Skipping Cluster Autoscaler (role ARN not found)${NC}"
fi
echo ""

# Install Istio Base
echo -e "${YELLOW}Installing Istio Base...${NC}"
helm upgrade --install istio-base istio/base \
    --namespace istio-system \
    --create-namespace \
    --version "$ISTIO_VERSION" \
    --set defaultRevision=default \
    --wait
echo -e "${GREEN}✓ Istio Base installed${NC}"
echo ""

# Install Istiod
echo -e "${YELLOW}Installing Istiod...${NC}"
helm upgrade --install istiod istio/istiod \
    --namespace istio-system \
    --version "$ISTIO_VERSION" \
    --set global.hub=docker.io/istio \
    --set global.tag="$ISTIO_VERSION" \
    --set meshConfig.accessLogFile=/dev/stdout \
    --set meshConfig.enableTracing=true \
    --set meshConfig.defaultConfig.proxyMetadata.ISTIO_META_TLS_MODE=ISTIO_MUTUAL \
    --set meshConfig.defaultConfig.tracing.zipkin.address=zipkin.istio-system:9411 \
    --wait
echo -e "${GREEN}✓ Istiod installed${NC}"
echo ""

# Install Istio Ingress Gateway
echo -e "${YELLOW}Installing Istio Ingress Gateway...${NC}"
helm upgrade --install istio-ingressgateway istio/gateway \
    --namespace istio-system \
    --version "$ISTIO_VERSION" \
    --set service.type=LoadBalancer \
    --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type=nlb" \
    --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme=internet-facing" \
    --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled=true" \
    --set resources.requests.cpu=100m \
    --set resources.requests.memory=128Mi \
    --set resources.limits.cpu=2000m \
    --set resources.limits.memory=1024Mi \
    --set autoscaling.enabled=true \
    --set autoscaling.minReplicas=2 \
    --set autoscaling.maxReplicas=5 \
    --set autoscaling.targetCPUUtilizationPercentage=80 \
    --wait
echo -e "${GREEN}✓ Istio Ingress Gateway installed${NC}"
echo ""

# Install Prometheus (Istio addon)
echo -e "${YELLOW}Installing Prometheus...${NC}"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/prometheus.yaml
echo -e "${GREEN}✓ Prometheus installed${NC}"
echo ""

# Install Grafana (Istio addon)
echo -e "${YELLOW}Installing Grafana...${NC}"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/grafana.yaml
echo -e "${GREEN}✓ Grafana installed${NC}"
echo ""

# Install Jaeger (Istio addon)
echo -e "${YELLOW}Installing Jaeger...${NC}"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/jaeger.yaml
echo -e "${GREEN}✓ Jaeger installed${NC}"
echo ""

# Install Kiali (Istio addon)
echo -e "${YELLOW}Installing Kiali...${NC}"
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/kiali.yaml
echo -e "${GREEN}✓ Kiali installed${NC}"
echo ""

# Create Redis resources
if [ -n "$REDIS_ENDPOINT" ]; then
    echo -e "${YELLOW}Creating Redis Kubernetes resources...${NC}"
    kubectl create secret generic redis-connection \
        --from-literal=REDIS_ADDR="$REDIS_ENDPOINT:6379" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl create configmap redis-config \
        --from-literal=REDIS_ADDR="$REDIS_ENDPOINT:6379" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}✓ Redis resources created${NC}"
else
    echo -e "${YELLOW}⊘ Skipping Redis resources (endpoint not found)${NC}"
fi
echo ""

# Enable Istio injection on default namespace
echo -e "${YELLOW}Enabling Istio injection on default namespace...${NC}"
kubectl label namespace default istio-injection=enabled --overwrite
echo -e "${GREEN}✓ Istio injection enabled${NC}"
echo ""

# Apply strict mTLS PeerAuthentication
echo -e "${YELLOW}Applying strict mTLS policy...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
echo -e "${GREEN}✓ Strict mTLS policy applied${NC}"
echo ""

# Summary
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Installed components:"
echo "  ✓ AWS Load Balancer Controller"
echo "  ✓ Metrics Server"
echo "  ✓ Cluster Autoscaler"
echo "  ✓ Istio Base"
echo "  ✓ Istiod"
echo "  ✓ Istio Ingress Gateway"
echo "  ✓ Prometheus"
echo "  ✓ Grafana"
echo "  ✓ Jaeger"
echo "  ✓ Kiali"
echo "  ✓ Redis connection resources"
echo "  ✓ Strict mTLS policy"
echo ""
echo "Next steps:"
echo "  1. Check cluster status: kubectl get pods -A"
echo "  2. Get Istio gateway URL: kubectl get svc -n istio-system istio-ingressgateway"
echo "  3. Deploy applications: kubectl apply -k kustomize/overlays/dev"
echo ""
echo "Useful commands:"
echo "  just k8s-status       # Check cluster status"
echo "  just istio-kiali      # Open Kiali dashboard"
echo "  just istio-grafana    # Open Grafana dashboard"
echo "  just istio-jaeger     # Open Jaeger dashboard"
echo ""
