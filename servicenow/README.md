# ServiceNow Configuration Files

This directory contains ServiceNow configuration files for the AWS Infrastructure Discovery integration.

## Files

### AWS_CMDB_Custom_Fields_Update_Set.xml

**Purpose:** ServiceNow Update Set containing all custom field definitions (u_* fields) required for AWS Infrastructure Discovery.

**What it does:**
- Creates all required custom fields on CMDB tables
- Defines field types, labels, and max lengths
- Can be imported directly into ServiceNow without manual field creation

**Tables Modified:**
- `cmdb_ci_network` - VPC resources (8 fields)
- `cmdb_ci_network_segment` - Subnet resources (8 fields)
- `cmdb_ci_firewall` - Security Groups (6 fields)
- `cmdb_ci_network_adapter` - NAT Gateways (6 fields)
- `cmdb_ci_database_instance` - ElastiCache Redis (11 fields)
- `cmdb_ci_app_server` - ECR Repositories (8 fields)
- `cmdb_ci_service_account` - IAM Roles (7 fields)
- `u_eks_cluster` - EKS Clusters (9 fields) **Note: Custom table must exist first**

**Total Fields:** 63 custom fields

## How to Import the Update Set

### Method 1: Via ServiceNow UI (Recommended)

1. **Login to ServiceNow**
   - Navigate to your ServiceNow instance
   - Login with admin credentials

2. **Navigate to Update Sets**
   - Go to **System Update Sets → Retrieved Update Sets**
   - Or search for "Retrieved Update Sets" in the filter navigator

3. **Import XML File**
   - Click **Import Update Set from XML**
   - Select `AWS_CMDB_Custom_Fields_Update_Set.xml` from this directory
   - Click **Upload**

4. **Preview Update Set**
   - Find the imported Update Set: "AWS CMDB Custom Fields"
   - Click on it to open
   - Click **Preview Update Set** button
   - Review the preview results for any conflicts or errors

5. **Commit Update Set**
   - If preview is successful, click **Commit Update Set**
   - Wait for the commit to complete
   - Verify all records are committed successfully

6. **Verify Installation**
   - Navigate to **System Definition → Tables**
   - Open each table (e.g., cmdb_ci_network)
   - Click **Columns** related list
   - Verify the u_* fields are present

### Method 2: Via API

```bash
# Set your ServiceNow credentials
export SERVICENOW_INSTANCE_URL="https://your-instance.service-now.com"
export SERVICENOW_USERNAME="admin"
export SERVICENOW_PASSWORD="your-password"

# Import the Update Set
curl -X POST \
  "${SERVICENOW_INSTANCE_URL}/api/now/import/sys_remote_update_set" \
  -H "Authorization: Basic $(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)" \
  -H "Content-Type: application/xml" \
  --data-binary @servicenow/AWS_CMDB_Custom_Fields_Update_Set.xml
```

### Method 3: Via GitHub Actions Workflow (Automated)

**Prerequisites:**
- ServiceNow credentials configured as GitHub secrets:
  - `SERVICENOW_INSTANCE_URL`
  - `SERVICENOW_USERNAME`
  - `SERVICENOW_PASSWORD`

**Steps:**
1. Go to **Actions** tab in GitHub
2. Select **Setup ServiceNow CMDB for AWS Discovery** workflow
3. Click **Run workflow**
4. Choose dry run mode to check existing fields (optional)
5. Click **Run workflow** to execute

This method uses the script in `scripts/setup-servicenow-fields.sh` to create fields via API.

## Prerequisites

### Before Importing

1. **Admin Privileges**
   - User must have `admin` role or equivalent permissions
   - Must have rights to modify sys_dictionary table

2. **Custom Table (u_eks_cluster)**
   - If you plan to use EKS discovery, create the `u_eks_cluster` table first:
     - Go to **System Definition → Tables**
     - Click **New**
     - Name: `u_eks_cluster`
     - Label: `EKS Cluster`
     - Extends: `cmdb_ci_cluster` (or `cmdb_ci`)
     - Create application file: Yes
     - Save

3. **Backup (Optional but Recommended)**
   - Create a backup update set before importing
   - Go to **System Update Sets → Local Update Sets**
   - Capture current state of affected tables

## Verification

After importing the Update Set, verify the fields are created:

### Via UI
```
1. Navigate to: System Definition → Dictionary
2. Filter by "Name" containing one of the tables (e.g., cmdb_ci_network)
3. Filter by "Column label" starting with "u_"
4. Verify all expected fields are present
```

### Via API
```bash
# Check VPC fields
curl -X GET \
  "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=cmdb_ci_network^elementSTARTSWITHu_&sysparm_fields=element,column_label" \
  -H "Authorization: Basic $(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)"

# Should return 8 fields: u_vpc_id, u_cidr_block, u_region, u_provider,
# u_enable_dns_support, u_enable_dns_hostnames, u_last_discovered, u_discovered_by
```

### Via Script
```bash
# Run the setup script in dry-run mode
cd /path/to/microservices-demo
export SERVICENOW_INSTANCE_URL="https://your-instance.service-now.com"
export SERVICENOW_USERNAME="admin"
export SERVICENOW_PASSWORD="your-password"

bash scripts/setup-servicenow-fields.sh
```

## Troubleshooting

### Import Failed

**Symptom:** Update Set import fails with errors

**Causes & Solutions:**

1. **XML Syntax Error**
   - Validate XML file is not corrupted
   - Re-download from repository

2. **Permission Denied**
   - User needs `admin` role
   - Check user has rights to sys_dictionary table

3. **Table Doesn't Exist**
   - u_eks_cluster table must be created manually first
   - Create table before importing Update Set

### Preview Errors

**Symptom:** Preview shows errors or conflicts

**Solutions:**

1. **Field Already Exists**
   - This is OK - Update Set will update existing field
   - Review if field type/length matches

2. **Table Not Found**
   - For u_eks_cluster: Create table first
   - For other tables: Verify ServiceNow version (tables should exist in standard CMDB)

### Commit Failed

**Symptom:** Commit fails after successful preview

**Solutions:**

1. **Database Lock**
   - Wait a few minutes and retry
   - No other user should be modifying the same tables

2. **Invalid Field Type**
   - Review field definitions in XML
   - Check compatibility with ServiceNow version

## Rollback

If you need to remove the custom fields:

### Method 1: Via Update Set Rollback

1. Go to **System Update Sets → Committed Update Sets**
2. Find "AWS CMDB Custom Fields"
3. Click **Rollback** (if available in your ServiceNow version)

### Method 2: Manual Deletion

1. Go to **System Definition → Dictionary**
2. Filter by "Column label" starting with "u_"
3. Select each AWS-related custom field
4. Delete (be careful - this is irreversible)

### Method 3: Via API Script

```bash
# WARNING: This will delete all u_* fields from specified tables
# Review carefully before executing

export SERVICENOW_INSTANCE_URL="https://your-instance.service-now.com"
export SERVICENOW_USERNAME="admin"
export SERVICENOW_PASSWORD="your-password"

BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# List of tables
TABLES=("cmdb_ci_network" "cmdb_ci_network_segment" "cmdb_ci_firewall" "cmdb_ci_network_adapter" "cmdb_ci_database_instance" "cmdb_ci_app_server" "cmdb_ci_service_account" "u_eks_cluster")

for table in "${TABLES[@]}"; do
  echo "Removing u_* fields from $table..."

  # Get all u_* fields for this table
  FIELDS=$(curl -s -X GET \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=${table}^elementSTARTSWITHu_&sysparm_fields=sys_id" \
    -H "Authorization: Basic ${BASIC_AUTH}" | jq -r '.result[].sys_id')

  # Delete each field
  for field_id in $FIELDS; do
    curl -X DELETE \
      "${SERVICENOW_INSTANCE_URL}/api/now/table/sys_dictionary/${field_id}" \
      -H "Authorization: Basic ${BASIC_AUTH}"
    echo "  Deleted field: $field_id"
  done
done

echo "Rollback complete"
```

## Next Steps

After successfully importing the Update Set:

1. **Run AWS Infrastructure Discovery**
   - Go to GitHub Actions
   - Run "AWS Infrastructure Discovery" workflow
   - Verify data populates in ServiceNow CMDB

2. **Verify Data in ServiceNow**
   - Navigate to **Configuration → Configuration Management → All CIs**
   - Search for your VPC, Subnets, EKS clusters, etc.
   - Verify custom fields contain data

3. **Review Relationships**
   - Go to **Configuration → Relationship Types**
   - View "Contains::Contained by" relationships
   - Verify VPC → Subnet relationships exist

## Related Documentation

- [AWS Infrastructure Discovery Guide](../docs/AWS-INFRASTRUCTURE-DISCOVERY-GUIDE.md) - Complete documentation
- [AWS Discovery Workflow](../.github/workflows/aws-infrastructure-discovery.yaml) - GitHub Actions workflow
- [Setup Script](../scripts/setup-servicenow-fields.sh) - Automated field creation script

## Support

For issues or questions:
- Review detailed logs in GitHub Actions workflow runs
- Check ServiceNow system logs: **System Logs → System Log → All**
- Consult [AWS-INFRASTRUCTURE-DISCOVERY-GUIDE.md](../docs/AWS-INFRASTRUCTURE-DISCOVERY-GUIDE.md)
- Open an issue in the repository

---

**Version:** 1.0.0
**Last Updated:** 2025-10-20
**Maintainer:** DevSecOps Team
