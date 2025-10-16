# Viewing EKS Nodes in ServiceNow

> Guide for viewing cluster nodes and relationships in ServiceNow CMDB

**Last Updated**: 2025-10-16
**Issue**: Empty "Cluster Nodes" and "Cluster Resources" tabs on u_eks_cluster form
**Solution**: Use CMDB Relationships view or direct server queries

---

## Problem

When viewing an EKS cluster record at `u_eks_cluster.do`, the following tabs appear empty:
- "Cluster Nodes" tab
- "Cluster Resources" tab

## Root Cause

These tabs are placeholder related lists that were auto-created when the u_eks_cluster table was created, but they don't have:
1. Configured related list queries
2. Reference fields pointing to nodes/resources
3. Proper relationship mappings

The nodes **ARE** in ServiceNow and **ARE** related to the cluster - they just need to be viewed differently.

## ✅ Solution 1: View via CMDB Relationships (Recommended)

This uses the standard CMDB relationship functionality that all Configuration Items have.

### Step-by-Step:

1. **Navigate to EKS Cluster**
   ```
   https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_eks_cluster_list.do
   ```

2. **Open the cluster record** (click on "microservices")

3. **Click on "Related Items" tab** (standard CMDB tab)
   - This tab is inherited from cmdb_ci parent class
   - Shows all CMDB relationships

4. **Look for relationship sections**:
   - "Virtualized by::Virtualizes" section
   - OR "Child CIs" section
   - OR "Downstream CIs" section

5. **Click the relationship link** to see all related nodes

### Alternative: Use the CI Relationship Formatter

1. On the cluster record, look for **"Visualize Relationships"** icon
2. Click it to see a graphical view of related CIs
3. This shows the cluster → nodes relationship visually

## ✅ Solution 2: Direct Server Query

Query servers directly filtered by cluster name.

### Step-by-Step:

1. **Navigate to Servers**
   ```
   https://calitiiltddemo3.service-now.com/nav_to.do?uri=cmdb_ci_server_list.do
   ```

2. **Add Filter**:
   - Click "Filter" (funnel icon)
   - Select "Cluster name" field
   - Enter: `microservices`
   - Click "Run"

3. **View Results**:
   - Shows all EKS nodes for this cluster
   - Full server details visible
   - Can click any node for details

### Quick URL (with filter):
```
https://calitiiltddemo3.service-now.com/nav_to.do?uri=cmdb_ci_server_list.do?sysparm_query=cluster_name=microservices
```

## ✅ Solution 3: API Query for Relationships

Use the ServiceNow REST API to query relationships programmatically.

### Get Cluster sys_id:
```bash
curl -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_eks_cluster?sysparm_query=name=microservices&sysparm_fields=sys_id,name" \
  | jq -r '.result[0].sys_id'
```

Response: `1143d7f2c3acbe90e1bbf0cb0501318d`

### Get Related Nodes:
```bash
curl -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_rel_ci?sysparm_query=parent=1143d7f2c3acbe90e1bbf0cb0501318d&sysparm_display_value=true&sysparm_fields=child.name,child.ip_address,child.cpu_count,child.ram,type.name"
```

Response:
```json
{
  "result": [
    {
      "child.name": "ip-10-0-2-114.eu-west-2.compute.internal",
      "child.ip_address": "10.0.2.114",
      "child.cpu_count": "4",
      "child.ram": "15802",
      "type.name": "Virtualized by::Virtualizes"
    }
  ]
}
```

## ✅ Solution 4: Configure Related Lists (Advanced)

For users with admin access who want to fix the empty tabs permanently.

### Option A: Add Related List for Relationships

1. **Navigate to**: System UI → Related Lists → Related List Definitions

2. **Create New Related List**:
   - **Name**: Cluster Nodes
   - **Table**: u_eks_cluster
   - **Related List**: cmdb_rel_ci
   - **Filter**: parent=CURRENT
   - **Display Fields**: child.name, child.ip_address, child.cpu_count, child.ram, child.operational_status

3. **Add to Form Layout**:
   - System UI → Forms → u_eks_cluster
   - Add "Related Lists" section
   - Insert the new "Cluster Nodes" related list

### Option B: Use Reference Field (More Complex)

This requires creating a reference field and maintaining it via workflow, so it's not recommended for this use case.

## ✅ Solution 5: Create Custom Report

Create a report showing cluster-to-node relationships.

### Step-by-Step:

1. **Navigate to**: Reports → View/Run

2. **Create New Report**:
   - **Table**: CMDB Relationship [cmdb_rel_ci]
   - **Type**: List
   - **Conditions**:
     - Parent.Name = microservices
     - Type = Virtualized by::Virtualizes

3. **Columns to Display**:
   - Parent.Name (Cluster)
   - Child.Name (Node)
   - Child.IP Address
   - Child.CPU Count
   - Child.RAM
   - Child.Operational Status

4. **Save and Run**

## Verification

Let's verify the data is actually there:

### 1. Check Cluster Exists:
```bash
curl -s -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_eks_cluster?name=microservices" \
  | jq '.result[] | {name, cluster_name: .u_u_cluster_name, version: .u_u_version, status: .u_u_status}'
```

Expected:
```json
{
  "name": "microservices",
  "cluster_name": "microservices",
  "version": "Kubernetes 1.30",
  "status": "ACTIVE"
}
```

### 2. Check Nodes Exist:
```bash
curl -s -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_server?cluster_name=microservices" \
  | jq '.result[] | {name, ip_address, cpu_count, ram, operational_status}'
```

Expected:
```json
{
  "name": "ip-10-0-2-114.eu-west-2.compute.internal",
  "ip_address": "10.0.2.114",
  "cpu_count": "4",
  "ram": "15802",
  "operational_status": "1"
}
```

### 3. Check Relationship Exists:
```bash
curl -s -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_rel_ci?parent.name=microservices" \
  | jq '.result[] | {parent: .["parent.name"], child: .["child.name"], type: .["type.name"]}'
```

Expected:
```json
{
  "parent": "microservices",
  "child": "ip-10-0-2-114.eu-west-2.compute.internal",
  "type": "Virtualized by::Virtualizes"
}
```

## Why This Happens

When you create a custom table extending cmdb_ci in ServiceNow, the system:

1. **Auto-creates placeholder tabs** based on common patterns
2. **These tabs don't have queries** - they're just UI placeholders
3. **Standard CMDB relationships work** - just not visible in those specific tabs

The data is properly stored in:
- `u_eks_cluster` - Cluster CI
- `cmdb_ci_server` - Node CIs
- `cmdb_rel_ci` - Relationships

## Recommended Approach

**For Daily Use**: Use Solution 2 (Direct Server Query)
- Fastest and simplest
- Filter servers by cluster_name
- All node details visible immediately

**For Relationship View**: Use Solution 1 (CMDB Relationships)
- Shows standard CMDB dependency map
- Visual representation available
- Works with all CMDB tools

**For Automation**: Use Solution 3 (API Query)
- Programmatic access
- Easy to integrate with scripts
- Returns structured data

## Quick Reference Card

| Task | Method | URL/Command |
|------|--------|-------------|
| View all nodes | Direct query | `cmdb_ci_server_list.do?sysparm_query=cluster_name=microservices` |
| View relationships | CMDB Relationships tab | Open cluster → "Related Items" tab |
| API query nodes | REST API | `/api/now/table/cmdb_ci_server?cluster_name=microservices` |
| API query relationships | REST API | `/api/now/table/cmdb_rel_ci?parent.name=microservices` |

## Future Enhancement

To make the "Cluster Nodes" tab functional, we would need to:

1. **Create a proper related list definition**
2. **Configure the query** to filter cmdb_ci_server by cluster relationship
3. **Add to form layout** replacing the placeholder tab

This would require ServiceNow admin UI work and is optional - the data is accessible through standard CMDB views.

## Summary

✅ **The data IS in ServiceNow**:
- Cluster CI exists with all metadata
- Node CIs exist in cmdb_ci_server
- Relationships exist in cmdb_rel_ci

❌ **The specific tabs are empty because**:
- They're placeholder UI elements
- No related list configuration
- No reference fields configured

✅ **View the nodes using**:
- Direct server query (filter by cluster_name)
- CMDB Relationships tab on cluster record
- API queries for automation

---

**Questions?** Check:
- [Node Discovery Guide](SERVICENOW-NODE-DISCOVERY.md)
- [Quick Start Guide](SERVICENOW-QUICK-START.md)
- [Setup Checklist](SERVICENOW-SETUP-CHECKLIST.md)
