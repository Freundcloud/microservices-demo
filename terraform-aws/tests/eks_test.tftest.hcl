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

# EKS Cluster Configuration Tests
# Tests to verify EKS cluster and node group configuration

run "eks_cluster_version_test" {
  command = plan

  variables {
    cluster_name    = "test-cluster"
    aws_region      = "eu-west-2"
    environment     = "test"
    cluster_version = "1.29"
  }

  # Verify cluster version
  assert {
    condition     = module.eks.cluster_version == "1.29"
    error_message = "EKS cluster version should be 1.29"
  }
}

run "eks_node_group_configuration_test" {
  command = plan

  variables {
    cluster_name   = "test-cluster"
    aws_region     = "eu-west-2"
    environment    = "test"
    enable_istio   = false
    enable_redis   = false
  }

  # Verify all four node groups exist
  assert {
    condition     = contains(keys(module.eks.eks_managed_node_groups), "system")
    error_message = "System node group should exist"
  }

  assert {
    condition     = contains(keys(module.eks.eks_managed_node_groups), "dev")
    error_message = "Dev node group should exist"
  }

  assert {
    condition     = contains(keys(module.eks.eks_managed_node_groups), "qa")
    error_message = "QA node group should exist"
  }

  assert {
    condition     = contains(keys(module.eks.eks_managed_node_groups), "prod")
    error_message = "Prod node group should exist"
  }

  # Verify system node group uses t3.small
  assert {
    condition     = contains(module.eks.eks_managed_node_groups["system"].instance_types, "t3.small")
    error_message = "System node group should use t3.small instance type"
  }

  # Verify dev node group uses t3.medium
  assert {
    condition     = contains(module.eks.eks_managed_node_groups["dev"].instance_types, "t3.medium")
    error_message = "Dev node group should use t3.medium instance type"
  }

  # Verify qa node group uses t3.large
  assert {
    condition     = contains(module.eks.eks_managed_node_groups["qa"].instance_types, "t3.large")
    error_message = "QA node group should use t3.large instance type"
  }

  # Verify prod node group uses t3.xlarge
  assert {
    condition     = contains(module.eks.eks_managed_node_groups["prod"].instance_types, "t3.xlarge")
    error_message = "Prod node group should use t3.xlarge instance type"
  }
}

run "eks_addons_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
  }

  # Verify required EKS addons
  assert {
    condition     = contains(keys(module.eks.cluster_addons), "coredns")
    error_message = "CoreDNS addon should be enabled"
  }

  assert {
    condition     = contains(keys(module.eks.cluster_addons), "kube-proxy")
    error_message = "kube-proxy addon should be enabled"
  }

  assert {
    condition     = contains(keys(module.eks.cluster_addons), "vpc-cni")
    error_message = "VPC CNI addon should be enabled"
  }

  assert {
    condition     = contains(keys(module.eks.cluster_addons), "aws-ebs-csi-driver")
    error_message = "EBS CSI driver addon should be enabled"
  }
}

run "eks_irsa_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
  }

  # Verify IRSA is enabled
  assert {
    condition     = module.eks.enable_irsa == true
    error_message = "IRSA should be enabled for secure AWS access"
  }

  # Verify OIDC provider exists
  assert {
    condition     = module.eks.oidc_provider_arn != ""
    error_message = "OIDC provider should be created for IRSA"
  }
}

run "eks_security_group_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
  }

  # Verify cluster security group exists
  assert {
    condition     = module.eks.cluster_security_group_id != ""
    error_message = "Cluster security group should be created"
  }
}

run "eks_multi_environment_test" {
  command = plan

  variables {
    cluster_name   = "microservices-dev"
    aws_region     = "eu-west-2"
    environment    = "dev"
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    instance_types = ["t3.medium"]
  }

  # Verify dev environment configuration
  assert {
    condition     = module.eks.cluster_name == "microservices-dev"
    error_message = "Cluster name should include environment suffix"
  }

  assert {
    condition     = lookup(module.eks.eks_managed_node_groups["main"], "desired_size", 0) == 2
    error_message = "Dev environment should have 2 desired nodes"
  }
}

run "eks_production_environment_test" {
  command = plan

  variables {
    cluster_name   = "microservices-prod"
    aws_region     = "eu-west-2"
    environment    = "prod"
    desired_size   = 5
    min_size       = 3
    max_size       = 10
    instance_types = ["t3.large", "t3.xlarge"]
  }

  # Verify production environment configuration
  assert {
    condition     = module.eks.cluster_name == "microservices-prod"
    error_message = "Cluster name should include environment suffix"
  }

  assert {
    condition     = lookup(module.eks.eks_managed_node_groups["main"], "desired_size", 0) == 5
    error_message = "Production environment should have 5 desired nodes"
  }

  assert {
    condition     = lookup(module.eks.eks_managed_node_groups["main"], "min_size", 0) == 3
    error_message = "Production environment should have minimum 3 nodes"
  }

  # Verify production uses larger instance types
  assert {
    condition     = contains(lookup(module.eks.eks_managed_node_groups["main"], "instance_types", []), "t3.large")
    error_message = "Production should use t3.large or larger instances"
  }
}
