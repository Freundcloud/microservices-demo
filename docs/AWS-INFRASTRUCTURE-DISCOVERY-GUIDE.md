# AWS Infrastructure Discovery Guide (Terraform State)

## Overview

This guide explains the **AWS Infrastructure Discovery** workflow that automatically discovers and syncs your complete AWS infrastructure to ServiceNow CMDB using Terraform state as the source of truth.

## Table of Contents

1. [What Gets Discovered](#what-gets-discovered)
2. [Why Terraform State?](#why-terraform-state)
3. [Architecture](#architecture)
4. [ServiceNow CMDB Integration](#servicenow-cmdb-integration)
5. [Usage](#usage)
6. [Cost Estimation](#cost-estimation)
7. [Comparison with EKS Discovery](#comparison-with-eks-discovery)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Configuration](#advanced-configuration)

---

## What Gets Discovered

The workflow extracts and syncs **all AWS resources** managed by Terraform in your [terraform-aws](../terraform-aws) directory:

### 🌐 Networking (vpc.tf)
- **VPC** → `cmdb_ci_network`
  - VPC ID, CIDR block, DNS settings, tags
- **Subnets** → `cmdb_ci_network_segment`
  - Public/Private subnets across 3 AZs
  - CIDR blocks, availability zones
- **Internet Gateways** → `cmdb_ci_network_adapter`
  - IGW ID, VPC association
- **NAT Gateways** → `cmdb_ci_network_adapter`
  - NAT ID, Public IP, subnet placement
- **Route Tables** → Discovered but not currently synced
- **VPC Endpoints** → Discovered (ECR, S3, CloudWatch)
  - Service name, type (Interface/Gateway), state

### 🔒 Security (iam.tf, eks.tf)
- **Security Groups** → `cmdb_ci_firewall`
  - Name, description, VPC
  - Ingress/egress rule counts
- **IAM Roles** → `cmdb_ci_service_account`
  - Role name, ARN, description
  - Includes: EKS cluster role, node role, IRSA roles

### ☸️ Compute (eks.tf)
- **EKS Cluster** → `u_eks_cluster` (custom table)
  - Cluster name, version, endpoint, ARN
  - VPC configuration, status
- **EKS Node Groups** → Metadata extracted
  - Instance types, scaling configuration
  - AMI type, disk size, labels, taints

### 💾 Storage & Cache (elasticache.tf)
- **ElastiCache Redis** → `cmdb_ci_database_instance`
  - Cluster ID, engine version
  - Node type, number of nodes
  - Endpoint, encryption settings

### 📦 Container Registry (ecr.tf)
- **ECR Repositories** → `cmdb_ci_app_server`
  - All 12 microservice repositories
  - Repository URL, ARN
  - Scan on push, encryption type

### ⎈ Platform (helm-installs.tf, istio.tf)
- **Helm Releases** → Metadata only
  - Istio components (base, istiod, ingress)
  - Chart version, namespace, status

---

## Why Terraform State?

### Advantages Over Traditional Discovery

| Feature | AWS API Discovery | Terraform State Discovery |
|---------|-------------------|---------------------------|
| **Coverage** | Only running resources | All managed resources |
| **Relationships** | Must be inferred | Already defined in IaC |
| **Accuracy** | Real-time but incomplete | 100% accurate to IaC |
| **Configuration** | Limited metadata | Full configuration details |
| **Tags** | Available | Available + Terraform metadata |
| **Cost Estimation** | Complex | Simple (resource types known) |
| **Drift Detection** | Requires comparison | Built-in |
| **Compliance** | Manual tagging check | Automated IaC validation |

### Terraform State Benefits

✅ **Source of Truth**: Terraform state = deployed infrastructure
✅ **Complete Visibility**: Every resource managed by Terraform
✅ **Relationship Mapping**: VPC → Subnets → EKS → Nodes (already defined)
✅ **No API Rate Limits**: Single state file read
✅ **No Credentials Juggling**: Terraform already authenticated
✅ **IaC Alignment**: CMDB reflects infrastructure-as-code

---

## Architecture

### Discovery Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Workflow Trigger (Daily 6AM UTC or Manual)                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Initialize Terraform                                         │
│     - terraform init                                             │
│     - terraform show -json > terraform-state.json                │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Parse Resources by Type                                      │
│     ├── VPCs (aws_vpc)                                           │
│     ├── Subnets (aws_subnet)                                     │
│     ├── Security Groups (aws_security_group)                     │
│     ├── EKS Cluster (aws_eks_cluster)                            │
│     ├── EKS Node Groups (aws_eks_node_group)                     │
│     ├── Redis (aws_elasticache_replication_group)                │
│     ├── ECR Repos (aws_ecr_repository)                           │
│     ├── IAM Roles (aws_iam_role)                                 │
│     └── Helm Releases (helm_release)                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Transform to ServiceNow Format                               │
│     - Map AWS attributes to CMDB fields                          │
│     - Add discovery metadata (timestamp, source)                 │
│     - Prepare relationship payloads                              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Upload to ServiceNow CMDB (REST API)                         │
│     ├── Create or Update VPCs                                    │
│     ├── Create or Update Subnets                                 │
│     ├── Create or Update Security Groups                         │
│     ├── Create or Update Redis                                   │
│     ├── Create or Update ECR                                     │
│     ├── Create or Update IAM Roles                               │
│     └── Create Relationships (VPC ↔ Subnets)                     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. Generate Reports                                             │
│     ├── Discovery summary (GitHub Actions Summary)              │
│     ├── Cost estimation ($XXX/month)                             │
│     ├── Resource counts by category                              │
│     └── Markdown report (artifact)                               │
└─────────────────────────────────────────────────────────────────┘
```

### Data Extraction Example

**Terraform State (JSON):**
```json
{
  "values": {
    "root_module": {
      "resources": [
        {
          "type": "aws_vpc",
          "values": {
            "id": "vpc-0abc123",
            "cidr_block": "10.0.0.0/16",
            "tags": {"Name": "microservices-vpc"}
          }
        }
      ]
    }
  }
}
```

**ServiceNow CMDB CI (cmdb_ci_network):**
```json
{
  "name": "microservices-vpc",
  "ip_address": "10.0.0.0/16",
  "u_vpc_id": "vpc-0abc123",
  "u_cidr_block": "10.0.0.0/16",
  "u_region": "eu-west-2",
  "u_provider": "AWS",
  "u_last_discovered": "2025-10-20T14:30:00Z",
  "u_discovered_by": "GitHub Actions - Terraform State"
}
```

---

## ServiceNow CMDB Integration

### CMDB Tables Used

| AWS Resource | ServiceNow Table | Key Fields |
|--------------|------------------|------------|
| VPC | `cmdb_ci_network` | u_vpc_id, u_cidr_block, u_region |
| Subnet | `cmdb_ci_network_segment` | u_subnet_id, u_cidr_block, u_availability_zone, u_is_public |
| Security Group | `cmdb_ci_firewall` | u_security_group_id, u_vpc_id, u_ingress_rules, u_egress_rules |
| EKS Cluster | `u_eks_cluster` | u_u_cluster_name, u_u_arn, u_u_version, u_u_endpoint |
| Redis | `cmdb_ci_database_instance` | u_cluster_id, u_engine, u_engine_version, u_endpoint |
| ECR Repository | `cmdb_ci_app_server` | u_repository_arn, u_repository_url, u_scan_on_push |
| IAM Role | `cmdb_ci_service_account` | u_role_arn, u_description |

### Relationships Created

The workflow creates CI relationships in `cmdb_rel_ci` table:

**VPC → Subnets (Contains)**
```
Type: d93304fb0a0a0b78006081a72ef08444 (Contains::Contained by)
Parent: VPC sys_id
Child: Subnet sys_id
```

**Future Relationships** (can be added):
- VPC → Security Groups
- Subnet → EKS Node Groups
- EKS Cluster → Node Groups
- Node Groups → EC2 Instances

### Custom Fields Required

If using standard ServiceNow tables, you'll need to add custom fields (u_* prefix):

#### cmdb_ci_network (VPC)
```
u_vpc_id (String)
u_cidr_block (String)
u_region (String)
u_provider (String)
u_last_discovered (Date/Time)
u_discovered_by (String)
```

#### cmdb_ci_network_segment (Subnet)
```
u_subnet_id (String)
u_cidr_block (String)
u_availability_zone (String)
u_vpc_id (String)
u_is_public (Boolean)
u_last_discovered (Date/Time)
```

#### cmdb_ci_firewall (Security Group)
```
u_security_group_id (String)
u_vpc_id (String)
u_ingress_rules (Integer)
u_egress_rules (Integer)
u_last_discovered (Date/Time)
```

**Note**: The workflow uses `u_eks_cluster` custom table from the existing EKS discovery workflow.

---

## Usage

### Trigger Methods

#### 1. Scheduled (Automatic)
```yaml
# Runs daily at 6 AM UTC
on:
  schedule:
    - cron: '0 6 * * *'
```

#### 2. Manual (workflow_dispatch)
```bash
# Via GitHub Actions UI
Actions → AWS Infrastructure Discovery → Run workflow

# Via GitHub CLI
gh workflow run aws-infrastructure-discovery.yaml
```

#### 3. On Terraform Changes
```yaml
# Runs when Terraform files are modified
on:
  push:
    paths:
      - 'terraform-aws/**'
```

### View Results

#### GitHub Actions Summary
Every run produces a detailed summary:

```
🔍 AWS Infrastructure Discovery

Discovery Time: 2025-10-20 14:30:00 UTC
Region: eu-west-2
Source: Terraform State

Terraform State Extraction
✅ Terraform initialized
- State file size: 2.3M
- Total resources: 147

🌐 VPC & Networking Discovery

VPCs: 1
- microservices-vpc (vpc-0abc123) - CIDR: 10.0.0.0/16

Subnets: 6
- microservices-private-eu-west-2a (eu-west-2a) - 10.0.1.0/24 - Private
- microservices-private-eu-west-2b (eu-west-2b) - 10.0.2.0/24 - Private
...

💰 Resource Summary & Cost Estimate

| Resource Type | Count | Est. Monthly Cost (USD) |
|--------------|-------|-------------------------|
| VPC | 1 | $0 |
| NAT Gateways | 1 | $32 |
| EKS Cluster | 1 | $73 |
| EKS Node Groups | 1 | $61 |
| Redis | 1 | $15 |
| TOTAL | - | $181 |
```

#### ServiceNow CMDB
Navigate to ServiceNow:

- **Networks**: Service Catalog → CMDB → Networks
- **Subnets**: Service Catalog → CMDB → Network Segments
- **Security Groups**: Service Catalog → CMDB → Firewalls
- **Redis**: Service Catalog → CMDB → Database Instances
- **ECR**: Service Catalog → CMDB → Application Servers
- **IAM**: Service Catalog → CMDB → Service Accounts

#### Workflow Artifacts
Download detailed JSON files:

```
infrastructure-discovery-{run_number}/
├── discovery-report.md          # Human-readable summary
├── terraform-state.json         # Full Terraform state
├── network-resources.json       # VPC, subnets, gateways
├── security-groups.json         # Security groups with rules
├── eks-cluster.json             # EKS cluster metadata
├── eks-node-groups.json         # Node group configurations
├── elasticache-redis.json       # Redis cluster details
├── ecr-repositories.json        # ECR repositories
├── iam-roles.json               # IAM roles
├── helm-releases.json           # Helm charts
└── resource-summary.json        # Counts and cost estimate
```

---

## Cost Estimation

The workflow provides approximate monthly costs based on standard AWS pricing (eu-west-2):

### Cost Calculation Logic

```bash
# NAT Gateways: $32/gateway/month
NAT_COST = nat_gateway_count × $32

# EKS Cluster: $73/cluster/month (control plane)
EKS_COST = $73

# EKS Node Groups: Varies by instance type
# Simplified: $61/month per t3.large node group
NODE_COST = node_group_count × $61

# ElastiCache Redis: Varies by node type
# Simplified: $15/month for cache.t3.micro
REDIS_COST = redis_cluster_count × $15

# Total
TOTAL_COST = NAT_COST + EKS_COST + NODE_COST + REDIS_COST
```

### Example Output

For the ultra-minimal configuration (1 node group):

```
Estimated Monthly Cost: $181 USD

Breakdown:
- NAT Gateways (1): $32
- EKS Control Plane: $73
- Node Groups (1): $61
- Redis (1): $15
```

### Cost Optimization Opportunities

The workflow helps identify:
- **Unused NAT Gateways**: Consider using VPC endpoints instead
- **Over-provisioned node groups**: Check actual usage vs capacity
- **Idle Redis clusters**: Remove if not used by microservices
- **Unnecessary ECR repositories**: Clean up old/unused repos

---

## Comparison with EKS Discovery

You have **two complementary discovery workflows**:

### EKS Discovery (Runtime State)
**File**: [`.github/workflows/eks-discovery.yaml`](../.github/workflows/eks-discovery.yaml)

**What it discovers:**
- ✅ EKS cluster runtime state (from AWS API)
- ✅ Kubernetes nodes with resource utilization
- ✅ Running microservices across all namespaces
- ✅ Pod counts, replica status, health

**Schedule**: Every 6 hours (runtime changes frequently)

**Use case**: Monitor application health, track deployments

---

### AWS Infrastructure Discovery (IaC State)
**File**: [`.github/workflows/aws-infrastructure-discovery.yaml`](../.github/workflows/aws-infrastructure-discovery.yaml)

**What it discovers:**
- ✅ Complete AWS infrastructure (from Terraform state)
- ✅ Networking (VPC, subnets, NAT, security groups)
- ✅ Storage (Redis, ECR)
- ✅ Security (IAM roles, policies)
- ✅ Platform (Helm releases)

**Schedule**: Daily (infrastructure changes less often)

**Use case**: Infrastructure inventory, cost analysis, compliance

---

### Combined Power

**Together, these workflows provide:**

1. **Complete Visibility**
   - Infrastructure layer (Terraform)
   - Runtime layer (Kubernetes)
   - Application layer (Microservices)

2. **Drift Detection**
   - Compare Terraform state vs AWS API
   - Identify manual changes outside IaC

3. **Compliance Evidence**
   - Prove infrastructure matches IaC
   - Track all resources for audits

4. **Cost Attribution**
   - Infrastructure costs (from Terraform)
   - Runtime utilization (from K8s metrics)

---

## Troubleshooting

### Issue: No resources discovered

**Symptoms:**
```
Total resources: 0
```

**Causes & Solutions:**

1. **Terraform not initialized**
   ```bash
   # Check: Terraform state exists
   cd terraform-aws
   terraform state list

   # Fix: Initialize and apply
   terraform init
   terraform apply
   ```

2. **Wrong directory**
   ```yaml
   # Check: TF_DIR environment variable
   env:
     TF_DIR: terraform-aws  # Must match your directory
   ```

3. **Empty state**
   ```bash
   # Check: State has resources
   terraform show -json | jq '.values.root_module.resources | length'

   # Fix: Deploy infrastructure first
   terraform apply
   ```

---

### Issue: ServiceNow upload fails

**Symptoms:**
```
⚠️ ServiceNow CMDB integration not configured
```

**Causes & Solutions:**

1. **Missing secrets**
   ```bash
   # Required secrets:
   SERVICENOW_INSTANCE_URL=https://your-instance.service-now.com
   SERVICENOW_USERNAME=github_integration
   SERVICENOW_PASSWORD=your-password
   ```

2. **Invalid credentials**
   ```bash
   # Test credentials
   curl -u "username:password" \
     "https://your-instance.service-now.com/api/now/table/cmdb_ci_network?sysparm_limit=1"
   ```

3. **Missing CMDB tables/fields**
   - Ensure custom fields (u_*) exist in ServiceNow
   - Check user has CMDB write permissions

---

### Issue: Custom fields missing in ServiceNow

**Symptoms:**
```
Field 'u_vpc_id' does not exist on table 'cmdb_ci_network'
```

**Solution:**

Create custom fields in ServiceNow:

1. Navigate to: **System Definition → Tables**
2. Find table (e.g., `cmdb_ci_network`)
3. Go to **Columns** tab
4. Add custom columns:
   - `u_vpc_id` (String, 255)
   - `u_cidr_block` (String, 50)
   - `u_region` (String, 50)
   - `u_provider` (String, 50)
   - `u_last_discovered` (Date/Time)
   - `u_discovered_by` (String, 100)

Repeat for all tables in [ServiceNow CMDB Integration](#servicenow-cmdb-integration) section.

---

### Issue: Relationships not created

**Symptoms:**
- VPCs and Subnets exist in CMDB
- No visible relationships in ServiceNow

**Causes & Solutions:**

1. **sys_id mapping failed**
   ```bash
   # Check: VPC sys_ids saved
   cat vpc-sys-ids.txt
   # Should show: vpc-0abc123=<sys_id>
   ```

2. **Relationship type invalid**
   ```yaml
   # Default relationship type for "Contains"
   type: "d93304fb0a0a0b78006081a72ef08444"

   # Find your instance's relationship type:
   # ServiceNow → CMDB → Relationship Types → "Contains::Contained by"
   ```

3. **Check relationships in ServiceNow**
   - Open VPC CI record
   - Go to **Related Items** → **Relationships**
   - Should see subnets listed

---

### Issue: Cost estimate inaccurate

**Symptoms:**
```
Estimated Monthly Cost: $0
```

**Explanation:**

The cost estimation uses **simplified assumptions**:
- Fixed price per resource type
- Doesn't account for: data transfer, storage, snapshots
- Doesn't consider: Reserved Instances, Savings Plans

**To improve accuracy:**

1. Use AWS Cost Explorer API
2. Parse actual billing data
3. Implement resource-specific calculators

---

## Advanced Configuration

### Customize ServiceNow Tables

Edit the workflow to use different CMDB tables:

```yaml
# Change from cmdb_ci_network to custom table
- name: Upload VPC to ServiceNow CMDB
  run: |
    # Replace: cmdb_ci_network
    # With: u_aws_vpc (your custom table)

    curl -X POST \
      "${SERVICENOW_INSTANCE_URL}/api/now/table/u_aws_vpc" \
      ...
```

### Add More Resource Types

To discover additional AWS resources:

1. **Add extraction step**:
   ```yaml
   - name: Discover S3 buckets
     run: |
       jq -r '
         [.values.root_module.resources[]?, .values.root_module.child_modules[]?.resources[]?] |
         map(select(.type == "aws_s3_bucket")) |
         map({
           name: .values.bucket,
           arn: .values.arn,
           region: .values.region
         })
       ' terraform-state.json > s3-buckets.json
   ```

2. **Add ServiceNow upload step**:
   ```yaml
   - name: Upload S3 to ServiceNow
     run: |
       # Upload to cmdb_ci_storage_device
       # Or custom u_s3_bucket table
   ```

### Change Discovery Schedule

```yaml
on:
  schedule:
    # Daily at 6 AM UTC
    - cron: '0 6 * * *'

    # Change to: Every 12 hours
    - cron: '0 */12 * * *'

    # Or: Weekly on Mondays at 9 AM
    - cron: '0 9 * * 1'
```

### Filter Resources by Tags

Extract only tagged resources:

```bash
jq -r '
  [.values.root_module.resources[]?, .values.root_module.child_modules[]?.resources[]?] |
  map(select(.type == "aws_vpc")) |
  map(select(.values.tags.Environment == "production"))  # Filter by tag
' terraform-state.json > vpcs.json
```

### Export to Other Systems

The extracted JSON files can be used for:

**Cost Management Tools:**
```bash
# Send to CloudHealth, CloudCheckr, etc.
curl -X POST "https://cost-tool.example.com/api/resources" \
  -d @resource-summary.json
```

**Asset Management:**
```bash
# Import into internal CMDB/asset tracking
python import-to-asset-db.py resource-summary.json
```

**Compliance Tools:**
```bash
# Export for security audits
zip compliance-evidence.zip *.json discovery-report.md
```

---

## Related Documentation

- [EKS Discovery Workflow](../. github/workflows/eks-discovery.yaml) - Runtime state discovery
- [ServiceNow Integration Guide](./GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) - Complete integration docs
- [Security Evidence Guide](./SECURITY-EVIDENCE-GUIDE.md) - Security scan evidence
- [Terraform AWS README](../terraform-aws/README.md) - Infrastructure details

---

## Support

### Questions

- Review [GitHub Discussions](https://github.com/Calitti/ARC/microservices-demo/discussions)
- Check workflow run logs for detailed output
- Verify Terraform state: `cd terraform-aws && terraform show`

### Issues

- [Report workflow issues](https://github.com/Calitti/ARC/microservices-demo/issues)
- Include: Run ID, screenshots, error messages
- Attach: Workflow artifacts (if not sensitive)

---

**Last Updated:** 2025-10-20
**Version:** 1.0.0
**Maintainer:** DevOps Team
