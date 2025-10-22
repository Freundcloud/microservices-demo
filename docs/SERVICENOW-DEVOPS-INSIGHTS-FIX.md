# ServiceNow DevOps Insights Dashboard - Fix Empty Data

## Problem Statement

**Issue**: DevOps Change Insights Home dashboard is empty
- URL: https://calitiiltddemo3.service-now.com/now/devops-change/insights-home
- No metrics, charts, or data displayed
- Even though deployments and change requests exist

## Root Cause

Based on recent ServiceNow community forums (2025), the most common reason for empty DevOps Insights dashboards is:

**Missing Product Association**: DevOps applications must be grouped into a Product for the insights data collection jobs to populate metrics.

### Key Missing Component

The table `sn_devops_insights_application_product_detail` is empty, which prevents:
- Change Acceleration tab data
- Deployment frequency metrics
- Lead time for changes
- Mean time to recovery (MTTR)
- Change failure rate

## Solution Overview

There are **two approaches** to fix this:

### Approach A: Manual UI Configuration (Recommended for Demo)
Configure via ServiceNow UI - easier for demos and testing

### Approach B: API/Script Automation (Recommended for Production)
Automate via REST API - better for repeatability and CI/CD

---

## Approach A: Manual UI Configuration

### Step 1: Create a Product

1. **Navigate to DevOps Products**:
   - Filter Navigator → Type: "DevOps Products"
   - Or: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_product_list.do

2. **Create New Product**:
   - Click "New" button
   - Fill in:
     - **Name**: Online Boutique Platform
     - **Description**: Cloud-native microservices demo application
     - **Active**: Checked
     - **Owner**: (Your user or github_integration)
   - Click "Submit"

3. **Note the Product sys_id** from the URL after creation

### Step 2: Associate Application with Product

1. **Open your DevOps Application**:
   - https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120

2. **Edit Application**:
   - Look for "Product" field (may need to configure form layout if not visible)
   - Select "Online Boutique Platform" (the product you just created)
   - Click "Update"

**Alternative if Product field doesn't exist**:
Navigate to the product record and look for an "Applications" related list where you can add the DevOps application.

### Step 3: Run Data Collection Jobs

ServiceNow has scheduled jobs that populate the insights data. Manually trigger them:

1. **Navigate to Scheduled Jobs**:
   - Filter Navigator → Type: "Scheduled Jobs"
   - Or: System Definition → Scheduled Jobs

2. **Find and Run These Jobs**:

   **Job 1**: "[DevOps] Update Repo Details and Work Item State Details"
   - Find this job in the list
   - Right-click → Execute Now
   - This populates `sn_devops_insights_application_product_detail`

   **Job 2**: "[DevOps] Historical Data Collection"
   - Find this job in the list
   - Right-click → Execute Now
   - This populates historical metrics for charts

   **Job 3**: "[DevOps] Daily Data Collection"
   - Find this job in the list
   - Right-click → Execute Now
   - This populates daily metrics

3. **Wait for Jobs to Complete** (5-15 minutes depending on data volume)

### Step 4: Verify Data View

Check if data is now available in the database view:

1. **Navigate to**:
   - Filter Navigator → Type: "sn_devops_insights_change_request_standalone_v2"
   - Or Tables & Columns → Database Views

2. **Open the view** and check if records now exist

3. **If data appears**, the Insights dashboard should now show metrics!

### Step 5: Refresh Insights Dashboard

1. **Navigate to**: https://calitiiltddemo3.service-now.com/now/devops-change/insights-home
2. **Refresh the page** (Ctrl+F5 or Cmd+Shift+R)
3. **Check for data** in:
   - Change Acceleration tab
   - Deployment Frequency
   - Lead Time for Changes
   - Mean Time to Recovery
   - Change Failure Rate

---

## Approach B: API/Script Automation

### Prerequisites

- ServiceNow admin or elevated permissions
- API access to create products and update applications
- jq installed for JSON parsing

### Script to Create Product and Associate Application

```bash
#!/bin/bash

# ServiceNow Configuration
SERVICENOW_INSTANCE="https://calitiiltddemo3.service-now.com"
SERVICENOW_USERNAME="github_integration"
SERVICENOW_PASSWORD="YOUR_PASSWORD"

DEVOPS_APP_SYS_ID="6047e45ac3e4f690e1bbf0cb05013120"

echo "Step 1: Creating DevOps Product..."

# Create Product
PRODUCT_PAYLOAD=$(cat <<'EOF'
{
  "name": "Online Boutique Platform",
  "description": "Cloud-native microservices demo application on AWS EKS",
  "active": true
}
EOF
)

PRODUCT_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$PRODUCT_PAYLOAD" \
  "$SERVICENOW_INSTANCE/api/now/table/sn_devops_product")

PRODUCT_HTTP_CODE=$(echo "$PRODUCT_RESPONSE" | tail -n1)
PRODUCT_BODY=$(echo "$PRODUCT_RESPONSE" | sed '$d')

if [ "$PRODUCT_HTTP_CODE" == "201" ]; then
  PRODUCT_SYS_ID=$(echo "$PRODUCT_BODY" | jq -r '.result.sys_id')
  echo "✓ Product created: $PRODUCT_SYS_ID"
else
  echo "✗ Failed to create product (HTTP $PRODUCT_HTTP_CODE)"
  echo "$PRODUCT_BODY" | jq .
  exit 1
fi

echo ""
echo "Step 2: Associating Application with Product..."

# Update DevOps Application with product reference
APP_UPDATE_PAYLOAD=$(cat <<EOF
{
  "product": "$PRODUCT_SYS_ID"
}
EOF
)

APP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PATCH \
  -H "Content-Type: application/json" \
  --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -d "$APP_UPDATE_PAYLOAD" \
  "$SERVICENOW_INSTANCE/api/now/table/sn_devops_app/$DEVOPS_APP_SYS_ID")

APP_HTTP_CODE=$(echo "$APP_RESPONSE" | tail -n1)

if [ "$APP_HTTP_CODE" == "200" ]; then
  echo "✓ Application associated with product"
else
  echo "✗ Failed to update application (HTTP $APP_HTTP_CODE)"
  echo "$APP_RESPONSE" | sed '$d' | jq .
  exit 1
fi

echo ""
echo "Step 3: Triggering Data Collection Jobs..."
echo "You need to manually run these scheduled jobs in ServiceNow UI:"
echo "  1. [DevOps] Update Repo Details and Work Item State Details"
echo "  2. [DevOps] Historical Data Collection"
echo "  3. [DevOps] Daily Data Collection"
echo ""
echo "Or wait for them to run on their scheduled time."
```

### Trigger Scheduled Jobs via API (Advanced)

```bash
# Get scheduled job sys_id
JOB_NAME="[DevOps] Update Repo Details and Work Item State Details"

JOB_RESPONSE=$(curl -s --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/sysauto?sysparm_query=nameLIKE$JOB_NAME&sysparm_fields=sys_id,name" \
  | jq -r '.result[0].sys_id')

# Execute job
curl -X POST --user "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/sysauto/$JOB_RESPONSE/execute"
```

---

## Troubleshooting

### Issue: Product field not visible on DevOps Application form

**Solution**: Add the field to the form layout
1. Navigate to sn_devops_app form
2. Configure → Form Layout
3. Add "Product" field to the form
4. Save

### Issue: Jobs running but dashboard still empty

**Checks**:
1. Verify product association:
   ```bash
   curl -s --user 'USER:PASS' \
     "https://instance.service-now.com/api/now/table/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120?sysparm_fields=product" \
     | jq '.result.product'
   ```

2. Check if `sn_devops_insights_application_product_detail` has records:
   ```bash
   curl -s --user 'USER:PASS' \
     "https://instance.service-now.com/api/now/table/sn_devops_insights_application_product_detail?sysparm_limit=1" \
     | jq '.result | length'
   ```

3. Check job execution history:
   - Navigate to: System Logs → Scheduled Jobs History
   - Look for "[DevOps]" jobs
   - Check for errors in execution

### Issue: API returns "Invalid table sn_devops_product"

**Possible causes**:
1. DevOps plugins not fully installed
2. Insufficient user permissions
3. ServiceNow version doesn't have this table

**Solution**: Use UI approach instead, or check with ServiceNow admin

### Issue: Still no data after 30+ minutes

**Advanced troubleshooting**:
1. Check system logs for errors:
   - Navigate to: System Logs → System Log → All
   - Filter by: Source contains "DevOps"
   - Look for exceptions

2. Verify change requests have required fields:
   ```bash
   curl -s --user 'USER:PASS' \
     "https://instance.service-now.com/api/now/table/change_request?sysparm_query=category=DevOps&sysparm_fields=number,category,devops_change,business_service" \
     | jq '.result[] | {number, category, devops_change, business_service: .business_service.value}'
   ```

3. Check if deployments are linked to changes:
   - Navigate to: DevOps → Deployments
   - Open a deployment record
   - Check if "Change Request" field is populated

---

## Expected Timeline

- **Product creation**: Immediate
- **Application association**: Immediate
- **Data collection jobs**: 5-15 minutes per job
- **Dashboard population**: 20-30 minutes total

---

## Alternative: Use Existing Change Requests for Metrics

If you have historical change requests but insights dashboard is empty, the jobs need to process existing data.

### Manual Workaround

1. Open existing change requests
2. Add/verify these fields are populated:
   - `category` = "DevOps"
   - `devops_change` = true
   - `business_service` = (linked to service)
   - `u_tool_id` = (GitHub tool ID)

3. Re-run Historical Data Collection job

---

## Verification Checklist

After completing the fix:

- [ ] Product created in ServiceNow
- [ ] DevOps application associated with product
- [ ] Data collection jobs executed successfully
- [ ] `sn_devops_insights_application_product_detail` has records
- [ ] View `sn_devops_insights_change_request_standalone_v2` has data
- [ ] Insights dashboard shows metrics
- [ ] Charts display data (Change Acceleration, Deployment Frequency, etc.)

---

## Related Documentation

- [SERVICENOW-DEVOPS-CHANGE-SERVICES-FIX.md](SERVICENOW-DEVOPS-CHANGE-SERVICES-FIX.md) - Services association fix
- ServiceNow Community: "Issue with DevOps Insights Dashboard" (2025)
- ServiceNow Docs: DevOps Insights Standard Dashboard

---

## Summary

**Key Takeaways**:
1. DevOps Insights requires applications to be grouped into Products
2. Data collection jobs must run after product association
3. The `sn_devops_insights_application_product_detail` table is critical
4. UI approach is faster for demos, API approach is better for automation

**Next Steps**:
1. Create product via UI (5 minutes)
2. Associate application with product (2 minutes)
3. Run data collection jobs (15-20 minutes)
4. Verify insights dashboard (1 minute)

**Total Time**: ~30 minutes

---

**Last Updated**: 2025-10-22
**Status**: Solution documented - User needs to create product in ServiceNow UI
**Priority**: Medium - Dashboard visibility for demos
