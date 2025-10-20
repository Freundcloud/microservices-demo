# ServiceNow DevOps Change API - Missing Prerequisites

**Status**: ⚠️ **CRITICAL - Required Plugins May Be Missing**
**Created**: 2025-10-17
**Issue**: ServiceNow DevOps Change GitHub Actions failing with "Internal server error"

---

## Root Cause Analysis

Based on official ServiceNow documentation, the DevOps Change GitHub Actions **require IntegrationHub plugins** that may not be installed in your ServiceNow instance.

---

## Required Plugins (NOT VERIFIED)

The following plugins are **required** for GitHub Actions integration with ServiceNow DevOps Change:

### 1. ServiceNow IntegrationHub Runtime
- **Plugin ID**: `com.glide.hub.integration.runtime`
- **Purpose**: Core IntegrationHub functionality
- **Required For**: All IntegrationHub-based integrations

### 2. IntegrationHub Action Step - REST
- **Plugin ID**: `com.glide.hub.action_step.rest`
- **Purpose**: REST API action steps
- **Required For**: GitHub Actions to call ServiceNow APIs

### 3. IntegrationHub Action Template - Data Stream
- **Plugin ID**: `com.glide.hub.action_type.datastream`
- **Purpose**: Data streaming templates
- **Required For**: Real-time data exchange with GitHub

### 4. Legacy IntegrationHub Usage Dashboard
- **Plugin ID**: `com.glide.hub.usage.dashboard`
- **Purpose**: Usage tracking and monitoring
- **Required For**: Monitoring integration health

---

## How to Verify Plugin Installation

### Method 1: Via ServiceNow UI

1. **Navigate to**:
   ```
   All → System Applications → Plugins
   ```

2. **Search for**: `IntegrationHub`

3. **Check if these are installed**:
   - ServiceNow IntegrationHub Runtime
   - IntegrationHub Action Step - REST
   - IntegrationHub Action Template - Data Stream
   - Legacy IntegrationHub Usage Dashboard

4. **Look for**: Green checkmark = Installed, Red X = Not installed

### Method 2: Via ServiceNow Navigator

1. **Filter Navigator**: Type `plugins`
2. Click: **Plugins**
3. **Search**: `integration hub`
4. **Check**: Active column shows "true" for all

### Method 3: Via REST API (if permitted)

```bash
# Check installed plugins
curl -u "username:password" \
  "https://YOUR_INSTANCE.service-now.com/api/now/table/sys_plugins?sysparm_query=idLIKEglide.hub&sysparm_fields=id,name,active,version" \
  | jq .
```

---

## What Happens If Plugins Are Missing?

### Symptoms:
- ✅ GitHub Action starts
- ✅ Shows "Calling Change Control API to create change...."
- ❌ Returns "Internal server error"
- ❌ No change request number returned
- ❌ No change created in ServiceNow

### Why:
- ServiceNow DevOps Change API **depends on IntegrationHub**
- Without IntegrationHub, the API calls fail silently
- GitHub Actions don't get proper error messages

---

## Solution Options

### Option 1: Install Required Plugins (Recommended for Production)

**Steps**:
1. Contact your ServiceNow administrator
2. Request installation of IntegrationHub plugins
3. List the 4 required plugins above
4. Installation requires admin privileges
5. May require instance restart

**Benefits**:
- ✅ Full DevOps Change API functionality
- ✅ Changes visible in DevOps Change workspace
- ✅ DORA metrics enabled
- ✅ Real-time pipeline tracking

**Time**: 1-2 hours (admin task + restart)

### Option 2: Use Hybrid Workflow (Current Workaround)

**Use**: `deploy-with-servicenow-hybrid.yaml`

**Why It Works**:
- Uses basic REST API (doesn't require IntegrationHub)
- Proven to work in your environment
- Includes DevOps correlation fields
- Full approval workflow support

**Limitations**:
- ❌ Changes may not appear in DevOps Change workspace
- ❌ No automatic DORA metrics
- ❌ No real-time pipeline tracking

**Benefits**:
- ✅ Works immediately (no plugin installation)
- ✅ Creates changes successfully
- ✅ All deployment features work
- ✅ Production-ready

---

## Verification Checklist

Before attempting to use ServiceNow DevOps Change GitHub Actions again, verify:

### Prerequisites:
- [ ] ServiceNow instance is **Xanadu Patch 5** or later
- [ ] **DevOps Change Velocity** plugin installed (v6.1.0) ✅ CONFIRMED
- [ ] **IntegrationHub Runtime** plugin installed ⚠️ NOT VERIFIED
- [ ] **IntegrationHub REST Action** plugin installed ⚠️ NOT VERIFIED
- [ ] **IntegrationHub Data Stream** plugin installed ⚠️ NOT VERIFIED
- [ ] **IntegrationHub Usage Dashboard** plugin installed ⚠️ NOT VERIFIED

### Configuration:
- [ ] GitHub tool created in ServiceNow ✅ CONFIRMED (GitHubARC)
- [ ] OAuth 2.0 configured ✅ CONFIRMED
- [ ] Integration token generated ✅ CONFIRMED
- [ ] Token added to GitHub secrets ✅ CONFIRMED

### Workflow:
- [ ] `job-name` matches job's `name` field ✅ CONFIRMED
- [ ] `tool-id` matches GitHub tool sys_id ✅ CONFIRMED
- [ ] `context-github` includes toJSON(github) ✅ CONFIRMED

---

## Testing After Plugin Installation

Once IntegrationHub plugins are installed:

### 1. Verify Plugin Status

```bash
# Check via API
curl -u "username:password" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_plugins?sysparm_query=idLIKEglide.hub^active=true&sysparm_fields=id,name"
```

Expected: All 4 plugins show as active

### 2. Test DevOps Change API

```bash
# Test workflow
gh workflow run deploy-with-servicenow-devops.yaml --field environment=dev
```

Expected results:
- ✅ No "Internal server error"
- ✅ Change request number returned
- ✅ Change visible in ServiceNow
- ✅ Change visible in DevOps Change workspace

### 3. Verify Workspace Integration

1. Go to: https://calitiiltddemo3.service-now.com/now/devops-change/home
2. Click: **Pipelines** tab
3. Should see: "Deploy with ServiceNow DevOps Change"
4. Click: **Changes** tab
5. Should see: Change request linked to GitHub run

---

## Comparison: With vs Without IntegrationHub

| Feature | Without IntegrationHub | With IntegrationHub |
|---------|----------------------|-------------------|
| **REST API** | ✅ Works | ✅ Works |
| **DevOps Change API** | ❌ Fails | ✅ Works |
| **Change Creation** | ✅ Via REST | ✅ Via DevOps API |
| **Workspace Visibility** | ❌ Limited | ✅ Full visibility |
| **Pipeline Tracking** | ❌ No | ✅ Real-time |
| **DORA Metrics** | ❌ Manual | ✅ Automatic |
| **Approval Workflow** | ✅ Works | ✅ Works |
| **Deployment** | ✅ Works | ✅ Works |

---

## Current Status

### What Works Now:
- ✅ REST API change creation (`deploy-with-servicenow-basic.yaml`)
- ✅ Hybrid workflow with correlation (`deploy-with-servicenow-hybrid.yaml`)
- ✅ Full deployment pipeline
- ✅ Approval workflows (dev/qa/prod)
- ✅ Rollback on failure

### What Doesn't Work:
- ❌ ServiceNow DevOps Change GitHub Actions
- ❌ DevOps Change workspace integration
- ❌ Automatic DORA metrics
- ❌ Real-time pipeline tracking

### Why:
- ⚠️ **IntegrationHub plugins likely not installed**

---

## Recommended Actions

### Immediate (Today):
1. ✅ Use `deploy-with-servicenow-hybrid.yaml` for deployments
2. ✅ Continue with existing workflows
3. ✅ All features work except workspace integration

### Short-term (This Week):
1. Check if IntegrationHub plugins are installed
2. If missing, request installation from ServiceNow admin
3. Test DevOps Change API after installation

### Long-term (This Month):
1. Once plugins installed, migrate to DevOps Change API
2. Enable DORA metrics dashboards
3. Use DevOps Change workspace for visibility

---

## Support Resources

### ServiceNow Documentation:
- **IntegrationHub**: https://docs.servicenow.com/bundle/zurich-platform-integrations/page/product/integration-hub/reference/integrationhub-landing-page.html
- **DevOps Change**: https://docs.servicenow.com/bundle/zurich-it-service-management/page/product/enterprise-dev-ops/concept/github-actions-integration-with-devops.html

### Plugin Installation:
- **ServiceNow Store**: https://store.servicenow.com/
- **Admin Guide**: System Applications → Plugins → Find IntegrationHub plugins

### Community:
- **DevOps Forum**: https://www.servicenow.com/community/devops-change-velocity/ct-p/DevOps

---

## Summary

**Root Cause**: ServiceNow DevOps Change API requires IntegrationHub plugins that may not be installed.

**Current Workaround**: Use `deploy-with-servicenow-hybrid.yaml` (REST API-based) - works perfectly!

**Long-term Solution**: Install IntegrationHub plugins, then retry `deploy-with-servicenow-devops.yaml`.

**Impact**: Low - all deployment features work with hybrid workflow. DevOps workspace integration is nice-to-have, not required.

---

**Last Updated**: 2025-10-17
**Status**: Awaiting IntegrationHub plugin verification
**Workaround**: deploy-with-servicenow-hybrid.yaml ✅ WORKING
