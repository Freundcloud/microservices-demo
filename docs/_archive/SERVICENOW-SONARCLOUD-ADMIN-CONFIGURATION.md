# ServiceNow SonarCloud Integration - Admin Configuration Guide

> **For:** ServiceNow Administrators
> **Purpose:** Enable SonarCloud quality scan data to flow into ServiceNow DevOps
> **Status:** Configuration Required
> **Date:** 2025-10-28

---

## 🎯 **Objective**

Enable ServiceNow DevOps to receive and store SonarCloud quality scan data from GitHub Actions pipelines.

**Current Status:**
- ✅ ServiceNow DevOps v6.1.0 installed
- ✅ GitHub Actions configured correctly
- ✅ SonarCloud tool record created (Tool ID: `98d718bac3bc3e54e1bbf0cb050131d5`)
- ❌ Quality scan data NOT flowing into ServiceNow tables
- ❌ Requires UI configuration (cannot be done via API)

---

## 📋 **Prerequisites Verified**

✅ **ServiceNow DevOps Version:** 6.1.0 (confirmed installed)
✅ **Required Tables Exist:**
- `sn_devops_software_quality_scan_summary`
- `sn_devops_software_quality_scan_detail`
- `sn_devops_software_quality_category`

✅ **GitHub Tool Configured:**
- Tool ID: `f62c4e49c3fcf614e1bbf0cb050131ef`
- Name: "GithHubARC"
- Type: GitHub
- Authentication: Basic (github_integration user)

✅ **SonarCloud Tool Created:**
- Tool ID: `98d718bac3bc3e54e1bbf0cb050131d5`
- Name: "SonarCloud"
- Type: SonarQube
- URL: https://sonarcloud.io

---

## 🔧 **Required Configuration Steps**

### **Step 1: Verify SonarCloud Tool Configuration**

**Navigate to:**
```
ServiceNow → DevOps → Tools
```

**Find the SonarCloud tool:**
- Search for: "SonarCloud" or Tool ID `98d718bac3bc3e54e1bbf0cb050131d5`
- Verify fields:
  - **Name:** SonarCloud
  - **Type:** SonarQube
  - **URL:** https://sonarcloud.io
  - **Active:** true (checkbox checked)

**If fields are incomplete:**
- Click "Edit"
- Fill in missing fields
- Save

---

### **Step 2: Enable Quality Scanning Feature**

**Navigate to:**
```
ServiceNow → DevOps → Configuration → Properties
```

**Search for property:**
```
sn_devops.enable_software_quality_scanning
```

**Set to:** `true`

**If property doesn't exist:**
1. Create new property: `sn_devops.enable_software_quality_scanning`
2. Type: `true/false`
3. Value: `true`
4. Description: "Enable software quality scanning integration"

---

### **Step 3: Configure Tool Integration**

**Navigate to:**
```
ServiceNow → DevOps → Tool Integration Configuration
```

**Create new integration:**
1. Click "New"
2. Fill in:
   - **Tool:** Select "SonarCloud" (98d718bac3bc3e54e1bbf0cb050131d5)
   - **Orchestration Tool:** Select "GithHubARC" (f62c4e49c3fcf614e1bbf0cb050131ef)
   - **Active:** true
   - **Integration Type:** Quality Scan
3. Save

**Purpose:** This links the GitHub tool (for authentication) with the SonarCloud tool (for quality data).

---

### **Step 4: Configure API Endpoint (if needed)**

**Navigate to:**
```
ServiceNow → System Web Services → REST API
```

**Verify endpoint exists:**
```
/api/devops/orchestration/qualityScan
```

**If missing, create:**
1. Go to: System Web Services → Scripted REST APIs
2. Create new: "DevOps Quality Scan"
3. Base path: `/api/devops/orchestration`
4. Add resource: `qualityScan`
5. Method: POST
6. Active: true

---

### **Step 5: Grant User Permissions**

**Navigate to:**
```
ServiceNow → User Administration → Users
```

**Find user:** `github_integration`

**Verify roles include:**
- ✅ `sn_devops.integrations` (or `sn_devops.integration_user`)
- ✅ `sn_devops.viewer`
- ✅ `web_service_admin` (for API access)

**Add missing roles if needed.**

---

### **Step 6: Enable Quality Gate Evaluation (Optional)**

**Navigate to:**
```
ServiceNow → DevOps → Configuration → Quality Gates
```

**Configure:**
1. Create quality gate policies
2. Link to change request workflows
3. Define thresholds (bugs, vulnerabilities, code smells)

**Note:** This is optional but recommended for automated quality enforcement.

---

### **Step 7: Verify Integration Endpoints**

**Navigate to:**
```
ServiceNow → System Logs → REST Messages
```

**Enable logging:**
1. Go to: System Diagnostics → Debug Log
2. Enable: `sn_devops.*`
3. Level: Info or Debug

**Purpose:** Helps troubleshoot if data still doesn't flow after configuration.

---

## 🧪 **Testing the Configuration**

### **Test 1: Trigger GitHub Workflow**

**From command line:**
```bash
gh workflow run sonarcloud-scan.yaml --ref main
```

**Or from GitHub UI:**
1. Navigate to: https://github.com/Freundcloud/microservices-demo/actions
2. Select: "SonarCloud Quality Analysis"
3. Click: "Run workflow"
4. Branch: main
5. Click: "Run workflow"

### **Test 2: Verify Data in ServiceNow**

**After workflow completes (~3-5 minutes):**

**Navigate to:**
```
ServiceNow → DevOps → Software Quality Scan Summary
```

**Or via API:**
```bash
curl -u "USERNAME:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_software_quality_scan_summary?sysparm_limit=5"
```

**Expected result:**
```json
{
  "result": [
    {
      "project_key": "Freundcloud_microservices-demo",
      "quality_gate_status": "OK",
      "bugs": "0",
      "vulnerabilities": "5",
      "code_smells": "23",
      "sys_created_on": "2025-10-28 14:45:00"
    }
  ]
}
```

---

## 🔍 **Troubleshooting**

### **Issue: Data Still Not Appearing**

**Check 1: ServiceNow Logs**

**Navigate to:**
```
ServiceNow → System Logs → Application Logs
```

**Filter:**
- Source: `sn_devops.*`
- Level: Error or Warning
- Created: Last 1 hour

**Look for:**
- Authentication errors
- Tool configuration errors
- API endpoint errors

---

**Check 2: GitHub Action Logs**

**Navigate to:**
```
GitHub → Actions → Recent workflow run
```

**Check step:** "Upload SonarCloud Results to ServiceNow"

**Look for:**
- HTTP status codes (should be 200 or 201)
- Error messages from ServiceNow
- Authentication failures

---

**Check 3: Tool Integration**

**Verify in ServiceNow:**
```
DevOps → Tool Integration Configuration
```

**Ensure:**
- Integration exists
- Both tools are linked
- Integration is Active
- No error messages

---

**Check 4: System Properties**

**Navigate to:**
```
ServiceNow → System Definition → System Properties
```

**Search for:** `sn_devops`

**Verify these are set:**
```
sn_devops.enable_software_quality_scanning = true
sn_devops.enable_automatic_associations = true
sn_devops.import.save.payloads.as.attachments = false (for performance)
```

---

### **Issue: Authentication Errors**

**Verify credentials:**

**Navigate to:**
```
ServiceNow → User Administration → Users → github_integration
```

**Check:**
- User is Active
- Password is correct (test login)
- Has required roles
- Not locked out

**Test authentication:**
```bash
curl -u "github_integration:PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool/98d718bac3bc3e54e1bbf0cb050131d5"
```

Should return the SonarCloud tool record.

---

### **Issue: Missing Tables**

**If tables don't exist, reinstall DevOps module:**

**Navigate to:**
```
ServiceNow → System Applications → All Available Applications → All
```

**Search:** "DevOps Change Velocity"

**Install/Upgrade:**
- Current version: 6.1.0
- Ensure all plugins are activated
- Restart instance if needed

---

## 📞 **ServiceNow Support**

If configuration still doesn't work after following these steps:

**Create ServiceNow Support Ticket:**
- **Category:** DevOps
- **Subcategory:** Integration
- **Issue:** SonarQube quality scan data not flowing from GitHub Actions

**Include in ticket:**
- ServiceNow instance: calitiiltddemo3.service-now.com
- DevOps version: 6.1.0
- Tool IDs: GitHub (f62c4e49c3fcf614e1bbf0cb050131ef), SonarCloud (98d718bac3bc3e54e1bbf0cb050131d5)
- GitHub Actions workflow: https://github.com/Freundcloud/microservices-demo/actions
- Error logs from ServiceNow (if any)
- GitHub Action logs showing successful upload

---

## 📚 **Additional Resources**

**ServiceNow Documentation:**
- [SonarQube Integration](https://docs.servicenow.com/bundle/utah-devops/page/product/enterprise-dev-ops/concept/sonarqube-devops-integration-devops.html)
- [DevOps Change Velocity](https://docs.servicenow.com/bundle/utah-devops/page/product/enterprise-dev-ops/concept/devops-change-velocity.html)

**GitHub Actions:**
- [ServiceNow DevOps Sonar Action](https://github.com/ServiceNow/servicenow-devops-sonar)
- [GitHub Marketplace](https://github.com/marketplace/actions/servicenow-devops-sonar)

**SonarCloud:**
- [Dashboard](https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo)

---

## ✅ **Success Criteria**

After completing these steps, you should see:

1. ✅ Quality scan summaries in: `DevOps → Software Quality Scan Summary`
2. ✅ Project: "Freundcloud_microservices-demo"
3. ✅ Quality gate status, bugs, vulnerabilities, code smells
4. ✅ Data updated with each GitHub Actions workflow run

---

## 🎯 **Expected Timeline**

- **Configuration:** 15-30 minutes
- **Testing:** 5 minutes per workflow run
- **Troubleshooting (if needed):** 30-60 minutes

---

## 📝 **Configuration Checklist**

Use this checklist to track progress:

- [ ] **Step 1:** Verified SonarCloud tool configuration
- [ ] **Step 2:** Enabled quality scanning feature property
- [ ] **Step 3:** Created tool integration configuration
- [ ] **Step 4:** Verified API endpoints exist
- [ ] **Step 5:** Granted user permissions
- [ ] **Step 6:** (Optional) Configured quality gates
- [ ] **Step 7:** Enabled debug logging
- [ ] **Test 1:** Triggered GitHub workflow
- [ ] **Test 2:** Verified data in ServiceNow
- [ ] **Success:** Quality scan data flowing correctly

---

## 💡 **Alternative: Use SonarCloud Dashboard**

If ServiceNow configuration proves complex or time-consuming:

**Recommendation:** Use SonarCloud dashboard as primary source

**Benefits:**
- ✅ Already working (no configuration needed)
- ✅ Richer visualizations and analysis
- ✅ Full quality history and trends
- ✅ Better developer experience
- ✅ No additional ServiceNow licensing

**Access:**
```
https://sonarcloud.io/dashboard?id=Freundcloud_microservices-demo
```

**This is industry best practice** - many organizations use tool-native dashboards for detailed analysis while using ServiceNow for change management only.

---

## 📧 **Contact**

**For questions about this configuration:**
- GitHub Repository: https://github.com/Freundcloud/microservices-demo
- Documentation: docs/SONARCLOUD-SERVICENOW-EXPLAINED.md

**For ServiceNow platform support:**
- ServiceNow Support Portal
- Instance: calitiiltddemo3.service-now.com

---

**Last Updated:** 2025-10-28
**Status:** Configuration Pending
**Priority:** Medium (workaround available via SonarCloud dashboard)
