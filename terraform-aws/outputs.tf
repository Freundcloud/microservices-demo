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

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# EKS Cluster Outputs
output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

# Node Group Outputs
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
}

# ElastiCache Outputs
output "redis_endpoint" {
  description = "The endpoint of the ElastiCache Redis cluster"
  value       = var.enable_redis ? aws_elasticache_cluster.redis[0].cache_nodes[0].address : null
}

output "redis_port" {
  description = "The port of the ElastiCache Redis cluster"
  value       = var.enable_redis ? aws_elasticache_cluster.redis[0].port : null
}

output "redis_connection_string" {
  description = "The full connection string for Redis"
  value       = var.enable_redis ? "${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${aws_elasticache_cluster.redis[0].port}" : null
}

# IAM Role Outputs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = var.enable_alb_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of IAM role for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

# Configuration Commands
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "deploy_application" {
  description = "Command to deploy the Online Boutique application"
  value       = "kubectl apply -f ../release/kubernetes-manifests.yaml"
}

# Region Output
output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for k, v in aws_ecr_repository.microservices : k => v.repository_url
  }
}

output "ecr_registry_url" {
  description = "ECR registry URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# ECR Login Command
output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# Istio Outputs
output "istio_enabled" {
  description = "Whether Istio is enabled"
  value       = var.enable_istio
}

output "istio_version" {
  description = "Istio version installed"
  value       = var.enable_istio ? var.istio_version : null
}

output "istio_ingress_gateway_url" {
  description = "Istio Ingress Gateway LoadBalancer URL"
  value       = var.enable_istio ? "kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'" : null
}

output "kiali_dashboard_command" {
  description = "Command to access Kiali dashboard"
  value       = var.enable_istio && var.enable_istio_addons ? "kubectl port-forward svc/kiali-server -n istio-system 20001:20001" : null
}

output "grafana_dashboard_command" {
  description = "Command to access Grafana dashboard"
  value       = var.enable_istio && var.enable_istio_addons ? "kubectl port-forward svc/grafana -n istio-system 3000:80" : null
}

output "jaeger_dashboard_command" {
  description = "Command to access Jaeger tracing UI"
  value       = var.enable_istio && var.enable_istio_addons ? "kubectl port-forward svc/jaeger-query -n istio-system 16686:16686" : null
}
