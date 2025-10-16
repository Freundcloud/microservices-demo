# ServiceNow EKS Node Discovery Guide

> Complete guide for EKS node discovery and CMDB population in ServiceNow

**Last Updated**: 2025-10-16
**ServiceNow Version**: Zurich v6.1.0
**Status**: ✅ Implemented and Tested

---

## Overview

This guide explains how the EKS discovery workflow populates cluster nodes and their relationships in ServiceNow CMDB.

## Architecture

### Discovery Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                     │
│                    (eks-discovery.yaml)                         │
└────────────┬────────────────────────────────────────────────────┘
             │
             ├─► 1. Discover EKS Cluster
             │   └─► AWS: eks describe-cluster
             │
             ├─► 2. Discover EKS Nodes
             │   ├─► AWS: eks list-nodegroups
             │   ├─► AWS: eks describe-nodegroup
             │   ├─► AWS: autoscaling describe-auto-scaling-groups
             │   ├─► AWS: ec2 describe-instances
             │   └─► Kubernetes: kubectl get nodes
             │
             ├─► 3. Discover Microservices
             │   └─► Kubernetes: kubectl get deployments
             │
             └─► 4. Upload to ServiceNow CMDB
                 ├─► Create/Update Cluster CI (u_eks_cluster)
                 ├─► Create/Update Node CIs (cmdb_ci_server)
                 ├─► Create/Update Microservice CIs (u_microservice)
                 └─► Create Relationships (cmdb_rel_ci)
```

### ServiceNow CMDB Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                     ServiceNow CMDB                             │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   u_eks_cluster      │  Extends: cmdb_ci
│  ┌────────────────┐  │
│  │ microservices  │  │  Standard Fields:
│  └────────────────┘  │  - name, ip_address, sys_id
│                      │
│  Custom Fields:      │  Custom Fields (u_u_ prefix):
│  - u_u_cluster_name  │  - u_u_arn
│  - u_u_version       │  - u_u_endpoint
│  - u_u_status        │  - u_u_region
│  - u_u_vpc_id        │  - u_u_provider
│  - u_u_last_discovered
│  - u_u_discovered_by
└──────────┬───────────┘
           │
           │ Relationship: "Virtualized by::Virtualizes"
           │ (cmdb_rel_ci)
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│              cmdb_ci_server (EKS Nodes)                      │
│  ┌────────────────────────────────────────────┐              │
│  │ ip-10-0-2-114.eu-west-2.compute.internal   │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  Standard CMDB Fields:           EKS-Specific Custom Fields: │
│  - name                          - u_instance_id             │
│  - ip_address                    - u_instance_type           │
│  - host_name                     - u_availability_zone       │
│  - cpu_count                     - u_eks_state               │
│  - ram (MB)                      - u_kubernetes_status       │
│  - disk_space (GB)               - u_nodegroup                │
│  - os_version                    - u_ami_type                │
│  - cluster_name                  - u_last_discovered         │
│  - operational_status                                        │
│  - short_description                                         │
│  - comments                                                  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│            u_microservice (Microservices)                    │
│  ┌────────────────┐  ┌────────────────┐                     │
│  │   frontend     │  │  cartservice   │  ... (11 services)  │
│  └────────────────┘  └────────────────┘                     │
│                                                               │
│  Custom Fields:                                              │
│  - u_name (mandatory)                                        │
│  - u_namespace (mandatory)                                   │
│  - u_cluster_name                                            │
│  - u_image                                                   │
│  - u_replicas                                                │
│  - u_ready_replicas                                          │
│  - u_status                                                  │
│  - u_language                                                │
└──────────────────────────────────────────────────────────────┘
```

## Node Discovery Process

### Step 1: Get Node Groups

```bash
aws eks list-nodegroups --cluster-name microservices --region eu-west-2
```

Returns list of node groups:
- `microservices-sys-20251014211110362000000003`
- `microservices-dev-20251014211110362000000001`
- `microservices-qa-20251014211110362000000002`
- `microservices-prod-20251014211110362000000004`

### Step 2: Describe Each Node Group

```bash
aws eks describe-nodegroup \
  --cluster-name microservices \
  --nodegroup-name microservices-sys-20251014211110362000000003
```

Extracts:
- Instance types (t3.xlarge, t3.2xlarge, m5.4xlarge)
- AMI type (AL2_x86_64)
- Disk size (20 GB)
- Scaling config (min/max/desired)
- Auto Scaling Group name

### Step 3: Get EC2 Instances

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names eks-microservices-sys-...
```

Gets instance IDs, then describes each instance:

```bash
aws ec2 describe-instances --instance-ids i-0123456789abcdef0
```

Extracts:
- Instance ID
- Instance type
- Private IP address
- Public IP address (if any)
- Availability zone
- State (running, stopped, etc.)
- Launch time

### Step 4: Get Kubernetes Node Info

```bash
kubectl get nodes -o json
```

Matches EC2 instances to Kubernetes nodes by instance ID in `spec.providerID`.

For each node:

```bash
kubectl get node ip-10-0-2-114.eu-west-2.compute.internal -o json
```

Extracts:
- Node name
- Kubernetes version
- Capacity (CPU, memory)
- Allocatable resources (CPU, memory)
- Ready status

### Step 5: Upload to ServiceNow

For each node, creates/updates a CI in `cmdb_ci_server`:

```json
{
  "name": "ip-10-0-2-114.eu-west-2.compute.internal",
  "ip_address": "10.0.2.114",
  "host_name": "ip-10-0-2-114.eu-west-2.compute.internal",
  "short_description": "EKS Node - microservices-sys-...",
  "comments": "Instance ID: i-0123...\nNode Group: microservices-sys-...\nKubernetes Version: v1.30.14-eks-113cf36\nAllocatable CPU: 3920m\nAllocatable Memory: 15154528Ki",
  "operational_status": "1",
  "cpu_count": "4",
  "ram": "15802",
  "disk_space": "20",
  "os_version": "v1.30.14-eks-113cf36",
  "cluster_name": "microservices",
  "u_instance_id": "i-0123456789abcdef0",
  "u_instance_type": "t3.xlarge",
  "u_availability_zone": "eu-west-2a",
  "u_eks_state": "running",
  "u_kubernetes_status": "True",
  "u_nodegroup": "microservices-sys-20251014211110362000000003",
  "u_ami_type": "AL2_x86_64",
  "u_last_discovered": "2025-10-16T18:11:25Z"
}
```

### Step 6: Create Relationships

Creates relationship in `cmdb_rel_ci`:

```json
{
  "parent": "1143d7f2c3acbe90e1bbf0cb0501318d",  // Cluster sys_id
  "child": "106c5c13c61122750194a1e96cfde951",   // Node sys_id
  "type": "d93304fb0a0a0b78006081a72ef08444"     // "Virtualized by::Virtualizes"
}
```

## CMDB Table Details

### u_eks_cluster Table

**Extends**: `cmdb_ci` (Configuration Item)

**Purpose**: Stores EKS cluster metadata

**Custom Fields** (note u_u_ prefix due to CMDB inheritance):
- `u_u_cluster_name` (String, 255) - EKS cluster name
- `u_u_arn` (String, 512) - Cluster ARN
- `u_u_version` (String, 100) - Kubernetes version
- `u_u_endpoint` (URL, 1024) - API server endpoint
- `u_u_status` (String, 100) - Cluster status
- `u_u_region` (String, 100) - AWS region
- `u_u_vpc_id` (String, 255) - VPC ID
- `u_u_provider` (String, 100) - Cloud provider (AWS EKS)
- `u_u_last_discovered` (Date/Time) - Last discovery timestamp
- `u_u_discovered_by` (String, 100) - Discovery source

### cmdb_ci_server Table (Standard + Custom)

**Extends**: `cmdb_ci_computer` → `cmdb_ci`

**Purpose**: Standard ServiceNow server table for all servers

**Standard Fields Used**:
- `name` - Kubernetes node name
- `ip_address` - Private IP
- `host_name` - Kubernetes node name
- `cpu_count` - Number of CPUs
- `ram` - Memory in MB
- `disk_space` - Disk size in GB
- `os_version` - Kubernetes version
- `cluster_name` - EKS cluster name
- `operational_status` - 1 (Operational) or 2 (Non-Operational)
- `short_description` - Brief description
- `comments` - Detailed metadata

**EKS-Specific Custom Fields** (optional):
- `u_instance_id` (String, 255) - EC2 instance ID
- `u_instance_type` (String, 100) - EC2 instance type
- `u_availability_zone` (String, 100) - AWS AZ
- `u_eks_state` (String, 100) - EC2 state
- `u_kubernetes_status` (String, 100) - K8s ready status
- `u_nodegroup` (String, 255) - Node group name
- `u_ami_type` (String, 100) - AMI type
- `u_last_discovered` (Date/Time) - Discovery timestamp

### u_microservice Table

**Extends**: `cmdb_ci`

**Purpose**: Stores microservice deployment metadata

**Custom Fields**:
- `u_name` (String, 255) - Service name (MANDATORY)
- `u_namespace` (String, 255) - Kubernetes namespace (MANDATORY)
- `u_cluster_name` (String, 255) - EKS cluster name
- `u_image` (String, 512) - Container image
- `u_replicas` (String, 50) - Desired replicas
- `u_ready_replicas` (String, 50) - Ready replicas
- `u_status` (String, 100) - Service status
- `u_language` (String, 100) - Programming language

### cmdb_rel_ci Table (Standard)

**Purpose**: Standard CMDB relationship table

**Fields Used**:
- `parent` - Parent CI (cluster)
- `child` - Child CI (node)
- `type` - Relationship type sys_id

**Relationship Type**: "Virtualized by::Virtualizes"
- sys_id: `d93304fb0a0a0b78006081a72ef08444`
- Meaning: Cluster virtualizes (contains) nodes

## Viewing Data in ServiceNow

### 1. View Cluster

Navigate to: `https://your-instance.service-now.com/nav_to.do?uri=u_eks_cluster_list.do`

Filter by: `name = microservices`

**What You See**:
- Cluster name: `microservices`
- Version: `Kubernetes 1.30`
- Status: `ACTIVE`
- Region: `eu-west-2`
- All metadata fields populated

**Related Lists**:
- Click cluster → Related Lists
- "Virtualized by::Virtualizes" → Shows all nodes

### 2. View Nodes

Navigate to: `https://your-instance.service-now.com/nav_to.do?uri=cmdb_ci_server_list.do`

Filter by: `cluster_name = microservices`

**What You See**:
- Node name (e.g., `ip-10-0-2-114.eu-west-2.compute.internal`)
- IP address: `10.0.2.114`
- CPU count: `4`
- RAM: `15802 MB`
- Disk space: `20 GB`
- OS version: `v1.30.14-eks-113cf36`
- Operational status: Operational (green)

**Additional Details** (in Comments field):
- Instance ID
- Node group
- Kubernetes version
- Allocatable resources

### 3. View Microservices

Navigate to: `https://your-instance.service-now.com/nav_to.do?uri=u_microservice_list.do`

Filter by: `u_cluster_name = microservices`

**What You See**:
- All 11 microservices
- Namespace (dev/qa/prod)
- Replica counts
- Status
- Programming language

### 4. View Relationships

Navigate to cluster CI → Related Lists → "Virtualized by::Virtualizes"

**What You See**:
- All nodes associated with the cluster
- Click node to see full details
- Dependency mapping in CMDB

## Resource Calculations

### Memory Conversion

Kubernetes reports memory in Ki (kibibytes):

```bash
# Example: 16237988Ki
MEMORY_KB=16237988
MEMORY_MB=$((MEMORY_KB / 1024))
# Result: 15802 MB
```

### CPU Parsing

Kubernetes reports CPU as core count:

```bash
# Example: "4"
CPU_COUNT=4
```

Allocatable CPU in millicores:

```bash
# Example: "3920m"
ALLOCATABLE_CPU="3920m"
# Means: 3.92 cores available
```

## Operational Status Mapping

```bash
# Operational (status=1) if:
# - EC2 state = "running" AND
# - Kubernetes ready status = "True"

if [ "$EC2_STATE" = "running" ] && [ "$K8S_STATUS" = "True" ]; then
  OPERATIONAL_STATUS="1"  # Operational
else
  OPERATIONAL_STATUS="2"  # Non-Operational
fi
```

## Workflow Schedule

The EKS discovery workflow runs:

1. **Every 6 hours** (cron: `0 */6 * * *`)
2. **Manual trigger** (workflow_dispatch)
3. **On push** to:
   - `kustomize/overlays/**`
   - `kubernetes-manifests/**`
   - `.github/workflows/deploy-with-servicenow.yaml`

## Current State

### Discovered and Populated

✅ **Cluster**: 1 cluster (`microservices`)
- All metadata populated
- IP address extracted from endpoint
- Version, status, region, VPC all populated

✅ **Nodes**: 1 node discovered and populated
- `ip-10-0-2-114.eu-west-2.compute.internal`
- 4 CPU, 15802 MB RAM, 20 GB disk
- Kubernetes v1.30.14-eks-113cf36
- Operational status
- Node group: `microservices-sys-20251014211110362000000003`

✅ **Relationships**: Created
- Cluster → Node relationship in cmdb_rel_ci
- Type: "Virtualized by::Virtualizes"

✅ **Microservices**: 11 services populated
- All with cluster names, languages, replicas, status

## Troubleshooting

### No Nodes Discovered

**Problem**: Workflow completes but no nodes in ServiceNow

**Causes**:
1. No node groups in cluster
2. Auto Scaling Group not found
3. EC2 instances not running
4. kubectl not configured

**Solution**:
```bash
# Check node groups
aws eks list-nodegroups --cluster-name microservices

# Check kubectl access
kubectl get nodes

# Check workflow logs
gh run view --log | grep "Discover EKS nodes"
```

### Nodes Created Without Custom Fields

**Problem**: Nodes exist but u_ fields are empty

**Causes**:
1. Custom fields not created in ServiceNow
2. API doesn't have permission to set custom fields
3. Field names don't match

**Solution**:
- Custom fields are optional
- Standard CMDB fields (cpu_count, ram, etc.) work without custom fields
- Detailed metadata is in Comments field as fallback
- Create custom fields manually if needed (see setup guide)

### Relationship Not Created

**Problem**: Cluster and nodes exist but not linked

**Causes**:
1. Relationship type sys_id incorrect
2. Parent or child sys_id not found
3. cmdb_rel_ci table permission issue

**Solution**:
```bash
# Check cluster sys_id
curl -u "user:pass" \
  "https://instance.service-now.com/api/now/table/u_eks_cluster?name=microservices"

# Check node sys_id
curl -u "user:pass" \
  "https://instance.service-now.com/api/now/table/cmdb_ci_server?cluster_name=microservices"

# Check relationships
curl -u "user:pass" \
  "https://instance.service-now.com/api/now/table/cmdb_rel_ci?parent=CLUSTER_SYS_ID"
```

### Memory Conversion Errors

**Problem**: RAM shows as 0 or incorrect value

**Causes**:
1. Kubernetes memory format not parsed correctly
2. Division by zero
3. Empty capacity value

**Solution**:
- Check workflow logs for memory values
- Verify sed command extracts Ki correctly
- Ensure CAPACITY_MEMORY not empty

## Next Steps

### Enhance Node Discovery

1. **Add More Node Metadata**
   - Pod count on node
   - Resource utilization
   - Taints and labels
   - Node conditions

2. **Add Resource Discovery**
   - Load balancers
   - Security groups
   - VPC resources
   - IAM roles

3. **Add Pod Discovery**
   - Pods running on each node
   - Container details
   - Resource requests/limits

### Improve Relationships

1. **Add More Relationship Types**
   - Node → Pods
   - Cluster → Load Balancers
   - Cluster → VPC
   - Microservice → Nodes (where running)

2. **Add Application Services**
   - Business services
   - Application components
   - Service dependencies

### Monitoring and Alerting

1. **Add Health Checks**
   - Node not ready alerts
   - Pod failures
   - Resource exhaustion

2. **Add Change Tracking**
   - Node additions/removals
   - Version upgrades
   - Configuration changes

## References

- [ServiceNow Quick Start](SERVICENOW-QUICK-START.md)
- [Zurich Compatibility Guide](SERVICENOW-ZURICH-COMPATIBILITY.md)
- [Setup Checklist](SERVICENOW-SETUP-CHECKLIST.md)
- [Onboarding Script](../scripts/README.md)

---

**Last Updated**: 2025-10-16
**Version**: 1.0.0
**Status**: ✅ Production Ready
