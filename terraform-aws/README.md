# AWS EKS Deployment for Online Boutique

This directory contains Terraform configuration to deploy the Online Boutique microservices application on Amazon Web Services (AWS) using Elastic Kubernetes Service (EKS).

## Architecture Overview

This Terraform configuration creates:

- **Amazon EKS Cluster** - Managed Kubernetes cluster
- **VPC with Public/Private Subnets** - Network isolation across 3 availability zones
- **ElastiCache for Redis** - Managed Redis cache for cart service
- **Application Load Balancer** - Ingress for frontend service
- **IAM Roles & Policies** - Secure service authentication via IRSA
- **Auto Scaling** - Cluster autoscaler for dynamic scaling
- **CloudWatch Integration** - Logging and monitoring

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** >= 1.5.0 installed
   ```bash
   terraform version
   ```
4. **kubectl** installed
   ```bash
   kubectl version --client
   ```
5. **IAM Permissions** for:
   - EC2, VPC, EKS
   - ElastiCache
   - IAM roles and policies
   - CloudWatch Logs

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired configuration:

```hcl
aws_region  = "eu-west-2"
environment = "demo"
cluster_name = "online-boutique"
enable_redis = true
```

### 2. Initialize Terraform

```bash
terraform init
```

This will download the required Terraform providers and modules.

### 3. Review the Plan

```bash
terraform plan
```

Review the resources that will be created. Expected resources: ~60 resources.

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm. Deployment takes approximately 15-20 minutes.

### 5. Configure kubectl

After deployment completes, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region eu-west-2 --name online-boutique
```

Verify connectivity:

```bash
kubectl get nodes
```

### 6. Deploy the Application

Deploy the Online Boutique microservices:

```bash
kubectl apply -f ../release/kubernetes-manifests.yaml
```

Wait for all pods to be running:

```bash
kubectl get pods
```

### 7. Access the Application

Create an Ingress for the frontend service:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF
```

Get the Application Load Balancer URL:

```bash
kubectl get ingress frontend-ingress
```

Wait a few minutes for the ALB to provision, then access the application at the ALB DNS name.

## Configuration Options

### Cost Optimization

For development/demo environments, use these settings in `terraform.tfvars`:

```hcl
single_nat_gateway      = true   # Use single NAT gateway (saves ~$32/month)
node_instance_types     = ["t3.medium"]
node_group_desired_size = 2
redis_node_type         = "cache.t3.micro"
```

### Production Configuration

For production workloads:

```hcl
single_nat_gateway      = false  # NAT gateway per AZ for HA
node_instance_types     = ["t3.large"]
node_group_desired_size = 3
node_group_min_size     = 3
node_group_max_size     = 10
redis_node_type         = "cache.t3.small"
redis_num_cache_nodes   = 2
```

## ElastiCache Redis Integration

The cart service is configured to use ElastiCache Redis. The connection details are automatically injected via:

- **Kubernetes Secret**: `redis-connection`
- **ConfigMap**: `redis-config`

Update the cartservice deployment to use ElastiCache:

```yaml
env:
- name: REDIS_ADDR
  valueFrom:
    configMapKeyRef:
      name: redis-config
      key: REDIS_ADDR
```

## Monitoring & Logging

### CloudWatch Container Insights

Enable Container Insights for the cluster:

```bash
aws eks update-cluster-config \
  --region eu-west-2 \
  --name online-boutique \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### View Logs

```bash
# View all logs for a pod
kubectl logs -f <pod-name>

# View logs in CloudWatch Logs
aws logs tail /aws/eks/online-boutique/cluster --follow
```

## Scaling

### Manual Scaling

Scale node group:

```bash
# Update desired size in terraform.tfvars
node_group_desired_size = 5

terraform apply
```

### Automatic Scaling

The cluster autoscaler is installed by default and will automatically:
- Scale up when pods can't be scheduled
- Scale down when nodes are underutilized

## Maintenance

### Update EKS Cluster Version

1. Update `cluster_version` in `terraform.tfvars`
2. Run `terraform apply`
3. Wait for nodes to be updated (rolling update)

### Update Node AMI

Managed node groups automatically update to the latest AMI. To force an update:

```bash
terraform apply -replace='module.eks.eks_managed_node_groups["default"]'
```

## Security

### Security Features Enabled

- ✅ Private subnets for worker nodes
- ✅ Security groups with minimal required access
- ✅ IMDSv2 enforced on EC2 instances
- ✅ VPC Flow Logs enabled
- ✅ CloudWatch Logs for audit trail
- ✅ IAM Roles for Service Accounts (IRSA)
- ✅ Encryption at rest for EBS volumes

### Best Practices

1. **Use AWS Secrets Manager** for sensitive data
2. **Enable Pod Security Standards** in Kubernetes
3. **Regular security patching** via automated updates
4. **Network policies** to restrict pod-to-pod communication
5. **Audit logs** review via CloudWatch

## Cost Estimation

### Monthly Costs (Approximate)

| Resource | Configuration | Cost |
|----------|--------------|------|
| EKS Control Plane | 1 cluster | $72 |
| EC2 Nodes | 3x t3.medium | $90 |
| NAT Gateway | 1 gateway | $32 |
| ElastiCache | 1x cache.t3.micro | $15 |
| Application Load Balancer | 1 ALB | $20 |
| Data Transfer | Typical usage | $10 |
| CloudWatch Logs | Standard retention | $10 |
| **Total** | | **~$249/month** |

*Note: Costs may vary based on usage, region, and AWS pricing changes.*

### Cost Optimization Tips

1. Use Spot Instances for non-production workloads
2. Enable cluster autoscaler to scale down during low traffic
3. Use single NAT gateway for dev/test environments
4. Set CloudWatch Logs retention to 7 days for dev
5. Use Savings Plans or Reserved Instances for predictable workloads

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
```

### Cannot Access Application

```bash
# Check ingress
kubectl get ingress
kubectl describe ingress frontend-ingress

# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Redis Connection Issues

```bash
# Verify Redis cluster
aws elasticache describe-cache-clusters --region eu-west-2

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*redis*"

# Test connection from pod
kubectl run -it --rm debug --image=redis:7.0 --restart=Never -- redis-cli -h <redis-endpoint> ping
```

## Cleanup

To destroy all resources:

```bash
# Delete the application first
kubectl delete -f ../release/kubernetes-manifests.yaml

# Delete the Ingress
kubectl delete ingress frontend-ingress

# Wait a few minutes for ALB to be deleted

# Destroy Terraform resources
terraform destroy
```

Type `yes` when prompted. Cleanup takes approximately 10-15 minutes.

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ElastiCache for Redis](https://docs.aws.amazon.com/elasticache/redis/)

## Support

For issues related to:
- **Infrastructure**: Check Terraform logs and AWS CloudWatch
- **Application**: Review application logs via `kubectl logs`
- **Networking**: Verify security groups and VPC configuration

## Contributing

Contributions are welcome! Please:
1. Test changes thoroughly
2. Update documentation
3. Follow Terraform best practices
4. Submit pull requests with clear descriptions

## License

Apache License 2.0 - See LICENSE file for details
