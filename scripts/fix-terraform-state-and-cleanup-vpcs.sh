#!/bin/bash

# Fix Terraform State and Cleanup Unused VPCs
# This script imports the active VPC into Terraform state and deletes unused VPCs

set -e

REGION="eu-west-2"
CLUSTER_NAME="microservices"
ACTIVE_VPC_ID="vpc-0cc6ce334da44042e"  # VPC currently used by EKS cluster

echo "🔧 Terraform State Fix and VPC Cleanup"
echo "========================================"
echo ""
echo "Active VPC (will keep): $ACTIVE_VPC_ID"
echo "Region: $REGION"
echo ""

cd /home/olafkfreund/Source/Calitti/ARC/microservices-demo/terraform-aws || exit 1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Import Active VPC into Terraform State"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Import the active VPC
echo "Importing VPC: $ACTIVE_VPC_ID"
terraform import 'module.vpc.aws_vpc.this[0]' "$ACTIVE_VPC_ID" || {
  echo "  Note: VPC may already be imported or error occurred"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Cleanup Unused VPCs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get all VPCs except the active one
UNUSED_VPCS=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?VpcId!='$ACTIVE_VPC_ID'].VpcId" --output text)

if [ -z "$UNUSED_VPCS" ]; then
  echo "✅ No unused VPCs to delete"
else
  echo "Found $(echo $UNUSED_VPCS | wc -w) unused VPCs to delete"
  echo ""

  for VPC_ID in $UNUSED_VPCS; do
    echo "🗑️  Deleting VPC: $VPC_ID"

    # Delete dependencies first

    # 1. Delete NAT Gateways
    echo "  - Deleting NAT Gateways..."
    NAT_GWS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)
    for NAT_GW in $NAT_GWS; do
      aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW --region $REGION 2>/dev/null || true
    done

    # Wait for NAT gateways to delete (they can take time)
    if [ ! -z "$NAT_GWS" ]; then
      echo "  - Waiting for NAT Gateways to delete..."
      sleep 10
    fi

    # 2. Release Elastic IPs
    echo "  - Releasing Elastic IPs..."
    EIPS=$(aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query "Addresses[?AssociationId==null].AllocationId" --output text)
    for EIP in $EIPS; do
      # Check if EIP is associated with this VPC's NAT gateway
      aws ec2 release-address --allocation-id $EIP --region $REGION 2>/dev/null || true
    done

    # 3. Delete Internet Gateways
    echo "  - Detaching and deleting Internet Gateways..."
    IGWs=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text)
    for IGW in $IGWs; do
      aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
      aws ec2 delete-internet-gateway --internet-gateway-id $IGW --region $REGION 2>/dev/null || true
    done

    # 4. Delete Subnets
    echo "  - Deleting Subnets..."
    SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
    for SUBNET in $SUBNETS; do
      aws ec2 delete-subnet --subnet-id $SUBNET --region $REGION 2>/dev/null || true
    done

    # 5. Delete Route Tables (except main)
    echo "  - Deleting Route Tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    for RT in $ROUTE_TABLES; do
      aws ec2 delete-route-table --route-table-id $RT --region $REGION 2>/dev/null || true
    done

    # 6. Delete Security Groups (except default)
    echo "  - Deleting Security Groups..."
    SGS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    for SG in $SGS; do
      # First remove all rules
      aws ec2 revoke-security-group-ingress --group-id $SG --ip-permissions "$(aws ec2 describe-security-groups --region $REGION --group-ids $SG --query 'SecurityGroups[0].IpPermissions' --output json)" --region $REGION 2>/dev/null || true
      aws ec2 revoke-security-group-egress --group-id $SG --ip-permissions "$(aws ec2 describe-security-groups --region $REGION --group-ids $SG --query 'SecurityGroups[0].IpPermissionsEgress' --output json)" --region $REGION 2>/dev/null || true
      # Then delete
      aws ec2 delete-security-group --group-id $SG --region $REGION 2>/dev/null || true
    done

    # 7. Delete Network ACLs (except default)
    echo "  - Deleting Network ACLs..."
    NACLS=$(aws ec2 describe-network-acls --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' --output text)
    for NACL in $NACLS; do
      aws ec2 delete-network-acl --network-acl-id $NACL --region $REGION 2>/dev/null || true
    done

    # 8. Delete VPC Endpoints
    echo "  - Deleting VPC Endpoints..."
    ENDPOINTS=$(aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text)
    for ENDPOINT in $ENDPOINTS; do
      aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $ENDPOINT --region $REGION 2>/dev/null || true
    done

    # 9. Finally, delete the VPC
    echo "  - Deleting VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null && echo "  ✅ VPC $VPC_ID deleted" || echo "  ⚠️  Failed to delete VPC $VPC_ID (may have dependencies)"

    echo ""
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Verify VPC Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VPC_COUNT=$(aws ec2 describe-vpcs --region $REGION --query 'Vpcs | length(@)' --output text)
VPC_LIMIT=$(aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE --region $REGION --query 'Quota.Value' --output text 2>/dev/null || echo "5")

echo "Current VPCs: $VPC_COUNT / $VPC_LIMIT"
echo ""
echo "Remaining VPCs:"
aws ec2 describe-vpcs --region $REGION --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock,State]' --output table

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Run import script to import other resources: ./scripts/import-all-existing-resources.sh"
echo "2. Run: cd terraform-aws && terraform plan"
echo "3. Review the plan carefully"
echo "4. Run: terraform apply"
echo ""
