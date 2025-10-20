#!/bin/bash
set -e

# ServiceNow Custom Fields Setup Script
# This script creates all custom fields required for AWS Infrastructure Discovery

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICENOW_INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-}"
SERVICENOW_USERNAME="${SERVICENOW_USERNAME:-}"
SERVICENOW_PASSWORD="${SERVICENOW_PASSWORD:-}"

# Validate environment variables
if [[ -z "$SERVICENOW_INSTANCE_URL" || -z "$SERVICENOW_USERNAME" || -z "$SERVICENOW_PASSWORD" ]]; then
  echo -e "${RED}Error: Required environment variables not set${NC}"
  echo "Please set the following environment variables:"
  echo "  - SERVICENOW_INSTANCE_URL (e.g., https://instance.service-now.com)"
  echo "  - SERVICENOW_USERNAME"
  echo "  - SERVICENOW_PASSWORD"
  exit 1
fi

# Remove trailing slash from instance URL
SERVICENOW_INSTANCE_URL="${SERVICENOW_INSTANCE_URL%/}"

# Create Basic Auth header
BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# Counter for tracking
TOTAL_FIELDS=0
CREATED_FIELDS=0
EXISTING_FIELDS=0
FAILED_FIELDS=0

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}ServiceNow Custom Fields Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo "Instance: ${SERVICENOW_INSTANCE_URL}"
echo "User: ${SERVICENOW_USERNAME}"
echo ""

# Function to create a custom field
create_custom_field() {
  local table_name=$1
  local field_name=$2
  local field_type=$3
  local field_label=$4
  local max_length=${5:-100}
  local mandatory=${6:-false}

  TOTAL_FIELDS=$((TOTAL_FIELDS + 1))

  echo -n "Creating field ${field_name} on ${table_name}... "

  # Check if field already exists
  CHECK_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=${table_name}^element=${field_name}&sysparm_limit=1" \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    -H "Accept: application/json")

  CHECK_HTTP_CODE=$(echo "$CHECK_RESPONSE" | tail -n1)
  CHECK_BODY=$(echo "$CHECK_RESPONSE" | sed '$d')

  if [ "$CHECK_HTTP_CODE" != "200" ]; then
    echo -e "${RED}FAILED (HTTP ${CHECK_HTTP_CODE})${NC}"
    FAILED_FIELDS=$((FAILED_FIELDS + 1))
    return 1
  fi

  EXISTING_COUNT=$(echo "$CHECK_BODY" | jq -r '.result | length')

  if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}ALREADY EXISTS${NC}"
    EXISTING_FIELDS=$((EXISTING_FIELDS + 1))
    return 0
  fi

  # Create the field
  PAYLOAD=$(jq -n \
    --arg name "$table_name" \
    --arg element "$field_name" \
    --arg type "$field_type" \
    --arg label "$field_label" \
    --arg length "$max_length" \
    --arg mandatory "$mandatory" \
    '{
      name: $name,
      element: $element,
      internal_type: $type,
      column_label: $label,
      max_length: $length,
      mandatory: ($mandatory == "true"),
      active: true,
      read_only: false
    }')

  CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary" \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$PAYLOAD")

  CREATE_HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
  CREATE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

  if [ "$CREATE_HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}CREATED${NC}"
    CREATED_FIELDS=$((CREATED_FIELDS + 1))
  else
    echo -e "${RED}FAILED (HTTP ${CREATE_HTTP_CODE})${NC}"
    echo "Response: $CREATE_BODY" | jq '.' 2>/dev/null || echo "$CREATE_BODY"
    FAILED_FIELDS=$((FAILED_FIELDS + 1))
  fi
}

# =================================================================
# VPC Fields (cmdb_ci_network)
# =================================================================
echo -e "\n${GREEN}Creating VPC fields (cmdb_ci_network)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_network" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "cmdb_ci_network" "u_cidr_block" "string" "CIDR Block" "50" "false"
create_custom_field "cmdb_ci_network" "u_region" "string" "AWS Region" "50" "false"
create_custom_field "cmdb_ci_network" "u_provider" "string" "Cloud Provider" "50" "false"
create_custom_field "cmdb_ci_network" "u_enable_dns_support" "boolean" "Enable DNS Support" "40" "false"
create_custom_field "cmdb_ci_network" "u_enable_dns_hostnames" "boolean" "Enable DNS Hostnames" "40" "false"
create_custom_field "cmdb_ci_network" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_network" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# Subnet Fields (cmdb_ci_network_segment)
# =================================================================
echo -e "\n${GREEN}Creating Subnet fields (cmdb_ci_network_segment)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_network_segment" "u_subnet_id" "string" "Subnet ID" "50" "false"
create_custom_field "cmdb_ci_network_segment" "u_cidr_block" "string" "CIDR Block" "50" "false"
create_custom_field "cmdb_ci_network_segment" "u_availability_zone" "string" "Availability Zone" "50" "false"
create_custom_field "cmdb_ci_network_segment" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "cmdb_ci_network_segment" "u_is_public" "boolean" "Is Public" "40" "false"
create_custom_field "cmdb_ci_network_segment" "u_available_ips" "integer" "Available IPs" "40" "false"
create_custom_field "cmdb_ci_network_segment" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_network_segment" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# Security Group Fields (cmdb_ci_firewall)
# =================================================================
echo -e "\n${GREEN}Creating Security Group fields (cmdb_ci_firewall)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_firewall" "u_security_group_id" "string" "Security Group ID" "50" "false"
create_custom_field "cmdb_ci_firewall" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "cmdb_ci_firewall" "u_ingress_rules" "integer" "Ingress Rules Count" "40" "false"
create_custom_field "cmdb_ci_firewall" "u_egress_rules" "integer" "Egress Rules Count" "40" "false"
create_custom_field "cmdb_ci_firewall" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_firewall" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# NAT Gateway Fields (cmdb_ci_network_adapter)
# =================================================================
echo -e "\n${GREEN}Creating NAT Gateway fields (cmdb_ci_network_adapter)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_network_adapter" "u_nat_gateway_id" "string" "NAT Gateway ID" "50" "false"
create_custom_field "cmdb_ci_network_adapter" "u_subnet_id" "string" "Subnet ID" "50" "false"
create_custom_field "cmdb_ci_network_adapter" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "cmdb_ci_network_adapter" "u_allocation_id" "string" "Elastic IP Allocation ID" "50" "false"
create_custom_field "cmdb_ci_network_adapter" "u_public_ip" "string" "Public IP Address" "50" "false"
create_custom_field "cmdb_ci_network_adapter" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"

# =================================================================
# EKS Cluster Fields (u_eks_cluster - custom table)
# =================================================================
echo -e "\n${GREEN}Creating EKS Cluster fields (u_eks_cluster)...${NC}"
echo "---------------------------------------------------------------"
echo -e "${YELLOW}Note: u_eks_cluster is a custom table. Ensure it exists before running this.${NC}"

create_custom_field "u_eks_cluster" "u_cluster_name" "string" "Cluster Name" "100" "true"
create_custom_field "u_eks_cluster" "u_cluster_arn" "string" "Cluster ARN" "255" "false"
create_custom_field "u_eks_cluster" "u_cluster_version" "string" "Kubernetes Version" "20" "false"
create_custom_field "u_eks_cluster" "u_cluster_endpoint" "string" "Cluster Endpoint" "255" "false"
create_custom_field "u_eks_cluster" "u_region" "string" "AWS Region" "50" "false"
create_custom_field "u_eks_cluster" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "u_eks_cluster" "u_node_groups_count" "integer" "Node Groups Count" "40" "false"
create_custom_field "u_eks_cluster" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "u_eks_cluster" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# ElastiCache Redis Fields (cmdb_ci_database_instance)
# =================================================================
echo -e "\n${GREEN}Creating ElastiCache Redis fields (cmdb_ci_database_instance)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_database_instance" "u_cache_cluster_id" "string" "Cache Cluster ID" "100" "false"
create_custom_field "cmdb_ci_database_instance" "u_replication_group_id" "string" "Replication Group ID" "100" "false"
create_custom_field "cmdb_ci_database_instance" "u_cache_node_type" "string" "Node Type" "50" "false"
create_custom_field "cmdb_ci_database_instance" "u_engine" "string" "Engine" "50" "false"
create_custom_field "cmdb_ci_database_instance" "u_engine_version" "string" "Engine Version" "50" "false"
create_custom_field "cmdb_ci_database_instance" "u_num_cache_nodes" "integer" "Number of Cache Nodes" "40" "false"
create_custom_field "cmdb_ci_database_instance" "u_cache_subnet_group" "string" "Cache Subnet Group" "100" "false"
create_custom_field "cmdb_ci_database_instance" "u_cache_parameter_group" "string" "Parameter Group" "100" "false"
create_custom_field "cmdb_ci_database_instance" "u_vpc_id" "string" "VPC ID" "50" "false"
create_custom_field "cmdb_ci_database_instance" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_database_instance" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# ECR Repository Fields (cmdb_ci_app_server)
# =================================================================
echo -e "\n${GREEN}Creating ECR Repository fields (cmdb_ci_app_server)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_app_server" "u_repository_name" "string" "Repository Name" "255" "false"
create_custom_field "cmdb_ci_app_server" "u_repository_arn" "string" "Repository ARN" "255" "false"
create_custom_field "cmdb_ci_app_server" "u_repository_uri" "string" "Repository URI" "255" "false"
create_custom_field "cmdb_ci_app_server" "u_registry_id" "string" "Registry ID" "50" "false"
create_custom_field "cmdb_ci_app_server" "u_region" "string" "AWS Region" "50" "false"
create_custom_field "cmdb_ci_app_server" "u_image_scan_on_push" "boolean" "Image Scan on Push" "40" "false"
create_custom_field "cmdb_ci_app_server" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_app_server" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# IAM Role Fields (cmdb_ci_service_account)
# =================================================================
echo -e "\n${GREEN}Creating IAM Role fields (cmdb_ci_service_account)...${NC}"
echo "---------------------------------------------------------------"

create_custom_field "cmdb_ci_service_account" "u_role_arn" "string" "Role ARN" "255" "false"
create_custom_field "cmdb_ci_service_account" "u_role_id" "string" "Role ID" "100" "false"
create_custom_field "cmdb_ci_service_account" "u_assume_role_policy" "string" "Assume Role Policy" "4000" "false"
create_custom_field "cmdb_ci_service_account" "u_path" "string" "IAM Path" "255" "false"
create_custom_field "cmdb_ci_service_account" "u_max_session_duration" "integer" "Max Session Duration" "40" "false"
create_custom_field "cmdb_ci_service_account" "u_last_discovered" "glide_date_time" "Last Discovered" "40" "false"
create_custom_field "cmdb_ci_service_account" "u_discovered_by" "string" "Discovered By" "100" "false"

# =================================================================
# Summary
# =================================================================
echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}Setup Complete${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo "Total fields processed: ${TOTAL_FIELDS}"
echo -e "${GREEN}Created: ${CREATED_FIELDS}${NC}"
echo -e "${YELLOW}Already existed: ${EXISTING_FIELDS}${NC}"
echo -e "${RED}Failed: ${FAILED_FIELDS}${NC}"
echo ""

if [ $FAILED_FIELDS -gt 0 ]; then
  echo -e "${RED}Some fields failed to create. Please review the output above.${NC}"
  exit 1
fi

echo -e "${GREEN}All custom fields have been successfully configured!${NC}"
echo ""
echo "Next steps:"
echo "1. Run the AWS Infrastructure Discovery workflow"
echo "2. Verify data in ServiceNow CMDB tables"
echo ""
