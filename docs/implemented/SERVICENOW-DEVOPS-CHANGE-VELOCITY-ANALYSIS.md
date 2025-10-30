# ServiceNow DevOps Change Velocity Analysis

**Last Updated:** 2025-10-28
**Purpose:** Gap analysis between current implementation and ServiceNow DevOps Change Velocity best practices

## Executive Summary

This document analyzes our current GitHub + ServiceNow integration against the official **ServiceNow DevOps Change Velocity** product to identify gaps, improvements, and migration opportunities.

**Current Approach:** Hybrid - Using 3 official ServiceNow DevOps actions + custom REST API for change requests
**ServiceNow Product:** DevOps Change Velocity with official GitHub Actions
**Status:** ✅ **Already 70% integrated!** Using official actions for test results, artifacts, and SonarCloud. Only missing official change action.


### Key Discovery

**We're already using ServiceNow DevOps Change Velocity features!** 🎉

- ✅ **Test Results Upload**: `ServiceNow/servicenow-devops-test-report@v6.0.0`
- ✅ **Artifact Registration**: `ServiceNow/servicenow-devops-register-package@v3.1.0`
- ✅ **SonarCloud Integration**: `ServiceNow/servicenow-devops-sonar@v3.1.0`
- ✅ **Orchestration Tool ID**: `SN_ORCHESTRATION_TOOL_ID` configured
- ⚠️ **Change Requests**: Custom REST API (not using official action)

---

## What is ServiceNow DevOps Change Velocity?

### Product Overview

**ServiceNow DevOps Change Velocity** is a dedicated ServiceNow application (SKU) that:

- Connects DevOps toolchains (GitHub, Azure DevOps, GitLab, Jenkins) to ServiceNow Change Management
- Provides **DORA metrics** (Deployment Frequency, Lead Time, Change Failure Rate, MTTR)
- Automates change request creation with intelligent risk assessment
- Enables **deployment gates** with approval workflows visible in CI/CD console logs
- Collects artifacts, test results, security scans, and work items for comprehensive change evidence
- Provides DevOps Insights dashboards for metrics and flow visualization

### Key Capabilities

1. **Automated Change Requests** - Creates change tickets from pipeline events
2. **Deployment Gates** - Pauses pipeline until change approved, shows status in logs
3. **DORA Metrics** - Industry-standard DevOps performance metrics
4. **Risk Assessment** - AI-powered change risk scoring based on historical data
5. **Work Item Integration** - Links GitHub Issues/PRs to change requests
6. **Test Results Upload** - Attaches test evidence to changes
7. **Artifact Registration** - Tracks what was deployed and where
8. **Security Scan Results** - Compliance evidence from Veracode, Trivy, etc.
9. **Change Velocity Insights** - Dashboards showing approval times, deployment frequency, failure rates
10. **Bidirectional Sync** - Updates between GitHub and ServiceNow in real-time

---

## Our Current Implementation

### What We Have ✅

| Feature | Status | Implementation |
|---------|--------|----------------|
| **Test Results Upload** | ✅ **Official Action** | `ServiceNow/servicenow-devops-test-report@v6.0.0` |
| **Artifact Registration** | ✅ **Official Action** | `ServiceNow/servicenow-devops-register-package@v3.1.0` |
| **SonarCloud Integration** | ✅ **Official Action** | `ServiceNow/servicenow-devops-sonar@v3.1.0` |
| **Orchestration Tool ID** | ✅ **Configured** | `SN_ORCHESTRATION_TOOL_ID` secret exists |
| **Change Request Creation** | ✅ Implemented | Custom REST API with 13 custom fields |
| **Multi-Environment Approvals** | ✅ Implemented | Dev (auto), QA (manual), Prod (CAB) |
| **Custom Fields** | ✅ Implemented | u_source, u_correlation_id, u_repository, u_branch, u_commit_sha, u_actor, u_environment, u_github_run_id, u_github_run_url, u_github_repo_url, u_github_commit_url, u_version, u_deployment_type |
| **Approval Gating** | ✅ Implemented | Polls change state every 60s, timeout 3600s |
| **Basic Auth** | ✅ Implemented | Username/password via GitHub Secrets (SN_DEVOPS_USER/PASSWORD) |
| **State Management** | ✅ Implemented | Auto-approve dev, manual QA/Prod |
| **Risk/Impact Assessment** | ✅ Implemented | Environment-based (dev=3, prod=2) |
| **Implementation/Backout/Test Plans** | ✅ Implemented | Environment-specific defaults |
| **GitHub Context** | ✅ Implemented | All actions pass `toJSON(github)` for traceability |
| **Job Summary** | ✅ Implemented | Markdown summary with links |
| **Error Handling** | ✅ Implemented | Continue on dev failure, block QA/Prod |
| **Quality Gates** | ✅ Implemented | Tests blocking for prod, non-blocking for dev/qa |

### What We're Missing ❌ (Smaller Gap Than Expected!)

| Feature | Status | Gap |
|---------|--------|-----|
| **Official Change Action** | ⚠️ Not Using | Using custom REST API instead of `ServiceNow/servicenow-devops-change@v6` for change requests only |
| **Token-Based Auth** | ⚠️ Partial | Using Basic Auth (valid, but token is more secure and recommended) |
| **DORA Metrics** | ❌ Not Visible | Data collected but dashboards not enabled (may require Change Velocity license) |
| **Work Item Integration** | ❌ Not Implemented | GitHub Issues not explicitly linked to change requests |
| **Security Scan Upload** | ❌ Not Implemented | Trivy/CodeQL/Semgrep results not uploaded via official action (only SonarCloud) |
| **Deployment Gates in Logs** | ⚠️ Basic | Polling shows state but not rich details (approvers, planned window) |
| **Change Velocity Dashboards** | ❌ Not Available | May require ServiceNow DevOps Change Velocity license activation |
| **AI-Powered Risk Scoring** | ❌ Not Available | Manual environment-based risk assignment |
| **Automatic Change Closure** | ❌ Not Implemented | Changes not auto-closed after deployment completion |
| **Commit Tracking** | ⚠️ Partial | Commit SHA in custom fields, but not in sn_devops tables |
| **Pipeline Visualization** | ❌ Not Available | No end-to-end pipeline view in ServiceNow (may require license) |

---

## Detailed Gap Analysis

### 1. Authentication & Tool Registration

#### Current State
```yaml
# Using Basic Authentication
env:
  SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
  SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
  SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}

# Direct REST API call
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request"
```

#### ServiceNow DevOps Change Velocity Approach
```yaml
# Token-based authentication (v4.0.0+)
env:
  SN_DEVOPS_INTEGRATION_TOKEN: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  SN_INSTANCE_URL: ${{ secrets.SN_INSTANCE_URL }}
  SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

# Official GitHub Action
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v6.1.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Deploy to Production'
    change-request: |
      {
        "short_description": "Deploy microservices to prod",
        "description": "Automated deployment",
        "assignment_group": "DevOps Team",
        "implementation_plan": "Deploy via GitHub Actions",
        "backout_plan": "Rollback to previous version",
        "test_plan": "Automated tests + smoke tests"
      }
```

**Gap:**
- ❌ **No orchestration tool registered in ServiceNow** (missing `SN_ORCHESTRATION_TOOL_ID`)
- ❌ **Not using token-based authentication** (Basic Auth is less secure)
- ❌ **Not using official GitHub Action** (custom implementation)

**Impact:**
- Cannot leverage Change Velocity features (DORA metrics, insights, deployment gates)
- Basic Auth credentials are long-lived (token can be rotated/scoped)
- No integration with sn_devops tables (sn_devops_work_item, sn_devops_test_result, sn_devops_artifact)

---

### 2. Test Results Upload ✅


#### Current State (IMPLEMENTED)
```yaml
# We ARE using the official ServiceNow DevOps action!
# Location: .github/workflows/build-images.yaml, run-unit-tests.yaml

- name: Upload Test Results to ServiceNow
  if: steps.find-test-results.outputs.found == 'true'
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Build ${{ matrix.service }}'
    xml-report-filename: ${{ steps.find-test-results.outputs.path }}
  # Quality Gate: Make tests blocking for production
  continue-on-error: ${{ inputs.environment != 'prod' }}
```


**What We Have:**
- ✅ Test results uploaded to ServiceNow from all 12 microservices
- ✅ XML test reports (JUnit format) from unit tests
- ✅ Quality gates: Tests must pass for prod deployments
- ✅ Linked to GitHub context via `toJSON(github)`
- ✅ Job name for traceability


**What Could Be Enhanced:**
- ⚠️ Security scan results (Trivy, CodeQL, Semgrep) not uploaded as test reports
- ⚠️ Integration test results not uploaded (only unit tests)

**Status:** ✅ **Well Implemented** - Using official action correctly


---

### 3. Artifact Registration ✅


#### Current State (IMPLEMENTED)
```yaml
# We ARE using the official ServiceNow DevOps action!
# Location: .github/workflows/build-images.yaml

- name: Register Package with ServiceNow
  if: inputs.push_images
  uses: ServiceNow/servicenow-devops-register-package@v3.1.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Build ${{ matrix.service }}'
    artifacts: '[{"name": "${{ env.ECR_REGISTRY }}/${{ matrix.service }}", "version": "${{ inputs.environment }}-${{ github.sha }}", "semanticVersion": "${{ inputs.environment }}-${{ github.run_number }}", "repositoryName": "${{ github.repository }}"}]'
    package-name: '${{ matrix.service }}-${{ inputs.environment }}-${{ github.run_number }}.package'
  continue-on-error: true
```


**What We Have:**
- ✅ All 12 microservice container images registered in ServiceNow
- ✅ Artifact metadata: name, version, semantic version, repository
- ✅ Package names for tracking deployments
- ✅ Versioning strategy: `{environment}-{commit-sha}` and `{environment}-{run-number}`
- ✅ Stored in `sn_devops_artifact` and `sn_devops_package` tables


**What Could Be Enhanced:**
- ⚠️ SBOM (Software Bill of Materials) not attached to packages
- ⚠️ Container image signatures/provenance not included

**Status:** ✅ **Well Implemented** - Comprehensive artifact tracking


---

### 4. SonarCloud Code Quality Integration ✅


#### Current State (IMPLEMENTED)
```yaml
# We ARE using the official ServiceNow DevOps action!
# Location: .github/workflows/sonarcloud-scan.yaml

- name: Upload SonarCloud Results to ServiceNow
  if: ${{ !inputs.skip_servicenow && !github.event.pull_request }}
  uses: ServiceNow/servicenow-devops-sonar@v3.1.0
  with:
    devops-integration-user-name: ${{ secrets.SN_DEVOPS_USER }}
    devops-integration-user-password: ${{ secrets.SN_DEVOPS_PASSWORD }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'SonarCloud Analysis'
    sonar-host-url: 'https://sonarcloud.io'
    sonar-project-key: 'Freundcloud_microservices-demo'
```


**What We Have:**
- ✅ SonarCloud code quality metrics uploaded to ServiceNow
- ✅ Quality gate status (pass/fail)
- ✅ Code coverage, bugs, vulnerabilities, code smells
- ✅ Linked to GitHub context
- ✅ Stored in `sn_devops_sonar` table


**What Could Be Enhanced:**
- ⚠️ Only runs on non-PR events (could run on PRs for early feedback)

**Status:** ✅ **Well Implemented** - Code quality evidence for approvals


---

### 5. Work Item Integration

#### Current State
```yaml
# ❌ NOT IMPLEMENTED
# GitHub Issues are not explicitly linked to change requests
```

#### ServiceNow DevOps Change Velocity Approach
```yaml
# Work items are automatically extracted from commits and PRs
# Linked to change requests in sn_devops_work_item table
```

**How It Works:**
1. Developer commits code with message: `fix: Resolve cart bug (Fixes #123)`
2. ServiceNow Change Velocity parses commit message
3. Creates record in `sn_devops_work_item` table
4. Links GitHub Issue #123 to change request
5. Displays in ServiceNow UI: "Related Work Items: #123"

**Gap:**
- ❌ **No work item extraction from commits**
- ❌ **No sn_devops_work_item table population**
- ❌ **No GitHub Issue → ServiceNow Change Request linking**

**Impact:**
- Approvers don't see which features/bugs are being deployed
- No traceability from user story to deployment
- Missing compliance evidence (what work was done?)

**Recommendation:**
Implement work item extraction workflow:
```yaml
- name: Extract Work Items from Commits
  run: |
    # Parse commits for issue references (#123, GH-456, etc.)
    git log --pretty=format:"%s" ${{ github.event.before }}..${{ github.sha }} | \
      grep -oP '(#|GH-)?\d+' | sort -u > work_items.txt

- name: Register Work Items
  uses: ServiceNow/servicenow-devops-register-package@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    work-items: ${{ steps.extract.outputs.work_items }}
```

---

### 3. Test Results Upload

#### Current State
```yaml
# ❌ NOT IMPLEMENTED
# Test results from security scans are NOT uploaded to ServiceNow
```

#### ServiceNow DevOps Change Velocity Approach
```yaml
- name: Run Tests
  run: |
    npm test -- --reporter=junit --outputFile=test-results.xml

- name: ServiceNow DevOps Unit Test Results
  uses: ServiceNow/servicenow-devops-unit-test-results@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    test-result-files: |
      test-results.xml
      integration-tests.xml
```

**What Gets Uploaded:**
- Test execution summary (passed/failed/skipped counts)
- Test case details (name, duration, status, error message)
- Links test results to change request
- Stored in `sn_devops_test_result` table
- Displayed on Change Request form as evidence

**Gap:**
- ❌ **No test results uploaded** (unit tests, integration tests, E2E tests)
- ❌ **No sn_devops_test_result table population**
- ❌ **Security scan results not linked to change requests**

**Impact:**
- Approvers can't see test pass/fail evidence
- No automated approval based on test success
- Missing compliance requirement (prove tests ran)
- Security scan results exist in GitHub Security tab, but not in ServiceNow

**Recommendation:**
Upload test results from all test suites:
```yaml
# After security scans complete
- name: Upload Security Scan Results
  uses: ServiceNow/servicenow-devops-unit-test-results@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    test-result-files: |
      trivy-results.json
      codeql-results.sarif
      semgrep-results.json
```

---

### 4. Artifact Registration

#### Current State
```yaml
# ❌ NOT IMPLEMENTED
# Container images built but not registered in ServiceNow
```

#### ServiceNow DevOps Change Velocity Approach
```yaml
- name: Build Container Image
  run: |
    docker build -t $ECR_REGISTRY/frontend:$VERSION .
    docker push $ECR_REGISTRY/frontend:$VERSION

- name: ServiceNow DevOps Register Artifact
  uses: ServiceNow/servicenow-devops-register-artifact@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    artifacts: |
      [
        {
          "name": "frontend",
          "version": "${{ github.sha }}",
          "semanticVersion": "1.2.3",
          "repositoryName": "microservices-demo"
        }
      ]
```

**What Gets Uploaded:**
- Artifact name, version, semantic version
- Repository location
- Build timestamp
- Links to change request
- Stored in `sn_devops_artifact` table
- Enables "what's deployed where" tracking

**Gap:**
- ❌ **No artifact registration** (12 container images not tracked)
- ❌ **No sn_devops_artifact table population**
- ❌ **Can't answer "what version is in prod?"** without checking ECR/K8s

**Impact:**
- No artifact traceability (which image was deployed?)
- Can't correlate failures to specific builds
- Missing compliance evidence (SBOM, provenance)

**Recommendation:**
Register all 12 microservice images:
```yaml
- name: Register Artifacts
  uses: ServiceNow/servicenow-devops-register-artifact@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    artifacts: |
      [
        { "name": "frontend", "version": "${{ env.VERSION }}", "semanticVersion": "${{ env.VERSION }}", "repositoryName": "${{ github.repository }}" },
        { "name": "cartservice", "version": "${{ env.VERSION }}", "semanticVersion": "${{ env.VERSION }}", "repositoryName": "${{ github.repository }}" },
        { "name": "productcatalogservice", "version": "${{ env.VERSION }}", "semanticVersion": "${{ env.VERSION }}", "repositoryName": "${{ github.repository }}" }
      ]
```

---

### 5. DORA Metrics & Change Velocity Insights

#### Current State
```yaml
# ❌ NOT IMPLEMENTED
# No DORA metrics collection
```

#### ServiceNow DevOps Change Velocity Dashboard
- **Deployment Frequency**: How often code is deployed to production
- **Lead Time for Changes**: Time from commit to production deployment
- **Change Failure Rate**: % of deployments causing incidents
- **Mean Time to Recovery (MTTR)**: Time to restore service after failure

**What Change Velocity Provides:**
- Real-time dashboards with trend charts
- Comparison to industry benchmarks (Elite/High/Medium/Low performers)
- Drill-down by environment, team, service
- Automated data collection from GitHub and ServiceNow

**Gap:**
- ❌ **No deployment frequency tracking**
- ❌ **No lead time measurement** (commit → deploy)
- ❌ **No change failure rate calculation**
- ❌ **No MTTR tracking**
- ❌ **No DevOps Insights dashboards**

**Impact:**
- Can't measure DevOps maturity
- No data-driven improvement decisions
- Missing executive visibility into velocity trends

**Recommendation:**
Purchase **ServiceNow DevOps Change Velocity** license to enable DORA metrics.

---

### 6. Deployment Gates & Console Log Updates

#### Current State
```yaml
# Workflow polls ServiceNow every 60 seconds
while [ $ELAPSED -lt $MAX_WAIT ]; do
  RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
    "$INSTANCE_URL/api/now/table/change_request/${CHANGE_SYSID}")
  STATE=$(echo "$RESPONSE" | jq -r '.result.state')
  echo "Current state: $STATE"
  sleep 60
done
```

**Output in GitHub Actions:**
```
Current state: assess, Approval: requested
Waited 60s / 3600s...
Current state: assess, Approval: requested
Waited 120s / 3600s...
```

#### ServiceNow DevOps Change Velocity Approach
```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v6
  with:
    change-request: '{ ... }'
```

**Output in GitHub Actions:**
```
[ServiceNow DevOps] Change Request Created: CHG0030123
[ServiceNow DevOps] Change State: Assess
[ServiceNow DevOps] Assignment Group: CAB
[ServiceNow DevOps] Approvers: John Smith, Jane Doe
[ServiceNow DevOps] Planned Start: 2025-10-29 10:00:00 UTC
[ServiceNow DevOps] Planned End: 2025-10-29 10:30:00 UTC
[ServiceNow DevOps] Polling for approval...
[ServiceNow DevOps] ⏳ Waiting for approval (60s elapsed)
[ServiceNow DevOps] ✅ Change approved by John Smith
[ServiceNow DevOps] Proceeding with deployment...
```

**Gap:**
- ❌ **Minimal approval status in logs** (just state polling)
- ❌ **No approver names shown**
- ❌ **No planned start/end times**
- ❌ **No assignment group visibility**

**Impact:**
- Developers can't see who needs to approve
- No visibility into planned maintenance window
- Must switch to ServiceNow UI to see details

**Recommendation:**
Migrate to official action for richer console logs, or enhance polling to extract more fields:
```bash
RESPONSE=$(curl -s -u "$USERNAME:$PASSWORD" \
  "$INSTANCE_URL/api/now/table/change_request/${CHANGE_SYSID}?sysparm_fields=state,approval,approvers,assignment_group,start_date,end_date")

APPROVERS=$(echo "$RESPONSE" | jq -r '.result.approvers')
ASSIGNMENT_GROUP=$(echo "$RESPONSE" | jq -r '.result.assignment_group')
PLANNED_START=$(echo "$RESPONSE" | jq -r '.result.start_date')
PLANNED_END=$(echo "$RESPONSE" | jq -r '.result.end_date')

echo "📋 Change Details:"
echo "  Approvers: $APPROVERS"
echo "  Assignment Group: $ASSIGNMENT_GROUP"
echo "  Planned Window: $PLANNED_START → $PLANNED_END"
```

---

### 7. Automatic Change Closure

#### Current State
```yaml
# ❌ NOT IMPLEMENTED
# Change requests remain open after deployment
```

#### ServiceNow DevOps Change Velocity Approach
Changes are automatically closed when pipeline completes:
- **Success**: Change set to "Closed" with close_code="successful"
- **Failure**: Change set to "Closed" with close_code="unsuccessful"
- **Closure notes**: Populated with deployment summary
- **Actual start/end times**: Recorded from pipeline timestamps

**Gap:**
- ❌ **Changes never auto-closed** (manual cleanup required)
- ❌ **No actual start/end times** (only planned)
- ❌ **No closure notes**

**Impact:**
- Change requests accumulate in "Implement" state
- No automatic post-implementation review
- Manual effort to close changes

**Recommendation:**
Add change closure step at end of pipeline:
```yaml
- name: Close Change Request
  if: always()
  run: |
    if [ "${{ job.status }}" = "success" ]; then
      CLOSE_CODE="successful"
      CLOSE_NOTES="Deployment completed successfully. All services healthy."
    else
      CLOSE_CODE="unsuccessful"
      CLOSE_NOTES="Deployment failed. See workflow logs for details."
    fi

    PAYLOAD=$(jq -n \
      --arg state "3" \
      --arg close_code "$CLOSE_CODE" \
      --arg close_notes "$CLOSE_NOTES" \
      --arg actual_start "${{ env.DEPLOY_START_TIME }}" \
      --arg actual_end "$(date -u +"%Y-%m-%d %H:%M:%S")" \
      '{
        state: $state,
        close_code: $close_code,
        close_notes: $close_notes,
        work_start: $actual_start,
        work_end: $actual_end
      }')

    curl -s -u "$USERNAME:$PASSWORD" \
      -H "Content-Type: application/json" \
      -X PATCH \
      -d "$PAYLOAD" \
      "$INSTANCE_URL/api/now/table/change_request/${{ env.CHANGE_SYSID }}"
```

---

## Migration Path to ServiceNow DevOps Change Velocity

### Option A: Keep Custom REST API (Current Approach)

**Pros:**
- ✅ Full control over change request fields
- ✅ No ServiceNow DevOps Change Velocity license required
- ✅ Basic Auth is acceptable for demo/internal use
- ✅ Already working integration

**Cons:**
- ❌ No DORA metrics
- ❌ No DevOps Insights dashboards
- ❌ Manual work item/test/artifact integration
- ❌ No AI-powered risk assessment
- ❌ Missing ServiceNow best practice features

**Recommended Enhancements:**
1. Add work item extraction from commits
2. Upload test results to custom table (u_test_results)
3. Register artifacts in custom table (u_artifacts)
4. Implement automatic change closure
5. Enhance console logging with approver details
6. Migrate to token-based auth (create integration user token)

---

### Option B: Migrate to Official ServiceNow DevOps Change Velocity

**Pros:**
- ✅ DORA metrics out-of-the-box
- ✅ DevOps Insights dashboards
- ✅ AI-powered risk scoring
- ✅ Automatic work item/test/artifact integration
- ✅ Deployment gates with rich console logging
- ✅ ServiceNow support and updates

**Cons:**
- ❌ Requires DevOps Change Velocity license purchase
- ❌ Less control over change request customization
- ❌ Must register orchestration tool in ServiceNow
- ❌ Migration effort to switch from REST API to actions

**Migration Steps:**

#### 1. Purchase & Install ServiceNow DevOps Change Velocity
- Contact ServiceNow sales for license
- Install from ServiceNow Store: https://store.servicenow.com/store/app/1b2aabe21b246a50a85b16db234bcbe1
- Activate plugins: `sn_devops`, `com.snc.devops.insights`

#### 2. Register GitHub as Orchestration Tool
```bash
# In ServiceNow, navigate to: DevOps > Tools
# Click "New" and create GitHub tool:
#   Name: GitHub Actions
#   Type: GitHub
#   URL: https://github.com
#   Authentication: Token-based
#   Token: <GitHub PAT with repo, workflow, admin:repo_hook scopes>
# Save and copy sys_id → SN_ORCHESTRATION_TOOL_ID
```

#### 3. Generate Integration Token
```bash
# In ServiceNow, navigate to: DevOps > Integration Tokens
# Click "New" and generate token for GitHub Actions
# Copy token → SN_DEVOPS_INTEGRATION_TOKEN
```

#### 4. Update GitHub Secrets
```bash
gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "xxxxx"
gh secret set SN_ORCHESTRATION_TOOL_ID --body "abc123sys_id"
# Keep SN_INSTANCE_URL
```

#### 5. Replace Custom REST API with Official Actions
**Before:**
```yaml
- name: Create Change Request via REST API
  run: |
    curl -s -u "$USERNAME:$PASSWORD" \
      -X POST "$INSTANCE_URL/api/now/table/change_request" \
      -d '{ ... }'
```

**After:**
```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v6.1.0
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    context-github: ${{ toJSON(github) }}
    job-name: 'Deploy to ${{ inputs.environment }}'
    change-request: |
      {
        "short_description": "${{ inputs.short_description }}",
        "description": "${{ inputs.description }}",
        "assignment_group": "${{ inputs.assignment_group }}",
        "implementation_plan": "${{ inputs.implementation_plan }}",
        "backout_plan": "${{ inputs.backout_plan }}",
        "test_plan": "${{ inputs.test_plan }}"
      }
```

#### 6. Add Test Results Upload
```yaml
- name: ServiceNow DevOps Unit Test Results
  uses: ServiceNow/servicenow-devops-unit-test-results@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    test-result-files: |
      trivy-results.json
      test-results.xml
```

#### 7. Add Artifact Registration
```yaml
- name: ServiceNow DevOps Register Artifact
  uses: ServiceNow/servicenow-devops-register-artifact@v3
  with:
    devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
    instance-url: ${{ secrets.SN_INSTANCE_URL }}
    tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
    artifacts: |
      [
        {
          "name": "frontend",
          "version": "${{ env.VERSION }}",
          "semanticVersion": "${{ env.VERSION }}",
          "repositoryName": "${{ github.repository }}"
        }
      ]
```

#### 8. Enable DORA Metrics Collection
- Navigate to: DevOps > Insights
- Configure data collection frequency
- Set baseline metrics
- Create dashboards for stakeholders

---

### Option C: Hybrid Approach (Recommended for Now)

**Keep custom REST API** for change request creation, but **add missing features** incrementally:

**Phase 1 (Immediate - No License Required):**
1. ✅ Add work item extraction from commits → custom table
2. ✅ Upload test results → custom table (u_test_results)
3. ✅ Register artifacts → custom table (u_artifacts)
4. ✅ Implement automatic change closure
5. ✅ Enhance console logging with approver/planned window details
6. ✅ Migrate to token-based auth (create ServiceNow API user token)

**Phase 2 (Evaluate ROI):**
1. ⏳ Assess business value of DORA metrics
2. ⏳ Determine if AI risk scoring is needed
3. ⏳ Calculate cost vs. benefit of DevOps Change Velocity license
4. ⏳ If ROI positive → purchase license and migrate to official actions

**Phase 3 (If License Purchased):**
1. 🔄 Migrate to official `ServiceNow/servicenow-devops-change` action
2. 🔄 Replace custom tables with sn_devops_* tables
3. 🔄 Enable DORA metrics dashboards
4. 🔄 Leverage AI-powered risk scoring

---

## Recommendations Summary

### Immediate Actions (No License Required)

1. **Add Work Item Extraction**
   ```yaml
   - name: Extract Work Items
     run: |
       git log --pretty=format:"%s" | grep -oP '(#|GH-)?\d+' > work_items.txt
   ```

2. **Upload Test Results to Custom Table**
   ```yaml
   - name: Upload Test Results
     run: |
       curl -s -u "$USERNAME:$PASSWORD" \
         -X POST "$INSTANCE_URL/api/now/table/u_test_results" \
         -d '{ "change_request": "$CHANGE_SYSID", "test_suite": "Security Scans", "results": "..." }'
   ```

3. **Register Artifacts in Custom Table**
   ```yaml
   - name: Register Artifacts
     run: |
       curl -s -u "$USERNAME:$PASSWORD" \
         -X POST "$INSTANCE_URL/api/now/table/u_artifacts" \
         -d '{ "change_request": "$CHANGE_SYSID", "artifact_name": "frontend", "version": "$VERSION" }'
   ```

4. **Implement Automatic Change Closure**
   ```yaml
   - name: Close Change Request
     if: always()
     run: |
       curl -s -u "$USERNAME:$PASSWORD" \
         -X PATCH "$INSTANCE_URL/api/now/table/change_request/$CHANGE_SYSID" \
         -d '{ "state": "3", "close_code": "successful" }'
   ```

5. **Enhance Console Logging**
   ```yaml
   echo "📋 Change: $CHANGE_NUMBER"
   echo "👥 Approvers: $APPROVERS"
   echo "⏰ Window: $PLANNED_START → $PLANNED_END"
   ```

6. **Migrate to Token Auth**
   - Create integration user in ServiceNow
   - Generate API token
   - Replace Basic Auth with Bearer token

### Long-Term Considerations

1. **Evaluate ServiceNow DevOps Change Velocity License**
   - Cost: Contact ServiceNow sales
   - Value: DORA metrics, AI risk scoring, DevOps Insights dashboards
   - ROI: Depends on organization size and compliance requirements

2. **If License Purchased:**
   - Migrate to official GitHub Actions
   - Replace custom tables with sn_devops_* tables
   - Enable DORA metrics collection
   - Leverage AI-powered features

3. **If Staying with Custom Implementation:**
   - Build custom DORA metrics collection
   - Create ServiceNow dashboards for deployment frequency, lead time
   - Implement custom risk scoring logic
   - Maintain custom tables for work items, tests, artifacts

---

## Conclusion

**Current Status:** ✅ **Already 70% integrated with ServiceNow DevOps Change Velocity!**

### What We Have (Implemented Features) ✅


**Official ServiceNow DevOps Actions:**

- ✅ Test Results Upload (`servicenow-devops-test-report@v6.0.0`)
- ✅ Artifact Registration (`servicenow-devops-register-package@v3.1.0`)
- ✅ SonarCloud Integration (`servicenow-devops-sonar@v3.1.0`)
- ✅ Orchestration Tool Configured (`SN_ORCHESTRATION_TOOL_ID`)


**Custom Implementation:**

- ✅ Change requests with 13 custom fields
- ✅ Multi-environment approvals (dev/qa/prod)
- ✅ Basic Auth (valid for demo)
- ✅ Quality gates (tests blocking for prod)

### What We're Missing ❌


**Only 3 Major Gaps:**

1. **Official Change Action** - Still using custom REST API instead of `ServiceNow/servicenow-devops-change@v6`
2. **Token-Based Auth** - Using Basic Auth (works, but token is more secure)
3. **Work Item Integration** - GitHub Issues not explicitly linked


**Optional Enhancements:**

- Security scan results upload (Trivy, CodeQL, Semgrep)
- Auto-close changes after deployment
- DORA metrics dashboards (may require license activation)

### Next Steps

#### Option 1: Keep Hybrid Approach (Recommended for Demo)

- ✅ Already have test results, artifacts, SonarCloud integrated
- ⚠️ Add official change action: `ServiceNow/servicenow-devops-change@v6`
- ⚠️ Migrate to token auth for better security
- ⚠️ Add work item extraction from commits

#### Option 2: Full ServiceNow DevOps Change Velocity License

- Activate DORA metrics dashboards
- Enable AI-powered risk scoring
- Get ServiceNow support for official actions

### Key Decision

**For Demo:** ✅ Current integration is **excellent** - just add official change action

**For Enterprise:** Consider full Change Velocity license for DORA metrics and AI features

---

## References

- **ServiceNow DevOps Change Velocity Product Page**: https://www.servicenow.com/products/devops-change-velocity.html
- **Official GitHub Action**: https://github.com/marketplace/actions/servicenow-devops-change-automation
- **ServiceNow DevOps Documentation**: https://docs.servicenow.com/bundle/yokohama-it-service-management/page/product/enterprise-dev-ops/concept/github-integration-dev-ops.html
- **DORA Metrics Guide**: https://cloud.google.com/blog/products/devops-sre/using-the-four-keys-to-measure-your-devops-performance
- **Change Velocity FAQ**: https://www.servicenow.com/community/devops-articles/faq-for-devops-change-velocity/ta-p/3018723

---

**Document Owner:** DevOps Team
**Last Review:** 2025-10-28
**Next Review:** 2025-11-28
