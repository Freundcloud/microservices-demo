# Istio Service Mesh Deployment Guide

This guide explains how Istio service mesh is deployed and configured for the microservices demo on AWS EKS.

## Overview

Istio provides:
- **Service-to-service communication security** with mutual TLS (mTLS)
- **Traffic management** with intelligent routing
- **Observability** with metrics, logs, and distributed tracing
- **Circuit breaking and fault injection** for resilience testing

## Architecture

The Istio deployment consists of:

1. **Istio Control Plane (istiod)**: Manages service mesh configuration
2. **Istio Ingress Gateway**: Handles external traffic entry with AWS NLB
3. **Observability Stack**:
   - **Kiali**: Service mesh dashboard and topology visualization
   - **Prometheus**: Metrics collection and storage
   - **Jaeger**: Distributed tracing
   - **Grafana**: Metrics visualization

## Terraform Configuration

### Enable/Disable Istio

Istio is controlled via Terraform variables in `terraform-aws/variables.tf`:

```hcl
variable "enable_istio" {
  description = "Enable Istio service mesh"
  type        = bool
  default     = true
}

variable "istio_version" {
  description = "Istio version to install"
  type        = string
  default     = "1.20.0"
}

variable "enable_istio_addons" {
  description = "Enable Istio observability addons (Kiali, Prometheus, Jaeger, Grafana)"
  type        = bool
  default     = true
}
```

### Terraform Deployment

The Istio infrastructure is defined in `terraform-aws/istio.tf`:

**Components deployed:**
1. `helm_release.istio_base` - Istio CRDs and base resources
2. `helm_release.istiod` - Istio control plane
3. `helm_release.istio_ingressgateway` - Ingress gateway with AWS NLB
4. `helm_release.kiali` - Service mesh dashboard
5. `helm_release.prometheus` - Metrics collection
6. `helm_release.jaeger` - Distributed tracing
7. `helm_release.grafana` - Visualization dashboards
8. `kubernetes_namespace.istio_enabled` - Application namespace with Istio injection
9. `kubectl_manifest.peer_authentication` - Strict mTLS enforcement
10. `kubectl_manifest.destination_rule_mtls` - mTLS traffic policy

### AWS-Specific Configuration

The Istio Ingress Gateway is configured for AWS with:

```hcl
set {
  name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
  value = "nlb"  # Network Load Balancer
}

set {
  name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
  value = "internet-facing"
}

set {
  name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
  value = "true"
}
```

### Security Configuration

**Strict mTLS is enforced globally:**

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

**All services use mTLS for communication:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default
  namespace: istio-system
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

## Istio Manifests

The `istio-manifests/` directory contains Istio routing configurations:

### frontend-gateway.yaml
Defines the Istio Gateway and VirtualService for external traffic:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-ingress
spec:
  hosts:
  - "*"
  gateways:
  - frontend-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
```

### frontend.yaml
Defines internal service routing:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "frontend.default.svc.cluster.local"
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
```

## Deployment Steps

### 1. Deploy Infrastructure with Istio

```bash
cd terraform-aws

# Initialize Terraform
terraform init

# Review Istio configuration
terraform plan

# Deploy (Istio will be installed automatically)
terraform apply
```

### 2. Verify Istio Installation

```bash
# Configure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check Istio components
kubectl get pods -n istio-system

# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# grafana-xxx                           1/1     Running   0          5m
# istio-ingressgateway-xxx              1/1     Running   0          5m
# istiod-xxx                            1/1     Running   0          6m
# jaeger-xxx                            1/1     Running   0          5m
# kiali-server-xxx                      1/1     Running   0          5m
# prometheus-server-xxx                 1/1     Running   0          5m
```

### 3. Deploy Application with Istio

```bash
# Deploy Kubernetes manifests (microservices will get Istio sidecar automatically)
kubectl apply -f release/kubernetes-manifests.yaml

# Apply Istio routing rules
kubectl apply -f istio-manifests/

# Verify Istio sidecar injection
kubectl get pods -n default
# Each pod should show 2/2 containers (app + istio-proxy)
```

### 4. Get Ingress Gateway URL

```bash
# Get the NLB hostname
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or use Terraform output
terraform output istio_ingress_gateway_url
```

## Observability Dashboards

### Kiali (Service Mesh Dashboard)

Access Kiali to visualize service topology and traffic flow:

```bash
kubectl port-forward svc/kiali-server -n istio-system 20001:20001
```

Then open: http://localhost:20001

**Features:**
- Service graph visualization
- Traffic metrics and rates
- Service health indicators
- Configuration validation
- Distributed tracing integration

### Grafana (Metrics Visualization)

Access Grafana for metrics dashboards:

```bash
kubectl port-forward svc/grafana -n istio-system 3000:80
```

Then open: http://localhost:3000

**Pre-configured dashboards:**
- Istio Mesh Dashboard
- Istio Service Dashboard
- Istio Workload Dashboard
- Istio Performance Dashboard

### Jaeger (Distributed Tracing)

Access Jaeger for request tracing:

```bash
kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
```

Then open: http://localhost:16686

**Features:**
- End-to-end request tracing
- Service dependency analysis
- Performance bottleneck identification
- Error trace analysis

### Prometheus (Metrics Collection)

Access Prometheus for raw metrics:

```bash
kubectl port-forward svc/prometheus-server -n istio-system 9090:80
```

Then open: http://localhost:9090

## Terraform Outputs

After deployment, Terraform provides these Istio-related outputs:

```bash
terraform output istio_enabled              # Whether Istio is enabled
terraform output istio_version              # Installed Istio version
terraform output istio_ingress_gateway_url  # Command to get ingress URL
terraform output kiali_dashboard_command    # Command to access Kiali
terraform output grafana_dashboard_command  # Command to access Grafana
terraform output jaeger_dashboard_command   # Command to access Jaeger
```

## Traffic Management Examples

### Canary Deployment

Deploy a new version alongside the old:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-canary
spec:
  hosts:
  - frontend
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: frontend
        subset: v2
  - route:
    - destination:
        host: frontend
        subset: v1
      weight: 90
    - destination:
        host: frontend
        subset: v2
      weight: 10
```

### Circuit Breaking

Protect services from cascading failures:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: frontend-circuit-breaker
spec:
  host: frontend
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

### Fault Injection

Test resilience with controlled failures:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-fault
spec:
  hosts:
  - frontend
  http:
  - fault:
      delay:
        percentage:
          value: 10.0
        fixedDelay: 5s
      abort:
        percentage:
          value: 5.0
        httpStatus: 500
    route:
    - destination:
        host: frontend
```

## Monitoring and Alerts

### Service Mesh Metrics

Istio automatically collects metrics for:
- Request volume, duration, and size
- Success/failure rates
- Request/response latencies (p50, p90, p95, p99)
- TCP connection metrics

### CloudWatch Integration

The Terraform configuration includes EventBridge rules for critical Istio events:

```hcl
resource "aws_cloudwatch_event_rule" "istio_alerts" {
  name        = "${var.cluster_name}-istio-alerts"
  description = "Alert on Istio service mesh issues"

  event_pattern = jsonencode({
    source      = ["aws.elasticloadbalancing"]
    detail-type = ["ELB Health Check Failed"]
  })
}
```

## Troubleshooting

### Check Istio Sidecar Injection

```bash
# Verify namespace has injection label
kubectl get namespace default --show-labels

# Expected: istio-injection=enabled

# If missing, add the label:
kubectl label namespace default istio-injection=enabled
```

### Verify mTLS Configuration

```bash
# Check peer authentication
kubectl get peerauthentication -n istio-system

# Verify destination rules
kubectl get destinationrule -n istio-system
```

### Debug Traffic Routing

```bash
# Check Istio configuration
istioctl analyze

# View Envoy configuration for a pod
istioctl proxy-config cluster <pod-name> -n default

# Check route configuration
istioctl proxy-config route <pod-name> -n default
```

### View Istio Logs

```bash
# Istiod logs
kubectl logs -n istio-system -l app=istiod

# Ingress gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway

# Sidecar proxy logs for a specific pod
kubectl logs <pod-name> -n default -c istio-proxy
```

## Cost Optimization

### Reduce Observability Stack Costs

If you don't need full observability, disable add-ons:

```hcl
# In terraform.tfvars
enable_istio_addons = false
```

This removes Kiali, Prometheus, Jaeger, and Grafana, reducing costs by ~50%.

### Ingress Gateway Autoscaling

The ingress gateway is configured with HPA:

```hcl
set {
  name  = "autoscaling.enabled"
  value = "true"
}

set {
  name  = "autoscaling.minReplicas"
  value = "2"
}

set {
  name  = "autoscaling.maxReplicas"
  value = "5"
}
```

Adjust these values based on your traffic patterns.

## Security Best Practices

1. **Enforce mTLS everywhere** - Already configured via PeerAuthentication
2. **Use Authorization Policies** - Define which services can communicate
3. **Enable audit logging** - Track all service mesh changes
4. **Regular security updates** - Keep Istio version current
5. **Limit egress traffic** - Use ServiceEntry for external services

### Example Authorization Policy

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-policy
  namespace: default
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/checkoutservice"]
    to:
    - operation:
        methods: ["GET", "POST"]
```

## Cleanup

To remove Istio:

```bash
# Set enable_istio to false
# In terraform.tfvars or via command:
terraform apply -var="enable_istio=false"
```

This will cleanly uninstall all Istio components.

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio on AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/networking/service-mesh/istio/)
- [Kiali Documentation](https://kiali.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
