#!/bin/bash
# ServiceNow Integration Verification Script
# This script pulls all data sent to ServiceNow and provides verification URLs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ServiceNow instance details
INSTANCE_URL="${SERVICENOW_INSTANCE_URL:-https://calitiiltddemo3.service-now.com}"
USERNAME="${SERVICENOW_USERNAME}"
PASSWORD="${SERVICENOW_PASSWORD}"

# Check required environment variables
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}ERROR: SERVICENOW_USERNAME and SERVICENOW_PASSWORD environment variables must be set${NC}"
    echo "Example:"
    echo "  export SERVICENOW_USERNAME='your-username'"
    echo "  export SERVICENOW_PASSWORD='your-password'"
    exit 1
fi

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}ServiceNow Integration Verification${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}Instance:${NC} $INSTANCE_URL"
echo -e "${GREEN}User:${NC} $USERNAME"
echo ""

# Function to make API calls
api_call() {
    local endpoint=$1
    local query=$2

    curl -s -u "$USERNAME:$PASSWORD" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "${INSTANCE_URL}/api/now/table/${endpoint}?${query}"
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 1. Check Change Requests
print_section "📋 Change Requests (Last 10)"
CHANGES=$(api_call "change_request" "sysparm_query=u_source%3DGitHub%20Actions%5EORDERBYDESCsys_created_on&sysparm_limit=10&sysparm_fields=number,sys_id,short_description,state,u_source,u_correlation_id,sys_created_on,assigned_to,approval")

echo "$CHANGES" | jq -r '.result[] |
"
Number:       \(.number)
Sys ID:       \(.sys_id)
Description:  \(.short_description)
State:        \(.state)
Source:       \(.u_source // "N/A")
Correlation:  \(.u_correlation_id // "N/A")
Created:      \(.sys_created_on)
URL:          '"$INSTANCE_URL"'/nav_to.do?uri=change_request.do?sys_id=\(.sys_id)
"' 2>/dev/null || echo -e "${YELLOW}No change requests found or error fetching data${NC}"

# 2. Check Test Results
print_section "🧪 Test Results (Last 10)"
TEST_RESULTS=$(api_call "sn_devops_test_result" "sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=10&sysparm_fields=test_suite_name,test_result,test_duration,correlation_id,sys_created_on")

echo "$TEST_RESULTS" | jq -r '.result[] |
"
Test Suite:   \(.test_suite_name)
Result:       \(.test_result)
Duration:     \(.test_duration)s
Correlation:  \(.correlation_id // "N/A")
Created:      \(.sys_created_on)
"' 2>/dev/null || echo -e "${YELLOW}No test results found or error fetching data${NC}"

# 3. Check Security Results
print_section "🔒 Security Scan Results (Last 10)"
SECURITY_RESULTS=$(api_call "sn_devops_security_result" "sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=10&sysparm_fields=security_tool,security_result_state,critical_count,high_count,medium_count,low_count,sys_created_on")

echo "$SECURITY_RESULTS" | jq -r '.result[] |
"
Tool:         \(.security_tool)
State:        \(.security_result_state)
Critical:     \(.critical_count // 0)
High:         \(.high_count // 0)
Medium:       \(.medium_count // 0)
Low:          \(.low_count // 0)
Created:      \(.sys_created_on)
"' 2>/dev/null || echo -e "${YELLOW}No security results found or error fetching data${NC}"

# 4. Check Work Items/Notes
print_section "📝 Work Items (Last 10)"
WORK_ITEMS=$(api_call "sn_devops_work_item" "sysparm_query=ORDERBYDESCsys_created_on&sysparm_limit=10&sysparm_fields=name,state,type,correlation_id,sys_created_on")

echo "$WORK_ITEMS" | jq -r '.result[] |
"
Name:         \(.name)
State:        \(.state)
Type:         \(.type)
Correlation:  \(.correlation_id // "N/A")
Created:      \(.sys_created_on)
"' 2>/dev/null || echo -e "${YELLOW}No work items found or error fetching data${NC}"

# 5. Check CMDB - EKS Clusters
print_section "☁️  EKS Clusters in CMDB"
EKS_CLUSTERS=$(api_call "u_eks_cluster" "sysparm_limit=10&sysparm_fields=name,cluster_version,cluster_status,vpc_id,sys_created_on")

echo "$EKS_CLUSTERS" | jq -r '.result[] |
"
Name:         \(.name)
Version:      \(.cluster_version)
Status:       \(.cluster_status)
VPC ID:       \(.vpc_id)
Created:      \(.sys_created_on)
"' 2>/dev/null || echo -e "${YELLOW}No EKS clusters found or CMDB not configured${NC}"

# 6. Check CMDB - Microservices
print_section "🔧 Microservices in CMDB"
MICROSERVICES=$(api_call "u_microservice" "sysparm_limit=10&sysparm_fields=name,namespace,replicas,image,sys_created_on")

echo "$MICROSERVICES" | jq -r '.result[] |
"
Name:         \(.name)
Namespace:    \(.namespace)
Replicas:     \(.replicas)
Image:        \(.image)
Created:      \(.sys_created_on)
"' 2>/dev/null || echo -e "${YELLOW}No microservices found or CMDB not configured${NC}"

# Summary and URLs
print_section "🔗 ServiceNow URLs for Manual Verification"
echo ""
echo -e "${GREEN}Change Management:${NC}"
echo "  ${INSTANCE_URL}/now/nav/ui/classic/params/target/change_request_list.do"
echo ""
echo -e "${GREEN}DevOps Changes:${NC}"
echo "  ${INSTANCE_URL}/now/devops-change/changes"
echo ""
echo -e "${GREEN}Test Results:${NC}"
echo "  ${INSTANCE_URL}/nav_to.do?uri=sn_devops_test_result_list.do"
echo ""
echo -e "${GREEN}Security Results:${NC}"
echo "  ${INSTANCE_URL}/nav_to.do?uri=sn_devops_security_result_list.do"
echo ""
echo -e "${GREEN}Work Items:${NC}"
echo "  ${INSTANCE_URL}/nav_to.do?uri=sn_devops_work_item_list.do"
echo ""
echo -e "${GREEN}CMDB - EKS Clusters:${NC}"
echo "  ${INSTANCE_URL}/nav_to.do?uri=u_eks_cluster_list.do"
echo ""
echo -e "${GREEN}CMDB - Microservices:${NC}"
echo "  ${INSTANCE_URL}/nav_to.do?uri=u_microservice_list.do"
echo ""
echo -e "${GREEN}DevOps Dashboard:${NC}"
echo "  ${INSTANCE_URL}/now/nav/ui/classic/params/target/sn_devops_dashboard.do"
echo ""

# Statistics
print_section "📊 Statistics"
CHANGE_COUNT=$(echo "$CHANGES" | jq -r '.result | length' 2>/dev/null || echo "0")
TEST_COUNT=$(echo "$TEST_RESULTS" | jq -r '.result | length' 2>/dev/null || echo "0")
SECURITY_COUNT=$(echo "$SECURITY_RESULTS" | jq -r '.result | length' 2>/dev/null || echo "0")
WORK_ITEM_COUNT=$(echo "$WORK_ITEMS" | jq -r '.result | length' 2>/dev/null || echo "0")
EKS_COUNT=$(echo "$EKS_CLUSTERS" | jq -r '.result | length' 2>/dev/null || echo "0")
MICROSERVICE_COUNT=$(echo "$MICROSERVICES" | jq -r '.result | length' 2>/dev/null || echo "0")

echo ""
echo -e "${GREEN}Total Records Found:${NC}"
echo "  Change Requests:      $CHANGE_COUNT"
echo "  Test Results:         $TEST_COUNT"
echo "  Security Results:     $SECURITY_COUNT"
echo "  Work Items:           $WORK_ITEM_COUNT"
echo "  EKS Clusters:         $EKS_COUNT"
echo "  Microservices:        $MICROSERVICE_COUNT"
echo ""

if [ "$CHANGE_COUNT" -eq "0" ] && [ "$TEST_COUNT" -eq "0" ]; then
    echo -e "${YELLOW}⚠️  Warning: No data found. Possible reasons:${NC}"
    echo "  1. No workflows have run yet"
    echo "  2. ServiceNow credentials are incorrect"
    echo "  3. ServiceNow DevOps plugin not configured"
    echo "  4. Custom fields (u_source, u_correlation_id) not created"
else
    echo -e "${GREEN}✅ ServiceNow integration is working!${NC}"
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Verification Complete${NC}"
echo -e "${BLUE}======================================${NC}"
