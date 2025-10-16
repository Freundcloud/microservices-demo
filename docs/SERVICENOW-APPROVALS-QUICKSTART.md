# ServiceNow Approvals - Quick Start Guide

> **Time to Complete**: 15 minutes
> **Purpose**: Set up and test approval workflow for dev/qa/prod deployments

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] ServiceNow instance access (admin role)
- [ ] GitHub repository access
- [ ] AWS credentials configured
- [ ] EKS cluster running
- [ ] ServiceNow secrets configured in GitHub

---

## Step 1: Run Automated Setup (2 minutes)

The automated script creates the three required approval groups:

```bash
cd /home/olafkfreund/Source/Calitti/ARC/microservices-demo

# Set environment variables
export SERVICENOW_INSTANCE_URL="https://calitiiltddemo3.service-now.com"
export SERVICENOW_USERNAME="github_integration"
export SERVICENOW_PASSWORD='oA3KqdUVI8Q_^>'

# Run setup script
bash scripts/setup-servicenow-approvals.sh
```

**Expected Output**:
```
═══════════════════════════════════════════════════════════════
       ServiceNow Approval Groups Setup Script
═══════════════════════════════════════════════════════════════

[SUCCESS] Prerequisites check passed
[SUCCESS] ServiceNow connectivity verified
[SUCCESS] Current user: GitHub Integration (a1b2c3d4...)
[SUCCESS] ✓ QA Team (Manager: GitHub Integration, Active: true)
[SUCCESS] ✓ DevOps Team (Manager: GitHub Integration, Active: true)
[SUCCESS] ✓ Change Advisory Board (Manager: GitHub Integration, Active: true)

Next Steps: [see output]
```

---

## Step 2: Test Dev Deployment (No Approval) - 5 minutes

Dev deployments are auto-approved and deploy immediately.

### Trigger Deployment

```bash
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=dev
```

### Monitor Progress

```bash
# Get latest run ID
RUN_ID=$(gh run list --workflow=deploy-with-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)

# Watch the run
gh run watch $RUN_ID --repo Freundcloud/microservices-demo
```

### Expected Behavior

```
✅ Create Change Request        (30 seconds)
   └─ Change Request: CHG0123456
   └─ Risk: Low
   └─ Auto-close: true

⏩ Wait for Approval             (SKIPPED - dev environment)

✅ Pre-Deployment Checks         (1 minute)
   └─ EKS cluster access verified
   └─ Namespace exists

✅ Deploy to dev                 (2 minutes)
   └─ Kustomize apply
   └─ 11 services deployed
   └─ All pods running

✅ Update CMDB                   (30 seconds)

✅ Close Change Request          (10 seconds)
   └─ Status: Successful
```

### Verify in ServiceNow

1. **Open**: https://calitiiltddemo3.service-now.com/change_request_list.do

2. **Filter**:
   - Number: CHG0123456 (from workflow output)
   - OR: Short description contains "dev"

3. **Verify**:
   - ✅ State: Closed
   - ✅ Close code: successful
   - ✅ Risk: Low
   - ✅ Priority: 3 (Low)

---

## Step 3: Test QA Deployment (Single Approval) - 5 minutes

QA deployments require QA Team Lead approval.

### Trigger Deployment

```bash
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=qa
```

### Monitor Progress

```bash
RUN_ID=$(gh run list --workflow=deploy-with-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)
gh run watch $RUN_ID --repo Freundcloud/microservices-demo
```

### Expected Behavior

```
✅ Create Change Request        (30 seconds)
   └─ Change Request: CHG0123457
   └─ Risk: Medium
   └─ Assignment Group: QA Team

⏸️  Wait for Approval            (PAUSED)
   └─ Polling ServiceNow every 30 seconds...
   └─ Timeout: 2 hours
   └─ Approvers notified via email
```

### Approve in ServiceNow

**Method 1: Via Email** (if configured)
1. Check email inbox
2. Look for "Approval Required: CHG0123457"
3. Click "Approve" link
4. Add optional comments
5. Submit

**Method 2: Via ServiceNow UI** (fastest for testing)
1. **Open**: https://calitiiltddemo3.service-now.com/change_request_list.do

2. **Find**: CHG0123457 (from workflow output)

3. **Open**: Click on the change request number

4. **Scroll**: To "Approval" section

5. **Change**: Approval dropdown from "Requested" to "Approved"

6. **Click**: Update

### Workflow Resumes

After approval, the workflow continues automatically:

```
✅ Approval Received            (within 30 seconds)

✅ Pre-Deployment Checks         (1 minute)

✅ Deploy to qa                  (3 minutes)
   └─ 11 services + loadgenerator
   └─ 2 replicas per service

✅ Smoke Tests                   (1 minute)
   └─ Homepage: HTTP 200
   └─ Product page: HTTP 200

✅ Update CMDB                   (30 seconds)

✅ Close Change Request          (10 seconds)
```

### Verify in ServiceNow

1. **Reload**: Change request page

2. **Verify**:
   - ✅ State: Closed
   - ✅ Approval: Approved
   - ✅ Approved by: [Your name]
   - ✅ Close code: successful

---

## Step 4: Test Production Deployment (Multi-Level Approval) - 5 minutes

Production deployments require DevOps Lead + CAB approval.

### Trigger Deployment

```bash
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=prod
```

### Monitor Progress

```bash
RUN_ID=$(gh run list --workflow=deploy-with-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)
gh run watch $RUN_ID --repo Freundcloud/microservices-demo
```

### Expected Behavior

```
✅ Create Change Request        (30 seconds)
   └─ Change Request: CHG0123458
   └─ Risk: High
   └─ Priority: 1 (Critical)
   └─ Assignment Group: Change Advisory Board

⏸️  Wait for Approval            (PAUSED)
   └─ Stage 1: DevOps Lead approval
   └─ Stage 2: CAB approval (2 required)
   └─ Timeout: 24 hours
```

### Stage 1: DevOps Lead Approval

1. **Open**: https://calitiiltddemo3.service-now.com/change_request.do?sys_id=CHG0123458

2. **Scroll**: To "Approvers" section

3. **Find**: DevOps Team approver (Approval Order: 1)

4. **Click**: Approve

5. **Add Comment**: "Infrastructure ready for production deployment"

6. **Submit**

**Status**: Stage 1 complete ✅

### Stage 2: CAB Approval (Need 2 approvals)

1. **Find**: CAB Member approvers (Approval Order: 2)

2. **First CAB Member**:
   - Click Approve
   - Comment: "Business impact reviewed and approved"
   - Submit

3. **Second CAB Member**:
   - Click Approve
   - Comment: "Security review passed"
   - Submit

**Status**: Stage 2 complete ✅ → Workflow resumes

### Workflow Completes

```
✅ All Approvals Received

✅ Pre-Deployment Checks         (1 minute)

✅ Deploy to prod                (5 minutes)
   └─ 11 services (no loadgenerator)
   └─ 3 replicas per service (HA)
   └─ Rolling update strategy

✅ Comprehensive Smoke Tests     (2 minutes)

✅ Update CMDB                   (1 minute)

✅ Close Change Request          (10 seconds)
   └─ Detailed close notes with metrics
```

### Verify Production Deployment

```bash
# Check production pods
kubectl get pods -n microservices-prod

# Verify all running
kubectl get pods -n microservices-prod -o json | jq '[.items[] | select(.status.phase=="Running")] | length'

# Get application URL
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Step 5: Test Rejection Flow (2 minutes)

### Trigger Another QA Deployment

```bash
gh workflow run deploy-with-servicenow.yaml \
  --repo Freundcloud/microservices-demo \
  --field environment=qa
```

### Reject the Change Request

1. **Open**: Latest change request in ServiceNow

2. **Scroll**: To "Approval" section

3. **Change**: Approval dropdown to "Rejected"

4. **Work Notes**: "Insufficient testing documentation provided"

5. **Click**: Update

### Expected Behavior

```
❌ Approval Rejected             (within 30 seconds)
   └─ Reason: Insufficient testing documentation

❌ Workflow Failed               (immediate)
   └─ Job: Wait for Change Approval
   └─ Exit code: 1

✅ Change Request Closed         (automatic)
   └─ State: Closed/Rejected
   └─ Close code: Rejected
   └─ Close notes: [Rejection reason]
```

---

## Verification Checklist

After completing all steps, verify:

- [ ] Dev deployment completed without approval (auto-approved)
- [ ] QA deployment waited for approval and resumed after approval
- [ ] Production deployment required multi-level approval
- [ ] Rejection properly failed the workflow
- [ ] All change requests visible in ServiceNow
- [ ] CMDB updated with deployment information
- [ ] Email notifications sent (if configured)

---

## Troubleshooting

### Workflow Stuck "Waiting for Approval"

**Symptoms**: Workflow shows "Polling ServiceNow..." but doesn't resume after approval

**Fixes**:

1. **Check Change Request State**:
   ```bash
   PASSWORD='oA3KqdUVI8Q_^>' bash -c 'curl -s -u "github_integration:$PASSWORD" \
     "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=number=CHG0123456" \
     | jq ".result[0] | {state, approval, approval_history}"'
   ```

2. **Verify Approval Status**: State should be "Approved" not just "Requested"

3. **Wait 30 seconds**: Workflow polls every 30 seconds

4. **Check ServiceNow DevOps Plugin**: Navigate to Plugins → Search "DevOps Change" → Verify "Active"

### No Email Notifications

**Fix**: Enable outbound email in ServiceNow
1. Navigate to: System Mailboxes → Administration
2. Verify SMTP configuration
3. Test email: System Mailboxes → Email Logs

### Approval Not Creating Approvers

**Symptoms**: Change request created but no approvers assigned

**Fixes**:
1. Verify approval groups exist and have members
2. Check approval rules are active
3. Verify assignment group matches rule conditions

---

## Next Steps

Now that approvals are working:

1. **Add Team Members**:
   - Add real QA team members to QA Team group
   - Add DevOps engineers to DevOps Team group
   - Add executives to CAB group

2. **Configure Email Notifications**:
   - See: [SERVICENOW-APPROVALS.md](SERVICENOW-APPROVALS.md#step-3-configure-email-notifications-5-minutes)

3. **Create Custom Approval Rules**:
   - Time-based rules (after hours, weekends)
   - Risk-based rules (high risk = more approvers)
   - Emergency change fast-track

4. **Set Up Dashboards**:
   - Pending approvals widget
   - Approval turnaround time metrics
   - Rejection rate tracking

5. **Train Your Team**:
   - Share [SERVICENOW-APPROVALS.md](SERVICENOW-APPROVALS.md)
   - Walk through approval process
   - Document your org's specific policies

---

## Summary

You've successfully configured and tested:

✅ **3 approval groups**: QA Team, DevOps Team, Change Advisory Board
✅ **3 deployment environments**: dev (auto), qa (1 approval), prod (multi-level)
✅ **Approval workflow**: Create → Wait → Approve → Deploy → Close
✅ **Rejection handling**: Properly fails workflow and closes change request

**Your deployment pipeline now has enterprise-grade change control!**

---

## Related Documentation

- [Complete Approval Guide](SERVICENOW-APPROVALS.md)
- [Deployment Workflow](.github/workflows/deploy-with-servicenow.yaml)
- [Kustomize Multi-Environment](../kustomize/overlays/README.md)
- [ServiceNow Quick Start](SERVICENOW-QUICK-START.md)
