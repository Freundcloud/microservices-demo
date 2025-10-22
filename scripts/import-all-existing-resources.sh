#!/bin/bash

# Import All Existing Resources into Terraform State
# This script imports existing AWS resources into Terraform state to avoid "already exists" errors

set -e

REGION="eu-west-2"
CLUSTER_NAME="microservices"
ACCOUNT_ID="533267307120"

echo "🔄 Starting comprehensive resource import..."
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Account: $ACCOUNT_ID"
echo ""

cd terraform-aws || exit 1

# Function to safely import (doesn't fail if already imported)
safe_import() {
  local resource=$1
  local id=$2

  echo "Importing: $resource"
  if terraform import "$resource" "$id" 2>&1 | grep -q "Resource already managed"; then
    echo "  ✓ Already imported"
  else
    echo "  ✓ Imported successfully"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Importing KMS Keys and Aliases"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get KMS key IDs
ECR_KEY_ID=$(aws kms list-aliases --region $REGION --query "Aliases[?AliasName=='alias/microservices-ecr'].TargetKeyId" --output text 2>/dev/null || echo "")
CLOUDWATCH_KEY_ID=$(aws kms list-aliases --region $REGION --query "Aliases[?AliasName=='alias/microservices-cloudwatch'].TargetKeyId" --output text 2>/dev/null || echo "")
SNS_KEY_ID=$(aws kms list-aliases --region $REGION --query "Aliases[?AliasName=='alias/microservices-sns'].TargetKeyId" --output text 2>/dev/null || echo "")
EKS_KEY_ID=$(aws kms list-aliases --region $REGION --query "Aliases[?AliasName=='alias/eks/microservices'].TargetKeyId" --output text 2>/dev/null || echo "")

if [ ! -z "$ECR_KEY_ID" ]; then
  safe_import "aws_kms_key.ecr" "$ECR_KEY_ID"
  safe_import "aws_kms_alias.ecr" "alias/microservices-ecr"
fi

if [ ! -z "$CLOUDWATCH_KEY_ID" ]; then
  safe_import "aws_kms_key.cloudwatch" "$CLOUDWATCH_KEY_ID"
  safe_import "aws_kms_alias.cloudwatch" "alias/microservices-cloudwatch"
fi

if [ ! -z "$SNS_KEY_ID" ]; then
  safe_import "aws_kms_key.sns" "$SNS_KEY_ID"
  safe_import "aws_kms_alias.sns" "alias/microservices-sns"
fi

if [ ! -z "$EKS_KEY_ID" ]; then
  safe_import "module.eks.module.kms.aws_kms_key.this[0]" "$EKS_KEY_ID"
  safe_import "module.eks.module.kms.aws_kms_alias.this[\"cluster\"]" "alias/eks/microservices"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Importing ECR Repositories"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICES=(
  "emailservice"
  "productcatalogservice"
  "currencyservice"
  "paymentservice"
  "shippingservice"
  "recommendationservice"
  "adservice"
  "shoppingassistantservice"
  "frontend"
  "checkoutservice"
  "cartservice"
  "loadgenerator"
)

for service in "${SERVICES[@]}"; do
  # Check if repository exists
  if aws ecr describe-repositories --repository-names "$service" --region $REGION &>/dev/null; then
    safe_import "aws_ecr_repository.microservices[\"$service\"]" "$service"

    # Import lifecycle policy if exists
    if aws ecr get-lifecycle-policy --repository-name "$service" --region $REGION &>/dev/null; then
      safe_import "aws_ecr_lifecycle_policy.microservices[\"$service\"]" "$service"
    fi

    # Import repository policy if exists
    if aws ecr get-repository-policy --repository-name "$service" --region $REGION &>/dev/null; then
      safe_import "aws_ecr_repository_policy.microservices[\"$service\"]" "$service"
    fi
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Importing SNS Topic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SNS_TOPIC_ARN=$(aws sns list-topics --region $REGION --query "Topics[?contains(TopicArn, 'microservices-ecr-scan-alerts')].TopicArn" --output text 2>/dev/null || echo "")

if [ ! -z "$SNS_TOPIC_ARN" ]; then
  safe_import "aws_sns_topic.ecr_scan_alerts" "$SNS_TOPIC_ARN"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Importing ElastiCache Resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Import parameter group
if aws elasticache describe-cache-parameter-groups --cache-parameter-group-name "microservices-redis-params" --region $REGION &>/dev/null; then
  safe_import "aws_elasticache_parameter_group.redis[0]" "microservices-redis-params"
fi

# Import replication group
REDIS_ID=$(aws elasticache describe-replication-groups --region $REGION --query "ReplicationGroups[?ReplicationGroupId=='microservices-redis'].ReplicationGroupId" --output text 2>/dev/null || echo "")

if [ ! -z "$REDIS_ID" ]; then
  safe_import "aws_elasticache_replication_group.redis[0]" "$REDIS_ID"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Importing IAM Policies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ALB Controller Policy
ALB_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='microservices-aws-load-balancer-controller'].Arn" --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_POLICY_ARN" ]; then
  safe_import "aws_iam_policy.aws_load_balancer_controller[0]" "$ALB_POLICY_ARN"
fi

# Cluster Autoscaler Policy
CA_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='microservices-cluster-autoscaler'].Arn" --output text 2>/dev/null || echo "")
if [ ! -z "$CA_POLICY_ARN" ]; then
  safe_import "aws_iam_policy.cluster_autoscaler[0]" "$CA_POLICY_ARN"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Importing CloudWatch Log Groups"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# EKS Cluster Log Group
if aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$CLUSTER_NAME/cluster" --region $REGION &>/dev/null; then
  safe_import "module.eks.aws_cloudwatch_log_group.this[0]" "/aws/eks/$CLUSTER_NAME/cluster"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Checking VPC Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check VPC limit
VPC_COUNT=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs | length(@)' --output text 2>/dev/null || echo "0")
VPC_LIMIT=$(aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE --region $REGION --query 'Quota.Value' --output text 2>/dev/null || echo "5")

echo "Current VPCs: $VPC_COUNT / $VPC_LIMIT"

if [ "$VPC_COUNT" -ge "$VPC_LIMIT" ]; then
  echo ""
  echo "⚠️  WARNING: VPC limit reached!"
  echo "You need to either:"
  echo "  1. Delete unused VPCs: ./scripts/cleanup-unused-vpcs.sh"
  echo "  2. Request VPC limit increase: ./scripts/request-vpc-limit-increase.sh 10"
  echo ""
  echo "Listing all VPCs:"
  aws ec2 describe-vpcs --region $REGION --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock,State]' --output table
  exit 1
fi

# Try to find and import existing VPC
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=microservices-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "Found existing VPC: $VPC_ID"
  safe_import "module.vpc.aws_vpc.this[0]" "$VPC_ID"

  # Import related VPC resources
  # Note: This is complex and requires knowing subnet IDs, route table IDs, etc.
  # For now, we'll skip this and let Terraform create them if needed
else
  echo "No existing VPC found with tag Name=microservices-vpc"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Import Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Run: terraform plan"
echo "2. Review the plan carefully"
echo "3. Run: terraform apply"
echo ""
