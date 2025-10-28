# Terraform State Import & AWS Resource Cleanup Guide

## Problem Summary

The Terraform apply is failing because resources already exist in AWS but are not tracked in Terraform state. This happens when:
1. Resources were created manually or by previous Terraform runs
2. Terraform state was lost or not properly maintained
3. Resources exist but state file doesn't reflect them

## Root Causes

### 1. Resource Already Exists Errors
```
Error: creating KMS Alias (alias/microservices-ecr): AlreadyExistsException
Error: creating ECR Repository (currencyservice): RepositoryAlreadyExistsException
Error: creating IAM Policy (microservices-aws-load-balancer-controller): EntityAlreadyExists
```

**Solution**: Import existing resources into Terraform state

### 2. VPC Limit Reached (CRITICAL)
```
Error: creating EC2 VPC: VpcLimitExceeded: The maximum number of VPCs has been reached.
```

**Solution**: Delete unused VPCs or request limit increase

## Solutions

### Option 1: Import Existing Resources (Recommended)

We've created a script to import all existing resources:

```bash
# Run the import script
./scripts/import-existing-resources.sh
```

This imports:
- KMS aliases (ecr, cloudwatch, sns)
- All 12 ECR repositories
- SNS topics
- ElastiCache parameter groups
- IAM policies

### Option 2: Clean Up Unused VPCs (REQUIRED)

**The VPC limit error MUST be fixed before Terraform can proceed.**

#### Check Current VPCs
```bash
aws ec2 describe-vpcs --region eu-west-2 --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],State]' --output table
```

#### Delete Unused VPCs
```bash
# Use the cleanup script
./scripts/cleanup-unused-vpcs.sh
```

**OR manually delete via AWS Console:**
1. Go to VPC Dashboard
2. Identify VPCs not in use
3. Delete dependencies first:
   - NAT Gateways
   - Internet Gateways
   - Subnets
   - Route Tables
   - Security Groups
4. Delete the VPC

#### Request VPC Limit Increase
If you need more than 5 VPCs:
1. Go to AWS Service Quotas console
2. Search for "VPC"
3. Request increase for "VPCs per Region"
4. Wait for approval (usually 1-2 business days)

### Option 3: Use Existing VPC (Alternative)

Instead of creating a new VPC, modify Terraform to use an existing one:

```hcl
# In terraform-aws/vpc.tf or main configuration
data "aws_vpc" "existing" {
  id = "vpc-xxxxxxxxx"  # Your existing VPC ID
}

# Comment out or remove:
# module "vpc" {
#   source = "terraform-aws-modules/vpc/aws"
#   ...
# }
```

## Detailed Import Commands

If the script doesn't work, run these commands individually:

### KMS Aliases
```bash
cd terraform-aws

terraform import aws_kms_alias.ecr alias/microservices-ecr
terraform import aws_kms_alias.cloudwatch alias/microservices-cloudwatch
terraform import aws_kms_alias.sns alias/microservices-sns
```

### ECR Repositories
```bash
terraform import 'aws_ecr_repository.microservices["currencyservice"]' currencyservice
terraform import 'aws_ecr_repository.microservices["frontend"]' frontend
terraform import 'aws_ecr_repository.microservices["productcatalogservice"]' productcatalogservice
terraform import 'aws_ecr_repository.microservices["shippingservice"]' shippingservice
terraform import 'aws_ecr_repository.microservices["cartservice"]' cartservice
terraform import 'aws_ecr_repository.microservices["paymentservice"]' paymentservice
terraform import 'aws_ecr_repository.microservices["adservice"]' adservice
terraform import 'aws_ecr_repository.microservices["checkoutservice"]' checkoutservice
terraform import 'aws_ecr_repository.microservices["shoppingassistantservice"]' shoppingassistantservice
terraform import 'aws_ecr_repository.microservices["emailservice"]' emailservice
terraform import 'aws_ecr_repository.microservices["recommendationservice"]' recommendationservice
terraform import 'aws_ecr_repository.microservices["loadgenerator"]' loadgenerator
```

### SNS Topic
```bash
terraform import aws_sns_topic.ecr_scan_alerts arn:aws:sns:eu-west-2:533267307120:microservices-ecr-scan-alerts
```

### ElastiCache Parameter Group
```bash
terraform import 'aws_elasticache_parameter_group.redis[0]' microservices-redis-params
```

### IAM Policies
```bash
terraform import 'aws_iam_policy.aws_load_balancer_controller[0]' arn:aws:iam::533267307120:policy/microservices-aws-load-balancer-controller
terraform import 'aws_iam_policy.cluster_autoscaler[0]' arn:aws:iam::533267307120:policy/microservices-cluster-autoscaler
```

## Verification

After importing, verify the state:

```bash
cd terraform-aws

# Check what's in state
terraform state list

# Plan should show no changes for imported resources
terraform plan
```

## Prevention

To avoid this in the future:

### 1. Use Remote State
Configure S3 backend in `terraform-aws/versions.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "microservices/terraform.tfstate"
    region = "eu-west-2"

    # Enable state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### 2. Always Use Terraform
- Never create resources manually in AWS Console
- Always use `terraform apply` for infrastructure changes
- Use `terraform import` immediately if resources are created externally

### 3. Regular State Backups
```bash
# Backup current state
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d)
```

## Troubleshooting

### Import Fails with "Resource Not Found"
- Verify resource exists: `aws ecr describe-repositories --repository-names currencyservice`
- Check region: Ensure you're in `eu-west-2`
- Check AWS credentials: `aws sts get-caller-identity`

### VPC Deletion Fails
Error: "has dependencies and cannot be deleted"

**Solution**: Delete in this order:
1. EC2 instances
2. Load Balancers
3. NAT Gateways (release Elastic IPs after)
4. VPC Endpoints
5. Subnets
6. Route Tables (except main)
7. Internet Gateways
8. Security Groups (except default)
9. Network ACLs (except default)
10. VPC

### State Lock Error
```
Error: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

## Emergency Cleanup

If you need to completely start fresh:

```bash
# WARNING: This destroys ALL infrastructure
cd terraform-aws
terraform destroy -auto-approve

# Remove state files
rm -rf terraform.tfstate terraform.tfstate.backup .terraform/

# Re-initialize
terraform init
terraform plan
terraform apply
```

## Next Steps

1. **Immediate**: Fix VPC limit (delete unused VPCs or request increase)
2. **Short-term**: Run import script to capture existing resources
3. **Long-term**: Set up remote state backend to prevent this issue

## Support

For AWS limit increases:
- Open AWS Support case: https://console.aws.amazon.com/support/home
- Request type: "Service Limit Increase"
- Limit type: "VPC"
- New limit value: 10 (or your desired number)

For Terraform state issues:
- Terraform docs: https://developer.hashicorp.com/terraform/cli/state
- Import command: https://developer.hashicorp.com/terraform/cli/import
