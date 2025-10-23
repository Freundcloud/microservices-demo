# ServiceNow Application and Service Dependency Mapping

> **Purpose**: Configure ServiceNow Application, associate deployments, and map service dependencies
> **Time Required**: 30-45 minutes
> **Status**: Complete Implementation Guide

---

## Overview

This guide shows you how to:
1. ✅ Configure ServiceNow Application for "Online Boutique"
2. ✅ Make change requests visible in DevOps Change workspace
3. ✅ Associate deployments with the application
4. ✅ Map all 11 microservices and their dependencies
5. ✅ Set up automated health monitoring
6. ✅ Create dependency visualization

---

## Problem: Change Requests Not Visible in DevOps Change Workspace

### Why This Happens

The **DevOps Change workspace** in ServiceNow requires:
1. **Application** record configured
2. **Change requests** associated with the application
3. **DevOps Change plugin** installed and configured
4. **Orchestration tool** registration (optional but recommended)

If change requests are created via REST API without these associations, they appear in standard Change Management but not in the DevOps workspace.

---

## Solution Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ServiceNow Architecture                   │
└─────────────────────────────────────────────────────────────┘

1. Application (Online Boutique)
   └─ CMDB CI: u_eks_cluster (microservices)
      └─ Services (u_microservice table)
         ├─ frontend
         ├─ cartservice
         ├─ productcatalogservice
         └─ ... (11 services total)

2. Change Requests
   └─ Associated with Application
      └─ Triggers DevOps Change workflow

3. Service Dependencies
   └─ Mapped in CMDB relationships
      └─ frontend → cartservice
      └─ frontend → productcatalogservice
      └─ cartservice → redis-cart
      └─ ... (dependency graph)

4. Application Services
   └─ Business Service in Service Portfolio
      └─ Contains all technical services
      └─ Monitors health and incidents
```

---

## Part 1: Configure ServiceNow Application

### Step 1: Create Business Application (5 minutes)

1. **Navigate to**: https://calitiiltddemo3.service-now.com/cmdb_ci_business_app_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name:              Online Boutique
   Short description: Cloud-native microservices demo application
   Description:       E-commerce demo application consisting of 11 microservices
                      deployed on AWS EKS with Istio service mesh

   Version:           1.0
   Status:            Operational

   Business Owner:    [Your name/team]
   Technical Owner:   [DevOps team lead]
   Support Group:     DevOps Team

   Environment:       Production
   ```

4. **Click**: Submit

5. **Copy the sys_id** from the URL (format: `abc123def456...`)
   - URL will look like: `.../cmdb_ci_business_app.do?sys_id=ABC123...`

---

### Step 2: Link Application to EKS Cluster

1. **Navigate to**: The application record you just created

2. **Scroll to**: "Relationships" tab

3. **Click**: "New" under "CI Relationships"

4. **Fill in**:
   ```
   Parent:           Online Boutique (cmdb_ci_business_app)
   Type:             Runs on::Runs
   Child:            microservices (u_eks_cluster)
   ```

5. **Click**: Submit

---

### Step 3: Create Application Portfolio Service (Optional but Recommended)

This creates a business service that can be monitored for incidents and changes.

1. **Navigate to**: https://calitiiltddemo3.service-now.com/business_service_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name:              Online Boutique Service
   Short description: E-commerce application service
   Business application: Online Boutique
   Status:            Operational
   Service classification: Application Service

   Support group:     DevOps Team
   Service owner:     [Your name]
   ```

4. **Click**: Submit

---

## Part 2: Associate Change Requests with Application

### Option A: Update Existing Workflow (Recommended)

Update your workflow to include the application reference when creating change requests.

**Edit**: `.github/workflows/deploy-with-servicenow-basic.yaml`

Find the "Create Change Request via REST API" step and add `business_service` field:

```yaml
- name: Create Change Request via REST API
  id: create-cr
  run: |
    ENV="${{ github.event.inputs.environment }}"

    # Get application sys_id (set as GitHub secret)
    APP_SYS_ID="${{ secrets.SERVICENOW_APP_SYS_ID }}"

    PAYLOAD=$(cat <<EOF
    {
      "short_description": "Deploy microservices-demo to $ENV",
      "description": "...",
      "business_service": "$APP_SYS_ID",
      "cmdb_ci": "$APP_SYS_ID",
      "u_application": "Online Boutique",
      ...
    }
    EOF
    )
```

**Set GitHub Secret**:
```bash
gh secret set SERVICENOW_APP_SYS_ID \
  --repo Freundcloud/microservices-demo \
  --body "YOUR_APP_SYS_ID_HERE"
```

---

### Option B: Manually Associate Existing Change Requests

1. **Navigate to**: https://calitiiltddemo3.service-now.com/change_request_list.do

2. **Open**: A change request created by your workflow

3. **Find**: "Business service" or "CMDB CI" field

4. **Select**: Online Boutique

5. **Click**: Update

---

## Part 3: Map Service Dependencies in CMDB

### Understanding the Microservices Architecture

```
Frontend (User-facing)
  ├─→ Cart Service
  │     └─→ Redis Cart
  ├─→ Product Catalog Service
  ├─→ Currency Service
  ├─→ Recommendation Service
  ├─→ Ad Service
  ├─→ Checkout Service
        ├─→ Payment Service
        ├─→ Shipping Service
        ├─→ Email Service
        └─→ Currency Service
```

---

### Step 1: Verify All Services Exist in CMDB

Check that the EKS discovery workflow has created all service records:

```bash
PASSWORD='<your-password>' bash -c 'curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/u_microservice?sysparm_query=u_cluster_name=microservices&sysparm_fields=u_name,sys_id" \
  | jq -r ".result[] | \"\(.u_name): \(.sys_id)\""'
```

Expected output:
```
frontend: abc123...
cartservice: def456...
productcatalogservice: ghi789...
...
```

---

### Step 2: Create Service Dependency Relationships

#### Manual Approach (ServiceNow UI)

1. **Navigate to**: https://calitiiltddemo3.service-now.com/cmdb_rel_ci_list.do

2. **Click**: New for each dependency

3. **Create relationships**:

| Parent (From) | Relationship Type | Child (To) | Description |
|---------------|-------------------|------------|-------------|
| frontend | Uses::Used by | cartservice | Frontend calls cart API |
| frontend | Uses::Used by | productcatalogservice | Frontend displays products |
| frontend | Uses::Used by | currencyservice | Frontend converts currency |
| frontend | Uses::Used by | recommendationservice | Frontend shows recommendations |
| frontend | Uses::Used by | adservice | Frontend displays ads |
| frontend | Uses::Used by | checkoutservice | Frontend processes checkout |
| cartservice | Uses::Used by | redis-cart | Cart stores data in Redis |
| checkoutservice | Uses::Used by | paymentservice | Checkout processes payment |
| checkoutservice | Uses::Used by | shippingservice | Checkout calculates shipping |
| checkoutservice | Uses::Used by | emailservice | Checkout sends confirmation |
| checkoutservice | Uses::Used by | currencyservice | Checkout converts currency |

#### Automated Approach (REST API Script)

Create `scripts/map-service-dependencies.sh`:

```bash
#!/usr/bin/env bash

SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
BASIC_AUTH=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

# Service dependency map
declare -A DEPENDENCIES=(
  ["frontend"]="cartservice,productcatalogservice,currencyservice,recommendationservice,adservice,checkoutservice"
  ["cartservice"]="redis-cart"
  ["checkoutservice"]="paymentservice,shippingservice,emailservice,currencyservice"
)

# Get service sys_id by name
get_service_sys_id() {
  local service_name="$1"
  curl -s -H "Authorization: Basic ${BASIC_AUTH}" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/u_microservice?sysparm_query=u_name=${service_name}&sysparm_fields=sys_id" \
    | jq -r '.result[0].sys_id'
}

# Create relationship
create_relationship() {
  local parent_sys_id="$1"
  local child_sys_id="$2"
  local description="$3"

  curl -s -X POST \
    -H "Authorization: Basic ${BASIC_AUTH}" \
    -H "Content-Type: application/json" \
    -d "{
      \"parent\": \"${parent_sys_id}\",
      \"child\": \"${child_sys_id}\",
      \"type\": \"d93304fb0a0a0b78006081a72ef08444\"
    }" \
    "${SERVICENOW_INSTANCE_URL}/api/now/table/cmdb_rel_ci"
}

# Map all dependencies
for parent in "${!DEPENDENCIES[@]}"; do
  parent_sys_id=$(get_service_sys_id "$parent")

  IFS=',' read -ra children <<< "${DEPENDENCIES[$parent]}"
  for child in "${children[@]}"; do
    child_sys_id=$(get_service_sys_id "$child")
    echo "Creating relationship: $parent → $child"
    create_relationship "$parent_sys_id" "$child_sys_id" "$parent depends on $child"
  done
done
```

---

### Step 3: Visualize Dependencies

1. **Navigate to**: https://calitiiltddemo3.service-now.com/cmdb_ci_list.do

2. **Search**: "Online Boutique"

3. **Click**: The application record

4. **View Options**:
   - **Dependency View**: Shows upstream/downstream dependencies
   - **Impact Analysis**: Shows what breaks if a service fails
   - **Service Map**: Visual graph of all dependencies

---

## Part 4: Set Up Application Service Mapping (ASM)

### What is ASM?

Application Service Mapping automatically discovers and maps:
- Service dependencies
- Infrastructure components
- Network connections
- Database connections

### Enable ASM (If Available)

1. **Navigate to**: https://calitiiltddemo3.service-now.com/v_plugin_list.do

2. **Search**: "Service Mapping"

3. **Check**: If "Service Mapping" plugin is active

4. **If active**, configure:
   - Navigate to: Service Mapping → Map Applications
   - Select: Online Boutique
   - Discovery method: Agent-based or Agentless
   - Scan: EKS cluster nodes

---

## Part 5: Automated Health Monitoring

### Create Health Check Workflow

This workflow monitors service health and creates incidents when services are unhealthy.

**File**: `.github/workflows/servicenow-health-check.yaml`

```yaml
name: ServiceNow Health Check

on:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes
  workflow_dispatch:

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices
  SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
  SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
  SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
  SERVICENOW_APP_SYS_ID: ${{ secrets.SERVICENOW_APP_SYS_ID }}

jobs:
  health-check:
    name: Check Service Health
    runs-on: ubuntu-latest

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Check service health
        run: |
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          SERVICES="frontend cartservice productcatalogservice currencyservice paymentservice shippingservice emailservice checkoutservice recommendationservice adservice"

          for namespace in microservices-dev microservices-qa microservices-prod; do
            if kubectl get namespace $namespace 2>/dev/null; then
              for service in $SERVICES; do
                # Check if deployment exists
                if kubectl get deployment $service -n $namespace 2>/dev/null; then
                  REPLICAS=$(kubectl get deployment $service -n $namespace -o jsonpath='{.spec.replicas}')
                  READY=$(kubectl get deployment $service -n $namespace -o jsonpath='{.status.readyReplicas}' || echo "0")

                  STATUS="operational"
                  if [ "$READY" != "$REPLICAS" ]; then
                    STATUS="degraded"
                  fi

                  # Update ServiceNow
                  curl -s -X PUT \
                    -H "Authorization: Basic ${BASIC_AUTH}" \
                    -H "Content-Type: application/json" \
                    -d "{\"u_status\":\"${STATUS}\",\"u_ready_replicas\":${READY},\"u_replicas\":${REPLICAS}}" \
                    "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/u_microservice?sysparm_query=u_name=${service}^u_namespace=${namespace}"

                  # Create incident if degraded
                  if [ "$STATUS" == "degraded" ]; then
                    curl -s -X POST \
                      -H "Authorization: Basic ${BASIC_AUTH}" \
                      -H "Content-Type: application/json" \
                      -d "{
                        \"short_description\":\"Service ${service} degraded in ${namespace}\",
                        \"description\":\"Ready replicas: ${READY}/${REPLICAS}\",
                        \"severity\":\"3\",
                        \"urgency\":\"2\",
                        \"impact\":\"2\",
                        \"business_service\":\"${{ secrets.SERVICENOW_APP_SYS_ID }}\",
                        \"cmdb_ci\":\"${{ secrets.SERVICENOW_APP_SYS_ID }}\",
                        \"assignment_group\":\"DevOps Team\"
                      }" \
                      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/incident"
                  fi
                fi
              done
            fi
          done
```

---

## Part 6: DevOps Change Workspace Visibility

### Why Change Requests Aren't Visible

The DevOps Change workspace filters changes by:
1. **Associated application** - Must have business_service or cmdb_ci field
2. **DevOps plugin** - Requires ServiceNow DevOps Change plugin
3. **Orchestration tool** - Links to GitHub/Jenkins/etc

### Solution 1: Add Application Association to Workflow

Update the change request creation in your workflow:

```yaml
- name: Create Change Request via REST API
  run: |
    # Get application sys_id
    APP_SYS_ID="${{ secrets.SERVICENOW_APP_SYS_ID }}"

    PAYLOAD=$(cat <<EOF
    {
      "short_description": "Deploy microservices-demo to $ENV",
      "business_service": "$APP_SYS_ID",
      "cmdb_ci": "$APP_SYS_ID",
      "u_application": "Online Boutique",
      "assignment_group": "DevOps Team",
      ...
    }
    EOF
    )
```

### Solution 2: Create Custom Workspace View

If you don't have the DevOps Change plugin, create a custom workspace:

1. **Navigate to**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=sys_aw_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Title:        Online Boutique Deployments
   Description:  Change requests for Online Boutique application
   Table:        Change Request (change_request)
   ```

4. **Add Filter**:
   ```
   Business service = Online Boutique
   OR
   Short description CONTAINS "microservices-demo"
   ```

5. **Click**: Submit

6. **Access**: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/[workspace_sys_id]

---

## Part 7: Dependency Visualization Dashboard

### Create Custom Dashboard

1. **Navigate to**: https://calitiiltddemo3.service-now.com/pa_dashboards_list.do

2. **Click**: New

3. **Fill in**:
   ```
   Name: Online Boutique Service Health
   Description: Real-time health and dependency monitoring
   ```

4. **Add Widgets**:
   - **Service Health Overview**: Gauge showing healthy/unhealthy services
   - **Dependency Map**: Visual graph of service relationships
   - **Recent Changes**: List of deployments and changes
   - **Open Incidents**: Services with active incidents
   - **Deployment History**: Timeline of changes

---

## Part 8: Verification and Testing

### Test 1: Verify Application Configuration

```bash
PASSWORD='<your-password>' bash -c 'curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_ci_business_app?sysparm_query=name=Online%20Boutique" \
  | jq .'
```

Expected: Application record with sys_id

---

### Test 2: Verify Service Relationships

```bash
PASSWORD='<your-password>' bash -c 'curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_rel_ci?sysparm_query=parent.name=frontend" \
  | jq -r ".result[] | \"\(.parent.name) → \(.child.name) (\(.type.name))\""'
```

Expected: List of frontend dependencies

---

### Test 3: Create Test Change Request with Application

```bash
PASSWORD='<your-password>' bash -c '
APP_SYS_ID="YOUR_APP_SYS_ID"
curl -s -X POST \
  -u "github_integration:$PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"short_description\":\"Test deployment - Online Boutique\",
    \"business_service\":\"${APP_SYS_ID}\",
    \"cmdb_ci\":\"${APP_SYS_ID}\",
    \"state\":\"3\",
    \"type\":\"standard\"
  }" \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request" \
  | jq .'
```

Then check if visible in DevOps Change workspace.

---

## Summary Checklist

- [ ] Created Business Application "Online Boutique"
- [ ] Linked application to EKS cluster
- [ ] Created Business Service (optional)
- [ ] Updated workflow to include application association
- [ ] Set SERVICENOW_APP_SYS_ID GitHub secret
- [ ] Mapped all 11 service dependencies
- [ ] Created automated health check workflow
- [ ] Verified change requests appear with application
- [ ] Created custom dashboard for monitoring
- [ ] Tested dependency visualization

---

## Next Steps

1. **Run the dependency mapping script** to create all relationships
2. **Trigger a deployment** with updated workflow
3. **Verify change request** appears with application association
4. **Set up health monitoring** workflow
5. **Create dashboard** for ops team visibility

---

## Related Documentation

- [ServiceNow Approvals Guide](SERVICENOW-APPROVALS.md)
- [EKS Discovery](SERVICENOW-NODE-DISCOVERY.md)
- [Security Scanning](SERVICENOW-SECURITY-SCANNING.md)

---

**Questions?** Check ServiceNow documentation or create an issue in the repository.
