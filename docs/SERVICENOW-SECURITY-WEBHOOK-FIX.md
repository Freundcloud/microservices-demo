# ServiceNow Security Webhook Authentication Fix

**Issue**: Webhook delivering 401 Unauthorized to `/softwarequality` endpoint
**Status**: Requires ServiceNow Configuration
**Date**: 2025-10-21

## Problem Summary

GitHub webhook ID `576481667` is successfully sending `code_scanning_alert` events to ServiceNow, but receiving **401 Unauthorized** responses:

```json
{
  "delivered_at": "2025-10-21T11:46:15Z",
  "event": "code_scanning_alert",
  "status": 401
}
```

## Root Cause

The ServiceNow `/softwarequality` endpoint **requires authentication** (Basic Auth), but GitHub webhooks **cannot send custom authentication headers**.

**Test Results**:
- ❌ Without Auth: `HTTP 401 Unauthorized`
- ✅ With Basic Auth: `HTTP 201 Created`

```bash
# Without authentication
curl -X POST "https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/softwarequality?toolId=..."
# Returns: 401 Unauthorized

# With Basic Authentication
curl -X POST -H "Authorization: Basic <credentials>" "https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/softwarequality?toolId=..."
# Returns: 201 Created
```

## Why Other Webhooks Work

Other ServiceNow DevOps endpoints **don't require authentication**:
- ✅ `/code` - Works without auth
- ✅ `/plan` - Works without auth
- ✅ `/orchestration` - Works without auth
- ❌ `/softwarequality` - **Requires auth** (different security setting)

## Solution Options

### Option 1: Configure ServiceNow GitHub Tool (RECOMMENDED)

**Steps for ServiceNow Admin**:

1. Navigate to **DevOps** → **Change** → **Tools**
2. Find and click on **GitHub Demo** tool
3. Click the **Edit** or **Configure** button (three-dot menu)
4. Look for webhook or API authentication settings
5. Check if there's an option to:
   - Allow unauthenticated webhook requests for security events
   - Configure token-based authentication for webhooks
   - Enable GitHub signature verification (instead of Basic Auth)

**Note**: The exact UI options depend on your ServiceNow DevOps plugin version. The goal is to configure the tool to accept GitHub webhook payloads for the `/softwarequality` endpoint without requiring Basic Authentication headers.

### Option 2: Use ServiceNow GitHub App Integration (PREFERRED)

Instead of manual webhooks, use ServiceNow's native GitHub App:

1. **In ServiceNow**:
   - Navigate to **DevOps** → **Change** → **Tools** → **GitHub Demo**
   - Click **Reconfigure** or **Setup GitHub App**
   - Follow wizard to install GitHub App

2. **In GitHub**:
   - Organization Settings → GitHub Apps
   - Install ServiceNow DevOps app
   - Grant permissions for Security events

3. **Benefits**:
   - ✅ Handles authentication automatically
   - ✅ Supports all event types including security
   - ✅ Better security (GitHub App tokens vs webhooks)
   - ✅ Automatic configuration

### Option 3: Contact ServiceNow Support

If Options 1 and 2 don't reveal configuration options in the UI:

1. **Open ServiceNow Support Case**:
   - Product: ServiceNow DevOps (Velocity)
   - Issue: Need to configure `/softwarequality` endpoint to accept GitHub webhooks
   - Details: Endpoint returns 401 for webhook events, needs to accept GitHub webhook signature auth

2. **Potential ServiceNow Configuration**:
   - They may need to modify ACL rules for the endpoint
   - Configure the endpoint to use GitHub webhook secret verification instead of Basic Auth
   - Add your GitHub webhook IP ranges to allowlist

3. **Documentation to Reference**:
   - [ServiceNow DevOps API Documentation](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/r-devops-api.html)
   - GitHub webhook signature verification: https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries

## Temporary Workaround

Until ServiceNow configuration is updated, security scan results can be manually reviewed in:

1. **GitHub Security Tab**:
   - Navigate to: https://github.com/Freundcloud/microservices-demo/security
   - View **Code scanning** alerts
   - All 7 tools upload SARIF results here

2. **GitHub Actions Workflow Results**:
   - Each security scan job shows detailed results
   - SARIF files available as artifacts

3. **Manual ServiceNow Update**:
   - Use `scripts/register-servicenow-security-tools.sh`
   - Sends authenticated API requests
   - Populates Security tab manually

## Current Webhook Configuration

**Webhook ID**: `576481667`
**URL**: `https://calitiiltddemo3.service-now.com/api/sn_devops/v2/devops/tool/softwarequality?toolId=2fe9c38bc36c72d0e1bbf0cb050131cc`
**Events**:
- `code_scanning_alert`
- `dependabot_alert`
- `secret_scanning_alert`
- `secret_scanning_alert_location`

**Status**: Active but failing auth ⚠️

## Verification After Fix

Once ServiceNow is configured to accept webhooks:

```bash
# 1. Trigger security scan
gh workflow run MASTER-PIPELINE.yaml

# 2. Check webhook deliveries (should show 200/201)
gh api repos/Freundcloud/microservices-demo/hooks/576481667/deliveries \
  --jq '.[0] | {event: .event, status: .status_code, delivered_at: .delivered_at}'

# Expected output:
{
  "event": "code_scanning_alert",
  "status": 200,  # or 201
  "delivered_at": "2025-10-21T12:00:00Z"
}

# 3. Verify in ServiceNow Security tab
# Navigate to: DevOps → Change → Tools → GitHub Demo → Security tab
# Should show security scan results
```

## Next Steps

**Immediate Action Required**:
1. Contact ServiceNow Administrator
2. Request configuration change for `/softwarequality` endpoint
3. Choose Option 1 (configure endpoint) or Option 2 (use GitHub App)

**After ServiceNow Configuration**:
1. No code changes needed - webhook already configured
2. Security events will automatically flow to ServiceNow
3. Security tab will populate with scan results

## Additional Resources

- **ServiceNow API Docs**: [DevOps REST API](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/r-devops-api.html)
- **GitHub Webhooks**: [Webhook Events](https://docs.github.com/en/webhooks/webhook-events-and-payloads)
- **Security Integration Guide**: `docs/SERVICENOW-SECURITY-INTEGRATION.md`

## Contact

**ServiceNow Instance**: `calitiiltddemo3.service-now.com`
**ServiceNow Admin**: Contact your ServiceNow administrator
**GitHub Repository**: https://github.com/Freundcloud/microservices-demo
