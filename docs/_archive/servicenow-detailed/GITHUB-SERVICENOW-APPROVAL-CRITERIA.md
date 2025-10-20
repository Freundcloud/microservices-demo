# ServiceNow Change Approval Criteria Guide

> **Status**: ✅ Implemented
> **Last Updated**: 2025-10-20
> **Version**: 1.0.0

## Overview

This guide defines the information required for change approvers to make informed decisions about deployment approvals in ServiceNow. It establishes clear criteria for what makes a change "ready for approval" vs. "needs more review."

## Current State

**Open Issues**: 2 (as of 2025-10-20)
- Issue #1: "Test1" (no labels)
- Issue #2: "Test2" (no labels)

**Impact**: Neither issue is labeled as `bug`, `security`, or `critical`, so they don't block deployments.

## What Approvers Need to Know

### 🎯 Critical Decision Factors

When reviewing a change request in ServiceNow, approvers should consider:

#### 1. **GitHub Repository Health**
- **Open Issues**: Total count and severity breakdown
- **Open Bugs**: Critical/High priority bugs that might be in production
- **Security Issues**: Open security vulnerabilities or alerts
- **Recent Failures**: Recent workflow failures or test failures

#### 2. **Change Context**
- **What's changing**: Specific services/components being deployed
- **Why it's changing**: Business reason (feature, bug fix, security patch)
- **Who made the change**: Commit author and approver
- **Code review status**: Was PR reviewed and approved?

#### 3. **Risk Indicators**
- **Failed Tests**: Any test failures in current build
- **Security Scan Results**: Critical/High severity findings
- **Deployment History**: Recent deployment failures in this environment
- **Change Scope**: How many services affected

#### 4. **Quality Metrics**
- **Code Coverage**: Test coverage for changed code
- **PR Reviews**: Number of reviewers and their feedback
- **CI/CD Status**: All checks passed?
- **Time in QA**: How long has this been tested?

## Approval Decision Matrix

### ✅ AUTO-APPROVE (Low Risk)

Changes that meet ALL criteria:
- **No open critical/high bugs** in affected services
- **All security scans passed** (no Critical/High findings)
- **All tests passed** in CI/CD
- **Environment**: Dev or QA (not production)
- **PR reviewed** and approved by at least 1 developer
- **Small scope**: Single service or configuration change
- **No recent failures** in target environment

**Example**: Deploying a UI text change to dev environment with clean security scans.

### 🟡 REQUIRES REVIEW (Medium Risk)

Changes that have ANY of these:
- **Open issues** related to affected services
- **Medium severity** security findings
- **Large scope**: Multiple services or infrastructure changes
- **Environment**: Production
- **First deployment** of new service/feature
- **Recent test failures** (but currently passing)
- **No PR review** (direct commits to main)

**Example**: Deploying new payment service to production with 2 medium security findings.

### 🔴 REQUIRES EXTRA SCRUTINY (High Risk)

Changes that have ANY of these:
- **Open critical bugs** in affected services
- **Open security issues** or Critical/High security scan findings
- **Recent deployment failures** in same environment
- **Failed tests** in current build
- **Emergency hotfix** (skipped normal process)
- **Major version upgrade** (e.g., Kubernetes version)
- **Database schema changes** affecting production data

**Example**: Emergency security patch with failed tests and open critical bug.

### ❌ SHOULD BE REJECTED

Changes that have ANY of these:
- **Blocking security vulnerabilities** not addressed
- **No testing** performed
- **Missing required approvals** (e.g., security team for prod)
- **Known breaking changes** without rollback plan
- **Violates change freeze** period (e.g., holidays)
- **Deployment to wrong environment** (e.g., prod instead of dev)

**Example**: Deploying to production with critical security vulnerability and no rollback plan.

## GitHub Issues Impact on Approvals

### When Issues SHOULD Block Approval

**Critical Issues**:
```
Label: bug + critical
Impact: Blocks ALL environments (dev/qa/prod)
Reason: Critical bugs indicate systemic problems
Action: Fix bug before deploying anything new
```

**Security Issues**:
```
Label: security + (high or critical)
Impact: Blocks production, warns for qa/dev
Reason: Security vulnerabilities expose data/systems
Action: Fix security issue or implement mitigation
```

**Open PRs Affecting Same Service**:
```
Condition: PR open for same service being deployed
Impact: Warns approver of potential conflicts
Reason: Incomplete work might conflict
Action: Review if PR should be merged first
```

### When Issues DON'T Block Approval

**Enhancement Requests**:
```
Label: enhancement or feature-request
Impact: No blocking
Reason: Future work, doesn't affect current deployment
```

**Documentation Issues**:
```
Label: documentation
Impact: No blocking
Reason: Docs don't affect system functionality
```

**Backlog Items**:
```
Label: backlog or help-wanted
Impact: No blocking
Reason: Low priority work
```

## Information Added to ServiceNow Change Requests

### Current Implementation

**GitHub Integration Metadata** (work note):
- Repository, branch, commit, author
- Workflow run URL and trigger
- PR information (if applicable)
- Deployment details (environment, namespace)
- Correlation ID for tracking

**Security Scan Evidence** (work note):
- Overall compliance status
- Findings by severity (Critical, High, Medium, Low)
- Scan tool results (Trivy, Gitleaks, CodeQL, etc.)
- Links to detailed reports

### Proposed Enhancements

**GitHub Issues Intelligence** (new work note):
- **Total open issues**: Overall repository health
- **Open bugs**: Bugs that might affect deployment
- **Open security issues**: Security vulnerabilities
- **Issues by service**: Breakdown by affected microservice
- **Issue trends**: Recently opened vs. recently closed
- **Blocking issues**: Issues that should prevent approval

**Risk Assessment** (new work note):
- **Risk Level**: Auto-calculated (Low/Medium/High)
- **Risk Factors**: What contributes to risk score
- **Recommendation**: Approve / Review Required / Reject
- **Blocking Conditions**: Why change is blocked (if any)

**Quality Metrics** (new work note):
- **Test Coverage**: Overall and for changed files
- **Code Review Status**: PR approval status
- **Deployment History**: Recent success/failure rate
- **Time in Environment**: How long tested in lower envs

## Enhanced Work Note Example

```
GitHub Issues & Risk Assessment

RISK LEVEL: MEDIUM
Recommendation: REQUIRES REVIEW

Open Issues Summary:
- Total Open: 2
- Open Bugs: 0
- Security Issues: 0
- Affecting This Deployment: 0

Issue Breakdown by Label:
- enhancement: 0
- bug: 0
- security: 0
- documentation: 0
- question: 2

Recent Issues (Last 30 Days):
- Opened: 2
- Closed: 0
- Resolution Rate: 0%

Issues Affecting Deployment Services:
- frontend: 0 issues
- cartservice: 0 issues
- checkoutservice: 0 issues

Blocking Conditions:
✅ No critical bugs
✅ No security issues
✅ All security scans passed
✅ All tests passed
⚠️  Large change scope (3 services)
⚠️  Production environment

Risk Factors:
1. Deployment to production environment (+2 risk)
2. Multiple services affected (+1 risk)
3. No blocking issues detected (-0 risk)
4. Clean security scans (-1 risk)
5. All tests passed (-1 risk)

Total Risk Score: 1/10 (MEDIUM)

Approval Recommendation:
This change requires standard review before approval.
- Review scope of changes across 3 services
- Verify rollback plan is documented
- Confirm testing completed in qa environment

Links:
- Open Issues: https://github.com/olafkfreund/microservices-demo/issues?q=is:open
- Security Alerts: https://github.com/olafkfreund/microservices-demo/security
- Recent Deployments: https://github.com/olafkfreund/microservices-demo/actions
```

## Implementation Recommendations

### Phase 1: GitHub Issues Data Collection

**What to Collect**:
```bash
# Get all open issues with metadata
gh issue list --state open --json number,title,labels,createdAt,author,url

# Get open bugs specifically
gh issue list --state open --label bug --json number,title,labels,url

# Get security issues
gh issue list --state open --label security --json number,title,labels,url

# Get issue trends (last 30 days)
gh issue list --state all --search "created:>=$(date -d '30 days ago' +%Y-%m-%d)" \
  --json number,state,createdAt,closedAt
```

**What to Include in Change Request**:
1. **Total counts**: Open issues, open bugs, security issues
2. **Service breakdown**: Issues tagged for specific services
3. **Severity**: Critical/high/medium/low breakdown
4. **Trends**: Recently opened vs. closed
5. **Links**: Direct links to filtered issue lists

### Phase 2: Risk Assessment Algorithm

**Risk Scoring** (0-10 scale):

```javascript
function calculateRiskScore(change) {
  let risk = 0;

  // Environment risk
  if (change.environment === 'prod') risk += 2;
  else if (change.environment === 'qa') risk += 1;

  // Open issues risk
  if (change.openBugs.critical > 0) risk += 5;
  if (change.openBugs.high > 0) risk += 3;
  if (change.openBugs.medium > 0) risk += 1;

  // Security issues risk
  if (change.securityIssues.critical > 0) risk += 5;
  if (change.securityIssues.high > 0) risk += 3;

  // Security scan risk
  if (change.scanFindings.critical > 0) risk += 4;
  if (change.scanFindings.high > 0) risk += 2;

  // Scope risk
  if (change.affectedServices > 5) risk += 2;
  else if (change.affectedServices > 2) risk += 1;

  // Test status risk
  if (change.testsFailed) risk += 3;

  // Positive factors (reduce risk)
  if (change.allTestsPassed) risk -= 1;
  if (change.prReviewed) risk -= 1;
  if (change.recentSuccessRate > 90) risk -= 1;

  return Math.max(0, Math.min(10, risk));
}

function getRiskLevel(score) {
  if (score <= 2) return 'LOW';
  if (score <= 5) return 'MEDIUM';
  return 'HIGH';
}

function getRecommendation(score, blockingIssues) {
  if (blockingIssues.length > 0) return 'REJECT';
  if (score <= 2) return 'APPROVE';
  if (score <= 5) return 'REQUIRES REVIEW';
  return 'REQUIRES EXTRA SCRUTINY';
}
```

### Phase 3: Automated Approval Rules

**ServiceNow Business Rules**:

```javascript
// Auto-approve low risk dev changes
if (change.environment === 'dev' &&
    change.riskScore <= 2 &&
    change.blockingIssues.length === 0) {
  change.approval_status = 'approved';
  change.approved_by = 'Automated (Low Risk)';
}

// Require manual review for medium risk
if (change.riskScore > 2 && change.riskScore <= 5) {
  // Route to standard approver
  createApprovalRequest(change, 'dev-lead');
}

// Require CAB review for high risk
if (change.riskScore > 5 || change.environment === 'prod') {
  // Route to Change Advisory Board
  createApprovalRequest(change, 'cab-board');
}

// Reject if blocking issues exist
if (change.blockingIssues.length > 0) {
  change.approval_status = 'rejected';
  change.rejection_reason = change.blockingIssues.join(', ');
}
```

## Approval Workflow Best Practices

### For Developers

**Before Triggering Deployment**:
1. ✅ Check open issues related to your service
2. ✅ Close or address critical/high bugs
3. ✅ Ensure security scans are clean
4. ✅ Verify all tests pass
5. ✅ Get PR review before merging
6. ✅ Test in dev before deploying to qa/prod

**In Commit Messages**:
- Reference issue numbers: `Fixes #123` or `Relates to #456`
- Explain what changed and why
- Include testing performed
- Note any risks or rollback considerations

### For Approvers

**Review Checklist**:
- [ ] Check risk level and score
- [ ] Review open issues (especially bugs/security)
- [ ] Verify security scans passed
- [ ] Check deployment history/success rate
- [ ] Confirm testing in lower environments
- [ ] Review change scope and affected services
- [ ] Verify rollback plan exists
- [ ] Check for change freeze periods
- [ ] Confirm proper approvals obtained

**Rejection Reasons**:
- Critical security findings not addressed
- Open critical bugs in affected services
- Failed tests or security scans
- Insufficient testing in lower environments
- Missing required approvals
- Change freeze period active
- Inadequate rollback plan

### For Administrators

**Monitoring**:
- Track approval times by environment
- Monitor auto-approval accuracy
- Review rejection reasons
- Analyze risk score correlation with failures
- Adjust risk scoring weights based on data

**Metrics to Track**:
1. **Mean Time to Approval** (MTTA)
2. **Approval Rate** by risk level
3. **Change Failure Rate** by risk level
4. **False Positive Rate** (approved but failed)
5. **False Negative Rate** (rejected but would succeed)

## Compliance and Audit

### Audit Trail Requirements

Every change request should capture:
1. **What changed**: Code diff, commit SHA
2. **Who changed it**: Author, committer, approvers
3. **Why it changed**: Commit message, linked issues
4. **When it changed**: Timestamps for each stage
5. **Risk assessment**: Calculated risk and factors
6. **Approval decision**: Who approved/rejected and why
7. **Deployment result**: Success/failure with evidence

### Regulatory Compliance

**SOC 2 Requirements**:
- ✅ Change approval process documented
- ✅ Separation of duties (author ≠ approver)
- ✅ Audit trail of all changes
- ✅ Security testing before deployment
- ✅ Rollback procedures documented

**ISO 27001 Requirements**:
- ✅ Risk assessment for changes
- ✅ Security impact analysis
- ✅ Approval workflow enforced
- ✅ Change records maintained
- ✅ Post-implementation review

## Example Scenarios

### Scenario 1: Simple Dev Deployment

**Context**:
- Environment: dev
- Scope: Frontend UI text change
- Open Issues: 2 (neither related)
- Security Scans: All passed
- Tests: All passed

**Risk Assessment**:
- Risk Score: 0/10 (LOW)
- Recommendation: AUTO-APPROVE
- Blocking Issues: None

**Outcome**: Automatically approved and deployed

### Scenario 2: Production Feature Release

**Context**:
- Environment: prod
- Scope: New payment processing feature (3 services)
- Open Issues: 5 (1 medium bug in unrelated service)
- Security Scans: 1 Medium finding (accepted risk)
- Tests: All passed
- PR: Reviewed by 2 developers

**Risk Assessment**:
- Risk Score: 3/10 (MEDIUM)
- Recommendation: REQUIRES REVIEW
- Risk Factors: Production environment, multiple services

**Outcome**: Routed to dev lead for approval, approved after review

### Scenario 3: Emergency Security Hotfix

**Context**:
- Environment: prod
- Scope: Security patch for auth service
- Open Issues: 1 (critical security issue being fixed)
- Security Scans: 1 Critical (the issue being fixed)
- Tests: All passed
- PR: Fast-tracked review

**Risk Assessment**:
- Risk Score: 7/10 (HIGH)
- Recommendation: REQUIRES EXTRA SCRUTINY
- Risk Factors: Critical security issue, production, emergency

**Outcome**: Routed to CAB for expedited review, approved with conditions

### Scenario 4: Failed Deployment Retry

**Context**:
- Environment: qa
- Scope: Infrastructure upgrade (5 services)
- Open Issues: 2 high bugs in services being deployed
- Security Scans: Passed
- Tests: 2 integration tests failing
- Recent Deployment: Failed 2 hours ago

**Risk Assessment**:
- Risk Score: 8/10 (HIGH)
- Recommendation: REJECT
- Blocking Issues: High priority bugs, failing tests

**Outcome**: Rejected, requires bug fixes and test fixes before retry

## Related Documentation

- **[Work Item Association Guide](GITHUB-SERVICENOW-WORK-ITEM-ASSOCIATION.md)** - GitHub-ServiceNow linking
- **[Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)** - Complete integration setup
- **[Antipatterns](GITHUB-SERVICENOW-ANTIPATTERNS.md)** - Common mistakes to avoid
- **[Best Practices](GITHUB-SERVICENOW-BEST-PRACTICES.md)** - Recommended patterns

## Next Steps

1. **Implement GitHub Issues Collection**: Add issues data to change requests
2. **Build Risk Assessment**: Calculate risk scores automatically
3. **Create Approval Rules**: Auto-approve low risk, escalate high risk
4. **Monitor and Tune**: Track accuracy and adjust risk weights
5. **Document Decisions**: Capture approval rationale for audits

---

**Questions?** See [GITHUB-SERVICENOW-INTEGRATION-GUIDE.md](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) for complete integration documentation.
