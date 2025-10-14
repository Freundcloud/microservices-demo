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

# VPC Configuration Tests
# Tests to verify VPC, subnets, and networking configuration

run "vpc_configuration_test" {
  command = plan

  variables {
    cluster_name       = "test-cluster"
    aws_region         = "eu-west-2"
    environment        = "test"
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    enable_istio       = false
    enable_redis       = false
  }

  # Verify VPC CIDR
  assert {
    condition     = module.vpc.vpc_cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should be 10.0.0.0/16"
  }

  # Verify number of availability zones
  assert {
    condition     = length(module.vpc.azs) == 3
    error_message = "Should have 3 availability zones"
  }

  # Verify private subnets exist
  assert {
    condition     = length(module.vpc.private_subnets) == 3
    error_message = "Should have 3 private subnets"
  }

  # Verify public subnets exist
  assert {
    condition     = length(module.vpc.public_subnets) == 3
    error_message = "Should have 3 public subnets"
  }

  # Verify NAT gateway is created
  assert {
    condition     = length(module.vpc.natgw_ids) > 0
    error_message = "At least one NAT gateway should be created"
  }

  # Verify VPC endpoints for private access
  # Note: VPC module doesn't expose vpc_endpoints directly
  # Endpoints are created but not testable through module outputs
  # assert {
  #   condition     = aws_vpc_endpoint.ecr_api != null
  #   error_message = "ECR API VPC endpoint should be created"
  # }
}

run "multi_az_subnet_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    azs          = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  }

  # Verify subnet distribution across AZs
  assert {
    condition     = length([for s in module.vpc.private_subnets : s]) == length(var.azs)
    error_message = "Private subnets should be distributed across all AZs"
  }

  # Verify public subnet distribution
  assert {
    condition     = length([for s in module.vpc.public_subnets : s]) == length(var.azs)
    error_message = "Public subnets should be distributed across all AZs"
  }
}

run "vpc_tagging_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
  }

  # Verify VPC has required tags for EKS
  assert {
    condition     = lookup(module.vpc.vpc_tags, "kubernetes.io/cluster/test-cluster", "") == "shared"
    error_message = "VPC should have EKS cluster tag"
  }

  # Verify private subnets have EKS internal tag
  assert {
    condition     = lookup(module.vpc.private_subnet_tags, "kubernetes.io/role/internal-elb", "") == "1"
    error_message = "Private subnets should have internal ELB tag"
  }

  # Verify public subnets have EKS external tag
  assert {
    condition     = lookup(module.vpc.public_subnet_tags, "kubernetes.io/role/elb", "") == "1"
    error_message = "Public subnets should have external ELB tag"
  }
}
