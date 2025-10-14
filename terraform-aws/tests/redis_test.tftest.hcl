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

# ElastiCache Redis Configuration Tests
# Tests to verify Redis cluster configuration

run "redis_enabled_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_redis = true
  }

  # Verify Redis cluster is created when enabled
  assert {
    condition     = length(aws_elasticache_cluster.redis) == 1
    error_message = "Redis cluster should be created when enable_redis is true"
  }
}

run "redis_disabled_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_redis = false
  }

  # Verify Redis cluster is not created when disabled
  assert {
    condition     = length(aws_elasticache_cluster.redis) == 0
    error_message = "Redis cluster should not be created when enable_redis is false"
  }
}

run "redis_configuration_test" {
  command = plan

  variables {
    cluster_name          = "test-cluster"
    aws_region            = "eu-west-2"
    environment           = "test"
    enable_redis          = true
    redis_node_type       = "cache.t3.micro"
    redis_num_cache_nodes = 1
    redis_engine_version  = "7.0"
  }

  # Verify Redis engine version
  assert {
    condition     = aws_elasticache_cluster.redis[0].engine_version == "7.0"
    error_message = "Redis engine version should be 7.0"
  }

  # Verify Redis node type
  assert {
    condition     = aws_elasticache_cluster.redis[0].node_type == "cache.t3.micro"
    error_message = "Redis node type should be cache.t3.micro"
  }

  # Verify number of cache nodes
  assert {
    condition     = aws_elasticache_cluster.redis[0].num_cache_nodes == 1
    error_message = "Should have 1 Redis cache node"
  }
}

run "redis_security_group_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_redis = true
  }

  # Verify Redis security group is created
  assert {
    condition     = length(aws_security_group.redis) == 1
    error_message = "Redis security group should be created"
  }

  # Verify security group has proper ingress rules (inline)
  assert {
    condition     = length(aws_security_group.redis[0].ingress) > 0
    error_message = "Redis security group should have ingress rules"
  }
}

run "redis_kubernetes_integration_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_redis = true
  }

  # Verify Kubernetes Secret is created
  assert {
    condition     = length(kubernetes_secret.redis_connection) == 1
    error_message = "Kubernetes Secret for Redis should be created"
  }

  # Verify Kubernetes ConfigMap is created
  assert {
    condition     = length(kubernetes_config_map.redis_config) == 1
    error_message = "Kubernetes ConfigMap for Redis should be created"
  }
}
