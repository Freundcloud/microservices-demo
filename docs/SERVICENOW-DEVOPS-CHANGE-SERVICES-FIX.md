# ServiceNow DevOps Change - Services Association & Visibility Fix

## Problem Statement

**Issue 1**: No services associated with the "Online Boutique" DevOps application
**Issue 2**: Change requests not appearing in ServiceNow Velocity DevOps Change workspace

## Solution Overview

This document explains how to:
1. Associate CMDB services with your DevOps application
2. Ensure change requests appear in the DevOps Change workspace
3. Configure proper integration between GitHub Actions and ServiceNow DevOps

---

## Part 1: Associate Services with DevOps Application

### Background

ServiceNow DevOps Change workspace requires proper relationships between:
- **DevOps Application** (`sn_devops_app`) ← What GitHub Actions interact with
- **Business Application** (`cmdb_ci_business_app`) ← CMDB asset representing your app
- **Services** (`cmdb_ci_service`) ← Individual services/components of your app

The relationship chain:
```
DevOps App (sn_devops_app)
  └── business_app → Business App (cmdb_ci_business_app)
                        └── Services (cmdb_ci_service) [via cmdb_rel_ci + svc_ci_assoc]
```

### Key Tables

| Table | Purpose |
|-------|---------|
| `sn_devops_app` | DevOps application record (linked to GitHub tool) |
| `cmdb_ci_business_app` | CMDB business application |
| `cmdb_ci_service` | Individual services/components |
| `cmdb_rel_ci` | CI-to-CI relationships (parent-child) |
| `svc_ci_assoc` | Service-CI associations (for Change Management) |

### Your Configuration

**DevOps Application**:
- **Name**: Online Boutique
- **Sys ID**: `6047e45ac3e4f690e1bbf0cb05013120`
- **URL**: https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120

**Business Application**:
- **Name**: Online Boutique
- **Sys ID**: `4ffc7bfec3a4fe90e1bbf0cb0501313f`
- **Number**: APM0001011

**Services**:
1. **Service 1**: Online Boutique (BSN0001005) - `1e7b938bc360b2d0e1bbf0cb050131da`
2. **Service 2**: Online Boutique (BSN0001006) - `3e1c530fc360b2d0e1bbf0cb05013185`

### Solution: Automated Script

Run the automated script to create all necessary relationships:

```bash
./scripts/servicenow-associate-services.sh
```

This script:
1. ✅ Verifies DevOps application exists
2. ✅ Verifies CMDB services exist
3. ✅ Creates `cmdb_rel_ci` relationships (Business App → Services)
4. ✅ Creates `svc_ci_assoc` records (for Change Management integration)
5. ✅ Verifies relationships were created successfully

### Manual Verification

After running the script, verify in ServiceNow UI:

1. **Navigate to DevOps Application**:
   - https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_app/6047e45ac3e4f690e1bbf0cb05013120

2. **Check Business Application**:
   - Click on "Business App" link → Should show "Online Boutique (APM0001011)"
   - Navigate to Business App record
   - Check "Related Lists" → "Services" should show 2 services

3. **Verify Relationships via API**:
   ```bash
   # Check CMDB relationships
   curl -s --user 'github_integration:PASSWORD' \
     "https://calitiiltddemo3.service-now.com/api/now/table/cmdb_rel_ci?sysparm_query=parent=4ffc7bfec3a4fe90e1bbf0cb0501313f" \
     | jq '.result | length'
   # Should return: 2

   # Check Service CI Associations
   curl -s --user 'github_integration:PASSWORD' \
     "https://calitiiltddemo3.service-now.com/api/now/table/svc_ci_assoc?sysparm_query=ci_id=4ffc7bfec3a4fe90e1bbf0cb0501313f" \
     | jq '.result | length'
   # Should return: 1 or more
   ```

---

## Part 2: Fix Change Requests Not Appearing in DevOps Change Workspace

### Root Cause Analysis

Change requests don't appear in the DevOps Change workspace (`/now/devops-change/changes/`) because they're missing **one or more** of these required fields:

| Required Field | Current Status | Fix Needed |
|----------------|----------------|------------|
| `category` = "DevOps" | ✅ Set in workflow | No change |
| `devops_change` = true | ✅ Set in workflow | No change |
| `u_tool_id` | ✅ Set in workflow | No change |
| `business_service` | ❌ **MISSING** | **ADD THIS** |

### The Missing Link: business_service Field

When creating change requests via REST API, you must include a `business_service` field that links to one of your CMDB services. This is what makes the change request appear in the DevOps Change workspace.

### Updated GitHub Actions Workflow

Modify `.github/workflows/servicenow-integration.yaml` to include `business_service`:

#### Current Code (Line 128-145):
```yaml
- name: Create ServiceNow Change Request
  id: create_change
  run: |
    CHANGE_PAYLOAD=$(cat <<'EOF'
    {
      "category": "DevOps",
      "devops_change": true,
      "type": "normal",
      "chg_model": "adffaa9e4370211072b7f6be5bb8f2ed",
      "short_description": "Deploy Online Boutique microservices to AWS EKS (dev)",
      "description": "Automated deployment from GitHub Actions...",
      "u_tool_id": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}",
      "u_github_repo": "${{ env.REPO_NAME }}",
      "u_github_commit": "${{ github.sha }}"
    }
    EOF
    )
```

#### Updated Code (with business_service):
```yaml
- name: Create ServiceNow Change Request
  id: create_change
  run: |
    CHANGE_PAYLOAD=$(cat <<'EOF'
    {
      "category": "DevOps",
      "devops_change": true,
      "type": "normal",
      "chg_model": "adffaa9e4370211072b7f6be5bb8f2ed",
      "business_service": "1e7b938bc360b2d0e1bbf0cb050131da",
      "short_description": "Deploy Online Boutique microservices to AWS EKS (dev)",
      "description": "Automated deployment from GitHub Actions...",
      "u_tool_id": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}",
      "u_github_repo": "${{ env.REPO_NAME }}",
      "u_github_commit": "${{ github.sha }}"
    }
    EOF
    )
```

**Key Addition**: `"business_service": "1e7b938bc360b2d0e1bbf0cb050131da"`

This links the change request to Service 1 (Online Boutique - BSN0001005).

### Alternative: Use cmdb_ci Field

If `business_service` doesn't work, try using `cmdb_ci` field instead:

```json
{
  "category": "DevOps",
  "devops_change": true,
  "cmdb_ci": "4ffc7bfec3a4fe90e1bbf0cb0501313f",
  "business_service": "1e7b938bc360b2d0e1bbf0cb050131da",
  ...
}
```

### Testing the Fix

1. **Update the workflow** with the `business_service` field
2. **Commit and push** the changes
3. **Trigger a deployment** workflow
4. **Check ServiceNow**:
   - Navigate to: https://calitiiltddemo3.service-now.com/now/devops-change/changes/
   - The new change request should now appear in the list!

### Verification Query

Check if change requests are properly linked to services:

```bash
curl -s --user 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request?sysparm_query=category=DevOps^devops_change=true&sysparm_fields=number,business_service,cmdb_ci&sysparm_limit=5" \
  | jq '.result[] | {number, business_service: .business_service.value, cmdb_ci: .cmdb_ci.value}'
```

Expected output:
```json
{
  "number": "CHG0030052",
  "business_service": "1e7b938bc360b2d0e1bbf0cb050131da",
  "cmdb_ci": null
}
```

---

## Part 3: Complete GitHub Actions Integration

### Required GitHub Secrets

Ensure these secrets are configured in your GitHub repository:

```bash
gh secret set SERVICENOW_USERNAME --body "github_integration"
gh secret set SERVICENOW_PASSWORD --body "YOUR_PASSWORD"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "4c5e482cc3383214e1bbf0cb05013196"
```

### ServiceNow DevOps Tool Configuration

Your GitHub tool in ServiceNow:
- **Tool ID**: `4c5e482cc3383214e1bbf0cb05013196`
- **URL**: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_tool.do%3Fsys_id%3D4c5e482cc3383214e1bbf0cb05013196

Verify tool is active:
```bash
curl -s --user 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool/4c5e482cc3383214e1bbf0cb05013196" \
  | jq '{name: .result.name, active: .result.active, type: .result.type}'
```

---

## Summary Checklist

- [ ] **Services Associated**: Run `./scripts/servicenow-associate-services.sh`
- [ ] **Verify Relationships**: Check Business App → Services in ServiceNow UI
- [ ] **Update Workflow**: Add `business_service` field to change request payload
- [ ] **Test Deployment**: Trigger workflow and verify change appears in DevOps Change workspace
- [ ] **Check Webhooks**: Ensure webhooks are active and delivering

---

## Troubleshooting

### Issue: Services still not showing in DevOps Change workspace

**Check**:
1. Business App has services linked (cmdb_rel_ci + svc_ci_assoc)
2. Change request has `business_service` field populated
3. Service is active (`operational_status = 1`)

**Query**:
```bash
# Check if service is linked to change request
curl -s --user 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/CHG_NUMBER" \
  | jq '{business_service: .result.business_service, cmdb_ci: .result.cmdb_ci}'
```

### Issue: Change requests not appearing in DevOps Change workspace

**Verify ALL required fields**:
```bash
curl -s --user 'github_integration:PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/change_request/CHG_NUMBER" \
  | jq '{category: .result.category, devops_change: .result.devops_change, business_service: .result.business_service, u_tool_id: .result.u_tool_id}'
```

Expected output:
```json
{
  "category": "DevOps",
  "devops_change": "true",
  "business_service": "1e7b938bc360b2d0e1bbf0cb050131da",
  "u_tool_id": "4c5e482cc3383214e1bbf0cb05013196"
}
```

### Issue: "Internal server error" when creating change requests

**Root causes**:
1. Invalid `chg_model` sys_id
2. Missing required fields
3. Invalid `business_service` sys_id
4. User permissions

**Solution**: Check ServiceNow system logs:
- Navigate to: All > System Logs > System Log > All
- Filter by: Created = Last 15 minutes
- Look for errors related to change_request table

---

## References

- **ServiceNow CMDB Relationships**: https://docs.servicenow.com/bundle/washingtondc-it-service-management/page/product/configuration-management/concept/c_CMDBRelationships.html
- **Service CI Associations**: https://docs.servicenow.com/bundle/washingtondc-it-service-management/page/product/service-mapping/concept/service-ci-association.html
- **DevOps Change Management**: https://docs.servicenow.com/bundle/washingtondc-devops/page/product/enterprise-dev-ops/concept/devops-change-management.html

---

## Files Modified

1. **Created**: `scripts/servicenow-associate-services.sh` - Automated service association script
2. **To Update**: `.github/workflows/servicenow-integration.yaml` - Add `business_service` field to change request payload

## Next Steps

1. ✅ Run service association script: `./scripts/servicenow-associate-services.sh`
2. ⏳ Update workflow with `business_service` field
3. ⏳ Test deployment to verify change appears in DevOps Change workspace
4. ⏳ Document any additional customizations needed

---

**Last Updated**: 2025-10-22
**Author**: Claude Code (with user requirements)
**Status**: Services associated ✅ | Workflow update pending ⏳
