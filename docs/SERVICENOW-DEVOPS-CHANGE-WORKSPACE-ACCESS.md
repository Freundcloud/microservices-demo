# Accessing ServiceNow DevOps Change Workspace

**Good News**: DevOps Change Velocity **IS INSTALLED** in your ServiceNow instance!

**Plugin**: `sn_devops_chgvlcty`
**Version**: 6.1.0
**Installed**: September 26, 2025

---

## 🎉 DevOps Change Workspace URL

### Direct Access:
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
```

**Bookmark this URL!**

---

## ✅ Prerequisites Verified

### Plugin Status:
- ✅ **DevOps Change Velocity** installed (v6.1.0)
- ✅ **Plugin ID**: `sn_devops_chgvlcty`
- ✅ **Installation Date**: September 26, 2025

### User Permissions:
Your `github_integration` user has the required roles:
- ✅ **sn_devops.viewer** - View DevOps Change workspace
- ✅ **sn_devops.tool_owner** - Manage DevOps tools
- ✅ **sn_devops.admin** - Administer DevOps Change
- ✅ **sn_devops.app_owner** - Application owner
- ✅ **sn_devops.integration** - Integration permissions
- ✅ **sn_devops.report_viewer** - View reports
- ✅ **sn_devops_ws.workspace_user** - Workspace user

**You have full access!**

---

## 📋 Accessing the Workspace

### Method 1: Direct URL (Recommended)
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
```

### Method 2: Via ServiceNow Navigation
1. Login to ServiceNow: https://calitiiltddemo3.service-now.com
2. In the **Filter Navigator** (left sidebar), search for: `DevOps Change Workspace`
3. Click: **DevOps Change Workspace ➚**

### Method 3: Via Application Menu
1. Click **All** in the top navigation
2. Find: **DevOps Change Workspace ➚** in the list
3. Click to open

---

## 🔧 Initial Setup Required

Since the plugin was recently installed (Sep 26, 2025), you'll need to complete the initial setup when you first access the workspace.

### Setup Wizard Steps:

1. **Open the workspace**:
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/home
   ```

2. **Follow the guided playbook**:
   - **Step 1: Connect tools** - Connect GitHub Actions
   - **Step 2: Configure change policies** - Set approval rules
   - **Step 3: Discover pipelines** - Auto-discover workflows
   - **Step 4: Enable automation** - Configure change creation

3. **Connect GitHub Actions**:
   - Tool type: **GitHub Actions**
   - Repository: `Freundcloud/microservices-demo`
   - Personal Access Token: (use existing GitHub PAT)
   - Scope: Repository workflows

4. **Configure Change Automation**:
   - Select workflows to automate:
     - `deploy-with-servicenow-basic.yaml`
     - `build-and-push-images.yaml`
   - Set change attributes:
     - Application: **Online Boutique**
     - Assignment group: **DevOps Team**
     - Approval policies: Based on environment

---

## 🎯 What You'll See in the Workspace

### Home Dashboard:
- **Change velocity metrics** - Deployment frequency, lead time
- **Pipeline overview** - All connected pipelines
- **Change risk insights** - AI-powered predictions
- **Recent changes** - Latest change requests

### Key Features:
1. **Pipelines** - All CI/CD pipelines
2. **Change Requests** - Associated with pipelines
3. **Applications** - Business applications (Online Boutique)
4. **Reports** - DORA metrics, velocity dashboards
5. **Configuration** - Tool connections, policies

---

## 🔗 Connecting GitHub Actions

### Prerequisites:
- GitHub Personal Access Token with `repo` and `workflow` scopes
- Admin access to `Freundcloud/microservices-demo` repository

### Connection Steps:

1. **In DevOps Change Workspace**:
   - Click: **Configuration** → **Tools**
   - Click: **Add Tool**
   - Select: **GitHub Actions**

2. **Configure Connection**:
   ```
   Tool Name: GitHub Actions - microservices-demo
   Repository URL: https://github.com/Freundcloud/microservices-demo
   Personal Access Token: <your-github-pat>
   Organization: Freundcloud
   ```

3. **Test Connection**:
   - Click: **Test Connection**
   - Verify: ✅ Connection successful

4. **Discover Workflows**:
   - Click: **Discover Workflows**
   - Select workflows to import:
     - [x] deploy-with-servicenow-basic.yaml
     - [x] build-and-push-images.yaml
     - [x] terraform-apply.yaml
     - [x] security-scan.yaml

5. **Enable Change Automation**:
   - For each workflow, configure:
     - **Trigger**: On workflow run
     - **Change Type**: Standard/Normal
     - **Application**: Online Boutique
     - **Environment**: dev/qa/prod (from workflow input)
     - **Auto-approve dev**: Yes
     - **Require approval qa/prod**: Yes

---

## 🎨 Workspace Layout

```
┌─────────────────────────────────────────────────────────────┐
│ DevOps Change Workspace (Modern UI)                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  📊 Dashboard                                                │
│  ├── Deployment Frequency: 12/week                          │
│  ├── Lead Time: 2.5 hours                                   │
│  ├── MTTR: 15 minutes                                       │
│  └── Change Failure Rate: 5%                                │
│                                                              │
│  🔄 Pipelines                                                │
│  ├── deploy-with-servicenow-basic.yaml                      │
│  ├── build-and-push-images.yaml                             │
│  └── terraform-apply.yaml                                   │
│                                                              │
│  📋 Recent Changes                                           │
│  ├── CHG0001234 - Deploy to dev (Closed Complete)           │
│  ├── CHG0001235 - Deploy to qa (Pending Approval)           │
│  └── CHG0001236 - Deploy to prod (Approved)                 │
│                                                              │
│  🏢 Applications                                             │
│  └── Online Boutique                                         │
│      ├── 11 microservices                                   │
│      ├── 33 dependencies                                    │
│      └── Risk Score: Low                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🆚 Workspace vs. Classic Change List

### DevOps Change Workspace (Modern):
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
```
- ✅ Modern, guided UI
- ✅ Pipeline visibility
- ✅ DORA metrics
- ✅ AI risk insights
- ✅ Integrated with CI/CD tools

### Classic Change Request List:
```
https://calitiiltddemo3.service-now.com/change_request_list.do
```
- ✅ Traditional ServiceNow UI
- ✅ All change requests
- ✅ Advanced filtering
- ✅ Export to Excel
- ✅ Custom reports

**Both are available!** Use whichever fits your workflow.

---

## 📊 Enabling DORA Metrics

Once connected, DevOps Change Velocity automatically calculates:

### Four Key Metrics:
1. **Deployment Frequency**
   - How often you deploy to production
   - Target: Multiple per day (elite performers)

2. **Lead Time for Changes**
   - Time from commit to production
   - Target: Less than 1 hour (elite performers)

3. **Mean Time to Restore (MTTR)**
   - Time to recover from incidents
   - Target: Less than 1 hour (elite performers)

4. **Change Failure Rate**
   - Percentage of changes causing incidents
   - Target: 0-15% (elite performers)

### Viewing Metrics:
1. Open: **DevOps Change Workspace**
2. Navigate to: **Reports** → **Velocity Metrics**
3. Select: **DORA Metrics Dashboard**
4. Filter by: Application (Online Boutique)

---

## 🔍 Troubleshooting Workspace Access

### Problem: "Page not found" or 404 error
**Solution**: Verify URL is correct:
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
```
(Note the `/now/devops-change/home` path)

### Problem: "Access denied" or permission error
**Solution**: Verify user has `sn_devops.viewer` role:
```bash
# Check via API
PASSWORD='oA3KqdUVI8Q_^>'
curl -s -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user_has_role?sysparm_query=user.user_name=github_integration^role.name=sn_devops.viewer"
```

### Problem: Workspace is empty / no data
**Solution**: Complete initial setup wizard:
1. Connect GitHub Actions tool
2. Discover workflows
3. Enable change automation
4. Trigger a test deployment

### Problem: Pipelines not showing
**Solution**:
1. Ensure GitHub Actions tool is connected
2. Run workflow discovery again
3. Check workflow has `servicenow` references in YAML
4. Verify repository permissions

---

## 🚀 Quick Start Workflow

### Complete Setup in 15 Minutes:

1. **Access Workspace** (1 min):
   ```
   https://calitiiltddemo3.service-now.com/now/devops-change/home
   ```

2. **Connect GitHub** (5 min):
   - Add GitHub Actions tool
   - Enter repository URL and PAT
   - Test connection

3. **Discover Workflows** (3 min):
   - Click: Discover Workflows
   - Select all deployment workflows
   - Import

4. **Configure Automation** (5 min):
   - For each workflow:
     - Set Application: Online Boutique
     - Configure approval rules
     - Enable auto-creation

5. **Test Deployment** (1 min):
   ```bash
   gh workflow run deploy-with-servicenow-basic.yaml --field environment=dev
   ```

6. **Verify in Workspace**:
   - Check: Pipelines tab
   - View: Recent Changes
   - Monitor: Change progress

---

## 📚 Additional Resources

### ServiceNow Documentation:
- **DevOps Change Velocity**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/concept/devops-landing-page-new.html
- **GitHub Actions Integration**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/task/github-tool-registration.html
- **Change Automation**: https://www.servicenow.com/docs/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/task/configure-change-automation.html

### Community:
- **DevOps Change Velocity Community**: https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps
- **FAQ**: https://www.servicenow.com/community/devops-articles/faq-for-devops-change-velocity/ta-p/3018723

---

## ✅ Summary

**DevOps Change Velocity Status**:
- ✅ Plugin installed (v6.1.0)
- ✅ User has required roles
- ✅ Workspace accessible

**Access URL**:
```
https://calitiiltddemo3.service-now.com/now/devops-change/home
```

**Next Steps**:
1. Open workspace URL
2. Complete initial setup wizard
3. Connect GitHub Actions
4. Enable change automation
5. Trigger test deployment
6. View metrics and insights

**You're ready to use the modern DevOps Change Workspace!** 🎉

---

**Last Updated**: 2025-10-16
**Plugin Version**: 6.1.0 (sn_devops_chgvlcty)
**User**: github_integration (full access verified)
