# ServiceNow Integration - Complete Documentation Index

**Last Updated**: 2025-10-16
**Plugin Version**: DevOps Change Velocity 6.1.0 (sn_devops_chgvlcty)
**Instance**: https://calitiiltddemo3.service-now.com

---

## 🚀 Quick Start (Start Here!)

**New to ServiceNow integration?** Follow this path:

1. **[Quick Start Guide](SERVICENOW-QUICK-START.md)** (5 minutes)
   - Prerequisites check
   - First-time setup
   - Verify everything works

2. **[DevOps Change Workspace Access](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md)** ⭐ (15 minutes)
   - Access the modern workspace
   - Connect GitHub Actions
   - View DORA metrics

3. **[Navigation URLs](SERVICENOW-NAVIGATION-URLS.md)** 🔖 (Bookmark this!)
   - All ServiceNow URLs
   - Quick reference table
   - How to find everything

---

## 📋 Documentation by Topic

### 🎯 Core Setup

#### Application Setup
- **[Application Quick Start](SERVICENOW-APPLICATION-QUICKSTART.md)** ⭐ **10 minutes**
  - Create "Online Boutique" application
  - Configure GitHub secret
  - Map service dependencies
  - Complete verification

- **[Application Setup Complete Guide](SERVICENOW-APPLICATION-SETUP.md)** (Reference)
  - Business Application creation
  - CMDB relationship mapping
  - Health monitoring
  - Impact analysis

- **[Application Category Fix](SERVICENOW-APPLICATION-CREATION-FIX.md)** (Troubleshooting)
  - Fix "Application Category is empty" error
  - Required field explanation
  - Automated creation script

#### Change Management & Approvals

- **[DevOps API Prerequisites](SERVICENOW-DEVOPS-API-PREREQUISITES.md)** ⚠️ **READ FIRST!**
  - **Root cause**: IntegrationHub plugins may be missing
  - Required plugins for DevOps Change API
  - How to verify plugin installation
  - Why API fails with "Internal server error"
  - Workaround: Use hybrid workflow

- **[DevOps Change API Integration](SERVICENOW-DEVOPS-CHANGE-API-INTEGRATION.md)** ⭐ **NEW!**
  - Official ServiceNow DevOps Change GitHub Actions
  - Token-based authentication (OAuth)
  - Workspace integration (requires IntegrationHub!)
  - DORA metrics enabled
  - Real-time pipeline tracking
  - Step-by-step setup guide

- **[Approval Workflow Guide](SERVICENOW-APPROVALS.md)** (Comprehensive)
  - Multi-level approval configuration
  - Dev/QA/Prod policies
  - Approval groups setup
  - Email notifications
  - Best practices

- **[Approval Quick Start](SERVICENOW-APPROVALS-QUICKSTART.md)** ⭐ **15 minutes**
  - Automated group creation
  - Testing for each environment
  - Verification checklist

#### DevOps Change Workspace
- **[Workspace Access Guide](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md)** ⭐ **PRIMARY**
  - Direct workspace URL
  - Initial setup wizard
  - GitHub Actions connection
  - DORA metrics access
  - Troubleshooting

- **[DevOps Change Velocity Overview](SERVICENOW-DEVOPS-CHANGE-VELOCITY.md)** (Reference)
  - Plugin features and capabilities
  - vs. Standard Change Management
  - What's included in v6.1.0

---

### 🔒 Security Integration

- **[Security Scanning Design](SERVICENOW-SECURITY-SCANNING.md)** (Architecture)
  - 8-tool security integration
  - SARIF aggregation
  - Custom table schema
  - Upload automation

- **[Security Verification Guide](SERVICENOW-SECURITY-VERIFICATION.md)** (Testing)
  - Test connectivity
  - Verify uploads
  - Troubleshoot issues
  - Validate results

---

### 🔍 EKS Discovery & CMDB

- **[Node Discovery](SERVICENOW-NODE-DISCOVERY.md)** (How It Works)
  - EKS cluster discovery
  - Node metadata collection
  - Relationship mapping
  - Automated updates

- **[Viewing Nodes in ServiceNow](SERVICENOW-VIEWING-NODES.md)** (UI Guide)
  - ServiceNow UI navigation
  - Filtering and searching
  - Custom views

---

### 🔧 Troubleshooting & Fixes

#### Change Request Issues
- **[Change Request States Explained](SERVICENOW-CHANGE-REQUEST-STATES.md)**
  - Why you see "request approval"
  - Change lifecycle diagram
  - State values and meanings
  - What happens at each stage

- **[Workflow Fix Needed](SERVICENOW-WORKFLOW-FIX.md)**
  - Approval request missing
  - Proper state transitions
  - Code fixes required
  - Manual workaround

#### CMDB Issues
- **[CMDB Troubleshooting](workflows/TROUBLESHOOTING-SERVICENOW-CMDB.md)**
  - Shell heredoc errors
  - API authentication
  - JSON payload construction
  - Rate limiting

---

### 📚 Reference Documentation

#### Navigation & URLs
- **[Navigation URLs](SERVICENOW-NAVIGATION-URLS.md)** 🔖 **BOOKMARK**
  - DevOps Change Workspace URL
  - All ServiceNow feature URLs
  - Change Request lists
  - Custom views and filters
  - Quick reference table

#### Setup & Configuration
- **[Setup Checklist](SERVICENOW-SETUP-CHECKLIST.md)**
  - Step-by-step validation
  - Configuration verification
  - Access testing
  - Common issues

- **[GitHub Secrets Setup](GITHUB-SECRETS-SERVICENOW.md)**
  - Required secrets
  - Configuration instructions
  - Testing credentials

#### Implementation Status
- **[Implementation Status](SERVICENOW-IMPLEMENTATION-STATUS.md)**
  - Overall progress tracking
  - Component status
  - Testing checklist
  - Next steps

#### Workflows
- **[Workflow Testing](SERVICENOW-WORKFLOW-TESTING.md)**
  - Workflow execution testing
  - API validation
  - Data verification

- **[Workflows README](.github/workflows/SERVICENOW-WORKFLOWS-README.md)**
  - GitHub Actions workflows
  - Integration points
  - Workflow documentation

---

## 🗂️ Documentation Organization

### By Use Case

#### "I'm setting up ServiceNow for the first time"
1. [Quick Start Guide](SERVICENOW-QUICK-START.md)
2. [Application Quick Start](SERVICENOW-APPLICATION-QUICKSTART.md)
3. [Approval Quick Start](SERVICENOW-APPROVALS-QUICKSTART.md)
4. [DevOps Workspace Access](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md)

#### "I need to access the DevOps Change workspace"
1. [Workspace Access Guide](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md) ⭐
2. [Navigation URLs](SERVICENOW-NAVIGATION-URLS.md)

#### "I'm getting an error"
1. [Change Request States](SERVICENOW-CHANGE-REQUEST-STATES.md) - "request approval"
2. [Application Category Fix](SERVICENOW-APPLICATION-CREATION-FIX.md) - "Category is empty"
3. [Workflow Fix](SERVICENOW-WORKFLOW-FIX.md) - Approval issues
4. [CMDB Troubleshooting](workflows/TROUBLESHOOTING-SERVICENOW-CMDB.md) - API errors

#### "I want to understand how it works"
1. [DevOps Change Velocity Overview](SERVICENOW-DEVOPS-CHANGE-VELOCITY.md)
2. [Security Scanning Design](SERVICENOW-SECURITY-SCANNING.md)
3. [Node Discovery](SERVICENOW-NODE-DISCOVERY.md)
4. [Implementation Status](SERVICENOW-IMPLEMENTATION-STATUS.md)

---

## 📊 Integration Components

### ✅ Fully Implemented

1. **DevOps Change Velocity Plugin** (v6.1.0)
   - Modern workspace UI
   - DORA metrics
   - CI/CD integration
   - AI risk insights

2. **Security Scanning** (8 Tools)
   - CodeQL, Trivy, Gitleaks, Semgrep
   - Checkov, tfsec, OWASP Dependency-Check, npm audit
   - SARIF aggregation
   - Custom tables

3. **EKS Discovery** (Automated)
   - 1 EKS cluster
   - 18 nodes across 4 node groups
   - 11 microservices (dev/qa/prod namespaces)
   - Automated relationship mapping

4. **Application Association**
   - Business Application: "Online Boutique"
   - 11 microservices mapped
   - 33+ service dependencies
   - Complete CMDB integration

### ⏳ In Progress

1. **Change Management Automation**
   - Change request creation ✅
   - Approval request ⏳ (needs workflow fix)
   - Multi-level approvals ⏳ (groups need setup)
   - Auto-close ⏳

2. **DORA Metrics**
   - Deployment frequency ⏳
   - Lead time for changes ⏳
   - MTTR ⏳
   - Change failure rate ⏳

---

## 🎯 Quick Reference

### Most Important URLs
```
DevOps Change Workspace:
https://calitiiltddemo3.service-now.com/now/devops-change/home

Online Boutique Changes:
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique

Business Application:
https://calitiiltddemo3.service-now.com/cmdb_ci_business_app.do?sys_id=4ffc7bfec3a4fe90e1bbf0cb0501313f
```

### Key Scripts
```bash
# Create application
bash scripts/create-servicenow-application.sh

# Get application sys_id
bash scripts/get-servicenow-app-sys-id.sh

# Map service dependencies
bash scripts/map-service-dependencies.sh

# Setup approval groups
bash scripts/setup-servicenow-approvals.sh
```

### GitHub Secrets Required
```
SERVICENOW_INSTANCE_URL
SERVICENOW_USERNAME
SERVICENOW_PASSWORD
SERVICENOW_APP_SYS_ID (optional, for application association)
```

---

## 📞 Getting Help

### Documentation Issues
- Check the [Troubleshooting section](#-troubleshooting--fixes) above
- Review [Change Request States](SERVICENOW-CHANGE-REQUEST-STATES.md) for workflow questions
- See [Workspace Access Guide](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md) for setup help

### ServiceNow Resources
- **DevOps Change Velocity Community**: https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps
- **Documentation**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/concept/devops-landing-page-new.html
- **FAQ**: https://www.servicenow.com/community/devops-articles/faq-for-devops-change-velocity/ta-p/3018723

---

## 🗂️ File Organization

### Essential Files (Keep bookmarked)
1. THIS FILE - Complete index
2. [Workspace Access](SERVICENOW-DEVOPS-CHANGE-WORKSPACE-ACCESS.md) - How to access workspace
3. [Navigation URLs](SERVICENOW-NAVIGATION-URLS.md) - All URLs
4. [Application Quick Start](SERVICENOW-APPLICATION-QUICKSTART.md) - Setup guide
5. [Change Request States](SERVICENOW-CHANGE-REQUEST-STATES.md) - Troubleshooting

### All Documentation Files
See complete list in [docs/README.md](README.md) ServiceNow Integration section

---

**Total Documentation**: 23 files
**Quick Start Time**: 30 minutes (all quick starts combined)
**Integration Status**: 80% complete (core features working)

**Ready to get started?** Begin with the [Quick Start Guide](SERVICENOW-QUICK-START.md)!
