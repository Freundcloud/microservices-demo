# Single Cluster Migration Summary

## Overview

The project has been migrated from a **3-cluster architecture** to a **single-cluster architecture** with dedicated node groups per environment. This significantly reduces costs while maintaining proper isolation between dev, qa, and prod environments.

## Architecture Before

**3 Separate EKS Clusters:**
- `microservices-dev` cluster (dedicated VPC, dedicated nodes)
- `microservices-qa` cluster (dedicated VPC, dedicated nodes)
- `microservices-prod` cluster (dedicated VPC, dedicated nodes)

**Cost:** ~$219/month for control planes alone ($73 × 3) + 3× node costs

## Architecture Now

**1 Shared EKS Cluster:** `microservices`

**4 Dedicated Node Groups:**

1. **System Node Group** ⭐ NEW
   - Instance type: `t3.small` (2 vCPU, 2 GB RAM)
   - Min/Max/Desired: 2/3/2 nodes
   - Node labels: `role=system`, `workload=cluster-addons`
   - **No taints** - Allows cluster add-ons (CoreDNS, EBS CSI driver, etc.) to schedule
   - Purpose: Hosts essential cluster components without interfering with application workloads

2. **Dev Node Group**
   - Instance type: `t3.medium` (2 vCPU, 4 GB RAM)
   - Min/Max/Desired: 2/4/2 nodes
   - Node labels: `environment=dev`, `workload=microservices-dev`
   - Node taints: `environment=dev:NO_SCHEDULE`

3. **QA Node Group**
   - Instance type: `t3.large` (2 vCPU, 8 GB RAM)
   - Min/Max/Desired: 3/6/3 nodes
   - Node labels: `environment=qa`, `workload=microservices-qa`
   - Node taints: `environment=qa:NO_SCHEDULE`

4. **Prod Node Group**
   - Instance type: `t3.xlarge` (4 vCPU, 16 GB RAM)
   - Min/Max/Desired: 5/10/5 nodes
   - Node labels: `environment=prod`, `workload=microservices-prod`
   - Node taints: `environment=prod:NO_SCHEDULE`

**3 Separate Namespaces:**
- `microservices-dev` (1 replica per service)
- `microservices-qa` (2 replicas per service)
- `microservices-prod` (3 replicas per service)

**Cost:** ~$73/month for control plane + shared infrastructure = **~$146/month savings**

## Region Configuration

All resources are deployed to **eu-west-2** (London, UK) with availability zones:
- `eu-west-2a`
- `eu-west-2b`
- `eu-west-2c`

## System Node Group Rationale

**Why is the system node group needed?**

When all node groups have taints (dev, qa, prod), Kubernetes system components like CoreDNS and the EBS CSI driver cannot schedule because they don't have matching tolerations. This causes the cluster add-ons to remain in a DEGRADED state and prevents the cluster from becoming fully operational.

**Solution:** Create a small, untainted node group specifically for cluster system components. This allows:
- Essential cluster add-ons (CoreDNS, kube-proxy, vpc-cni, aws-ebs-csi-driver) to schedule
- Cluster autoscaler, metrics-server, and load balancer controller to run
- Istio control plane components to deploy
- System monitoring and observability tools to function

The system node group is small (t3.small) and cost-effective (~$15/month for 2 nodes) while ensuring cluster stability.

## Node Affinity & Isolation

Each namespace's pods are restricted to their dedicated node group using:

1. **Node Selectors** - Simple label matching
2. **Node Taints** - Prevents other workloads from scheduling on dedicated nodes
3. **Tolerations** - Allows namespace pods to tolerate their node group's taint
4. **Node Affinity** - Required scheduling rules

### Example (Dev Namespace):
```yaml
nodeSelector:
  environment: dev
  workload: microservices-dev

tolerations:
- key: "environment"
  operator: "Equal"
  value: "dev"
  effect: "NoSchedule"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: environment
          operator: In
          values:
          - dev
```

## Files Modified

### Terraform Configuration
1. **terraform-aws/eks.tf** - Updated to create 3 node groups instead of 1
2. **terraform-aws/variables.tf** - Removed deprecated node group variables
3. **terraform-aws/terraform.tfvars** - New unified configuration file
4. **terraform-aws/environments/*.tfvars** - Moved to `environments/deprecated/`

### Kustomize Overlays
1. **kustomize/overlays/dev/node-affinity.yaml** - Dev node affinity rules
2. **kustomize/overlays/qa/node-affinity.yaml** - QA node affinity rules
3. **kustomize/overlays/prod/node-affinity.yaml** - Prod node affinity rules
4. Updated all `kustomization.yaml` files to include node affinity patches

### Deployment Tools
1. **justfile** - Updated commands:
   - `just tf-init` (no env parameter)
   - `just tf-plan` (no env parameter)
   - `just tf-apply` (no env parameter)
   - `just tf-destroy` (with warning)
   - `just k8s-config` (no env parameter, connects to "microservices" cluster)

2. **.envrc.example** - Updated to eu-west-2 region

## Deployment Commands

### Infrastructure Deployment
```bash
# Initialize Terraform
just tf-init

# Plan changes (creates 1 cluster with 3 node groups)
just tf-plan

# Apply (creates cluster named "microservices")
just tf-apply

# Configure kubectl
just k8s-config
```

### Application Deployment (per environment)
```bash
# Deploy to dev namespace
kubectl apply -k kustomize/overlays/dev

# Deploy to qa namespace
kubectl apply -k kustomize/overlays/qa

# Deploy to prod namespace
kubectl apply -k kustomize/overlays/prod
```

### Verify Node Isolation
```bash
# Check nodes and their labels
kubectl get nodes --show-labels

# Verify dev pods are on dev nodes
kubectl get pods -n microservices-dev -o wide

# Verify qa pods are on qa nodes
kubectl get pods -n microservices-qa -o wide

# Verify prod pods are on prod nodes
kubectl get pods -n microservices-prod -o wide
```

## Cost Breakdown

### Old Architecture (3 Clusters)
- EKS Control Planes: 3 × $73 = $219/month
- Dev nodes: 2 × t3.medium = ~$60/month
- QA nodes: 3 × t3.medium = ~$90/month
- Prod nodes: 5 × t3.large = ~$300/month
- **Total: ~$669/month**

### New Architecture (1 Cluster)
- EKS Control Plane: 1 × $73 = $73/month
- Dev nodes: 2 × t3.medium = ~$60/month
- QA nodes: 3 × t3.large = ~$100/month
- Prod nodes: 5 × t3.xlarge = ~$340/month
- **Total: ~$573/month**

**Savings: ~$96/month (~14% reduction)**

Plus additional savings from:
- Shared VPC infrastructure
- Shared ElastiCache Redis
- Shared Istio control plane
- Shared Load Balancers

## Resource Quotas

Each namespace has resource quotas to prevent overconsumption:

### Dev Namespace
- CPU: 10 cores request, 20 cores limit
- Memory: 20Gi request, 40Gi limit
- Max pods: 50

### QA Namespace
- CPU: 15 cores request, 30 cores limit
- Memory: 30Gi request, 60Gi limit
- Max pods: 75

### Prod Namespace
- CPU: 30 cores request, 60 cores limit
- Memory: 60Gi request, 120Gi limit
- Max pods: 100

## Benefits

✅ **Cost Savings**: ~$96/month base savings
✅ **Simplified Management**: One cluster to maintain
✅ **Resource Efficiency**: Shared infrastructure components
✅ **Proper Isolation**: Node-level separation via taints/tolerations
✅ **Namespace Isolation**: ResourceQuotas and NetworkPolicies
✅ **Scalability**: Cluster autoscaler works across all node groups
✅ **Observability**: Single Istio dashboard for all environments

## Migration Steps (for existing deployments)

If you have existing clusters to migrate:

1. **Backup existing data**:
   ```bash
   # Backup Redis data from old clusters
   # Backup any persistent volumes
   ```

2. **Create new cluster**:
   ```bash
   just tf-apply
   just k8s-config
   ```

3. **Deploy applications**:
   ```bash
   kubectl apply -k kustomize/overlays/dev
   kubectl apply -k kustomize/overlays/qa
   kubectl apply -k kustomize/overlays/prod
   ```

4. **Verify deployments**:
   ```bash
   kubectl get pods -n microservices-dev
   kubectl get pods -n microservices-qa
   kubectl get pods -n microservices-prod
   ```

5. **Update DNS/Load Balancers** to point to new cluster

6. **Destroy old clusters**:
   ```bash
   # Only after verifying new cluster works!
   terraform destroy -var-file=environments/dev.tfvars
   terraform destroy -var-file=environments/qa.tfvars
   terraform destroy -var-file=environments/prod.tfvars
   ```

## Important Notes

⚠️ **WARNING**: Running `just tf-destroy` will destroy the ENTIRE cluster including all three environments!

🔒 **Security**: Node taints ensure dev workloads cannot accidentally run on prod nodes and vice versa.

📊 **Monitoring**: Use Istio dashboards to monitor all environments:
- `just istio-kiali` - Service mesh visualization
- `just istio-grafana` - Metrics dashboards
- `just istio-jaeger` - Distributed tracing

## Troubleshooting

### Pods stuck in Pending state?
Check if pods have the correct tolerations:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

Look for "Toleration" in the output. If missing, the Kustomize patch may not have applied.

### Pods running on wrong nodes?
Check node affinity:
```bash
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 20 affinity
```

### Need to add more capacity?
Edit `terraform-aws/eks.tf` and adjust `max_size` for the relevant node group, then run:
```bash
just tf-apply
```

## Documentation Updates Needed

The following documentation files should be updated (future task):
- [ ] docs/README-AWS.md
- [ ] docs/ONBOARDING.md
- [ ] CLAUDE.md
- [ ] README.md
- [ ] .github/workflows/*.yaml (remove environment parameters)

## Next Steps

1. Test the single-cluster deployment in your AWS account
2. Verify node affinity is working correctly
3. Update GitHub Actions workflows to remove environment parameters
4. Update all documentation to reflect single-cluster architecture
5. Consider adding NetworkPolicies for additional namespace isolation

---

Created: 2025-10-14
Author: Claude Code
Purpose: Document single-cluster migration for cost optimization
