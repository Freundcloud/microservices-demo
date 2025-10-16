# ServiceNow Navigation - Correct URLs

**Instance**: https://calitiiltddemo3.service-now.com

This document provides the correct URLs for accessing various ServiceNow features for the Online Boutique integration.

---

## Change Management

### All Change Requests
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/change_request_list.do
```

**Navigation**:
- Left menu: **Change** → **All**
- Or search for: "Change Request" in the filter navigator

### Change Requests for "Online Boutique" Application
**Direct URL** (filtered by application):
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
```

**Navigation**:
1. Go to: **Change** → **All**
2. Click filter icon
3. Add condition: `Business Service` = `Online Boutique`
4. Click: Run

---

## CMDB - Configuration Items

### Business Applications
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/cmdb_ci_business_app_list.do
```

**Navigation**:
- Left menu: **Configuration** → **CMDB** → **Applications** → **Business Applications**

### View "Online Boutique" Application
**Direct URL** (if you have the sys_id):
```
https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=4ffc7bfec3a4fe90e1bbf0cb0501313f
```

**Navigation**:
1. Go to: **Configuration** → **CMDB** → **Applications** → **Business Applications**
2. Search for: `Online Boutique`
3. Click on the record

### All Servers (EKS Nodes)
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/cmdb_ci_server_list.do
```

**Navigation**:
- Left menu: **Configuration** → **CMDB** → **Servers** → **All**

### EKS Cluster
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/u_eks_cluster_list.do
```

**Navigation**:
- Search in filter navigator: `u_eks_cluster`

### Microservices
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/u_microservice_list.do
```

**Navigation**:
- Search in filter navigator: `u_microservice`

### CI Relationship Editor (Dependency Visualization)
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=%2Frelationship_vis.do%3Fsysparm_root_ci%3D
```

**Navigation**:
1. Left menu: **Configuration** → **CMDB** → **CI Relationship Editor**
2. Search for CI: e.g., `frontend`
3. Click: **Visualize** → **Dependency View**

---

## Security Scanning

### Security Scan Summary
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/u_security_scan_summary_list.do
```

**Navigation**:
- Search in filter navigator: `Security Scan Summary`
- Or: Custom application menu → **Security Scan Summary**

### Security Scan Results
**Direct URL**:
```
https://calitiiltddemo3.service-now.com/u_security_scan_result_list.do
```

**Navigation**:
- Search in filter navigator: `Security Scan Result`
- Or: Custom application menu → **Security Scan Result**

---

## DevOps Integration

### DevOps Application (if available)
**Note**: The "DevOps Change" workspace may require additional ServiceNow DevOps plugins to be installed.

**Alternative - Standard Change List**:
```
https://calitiiltddemo3.service-now.com/change_request_list.do
```

**To see changes associated with your application**:
1. Navigate to: **Change** → **All**
2. Create a filter:
   - `Business Service` = `Online Boutique`
   - Or `Description` contains `Online Boutique`
3. Save the filter as a personal view

---

## Quick Reference URLs

| Resource | URL |
|----------|-----|
| All Change Requests | https://calitiiltddemo3.service-now.com/change_request_list.do |
| Online Boutique Changes | https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique |
| Business Applications | https://calitiiltddemo3.service-now.com/cmdb_ci_business_app_list.do |
| Online Boutique App | https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=4ffc7bfec3a4fe90e1bbf0cb0501313f |
| All Servers (EKS Nodes) | https://calitiiltddemo3.service-now.com/cmdb_ci_server_list.do |
| EKS Cluster | https://calitiiltddemo3.service-now.com/u_eks_cluster_list.do |
| Microservices | https://calitiiltddemo3.service-now.com/u_microservice_list.do |
| Security Scan Summary | https://calitiiltddemo3.service-now.com/u_security_scan_summary_list.do |
| Security Scan Results | https://calitiiltddemo3.service-now.com/u_security_scan_result_list.do |
| CI Relationship Editor | https://calitiiltddemo3.service-now.com/nav_to.do?uri=%2Frelationship_vis.do |

---

## Creating Custom Filters and Views

### Save a Custom View for Online Boutique Changes

1. Navigate to: **Change** → **All**
2. Click the filter icon (funnel)
3. Add conditions:
   - `Business Service` = `Online Boutique`
   - `State` is not `Closed Complete` (optional - to hide completed changes)
4. Click: **Run**
5. Click: **Save** → **Save filter as**
6. Name: `Online Boutique - Active Changes`
7. Check: **Make this filter visible to other users** (if you want to share)
8. Click: **Save**

Now you can quickly access this view from the saved filters dropdown.

---

## Verification After Deployment

After deploying with application association, verify using these URLs:

### 1. Check Change Request Created
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=short_descriptionLIKEOnline%20Boutique
```

### 2. Check Application Has Services
```
https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=4ffc7bfec3a4fe90e1bbf0cb0501313f
```
Click the **Services** tab to see all 11 microservices.

### 3. Check Service Dependencies
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=%2Frelationship_vis.do
```
Search for `frontend` and click **Visualize**.

---

## Troubleshooting URLs

### Check if Application Category is Set
```
https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app?sysparm_query=name=Online%20Boutique&sysparm_fields=sys_id,name,application_category&sysparm_display_value=true
```

View in browser - should show Application Category = "Service Delivery"

### List All Change Requests (Raw Data)
```
https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=short_descriptionLIKEOnline%20Boutique&sysparm_display_value=true
```

### Check CMDB Relationships for Frontend
```
https://calitiiltddemo3.service-now.com/api/now/table/cmdb_rel_ci?sysparm_query=parent.name=frontend&sysparm_display_value=true
```

---

## Important Notes

### DevOps Change Workspace
The URL `https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/devops_change_v2_list.do` **does not exist** in standard ServiceNow installations.

**Why?**
- This requires the **ServiceNow DevOps Change Management** plugin
- Plugin installation is a separate step
- May not be available in all ServiceNow editions

**Alternative**:
Use the standard Change Request list with filters:
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
```

This provides similar functionality:
- Lists all changes for Online Boutique
- Shows approval status
- Displays deployment details
- Can be customized with additional columns

---

## Next Steps

After your first deployment with application association:

1. **View the change request**:
   ```
   https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=short_descriptionLIKEOnline%20Boutique^ORDERBYDESCsys_created_on
   ```

2. **Verify application association**:
   - Open the change request
   - Check: `Business Service` field = "Online Boutique"
   - Check: `Configuration Item` field = "Online Boutique"

3. **View service dependencies**:
   - Navigate to CI Relationship Editor
   - Search for any microservice
   - Click Visualize to see the graph

---

## Bookmark These URLs

**Most Frequently Used**:
1. Online Boutique Changes: https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
2. Online Boutique Application: https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=4ffc7bfec3a4fe90e1bbf0cb0501313f
3. Security Scan Summary: https://calitiiltddemo3.service-now.com/u_security_scan_summary_list.do

---

**Last Updated**: 2025-10-16
**Application sys_id**: 4ffc7bfec3a4fe90e1bbf0cb0501313f
