# Documentation Hub

> Complete documentation for ServiceNow + GitHub DevOps Integration Demo

## 🚀 Getting Started

This project demonstrates **ServiceNow DevOps Change Management** integrated with **GitHub Actions** for automated, compliant deployments.

### Essential Guides

Follow these 3 guides in order to get the demo running:

1. **[AWS Deployment Guide](1-AWS-DEPLOYMENT-GUIDE.md)** (30-45 minutes)
   - Deploy EKS cluster and infrastructure to AWS
   - Prerequisites: AWS account, Terraform, kubectl
   - Creates the test application environment

2. **[GitHub Setup Guide](2-GITHUB-SETUP-GUIDE.md)** (20-30 minutes)
   - Configure GitHub Actions and workflows
   - Set up AWS and ServiceNow secrets
   - Build and deploy container images

3. **[ServiceNow Integration Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)** (45-60 minutes)
   - Install ServiceNow DevOps plugin
   - Create 13 custom fields on change_request table
   - Configure automated change management
   - Set up approval workflows (dev/qa/prod)

**Total Setup Time**: 2-3 hours

---

## 🎯 Demo Materials

Once setup is complete, use these materials to present the demo:

- **[Demo Script](SERVICENOW-GITHUB-DEMO-GUIDE.md)** - Complete demo walkthrough
  - 5 demo scenarios (10-30 minutes each)
  - Pre-demo checklist
  - Q&A preparation
  - Focus on ServiceNow + GitHub integration

- **[Demo Slides](SERVICENOW-GITHUB-DEMO-SLIDES.md)** - 18-slide presentation
  - Problem statement and solution
  - Custom fields and automation benefits
  - Security and compliance value
  - ROI and business benefits

---

## 📚 Quick Reference

### What This Demo Shows

✅ **Automated Change Management**
- GitHub Actions automatically create ServiceNow Change Requests
- Dev deployments auto-approved
- QA/Prod require manual approval

✅ **Complete Audit Trail**
- 13 custom fields capture GitHub context (repo, branch, commit, actor, environment)
- Work items track GitHub Issues
- Test results uploaded to ServiceNow
- Full compliance evidence

✅ **Multi-Environment Pipeline**
- Dev → QA → Prod promotion workflow
- Environment-specific approval requirements
- Automated rollback on failures

### What This Demo Is NOT About

❌ Kubernetes architecture
❌ AWS infrastructure details
❌ Microservices patterns
❌ Container orchestration

**Key Message**: *"The cluster is just a test application. The value is in the ServiceNow + GitHub integration."*

---

## 🏗️ Architecture Overview

### Infrastructure (Just for Testing)
- **AWS EKS**: Kubernetes cluster (1 node, ultra-minimal)
- **12 Microservices**: Online Boutique demo app
- **3 Environments**: dev, qa, prod namespaces
- **Cost**: ~$134/month (see [COST-OPTIMIZATION.md](../COST-OPTIMIZATION.md))

### Integration (The Important Part!)
- **ServiceNow DevOps Plugin**: Change automation
- **GitHub Actions**: 12 workflows with security scanning
- **Custom Fields**: 13 fields on change_request table
- **Work Items**: GitHub Issues → ServiceNow tracking
- **Test Results**: Automated evidence upload

---

## 🔧 Common Commands

### Infrastructure Management
```bash
just onboard                  # First-time setup (automated)
just tf-apply                 # Deploy AWS infrastructure
just k8s-config               # Configure kubectl
```

### Application Deployment
```bash
# Traditional deployment
just k8s-deploy               # Deploy to cluster

# Kustomize multi-environment
kubectl apply -k kustomize/overlays/dev    # Deploy to dev
kubectl apply -k kustomize/overlays/qa     # Deploy to qa
kubectl apply -k kustomize/overlays/prod   # Deploy to prod
```

### Demo Workflows
```bash
just promote 1.2.3 all        # Automated version promotion
just demo-run dev 1.2.3       # Run demo deployment
```

### Monitoring
```bash
just cluster-status           # Overall cluster health
just k8s-logs frontend        # View service logs
kubectl get pods -n microservices-dev
```

**Full command reference**: Run `just` to see all 50+ commands

---

## 📖 Additional Documentation

### ServiceNow DevOps Action Reference

Official ServiceNow DevOps Change action documentation:

- **[ServiceNow DevOps Action Success Guide](SERVICENOW-DEVOPS-ACTION-SUCCESS.md)** - Working configuration
  - Authentication setup (Basic Auth vs Token)
  - Test results and verification
  - Comparison with REST API integration

- **[ServiceNow DevOps Action Troubleshooting](SERVICENOW-DEVOPS-ACTION-TROUBLESHOOTING.md)** - Complete troubleshooting guide
  - Prerequisites and plugin installation
  - Authentication issues and solutions
  - Demo instance limitations

- **[ServiceNow DevOps Changes Troubleshooting](SERVICENOW-DEVOPS-CHANGES-TROUBLESHOOTING.md)** - UI visibility issues
  - Why changes don't appear in DevOps UI
  - changeControl: false behavior
  - Alternative table locations

- **[Enable changeControl Guide](SERVICENOW-ENABLE-CHANGE-CONTROL.md)** - How to enable traditional CRs
  - ✅ SOLUTION: Remove deployment-gate parameter
  - Source code analysis and explanation
  - Traditional CR vs Deployment Gate comparison

- **[Auto-Approval Setup Guide](SERVICENOW-AUTO-APPROVAL-SETUP.md)** - Configure auto-approval for dev
  - Standard change type configuration
  - Auto-approval rules and templates
  - Hybrid approach (fast dev, compliant qa/prod)
  - Troubleshooting approval issues

- **[Change Request Payload Fix](SERVICENOW-DEVOPS-CHANGE-PAYLOAD-FIX.md)** - Fix "Internal server error" issues
  - Why display names fail (must use sys_id)
  - Invalid/unsupported fields (subcategory, justification)
  - Correct payload structure
  - Testing strategy (minimal payload → incremental)

- **[Test Results Integration](SERVICENOW-TEST-RESULTS-INTEGRATION.md)** - Link unit tests and SonarCloud to approvals ⭐ NEW
  - 13 custom fields for test results and code quality
  - Unit test status, counts, coverage
  - SonarCloud quality gate, bugs, vulnerabilities, code smells
  - Complete implementation guide with API examples
  - Approval decision matrices

- **[What's New: Test Results](WHATS-NEW-TEST-RESULTS.md)** - Quick overview of test integration
  - User-friendly summary of new capability
  - Benefits for approvers and compliance
  - Example approval rules

- **[Fields Verification Report](SERVICENOW-FIELDS-VERIFICATION.md)** - Test results field verification
  - All 13 fields verified working
  - API test results
  - Production readiness confirmation

### Still Available (in _archive)
- Detailed architecture guides
- Development workflows
- Troubleshooting deep-dives
- Historical implementation docs

These have been moved to `docs/_archive/` for reference but are not needed for the demo.

---

## 🆘 Troubleshooting

### Quick Fixes

**AWS Deployment Issues**:
- See [AWS Deployment Guide - Troubleshooting](1-AWS-DEPLOYMENT-GUIDE.md#troubleshooting)

**GitHub Actions Failures**:
- See [GitHub Setup Guide - Troubleshooting](2-GITHUB-SETUP-GUIDE.md#troubleshooting)

**ServiceNow Integration Issues**:
- See [ServiceNow Integration Guide - Troubleshooting](3-SERVICENOW-INTEGRATION-GUIDE.md#troubleshooting)

### Common Issues

**Pods not starting**:
```bash
kubectl get pods -n microservices-dev
kubectl describe pod <pod-name> -n microservices-dev
kubectl logs <pod-name> -n microservices-dev
```

**Terraform errors**:
```bash
just tf-validate              # Validate configuration
just tf-test                  # Run tests
```

**ServiceNow Change Request errors**:
- Check custom fields exist: [Guide Section](3-SERVICENOW-INTEGRATION-GUIDE.md#create-custom-fields)
- Verify orchestration tool ID: [Guide Section](3-SERVICENOW-INTEGRATION-GUIDE.md#configure-orchestration-tool)

---

## 📞 Getting Help

1. **Check the 3 essential guides** above first
2. **Review demo materials** for presentation guidance
3. **Search existing GitHub issues**
4. **Open an issue** with:
   - Problem description
   - Steps to reproduce
   - Error messages and logs
   - Environment details (AWS region, ServiceNow instance, etc.)

---

## 🎓 Learning Path

**New to this project?** Follow this path:

1. Read this README (you are here!)
2. Complete [AWS Deployment Guide](1-AWS-DEPLOYMENT-GUIDE.md)
3. Complete [GitHub Setup Guide](2-GITHUB-SETUP-GUIDE.md)
4. Complete [ServiceNow Integration Guide](3-SERVICENOW-INTEGRATION-GUIDE.md)
5. Review [Demo Script](SERVICENOW-GITHUB-DEMO-GUIDE.md)
6. Practice with [Demo Slides](SERVICENOW-GITHUB-DEMO-SLIDES.md)
7. Run your first demo!

---

## 📄 License

Apache License 2.0 - Based on [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)

---

**Ready to start?** Begin with [AWS Deployment Guide](1-AWS-DEPLOYMENT-GUIDE.md) 🚀
