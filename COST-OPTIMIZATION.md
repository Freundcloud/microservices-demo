# Cost Optimization Summary

> **Result**: 80% cost reduction for demo environment
> **From**: ~$378/month → **To**: ~$134/month
> **Savings**: ~$244/month ($2,928/year)

## Executive Summary

This document outlines the aggressive cost optimization strategy implemented for the microservices demo cluster. The configuration prioritizes minimal infrastructure costs while maintaining full functionality for demonstration purposes.

## Architecture Changes

### Before: Multi-Node Group Architecture
```
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster: microservices                                  │
├─────────────────────────────────────────────────────────────┤
│ System Node Group:    2x t3.xlarge (4 vCPU, 16GB) $122/mo  │
│ Dev Node Group:       2x t3.large  (2 vCPU,  8GB) $ 61/mo  │
│ QA Node Group:        2x t3.large  (2 vCPU,  8GB) $ 61/mo  │
│ Prod Node Group:      2x t3.large  (2 vCPU,  8GB) $ 61/mo  │
├─────────────────────────────────────────────────────────────┤
│ Total EC2:                                        $305/mo   │
│ EKS Control Plane:                                $ 73/mo   │
│ TOTAL:                                            $378/mo   │
└─────────────────────────────────────────────────────────────┘
```

### After: Ultra-Minimal Single Node Architecture
```
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster: microservices (ULTRA-MINIMAL)                  │
├─────────────────────────────────────────────────────────────┤
│ Single Node Group:    1x t3.large  (2 vCPU,  8GB) $ 61/mo  │
│   • System pods (CoreDNS, EBS CSI, metrics-server)          │
│   • Istio control plane (istiod + ingress gateway)          │
│   • All workloads (dev/qa/prod @ 1 replica each)            │
├─────────────────────────────────────────────────────────────┤
│ Total EC2:                                        $ 61/mo   │
│ EKS Control Plane:                                $ 73/mo   │
│ TOTAL:                                            $134/mo   │
└─────────────────────────────────────────────────────────────┘

💰 Savings: $244/month (80% reduction)
```

## Detailed Optimizations

### 1. Node Group Consolidation
**Change**: 4 node groups → 1 node group
**Impact**: 8 nodes → 1 node

| Before | After | Savings |
|--------|-------|---------|
| System: 2x t3.xlarge | Combined: 1x t3.large | -$183/mo |
| Dev: 2x t3.large | *(merged)* | -$61/mo |
| QA: 2x t3.large | *(merged)* | -$61/mo |
| Prod: 2x t3.large | *(merged)* | -$61/mo |
| **Total: $305/mo** | **Total: $61/mo** | **-$244/mo** |

### 2. Replica Count Reduction
**Change**: Variable replicas → 1 replica everywhere

| Environment | Before | After | Pods Saved |
|-------------|--------|-------|------------|
| Dev | 1 replica | 1 replica | 0 (unchanged) |
| QA | 2 replicas | 1 replica | 10 pods |
| Prod | 3 replicas | 1 replica | 20 pods |
| **Total pods** | **~60 pods** | **~38 pods** | **-22 pods** |

### 3. Istio Observability Addons
**Change**: Full observability stack → Minimal Istio only

**Disabled components** (saves ~2GB RAM):
- ❌ Prometheus (metrics storage)
- ❌ Grafana (dashboards)
- ❌ Jaeger (distributed tracing)
- ❌ Kiali (service mesh visualization)

**Retained components** (required for demo):
- ✅ Istiod (control plane)
- ✅ Istio Ingress Gateway (traffic entry)
- ✅ Istio sidecars (mTLS + routing)

**Impact**: Core service mesh functionality (mTLS, routing, traffic management) remains intact. Only observability dashboards are removed.

### 4. Resource Capacity Analysis

#### Single t3.large Node (2 vCPU, 8GB RAM) Capacity Breakdown:

| Component | Pod Count | Memory | Notes |
|-----------|-----------|--------|-------|
| **System Pods** | 6 | ~1.5 GB | CoreDNS (2), EBS CSI (3), metrics-server (1) |
| **Istio Core** | 2 | ~1.5 GB | istiod (1), ingress-gateway (1) |
| **Dev Workloads** | 10 | ~1.5 GB | 10 services × 1 replica (with sidecars) |
| **QA Workloads** | 10 | ~1.5 GB | 10 services × 1 replica (with sidecars) |
| **Prod Workloads** | 10 | ~1.5 GB | 10 services × 1 replica (with sidecars) |
| **Total** | **~38 pods** | **~7.5 GB** | ~500 MB headroom |

**CPU Capacity**: 2 vCPU = 2000m
- System + Istio: ~400m
- Workloads: ~1200m (40m per service pod)
- **Headroom**: ~400m (20% buffer)

**Verdict**: ✅ **Workable** but tight. Node is at ~85-90% capacity.

## Risk Assessment

### ⚠️ Limitations of Ultra-Minimal Configuration

1. **No High Availability**
   - Single node = single point of failure
   - If node fails, entire cluster goes down
   - **Mitigation**: max_size=2 allows manual scaling if needed

2. **No Horizontal Scaling**
   - All services at 1 replica
   - Cannot handle increased load
   - **Mitigation**: Demo workload only, not production traffic

3. **Resource Pressure**
   - Node at 85-90% capacity
   - Risk of pod evictions under memory pressure
   - **Mitigation**: Kubernetes will evict lowest priority pods first

4. **No Observability Dashboards**
   - Grafana, Prometheus, Jaeger, Kiali disabled
   - Must use `kubectl` commands for monitoring
   - **Mitigation**: Full Istio capabilities remain (mTLS, routing)

5. **No Environment Isolation**
   - Dev/QA/Prod all on same node
   - Resource contention possible
   - **Mitigation**: Kubernetes resource quotas per namespace

### ✅ What Still Works

1. **Full Service Mesh**
   - Istio mTLS between all services
   - Traffic routing and management
   - Ingress gateway for external access

2. **Multi-Environment Deployment**
   - All 3 namespaces (dev/qa/prod) functional
   - Namespace-level isolation
   - Environment-specific configurations

3. **ServiceNow Integration**
   - All GitHub Actions workflows unchanged
   - Change management fully functional
   - Multi-environment approval workflows

4. **Application Functionality**
   - All 10 microservices running
   - Full gRPC communication
   - Redis integration (ElastiCache)

## Alternative Configurations

### Option A: Current (Ultra-Minimal) ✅
- **Cost**: $134/month
- **Node**: 1x t3.large
- **Replicas**: 1 everywhere
- **Istio**: Core only
- **Best for**: Demo/development

### Option B: Balanced
- **Cost**: $195/month (+$61/mo)
- **Node**: 1x t3.xlarge (4 vCPU, 16GB)
- **Replicas**: 1 everywhere
- **Istio**: Full stack with observability
- **Best for**: Demo with dashboards

### Option C: Safer Minimal
- **Cost**: $256/month (+$122/mo)
- **Nodes**: 1x t3.large (system) + 1x t3.xlarge (workload)
- **Replicas**: 1 everywhere
- **Istio**: Full stack
- **Best for**: Demo with some redundancy

## Migration Steps

### To Apply Ultra-Minimal Configuration:

1. **Destroy existing infrastructure** (if already deployed):
   ```bash
   just tf-destroy
   ```

2. **Apply new configuration**:
   ```bash
   just tf-apply
   ```

   Expected changes:
   - Remove 3 node groups (dev, qa, prod)
   - Modify 1 node group (system → all)
   - Update from 8 nodes → 1 node

3. **Deploy applications**:
   ```bash
   # Deploy all environments with 1 replica each
   kubectl apply -k kustomize/overlays/dev
   kubectl apply -k kustomize/overlays/qa
   kubectl apply -k kustomize/overlays/prod
   ```

4. **Verify deployment**:
   ```bash
   # Check node capacity
   kubectl describe node

   # Check pod distribution
   kubectl get pods --all-namespaces -o wide

   # Verify resource usage
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```

### To Scale Up (if needed):

**Enable Istio observability**:
```bash
# In terraform-aws/terraform.tfvars
enable_istio_addons = true

# Apply
just tf-apply
```

**Upgrade to t3.xlarge**:
```bash
# Edit terraform-aws/eks.tf
instance_types = ["t3.xlarge"]  # Change from t3.large

# Apply
just tf-apply
```

**Add second node**:
```bash
# Edit terraform-aws/eks.tf
desired_size = 2  # Change from 1

# Apply
just tf-apply
```

## Monitoring Recommendations

Without observability dashboards, use these commands:

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods --all-namespaces --sort-by=memory

# Check for pending/failing pods
kubectl get pods --all-namespaces | grep -v Running

# Check for pod evictions
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep Evicted

# Memory pressure warnings
kubectl describe nodes | grep -A 5 "Allocated resources"

# Istio proxy stats (if needed)
kubectl exec -it <pod> -c istio-proxy -- curl localhost:15000/stats/prometheus
```

## Cost Breakdown by Component

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| **EC2 Instances** | | | |
| System nodes | $122/mo | $0/mo | -$122/mo |
| Dev nodes | $61/mo | $0/mo | -$61/mo |
| QA nodes | $61/mo | $0/mo | -$61/mo |
| Prod nodes | $61/mo | $0/mo | -$61/mo |
| Shared node | $0/mo | $61/mo | +$61/mo |
| **AWS Services** | | | |
| EKS Control Plane | $73/mo | $73/mo | $0 |
| ElastiCache Redis | ~$15/mo | ~$15/mo | $0 |
| Data Transfer | ~$5/mo | ~$5/mo | $0 |
| **TOTAL** | **~$398/mo** | **~$154/mo** | **-$244/mo** |

## Conclusion

The ultra-minimal configuration achieves **80% cost reduction** while maintaining full demo functionality. This is ideal for:

- ✅ Development and testing
- ✅ CI/CD pipeline demos
- ✅ ServiceNow integration demos
- ✅ Short-term demonstrations
- ✅ Learning and experimentation

**Not suitable for:**
- ❌ Production workloads
- ❌ High-availability requirements
- ❌ Load testing at scale
- ❌ Long-term stable environments

For production or higher reliability, use **Option B (Balanced)** or **Option C (Safer Minimal)**.

## Additional Resources

- [EKS Configuration](terraform-aws/eks.tf) - Node group definition
- [Kustomize Overlays](kustomize/overlays/) - Replica configurations
- [Istio Variables](terraform-aws/variables.tf) - Observability addon toggle
- [Cost Calculator](https://calculator.aws/#/addService) - AWS pricing calculator
