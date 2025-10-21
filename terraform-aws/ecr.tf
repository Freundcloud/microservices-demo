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

# Local variables for microservices
locals {
  microservices = [
    "emailservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "checkoutservice",
    "paymentservice",
    "currencyservice",
    "cartservice",
    "frontend",
    "adservice",
    "loadgenerator",
    "shoppingassistantservice"
  ]
}

# KMS key for ECR encryption
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ecr-key"
    }
  )
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.cluster_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ECR Repositories for all microservices
# NOTE: Reverting to MUTABLE tags and AES256 encryption to match existing state
# force_delete = true is the only change to allow easier cleanup
resource "aws_ecr_repository" "microservices" {
  for_each = toset(local.microservices)

  name                 = each.value
  image_tag_mutability = "MUTABLE" # Revert to MUTABLE (was IMMUTABLE)
  force_delete         = true      # Allow deletion even if repository contains images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # Revert to AES256 (was KMS)
  }

  tags = merge(
    var.tags,
    {
      Name        = each.value
      Service     = each.value
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  )
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each = aws_ecr_repository.microservices

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["main", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep only last 3 PR images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["pr-"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository policy to allow EKS nodes to pull images
resource "aws_ecr_repository_policy" "microservices" {
  for_each = aws_ecr_repository.microservices

  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodesPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            module.eks.eks_managed_node_groups["all"].iam_role_arn
          ]
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      },
      {
        Sid    = "AllowGitHubActionsPush"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# KMS key for CloudWatch Logs encryption
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cloudwatch-key"
    }
  )
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${var.cluster_name}-cloudwatch"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

# CloudWatch Log Group for ECR (optional - for image scan results)
# Commented out to avoid KMS key policy issues during apply
# These log groups are created automatically by ECR when needed
#resource "aws_cloudwatch_log_group" "ecr_scan_results" {
#  for_each = toset(local.microservices)
#
#  name              = "/aws/ecr/${each.value}/scan-results"
#  retention_in_days = 365                        # CKV_AWS_338: Ensure CloudWatch log groups retain logs for at least 1 year
#  kms_key_id        = aws_kms_key.cloudwatch.arn # CKV_AWS_158: Ensure CloudWatch Log Group is encrypted by KMS
#
#  depends_on = [
#    aws_kms_key.cloudwatch,
#    aws_kms_alias.cloudwatch
#  ]
#
#  tags = merge(
#    var.tags,
#    {
#      Name    = "${each.value}-scan-results"
#      Service = each.value
#    }
#  )
#}

# EventBridge rule to notify on critical vulnerabilities
resource "aws_cloudwatch_event_rule" "ecr_scan_findings" {
  name        = "${var.cluster_name}-ecr-scan-findings"
  description = "Capture ECR image scan findings with CRITICAL severity"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      scan-status = ["COMPLETE"]
      finding-severity-counts = {
        CRITICAL = [{
          exists = true
        }]
      }
    }
  })

  tags = var.tags
}

# KMS key for SNS encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EventBridge to use the key"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-sns-key"
    }
  )
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.cluster_name}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

# SNS topic for security notifications (optional)
resource "aws_sns_topic" "ecr_scan_alerts" {
  name              = "${var.cluster_name}-ecr-scan-alerts"
  kms_master_key_id = aws_kms_key.sns.id # CKV_AWS_26: Ensure all data stored in the SNS topic is encrypted

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ecr-scan-alerts"
    }
  )
}

# EventBridge target to send to SNS
resource "aws_cloudwatch_event_target" "ecr_scan_to_sns" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.ecr_scan_alerts.arn
}

# SNS topic policy
resource "aws_sns_topic_policy" "ecr_scan_alerts" {
  arn = aws_sns_topic.ecr_scan_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.ecr_scan_alerts.arn
      }
    ]
  })
}
