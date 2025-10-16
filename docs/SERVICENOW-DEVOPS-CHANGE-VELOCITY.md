# ServiceNow DevOps Change Velocity - Setup Guide

**Current Status**: Not Installed/Configured
**Instance**: https://calitiiltddemo3.service-now.com
**Version**: Zurich (v6.1.0)

---

## 🔍 Current Situation

### What You're Seeing
- DevOps Change Velocity workspace is not available
- Everything appears in "classic mode" (standard ServiceNow UI)
- No DevOps Change menu items visible

### Why This Is Happening
**DevOps Change Velocity is a separate application that must be installed from the ServiceNow Store.**

**Current State**:
- ✅ ServiceNow instance: Running (Zurich v6.1.0)
- ✅ Change Management: Available (standard ITSM)
- ❌ DevOps Change Velocity plugin: **NOT INSTALLED**
- ❌ DevOps Change workspace: **NOT AVAILABLE**

---

## 📦 What is DevOps Change Velocity?

**DevOps Change Velocity** is a premium ServiceNow application that provides:

### Features:
1. **Modern DevOps Change workspace** - Next-gen UI (not classic mode)
2. **Automated change management** - Integration with CI/CD tools
3. **CI/CD orchestration** - GitHub Actions, Jenkins, GitLab, Azure DevOps
4. **Change velocity metrics** - Deployment frequency, lead time, MTTR
5. **Risk prediction** - AI-powered change risk assessment
6. **Pipeline integration** - Direct pipeline to change request linking
7. **Evidence collection** - Automated test results, scan reports

### Vs. Standard Change Management:
| Feature | Standard ITSM Change | DevOps Change Velocity |
|---------|---------------------|------------------------|
| Change Requests | ✅ Yes | ✅ Yes |
| Approval Workflows | ✅ Yes | ✅ Yes (automated) |
| Modern Workspace | ❌ Classic UI only | ✅ Modern UI |
| CI/CD Integration | ❌ Manual/API only | ✅ Native connectors |
| Velocity Metrics | ❌ No | ✅ Yes |
| Risk Prediction | ❌ No | ✅ AI-powered |
| Pipeline Visibility | ❌ No | ✅ Yes |

---

## 🚀 Installation Options

### Option 1: Install DevOps Change Velocity (Recommended for Full Features)

**Prerequisites**:
- ServiceNow Enterprise Edition (or higher)
- Admin access to ServiceNow instance
- License for DevOps Change Velocity application

**Installation Steps**:

1. **Access ServiceNow Store**:
   - Login to: https://store.servicenow.com/
   - Search for: "DevOps Change Velocity"
   - Product Link: https://store.servicenow.com/store/app/1b2aabe21b246a50a85b16db234bcbe1

2. **Request/Purchase License**:
   - DevOps Change Velocity may require separate licensing
   - Contact ServiceNow account representative
   - Or request trial license

3. **Install Application**:
   - From ServiceNow instance:
     - Navigate to: **System Applications** → **All Available Applications** → **All**
     - Search for: "DevOps Change Velocity"
     - Click: **Install**
   - Or from ServiceNow Store:
     - Click: **Request Install**
     - Follow installation wizard

4. **Configure Integration**:
   - After installation, access: **DevOps Change** menu (will appear in left navigation)
   - Follow guided setup playbook
   - Connect orchestration tools (GitHub Actions recommended)

**Estimated Time**: 2-4 hours (including configuration)

**Cost**: Requires additional licensing (contact ServiceNow sales)

---

### Option 2: Use Standard Change Management (Current Approach)

**What You Have Now**:
- ✅ Standard ITSM Change Management
- ✅ Change Request table
- ✅ Approval workflows
- ✅ REST API for automation
- ✅ Application association (we implemented this)
- ✅ CMDB integration

**What You Can Do**:
- Create change requests via API (already working)
- Automated approvals based on environment (dev/qa/prod)
- Associate changes with Business Applications
- Track deployment history
- View changes in standard Change list

**Access Your Changes**:
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
```

**Pros**:
- ✅ No additional cost
- ✅ Works with current ServiceNow edition
- ✅ Already implemented and functional
- ✅ Meets basic change management requirements

**Cons**:
- ❌ No modern DevOps workspace
- ❌ No automated CI/CD metrics
- ❌ No AI risk prediction
- ❌ Manual API integration required

---

## 📊 Comparison of Approaches

### With DevOps Change Velocity (After Installation)

**Workflow**:
```
GitHub Actions → DevOps Change Connector → Change Request (auto-created)
                    ↓
              Change Workspace (modern UI)
                    ↓
              Approval (automated based on risk)
                    ↓
              Deployment proceeds
                    ↓
              Evidence collected (test results, scans)
                    ↓
              Metrics dashboard updated
```

**Benefits**:
- Modern, guided workspace
- Automated change creation from pipelines
- Real-time pipeline visibility
- Change velocity metrics (DORA metrics)
- AI-powered risk assessment

---

### With Standard Change Management (Current Setup)

**Workflow**:
```
GitHub Actions → REST API call → Change Request created
                    ↓
              Change Request List (classic UI)
                    ↓
              Approval (based on environment rules)
                    ↓
              Deployment proceeds
                    ↓
              Change Request updated via API
```

**Benefits**:
- Already working
- No additional cost
- Sufficient for basic change tracking
- Good for smaller teams/projects

---

## 🎯 What We've Already Implemented (Without DevOps Change Velocity)

Even without the DevOps Change Velocity plugin, we've implemented comprehensive change management:

### ✅ Implemented Features:

1. **Automated Change Request Creation**:
   - GitHub Actions workflow creates change requests via REST API
   - Includes deployment details, environment, application association

2. **Multi-Level Approval Workflow**:
   - Dev: Auto-approved
   - QA: Single approval required
   - Prod: Multi-level approval (DevOps + CAB)

3. **Application Association**:
   - Change requests linked to "Online Boutique" Business Application
   - All 11 microservices mapped as related CIs
   - Complete dependency graph

4. **Security Integration**:
   - 8 security tools scan results uploaded to ServiceNow
   - SARIF aggregation from all scanners
   - Vulnerability tracking in custom tables

5. **Infrastructure Discovery**:
   - EKS cluster automatically discovered
   - 18 nodes populated in CMDB
   - Service-to-service relationships mapped

6. **Change Tracking**:
   - Complete deployment history
   - Approval audit trail
   - Status updates (pending/approved/implemented)

---

## 🚦 Recommendation

### For Your Use Case (Microservices Demo + Learning):

**Use Standard Change Management (Current Approach)**

**Reasons**:
1. ✅ Already implemented and working
2. ✅ No additional licensing costs
3. ✅ Meets all core change management requirements
4. ✅ Demonstrates ServiceNow integration capabilities
5. ✅ Sufficient for GitHub + AWS + ServiceNow demo

**When to Consider DevOps Change Velocity**:
- Enterprise production deployment
- Need for DORA metrics (deployment frequency, lead time, MTTR)
- AI-powered change risk assessment required
- Multiple CI/CD tools (Jenkins, GitLab, Azure DevOps, GitHub)
- Large team with high deployment frequency
- Budget for additional ServiceNow licensing

---

## 📋 Next Steps

### Immediate Actions:

1. **Continue with current setup** - Standard Change Management
2. **Access your changes**:
   ```
   https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
   ```
3. **Create custom view** for Online Boutique changes (see below)

### Creating "Online Boutique Changes" Custom View:

1. Navigate to: **Change** → **All**
2. Click filter icon (funnel)
3. Add conditions:
   - `Business Service` = `Online Boutique`
4. Click: **Run**
5. Right-click column header → **Configure** → **List Layout**
6. Add useful columns:
   - Environment (u_environment custom field)
   - Deployment Status
   - Approval Status
   - Implementation Date
7. Click: **Save**
8. Click breadcrumbs dropdown → **Save filter as**
9. Name: `Online Boutique - All Changes`
10. Check: **Make visible to other users**
11. Click: **Save**

Now you have a dedicated view for all Online Boutique changes that looks and works similarly to DevOps Change workspace.

---

### Optional: Explore DevOps Change Velocity

If you want to evaluate the premium features:

1. **Request Trial License**:
   - Contact ServiceNow representative
   - Or check if trial is available in ServiceNow Store

2. **Review Documentation**:
   - https://www.servicenow.com/products/devops-change-velocity.html
   - https://store.servicenow.com/store/app/1b2aabe21b246a50a85b16db234bcbe1

3. **Compare ROI**:
   - Licensing cost vs. value of advanced features
   - Team size and deployment frequency
   - Need for DORA metrics and AI risk assessment

---

## 🔧 Enhancing Current Setup (Without DevOps Change Velocity)

### You Can Still Add:

1. **Custom Dashboards**:
   - Create Performance Analytics dashboard
   - Track change success rate
   - Monitor deployment frequency
   - Calculate mean time to deployment

2. **Additional Automation**:
   - Auto-close changes after successful deployment
   - Send Slack/Teams notifications
   - Link to GitHub PR URLs
   - Include deployment logs

3. **Better Reporting**:
   - Create custom reports for change metrics
   - Export to PDF/Excel
   - Schedule automated reports

4. **Enhanced UI**:
   - Create custom Service Portal page
   - Build mobile-friendly change views
   - Add charts and visualizations

---

## ✅ Summary

**Current State**:
- ✅ Standard Change Management is working
- ✅ All core features implemented
- ❌ DevOps Change Velocity workspace not available (requires separate plugin)

**Your Options**:
1. **Continue with current setup** (recommended for demo/learning)
2. **Install DevOps Change Velocity** (requires licensing, 2-4 hours setup)

**What You're Using Now**:
```
Standard ServiceNow ITSM Change Management + Custom REST API Integration
```

**Access Your Changes**:
```
https://calitiiltddemo3.service-now.com/change_request_list.do?sysparm_query=business_service.name=Online%20Boutique
```

**This is NOT wrong** - it's a valid, functional approach that many organizations use successfully!

---

## 📞 Getting Help

**ServiceNow Support**:
- Plugin installation questions: ServiceNow support portal
- Licensing questions: ServiceNow account representative
- Trial license: https://www.servicenow.com/lpdem/request-a-servicenow-demo.html

**Community**:
- DevOps Change Velocity Community: https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps
- ITSM Community: https://www.servicenow.com/community/itsm-forum/bd-p/itsm_forum

---

**Last Updated**: 2025-10-16
**Recommendation**: Use standard Change Management (current setup) - fully functional for your use case
