# ServiceNow Integration - Complete Guide

> **Status**: ✅ Working
> **Last Updated**: 2025-10-27
> **Version**: 1.0.0

## Overview

This project includes **full ServiceNow Change Management integration** via REST API. Every deployment automatically creates a properly formatted Change Request with comprehensive ITIL fields and complete GitHub traceability.

## Architecture

### Integration Method

**REST API** (not ServiceNow DevOps GitHub Action)
- **Why**: DevOps API returns HTTP 422 errors
- **Endpoint**: `/api/now/table/change_request`
- **Auth**: Basic Authentication (username/password)
- **Proven**: Successfully created multiple test change requests

### Workflow Integration

**File**: `.github/workflows/servicenow-change-rest.yaml`

**Called By**: `MASTER-PIPELINE.yaml` → `servicenow-change` job

**When**: After security scans, before deployment

**Sequence**:
1. Security Scans Complete
2. Build & Push Images
3. Upload Test Results
4. Register Packages
5. **→ Create ServiceNow Change Request** ✅
6. Deploy to Environment
7. Upload Config Validation

## Change Request Fields

### Standard ITIL Fields

| Field | Value | Notes |
|-------|-------|-------|
| **short_description** | "Deploy microservices to {env} (Kubernetes) [{env}]" | From workflow input |
| **description** | Full deployment details + GitHub context | Multi-line with metadata |
| **type** | "standard" | Standard change type |
| **state** | "implement" (dev) / "assess" (qa/prod) | Auto-approved for dev |
| **priority** | "2" (prod) / "3" (dev/qa) | Higher for production |
| **assignment_group** | "DevOps Engineering" | Configurable |
| **category** | "DevOps" | For filtering/reporting |
| **subcategory** | "Deployment" | Specific classification |
| **risk** | "2" (prod) / "3" (dev/qa) | Medium/Low risk |
| **impact** | "2" (prod) / "3" (dev/qa) | Medium/Low impact |
| **urgency** | "3" | Low urgency (planned) |
| **justification** | CI/CD pipeline, tested, PR approved | Why change is needed |
| **cab_required** | true (prod) / false (dev/qa) | CAB approval for prod |
| **production_system** | true (prod) / false (dev/qa) | Production flag |
| **outside_maintenance_schedule** | false | Within normal windows |

### Deployment Plans (5 Steps Each)

**implementation_plan**:
```
1. Configure kubectl access to EKS cluster
2. Apply Kustomize overlays
3. Monitor rollout status
4. Verify all pods healthy
5. Test application endpoints
```

**backout_plan**:
```
1. Execute kubectl rollout undo
2. Verify rollback completed
3. Monitor pod status
4. Test application functionality
5. Notify stakeholders
```

**test_plan**:
```
1. Verify deployments rolled out
2. Check all pods Running
3. Verify service endpoints
4. Test frontend accessibility
5. Monitor application metrics
```

### GitHub Traceability Fields

| Field | Example Value | Purpose |
|-------|---------------|---------|
| **u_source** | "GitHub Actions" | Integration source |
| **u_environment** | "dev" / "qa" / "prod" | Target environment |
| **u_change_type** | "kubernetes" | Type of deployment |
| **u_github_repo** | "Freundcloud/microservices-demo" | Repository name |
| **u_github_workflow** | "🚀 Master CI/CD Pipeline" | Workflow name |
| **u_github_run_id** | "18851642020" | **Click to view run** |
| **u_github_actor** | "olafkfreund" | Who triggered |
| **u_github_ref** | "refs/heads/main" | Branch/tag |
| **u_github_sha** | "d3c9ba74..." | Commit SHA |

### Complete Audit Trail

Every change request includes:
- ✅ Who triggered the deployment
- ✅ What was deployed (commit SHA)
- ✅ When it was deployed (timestamp)
- ✅ Which workflow ran (with direct link)
- ✅ Complete deployment plans
- ✅ Risk assessment
- ✅ Impact analysis

## Approval Workflow

### DEV Environment
- **State**: "implement" (auto-approved)
- **Deployment**: Proceeds immediately after CR creation
- **Rationale**: Dev environment, low risk

### QA Environment
- **State**: "assess" (awaiting approval)
- **Workflow**: Polls ServiceNow every 60 seconds
- **Timeout**: 1 hour
- **Deployment**: Proceeds after approval

### PROD Environment
- **State**: "assess" (awaiting approval)
- **CAB Required**: true
- **Priority**: 2 (High)
- **Workflow**: Polls ServiceNow every 60 seconds
- **Timeout**: 1 hour
- **Deployment**: Proceeds after approval

## Technical Implementation

### JSON Payload Construction

**Method**: `jq -n` (programmatic JSON builder)

**Why jq**:
- ✅ Guarantees valid JSON
- ✅ Proper escaping of special characters
- ✅ Handles newlines correctly
- ✅ Boolean values properly formatted
- ✅ No syntax errors

**Code Structure**:
```yaml
- name: Create Change Request via REST API
  env:
    SHORT_DESC: ${{ inputs.short_description }}
    DESCRIPTION: ${{ inputs.description }}
    # ... all GitHub Actions values
  run: |
    # Build JSON using jq
    PAYLOAD=$(jq -n \
      --arg short_desc "$SHORT_DESC" \
      --arg description "$DESCRIPTION" \
      --argjson cab_required "$CAB_REQUIRED" \
      '{
        short_description: $short_desc,
        description: $description,
        cab_required: $cab_required,
        # ... all fields
      }'
    )

    # POST to ServiceNow
    curl -X POST \
      -u "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request"
```

### Error Handling

**Dev Environment**:
- `continue-on-error: true`
- Deployment proceeds even if CR creation fails
- Error logged but doesn't block pipeline

**QA/Prod Environment**:
- CR creation failure stops deployment
- Requires successful CR creation to proceed
- Approval timeout causes deployment failure

## Secrets Configuration

Required GitHub Secrets:

| Secret | Example | Purpose |
|--------|---------|---------|
| `SERVICENOW_INSTANCE_URL` | https://instance.service-now.com | ServiceNow URL |
| `SERVICENOW_USERNAME` | github_integration | API username |
| `SERVICENOW_PASSWORD` | ••••••••••• | API password |

**Not Required** (DevOps plugin not used):
- ~~`SN_DEVOPS_TOKEN`~~
- ~~`SN_ORCHESTRATION_TOOL_ID`~~

## Testing the Integration

### Manual Test

Run the test script to verify API connectivity:

```bash
./scripts/test-servicenow-change-api.sh
```

**Expected Output**:
```
✅ Connection successful (HTTP 200)
✅ Change Request Created Successfully!

   Change Number: CHG0030XXX
   Sys ID: ...
   🔗 View in ServiceNow: https://...
```

### CI/CD Test

Trigger a deployment:

```bash
# Manual workflow trigger
gh workflow run MASTER-PIPELINE.yaml -f environment=dev

# Or automated promotion
just promote 1.2.0 all
```

### Verify in ServiceNow

1. Navigate to: **Change** → **All**
2. Filter by: `Source = "GitHub Actions"`
3. Or search: `CHG00301XX`

## Success Criteria

✅ **Change Request Created**:
- HTTP 201 response
- Change Number returned (CHG00301XX)
- Visible in ServiceNow

✅ **All Fields Populated**:
- Category: DevOps > Deployment
- Risk/Impact: Appropriate for environment
- Plans: 5 steps each
- GitHub context: All fields present

✅ **Approval Workflow**:
- DEV: Auto-approved (state = implement)
- QA/PROD: Awaiting approval (state = assess)

✅ **Deployment Proceeds**:
- After CR creation (dev)
- After approval (qa/prod)

## Troubleshooting

### Change Request Creation Fails (HTTP 400)

**Symptom**: "The payload is not valid JSON"

**Cause**: JSON syntax error in payload

**Fix**: Check jq command, verify all `--arg` parameters

**Diagnostic**:
```bash
# Test JSON generation locally
jq -n --arg test "value" '{field: $test}'
```

### Change Request Creation Fails (HTTP 401)

**Symptom**: "Authentication failed"

**Cause**: Invalid credentials

**Fix**:
1. Verify secrets: `gh secret list --repo owner/repo`
2. Test locally: `./scripts/test-servicenow-change-api.sh`

### Change Request Creation Fails (HTTP 422)

**Symptom**: "Required field missing"

**Cause**: ServiceNow field validation

**Fix**: Check ServiceNow field requirements:
```bash
./scripts/get-change-request-fields.sh
```

### Approval Timeout

**Symptom**: Workflow times out after 1 hour

**Cause**: Change request not approved in ServiceNow

**Fix**:
1. Find CR in ServiceNow
2. Approve manually
3. Re-run workflow deployment step

## Benefits

### For DevOps Teams
- ✅ Fully automated change management
- ✅ No manual CR creation
- ✅ Complete GitHub integration
- ✅ End-to-end traceability

### For Security Teams
- ✅ Complete audit trail
- ✅ SBOM + vulnerability data
- ✅ Risk assessment per deployment
- ✅ Compliance evidence

### For Approvers
- ✅ Risk-based decision making
- ✅ Complete deployment context
- ✅ Direct link to GitHub workflow
- ✅ Clear implementation/backout plans

### For Compliance
- ✅ SOC 2 / ISO 27001 ready
- ✅ Complete change history
- ✅ Approval workflow enforced
- ✅ Searchable audit trail

## Related Documentation

- [MASTER-PIPELINE.yaml](.github/workflows/MASTER-PIPELINE.yaml) - Main workflow
- [servicenow-change-rest.yaml](.github/workflows/servicenow-change-rest.yaml) - CR creation workflow
- [test-servicenow-change-api.sh](scripts/test-servicenow-change-api.sh) - Test script
- [SERVICENOW-CUSTOM-FIELDS-SETUP.md](SERVICENOW-CUSTOM-FIELDS-SETUP.md) - Custom fields guide

## Future Enhancements

### Possible Improvements

1. **ServiceNow DevOps Plugin**
   - Install and configure DevOps plugin
   - Switch to GitHub Action for advanced features
   - Enables change velocity tracking

2. **CMDB Integration**
   - Link change requests to Configuration Items
   - Auto-populate affected CIs
   - Service dependency mapping

3. **Automated Testing Evidence**
   - Attach test results to CR
   - Include coverage reports
   - Link to test execution logs

4. **Risk Scoring**
   - Calculate risk based on metrics
   - Change frequency analysis
   - Blast radius estimation

5. **Rollback Automation**
   - Automatic rollback on failure
   - Update CR with rollback status
   - Notification to stakeholders

---

**Last Verified**: 2025-10-27
**Status**: ✅ Production Ready
**Maintainer**: DevOps Team
