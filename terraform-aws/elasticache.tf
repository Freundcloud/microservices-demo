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

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis" {
  count = var.enable_redis ? 1 : 0

  name       = "${var.cluster_name}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-redis-subnet-group"
    }
  )
}

# Security group for ElastiCache Redis
resource "aws_security_group" "redis" {
  count = var.enable_redis ? 1 : 0

  name_prefix = "${var.cluster_name}-redis-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "Allow Redis access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-redis-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Redis cluster
resource "aws_elasticache_cluster" "redis" {
  count = var.enable_redis ? 1 : 0

  cluster_id           = "${var.cluster_name}-redis"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis[0].name
  subnet_group_name    = aws_elasticache_subnet_group.redis[0].name
  security_group_ids   = [aws_security_group.redis[0].id]
  port                 = 6379

  # Maintenance and backup settings
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = 1

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Apply changes immediately (for demo purposes)
  apply_immediately = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-redis"
    }
  )
}

# ElastiCache parameter group for Redis
resource "aws_elasticache_parameter_group" "redis" {
  count = var.enable_redis ? 1 : 0

  name   = "${var.cluster_name}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-redis-params"
    }
  )
}

# Kubernetes Secret for Redis connection
resource "kubernetes_secret" "redis_connection" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = "redis-connection"
    namespace = var.namespace
  }

  data = {
    redis-address = "${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${aws_elasticache_cluster.redis[0].port}"
  }

  type = "Opaque"

  depends_on = [
    module.eks,
    aws_elasticache_cluster.redis
  ]
}

# Kubernetes ConfigMap with Redis configuration
resource "kubernetes_config_map" "redis_config" {
  count = var.enable_redis ? 1 : 0

  metadata {
    name      = "redis-config"
    namespace = var.namespace
  }

  data = {
    "REDIS_ADDR" = "${aws_elasticache_cluster.redis[0].cache_nodes[0].address}:${aws_elasticache_cluster.redis[0].port}"
  }

  depends_on = [
    module.eks,
    aws_elasticache_cluster.redis
  ]
}
