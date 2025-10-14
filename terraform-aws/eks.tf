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

# EKS Cluster Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" # Upgraded to fix deprecated inline_policy warning

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
    }
  }

  # Network configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster security group
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    # Enable IMDSv2 for security
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
      instance_metadata_tags      = "disabled"
    }

    # IAM role configuration
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    # System Node Group - Small instances for cluster add-ons (CoreDNS, EBS CSI, etc.)
    # No taints to allow system pods to schedule
    system = {
      name = "${var.cluster_name}-sys"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.small"] # 2 vCPU, 2 GB RAM - sufficient for system pods
      capacity_type  = "ON_DEMAND"

      labels = {
        role     = "system"
        workload = "cluster-addons"
      }

      # No taints - allow system pods to schedule freely

      tags = merge(
        var.tags,
        {
          Name        = "${var.cluster_name}-sys"
          Environment = "system"
        }
      )
    }

    # Development Node Group - Small instances for dev workloads (1 replica per service)
    dev = {
      name = "${var.cluster_name}-dev-ng"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"] # 2 vCPU, 4 GB RAM
      capacity_type  = "ON_DEMAND"

      labels = {
        environment = "dev"
        workload    = "microservices-dev"
      }

      taints = [
        {
          key    = "environment"
          value  = "dev"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = merge(
        var.tags,
        {
          Name        = "${var.cluster_name}-dev-ng"
          Environment = "dev"
        }
      )
    }

    # QA Node Group - Medium instances for qa workloads (2 replicas per service)
    qa = {
      name = "${var.cluster_name}-qa-ng"

      min_size     = 3
      max_size     = 6
      desired_size = 3

      instance_types = ["t3.large"] # 2 vCPU, 8 GB RAM
      capacity_type  = "ON_DEMAND"

      labels = {
        environment = "qa"
        workload    = "microservices-qa"
      }

      taints = [
        {
          key    = "environment"
          value  = "qa"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = merge(
        var.tags,
        {
          Name        = "${var.cluster_name}-qa-ng"
          Environment = "qa"
        }
      )
    }

    # Production Node Group - Large instances for prod workloads (3 replicas per service)
    prod = {
      name = "${var.cluster_name}-prod-ng"

      min_size     = 5
      max_size     = 10
      desired_size = 5

      instance_types = ["t3.xlarge"] # 4 vCPU, 16 GB RAM
      capacity_type  = "ON_DEMAND"

      labels = {
        environment = "prod"
        workload    = "microservices-prod"
      }

      taints = [
        {
          key    = "environment"
          value  = "prod"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = merge(
        var.tags,
        {
          Name        = "${var.cluster_name}-prod-ng"
          Environment = "prod"
        }
      )
    }
  }

  # CloudWatch logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Note: manage_aws_auth_configmap removed in EKS module v20+
  # aws-auth ConfigMap is now managed automatically by the module

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# IAM role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# NOTE: Helm releases moved to helm-installs.tf using null_resource + local-exec
# This approach properly inherits AWS credentials from environment variables

# # Install AWS Load Balancer Controller
# resource "helm_release" "aws_load_balancer_controller" {
#   count = var.enable_alb_controller ? 1 : 0
#   # ... (commented out, see helm-installs.tf)
# }

# # Install Kubernetes Metrics Server
# resource "helm_release" "metrics_server" {
#   count = var.enable_metrics_server ? 1 : 0
#   # ... (commented out, see helm-installs.tf)
# }

# # Install Cluster Autoscaler
# resource "helm_release" "cluster_autoscaler" {
#   count = var.enable_cluster_autoscaler ? 1 : 0
#   # ... (commented out, see helm-installs.tf)
# }

# Update kubeconfig for local access
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  }

  depends_on = [module.eks]
}
