# GitHub + ServiceNow Integration - Developer Onboarding Guide

**Last Updated**: 2025-10-20
**Version**: 1.0
**Estimated Time**: 30 minutes
**Audience**: New developers joining the team

---

## Welcome! 👋

This guide will help you understand how we use GitHub Actions and ServiceNow together for change management and deployments. By the end, you'll know how to:

- Deploy to dev/qa/prod environments
- Create and track change requests
- Navigate the approval process
- Troubleshoot common issues

---

## Table of Contents

1. [Quick Overview](#quick-overview)
2. [Your First Deployment](#your-first-deployment)
3. [Understanding Environments](#understanding-environments)
4. [The Approval Process](#the-approval-process)
5. [Common Tasks](#common-tasks)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)
8. [Getting Help](#getting-help)

---

## Quick Overview

### What is ServiceNow?

ServiceNow is our IT Service Management (ITSM) platform. We use it to:
- Track all changes to production
- Manage approvals for deployments
- Maintain an audit trail for compliance
- Visualize service dependencies

### How Does It Work with GitHub?

```
You trigger → GitHub Actions → Creates ServiceNow → Waits for → Deploys to
workflow       workflow runs   change request     approval      EKS cluster
```

Every deployment automatically:
1. Creates a change request in ServiceNow
2. Waits for approval (unless dev environment)
3. Deploys the application
4. Updates the change request with results

### Key Terminology

| Term | What It Means |
|------|---------------|
| **Change Request (CR)** | A record in ServiceNow tracking a deployment |
| **Change Number** | Unique ID like CHG0001234 |
| **Approval** | Permission required before deploying to qa/prod |
| **DevOps Workspace** | Modern UI in ServiceNow showing all deployments |
| **Correlation ID** | Links GitHub runs to ServiceNow changes |

---

## Your First Deployment

### Prerequisites Checklist

Before you start, make sure you have:

- [ ] GitHub account with access to this repository
- [ ] Permission to trigger GitHub Actions workflows
- [ ] ServiceNow account (for viewing change requests)
- [ ] AWS access (optional, for viewing cluster directly)
- [ ] Slack access (for deployment notifications)

### Step 1: Deploy to Dev (5 minutes)

Dev deployments are auto-approved and perfect for learning!

1. **Go to GitHub Actions**
   ```
   https://github.com/YOUR-ORG/microservices-demo/actions
   ```

2. **Select Workflow**
   - Click "Deploy with ServiceNow (Hybrid - REST API + Correlation)"
   - Or use the Quick Deploy workflow

3. **Click "Run workflow"**
   - Select branch: `main` (or your feature branch)
   - Choose environment: `dev`
   - Click green "Run workflow" button

4. **Watch the Workflow**
   - Job 1: Creates ServiceNow change request (30 seconds)
   - Job 2: Skipped (no approval needed for dev)
   - Job 3: Pre-deployment checks (20 seconds)
   - Job 4: Deploys application (2-3 minutes)
   - Job 5: Updates change request (10 seconds)

5. **View Results**
   - Click on the completed workflow run
   - Look for the "Deployment Summary" section
   - You'll see:
     - ✅ Change Request number (e.g., CHG0001234)
     - ✅ Link to ServiceNow
     - ✅ Deployment status
     - ✅ Kubernetes pod status

**🎉 Congratulations! You've deployed to dev!**

### Step 2: View in ServiceNow (5 minutes)

Now let's see the change request that was automatically created.

1. **Get ServiceNow URL**
   - From workflow output: Look for "View in ServiceNow" link
   - Or go to: https://calitiiltddemo3.service-now.com

2. **Login**
   - Use your ServiceNow credentials
   - (Ask your team lead if you don't have an account)

3. **View Change Request**
   - Click the ServiceNow link from workflow output
   - Or search for change number (e.g., CHG0001234)

4. **Explore the Change**
   Look at these fields:
   - **Short Description**: "Deploy Online Boutique to dev"
   - **State**: "Closed - Successful" (dev is auto-closed)
   - **Description**: Full details including commit SHA, actor, GitHub run URL
   - **Implementation Plan**: Step-by-step deployment process
   - **Backout Plan**: How to rollback if needed
   - **Work Notes**: Log of what happened

5. **View in DevOps Workspace**
   - Navigate to: https://calitiiltddemo3.service-now.com/now/devops-change/home
   - See modern UI with pipeline visualization
   - View DORA metrics (deployment frequency, etc.)

**📊 Now you can see how GitHub and ServiceNow work together!**

### Step 3: Understand What Happened (5 minutes)

Let's break down the workflow execution:

#### Phase 1: Create Change Request
```yaml
# Workflow created a change request with:
{
  "short_description": "Deploy Online Boutique to dev",
  "state": "3",  # Closed/Complete (auto-approved for dev)
  "correlation_id": "github-YOUR-ORG/microservices-demo-123456",
  "description": "Full details including commit, actor, run URL",
  "implementation_plan": "Detailed steps",
  "backout_plan": "How to rollback",
  "test_plan": "Verification steps"
}
```

#### Phase 2: Deploy Application
```bash
# Used Kustomize to deploy to dev namespace
kubectl apply -k kustomize/overlays/dev

# This deployed all 11 microservices:
# - frontend
# - cartservice (with Redis)
# - productcatalogservice
# - currencyservice
# - paymentservice
# - shippingservice
# - emailservice
# - checkoutservice
# - recommendationservice
# - adservice
# - loadgenerator (dev/qa only)
```

#### Phase 3: Update Change Request
```yaml
# Workflow updated the change with:
{
  "state": "3",  # Confirmed closed
  "close_code": "successful",
  "close_notes": "Deployment completed successfully",
  "work_notes": "All pods running, deployment verified"
}
```

---

## Understanding Environments

We have three environments with different characteristics:

### Dev Environment

**Purpose**: Rapid iteration and testing

**Characteristics**:
- 🚀 Auto-approved (no waiting)
- 🏃 Fast deployments (1-2 replicas)
- 🧪 Includes load generator
- 💰 Minimal resources (cost-efficient)
- 🔄 Can deploy multiple times per day

**When to Use**:
- Testing new features
- Debugging issues
- Experimenting with changes
- Learning the deployment process

**Access**:
- Namespace: `microservices-dev`
- Replicas: 1 per service
- Node Pool: dev node group (t3.xlarge)

### QA Environment

**Purpose**: Integration testing and quality assurance

**Characteristics**:
- ⏸️ Requires approval (QA team lead)
- 🕐 2-hour approval timeout
- 📊 2 replicas per service
- 🧪 Includes load generator
- 🔍 Full testing environment

**When to Use**:
- Testing before production
- QA team validation
- Load testing
- Regression testing

**Who Approves**: QA Team group in ServiceNow

**Access**:
- Namespace: `microservices-qa`
- Replicas: 2 per service
- Node Pool: qa node group (t3.2xlarge)

### Production Environment

**Purpose**: Live customer-facing service

**Characteristics**:
- ⏸️⏸️ Requires multi-level approval (DevOps + CAB)
- 🕐🕐 24-hour approval timeout
- 🏭 3-5 replicas per service (HA)
- 🚫 No load generator
- 💪 High availability configuration

**When to Use**:
- Deploying tested changes
- After QA approval
- During maintenance windows
- For customer-facing updates

**Who Approves**:
1. DevOps Team (first level)
2. Change Advisory Board / CAB (second level)

**Access**:
- Namespace: `microservices-prod`
- Replicas: 3-5 per service
- Node Pool: prod node group (m5.4xlarge)

### Environment Comparison Table

| Feature | Dev | QA | Production |
|---------|-----|-----|------------|
| **Approval** | None | Single | Multi-level |
| **Timeout** | 0 | 2 hours | 24 hours |
| **Replicas** | 1 | 2 | 3-5 |
| **Risk Level** | Low (3) | Medium (2) | High (1) |
| **Priority** | Low (3) | Medium (2) | Critical (1) |
| **Load Generator** | ✅ Yes | ✅ Yes | ❌ No |
| **Auto-Close Change** | ✅ Yes | ❌ No | ❌ No |
| **Daily Deployments** | ✅ Multiple | ⚠️ Few | ❌ Rare |

---

## The Approval Process

### How Approvals Work

1. **Workflow Creates Change Request**
   - State: "Pending Approval" (-5)
   - Assigned to approval group

2. **ServiceNow Sends Notification**
   - Email to approval group members
   - Slack notification (if configured)

3. **Approver Reviews Change**
   - Checks implementation plan
   - Reviews impact and risk
   - Verifies test plan
   - Decides: Approve or Reject

4. **Workflow Polls for Decision**
   - Checks every 30 seconds
   - Continues if approved
   - Fails if rejected
   - Times out if no response

5. **Deployment Proceeds**
   - Only after approval
   - Automatically updates change request
   - Notifies on success/failure

### Approval Groups

| Group | Environment | Members | Response Time |
|-------|-------------|---------|---------------|
| QA Team | QA | QA leads | < 2 hours (business hours) |
| DevOps Team | Production (L1) | DevOps engineers | < 8 hours |
| Change Advisory Board (CAB) | Production (L2) | Management, Ops leads | < 24 hours |

### What Approvers Look For

**✅ Approve If**:
- Clear description and impact
- Comprehensive implementation plan
- Tested in lower environment
- Backout plan defined
- No known issues
- Appropriate timing

**❌ Reject If**:
- Vague or incomplete details
- Not tested in QA (for prod)
- High risk without justification
- Bad timing (maintenance window, etc.)
- Known issues or blockers

### Tips for Getting Approved Quickly

1. **Deploy to Dev First**
   - Test thoroughly
   - Fix any issues
   - Document test results

2. **Provide Clear Details**
   - What is changing
   - Why it's changing
   - Impact assessment

3. **Time It Right**
   - Deploy during business hours
   - Avoid Friday afternoons
   - Check team calendars

4. **Communicate**
   - Notify approvers in advance
   - Be available for questions
   - Provide context in Slack

---

## Common Tasks

### Task 1: Deploy Your Feature Branch to Dev

```bash
# 1. Push your changes to GitHub
git add .
git commit -m "feat: Add new feature"
git push origin feature/my-feature

# 2. Go to GitHub Actions
# https://github.com/YOUR-ORG/microservices-demo/actions

# 3. Select workflow: "Deploy with ServiceNow (Hybrid)"

# 4. Run workflow:
#    Branch: feature/my-feature
#    Environment: dev

# 5. Wait ~3 minutes for deployment

# 6. Test your changes:
kubectl get pods -n microservices-dev
kubectl logs -f deployment/frontend -n microservices-dev
```

### Task 2: Check Deployment Status

**Via GitHub**:
```bash
# View recent workflows
gh run list --workflow="deploy-with-servicenow-hybrid.yaml" --limit 10

# View specific run
gh run view 123456789

# Watch live
gh run watch 123456789
```

**Via Kubernetes**:
```bash
# Configure kubectl
aws eks update-kubeconfig --name microservices --region eu-west-2

# Check pods
kubectl get pods -n microservices-dev

# Check specific service
kubectl describe deployment frontend -n microservices-dev

# View logs
kubectl logs -l app=frontend -n microservices-dev --tail=50
```

**Via ServiceNow**:
```
# DevOps Workspace
https://calitiiltddemo3.service-now.com/now/devops-change/home

# Change Request List
https://calitiiltddemo3.service-now.com/change_request_list.do

# Filter by your deployments
Created by: [your ServiceNow user]
```

### Task 3: Rollback a Deployment

**If Deployment Failed Automatically**:
- Workflow already rolled back
- Check logs in GitHub Actions
- Fix issues and redeploy

**Manual Rollback**:
```bash
# 1. Configure kubectl
aws eks update-kubeconfig --name microservices --region eu-west-2

# 2. Rollback specific service
kubectl rollout undo deployment/frontend -n microservices-dev

# 3. Or rollback all services
for deployment in $(kubectl get deployments -n microservices-dev -o name); do
  kubectl rollout undo $deployment -n microservices-dev
done

# 4. Verify rollback
kubectl rollout status deployment/frontend -n microservices-dev

# 5. Update ServiceNow change request
# (Manual process - add work notes explaining rollback)
```

### Task 4: Deploy to QA (After Dev Success)

```bash
# 1. Verify dev deployment successful
gh run list --workflow="deploy-with-servicenow-hybrid.yaml" --branch main --limit 1

# 2. Run workflow for QA
# Go to GitHub Actions → Run workflow
#   Branch: main
#   Environment: qa

# 3. Notify QA team
# Post in #qa-approvals Slack channel:
# "QA deployment ready for approval: CHG0001234
#  GitHub run: [link]
#  ServiceNow: [link]"

# 4. Wait for approval (up to 2 hours)

# 5. Verify deployment after approval
kubectl get pods -n microservices-qa
```

### Task 5: View Application in Browser

**Get Ingress URL**:
```bash
# Dev environment
kubectl get ingress -n microservices-dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# QA environment
kubectl get ingress -n microservices-qa -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Production (if you have access)
kubectl get ingress -n microservices-prod -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

**Test the Application**:
```bash
# Get URL
URL=$(kubectl get ingress -n microservices-dev -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test homepage
curl -s -o /dev/null -w "%{http_code}\n" http://$URL

# Test product page
curl -s http://$URL/products | head -20

# Open in browser
open http://$URL  # macOS
xdg-open http://$URL  # Linux
```

---

## Troubleshooting

### Issue 1: Workflow Failed to Create Change

**Symptoms**:
```
❌ Error: Failed to create change request
Required to provide Auth information
```

**Cause**: ServiceNow credentials issue

**Solution**:
1. Check that secrets are configured: Settings → Secrets → Actions
2. Required secrets:
   - `SERVICENOW_INSTANCE_URL`
   - `SERVICENOW_USERNAME`
   - `SERVICENOW_PASSWORD`
3. Contact team lead if secrets are missing

---

### Issue 2: Approval Timeout

**Symptoms**:
```
❌ Approval timeout reached (7200 seconds)
Workflow failed
```

**Cause**: Approval not granted within timeout period

**Solution**:
1. Check who is assigned in ServiceNow
2. Notify approver in Slack
3. If urgent, ask approver directly
4. For QA: 2-hour timeout during business hours is usually enough
5. For prod: 24-hour timeout, plan accordingly

---

### Issue 3: Pods Not Starting

**Symptoms**:
```
⚠️ frontend rollout timed out
Pods stuck in ImagePullBackOff
```

**Possible Causes**:
1. Image not pushed to ECR
2. Wrong image tag in manifest
3. ECR permissions issue
4. Resource quota exceeded

**Solution**:
```bash
# 1. Check pod status
kubectl get pods -n microservices-dev

# 2. Describe problematic pod
kubectl describe pod <pod-name> -n microservices-dev

# 3. Check events
kubectl get events -n microservices-dev --sort-by='.lastTimestamp'

# 4. Check image exists
aws ecr describe-images --repository-name frontend --region eu-west-2

# 5. Check resource quota
kubectl describe resourcequota -n microservices-dev
```

---

### Issue 4: Can't Access ServiceNow

**Symptoms**:
```
Can't login to ServiceNow
"Access Denied" error
```

**Solution**:
1. Verify you have ServiceNow account
2. Request access from team lead
3. Required roles:
   - `itil` (read changes)
   - `change_manager` (for approvers only)
4. Test access: https://calitiiltddemo3.service-now.com/nav_to.do?uri=change_request_list.do

---

### Issue 5: Deployment Succeeded but Application Not Working

**Symptoms**:
```
✅ All pods running
❌ Application returns 500 errors
```

**Debug Steps**:
```bash
# 1. Check pod logs
kubectl logs -l app=frontend -n microservices-dev --tail=100

# 2. Check all services have endpoints
kubectl get endpoints -n microservices-dev

# 3. Check service-to-service communication
kubectl exec -it deployment/frontend -n microservices-dev -- wget -O- http://productcatalogservice:3550/health

# 4. Check Istio sidecar
kubectl logs -l app=frontend -n microservices-dev -c istio-proxy --tail=50

# 5. View in Grafana
# URL: [Istio Grafana dashboard from team]
```

---

## Best Practices

### ✅ DO

1. **Always Deploy to Dev First**
   - Test your changes
   - Verify application works
   - Check logs for errors

2. **Write Clear Commit Messages**
   ```
   feat: Add product recommendations
   fix: Resolve cart persistence issue
   docs: Update API documentation
   ```

3. **Monitor Your Deployments**
   - Watch GitHub Actions workflow
   - Check ServiceNow change request
   - Verify pods running in Kubernetes

4. **Communicate**
   - Notify team before deploying to qa/prod
   - Update Slack channel
   - Be available during deployment

5. **Document Issues**
   - Add work notes to ServiceNow
   - Create GitHub issues for bugs
   - Share learnings with team

### ❌ DON'T

1. **Don't Deploy Directly to Production**
   - Always go through dev → qa → prod
   - Test thoroughly in each environment

2. **Don't Deploy on Friday Afternoon**
   - If it breaks, you're fixing it over the weekend
   - Plan production deployments for early week

3. **Don't Skip Testing**
   - Run unit tests locally
   - Verify in dev environment
   - Wait for QA approval

4. **Don't Ignore Warnings**
   - Pod restarts frequently? Investigate
   - High error rates? Don't promote to prod
   - Resource limits hit? Adjust configuration

5. **Don't Hardcode Configuration**
   - Use Kustomize overlays for environment-specific config
   - Store secrets in Kubernetes secrets
   - Use environment variables

---

## Getting Help

### Quick Links

**Documentation**:
- [ServiceNow Index](SERVICENOW-INDEX.md) - Complete documentation index
- [Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) - Detailed technical guide
- [Best Practices](GITHUB-SERVICENOW-BEST-PRACTICES.md) - Development best practices
- [Antipatterns](GITHUB-SERVICENOW-ANTIPATTERNS.md) - What NOT to do

**Tools**:
- GitHub Actions: https://github.com/YOUR-ORG/microservices-demo/actions
- ServiceNow: https://calitiiltddemo3.service-now.com
- DevOps Workspace: https://calitiiltddemo3.service-now.com/now/devops-change/home
- AWS Console: https://console.aws.amazon.com/eks

**Runbooks**:
- [Troubleshooting CMDB](workflows/TROUBLESHOOTING-SERVICENOW-CMDB.md)
- [Security Verification](SERVICENOW-SECURITY-VERIFICATION.md)
- [Application Setup](SERVICENOW-APPLICATION-QUICKSTART.md)

### Team Contacts

**For Deployment Issues**:
- #devops-support Slack channel
- DevOps on-call rotation

**For ServiceNow Access**:
- #servicenow-help Slack channel
- Your team lead

**For Approval Questions**:
- QA: #qa-approvals Slack channel
- Production: #change-advisory-board Slack channel

### Common Commands Cheatsheet

```bash
# View recent workflow runs
gh run list --limit 10

# Watch live workflow
gh run watch

# Get kubeconfig
aws eks update-kubeconfig --name microservices --region eu-west-2

# Check pods in all environments
kubectl get pods -n microservices-dev
kubectl get pods -n microservices-qa
kubectl get pods -n microservices-prod

# View logs
kubectl logs -l app=frontend -n microservices-dev --tail=50 -f

# Describe deployment
kubectl describe deployment frontend -n microservices-dev

# Check service endpoints
kubectl get endpoints -n microservices-dev

# Rollback deployment
kubectl rollout undo deployment/frontend -n microservices-dev

# Get ingress URL
kubectl get ingress -n microservices-dev

# Check resource usage
kubectl top pods -n microservices-dev

# View events
kubectl get events -n microservices-dev --sort-by='.lastTimestamp'
```

---

## Next Steps

Now that you've completed onboarding:

### Week 1: Get Comfortable
- [ ] Deploy to dev 3-5 times
- [ ] View changes in ServiceNow
- [ ] Explore DevOps workspace
- [ ] Check Kubernetes pods

### Week 2: Learn the Flow
- [ ] Deploy to QA with approval
- [ ] Practice rollback
- [ ] Read best practices doc
- [ ] Review antipatterns doc

### Week 3: Go Production-Ready
- [ ] Assist with production deployment
- [ ] Learn approval process
- [ ] Understand emergency changes
- [ ] Review team runbooks

### Ongoing
- [ ] Keep up with documentation updates
- [ ] Share knowledge with team
- [ ] Suggest improvements
- [ ] Help onboard new team members

---

**🎉 Welcome to the team! Happy deploying!**

---

**Document Version**: 1.0
**Last Updated**: 2025-10-20
**Questions?**: Ask in #devops-support Slack channel
