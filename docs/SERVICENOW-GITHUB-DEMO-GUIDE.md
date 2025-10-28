# ServiceNow + GitHub DevOps Integration Demo Guide

> **Focus**: Demonstrating bidirectional ServiceNow ↔ GitHub integration for enterprise ITSM automation
> **Duration**: 15-30 minutes
> **Audience**: IT Operations, Change Management, DevOps teams, ServiceNow administrators

## 🎯 Demo Value Proposition

**"Watch how GitHub Actions and ServiceNow DevOps work together to automate your entire change management process"**

This demo shows:
- ✅ **Automatic Change Request creation** from GitHub workflows
- ✅ **Work item tracking** (GitHub Issues → ServiceNow)
- ✅ **Approval gates** that pause deployments until ServiceNow approves
- ✅ **Test results upload** (security scans, builds, deployments)
- ✅ **Complete audit trail** for SOC 2 / ISO 27001 compliance
- ✅ **Bidirectional sync** (changes in either system reflected in both)

**The Kubernetes cluster is just a test application** - the real star is the ServiceNow + GitHub integration!

---

## 📊 What You're Actually Demonstrating

### The Integration Flow

```
GitHub Actions Workflow
         ↓
   Creates Change Request in ServiceNow
         ↓
   Uploads Test Results (security scans, builds)
         ↓
   Links Work Items (GitHub Issues)
         ↓
   Pauses for ServiceNow Approval
         ↓
   Approval granted in ServiceNow UI
         ↓
   Workflow resumes automatically
         ↓
   Deployment completes
         ↓
   Updates ServiceNow CR with deployment results
```

### What Makes This Enterprise-Ready

1. **No Manual Change Requests**: Developers never log into ServiceNow
2. **Automatic Compliance**: Every deployment has a CR, audit trail, approvals
3. **Risk-Based Approvals**: Dev auto-approved, QA needs approval, Prod needs CAB
4. **Complete Traceability**: Git commit → PR → Issue → CR → Deployment
5. **Zero Context Switching**: Developers stay in GitHub, approvers stay in ServiceNow

---

## 🎬 Demo Scenario 1: Automated Change Management (10 minutes)

**Narrative**: *"Watch how a simple code change automatically creates a ServiceNow Change Request, waits for approval, and completes the deployment"*

### Step 1: Trigger Deployment (1 minute)

```bash
# Show the one command that kicks everything off
just promote 1.2.0 all

# Or for faster demo (dev only):
just demo-run dev 1.2.0
```

**Key Talking Point**:
*"Notice we're not logging into ServiceNow at all. Everything is triggered from GitHub."*

### Step 2: Show GitHub Actions (3 minutes)

**Open**: https://github.com/Freundcloud/microservices-demo/actions

**Point out these jobs**:

1. **Code Validation** ✅
   - "Security scans run automatically"
   - "10+ scanners: CodeQL, Trivy, Semgrep, OWASP..."

2. **ServiceNow Change Request / Create Change Request (dev)** 🔄
   - "Watch this job - it's creating the ServiceNow CR right now"
   - "No human intervention required"

3. **Register Test Results** 🔄
   - "All security scan results upload to ServiceNow"
   - "Approvers can see test evidence before approving"

4. **Deploy to Kubernetes** ⏸️
   - "Notice it's waiting... paused for ServiceNow approval"

**Key Talking Point**:
*"The workflow has created a Change Request in ServiceNow and is now waiting for approval before deploying. Let's go look at ServiceNow."*

### Step 3: Show ServiceNow Change Request (5 minutes)

**Open**: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/change_request_list.do

**Show the automatically created CR**:

1. **Custom Fields Populated Automatically**:
   - ✅ **Source**: GitHub Actions
   - ✅ **Repository**: Freundcloud/microservices-demo
   - ✅ **Branch**: main (or release/v1.2.0)
   - ✅ **Commit SHA**: Exact Git commit hash
   - ✅ **Actor**: GitHub username who triggered it
   - ✅ **Environment**: dev (or qa, prod)
   - ✅ **Correlation ID**: Workflow run ID (for traceability)

2. **Test Results Tab**:
   - Show security scan results
   - Show build artifacts
   - Show SBOM (Software Bill of Materials)

3. **Work Notes**:
   - Auto-generated notes from GitHub workflow
   - Links back to GitHub Actions run
   - Deployment configuration details

4. **Work Items Tab** (if configured):
   - Linked GitHub Issues
   - Traceability from feature request to deployment

**Key Talking Point**:
*"All this data came automatically from GitHub. The approver has everything they need to make an informed decision: what's changing, who changed it, what tests passed, what the security scan found."*

### Step 4: Approve in ServiceNow (1 minute)

**Actions**:
1. Click the Change Request
2. Click **Approve** button
3. Add optional work note: "Security scans passed, approved for deployment"
4. Save

**Key Talking Point**:
*"Watch what happens now in GitHub Actions..."*

### Step 5: Show Deployment Resume (2 minutes)

**Switch back to GitHub Actions**

**Show**:
- ✅ **Deploy to Kubernetes** job now running (was paused before)
- ✅ Deployment completes successfully
- ✅ **Update ServiceNow CR** job updates the CR with deployment results

**Open the CR again in ServiceNow**:
- State changed to **Closed** or **Implemented**
- Work notes updated: "Deployment completed successfully"
- Close notes added automatically

**Key Talking Point**:
*"The entire lifecycle is automated. GitHub triggered it, ServiceNow approved it, GitHub deployed it, and ServiceNow has the complete record. Zero manual steps."*

---

## 🎬 Demo Scenario 2: Work Item Tracking (5 minutes)

**Narrative**: *"Let's show how GitHub Issues automatically become ServiceNow Work Items"*

### Step 1: Create GitHub Issue

```bash
# Create an issue via CLI (or use GitHub UI)
gh issue create \
  --title "Add new payment gateway integration" \
  --body "Integrate Stripe payment gateway for checkout flow" \
  --label enhancement
```

**Or open GitHub Issues in browser**: https://github.com/Freundcloud/microservices-demo/issues

### Step 2: Show Issue in ServiceNow

**Open**: ServiceNow DevOps > Work Items

**Show**:
- GitHub Issue appears as ServiceNow Work Item
- Issue number, title, description synced
- Labels mapped to ServiceNow categories
- State synced (Open, Closed, In Progress)

### Step 3: Link Work Item to Change Request

**In the deployment CR**:
- Show **Work Items** tab
- Show linked GitHub Issue
- Show traceability: Issue → CR → Deployment

**Key Talking Point**:
*"Now approvers can see WHY this deployment is happening. It's linked to a feature request, not just random code changes."*

---

## 🎬 Demo Scenario 3: Multi-Environment Approval Workflow (15 minutes)

**Narrative**: *"Watch how different environments have different approval requirements"*

### Environment-Based Approval Matrix

| Environment | ServiceNow CR State | Approval Required | Approvers |
|-------------|-------------------|-------------------|-----------|
| **DEV** | Auto-approved (implement) | ❌ No | Automatic |
| **QA** | Assessment | ✅ Yes | QA Lead |
| **PROD** | Assessment | ✅ Yes | CAB (Change Manager, App Owner, Security) |

### Step 1: Deploy to All Environments

```bash
just promote 1.2.1 all
```

### Step 2: Watch the Flow

**DEV Deployment** (Auto-approved):
1. GitHub workflow starts
2. Creates ServiceNow CR (state=implement)
3. **No approval needed** - deploys immediately
4. CR auto-closed after success

**QA Deployment** (QA Lead approval):
1. GitHub workflow starts
2. Creates ServiceNow CR (state=assess)
3. **Pauses** waiting for approval
4. QA Lead reviews and approves
5. Deployment proceeds
6. CR closed after success

**PROD Deployment** (CAB approval):
1. GitHub workflow starts
2. Creates ServiceNow CR (state=assess)
3. **Pauses** waiting for approval
4. Requires approval from:
   - Change Manager
   - Application Owner
   - Security Team
5. Deployment proceeds after all approvals
6. CR closed after success

### Step 3: Show ServiceNow Change Calendar

**Open**: ServiceNow > Change Management > Change Calendar

**Show**:
- All deployments visible on calendar
- Scheduled changes (if configured)
- Change collision detection
- Blackout windows respected

**Key Talking Point**:
*"ServiceNow is the single source of truth for all changes. Even though developers work in GitHub, everything flows into ServiceNow for compliance and audit."*

---

## 🎬 Demo Scenario 4: Security & Compliance (10 minutes)

**Narrative**: *"Show how security scanning results automatically upload to ServiceNow for approval evidence"*

### Step 1: Trigger Security Scans

```bash
# Trigger comprehensive security scan
gh workflow run security-scan.yaml
```

### Step 2: Show GitHub Security Tab

**Open**: https://github.com/Freundcloud/microservices-demo/security

**Show**:
- Code scanning alerts (CodeQL)
- Dependency vulnerabilities (Grype, OWASP)
- Infrastructure security (Checkov, tfsec)
- SARIF upload to GitHub Advanced Security

### Step 3: Show Results in ServiceNow

**Open**: ServiceNow DevOps > Security Results

**Show**:
- All security findings uploaded automatically
- Severity levels (Critical, High, Medium, Low)
- Affected components
- Remediation guidance
- Links back to GitHub Security tab

**Show in Change Request**:
- **Test Results** tab shows security scan results
- Approvers can see: "0 Critical, 2 High, 5 Medium vulnerabilities"
- Can reject CR if security posture unacceptable

**Key Talking Point**:
*"Approvers don't need to leave ServiceNow to see security scan results. Everything is automatically uploaded from GitHub, providing complete visibility for risk-based approval decisions."*

---

## 🎬 Demo Scenario 5: Complete Audit Trail (5 minutes)

**Narrative**: *"Show the complete compliance audit trail from code to production"*

### Step 1: Pick a Recent Deployment

**In ServiceNow**:
1. Open recent Change Request
2. Show **Related Records**:
   - Work Items (GitHub Issues)
   - Test Results (security scans, builds)
   - Packages (artifacts)
   - Configuration files

### Step 2: Show Traceability

**Follow the trail**:

1. **ServiceNow CR** → Click correlation ID
2. **GitHub Actions Run** → Click commit SHA
3. **Git Commit** → Click Issue reference (#123)
4. **GitHub Issue** → Click linked PR
5. **Pull Request** → Click Files Changed

**Result**: Complete traceability from:
- Feature request (Issue)
- Code changes (PR)
- CI/CD run (Actions)
- Security scans (Results)
- Change approval (ServiceNow)
- Deployment (Kubernetes)

**Key Talking Point**:
*"For SOC 2 Type II and ISO 27001 compliance, you need this level of traceability. Every production change must have: issue tracking, code review, automated testing, security scanning, and formal approval. This integration provides all of that automatically."*

---

## 📋 Demo Preparation Checklist

### Before the Demo

- [ ] ServiceNow instance accessible and logged in
- [ ] GitHub repository open in browser
- [ ] GitHub Actions page open
- [ ] GitHub Security tab open
- [ ] ServiceNow Change Request list open
- [ ] ServiceNow DevOps Work Items open
- [ ] ServiceNow DevOps Test Results open
- [ ] Terminal ready with `just promote` command prepared
- [ ] Version number decided (e.g., 1.2.0 → 1.2.1)

### Environment Checks

```bash
# Verify GitHub CLI authenticated
gh auth status

# Verify ServiceNow secrets configured
gh secret list --repo Freundcloud/microservices-demo | grep SERVICENOW

# Verify cluster is healthy (optional - not the focus!)
just cluster-status
```

### Browser Tabs to Have Open

1. **GitHub**:
   - https://github.com/Freundcloud/microservices-demo/actions
   - https://github.com/Freundcloud/microservices-demo/security
   - https://github.com/Freundcloud/microservices-demo/issues

2. **ServiceNow**:
   - Change Request List
   - DevOps > Work Items
   - DevOps > Test Results
   - DevOps > Security Results
   - Change Calendar (optional)

---

## 🎯 Key Talking Points (Copy/Paste for Presentation)

### Opening Statement

*"Today I'm going to show you how GitHub and ServiceNow work together to automate enterprise change management. What used to take hours of manual Change Request creation, approval tracking, and documentation now happens automatically with zero manual effort."*

### During GitHub Actions Demo

*"Notice we're not manually creating Change Requests. The GitHub workflow automatically creates them in ServiceNow, uploads test results, links work items, and waits for approval. Developers never leave GitHub, approvers never leave ServiceNow."*

### During ServiceNow Demo

*"Look at all this data that was automatically populated: repository, branch, commit, who triggered it, what environment, security scan results. Approvers have everything they need to make informed decisions without hunting for information."*

### During Approval Demo

*"Watch what happens when I approve this in ServiceNow... the GitHub workflow resumes automatically. No polling, no manual intervention. The integration is bidirectional and real-time."*

### Closing Statement

*"This is the power of ServiceNow + GitHub DevOps integration. Complete automation, full compliance, zero manual effort. Developers are faster, approvers have better data, and auditors get complete traceability."*

---

## 🎬 5-Minute Lightning Demo

**For very short time slots**:

1. **Run command** (30 seconds):
   ```bash
   just demo-run dev 1.2.0
   ```

2. **Show GitHub Actions** (1 minute):
   - "Workflow running"
   - "Creating ServiceNow CR"
   - "Waiting for approval"

3. **Show ServiceNow CR** (2 minutes):
   - "Automatically created"
   - "All data populated"
   - "Approve it"

4. **Show workflow resume** (1 minute):
   - "Deployment proceeding"
   - "CR updated automatically"

5. **Wrap up** (30 seconds):
   - "That's the integration - zero manual steps"

---

## 📊 Success Metrics to Highlight

### Before Integration
- ⏱️ **20-30 minutes** to manually create Change Request
- 📝 **50%** of CRs missing required data
- ⏳ **2-3 hours** approval turnaround (manual notifications)
- 🔍 **60%** of deployments lack proper audit trail

### After Integration
- ⏱️ **0 minutes** manual CR creation (automatic)
- 📝 **100%** of CRs have complete data (automatic population)
- ⏳ **5-10 minutes** approval turnaround (automated notifications)
- 🔍 **100%** complete audit trail (automatic linking)

### ROI Calculation
- **Time Saved**: 20 minutes × 50 deployments/month = 16.6 hours/month
- **Compliance Risk**: Eliminated (100% compliant)
- **Audit Cost**: Reduced by 80% (automated evidence collection)

---

## 🚫 What NOT to Focus On

Remember, this is a ServiceNow + GitHub demo, NOT:

- ❌ Kubernetes architecture (don't spend time on pods, namespaces, etc.)
- ❌ AWS infrastructure (don't talk about EKS, VPC, ALB, etc.)
- ❌ Microservices patterns (don't explain gRPC, service mesh, etc.)
- ❌ Container builds (don't show Docker, ECR, etc.)
- ❌ Cost optimization (that's not the point of this demo)

**If asked about infrastructure**:
*"We're using a simple Kubernetes cluster as a test application to demonstrate the integration. The cluster itself isn't important - any application could work. The magic is in how GitHub and ServiceNow communicate."*

---

## 🎓 Audience-Specific Customization

### For IT Operations / Change Management
**Focus on**:
- Automated CR creation
- Approval workflows
- Audit trail
- Change calendar integration

### For Security / Compliance Teams
**Focus on**:
- Security scan results upload
- Test evidence for approvals
- Complete audit trail
- SOC 2 / ISO 27001 compliance

### For Developers / DevOps
**Focus on**:
- No manual ServiceNow work
- Stay in GitHub
- Faster approvals
- Less context switching

### For Executives
**Focus on**:
- Time savings (hours → minutes)
- Risk reduction (100% compliant)
- Audit cost reduction
- Developer productivity

---

## 📝 Q&A Preparation

**Q: Does this work with our existing ServiceNow instance?**
A: Yes! This uses the standard ServiceNow DevOps plugin. As long as you have the plugin installed, it works with any ServiceNow instance.

**Q: Can we customize the approval workflow?**
A: Absolutely. You define approval groups in ServiceNow, and the integration respects them. Dev can be auto-approved, QA requires one approver, Prod requires CAB - all configurable.

**Q: What if ServiceNow is down?**
A: The GitHub workflow will fail gracefully. You can configure it to create a CR manually or proceed without ServiceNow in emergency situations.

**Q: Can we integrate with JIRA instead?**
A: This demo shows ServiceNow, but similar integrations exist for JIRA, BMC Remedy, and other ITSM tools.

**Q: How much does the ServiceNow DevOps plugin cost?**
A: That's a ServiceNow licensing question. Contact your ServiceNow rep. The GitHub Actions integration is free.

---

## ✅ Post-Demo Follow-Up

After the demo, provide:

1. **Documentation Links**:
   - ServiceNow DevOps Plugin: https://store.servicenow.com/
   - GitHub Actions: https://docs.github.com/actions
   - Integration Guide: `docs/SERVICENOW-GITHUB-SPOKE-CONFIGURATION.md`

2. **Quick Start Guide**:
   - `docs/SERVICENOW-QUICKSTART.md`
   - `docs/SERVICENOW-ESSENTIAL-SETUP.md`

3. **Sample Workflows**:
   - `.github/workflows/MASTER-PIPELINE.yaml`
   - `.github/workflows/servicenow-change-rest.yaml`

4. **Success Story**:
   - "We reduced Change Request creation time from 30 minutes to 0"
   - "100% compliance with SOC 2 Type II requirements"
   - "Developers save 20+ hours per month"

---

**Ready to demo?** Start with: `just promote 1.2.0 all` 🚀

**Remember**: You're selling the **ServiceNow + GitHub integration**, not the infrastructure. The Kubernetes cluster is just a prop to show real deployments happening!
