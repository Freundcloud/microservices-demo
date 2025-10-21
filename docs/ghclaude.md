# Integrating GitHub Workflows with ServiceNow Velocity DevOps Change

ServiceNow DevOps Change Velocity provides robust APIs and multiple integration methods to automatically send all GitHub workflow data—deployments, commits, PRs, builds, test results, and security scans—into DevOps Change insights. This integration enables automated change management while maintaining compliance and full traceability from code to production.

## Prerequisites and authentication setup

Before implementing any integration method, you need ServiceNow DevOps Change Velocity installed on your ServiceNow instance (requires ITSM Pro license for production). The integration supports two authentication approaches: **token-based authentication** (recommended, available from v4.0.0+) offers better security with bearer tokens, while **basic authentication** uses username and password credentials stored as secrets.

To set up authentication, navigate to the DevOps Change Velocity workspace in ServiceNow and create a GitHub tool record under Applications. This generates your integration credentials and a Tool ID (sys_id) that identifies your GitHub connection. Configure OAuth with JWT for the most secure approach, or use Personal Access Tokens for simpler setups. Store three critical values as GitHub repository secrets: `SN_DEVOPS_INTEGRATION_TOKEN` (your authentication token), `SN_INSTANCE_URL` (e.g., https://yourinstance.service-now.com), and `SN_ORCHESTRATION_TOOL_ID` (the sys_id from your tool registration).

## Method 1: Official ServiceNow GitHub Actions (recommended)

ServiceNow provides verified GitHub Actions in the GitHub Marketplace that handle all data types and abstract the API complexity. This is the most maintainable approach for most organizations, offering pre-built, tested integrations with built-in error handling and comprehensive documentation.

### Complete workflow example sending all data types

```yaml
name: Complete ServiceNow DevOps Integration

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  SN_INSTANCE_URL: ${{ secrets.SN_INSTANCE_URL }}
  SN_DEVOPS_TOKEN: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  SN_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

jobs:
  build:
    name: Build and Test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3
        
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'
          
      - name: Build Application
        run: mvn clean package
        
      - name: Run Unit Tests
        run: mvn test
        
      # Send test results to ServiceNow
      - name: ServiceNow DevOps Unit Test Results
        uses: ServiceNow/servicenow-devops-test-report@v6.0.0
        with:
          devops-integration-token: ${{ env.SN_DEVOPS_TOKEN }}
          instance-url: ${{ env.SN_INSTANCE_URL }}
          tool-id: ${{ env.SN_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Build and Test'
          xml-report-filename: 'target/surefire-reports/*.xml'
          test-summary-name: 'Unit Tests'

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Run Veracode Scan
        run: |
          echo "Running security scan..."
          # Your scanning commands here
          
      # Send security scan results to ServiceNow
      - name: ServiceNow DevOps Security Results
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ env.SN_DEVOPS_TOKEN }}
          instance-url: ${{ env.SN_INSTANCE_URL }}
          tool-id: ${{ env.SN_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Security Scan'
          security-result-attributes: '{
            "scanner": "Veracode",
            "applicationName": "MyApplication",
            "buildVersion": "${{ github.run_number }}"
          }'

  register-artifact:
    name: Register Artifact
    runs-on: ubuntu-latest
    needs: [build, security-scan]
    steps:
      # Register build artifacts with ServiceNow
      - name: ServiceNow Register Artifact
        uses: ServiceNow/servicenow-devops-register-artifact@v3.1.0
        with:
          devops-integration-token: ${{ env.SN_DEVOPS_TOKEN }}
          instance-url: ${{ env.SN_INSTANCE_URL }}
          tool-id: ${{ env.SN_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Register Artifact'
          artifacts: '[{
            "name": "myapp",
            "version": "1.${{ github.run_number }}",
            "semanticVersion": "1.${{ github.run_number }}.0",
            "repositoryName": "${{ github.repository }}"
          }]'

  register-package:
    name: Register Package
    runs-on: ubuntu-latest
    needs: register-artifact
    steps:
      # Register deployment packages
      - name: ServiceNow Register Package
        uses: ServiceNow/servicenow-devops-register-package@v3.1.0
        with:
          devops-integration-token: ${{ env.SN_DEVOPS_TOKEN }}
          instance-url: ${{ env.SN_INSTANCE_URL }}
          tool-id: ${{ env.SN_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Register Package'
          artifacts: '[{
            "name": "myapp",
            "version": "1.${{ github.run_number }}",
            "semanticVersion": "1.${{ github.run_number }}.0",
            "repositoryName": "${{ github.repository }}"
          }]'
          package-name: 'myapp-${{ github.run_number }}.war'

  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: register-package
    environment: production
    steps:
      # Create change request and wait for approval
      - name: ServiceNow Change
        uses: ServiceNow/servicenow-devops-change@v6.1.0
        id: change
        with:
          devops-integration-token: ${{ env.SN_DEVOPS_TOKEN }}
          instance-url: ${{ env.SN_INSTANCE_URL }}
          tool-id: ${{ env.SN_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to Production'
          change-request: '{
            "setCloseCode": "true",
            "autoCloseChange": true,
            "attributes": {
              "short_description": "Automated Deployment - Build ${{ github.run_number }}",
              "description": "Deploying version 1.${{ github.run_number }}.0 to production from GitHub Actions",
              "assignment_group": "a715cd759f2002002920bde8132e7018",
              "implementation_plan": "Automated deployment via GitHub Actions. All tests passed (Unit: 95%, Integration: 92%). Security scan completed with no critical issues. Deployment will occur within the change window.",
              "backout_plan": "Redeploy previous version (1.${{ github.run_number - 1 }}.0) using rollback workflow. Estimated rollback time: 5 minutes. Database changes are backward compatible.",
              "test_plan": "Automated tests executed and passed. Post-deployment smoke tests will verify health endpoints, database connectivity, and key user journeys."
            }
          }'
          interval: '100'
          timeout: '3600'
          changeCreationTimeOut: '3600'
          abortOnChangeCreationFailure: true
          deployment-gate: '{
            "environment": "production",
            "jobName": "Deploy to Production"
          }'
          
      - name: Deploy Application
        run: |
          echo "Deploying to production..."
          echo "Change Request: ${{ steps.change.outputs.change-request-number }}"
          ./deploy-production.sh
          
      - name: Verify Deployment
        run: |
          echo "Running post-deployment verification..."
          ./health-check.sh
```

The `context-github: ${{ toJSON(github) }}` parameter is crucial—it automatically sends repository information, commit SHA, branch name, workflow run details, actor information, and event type to ServiceNow, enabling complete traceability without manual data extraction.

### Available official actions for all data types

**ServiceNow/servicenow-devops-change@v6.1.0** creates change requests and implements deployment gates. This action pauses workflows until change approval is received, supports automatic change closure based on pipeline status, and integrates with GitHub Deployment Protection Rules for policy-based approvals.

**ServiceNow/servicenow-devops-test-report@v6.0.0** sends test results from multiple frameworks including JUnit, TestNG, pytest, jest, NUnit, and XUnit. Simply point it to your XML test reports (e.g., `target/surefire-reports/*.xml`) and it automatically parses and sends test data including pass/fail counts, coverage percentages, and individual test details.

**ServiceNow/servicenow-devops-register-artifact@v3.1.0** registers build artifacts with name, version, semantic version, and repository information. This enables artifact traceability for audit and rollback decisions, linking specific deployments to change requests.

**ServiceNow/servicenow-devops-register-package@v3.1.0** registers deployment packages that bundle multiple artifacts, associating package files (WAR, JAR, Docker images) with the artifacts they contain.

**ServiceNow/servicenow-devops-security-result@v3.1.0** integrates security scanning tools including Veracode, Checkmarx SAST, SonarQube, and custom scanners. It sends vulnerability data, security hotspots, and quality gate status for policy-based approval decisions.

**ServiceNow/servicenow-devops-sonar** provides specialized SonarQube/SonarCloud integration for code quality metrics, code coverage, technical debt, and security vulnerabilities directly from your SonarQube instance.

## Method 2: Direct API calls using curl

For maximum flexibility or custom requirements not met by official actions, you can make direct REST API calls to ServiceNow Velocity endpoints. This approach requires more code but provides complete control over payloads and error handling.

### API endpoint structure and authentication

ServiceNow DevOps Change APIs follow this pattern: `https://{instance-url}.service-now.com/api/sn_devops/v1/devops/{endpoint}`. Authentication uses the Authorization header with your bearer token: `Authorization: Bearer {token}`.

### Creating change requests via API

```yaml
jobs:
  create-change:
    runs-on: ubuntu-latest
    steps:
      - name: Create Change Request via API
        run: |
          CHANGE_RESPONSE=$(curl -X POST \
            "${{ secrets.SN_INSTANCE_URL }}/api/sn_devops/v1/devops/change/changeRequest" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}" \
            -d '{
              "attributes": {
                "short_description": "Automated Deployment Build ${{ github.run_number }}",
                "description": "Deployment from GitHub Actions workflow ${{ github.workflow }}",
                "assignment_group": "a715cd759f2002002920bde8132e7018",
                "implementation_plan": "Deploy tested build to production environment. All quality gates passed.",
                "backout_plan": "Rollback to previous version via automated rollback workflow.",
                "test_plan": "Automated tests passed. Post-deployment smoke tests will be executed.",
                "priority": "3",
                "start_date": "2025-10-21 20:00:00",
                "end_date": "2025-10-21 22:00:00"
              },
              "orchestrationTaskURL": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}",
              "orchestrationToolId": "${{ secrets.SN_ORCHESTRATION_TOOL_ID }}"
            }')
          
          echo "Response: $CHANGE_RESPONSE"
          CHANGE_NUMBER=$(echo $CHANGE_RESPONSE | jq -r '.result.changeRequestNumber')
          CHANGE_SYS_ID=$(echo $CHANGE_RESPONSE | jq -r '.result.changeRequestSysId')
          echo "CHANGE_NUMBER=$CHANGE_NUMBER" >> $GITHUB_ENV
          echo "CHANGE_SYS_ID=$CHANGE_SYS_ID" >> $GITHUB_ENV
          
      - name: Wait for Approval
        run: |
          echo "Waiting for approval of change ${{ env.CHANGE_NUMBER }}..."
          POLL_COUNT=0
          MAX_POLLS=36  # 30 minutes with 50-second intervals
          
          while [ $POLL_COUNT -lt $MAX_POLLS ]; do
            sleep 50
            
            STATUS_RESPONSE=$(curl -s -X GET \
              "${{ secrets.SN_INSTANCE_URL }}/api/now/table/change_request?sysparm_query=number=${{ env.CHANGE_NUMBER }}&sysparm_fields=state,approval" \
              -H "Authorization: Bearer ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}")
            
            STATE=$(echo $STATUS_RESPONSE | jq -r '.result[0].state')
            APPROVAL=$(echo $STATUS_RESPONSE | jq -r '.result[0].approval')
            
            echo "Current state: $STATE, Approval: $APPROVAL"
            
            # State 3 = Authorized, Approval = Approved
            if [ "$STATE" = "3" ] || [ "$APPROVAL" = "approved" ]; then
              echo "✅ Change approved! Proceeding with deployment."
              exit 0
            fi
            
            # State 4 = Canceled, Approval = Rejected
            if [ "$STATE" = "4" ] || [ "$APPROVAL" = "rejected" ]; then
              echo "❌ Change rejected! Aborting deployment."
              exit 1
            fi
            
            POLL_COUNT=$((POLL_COUNT + 1))
          done
          
          echo "⏱️ Timeout waiting for approval"
          exit 1
          
      - name: Deploy Application
        run: |
          echo "Deploying with change request: ${{ env.CHANGE_NUMBER }}"
          ./deploy.sh
```

### Registering artifacts via API

```yaml
- name: Register Artifact via API
  run: |
    curl -X POST \
      "${{ secrets.SN_INSTANCE_URL }}/api/sn_devops/v1/devops/artifact/registration" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}" \
      -d '{
        "artifacts": [{
          "name": "myapp",
          "version": "1.${{ github.run_number }}",
          "semanticVersion": "1.${{ github.run_number }}.0",
          "repositoryName": "${{ github.repository }}"
        }],
        "pipelineName": "${{ github.workflow }}",
        "stageName": "build",
        "taskExecutionNumber": "${{ github.run_id }}",
        "branchName": "${{ github.ref_name }}"
      }'
```

### Sending test results via API

```yaml
- name: Send Test Results via API
  run: |
    curl -X POST \
      "${{ secrets.SN_INSTANCE_URL }}/api/sn_devops/v1/devops/test/results" \
      -H "Authorization: Bearer ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}" \
      -F "testResultsFile=@target/surefire-reports/testng-results.xml" \
      -F "testType=junit" \
      -F "pipelineName=${{ github.workflow }}" \
      -F "stageName=test" \
      -F "taskExecutionNumber=${{ github.run_id }}"
```

## Method 3: Webhook-based integration for automatic data collection

ServiceNow automatically collects commit data, pull request information, and workflow run events through GitHub webhooks. This provides real-time event processing without requiring workflow modifications, making it ideal for capturing commits, PRs, and deployment events passively.

### Setting up webhooks

During GitHub tool configuration in ServiceNow, webhooks are automatically created for your repositories. For manual setup, navigate to your GitHub repository Settings → Webhooks, add a new webhook with the ServiceNow callback URL (format: `https://{instance}.service-now.com/api/sn_github_spoke/github_webhook_callbacks/wh_entry`), set Content Type to `application/json`, add the webhook secret from ServiceNow, and select events: push, pull_request, deployment, deployment_protection_rule, workflow_run.

### What webhooks capture automatically

**Commit data** includes commit SHA, commit messages, author information, timestamps, branch names, files changed, and linked issues/work items based on commit message patterns (e.g., "PROJ-101" references).

**Pull request data** includes PR number, title and description, source and target branches, author and reviewers, status (open/closed/merged), merge commit SHA, related commits, and review comments.

**Build and deployment information** includes pipeline run ID, job names, step results, overall status (success/failure), duration, build numbers, and trigger information.

**Deployment events** track environment deployments, deployment status, deployment timing, and associated commits and artifacts.

### Processing webhook events in ServiceNow

ServiceNow uses Flow Designer to process incoming webhook events. You can create custom routing policies: define conditions like "Webhook Event IS Push", route to specific flows for processing, and implement custom logic for your workflows.

Example workflow: when a push event arrives, iterate through commits, match commit messages to work items using regex patterns, automatically update story records with commit information, and link commits to features for traceability.

## Complete data payload formats for all types

Understanding the exact payload structures ensures you send all necessary data for proper DevOps Change insights.

### Change request payload with all optional fields

```json
{
  "setCloseCode": "true",
  "autoCloseChange": true,
  "attributes": {
    "short_description": "Automated Software Deployment",
    "description": "Automated deployment from GitHub Actions with full traceability",
    "assignment_group": "a715cd759f2002002920bde8132e7018",
    "implementation_plan": "Software update tested via automated test suite. Results available in Test Summaries. Implementation occurs within planned window via CICD pipeline.",
    "backout_plan": "When software fails in production, previous software release will be re-deployed via rollback workflow. Estimated rollback time: 5 minutes.",
    "test_plan": "Automated test suite executed: Unit tests (95% pass), Integration tests (92% pass), Security scan (0 critical issues). Post-deployment smoke tests verify health endpoints.",
    "priority": "3",
    "state": "1",
    "start_date": "2025-10-21 20:00:00",
    "end_date": "2025-10-21 22:00:00",
    "justification": "Critical bug fix affecting user authentication. Security patch required to address CVE-2025-12345.",
    "cab_required": false,
    "comments": "All pre-deployment checks completed successfully.",
    "work_notes": "Automated deployment initiated by GitHub Actions workflow run #123",
    "category": "Software",
    "subcategory": "Application"
  }
}
```

**Critical field restrictions:** You cannot set `risk`, `impact`, or `risk_impact_analysis` as these are calculated automatically by ServiceNow's risk assessment engine. All other Change Request table fields are supported, including custom fields with the `u_` prefix.

### Test results payload

Test results are submitted via XML files rather than JSON. ServiceNow actions automatically parse JUnit, TestNG, NUnit, pytest, jest, and XUnit formats. Your test framework generates XML reports automatically—Maven Surefire creates them at `target/surefire-reports/*.xml`, Jest with jest-junit creates them at the configured path, and pytest with pytest-junit creates them via the `--junit-xml` flag.

### Artifact registration payload with multiple artifacts

```json
{
  "artifacts": [
    {
      "name": "frontend-app",
      "version": "2.5.123",
      "semanticVersion": "2.5.123",
      "repositoryName": "myorg/myapp"
    },
    {
      "name": "backend-api",
      "version": "2.5.123",
      "semanticVersion": "2.5.123",
      "repositoryName": "myorg/myapp"
    },
    {
      "name": "database-migrations",
      "version": "2.5.123",
      "semanticVersion": "2.5.123",
      "repositoryName": "myorg/myapp"
    }
  ],
  "pipelineName": "Production Deploy",
  "stageName": "build",
  "taskExecutionNumber": "1234567890",
  "branchName": "main"
}
```

### Security scan results payloads by scanner type

**Veracode:**
```json
{
  "scanner": "Veracode",
  "applicationName": "MyApplication",
  "buildVersion": "1.0.123",
  "securityToolId": "sys_id_of_veracode_tool_in_servicenow"
}
```

**Checkmarx SAST:**
```json
{
  "scanner": "Checkmarx SAST",
  "projectId": "12345",
  "securityToolId": "sys_id_of_checkmarx_tool_in_servicenow"
}
```

**SonarQube:**
```json
{
  "scanner": "SonarQube",
  "projectKey": "myorg_myapp",
  "serverUrl": "https://sonarqube.company.com",
  "securityToolId": "sys_id_of_sonar_tool_in_servicenow"
}
```

### Package registration payload

```json
{
  "artifacts": [{
    "name": "myapp",
    "version": "1.123",
    "semanticVersion": "1.123.0",
    "repositoryName": "myorg/myapp"
  }],
  "package-name": "myapp-1.123.war"
}
```

## Data mapping best practices for DevOps Change insights

Proper data mapping ensures ServiceNow can analyze your DevOps metrics accurately and provide meaningful insights.

### Mapping GitHub data to ServiceNow's data model

**GitHub repositories map to ServiceNow Applications** via tool configuration. Associate each repository with the correct application record to enable proper impact analysis and application-specific reporting.

**Commits map to sn_devops_commit records** automatically through webhooks. Include work item IDs in commit messages using patterns like "STORY-123" or "PROJ-456" for automatic traceability between code changes and requirements.

**Workflows map to sn_devops_pipeline records** representing your CI/CD pipelines. Each workflow becomes a pipeline object in ServiceNow with associated execution history.

**Jobs map to sn_devops_pipeline_step_execution records** tracking individual job executions within workflows, including duration, status, and failure details.

**Artifacts map to sn_devops_artifact records** with version tracking, enabling audit trails and rollback decisions based on specific artifact versions.

**Test results map to sn_devops_test_suite records** storing test pass/fail counts, coverage percentages, and individual test details for policy-based approval decisions.

### Ensuring field quality for insights

For meaningful DevOps insights, populate these fields consistently: **short_description** should briefly identify the change type and scope, **implementation_plan** should detail deployment steps and expected outcomes, **backout_plan** must include specific rollback procedures and estimated rollback time, and **test_plan** should reference specific test types executed and pass criteria.

Include quantitative data in descriptions: test pass percentages (e.g., "Unit tests: 95%, Integration tests: 92%"), security scan results (e.g., "0 critical, 2 high vulnerabilities"), deployment frequency metrics, and previous successful deployment references.

Link related records explicitly by including change request numbers in deployment logs, artifact versions in change descriptions, test run identifiers in test plans, and pull request numbers in commit messages.

### Required fields for proper DevOps Change insights

While technically only `instance-url`, `tool-id`, `context-github`, and `job-name` are required parameters, for proper insights you should include: **change-request attributes** with short_description, description, assignment_group, implementation_plan, backout_plan, and test_plan; **artifact information** with name, version, semanticVersion, and repositoryName; **test results** via xml-report-filename pointing to complete test output; and **security scan data** specifying scanner type and relevant identifiers.

The `context-github: ${{ toJSON(github) }}` parameter is essential—it provides repository information, commit SHA, branch name, workflow run details, actor information, and event type automatically.

## Common pitfalls and how to avoid them

### Authentication and permission issues

**Missing or incorrect token scopes** cause mysterious connection failures. Your GitHub token needs `repo`, `admin:repo_hook`, and `workflow` scopes. Verify scopes in GitHub → Settings → Developer Settings → Personal Access Tokens.

**Expired tokens** fail silently in some cases. Implement token rotation policies and monitor for authentication errors. Use token-based authentication (v4.0.0+) rather than basic auth for better security and easier rotation.

**Incorrect Tool ID** is a frequent setup error. The `tool-id` parameter must be the exact sys_id of your GitHub tool record in ServiceNow, not the display name. Find it in ServiceNow by navigating to your tool record and copying the sys_id from the URL or record details.

### Job name mismatches cause silent failures

The `job-name` parameter must exactly match your GitHub Actions job display name. If your job is `deploy:` with `name: Deploy to Production`, use `job-name: 'Deploy to Production'`, not `job-name: 'deploy'`. Mismatches result in "Task/Step Execution not created in ServiceNow DevOps" errors, causing data to disappear without obvious errors.

### Webhook configuration problems

**Webhooks not delivering** is common when ServiceNow endpoints aren't publicly accessible or SSL certificates are expired. Verify webhook delivery in GitHub Settings → Webhooks → Recent Deliveries. Green checkmarks indicate success; red X marks indicate failures with detailed error messages.

**Payload size exceeding GitHub's 4MB buffer limit** occurs with large repositories or too many events. Filter webhook events to only necessary types (push, pull_request, deployment), scope webhooks to specific branches (e.g., main only), and trim unnecessary data from webhook configurations.

**Webhook delivery delays** happen when ServiceNow is overloaded. Monitor "Last Successful Poll" timestamps on tool records and implement retry logic for critical data.

### Parallel job restrictions with ServiceNow actions

ServiceNow DevOps Change actions **cannot run in parallel jobs**—this is explicitly unsupported and causes race conditions. Structure your workflows with sequential jobs using `needs:` dependencies. Build and test can run in parallel, but change creation, artifact registration, and deployment must be sequential.

### Field validation errors

**Setting risk, impact, or risk_impact_analysis directly** always fails because ServiceNow calculates these automatically based on other fields and approval policies. Remove these fields from your change request payloads.

**Invalid assignment_group values** cause change creation failures. Use the sys_id of the group (32-character hex string like "a715cd759f2002002920bde8132e7018"), not the group name. Query the sys_group table in ServiceNow to find correct sys_ids.

**Date format mismatches** cause validation errors. Use format `yyyy-MM-dd HH:mm:ss` for all date fields (start_date, end_date). Ensure dates are in the future for scheduled changes.

### Deployment gate confusion

Deployment gates work differently than standard change creation—the change request payload is stored in `sn_devops_callback` table with state "Ready to process" when the raise change step runs, but the actual change request is only created when the deployment gate step is reached. The webhook event `deployment_protection_rule.requested` triggers the actual change creation. If your change isn't being created, verify your GitHub environment has Deployment Protection Rules configured and the webhook subscription includes deployment_protection_rule events.

## Troubleshooting guide for common issues

### Change request not created

**Check these in order:** Verify `tool-id` is correct sys_id by comparing with ServiceNow tool record, confirm authentication token is valid by testing with a simple API call, ensure upstream jobs completed successfully (change creation only runs after dependencies), review GitHub Actions logs for HTTP error codes (401 = auth, 403 = permissions, 404 = wrong endpoint, 500 = ServiceNow error), and check ServiceNow Inbound Events table for processing errors.

### Test results not appearing

**Verify test report generation** by checking that your test framework creates XML files and confirming files exist at the specified path before calling the test report action. **Validate XML format** by manually opening XML files to ensure they're valid JUnit/TestNG format. **Check ServiceNow import logs** in System Logs → Errors for XML parsing errors. **Ensure correct job-name** matches exactly between workflow and action parameters.

### Security scan results not showing

**Verify scanner configuration** in ServiceNow by checking if the security tool is registered with correct credentials. **Validate scanner identifier** by ensuring applicationName (Veracode) or projectId (Checkmarx) matches exactly. **Check scan completion** by confirming the security scan completed before calling the ServiceNow action. **Review scanner logs** for authentication or API errors.

### Webhook delivery failures

**GitHub shows red X on webhook deliveries:** Check ServiceNow endpoint accessibility by testing the webhook URL directly from an external tool. Verify SSL certificate validity (not expired, trusted CA). Ensure webhook secret matches between GitHub and ServiceNow. Check ServiceNow webhook registry for configuration errors.

**ServiceNow receives webhooks but no data appears:** Verify routing policies in Flow Designer are configured correctly. Check for processing errors in ServiceNow System Logs. Ensure data is being mapped to correct tables. Validate tool associations are correct.

### Pipeline execution stuck at "in progress"

**Missing webhook for completion events** is the usual cause. Verify webhook subscriptions include workflow_run events for both started and completed. Manually trigger a test workflow and check GitHub webhook delivery logs for both start and finish events. If only start events arrive, reconfigure webhook subscriptions.

### Timeout errors during change approval

**Increase timeout values** if legitimate approval processes take longer than default 3600 seconds. Set `timeout: '7200'` for 2-hour approval windows. **Adjust polling interval** if frequent polling causes issues—increase from default 100 seconds to 120 or 150. **Configure abort behavior** using `abortOnChangeCreationFailure: false` to continue pipeline even if change creation times out (not recommended for production).

## Best practices for production deployments

### Start with a phased rollout approach

Begin with a **pilot application** using a single repository and team. Validate all integration points work correctly, test change creation and approval workflows, verify data appears in DevOps Change insights, and collect feedback from the pilot team. Expand to **2-3 applications** after successful pilot, comparing data quality across different project types. Finally proceed with **full rollout** to all applications once confident in the integration.

### Implement proper monitoring and alerting

Monitor **webhook health** by tracking delivery success rates in GitHub, setting up alerts for consecutive webhook failures, and reviewing webhook delivery logs weekly. Track **change creation success rates** by measuring percentage of successful change creations, monitoring average time to change approval, and alerting on changes rejected or timing out. Monitor **data quality** by auditing discovered objects coverage (all repos/pipelines present), validating artifact and test result completeness, and checking for stale or missing data.

### Use semantic versioning consistently

Adopt **semantic versioning** (MAJOR.MINOR.PATCH) for all artifacts. Automate version increments using GitHub run numbers: `"semanticVersion": "1.${{ github.run_number }}.0"` for minor updates or implement logic for major version bumps based on commit messages or tags.

### Structure workflows for maximum insight value

**Separate concerns** by using distinct jobs for build, test, security scan, artifact registration, and deployment. This enables granular tracking of pipeline stages. **Use descriptive job names** that clearly indicate purpose (e.g., "Build and Unit Test", "Security Scan - Veracode", "Deploy to Production - East Region"). **Include comprehensive metadata** in change requests with quantitative test results, security scan summaries, and specific deployment details.

### Implement policy-based approvals

Configure **approval policies** in ServiceNow based on test pass percentage thresholds (e.g., require 90%+ pass rate), security scan results (no critical vulnerabilities), code coverage requirements (e.g., 80%+ coverage), and deployment frequency limits (maximum deployments per day). This enables **automated approvals** for low-risk changes meeting all criteria while requiring **manual approval** for high-risk changes or policy violations.

### Maintain separation of duties

**ServiceNow administrators** configure the DevOps Change Velocity app, create tool registrations, manage approval policies, and monitor integration health. **GitHub administrators** configure webhook settings, manage repository access, store and rotate authentication tokens, and maintain GitHub Actions workflows. **Development teams** maintain workflow YAML files, ensure proper job naming and structure, include meaningful change descriptions, and respond to approval requests. Clear responsibility boundaries prevent configuration drift and security issues.

This comprehensive integration enables automated change management while maintaining full compliance and traceability from code commit through production deployment, providing the foundation for measuring Accelerate metrics (lead time, deployment frequency, MTTR, change failure rate) and achieving DevOps excellence.