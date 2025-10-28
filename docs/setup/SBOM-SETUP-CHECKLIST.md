# ServiceNow SBOM Integration - Setup Checklist

Quick reference for setting up SBOM integration with ServiceNow.

## ✅ Pre-Implementation Checklist

### ServiceNow Configuration

- [ ] **Verify Vulnerability Response plugin installed**
  ```
  Navigate to: System Applications → All Available Applications → All
  Search for: "Vulnerability Response"
  Status: Should show "Installed" or "Active"
  ```

- [ ] **Grant sbom_ingest role to integration user**
  ```
  Navigate to: User Administration → Users
  Find user: github_integration (or your integration user)
  Roles → Edit → Add role: sbom_ingest
  Save
  ```

- [ ] **Verify user credentials work**
  ```bash
  # Test with curl or the verification script
  curl -u "username:password" \
    "https://instance.service-now.com/api/now/table/sys_user?sysparm_limit=1"

  # Should return HTTP 200 with user data
  ```

### GitHub Secrets

- [ ] **Add or update SN_SBOM_USER**
  ```
  Navigate to: Repository → Settings → Secrets and variables → Actions
  Add secret: SN_SBOM_USER
  Value: github_integration (or your SBOM user)
  ```

- [ ] **Add or update SN_SBOM_PASSWORD**
  ```
  Add secret: SN_SBOM_PASSWORD
  Value: [password for SBOM user]
  ```

- [ ] **Verify SERVICENOW_INSTANCE_URL exists**
  ```
  Check existing secret: SERVICENOW_INSTANCE_URL
  Format: https://instance.service-now.com (no trailing slash)
  ```

- [ ] **Verify GITHUB_TOKEN has repo scope**
  ```
  This is automatically provided by GitHub Actions
  No action needed - automatically available
  ```

### Optional: Business Applications

- [ ] **Create business applications in ServiceNow (recommended)**
  ```
  Navigate to: Business Applications → Create New

  Create for each service:
  - Name: "Online Boutique - frontend"
  - Name: "Online Boutique - cartservice"
  - Name: "Online Boutique - productcatalogservice"
  ... (repeat for all 12 services)
  ```

## ✅ Post-Implementation Verification

### Test SBOM Upload

- [ ] **Trigger a build manually**
  ```bash
  # Option 1: Use promote script
  just promote 1.2.6 all

  # Option 2: GitHub Actions UI
  Navigate to: Actions → MASTER-PIPELINE
  Click: "Run workflow"
  Environment: dev
  Force build: true
  Run workflow
  ```

- [ ] **Check GitHub Actions output**
  ```
  Expected in build summary:
  ✅ SBOM generated and uploaded to ServiceNow
  ✅ Business Application: `Online Boutique - {service}`
  ✅ Lifecycle Stage: `pre_production`
  ```

- [ ] **Verify in ServiceNow**
  ```
  Navigate to: Vulnerability Response → SBOM Workspace → Documents

  Expected: 12 new SBOM documents (one per service)
  Format: microservices-demo/sbom-{service}.json
  Build ID: Should match GitHub run number
  ```

- [ ] **Check vulnerability correlation**
  ```
  Open any SBOM document
  Click "Vulnerabilities" tab
  Expected: List of CVEs (if any vulnerabilities exist)
  Status: Should show severity, CVSS score, affected packages
  ```

### Troubleshooting

- [ ] **If SBOM upload fails with 401 error**
  ```
  → Check: SN_SBOM_USER has sbom_ingest role
  → Check: Password in SN_SBOM_PASSWORD is correct
  → Check: User is active in ServiceNow
  ```

- [ ] **If no SBOMs appear in ServiceNow**
  ```
  → Wait 5-10 minutes for processing
  → Check ServiceNow system logs for errors
  → Verify Vulnerability Response plugin is active
  → Check that workflow step didn't skip (continue-on-error: true)
  ```

- [ ] **If vulnerabilities not showing**
  ```
  → Wait up to 15 minutes for correlation
  → Verify fetchVulnerabilityInfo: true in workflow
  → Check ServiceNow vulnerability database is updated
  → Contact ServiceNow admin if database access is restricted
  ```

## ✅ Ongoing Operations

### Monitor SBOM Uploads

- [ ] **Regular verification** (weekly)
  ```
  Check in ServiceNow: SBOM Workspace → Documents
  Verify recent builds have SBOMs uploaded
  Check for any failed uploads
  ```

- [ ] **Review vulnerabilities** (weekly)
  ```
  Navigate to: Vulnerability Response → Dashboard
  Review critical/high vulnerabilities
  Create change requests for remediation
  Track fixes across environments
  ```

### Maintenance

- [ ] **Rotate SBOM credentials** (90 days)
  ```
  1. Create new password for SN_SBOM_USER in ServiceNow
  2. Update SN_SBOM_PASSWORD secret in GitHub
  3. Test with a manual build
  4. Delete old password from password manager
  ```

- [ ] **Review business application mappings** (quarterly)
  ```
  Verify all services have correct business applications
  Update mappings if services are renamed
  Archive applications for retired services
  ```

## 📋 Quick Reference

### ServiceNow URLs

```bash
# Instance (replace 'instance' with your instance name)
https://instance.service-now.com

# SBOM Workspace
https://instance.service-now.com/now/nav/ui/classic/params/target/sbom_workspace.do

# Vulnerability Response Dashboard
https://instance.service-now.com/now/nav/ui/classic/params/target/vul_response_dashboard.do

# User Administration
https://instance.service-now.com/now/nav/ui/classic/params/target/sys_user_list.do
```

### GitHub Actions URLs

```bash
# Actions Dashboard
https://github.com/Freundcloud/microservices-demo/actions

# MASTER-PIPELINE Workflow
https://github.com/Freundcloud/microservices-demo/actions/workflows/MASTER-PIPELINE.yaml

# Build Images Workflow
https://github.com/Freundcloud/microservices-demo/actions/workflows/build-images.yaml

# Repository Secrets
https://github.com/Freundcloud/microservices-demo/settings/secrets/actions
```

### Documentation

```bash
# Complete SBOM Integration Guide
docs/SBOM-SERVICENOW-INTEGRATION.md

# ServiceNow Setup Guide
docs/setup/SERVICENOW-SETUP.md

# Workflow Documentation
.github/workflows/README.md
```

## 🎯 Success Criteria

Your SBOM integration is fully operational when:

- ✅ All 12 services generate SBOMs on every build
- ✅ SBOMs upload successfully to ServiceNow
- ✅ Business applications are correctly linked
- ✅ Vulnerabilities are automatically correlated
- ✅ Lifecycle stages track correctly (dev/qa/prod)
- ✅ No authentication errors in workflow logs
- ✅ ServiceNow SBOM Workspace shows recent uploads
- ✅ Team can access and review vulnerability data

---

**Need Help?**
- Review full documentation: [docs/SBOM-SERVICENOW-INTEGRATION.md](../SBOM-SERVICENOW-INTEGRATION.md)
- Check workflow logs: [GitHub Actions](https://github.com/Freundcloud/microservices-demo/actions)
- ServiceNow support: Contact your ServiceNow administrator

**Last Updated**: 2025-10-28
