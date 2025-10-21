#!/usr/bin/env bash
#
# Cleanup unused VPCs to stay under AWS VPC limit
#

set -euo pipefail

# VPC managed by Terraform (KEEP THIS ONE)
MANAGED_VPC="vpc-03204eaa401397960"

# VPCs to delete
VPCS_TO_DELETE=(
  "vpc-045543e6bc0c60194"
  "vpc-07d83f3f07735d7d8"
  "vpc-0a01c58ab216c6b61"
  "vpc-01d5250cd96d59f85"
)

echo "🔍 Cleaning up unused VPCs to stay under limit..."
echo "   Managed VPC (KEEP): $MANAGED_VPC"
echo "   VPCs to delete: ${VPCS_TO_DELETE[@]}"
echo ""

for vpc_id in "${VPCS_TO_DELETE[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🗑️  Deleting VPC: $vpc_id"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Delete NAT Gateways
  echo "  Deleting NAT Gateways..."
  for nat_id in $(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[*].NatGatewayId' --output text); do
    echo "    - $nat_id"
    aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" || true
  done

  # Wait for NAT gateways to be deleted
  sleep 5

  # Release Elastic IPs
  echo "  Releasing Elastic IPs..."
  for alloc_id in $(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query "Addresses[?AssociationId==null].AllocationId" --output text); do
    echo "    - $alloc_id"
    aws ec2 release-address --allocation-id "$alloc_id" 2>/dev/null || true
  done

  # Delete Internet Gateways
  echo "  Detaching and deleting Internet Gateways..."
  for igw_id in $(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text); do
    echo "    - $igw_id"
    aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" || true
    aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" || true
  done

  # Delete subnets
  echo "  Deleting subnets..."
  for subnet_id in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text); do
    echo "    - $subnet_id"
    aws ec2 delete-subnet --subnet-id "$subnet_id" || true
  done

  # Delete route tables (except main)
  echo "  Deleting route tables..."
  for rt_id in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
    echo "    - $rt_id"
    aws ec2 delete-route-table --route-table-id "$rt_id" || true
  done

  # Delete security groups (except default)
  echo "  Deleting security groups..."
  for sg_id in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
    echo "    - $sg_id"
    aws ec2 delete-security-group --group-id "$sg_id" || true
  done

  # Delete VPC
  echo "  Deleting VPC..."
  aws ec2 delete-vpc --vpc-id "$vpc_id" && echo "    ✅ VPC $vpc_id deleted!" || echo "    ❌ Failed to delete $vpc_id"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ VPC cleanup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Remaining VPCs:"
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
