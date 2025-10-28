# SOC 2 Type II / ISO 27001 Compliant Deployment Workflow

**Enterprise-Grade Secure SDLC Demonstration for Financial Services**

## Overview

This demonstration showcases a complete, compliance-ready deployment workflow designed for senior engineers in regulated industries (financial services, healthcare, government). It demonstrates real-world implementation of SOC 2 Type II and ISO 27001:2022 controls through an automated, auditable CI/CD pipeline.

## Target Audience

- **Chief Information Security Officers (CISOs)**
- **Security Architects & Engineers**
- **DevSecOps Team Leads**
- **Compliance Officers**
- **Enterprise Architects in Financial Services**

## Compliance Standards

### SOC 2 Type II Controls

| Control | Description | Implementation |
|---------|-------------|----------------|
| **CC6.1** | Logical and Physical Access Controls | IAM roles, GitHub branch protection, ServiceNow access controls |
| **CC6.6** | Security Incident Management | Automated security scanning, vulnerability detection, incident response |
| **CC7.2** | System Monitoring | CloudWatch logs, Istio observability, application metrics |
| **CC8.1** | Change Management | Documented change process, peer review, automated testing, ServiceNow integration |

### ISO 27001:2022 Controls

| Control | Description | Implementation |
|---------|-------------|----------------|
| **A.8.9** | Configuration Management | Infrastructure as Code (Terraform), version control, configuration baselines |
| **A.12.1.2** | Change Management | Formal change control, risk assessment, approval workflow, rollback procedures |
| **A.14.2.2** | System Change Control | Test environment validation, security testing, quality gates, documentation |

### Additional Frameworks

- **NIST Cybersecurity Framework**: ID.RA-1 (Risk Assessment)
- **CIS Controls**: Critical Security Controls implementation
- **PCI DSS** considerations for payment processing environments

## Quick Start

###  Run the Demonstration

```bash
# Execute the interactive demonstration
just demo-soc-compliance
```

The script will guide you through:
1. **Planning & Risk Assessment** - Identify change type and assess impact
2. **Secure Implementation** - Create feature branch and implement changes
3. **Work Item Management** - ServiceNow work item creation
4. **Peer Review Process** - Pull request and security validation
5. **Merge & Deploy** - Automated CI/CD pipeline execution
6. **Change Management** - ServiceNow change request lifecycle
7. **Deployment & Validation** - Monitoring and evidence collection
8. **Change Closure** - Audit trail completion
9. **Compliance Reporting** - Control verification summary

## Workflow Phases

### Phase 1: Planning & Risk Assessment (ISO 27001 A.14.2.1)

**Control Objective**: Establish change scope and risk before implementation

**Activities**:
- Identify change type (code change vs. version bump)
- Assess impact level (Low/Medium/High)
- Verify compliance requirements
- Document risk assessment

**Evidence Generated**:
- Risk assessment documentation
- Change classification
- Compliance checklist

### Phase 2: Secure Implementation (Secure SDLC)

**Control Objective**: Implement changes following secure development practices

**Activities**:
- Create isolated feature branch
- Implement changes with security checks
- Pre-commit validation (secret scanning, linting)
- Code commit with audit metadata

**Evidence Generated**:
- Git commit history
- Pre-commit scan results
- Code review artifacts

### Phase 3: ServiceNow Work Item Creation (ITSM Integration)

**Control Objective**: Track work through formal ITSM processes

**Activities**:
- Create ServiceNow work item
- Link to change request
- Assign to appropriate team
- Set priority and classification

**Evidence Generated**:
- Work item record
- Assignment history
- State transitions

### Phase 4: Pull Request & Peer Review (Separation of Duties)

**Control Objective**: Enforce dual control through peer review (SOC 2 CC6.1)

**Activities**:
- Create pull request with detailed description
- Trigger automated quality gates:
  - Security scanning (CodeQL, Semgrep, Trivy)
  - SAST/DAST analysis
  - Dependency vulnerability scanning
  - IaC security (Checkov, tfsec)
  - Container image scanning
  - Unit & integration tests
- Required peer review approval
- All CI/CD checks must pass

**Evidence Generated**:
- Pull request record
- Code review comments
- CI/CD pipeline logs
- Security scan results

### Phase 5: Merge & Trigger Deployment

**Control Objective**: Execute approved changes through automated pipeline

**Activities**:
- Merge approved pull request
- Automatic deployment pipeline trigger
- Track workflow execution
- Monitor progress

**Evidence Generated**:
- Merge commit
- Workflow run ID
- Pipeline execution logs

### Phase 6: ServiceNow Change Request Creation (Change Management)

**Control Objective**: Formal change management per ISO 27001 A.12.1.2

**Activities**:
- Create ServiceNow change request via REST API
- Populate change details:
  - Short description
  - Implementation plan
  - Backout plan
  - Test plan
  - Risk and impact assessment
- Link to GitHub workflow
- Correlation ID for traceability

**Change Request Fields**:
```json
{
  "category": "DevOps",
  "devops_change": true,
  "type": "normal",
  "risk": "Low|Medium|High",
  "impact": "Low|Medium|High",
  "implementation_plan": "Step-by-step deployment",
  "backout_plan": "Rollback procedures",
  "test_plan": "Validation steps",
  "correlation_id": "github-<workflow-id>"
}
```

**Evidence Generated**:
- Change request number (CHG#######)
- Approval audit trail
- Risk assessment documentation

### Phase 7: Deployment Execution & Monitoring

**Control Objective**: Execute deployment with comprehensive monitoring

**Activities**:
- Monitor CI/CD pipeline progress
- Collect deployment evidence:
  - Security scan results archived
  - Test execution reports
  - Deployment logs
  - Infrastructure state
  - Container SBOMs
- Post-deployment validation:
  - Health endpoint checks
  - Pod status verification
  - Service mesh connectivity
  - Database connections
  - Performance metrics

**Evidence Generated**:
- Deployment logs
- Test results
- Security artifacts
- Infrastructure evidence
- Health check reports

### Phase 8: ServiceNow Change Closure & Audit Trail

**Control Objective**: Complete change lifecycle with full audit trail

**Activities**:
- Update change request status
- Add deployment evidence to ServiceNow
- Document success/failure
- Close work item
- Generate audit trail summary

**Evidence Collection**:
- Git commit history
- Pull request discussion
- CI/CD workflow logs
- Security scan results
- ServiceNow change record
- Deployment evidence
- Post-deployment validation

### Phase 9: Compliance Reporting

**Control Objective**: Demonstrate compliance with all applicable standards

**Activities**:
- Verify SOC 2 Type II controls
- Verify ISO 27001:2022 controls
- Generate evidence package
- Document control effectiveness

**Reports Generated**:
- SOC 2 control verification
- ISO 27001 control verification
- Audit evidence package location
- Compliance summary

## Key Features

### 1. Complete Audit Trail

Every action is logged and traceable:

- **Git**: Commit history with detailed messages
- **GitHub**: Pull requests, code reviews, CI/CD logs
- **ServiceNow**: Change requests, work items, approvals
- **AWS**: CloudWatch logs, CloudTrail events
- **Kubernetes**: Pod logs, event history
- **Istio**: Service mesh telemetry

### 2. Security at Every Stage

Security validation throughout the SDLC:

- **Pre-commit**: Secret scanning (Gitleaks), linting
- **Pull Request**: SAST (CodeQL, Semgrep), dependency scanning
- **Build**: Container scanning (Trivy), IaC scanning (Checkov, tfsec)
- **Deploy**: Runtime security, network policies
- **Monitor**: Continuous security monitoring

### 3. Separation of Duties

Enforcement of dual control:

- **Developer**: Implements changes, creates PR
- **Reviewer**: Approves code changes (cannot self-approve)
- **Approver**: Approves ServiceNow change request
- **System**: Automated deployment execution
- **Auditor**: Reviews audit trail post-deployment

### 4. Automated Compliance Evidence

Automatic collection and retention of evidence:

- **Security Scans**: Archived in GitHub Actions artifacts
- **Test Results**: JUnit XML reports, coverage reports
- **Deployment Logs**: CloudWatch Logs retention
- **Infrastructure State**: Terraform state with history
- **Container Images**: SBOM generation, vulnerability reports
- **Change Records**: ServiceNow permanent record

### 5. Rollback Capabilities

Documented and tested rollback procedures:

- **Git**: Revert to previous commit
- **Kubernetes**: Rollback deployment
- **Terraform**: Revert infrastructure changes
- **ServiceNow**: Update change request with rollback status
- **Documentation**: Rollback procedures in change request

## Prerequisites

### Required Tools

- **git**: Version control
- **gh** (GitHub CLI): GitHub automation
- **jq**: JSON processing
- **curl**: API interactions
- **kubectl** (optional): Kubernetes verification

### Required Credentials

```bash
# ServiceNow credentials (in .envrc or environment)
export SERVICENOW_USERNAME="your-username"
export SERVICENOW_PASSWORD="your-password"
export SERVICENOW_INSTANCE="https://your-instance.service-now.com"
export SN_ORCHESTRATION_TOOL_ID="your-tool-id"

# GitHub CLI must be authenticated
gh auth login
```

### Repository Permissions

- **GitHub**: Write access to repository
- **ServiceNow**: Change management permissions
- **AWS** (for actual deployment): EKS access

## Demonstration Scenarios

### Scenario 1: Code Change (Feature/Bug Fix)

**Use Case**: Deploy a new feature or bug fix

**Workflow**:
1. Select "Code change" option
2. Enter change description (e.g., "Add user authentication")
3. Assess impact level (Low/Medium/High)
4. Implement code changes
5. Follow automated workflow through deployment

**Duration**: 15-20 minutes (interactive)

**Evidence**:
- Feature branch
- Pull request with security scans
- ServiceNow change request
- Deployment logs
- Compliance report

### Scenario 2: Version Bump (Release)

**Use Case**: Promote tested code to new production version

**Workflow**:
1. Select "Version bump" option
2. Enter new version (e.g., v1.2.0)
3. Assess impact level (typically Medium/High)
4. Automated ECR image tagging
5. Release deployment workflow

**Duration**: 10-15 minutes (automated)

**Evidence**:
- Version tags in ECR
- Release branch
- Change request with version info
- Deployment evidence
- Compliance report

## Integration Architecture

```
┌─────────────────┐
│   Developer     │
│   Workstation   │
└────────┬────────┘
         │
         │ git push
         ▼
┌─────────────────┐
│     GitHub      │
│  - Code Review  │
│  - CI/CD        │
│  - Artifacts    │
└────────┬────────┘
         │
         │ Webhook
         ▼
┌─────────────────┐         ┌─────────────────┐
│   ServiceNow    │◄────────┤   Automation    │
│  - Changes      │         │   Script        │
│  - Work Items   │         └─────────────────┘
│  - Approvals    │
└────────┬────────┘
         │
         │ Approved
         ▼
┌─────────────────┐
│   AWS EKS       │
│  - Deployment   │
│  - Monitoring   │
│  - Evidence     │
└─────────────────┘
```

## Evidence Package Contents

After successful demonstration, the following evidence is available:

### GitHub Evidence

**Location**: `https://github.com/<repo>/actions/runs/<workflow-id>`

- Workflow execution logs
- Security scan results (SARIF files)
- Test reports (JUnit XML)
- Container SBOMs
- Build artifacts

### ServiceNow Evidence

**Location**: `<instance>/change_request.do?sys_id=<change-sys-id>`

- Change request record
- Approval history
- Implementation notes
- Deployment evidence
- Work notes

### AWS Evidence

**Location**: CloudWatch Logs

- Application logs
- Deployment events
- Infrastructure changes
- Service mesh telemetry

## Presentation Tips

### For CISOs/Security Leaders

**Focus on**:
- Complete audit trail
- Security controls at every stage
- Compliance mapping (SOC 2, ISO 27001)
- Automated evidence collection
- Separation of duties

**Key Messages**:
- "Zero manual steps reduce human error"
- "Every action is logged and traceable"
- "Automated compliance evidence reduces audit burden"
- "Security is built into the pipeline, not bolted on"

### For DevOps/Engineering Teams

**Focus on**:
- Automated workflow
- Developer experience
- Zero-downtime deployments
- Rollback procedures
- Integration with existing tools

**Key Messages**:
- "Compliance doesn't slow down deployment"
- "Security scans happen automatically"
- "ServiceNow integration is seamless"
- "Complete visibility into deployment status"

### For Compliance/Audit Teams

**Focus on**:
- Evidence retention
- Control effectiveness
- Audit trail completeness
- Risk assessment process
- Change approval workflow

**Key Messages**:
- "Complete evidence package for every change"
- "Automated control verification"
- "Permanent record in ServiceNow"
- "Risk-based approval workflows"

## Common Questions & Answers

### Q: How long does a typical deployment take?

**A**: 10-15 minutes for automated deployments, longer if manual approval is required. The demo simulates approvals for time efficiency.

### Q: Can this integrate with our existing ServiceNow instance?

**A**: Yes. The script uses standard ServiceNow REST API calls. Configuration requires:
- ServiceNow credentials
- Tool ID registration
- Custom field mapping (if needed)

### Q: What happens if a deployment fails?

**A**:
- Pipeline stops at failure point
- Change request updated with failure status
- Rollback procedures documented in change request
- Notifications sent to relevant teams
- Root cause analysis required before retry

### Q: How is separation of duties enforced?

**A**:
- Developers cannot merge their own PRs (GitHub branch protection)
- Reviewers must be different from submitter
- ServiceNow approvers cannot be requesters
- Automated systems execute approved changes

### Q: What about secrets management?

**A**:
- Secrets stored in GitHub Secrets (encrypted)
- ServiceNow credentials not hardcoded
- Pre-commit hooks scan for leaked secrets (Gitleaks)
- AWS IAM roles for service authentication (IRSA)

### Q: Can we customize the workflow for our organization?

**A**: Yes. The script is modular and can be customized:
- Risk levels and approval thresholds
- ServiceNow field mappings
- Security scan tools
- Notification channels
- Evidence collection

### Q: How do we prove compliance during audits?

**A**: Provide auditors with:
- Evidence package URLs (GitHub + ServiceNow)
- Compliance mapping documentation
- Control effectiveness reports
- Audit trail exports
- Security scan results

## Troubleshooting

### Issue: ServiceNow API authentication fails

**Solution**:
```bash
# Verify credentials
echo $SERVICENOW_USERNAME
echo $SERVICENOW_PASSWORD

# Test API connection
curl -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE/api/now/table/sys_user?sysparm_limit=1"
```

### Issue: GitHub CLI not authenticated

**Solution**:
```bash
gh auth login
gh auth status
```

### Issue: Change request creation fails

**Solution**:
- Verify ServiceNow credentials
- Check tool ID configuration
- Ensure user has change management permissions
- Verify custom fields exist in ServiceNow

## Advanced Topics

### Custom Security Scan Integration

Add your own security scanning tools to the CI/CD pipeline:

```yaml
# .github/workflows/security-scan.yaml
- name: Custom Security Scan
  run: |
    your-scanner scan .
    your-scanner report --format sarif > results.sarif
```

### Custom ServiceNow Fields

Map additional fields in the change request:

```bash
# In scripts/demo-soc-iso27001-workflow.sh
change_payload=$(cat <<EOF
{
  "category": "DevOps",
  "u_custom_field_1": "$VALUE1",
  "u_custom_field_2": "$VALUE2"
}
EOF
)
```

### Multi-Environment Approval Workflows

Configure different approval requirements per environment:

- **Dev**: Auto-approved (demo/testing)
- **QA**: Team lead approval
- **Prod**: CAB approval + security review

## References

### SOC 2 Resources

- [AICPA SOC 2 Guide](https://www.aicpa.org/soc-for-service-organizations)
- [Common Criteria (CC) Controls](https://www.aicpa.org/resources/landing/trust-services-criteria)

### ISO 27001 Resources

- [ISO 27001:2022 Standard](https://www.iso.org/standard/82875.html)
- [Annex A Controls](https://www.isms.online/iso-27001/annex-a/)

### NIST Resources

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [NIST SP 800-53](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)

### ServiceNow Resources

- [DevOps Change Management](https://docs.servicenow.com/bundle/vancouver-devops/page/product/devops-change/concept/devops-change.html)
- [REST API Documentation](https://docs.servicenow.com/bundle/vancouver-api-reference/page/integrate/inbound-rest/concept/c_RESTAPI.html)

## Support & Feedback

For questions or issues with this demonstration:

1. **Documentation**: Check [docs/README.md](README.md) for comprehensive guides
2. **GitHub Issues**: Report bugs or request features
3. **Community**: Join discussions in GitHub Discussions

## License

Copyright 2024 - Licensed under Apache License 2.0

---

**Last Updated**: 2025-10-22
**Version**: 1.0.0
**Maintainer**: DevOps Team
