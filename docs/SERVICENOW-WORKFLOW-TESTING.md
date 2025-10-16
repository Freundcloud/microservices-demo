# ServiceNow Workflow Testing Guide

> Complete guide for testing updated GitHub Actions workflows with ServiceNow integration
> Last Updated: 2025-10-16

## Overview

This guide provides step-by-step testing procedures for all three updated workflows that use ServiceNow integration with Basic Authentication.

## Prerequisites

Before testing workflows, ensure you have completed:

- ✅ ServiceNow setup complete ([SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md))
- ✅ GitHub Secrets configured ([GITHUB-SECRETS-SERVICENOW.md](GITHUB-SECRETS-SERVICENOW.md))
- ✅ Authentication tested and working ([SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md))
- ✅ AWS EKS cluster deployed (for eks-discovery.yaml)

**Required GitHub Secrets**:
- `SERVICENOW_INSTANCE_URL`
- `SERVICENOW_USERNAME`
- `SERVICENOW_PASSWORD`
- `SERVICENOW_ORCHESTRATION_TOOL_ID`

## Updated Workflows

| Workflow | File | Purpose | ServiceNow Integration |
|----------|------|---------|------------------------|
| Security Scanning | `security-scan-servicenow.yaml` | Multi-tool security scanning | Uploads SARIF results |
| Deployment | `deploy-with-servicenow.yaml` | EKS deployment with change mgmt | Creates change requests |
| EKS Discovery | `eks-discovery.yaml` | Cluster and service discovery | Updates CMDB tables |

## Testing Strategy

### Testing Order

Test workflows in this sequence:

1. **Security Scanning** (easiest, no infrastructure required)
2. **EKS Discovery** (requires EKS cluster)
3. **Deployment** (full integration test)

### Test Types

**Unit Tests** (per workflow):
- Workflow syntax validation
- Authentication verification
- ServiceNow API calls
- Error handling

**Integration Tests**:
- End-to-end workflow execution
- ServiceNow data verification
- Multi-workflow interaction

---

## Test 1: Security Scanning Workflow

**File**: `.github/workflows/security-scan-servicenow.yaml`

### What This Tests

- CodeQL multi-language analysis
- Semgrep SAST scanning
- Trivy filesystem scanning
- Checkov IaC scanning
- Security results upload to ServiceNow
- Summary generation

### Test Execution

**Method 1: Trigger via Push (Automatic)**
```bash
# Make any code change and push
git add .
git commit -m "test: Trigger security scan"
git push origin main
```

**Method 2: Manual Trigger**
```bash
# Using GitHub CLI
gh workflow run security-scan-servicenow.yaml

# Or via GitHub UI
# Go to: Actions → Security Scanning with ServiceNow Integration → Run workflow
```

**Method 3: Schedule Trigger**
- Workflow runs daily at 2 AM UTC automatically
- Wait for next scheduled run

### Expected Results

**GitHub Actions**:
```
✅ CodeQL Analysis (python)       - Success
✅ CodeQL Analysis (javascript)   - Success
✅ CodeQL Analysis (go)           - Success
✅ CodeQL Analysis (java)         - Success
✅ CodeQL Analysis (csharp)       - Success
✅ Semgrep SAST                   - Success
✅ Trivy Filesystem Scan          - Success
✅ IaC Security Scan              - Success
✅ OWASP Dependency Check         - Success
✅ Security Summary               - Success
```

**ServiceNow Verification**:

1. Navigate to: **Security** → **Security Results** → **All**
2. Filter by: `Application Name = microservices-demo`
3. Expected records:
   ```
   Scanner: CodeQL (5 records - one per language)
   Scanner: Semgrep (1 record)
   Scanner: Trivy (1 record)
   Scanner: Checkov (1 record)
   ```
4. Click each record to verify:
   - ✅ SARIF file attached
   - ✅ Findings listed
   - ✅ Severity levels populated
   - ✅ GitHub context included

**GitHub Summary**:
```markdown
## Security Scan Summary

### Scan Results

| Scan Type | Status |
|-----------|--------|
| CodeQL Analysis | success |
| Semgrep SAST | success |
| Trivy Filesystem | success |
| IaC Scanning | success |
| K8s Manifest Scan | success |

### ServiceNow Integration
✅ Security results uploaded to ServiceNow
- View in ServiceNow: https://calitiiltddemo3.service-now.com/nav_to.do?uri=sn_devops_security_result_list.do
```

### Troubleshooting

**Issue: CodeQL analysis fails**
```bash
# Check Java setup (most common failure)
Error: Could not find or load main class
```
**Solution**: Java 21 build step handles this automatically

**Issue: Security results not in ServiceNow**
```bash
# Check ServiceNow action output
Error: 401 Unauthorized
```
**Solution**: Verify GitHub secrets, check [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)

**Issue: SARIF upload fails**
```bash
Error: No such file: semgrep-results.sarif
```
**Solution**: Check scanner step succeeded before upload

### Test Commands

**Verify security results in ServiceNow**:
```bash
# Using ServiceNow REST API
INSTANCE_URL="https://calitiiltddemo3.service-now.com"
USERNAME="github_integration"
PASSWORD="your-password"

curl -s -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/sn_devops_security_result?sysparm_query=u_application_name=microservices-demo&sysparm_limit=10" \
  | jq '.result[] | {scanner: .u_scanner, created: .sys_created_on, findings: .u_findings_count}'
```

---

## Test 2: EKS Discovery Workflow

**File**: `.github/workflows/eks-discovery.yaml`

### What This Tests

- EKS cluster information retrieval
- Node group discovery
- Microservices deployment scanning
- CMDB updates (u_eks_cluster, u_microservice tables)
- Discovery summary generation

### Prerequisites

**Required**:
- ✅ EKS cluster deployed via Terraform
- ✅ AWS credentials configured in GitHub Secrets
- ✅ Microservices deployed to EKS
- ✅ kubectl access configured

### Test Execution

**Method 1: Manual Trigger**
```bash
# Using GitHub CLI
gh workflow run eks-discovery.yaml

# Or via GitHub UI
# Go to: Actions → EKS Discovery and ServiceNow CMDB Update → Run workflow
```

**Method 2: Schedule Trigger**
- Workflow runs every 6 hours automatically
- Wait for next scheduled run

### Expected Results

**GitHub Actions**:
```
✅ Configure AWS credentials        - Success
✅ Get EKS cluster info             - Success
✅ Upload cluster info to CMDB      - Success
✅ Discover microservices           - Success
✅ Upload microservices to CMDB     - Success
✅ Create discovery summary         - Success
```

**ServiceNow Verification - Cluster**:

1. Navigate to: **CMDB** → **u_eks_cluster**
2. Expected record:
   ```
   Name: microservices
   Region: eu-west-2
   Version: 1.28 (or current version)
   Status: ACTIVE
   VPC: vpc-xxxxx
   Endpoint: https://xxxxx.eks.eu-west-2.amazonaws.com
   ```

**ServiceNow Verification - Microservices**:

1. Navigate to: **CMDB** → **u_microservice**
2. Filter by: `Cluster = microservices`
3. Expected records (12 services):
   ```
   ✅ frontend         (default namespace, 1 replica)
   ✅ cartservice      (default namespace, 1 replica)
   ✅ productcatalogservice (default namespace, 1 replica)
   ✅ currencyservice  (default namespace, 1 replica)
   ✅ paymentservice   (default namespace, 1 replica)
   ✅ shippingservice  (default namespace, 1 replica)
   ✅ emailservice     (default namespace, 1 replica)
   ✅ checkoutservice  (default namespace, 1 replica)
   ✅ recommendationservice (default namespace, 1 replica)
   ✅ adservice        (default namespace, 1 replica)
   ✅ loadgenerator    (default namespace, 1 replica)
   ✅ shoppingassistantservice (default namespace, 1 replica)
   ```
4. Click each record to verify:
   - ✅ Image populated
   - ✅ Replicas count correct
   - ✅ Status = Running
   - ✅ Language detected
   - ✅ Last discovered timestamp recent

**GitHub Artifacts**:
```
discovery-summary-[run_number]
├── discovery-summary.md
├── all-services.json
└── cluster.json
```

**GitHub Summary**:
```markdown
## EKS Discovery Summary

**Cluster**: microservices (eu-west-2)
- **Version**: Kubernetes 1.28
- **Status**: ACTIVE
- **VPC**: vpc-xxxxx

## Microservices Discovered
- frontend [production]: 1/1 replicas - Running
- cartservice [production]: 1/1 replicas - Running
[... 10 more services ...]

## ServiceNow Integration
✅ Data uploaded to ServiceNow CMDB
- **Cluster Record**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_eks_cluster_list.do
- **Services**: https://calitiiltddemo3.service-now.com/nav_to.do?uri=u_microservice_list.do
```

### Troubleshooting

**Issue: Cannot find EKS cluster**
```bash
Error: An error occurred (ResourceNotFoundException) when calling the DescribeCluster operation
```
**Solution**:
- Verify `CLUSTER_NAME` variable in workflow
- Check AWS credentials have EKS read permissions
- Confirm cluster exists: `aws eks describe-cluster --name microservices --region eu-west-2`

**Issue: kubectl not configured**
```bash
Error: error: You must be logged in to the server (Unauthorized)
```
**Solution**: Workflow automatically updates kubeconfig, check AWS credentials

**Issue: CMDB update fails**
```bash
Error: 401 Unauthorized
```
**Solution**: Verify ServiceNow credentials, check [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)

**Issue: Duplicate CMDB entries**
```bash
# Multiple entries for same service
```
**Solution**: Workflow checks for existing entries, but if sys_id changes, duplicates may occur. Manually delete in ServiceNow.

### Test Commands

**Verify cluster in CMDB**:
```bash
INSTANCE_URL="https://calitiiltddemo3.service-now.com"
USERNAME="github_integration"
PASSWORD="your-password"
CLUSTER_NAME="microservices"

curl -s -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/u_eks_cluster?sysparm_query=u_name=${CLUSTER_NAME}" \
  | jq '.result[] | {name: .u_name, region: .u_region, status: .u_status, version: .u_version}'
```

**Verify microservices in CMDB**:
```bash
curl -s -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/u_microservice?sysparm_query=u_cluster_name=${CLUSTER_NAME}&sysparm_limit=100" \
  | jq '.result[] | {name: .u_name, namespace: .u_namespace, replicas: .u_replicas, status: .u_status}' \
  | jq -s 'sort_by(.name)'
```

---

## Test 3: Deployment Workflow

**File**: `.github/workflows/deploy-with-servicenow.yaml`

### What This Tests

- ServiceNow change request creation
- Deployment to EKS (dev/qa/prod)
- Change request auto-approval
- CMDB updates post-deployment
- Deployment summary

### Prerequisites

**Required**:
- ✅ EKS cluster deployed
- ✅ Terraform applied
- ✅ Docker images built and pushed to ECR
- ✅ AWS credentials configured
- ✅ ServiceNow change management configured

### Test Execution

**Method 1: Manual Trigger**
```bash
# Using GitHub CLI (specify environment)
gh workflow run deploy-with-servicenow.yaml -f environment=dev

# Or via GitHub UI
# Go to: Actions → Deploy with ServiceNow Change Management
# Click: Run workflow
# Select: environment (dev/qa/prod)
# Click: Run workflow
```

**Method 2: Trigger via Tag**
```bash
# Create semantic version tag
git tag v1.0.0
git push origin v1.0.0

# Workflow triggers automatically for tags
```

### Expected Results

**GitHub Actions**:
```
✅ Create ServiceNow Change Request  - Success
✅ Wait for Change Approval          - Success (auto-approved)
✅ Configure AWS credentials         - Success
✅ Deploy to EKS                     - Success
✅ Verify deployment                 - Success
✅ Update CMDB with deployment info  - Success
✅ Close Change Request              - Success
✅ Deployment summary                - Success
```

**ServiceNow Verification - Change Request**:

1. Navigate to: **Change** → **All**
2. Filter by: `Short description contains "Deploy microservices-demo"`
3. Expected record:
   ```
   Number: CHG0030001 (example)
   Short description: Deploy microservices-demo to dev
   State: Closed (successful)
   Assignment group: CAB Approval
   Implementation plan: Deploy 12 microservices to EKS dev
   Backout plan: Roll back to previous version
   ```

**ServiceNow Verification - CMDB Updates**:

1. Navigate to: **CMDB** → **u_microservice**
2. Check deployment info updated:
   ```
   Last deployed: [RECENT_TIMESTAMP]
   Deployed by: GitHub Actions
   Change: CHG0030001
   ```

**Kubernetes Verification**:
```bash
# Check all pods running
kubectl get pods -n default

# Expected output
NAME                                     READY   STATUS    RESTARTS   AGE
frontend-xxxxx                          2/2     Running   0          2m
cartservice-xxxxx                       2/2     Running   0          2m
productcatalogservice-xxxxx             2/2     Running   0          2m
[... 9 more services ...]

# Check via Istio ingress
INGRESS_URL=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s http://${INGRESS_URL} | grep "Online Boutique"
# Expected: HTML with "Online Boutique" title
```

**GitHub Summary**:
```markdown
## Deployment Summary

**Environment**: dev
**Status**: ✅ Success

### Change Management
- **Change Request**: CHG0030001
- **State**: Closed
- **Approval**: Automatic

### Deployment Details
- **Services Deployed**: 12
- **Cluster**: microservices (eu-west-2)
- **Namespace**: default
- **Duration**: 5m 23s

### Application URL
🌐 https://xxxxx.elb.eu-west-2.amazonaws.com

### ServiceNow Records
- **Change**: CHG0030001
- **CMDB Updated**: ✅
```

### Troubleshooting

**Issue: Change request not created**
```bash
Error: ServiceNow change creation failed
```
**Solution**:
- Verify `SERVICENOW_ORCHESTRATION_TOOL_ID` secret
- Check GitHub Tool configured in ServiceNow
- Verify user has `devops_user` role

**Issue: Change stuck in pending approval**
```bash
# Change not auto-approving
```
**Solution**:
- Check ServiceNow change automation rules
- Verify approval groups configured
- May need manual approval for first run

**Issue: Deployment fails**
```bash
Error: unable to recognize "release/kubernetes-manifests.yaml": no matches for kind "Deployment"
```
**Solution**:
- Verify kubectl configured
- Check EKS cluster accessible
- Ensure manifests valid: `kubectl apply --dry-run=client -f release/kubernetes-manifests.yaml`

**Issue: Pods not starting**
```bash
# Pods stuck in ImagePullBackOff
```
**Solution**:
- Check ECR images exist: `aws ecr list-images --repository-name frontend`
- Verify IRSA roles configured for node groups
- Check image names in manifests match ECR

### Test Commands

**Verify change request**:
```bash
INSTANCE_URL="https://calitiiltddemo3.service-now.com"
USERNAME="github_integration"
PASSWORD="your-password"

# Get recent changes
curl -s -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/change_request?sysparm_query=short_descriptionLIKEmicroservices-demo&sysparm_limit=5&sysparm_display_value=true" \
  | jq '.result[] | {number: .number, state: .state, short_description: .short_description, sys_created_on: .sys_created_on}'
```

**Check deployment status**:
```bash
# Get all pods
kubectl get pods -A

# Check specific deployment
kubectl rollout status deployment/frontend -n default

# Check Istio gateway
kubectl get gateway,virtualservice -n default
```

---

## Integration Testing

### End-to-End Workflow

Test complete development cycle:

1. **Code Change**
   ```bash
   # Make a code change
   echo "// Update" >> src/frontend/main.go
   git add src/frontend/main.go
   git commit -m "feat: Update frontend"
   git push origin main
   ```

2. **Security Scanning** (automatic)
   - Workflow: `security-scan-servicenow.yaml` triggers
   - Wait for completion (~15 minutes)
   - Verify results in ServiceNow Security

3. **Build Images** (automatic or manual)
   ```bash
   # Trigger build workflow
   gh workflow run build-and-push-images.yaml
   ```
   - Wait for completion (~10 minutes)
   - Verify images in ECR

4. **Deploy to Dev** (manual)
   ```bash
   # Trigger deployment
   gh workflow run deploy-with-servicenow.yaml -f environment=dev
   ```
   - Verify change request created
   - Wait for auto-approval
   - Verify deployment success
   - Check application accessible

5. **Discovery** (automatic after 6 hours, or manual)
   ```bash
   # Trigger discovery
   gh workflow run eks-discovery.yaml
   ```
   - Verify CMDB updated
   - Check new deployment reflected

6. **Promote to QA** (manual)
   ```bash
   # Tag for QA
   git tag v1.0.0-qa
   git push origin v1.0.0-qa

   # Deploy to QA
   gh workflow run deploy-with-servicenow.yaml -f environment=qa
   ```

7. **Promote to Prod** (manual with approval)
   ```bash
   # Tag for production
   git tag v1.0.0
   git push origin v1.0.0

   # Deploy to production
   gh workflow run deploy-with-servicenow.yaml -f environment=prod
   ```

### Multi-Environment Testing

Test deployment across all 3 environments:

```bash
# Deploy to all environments
for ENV in dev qa prod; do
  echo "Deploying to $ENV..."
  gh workflow run deploy-with-servicenow.yaml -f environment=$ENV

  # Wait for completion
  sleep 300  # 5 minutes

  # Verify deployment
  echo "Verifying $ENV deployment..."
  gh run list --workflow=deploy-with-servicenow.yaml --limit=1
done
```

---

## Verification Checklist

### Per-Workflow Checklist

**Security Scanning**:
- [ ] Workflow completes successfully
- [ ] All scanner jobs pass
- [ ] SARIF files uploaded to GitHub Security tab
- [ ] Security results visible in ServiceNow
- [ ] Summary generated correctly

**EKS Discovery**:
- [ ] Cluster info retrieved from AWS
- [ ] Microservices discovered from EKS
- [ ] Cluster record created/updated in CMDB
- [ ] Service records created/updated in CMDB
- [ ] Discovery artifacts uploaded
- [ ] Summary shows correct counts

**Deployment**:
- [ ] Change request created in ServiceNow
- [ ] Change auto-approved (or manually approved)
- [ ] Deployment succeeds to EKS
- [ ] All pods running and healthy
- [ ] Application accessible via Istio ingress
- [ ] CMDB updated with deployment info
- [ ] Change request closed successfully

### ServiceNow Data Quality

Verify data accuracy in ServiceNow:

**Security Results**:
- [ ] Scanner name correct
- [ ] Finding counts match GitHub
- [ ] Severity distribution accurate
- [ ] SARIF files downloadable
- [ ] GitHub context populated

**CMDB - Cluster**:
- [ ] Cluster name matches AWS
- [ ] Region correct
- [ ] Version matches EKS
- [ ] Status = ACTIVE
- [ ] Endpoint URL valid

**CMDB - Microservices**:
- [ ] All 12 services present
- [ ] Names match deployments
- [ ] Namespaces correct
- [ ] Replica counts accurate
- [ ] Images match ECR
- [ ] Status = Running
- [ ] Last discovered timestamp recent

**Change Requests**:
- [ ] Short description clear
- [ ] Implementation plan detailed
- [ ] Backout plan present
- [ ] State progression correct (New → Assess → Approved → Implement → Review → Closed)
- [ ] Assignment group set
- [ ] Linked to CMDB items

---

## Performance Metrics

Track workflow performance:

| Workflow | Expected Duration | Acceptable Range | Failure Threshold |
|----------|-------------------|------------------|-------------------|
| Security Scanning | 15 minutes | 10-20 minutes | > 30 minutes |
| EKS Discovery | 5 minutes | 3-10 minutes | > 15 minutes |
| Deployment | 10 minutes | 5-15 minutes | > 20 minutes |

**Monitor**:
- GitHub Actions execution time
- ServiceNow API response times
- EKS deployment readiness
- Overall workflow success rate

---

## Common Issues and Solutions

### Authentication Issues

**Symptom**: HTTP 401 errors in multiple workflows

**Diagnostic**:
```bash
# Test authentication
curl -v -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**Solutions**: See [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)

### CMDB Duplication

**Symptom**: Multiple records for same cluster/service

**Root Cause**: sys_id changes or query logic issues

**Solution**:
```bash
# Find duplicates in ServiceNow
curl -s -u "${USERNAME}:${PASSWORD}" \
  "${INSTANCE_URL}/api/now/table/u_microservice?sysparm_query=u_name=frontend" \
  | jq '.result | length'

# If > 1, manually delete duplicates in ServiceNow UI
```

### Workflow Timeout

**Symptom**: Workflow exceeds timeout limits

**Solutions**:
- Check network connectivity to AWS/ServiceNow
- Verify no rate limiting
- Review step execution times in logs

### Missing ServiceNow Tables

**Symptom**: CMDB updates fail with "Table not found"

**Solution**:
- Verify tables exist: `u_eks_cluster`, `u_microservice`
- Check table access permissions
- May need ServiceNow admin to create tables

---

## Documentation Updates

After successful testing, update these files:

- [ ] [GITHUB-SECRETS-SERVICENOW.md](GITHUB-SECRETS-SERVICENOW.md) - Add any new secrets
- [ ] [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) - Update setup steps
- [ ] [README.md](README.md) - Update workflow descriptions
- [ ] [CLAUDE.md](CLAUDE.md) - Update CI/CD section

---

## Support and Troubleshooting

### Quick Reference

- **Authentication errors**: [SERVICENOW-401-FIX.md](SERVICENOW-401-FIX.md)
- **Password issues**: [SERVICENOW-PASSWORD-MANAGEMENT.md](SERVICENOW-PASSWORD-MANAGEMENT.md)
- **Tool sys_id extraction**: [SERVICENOW-SYSID-EXTRACTION-GUIDE.md](SERVICENOW-SYSID-EXTRACTION-GUIDE.md)
- **Complete setup**: [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md)

### Working Configuration

```yaml
# Verified working configuration
Instance: https://calitiiltddemo3.service-now.com
Username: github_integration
Password: oA3KqdUVI8Q_^>
Tool sys_id: 4eaebb06c320f690e1bbf0cb05013135
Required Roles: rest_service, api_analytics_read, devops_user
Authentication: Basic Auth (base64 encoded username:password)
```

### Test Workflow Example

```yaml
# Create this file for quick testing: .github/workflows/test-servicenow.yaml
name: Test ServiceNow Integration

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test Authentication
        run: |
          BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

          RESPONSE=$(curl -s -w "\nHTTP:%{http_code}" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sys_user?sysparm_limit=1")

          HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP:" | cut -d: -f2)

          if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ Authentication successful"
          else
            echo "❌ Authentication failed: HTTP $HTTP_CODE"
            exit 1
          fi
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**Tested Workflows**: All 3 workflows verified
**Instance**: calitiiltddemo3.service-now.com
