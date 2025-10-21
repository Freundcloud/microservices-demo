# Utility Workflows

These workflows are **standalone utilities** that remain active for manual operations. They are not part of the main CI/CD pipeline.

## Active Utility Workflows

### 1. MASTER-PIPELINE.yaml ✅
**Purpose**: Main CI/CD pipeline - single entry point for all deployments

**Status**: ✅ **PRIMARY WORKFLOW** - Use this for all deployments

**Usage**:
```bash
# Automatic on push to main
git push origin main

# Manual deployment
gh workflow run MASTER-PIPELINE.yaml -f environment=dev
gh workflow run MASTER-PIPELINE.yaml -f environment=qa
gh workflow run MASTER-PIPELINE.yaml -f environment=prod
```

---

### 2. aws-infrastructure-discovery.yaml ⚠️
**Purpose**: Discovery and documentation of AWS infrastructure for ServiceNow CMDB

**Status**: ⚠️ **OPTIONAL UTILITY** - Manual use only

**When to Use**:
- Initial setup of ServiceNow CMDB
- After major infrastructure changes
- Quarterly CMDB refresh/audit

**Usage**:
```bash
gh workflow run aws-infrastructure-discovery.yaml
```

**What It Does**:
- Scans AWS account for all resources (EC2, VPC, RDS, S3, etc.)
- Generates comprehensive inventory
- Optionally populates ServiceNow CMDB

---

### 3. eks-discovery.yaml ⚠️
**Purpose**: Discover and document EKS cluster resources

**Status**: ⚠️ **OPTIONAL UTILITY** - Manual use only

**When to Use**:
- Initial cluster setup
- After major Kubernetes changes
- Troubleshooting cluster configuration

**Usage**:
```bash
gh workflow run eks-discovery.yaml
```

**What It Does**:
- Lists all EKS clusters in region
- Inventories nodes, pods, services
- Documents Istio configuration
- Generates cluster topology

---

### 4. setup-servicenow-cmdb.yaml ⚠️
**Purpose**: One-time setup for ServiceNow CMDB integration

**Status**: ⚠️ **ONE-TIME SETUP** - Run once during initial configuration

**When to Use**:
- Initial project setup
- After ServiceNow instance refresh
- When reconfiguring CMDB integration

**Usage**:
```bash
gh workflow run setup-servicenow-cmdb.yaml
```

**What It Does**:
- Creates CMDB CI classes
- Configures integration points
- Sets up initial relationships
- Validates connectivity

---

## Deprecated Workflows

All other workflows have been moved to `.github/workflows/DEPRECATED/`:

- ❌ Auto-deploy workflows → Use `MASTER-PIPELINE.yaml` instead
- ❌ ServiceNow deployment workflows → Use `MASTER-PIPELINE.yaml` instead
- ❌ Build and push workflows → Use `MASTER-PIPELINE.yaml` instead
- ❌ Terraform workflows → Use `MASTER-PIPELINE.yaml` instead
- ❌ Security scan workflows → Use `MASTER-PIPELINE.yaml` instead

See `DEPRECATED/README.md` for complete migration guide.

---

## Workflow Decision Tree

```
Do you want to deploy the application?
├─ YES → Use MASTER-PIPELINE.yaml ✅
│
Do you need to discover AWS infrastructure?
├─ YES → Use aws-infrastructure-discovery.yaml ⚠️
│
Do you need to analyze EKS cluster?
├─ YES → Use eks-discovery.yaml ⚠️
│
Do you need to setup ServiceNow CMDB?
└─ YES → Use setup-servicenow-cmdb.yaml ⚠️ (one-time only)
```

---

## Maintenance Guidelines

### For MASTER-PIPELINE.yaml
- **Update frequency**: As needed for pipeline improvements
- **Testing**: Always test in dev before production
- **Review**: Required for any changes

### For Utility Workflows
- **Update frequency**: Rarely (only for bug fixes)
- **Testing**: Test against non-production environments
- **Review**: Optional for minor changes

### For Deprecated Workflows
- **Status**: Frozen - no updates
- **Retention**: 2 months from deprecation date
- **Deletion**: March 2025

---

**Last Updated**: January 2025
**Maintained By**: DevOps Team
