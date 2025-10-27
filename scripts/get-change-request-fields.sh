#!/usr/bin/env bash
# Get ServiceNow Change Request fields and their current values

set -euo pipefail

if [ -f .envrc ]; then
    source .envrc 2>/dev/null
fi

# Change request sys_id from our test
CR_SYSID="${1:-82fc3396c3743a54e1bbf0cb050131c8}"

echo "Fetching change request: $CR_SYSID"
echo ""

# Get the change request
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request/${CR_SYSID}" \
    | jq -r '.result | to_entries | map(select(.value != null and .value != "" and .value != "0" and .value != false)) | .[] | "\(.key): \(.value)"' \
    | sort

echo ""
echo "=========================="
echo "Key Fields for Automation:"
echo "=========================="
echo ""

# Get field schema
echo "Getting field definitions..."
curl -s -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=change_request^elementIN short_description,description,category,subcategory,assignment_group,assigned_to,priority,risk,impact,urgency,justification,implementation_plan,backout_plan,test_plan,business_service,cmdb_ci,cab_required,production_system,outside_maintenance_schedule,start_date,end_date,requested_by,type,state&sysparm_fields=element,column_label,internal_type,mandatory,max_length" \
    | jq -r '.result[] | "\(.column_label) (\(.element)): \(.internal_type) - Required: \(.mandatory) - Max: \(.max_length)"' \
    | sort
