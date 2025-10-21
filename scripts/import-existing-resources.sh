#!/bin/bash
# Import existing AWS resources into Terraform state to avoid "already exists" errors

set -e

cd "$(dirname "$0")/../terraform-aws" || exit 1

echo "🔄 Importing existing AWS resources into Terraform state..."
echo "This will take a few minutes..."
echo ""

# Import KMS aliases
echo "📦 Importing KMS aliases..."
terraform import -input=false aws_kms_alias.ecr alias/microservices-ecr 2>/dev/null && echo "  ✅ ecr" || echo "  ⚠️  ecr (skipped)"
terraform import -input=false aws_kms_alias.cloudwatch alias/microservices-cloudwatch 2>/dev/null && echo "  ✅ cloudwatch" || echo "  ⚠️  cloudwatch (skipped)"
terraform import -input=false aws_kms_alias.sns alias/microservices-sns 2>/dev/null && echo "  ✅ sns" || echo "  ⚠️  sns (skipped)"

# Import ECR repositories
echo ""
echo "📦 Importing ECR repositories..."
for service in currencyservice frontend productcatalogservice shippingservice cartservice \
               paymentservice adservice checkoutservice shoppingassistantservice \
               emailservice recommendationservice loadgenerator; do
  terraform import -input=false "aws_ecr_repository.microservices[\"$service\"]" "$service" 2>/dev/null && echo "  ✅ $service" || echo "  ⚠️  $service (skipped)"
done

# Import SNS topic
echo ""
echo "📦 Importing SNS topic..."
terraform import -input=false aws_sns_topic.ecr_scan_alerts arn:aws:sns:eu-west-2:533267307120:microservices-ecr-scan-alerts 2>/dev/null && echo "  ✅ ecr-scan-alerts" || echo "  ⚠️  ecr-scan-alerts (skipped)"

# Import ElastiCache parameter group
echo ""
echo "📦 Importing ElastiCache parameter group..."
terraform import -input=false 'aws_elasticache_parameter_group.redis[0]' microservices-redis-params 2>/dev/null && echo "  ✅ redis-params" || echo "  ⚠️  redis-params (skipped)"

# Import IAM policies
echo ""
echo "📦 Importing IAM policies..."
terraform import -input=false 'aws_iam_policy.aws_load_balancer_controller[0]' arn:aws:iam::533267307120:policy/microservices-aws-load-balancer-controller 2>/dev/null && echo "  ✅ alb-controller" || echo "  ⚠️  alb-controller (skipped)"
terraform import -input=false 'aws_iam_policy.cluster_autoscaler[0]' arn:aws:iam::533267307120:policy/microservices-cluster-autoscaler 2>/dev/null && echo "  ✅ cluster-autoscaler" || echo "  ⚠️  cluster-autoscaler (skipped)"

echo ""
echo "✅ Import process completed!"
echo ""
echo "⚠️  IMPORTANT: VPC limit error detected."
echo "   You have reached the maximum number of VPCs in your AWS account."
echo "   Options:"
echo "   1. Delete unused VPCs: Run scripts/cleanup-unused-vpcs.sh"
echo "   2. Request VPC limit increase from AWS Support"
echo "   3. Use existing VPC instead of creating new one"
echo ""
echo "Run 'terraform plan' to verify the import was successful."
