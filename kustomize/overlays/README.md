# Kustomize Overlays - Multi-Environment Deployment

This directory contains Kustomize overlays for deploying the Online Boutique application to multiple environments (dev, qa, prod) with different configurations.

## Directory Structure

```
kustomize/
├── base/                    # Base Kubernetes manifests (shared across environments)
├── components/              # Reusable kustomize components
│   ├── service-mesh-istio/ # Istio service mesh configuration
│   └── without-loadgenerator/ # Removes load generator
└── overlays/                # Environment-specific configurations
    ├── dev/                 # Development environment
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   └── resourcequota.yaml
    ├── qa/                  # QA/Testing environment
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   └── resourcequota.yaml
    └── prod/                # Production environment
        ├── kustomization.yaml
        ├── namespace.yaml
        └── resourcequota.yaml
```

## Environment Specifications

### Development (dev)

**Namespace**: `microservices-dev`

**Configuration**:
- **Replicas**: 1 per service
- **Load Generator**: Disabled
- **Image Tag**: `dev`
- **Resource Limits**:
  - Namespace CPU: 10 cores request, 20 cores limit
  - Namespace Memory: 20Gi request, 40Gi limit
  - Max pods: 50
  - Per-container defaults: 200m CPU / 256Mi memory

**Use Cases**:
- Active development
- Feature testing
- Integration testing
- Developer sandboxes

### QA (qa)

**Namespace**: `microservices-qa`

**Configuration**:
- **Replicas**: 2 per service
- **Load Generator**: Enabled (1 replica)
- **Image Tag**: `qa`
- **Resource Limits**:
  - Namespace CPU: 15 cores request, 30 cores limit
  - Namespace Memory: 30Gi request, 60Gi limit
  - Max pods: 75
  - Per-container defaults: 500m CPU / 512Mi memory

**Use Cases**:
- Quality assurance testing
- Performance testing
- Load testing
- UAT (User Acceptance Testing)
- Integration testing

### Production (prod)

**Namespace**: `microservices-prod`

**Configuration**:
- **Replicas**: 3 per service (High Availability)
- **Load Generator**: Disabled
- **Image Tag**: `prod`
- **Resource Limits**:
  - Namespace CPU: 30 cores request, 60 cores limit
  - Namespace Memory: 60Gi request, 120Gi limit
  - Max pods: 100
  - Per-container defaults: 1 core CPU / 1Gi memory

**Use Cases**:
- Live production traffic
- Customer-facing application
- High availability required

## Deployment Instructions

### Prerequisites

1. **Tools Required**:
   ```bash
   kubectl version --client  # >= 1.27
   kustomize version         # >= 5.0 (or use kubectl kustomize)
   ```

2. **AWS EKS Cluster** deployed via Terraform
3. **kubectl configured** for your EKS cluster:
   ```bash
   aws eks update-kubeconfig --region eu-west-2 --name microservices-dev
   ```

4. **Istio** installed (via Terraform or manually)

### Deploy to Development

```bash
# From repository root
cd kustomize

# Preview what will be deployed
kubectl kustomize overlays/dev

# Deploy to dev namespace
kubectl apply -k overlays/dev

# Verify deployment
kubectl get pods -n microservices-dev
kubectl get svc -n microservices-dev
```

### Deploy to QA

```bash
# Preview QA deployment
kubectl kustomize overlays/qa

# Deploy to QA namespace
kubectl apply -k overlays/qa

# Verify deployment
kubectl get pods -n microservices-qa
kubectl get all -n microservices-qa
```

### Deploy to Production

```bash
# Preview production deployment
kubectl kustomize overlays/prod

# Deploy to production namespace
kubectl apply -k overlays/prod

# Verify deployment
kubectl get pods -n microservices-prod
kubectl get all -n microservices-prod

# Check Istio injection
kubectl get pods -n microservices-prod -o jsonpath='{.items[*].spec.containers[*].name}'
# Should show both 'server' and 'istio-proxy'
```

## Accessing Applications

### Get Service URLs

Each environment has its own Istio Gateway and VirtualService:

```bash
# Development
kubectl get svc istio-ingressgateway -n istio-system

# The frontend service is accessed via Istio Gateway
# Get the NLB hostname
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Dev URL: http://$INGRESS_HOST"
```

**Note**: Since all environments share the same Istio ingress gateway, you need to configure VirtualServices with host-based routing or use different ingress gateways per environment.

### Port Forwarding (For Testing)

```bash
# Port forward to frontend service in dev
kubectl port-forward -n microservices-dev svc/frontend 8080:80

# Access at http://localhost:8080
```

## Environment-Specific Image Management

### Using Environment-Specific Tags

Images are tagged per environment in the kustomization files:

**Dev**: Uses `dev` tag
```yaml
images:
- name: frontend
  newTag: dev
```

**QA**: Uses `qa` tag
```yaml
images:
- name: frontend
  newTag: qa
```

**Prod**: Uses `prod` tag or semantic version
```yaml
images:
- name: frontend
  newTag: v1.2.3  # Or 'prod' for latest stable
```

### Updating Image Tags

To update images in an environment:

```bash
# Option 1: Edit kustomization.yaml
cd overlays/prod
# Edit kustomization.yaml, change newTag values
kubectl apply -k .

# Option 2: Use kustomize edit
cd overlays/prod
kustomize edit set image frontend=frontend:v1.2.3
kubectl apply -k .

# Option 3: Use kubectl set image
kubectl set image deployment/frontend \
  server=<ECR_URL>/frontend:v1.2.3 \
  -n microservices-prod
```

## Managing Resources

### Scaling Deployments

Replicas are defined in the overlay kustomization files via patches. To change:

**Temporary (runtime only)**:
```bash
kubectl scale deployment frontend --replicas=5 -n microservices-prod
```

**Permanent (via kustomize)**:
Edit `overlays/prod/kustomization.yaml`:
```yaml
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: frontend
    spec:
      replicas: 5  # Changed from 3 to 5
  target:
    kind: Deployment
    name: frontend
```

Then apply:
```bash
kubectl apply -k overlays/prod
```

### Resource Quotas

Each environment has resource quotas to prevent over-consumption:

```bash
# Check resource quota usage
kubectl describe resourcequota -n microservices-dev
kubectl describe limitrange -n microservices-dev

# View current resource usage
kubectl top nodes
kubectl top pods -n microservices-dev
```

## Troubleshooting

### Common Issues

**1. Pods Stuck in Pending**
```bash
# Check resource quota
kubectl describe resourcequota -n microservices-dev

# Check pod events
kubectl describe pod <pod-name> -n microservices-dev

# Possible causes:
# - Resource quota exceeded
# - Insufficient cluster resources
# - Image pull errors
```

**2. Namespace Already Exists**
```bash
# If namespace exists without Istio injection label
kubectl label namespace microservices-dev istio-injection=enabled --overwrite
```

**3. Kustomize Build Errors**
```bash
# Validate kustomize configuration
kubectl kustomize overlays/dev --enable-helm

# Check for syntax errors
kustomize build overlays/dev
```

**4. Image Pull Errors**
```bash
# Verify images exist in ECR
aws ecr describe-images --repository-name frontend --region eu-west-2

# Check ImagePullSecrets if using private registry
kubectl get secrets -n microservices-dev
```

**5. Istio Sidecar Not Injected**
```bash
# Check namespace label
kubectl get namespace microservices-dev --show-labels

# Verify Istio is installed
kubectl get pods -n istio-system

# Restart deployment to inject sidecar
kubectl rollout restart deployment/frontend -n microservices-dev
```

## Advanced Configurations

### Using Different ECR Repositories

To use different ECR repositories per environment:

Edit `overlays/<env>/kustomization.yaml`:
```yaml
images:
- name: frontend
  newName: 123456789012.dkr.ecr.eu-west-2.amazonaws.com/frontend
  newTag: v1.2.3
```

### Adding HorizontalPodAutoscaler

Create `overlays/prod/hpa.yaml`:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

Add to `overlays/prod/kustomization.yaml`:
```yaml
resources:
- hpa.yaml
```

### Adding PodDisruptionBudget

For production high availability, add PDB:

Create `overlays/prod/pdb.yaml`:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: frontend
```

### Environment-Specific ConfigMaps

Create environment-specific configuration:

`overlays/prod/configmap.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  FEATURE_FLAG_X: "enabled"
```

Add to `overlays/prod/kustomization.yaml`:
```yaml
resources:
- configmap.yaml

configMapGenerator:
- name: env-config
  literals:
  - ENVIRONMENT=production
  - DEBUG=false
```

## Promoting Between Environments

### Dev → QA Promotion

1. **Test in Dev**:
   ```bash
   kubectl apply -k overlays/dev
   # Run tests
   ```

2. **Update QA images**:
   ```bash
   cd overlays/qa
   # Update newTag in kustomization.yaml to tested version
   vi kustomization.yaml
   ```

3. **Deploy to QA**:
   ```bash
   kubectl apply -k overlays/qa
   ```

4. **Verify**:
   ```bash
   kubectl get pods -n microservices-qa
   kubectl logs -l app=frontend -n microservices-qa
   ```

### QA → Prod Promotion

1. **QA Testing Complete**:
   ```bash
   # Run full test suite in QA
   kubectl get pods -n microservices-qa
   ```

2. **Update Prod Configuration**:
   ```bash
   cd overlays/prod
   # Update image tags to QA-tested versions
   vi kustomization.yaml
   ```

3. **Deploy to Prod** (with caution):
   ```bash
   # Review changes
   kubectl diff -k overlays/prod

   # Apply changes
   kubectl apply -k overlays/prod

   # Watch rollout
   kubectl rollout status deployment/frontend -n microservices-prod
   ```

4. **Monitor**:
   ```bash
   # Check pod health
   kubectl get pods -n microservices-prod

   # Check Istio metrics
   kubectl port-forward -n istio-system svc/kiali-server 20001:20001
   # Open http://localhost:20001
   ```

## Rollback Procedures

### Quick Rollback

```bash
# Rollback to previous deployment
kubectl rollout undo deployment/frontend -n microservices-prod

# Rollback to specific revision
kubectl rollout history deployment/frontend -n microservices-prod
kubectl rollout undo deployment/frontend --to-revision=2 -n microservices-prod
```

### Full Environment Rollback

```bash
# Revert to previous kustomization
git checkout HEAD~1 overlays/prod/kustomization.yaml
kubectl apply -k overlays/prod

# Or use git tag
git checkout v1.0.0
kubectl apply -k overlays/prod
```

## Cleanup

### Delete Specific Environment

```bash
# Delete dev environment
kubectl delete -k overlays/dev

# Or delete namespace (removes everything)
kubectl delete namespace microservices-dev
```

### Delete All Environments

```bash
kubectl delete -k overlays/dev
kubectl delete -k overlays/qa
kubectl delete -k overlays/prod
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Deploy to Dev
  run: |
    aws eks update-kubeconfig --region eu-west-2 --name microservices-dev
    kubectl apply -k kustomize/overlays/dev

- name: Deploy to QA
  if: github.ref == 'refs/heads/main'
  run: |
    aws eks update-kubeconfig --region eu-west-2 --name microservices-qa
    kubectl apply -k kustomize/overlays/qa

- name: Deploy to Prod
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    aws eks update-kubeconfig --region eu-west-2 --name microservices-prod
    kubectl apply -k kustomize/overlays/prod
```

### Using Justfile

Add to project `justfile`:
```bash
# Deploy to specific environment
deploy-kustomize env:
    kubectl apply -k kustomize/overlays/{{env}}

# Deploy to all environments
deploy-all-kustomize:
    just deploy-kustomize dev
    just deploy-kustomize qa
    just deploy-kustomize prod
```

## Best Practices

1. **Never edit base manifests** - Use overlays for customizations
2. **Use semantic versioning** for production image tags
3. **Test in dev before promoting** to higher environments
4. **Keep resource quotas** to prevent resource exhaustion
5. **Use HPA in production** for auto-scaling
6. **Enable Istio injection** on all namespaces
7. **Monitor resource usage** regularly
8. **Document environment-specific changes** in commit messages
9. **Use PodDisruptionBudgets** in production for HA
10. **Regular review** of resource limits and quotas

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Istio Multi-Tenancy](https://istio.io/latest/docs/ops/deployment/deployment-models/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
