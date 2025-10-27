# Copyright 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Helm Chart Installations using local-exec
# This approach properly inherits AWS credentials from environment variables

# Install AWS Load Balancer Controller
resource "null_resource" "install_alb_controller" {
  count = var.enable_alb_controller ? 1 : 0

  triggers = {
    cluster_version = module.eks.cluster_version
    role_arn        = aws_iam_role.aws_load_balancer_controller[0].arn
    # Removed always_run to prevent unnecessary re-installations on every terraform apply
    # Helm upgrade --install is idempotent and will only update if changes are detected
  }

  provisioner "local-exec" {
    environment = {
      AWS_REGION         = var.aws_region
      AWS_DEFAULT_REGION = var.aws_region
      KUBECONFIG         = pathexpand("~/.kube/config")
    }

    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}

      # Add helm repo
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update

      # Install or upgrade ALB controller
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --version 1.6.2 \
        --set clusterName=${module.eks.cluster_name} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.aws_load_balancer_controller[0].arn} \
        --set region=${var.aws_region} \
        --set vpcId=${module.vpc.vpc_id} \
        --wait
    EOT
  }

  depends_on = [
    module.eks,
    aws_iam_role.aws_load_balancer_controller
  ]
}

# Install Metrics Server
resource "null_resource" "install_metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  triggers = {
    cluster_version = module.eks.cluster_version
    # Removed always_run to prevent unnecessary re-installations on every terraform apply
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}

      # Add helm repo
      helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
      helm repo update

      # Install or upgrade metrics server
      helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --version 3.11.0 \
        --set args[0]=--kubelet-preferred-address-types=InternalIP \
        --wait
    EOT
  }

  depends_on = [module.eks]
}

# Install Cluster Autoscaler
resource "null_resource" "install_cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  triggers = {
    cluster_version = module.eks.cluster_version
    role_arn        = aws_iam_role.cluster_autoscaler[0].arn
    # Removed always_run to prevent unnecessary re-installations on every terraform apply
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}

      # Add helm repo
      helm repo add autoscaler https://kubernetes.github.io/autoscaler
      helm repo update

      # Install or upgrade cluster autoscaler
      helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
        --namespace kube-system \
        --version 9.29.3 \
        --set autoDiscovery.clusterName=${module.eks.cluster_name} \
        --set awsRegion=${var.aws_region} \
        --set rbac.serviceAccount.create=true \
        --set rbac.serviceAccount.name=cluster-autoscaler \
        --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.cluster_autoscaler[0].arn} \
        --wait
    EOT
  }

  depends_on = [
    module.eks,
    aws_iam_role.cluster_autoscaler
  ]
}

# Istio removed - using native Kubernetes services with ALB ingress
# This simplifies the demo and reduces resource usage by ~1.7 CPU cores and 3.5GB memory
# Application services now communicate directly without service mesh overhead

# Create Redis connection secret and configmap
resource "null_resource" "create_redis_resources" {
  count = var.enable_redis ? 1 : 0

  triggers = {
    redis_endpoint = aws_elasticache_cluster.redis[0].cache_nodes[0].address
    # Removed always_run to prevent unnecessary re-creation of Redis resources on every terraform apply
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}

      # Create Redis secret
      kubectl create secret generic redis-connection \
        --from-literal=REDIS_ADDR=${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:6379 \
        --dry-run=client -o yaml | kubectl apply -f -

      # Create Redis configmap
      kubectl create configmap redis-config \
        --from-literal=REDIS_ADDR=${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:6379 \
        --dry-run=client -o yaml | kubectl apply -f -
    EOT
  }

  depends_on = [
    module.eks,
    aws_elasticache_cluster.redis
  ]
}
