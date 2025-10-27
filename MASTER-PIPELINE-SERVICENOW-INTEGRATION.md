# ServiceNow Integration in MASTER-PIPELINE.yaml

> **Status**: Implementation Guide
> **Goal**: Add complete ServiceNow integration to MASTER-PIPELINE

---

## Current ServiceNow Workflows (Reusable)

These existing workflows contain ServiceNow integration logic:

1. **servicenow-change.yaml** - Creates Change Requests
   - Auto-approves for dev (state = "implement")
   - Requires approval for qa/prod (state = "assess")
   - Already implemented ✅

2. **build-images.yaml** (lines 200-250) - Contains:
   - ServiceNow test result upload
   - ServiceNow package registration
   - Already implemented ✅

3. **deploy-environment.yaml** (lines 45-79, 157-175) - Contains:
   - ServiceNow Change Request creation (calls servicenow-change.yaml)
   - ServiceNow config upload
   - Already implemented ✅

---

## Integration Points in MASTER-PIPELINE

### Stage 3.5: ServiceNow Test Results & Package Registration

**Add AFTER `build-and-push` job** (around line 286):

```yaml
  # ============================================================================
  # STAGE 3.5: ServiceNow Integration (Test Results & Packages)
  # ============================================================================

  upload-test-results:
    name: "📊 Upload Test Results to ServiceNow"
    needs: [pipeline-init, build-and-push]
    if: |
      needs.build-and-push.result == 'success' &&
      github.event_name != 'pull_request'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Upload Test Results
        uses: ServiceNow/servicenow-devops-test-report@v2.0.0
        with:
          devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
          devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Build and Test - ${{ needs.pipeline-init.outputs.environment }}'
          xml-report-filename: '**/test-results/*.xml'

      - name: Test Upload Summary
        if: always()
        run: |
          echo "## 📊 Test Results Uploaded" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Test results uploaded to ServiceNow" >> $GITHUB_STEP_SUMMARY
          echo "Environment: **${{ needs.pipeline-init.outputs.environment }}**" >> $GITHUB_STEP_SUMMARY

  register-packages:
    name: "📦 Register Packages in ServiceNow"
    needs: [pipeline-init, build-and-push]
    if: |
      needs.build-and-push.result == 'success' &&
      github.event_name != 'pull_request'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Build Package Metadata
        id: package-metadata
        run: |
          # Extract services that were built
          SERVICES="${{ needs.build-and-push.outputs.services_built }}"

          # Build artifacts JSON for ServiceNow
          ARTIFACTS='[]'
          for service in $(echo "$SERVICES" | jq -r '.[]' 2>/dev/null || echo ""); do
            ARTIFACT=$(jq -n \
              --arg name "${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.eu-west-2.amazonaws.com/${service}" \
              --arg version "${{ needs.pipeline-init.outputs.environment }}-${{ github.sha }}" \
              --arg semantic "${{ needs.pipeline-init.outputs.environment }}-${{ github.run_number }}" \
              --arg repo "${{ github.repository }}" \
              '{
                "name": $name,
                "version": $version,
                "semanticVersion": $semantic,
                "repositoryName": $repo
              }')
            ARTIFACTS=$(echo "$ARTIFACTS" | jq ". += [$ARTIFACT]")
          done

          echo "artifacts=$ARTIFACTS" >> $GITHUB_OUTPUT

      - name: Register Docker Images
        uses: ServiceNow/servicenow-devops-register-package@v2.0.0
        with:
          devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
          devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Register Packages - ${{ needs.pipeline-init.outputs.environment }}'
          artifacts: ${{ steps.package-metadata.outputs.artifacts }}
          package-name: 'microservices-${{ needs.pipeline-init.outputs.environment }}-${{ github.run_number }}.package'

      - name: Package Registration Summary
        if: always()
        run: |
          echo "## 📦 Packages Registered" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Docker images registered in ServiceNow" >> $GITHUB_STEP_SUMMARY
          echo "Environment: **${{ needs.pipeline-init.outputs.environment }}**" >> $GITHUB_STEP_SUMMARY
          echo "Package: \`microservices-${{ needs.pipeline-init.outputs.environment }}-${{ github.run_number }}.package\`" >> $GITHUB_STEP_SUMMARY
```

### Stage 4: ServiceNow Change Request & Config Upload

**REPLACE `deploy-to-environment` job** (around line 291) **with**:

```yaml
  # ============================================================================
  # STAGE 4: Deployment with ServiceNow Integration
  # ============================================================================

  servicenow-change:
    name: "📝 ServiceNow Change Request"
    needs: [pipeline-init, register-packages]
    if: |
      always() &&
      needs.pipeline-init.outputs.should_deploy == 'true' &&
      needs.pipeline-init.outputs.policy_ok == 'true' &&
      !inputs.skip_deploy
    uses: ./.github/workflows/servicenow-change.yaml
    secrets: inherit
    with:
      environment: ${{ needs.pipeline-init.outputs.environment }}
      change_type: 'kubernetes'
      short_description: 'Deploy microservices to ${{ needs.pipeline-init.outputs.environment }} (Kubernetes)'
      description: |
        Kubernetes deployment of microservices application to ${{ needs.pipeline-init.outputs.environment }} environment.

        Environment: ${{ needs.pipeline-init.outputs.environment }}
        Namespace: microservices-${{ needs.pipeline-init.outputs.environment }}
        Deployment Method: Kustomize overlays
        Triggered by: ${{ github.actor }}
        Commit: ${{ github.sha }}
        Workflow: ${{ github.workflow }}
      implementation_plan: |
        1. Configure kubectl access to EKS cluster
        2. Ensure namespace microservices-${{ needs.pipeline-init.outputs.environment }} exists
        3. Apply Kustomize overlays for ${{ needs.pipeline-init.outputs.environment }}
        4. Monitor rollout status for all deployments
        5. Verify all pods healthy and running
        6. Test frontend application endpoint
      backout_plan: |
        1. kubectl rollout undo -n microservices-${{ needs.pipeline-init.outputs.environment }} --all
        2. Verify all services rolled back to previous version
        3. Monitor pod status and logs
        4. Test application functionality
      test_plan: |
        1. Verify all deployments rolled out successfully
        2. Check all pods are in Running state
        3. Verify service endpoints responding
        4. Test frontend URL accessibility
        5. Monitor application metrics and logs

  deploy-to-environment:
    name: "🚀 Deploy Application"
    needs: [pipeline-init, servicenow-change]
    if: needs.servicenow-change.result == 'success'
    runs-on: ubuntu-latest
    environment: ${{ needs.pipeline-init.outputs.environment }}

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy with Kustomize
        run: |
          kubectl apply -k kustomize/overlays/${{ needs.pipeline-init.outputs.environment }}

      - name: Wait for Rollout Complete
        run: |
          kubectl rollout status deployment --all \
            -n microservices-${{ needs.pipeline-init.outputs.environment }} \
            --timeout=10m

      - name: Deployment Summary
        if: always()
        run: |
          echo "## 🚀 Deployment Complete" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Environment: **${{ needs.pipeline-init.outputs.environment }}**" >> $GITHUB_STEP_SUMMARY
          echo "Namespace: \`microservices-${{ needs.pipeline-init.outputs.environment }}\`" >> $GITHUB_STEP_SUMMARY

  upload-config-to-servicenow:
    name: "⚙️ Upload Config to ServiceNow"
    needs: [pipeline-init, deploy-to-environment]
    if: needs.deploy-to-environment.result == 'success'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Upload Deployment Config
        uses: ServiceNow/servicenow-devops-config-validate@v1.0.0-beta
        with:
          devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
          devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
          instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          application-name: 'microservices-demo'
          snapshot-name: 'deployment-${{ github.run_number }}'
          target-environment: ${{ needs.pipeline-init.outputs.environment }}
          deployable-name: 'microservices-${{ needs.pipeline-init.outputs.environment }}'
          config-file-path: 'kustomize/overlays/${{ needs.pipeline-init.outputs.environment }}/*.yaml'
          auto-commit: 'true'
          auto-validate: 'true'
          auto-publish: 'true'

      - name: Config Upload Summary
        if: always()
        run: |
          echo "## ⚙️ Configuration Uploaded" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "✅ Kubernetes configs uploaded to ServiceNow" >> $GITHUB_STEP_SUMMARY
          echo "Snapshot: \`deployment-${{ github.run_number }}\`" >> $GITHUB_STEP_SUMMARY
          echo "Environment: **${{ needs.pipeline-init.outputs.environment }}**" >> $GITHUB_STEP_SUMMARY
```

---

## Updated Job Dependencies

### Before (Current MASTER-PIPELINE):
```
build-and-push → deploy-to-environment → smoke-tests
```

### After (With ServiceNow Integration):
```
build-and-push → upload-test-results (parallel)
              ├→ register-packages (parallel)
              └→ servicenow-change
                 └→ deploy-to-environment
                    └→ upload-config-to-servicenow
                       └→ smoke-tests
```

---

## Summary Job Update

**Update `pipeline-summary` job** to include ServiceNow stages:

```yaml
  pipeline-summary:
    name: "📊 Pipeline Summary"
    needs:
      - pipeline-init
      - security-scans
      - detect-terraform-changes
      - detect-service-changes
      - build-and-push
      - upload-test-results              # NEW
      - register-packages                # NEW
      - servicenow-change                # NEW
      - deploy-to-environment
      - upload-config-to-servicenow      # NEW
      - smoke-tests
    if: always()
    runs-on: ubuntu-latest

    steps:
      - name: Generate Summary
        run: |
          echo "# 🚀 Master CI/CD Pipeline Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "## Pipeline Configuration" >> $GITHUB_STEP_SUMMARY
          echo "| Parameter | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|-----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Environment | **${{ needs.pipeline-init.outputs.environment }}** |" >> $GITHUB_STEP_SUMMARY
          echo "| Trigger | ${{ github.event_name }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Branch | \`${{ github.ref_name }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| Actor | @${{ github.actor }} |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          echo "## Stage Results" >> $GITHUB_STEP_SUMMARY
          echo "| Stage | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Security Scans | ${{ needs.security-scans.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Build Images | ${{ needs.build-and-push.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Upload Test Results | ${{ needs.upload-test-results.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Register Packages | ${{ needs.register-packages.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| ServiceNow Change | ${{ needs.servicenow-change.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Deploy | ${{ needs.deploy-to-environment.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Upload Config | ${{ needs.upload-config-to-servicenow.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Smoke Tests | ${{ needs.smoke-tests.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          echo "## ServiceNow Integration" >> $GITHUB_STEP_SUMMARY
          echo "| Item | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Change Request | ${{ needs.servicenow-change.outputs.change_request_number }} |" >> $GITHUB_STEP_SUMMARY
          if [ "${{ needs.pipeline-init.outputs.environment }}" == "dev" ]; then
            echo "| Approval Status | ✅ Auto-Approved (DEV) |" >> $GITHUB_STEP_SUMMARY
          else
            echo "| Approval Status | ✅ Approved in ServiceNow |" >> $GITHUB_STEP_SUMMARY
          fi
          echo "" >> $GITHUB_STEP_SUMMARY

          echo "## 🎯 Final Result" >> $GITHUB_STEP_SUMMARY
          if [ "${{ needs.deploy-to-environment.result }}" == "success" ] && [ "${{ needs.smoke-tests.result }}" == "success" ]; then
            echo "### ✅ **DEPLOYMENT SUCCESSFUL**" >> $GITHUB_STEP_SUMMARY
            echo "Application successfully deployed to **${{ needs.pipeline-init.outputs.environment }}**" >> $GITHUB_STEP_SUMMARY
          elif [ "${{ needs.deploy-to-environment.result }}" == "skipped" ]; then
            echo "### ℹ️ **BUILD ONLY**" >> $GITHUB_STEP_SUMMARY
            echo "No deployment occurred (PR or manual skip)" >> $GITHUB_STEP_SUMMARY
          else
            echo "### ❌ **DEPLOYMENT FAILED**" >> $GITHUB_STEP_SUMMARY
            echo "Check individual stage logs for details" >> $GITHUB_STEP_SUMMARY
          fi
```

---

## Implementation Checklist

- [ ] Add `upload-test-results` job after `build-and-push`
- [ ] Add `register-packages` job after `build-and-push`
- [ ] Add `servicenow-change` job before `deploy-to-environment`
- [ ] Update `deploy-to-environment` job to wait for `servicenow-change`
- [ ] Add `upload-config-to-servicenow` job after `deploy-to-environment`
- [ ] Update `pipeline-summary` job dependencies
- [ ] Update `pipeline-summary` job output to include ServiceNow stages
- [ ] Test workflow with dev deployment
- [ ] Test workflow with qa deployment (manual approval)
- [ ] Verify ServiceNow evidence upload

---

## Testing

After implementation, verify:

1. ✅ Test results uploaded after builds
2. ✅ Packages registered after builds
3. ✅ Change Request created before deployment
4. ✅ DEV: Auto-approved (state = "implement")
5. ✅ QA/PROD: Manual approval required (state = "assess")
6. ✅ Config uploaded after deployment
7. ✅ All evidence visible in ServiceNow

ServiceNow URLs:
- Test Results: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_test_result_list.do
- Packages: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_package_list.do
- Change Requests: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/change_request_list.do
- Config Snapshots: https://calitiiltddemo3.service-now.com/now/nav/ui/classic/params/target/sn_devops_config_validate_list.do
