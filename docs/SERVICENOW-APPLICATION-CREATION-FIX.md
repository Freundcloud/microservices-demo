# ServiceNow Business Application Creation - Required Fields Fix

**Issue**: Business Rule requires "Application Category" field to be populated
**Error**: `Operation against file 'cmdb_ci_business_app' was aborted by Business Rule 'Check if Application Category is empty^b11c3f3e20a4fe907ac8a99253a30124'`

**Solution**: Include required Application Category field when creating Business Application

---

## Problem Details

When creating a Business Application in ServiceNow, you encountered this error:

```
Error in CI insert:
• Insertion failed with error: Operation against file 'cmdb_ci_business_app'
  was aborted by Business Rule 'Check if Application Category is empty^b11c3f3e20a4fe907ac8a99253a30124'.

IRE Error Code(s): [INSERT_FAILED]
```

**Root Cause**: ServiceNow has a Business Rule that validates the `application_category` field must not be empty when creating a Business Application.

---

## Solution: Create Business Application via ServiceNow UI

### Step 1: Navigate to Business Applications

1. Log in to ServiceNow: https://calitiiltddemo3.service-now.com
2. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
3. Click: **New**

### Step 2: Fill Required Fields

**Basic Information**:
- **Name**: `Online Boutique`
- **Operational Status**: `Operational`
- **Application Category**: `Service Delivery` ⭐ **REQUIRED**
- **Short Description**: `Cloud-native microservices demo application on AWS EKS`
- **Description**: `Microservices-based e-commerce demo featuring 11 services (Go, Python, Java, Node.js, C#) running on AWS EKS with Istio service mesh`

**Optional but Recommended**:
- **Owner**: Your ServiceNow user
- **Managed By**: Your ServiceNow user or support group
- **Support Group**: Your team's support group

### Step 3: Submit

1. Click: **Submit**
2. Note the sys_id from the URL or run the sys_id retrieval script

---

## Solution: Create Business Application via REST API

If you prefer automation, use this REST API call with the required fields:

```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)

# Application Category sys_id for "Service Delivery"
APP_CATEGORY_SYS_ID="18d3b632210e3b00964f98b7f95cf808"

# Create Business Application with required fields
curl -X POST \
  -H "Authorization: Basic ${BASIC_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Online Boutique",
    "operational_status": "1",
    "application_category": "'"${APP_CATEGORY_SYS_ID}"'",
    "short_description": "Cloud-native microservices demo application on AWS EKS",
    "description": "Microservices-based e-commerce demo featuring 11 services (Go, Python, Java, Node.js, C#) running on AWS EKS with Istio service mesh"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app" \
  | jq -r '.result.sys_id'
```

**Expected Output**: sys_id (32-character string)
```
1143d7f2c3acbe90e1bbf0cb0501318d
```

---

## Available Application Categories

Choose the most appropriate category for your application:

| Category | sys_id | Use Case |
|----------|--------|----------|
| Service Delivery | `18d3b632210e3b00964f98b7f95cf808` | **Recommended** - Service-based applications |
| Product Development | `08a2bafe21ca3b00964f98b7f95cf886` | Development-focused applications |
| Customer Care | `21947e32210e3b00964f98b7f95cf890` | Customer-facing applications |
| Sales | `6cf4db9bdba312003b9cffefbf961980` | E-commerce, sales applications |
| Business Intelligence | `2fc51f9bdba312003b9cffefbf96193f` | Analytics, reporting applications |

**Complete List**:
```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)
curl -s -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/apm_application_category?sysparm_fields=sys_id,name" \
  | jq -r '.result[] | "\(.name) - \(.sys_id)"'
```

---

## Verification

After creating the Business Application, verify it was created successfully:

### Option 1: ServiceNow UI
1. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Search for: **Online Boutique**
3. Verify fields:
   - ✅ Name: Online Boutique
   - ✅ Operational Status: Operational
   - ✅ Application Category: Service Delivery
   - ✅ Short Description: populated

### Option 2: REST API
```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)
curl -s -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app?sysparm_query=name=Online%20Boutique&sysparm_fields=sys_id,name,operational_status,application_category" \
  | jq .
```

**Expected Output**:
```json
{
  "result": [
    {
      "sys_id": "1143d7f2c3acbe90e1bbf0cb0501318d",
      "name": "Online Boutique",
      "operational_status": "1",
      "application_category": {
        "link": "https://calitiiltddemo3.service-now.com/api/now/table/apm_application_category/18d3b632210e3b00964f98b7f95cf808",
        "value": "18d3b632210e3b00964f98b7f95cf808"
      }
    }
  ]
}
```

---

## Updated Quick Start Script

I've created an automated script that includes the required Application Category field:

**[scripts/create-servicenow-application.sh](../scripts/create-servicenow-application.sh)**

```bash
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD='oA3KqdUVI8Q_^>'
bash scripts/create-servicenow-application.sh
```

**What it does**:
- Checks if "Online Boutique" application already exists
- Creates application with required Application Category field
- Returns sys_id for GitHub secret configuration
- Provides next steps

---

## Next Steps

After creating the Business Application:

1. **Get sys_id**:
   ```bash
   bash scripts/get-servicenow-app-sys-id.sh
   ```

2. **Configure GitHub Secret**:
   ```bash
   gh secret set SERVICENOW_APP_SYS_ID --body "<sys_id>"
   ```

3. **Map Service Dependencies**:
   ```bash
   bash scripts/map-service-dependencies.sh
   ```

4. **Test Deployment**:
   ```bash
   gh workflow run deploy-with-servicenow-basic.yaml --field environment=dev
   ```

---

## Troubleshooting

### Problem: Application already exists but missing Application Category

**Solution**: Update existing application via REST API:
```bash
PASSWORD='oA3KqdUVI8Q_^>'
BASIC_AUTH=$(echo -n "github_integration:$PASSWORD" | base64)
APP_CATEGORY_SYS_ID="18d3b632210e3b00964f98b7f95cf808"

# Get existing application sys_id
APP_SYS_ID=$(curl -s -H "Authorization: Basic ${BASIC_AUTH}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app?sysparm_query=name=Online%20Boutique&sysparm_fields=sys_id" \
  | jq -r '.result[0].sys_id')

# Update with Application Category
curl -X PATCH \
  -H "Authorization: Basic ${BASIC_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
    "application_category": "'"${APP_CATEGORY_SYS_ID}"'"
  }' \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app/${APP_SYS_ID}" \
  | jq .
```

### Problem: Different Application Category needed

**Solution**: Choose from available categories:
1. List all categories: See "Available Application Categories" section above
2. Update script with desired category sys_id
3. Re-run application creation or update

---

## Summary

**Issue**: Missing required `application_category` field
**Solution**: Include "Service Delivery" (or appropriate category) when creating Business Application
**Status**: ✅ Fix documented with automated script

**Continue with**: [SERVICENOW-APPLICATION-QUICKSTART.md](SERVICENOW-APPLICATION-QUICKSTART.md) after creating application
