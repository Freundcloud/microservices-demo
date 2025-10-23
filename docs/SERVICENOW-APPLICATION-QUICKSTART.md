# ServiceNow Application Setup - Quick Start

**Goal**: Make change requests visible in DevOps Change workspace with full service dependency tracking.

**Time required**: 10 minutes

## Prerequisites

- ServiceNow instance: https://calitiiltddemo3.service-now.com
- GitHub repository access to configure secrets

---

## Step 0: Create Business Application (if not already done)

**If you haven't created the "Online Boutique" application yet**, you need to create it first with the required **Application Category** field.

### Quick Creation via Script (Recommended)
```bash
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD='<your-password>'
bash scripts/create-servicenow-application.sh
```

### Manual Creation via ServiceNow UI
1. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Click: **New**
3. Fill in:
   - **Name**: `Online Boutique`
   - **Operational Status**: `Operational`
   - **Application Category**: `Service Delivery` ⭐ **REQUIRED**
   - **Short Description**: `Cloud-native microservices demo application on AWS EKS`
4. Click: **Submit**

**Important**: The Application Category field is **required** by a ServiceNow Business Rule. If you get an error about "Application Category is empty", see [SERVICENOW-APPLICATION-CREATION-FIX.md](SERVICENOW-APPLICATION-CREATION-FIX.md) for details.

---

## Step 1: Get Application sys_id (2 minutes)

### Option A: Via ServiceNow UI
1. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Search for: **Online Boutique**
3. Click on the application
4. In the URL, copy the sys_id parameter:
   ```
   https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                                                                          ↑ Copy this 32-character ID
   ```

### Option B: Via REST API (Automated)
```bash
PASSWORD='<your-password>'
curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app?sysparm_query=name=Online%20Boutique&sysparm_fields=sys_id,name" \
  | jq -r '.result[0].sys_id'
```

**Save this sys_id** - you'll need it in the next step.

---

## Step 2: Configure GitHub Secret (2 minutes)

### Via GitHub UI:
1. Go to: https://github.com/Freundcloud/microservices-demo/settings/secrets/actions
2. Click: **New repository secret**
3. Name: `SERVICENOW_APP_SYS_ID`
4. Value: `<paste-sys_id-from-step-1>`
5. Click: **Add secret**

### Via GitHub CLI (if installed):
```bash
gh secret set SERVICENOW_APP_SYS_ID --body "<paste-sys_id-here>"
```

---

## Step 3: Map Service Dependencies (3 minutes)

This creates CMDB relationships for all 11 microservices showing their dependencies.

```bash
# Set environment variables
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD='<your-password>'

# Run dependency mapping script
bash scripts/map-service-dependencies.sh
```

**Expected output**:
```
═══════════════════════════════════════════════════════════════
       ServiceNow Service Dependency Mapping
═══════════════════════════════════════════════════════════════

[INFO] Verifying services in CMDB...
[SUCCESS] ✓ frontend
[SUCCESS] ✓ cartservice
[SUCCESS] ✓ productcatalogservice
... (all 11 services)

[INFO] Mapping dependencies for namespace: microservices-dev
[SUCCESS] Created: frontend → cartservice
[SUCCESS] Created: frontend → productcatalogservice
... (all dependencies)

Total relationships: 33
```

**What this does**:
- Verifies all 11 microservices exist in CMDB
- Creates parent-child relationships:
  - `frontend` → `cartservice`, `productcatalogservice`, `currencyservice`, etc.
  - `cartservice` → `redis-cart`
  - `checkoutservice` → `paymentservice`, `shippingservice`, `emailservice`, `currencyservice`
- Maps for all 3 namespaces: dev, qa, prod

---

## Step 4: Verify in ServiceNow UI (3 minutes)

### View Application:
1. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Search for: **Online Boutique**
3. Click on the application
4. You should see:
   - **Services** tab: All 11 microservices listed
   - **Related Lists** section: Shows relationships

### View Dependencies:
1. Navigate to: **Configuration** → **CMDB** → **CI Relationship Editor**
2. Search for: **frontend**
3. Click: **Visualize** → **Dependency View**
4. You should see the complete service dependency graph:
   ```
   frontend
   ├── cartservice
   │   └── redis-cart
   ├── productcatalogservice
   ├── currencyservice
   ├── recommendationservice
   ├── adservice
   └── checkoutservice
       ├── paymentservice
       ├── shippingservice
       ├── emailservice
       └── currencyservice
   ```

### View DevOps Change Workspace:
1. Navigate to: **DevOps Change** → **Change Requests**
2. Or direct link: https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
3. **Important**: You won't see any change requests yet until you trigger a deployment (next step)

---

## Step 5: Test Deployment with Application Association (2 minutes)

Trigger a deployment to create a change request with application association:

### Via GitHub UI:
1. Go to: https://github.com/Freundcloud/microservices-demo/actions/workflows/deploy-with-servicenow-basic.yaml
2. Click: **Run workflow**
3. Select environment: **dev**
4. Click: **Run workflow**

### Via GitHub CLI:
```bash
gh workflow run deploy-with-servicenow-basic.yaml --field environment=dev
```

**What happens**:
1. Workflow creates change request with:
   - `business_service`: Points to "Online Boutique" application
   - `cmdb_ci`: Links to application CI
   - `u_application`: "Online Boutique" (custom field)
2. For dev environment: Auto-approved immediately
3. Deployment proceeds
4. Change request updated with deployment results

---

## Step 6: Verify Change Request Visibility

### In DevOps Change Workspace:
1. Navigate to: **DevOps Change** → **Change Requests**
2. You should now see the change request:
   - **Application**: Online Boutique
   - **Environment**: dev
   - **Status**: Closed Complete (if successful)
   - **Related Services**: All 11 microservices

### In Application View:
1. Navigate to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Click: **Online Boutique**
3. Click: **Changes** tab
4. You should see all change requests associated with this application

---

## Verification Checklist

- [ ] Application sys_id retrieved from ServiceNow
- [ ] GitHub secret `SERVICENOW_APP_SYS_ID` configured
- [ ] Dependency mapping script executed successfully
- [ ] All 11 services verified in CMDB
- [ ] 33+ relationships created (11 services × 3 namespaces)
- [ ] Dependency visualization works in ServiceNow
- [ ] Test deployment triggered
- [ ] Change request visible in DevOps Change workspace
- [ ] Change request associated with "Online Boutique" application
- [ ] Related services visible in change request

---

## Troubleshooting

### Problem: "Application Category is empty" error
**Symptom**:
```
Error in CI insert:
• Insertion failed with error: Operation against file 'cmdb_ci_business_app'
  was aborted by Business Rule 'Check if Application Category is empty'
```

**Solution**: The Application Category field is **required**. Use the automated script which includes this field:
```bash
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD='<your-password>'
bash scripts/create-servicenow-application.sh
```

Or manually set "Application Category" to "Service Delivery" when creating via UI.

**Details**: See [SERVICENOW-APPLICATION-CREATION-FIX.md](SERVICENOW-APPLICATION-CREATION-FIX.md) for complete fix documentation.

### Problem: Services not found in CMDB
**Symptom**: `map-service-dependencies.sh` reports services missing

**Solution**: Services are created by EKS discovery workflow. Trigger it:
```bash
gh workflow run eks-discovery.yaml
# Wait 5 minutes for discovery to complete
# Then re-run dependency mapping
```

### Problem: Change requests still not visible in DevOps Change workspace
**Checks**:
1. Verify secret is set: `gh secret list | grep SERVICENOW_APP_SYS_ID`
2. Check workflow run logs: Look for "business_service" field in change request payload
3. Verify application sys_id is correct: Compare with ServiceNow UI
4. Check ServiceNow application: Ensure it's active and not archived

### Problem: Relationship creation fails
**Symptom**: "Failed to create relationship" errors

**Solution**:
1. Verify ServiceNow user has permissions:
   ```bash
   PASSWORD='oA3KqdUVI8Q_^>'
   curl -s -u "github_integration:$PASSWORD" \
     "https://calitiiltddemo3.service-now.com/api/now/table/sys_user_role_contains?sysparm_query=user.user_name=github_integration"
   ```
2. User needs roles: `admin` or `cmdb_admin`

### Problem: Duplicate relationships
**Symptom**: "Relationship already exists" warnings

**Solution**: This is normal! Script checks for existing relationships before creating. Warnings indicate the relationship was already mapped (safe to ignore).

---

## What You Get

### Service Dependency Tracking
- Complete visibility of which services depend on each other
- Automatic impact analysis when a service fails
- Health monitoring across the entire application

### DevOps Change Workspace
- All change requests in one place
- Filtered by application: "Online Boutique"
- Approval tracking and status
- Deployment history

### CMDB Integration
- Business Application "Online Boutique" as central CI
- All 11 microservices linked as child CIs
- Relationship graph showing dependencies
- Foundation for automated change risk assessment

### Health Monitoring
When a service fails:
1. ServiceNow identifies which services depend on it
2. Automatically assesses impact
3. Can notify stakeholders of affected services
4. Helps prioritize incident response

---

## Next Steps

### Optional Enhancements:

1. **Configure Health Monitoring**:
   - Set up Service Watch for automatic health checks
   - Configure alerts when services go down
   - See: [SERVICENOW-APPLICATION-SETUP.md](SERVICENOW-APPLICATION-SETUP.md#step-5-configure-health-monitoring-optional)

2. **Create Custom Dashboard**:
   - Visual representation of all services
   - Real-time health status
   - Deployment history
   - Pending approvals

3. **Enable Automated Change Risk Assessment**:
   - ServiceNow Predictive Intelligence
   - Analyzes past changes to predict risk
   - Requires ServiceNow ITSM Pro license

---

## Reference

- **Complete Guide**: [SERVICENOW-APPLICATION-SETUP.md](SERVICENOW-APPLICATION-SETUP.md)
- **Approval Workflow**: [SERVICENOW-APPROVALS.md](SERVICENOW-APPROVALS.md)
- **ServiceNow Documentation**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/task/app-create-workspace.html

---

**Time to complete**: ~10 minutes
**Complexity**: Low (mostly point-and-click)
**Impact**: High (complete visibility and change tracking)
