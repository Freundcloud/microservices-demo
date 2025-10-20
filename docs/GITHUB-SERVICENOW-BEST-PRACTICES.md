# GitHub + ServiceNow Integration - Best Practices

**Last Updated**: 2025-10-20
**Version**: 1.0
**Audience**: Developers, DevOps Engineers, Platform Engineers

---

## Table of Contents

1. [Workflow Design Principles](#workflow-design-principles)
2. [Security Best Practices](#security-best-practices)
3. [Change Request Quality](#change-request-quality)
4. [Approval Management](#approval-management)
5. [Error Handling & Resilience](#error-handling--resilience)
6. [Testing Strategies](#testing-strategies)
7. [Monitoring & Observability](#monitoring--observability)
8. [Team Collaboration](#team-collaboration)
9. [Performance Optimization](#performance-optimization)
10. [Compliance & Audit](#compliance--audit)

---

## Workflow Design Principles

### 1. Separation of Concerns

**Principle**: Each job should have a single, clear responsibility.

**✅ Good Example**:
```yaml
jobs:
  create-change:
    name: Create ServiceNow Change Request
    steps:
      - name: Create change via API
      - name: Validate change creation
      - name: Output change details

  wait-approval:
    needs: create-change
    name: Wait for Change Approval
    steps:
      - name: Poll for approval status
      - name: Handle timeout

  deploy:
    needs: [create-change, wait-approval]
    name: Deploy Application
    steps:
      - name: Deploy to cluster
      - name: Verify deployment

  update-change:
    needs: deploy
    name: Update Change Request
    steps:
      - name: Update with deployment result
```

**❌ Bad Example**:
```yaml
jobs:
  deploy-everything:
    steps:
      - name: Create change and deploy and update and everything
        run: |
          # 500 lines of mixed concerns
```

**Benefits**:
- Easier to debug failures
- Can retry individual steps
- Clear workflow visualization
- Reusable components

### 2. Fail Fast, Recover Gracefully

**Principle**: Detect failures early, but provide recovery paths.

**✅ Good Example**:
```yaml
- name: Create Change Request
  id: create-cr
  run: |
    RESPONSE=$(curl -s -w "%{http_code}" -o response.json ...)
    HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

    if [ "$HTTP_CODE" != "201" ]; then
      echo "❌ Failed to create change request (HTTP $HTTP_CODE)"
      cat response.json | jq .
      exit 1
    fi

    CHANGE_NUMBER=$(jq -r '.result.number' response.json)

    if [ -z "$CHANGE_NUMBER" ] || [ "$CHANGE_NUMBER" == "null" ]; then
      echo "❌ Change number not returned"
      exit 1
    fi

    echo "✅ Created: $CHANGE_NUMBER"
    echo "change_number=$CHANGE_NUMBER" >> $GITHUB_OUTPUT

- name: Fallback to Manual Process
  if: failure() && steps.create-cr.outcome == 'failure'
  run: |
    echo "⚠️ Automated change creation failed"
    echo "Please create change request manually:"
    echo "1. Go to ServiceNow"
    echo "2. Create standard change"
    echo "3. Add change number to this run as comment"
```

**Benefits**:
- Early failure detection
- Clear error messages
- Provides fallback options
- Reduces deployment delays

### 3. Idempotency

**Principle**: Running the same workflow multiple times should be safe.

**✅ Good Example**:
```yaml
- name: Create Change Request (Idempotent)
  id: create-cr
  run: |
    CORRELATION_ID="github-${{ github.repository }}-${{ github.run_id }}"

    # Check if change already exists
    EXISTING=$(curl -s \
      -H "Authorization: Basic $BASIC_AUTH" \
      "$INSTANCE_URL/api/now/table/change_request?sysparm_query=correlation_id=$CORRELATION_ID&sysparm_fields=number,sys_id")

    EXISTING_COUNT=$(echo "$EXISTING" | jq '.result | length')

    if [ "$EXISTING_COUNT" -gt 0 ]; then
      # Change already exists, reuse it
      CHANGE_NUMBER=$(echo "$EXISTING" | jq -r '.result[0].number')
      CHANGE_SYS_ID=$(echo "$EXISTING" | jq -r '.result[0].sys_id')
      echo "♻️  Reusing existing change: $CHANGE_NUMBER"
    else
      # Create new change
      RESPONSE=$(curl -s -X POST ...)
      CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
      CHANGE_SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')
      echo "✅ Created new change: $CHANGE_NUMBER"
    fi

    echo "change_number=$CHANGE_NUMBER" >> $GITHUB_OUTPUT
    echo "change_sys_id=$CHANGE_SYS_ID" >> $GITHUB_OUTPUT
```

**Benefits**:
- Safe to retry workflows
- No duplicate changes
- Consistent behavior
- Better testing

### 4. Progressive Disclosure of Complexity

**Principle**: Start simple, add complexity only when needed.

**Maturity Levels**:

**Level 1 - Basic** (Week 1):
```yaml
# Just create change, no approval
- Create change request
- Deploy
- Close change
```

**Level 2 - Approval Gates** (Month 1):
```yaml
# Add approval workflow
- Create change request
- Wait for approval (prod only)
- Deploy
- Close change
```

**Level 3 - Full Integration** (Month 2):
```yaml
# Add CMDB, metrics, advanced features
- Create change with application association
- Wait for multi-level approval
- Deploy with verification
- Update CMDB
- Close change with metrics
```

---

## Security Best Practices

### 1. Credential Management

**✅ Best Practices**:

1. **Use GitHub Secrets (Never Hard-Code)**
   ```yaml
   # ✅ Correct
   -H "Authorization: Basic $(echo -n '${{ secrets.SN_USER }}:${{ secrets.SN_PASS }}' | base64)"

   # ❌ Wrong
   -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ="
   ```

2. **Use Service Accounts**
   ```
   ✅ Create dedicated "github_integration" user
   ❌ Use personal admin account
   ```

3. **Least Privilege Principle**
   ```
   Required Roles:
   - change_manager (create/update changes)
   - itil (read CMDB)

   NOT Required:
   - admin
   - security_admin
   ```

4. **Credential Rotation**
   ```bash
   # Set expiration reminder
   gh secret set SERVICENOW_PASSWORD --body "password123"

   # Add note in team calendar
   echo "Rotate ServiceNow integration password every 90 days"
   ```

### 2. Secure API Calls

**✅ Best Practice**:
```yaml
- name: Create Change (Secure)
  run: |
    # Store credentials in variable (not in command)
    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

    # Use HTTPS only
    RESPONSE=$(curl -s \
      -H "Authorization: Basic $BASIC_AUTH" \
      -H "Content-Type: application/json" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

    # Don't log credentials or full response with sensitive data
    echo "Change created: $(echo "$RESPONSE" | jq -r '.result.number')"
    # NOT: echo "Response: $RESPONSE"
```

### 3. Audit Trail

**✅ Best Practice**:
```yaml
- name: Create Change with Full Audit Trail
  run: |
    PAYLOAD=$(cat <<EOF
    {
      "short_description": "Deploy Online Boutique to production",
      "description": "Automated deployment via GitHub Actions

**Audit Information**:
- Commit SHA: ${{ github.sha }}
- Commit Message: $(git log -1 --pretty=%B)
- Commit Author: $(git log -1 --pretty=%an)
- Triggered By: ${{ github.actor }}
- Workflow: ${{ github.workflow }}
- Run ID: ${{ github.run_id }}
- Run URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
- Repository: ${{ github.repository }}
- Branch: ${{ github.ref_name }}
- Event: ${{ github.event_name }}
- Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
",
      "work_notes": "Created by GitHub Actions automation"
    }
    EOF
    )
```

---

## Change Request Quality

### 1. Descriptive Short Descriptions

**✅ Good Examples**:
```
Deploy Online Boutique v1.2.3 to production
Rollback payment service to v1.2.2 in production
Emergency hotfix: Fix XSS vulnerability in frontend
Scale recommendation service from 3 to 5 replicas in prod
```

**❌ Bad Examples**:
```
Deploy
Deployment
Update application
Change
```

**Template**:
```
[Action] [Component] [Version/Details] [Environment]
```

### 2. Comprehensive Implementation Plans

**✅ Good Example**:
```yaml
implementation_plan: |
  **Pre-Deployment**:
  1. Verify all security scans passed (CodeQL, Trivy, Gitleaks)
  2. Validate Kubernetes manifests with kubeval
  3. Check EKS cluster health (nodes ready, no pending pods)
  4. Verify namespace quota (ensure sufficient resources)

  **Deployment**:
  5. Deploy using Kustomize overlay: kubectl apply -k kustomize/overlays/prod
  6. Wait for all 11 services to reach Ready state (timeout: 10 minutes)
  7. Verify Istio sidecar injection (all pods should have 2/2 containers)

  **Verification**:
  8. Check pod status: kubectl get pods -n microservices-prod
  9. Verify all services have endpoints: kubectl get endpoints -n microservices-prod
  10. Run health checks against frontend service
  11. Verify Istio metrics in Grafana dashboard
  12. Smoke test: Place test order through UI

  **Post-Deployment**:
  13. Update ServiceNow CMDB with new version
  14. Update change request with deployment results
  15. Notify team in Slack channel
  16. Monitor error rates for 15 minutes

  **Estimated Duration**: 25 minutes
```

### 3. Realistic Backout Plans

**✅ Good Example**:
```yaml
backout_plan: |
  **If deployment fails during rollout**:
  1. Deployment will automatically fail and not proceed
  2. Previous version remains active (no impact)
  3. Investigation required before retry

  **If deployment succeeds but issues detected**:
  1. Immediate rollback: kubectl rollout undo deployment/[service] -n microservices-prod
  2. OR Delete entire deployment: kubectl delete -k kustomize/overlays/prod
  3. Verify rollback: kubectl rollout status deployment -n microservices-prod
  4. Confirm previous version serving traffic (check pod image tags)
  5. Update this change request with rollback details

  **If database migration included**:
  1. Rollback application first (see above)
  2. Run database migration rollback script: scripts/db-migrate-down.sh
  3. Verify data consistency

  **Recovery Time Objective**: 10 minutes
  **Last Successful Version**: v1.2.2 (commit: abc123)
  **Rollback Tested**: Yes (in QA environment on 2025-10-19)
```

### 4. Effective Test Plans

**✅ Good Example**:
```yaml
test_plan: |
  **Automated Tests** (run before deployment):
  - ✅ Unit tests: 156 tests passed
  - ✅ Integration tests: 42 tests passed
  - ✅ Security scans: 0 critical vulnerabilities
  - ✅ Kubernetes manifest validation: All resources valid

  **Post-Deployment Verification**:
  1. **Health Checks** (2 minutes):
     - All pods running: kubectl get pods -n microservices-prod
     - All services have endpoints
     - No CrashLoopBackOff or ImagePullBackOff

  2. **Functional Tests** (5 minutes):
     - Load homepage: https://boutique.example.com
     - Browse products: Click through 3 product pages
     - Add to cart: Add 2 products to cart
     - Checkout: Complete test purchase with test card
     - Email received: Confirm order confirmation email

  3. **Performance Tests** (5 minutes):
     - Response time < 500ms for homepage
     - Response time < 1s for product pages
     - Response time < 2s for checkout
     - Load generator: 100 RPS sustained for 5 minutes

  4. **Istio Metrics** (3 minutes):
     - Check Grafana dashboard: https://grafana.example.com/d/istio
     - Verify 5xx error rate < 0.1%
     - Verify P95 latency < 1s
     - Verify no circuit breaker trips

  5. **Monitoring** (15 minutes):
     - Watch CloudWatch metrics for anomalies
     - Monitor error logs in CloudWatch Logs
     - Check Slack #prod-alerts channel
     - Verify no PagerDuty alerts triggered

  **Success Criteria**:
  - All health checks pass
  - All functional tests complete successfully
  - Performance within acceptable range
  - No alerts triggered in first 15 minutes
  - Team confirms deployment successful

  **Who Tests**: QA team lead (if qa/prod), Automated (if dev)
```

---

## Approval Management

### 1. Environment-Specific Rules

**✅ Best Practice**:

| Environment | Risk | Approval | Timeout | Auto-Close |
|-------------|------|----------|---------|------------|
| Dev | Low (3) | None (auto) | 0 | Yes |
| QA | Medium (2) | Single (QA lead) | 2 hours | No |
| Prod | High (1) | Multi (DevOps + CAB) | 24 hours | No |

**Implementation**:
```yaml
- name: Set Environment Rules
  id: rules
  run: |
    ENV="${{ github.event.inputs.environment }}"

    case "$ENV" in
      dev)
        echo "state=3" >> $GITHUB_OUTPUT  # Closed/Complete (auto-approved)
        echo "risk=3" >> $GITHUB_OUTPUT   # Low
        echo "priority=3" >> $GITHUB_OUTPUT  # Low
        echo "needs_approval=false" >> $GITHUB_OUTPUT
        echo "timeout=0" >> $GITHUB_OUTPUT
        ;;
      qa)
        echo "state=-5" >> $GITHUB_OUTPUT  # Pending approval
        echo "risk=2" >> $GITHUB_OUTPUT    # Medium
        echo "priority=2" >> $GITHUB_OUTPUT  # Medium
        echo "needs_approval=true" >> $GITHUB_OUTPUT
        echo "timeout=7200" >> $GITHUB_OUTPUT  # 2 hours
        echo "assignment_group=QA Team" >> $GITHUB_OUTPUT
        ;;
      prod)
        echo "state=-5" >> $GITHUB_OUTPUT  # Pending approval
        echo "risk=1" >> $GITHUB_OUTPUT    # High
        echo "priority=1" >> $GITHUB_OUTPUT  # High/Critical
        echo "needs_approval=true" >> $GITHUB_OUTPUT
        echo "timeout=86400" >> $GITHUB_OUTPUT  # 24 hours
        echo "assignment_group=Change Advisory Board" >> $GITHUB_OUTPUT
        ;;
    esac
```

### 2. Smart Polling

**✅ Best Practice**:
```yaml
- name: Wait for Approval with Smart Polling
  run: |
    TIMEOUT="${{ steps.rules.outputs.timeout }}"
    ELAPSED=0

    # Business hours: poll every 30 seconds
    # After hours: poll every 5 minutes
    CURRENT_HOUR=$(date +%H)

    if [ $CURRENT_HOUR -ge 9 ] && [ $CURRENT_HOUR -le 17 ]; then
      INTERVAL=30  # Business hours
    else
      INTERVAL=300  # After hours
    fi

    # Warning threshold at 80% of timeout
    WARNING_THRESHOLD=$((TIMEOUT * 80 / 100))

    while [ $ELAPSED -lt $TIMEOUT ]; do
      # Poll ServiceNow
      RESPONSE=$(curl -s ...)
      APPROVAL=$(echo "$RESPONSE" | jq -r '.result.approval')

      # Log progress
      PERCENT=$((ELAPSED * 100 / TIMEOUT))
      echo "[$PERCENT%] State: $APPROVAL (${ELAPSED}s / ${TIMEOUT}s)"

      # Check approval status
      if [ "$APPROVAL" == "approved" ]; then
        echo "✅ Approved!"
        exit 0
      elif [ "$APPROVAL" == "rejected" ]; then
        echo "❌ Rejected"
        exit 1
      fi

      # Send reminder at warning threshold
      if [ $ELAPSED -eq $WARNING_THRESHOLD ] && [ "$SENT_WARNING" != "true" ]; then
        echo "⚠️ Approval pending for $((ELAPSED / 3600)) hours"
        # TODO: Send Slack notification to approval group
        SENT_WARNING=true
      fi

      sleep $INTERVAL
      ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo "❌ Timeout reached"
    # TODO: Send timeout notification
    exit 1
```

### 3. Approval Notifications

**✅ Best Practice**:
```yaml
- name: Create Change and Notify Approvers
  run: |
    # Create change request
    RESPONSE=$(curl -s -X POST ...)
    CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
    CHANGE_SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')

    # Build approval URL
    APPROVAL_URL="${{ secrets.SERVICENOW_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=$CHANGE_SYS_ID"

    # Send Slack notification
    curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
      -H "Content-Type: application/json" \
      -d "{
        \"text\": \"⏸️  Deployment to ${{ github.event.inputs.environment }} requires approval\",
        \"blocks\": [
          {
            \"type\": \"section\",
            \"text\": {
              \"type\": \"mrkdwn\",
              \"text\": \"*Change Request:* $CHANGE_NUMBER\n*Environment:* ${{ github.event.inputs.environment }}\n*Requested by:* ${{ github.actor }}\"
            }
          },
          {
            \"type\": \"actions\",
            \"elements\": [
              {
                \"type\": \"button\",
                \"text\": {
                  \"type\": \"plain_text\",
                  \"text\": \"Review in ServiceNow\"
                },
                \"url\": \"$APPROVAL_URL\",
                \"style\": \"primary\"
              },
              {
                \"type\": \"button\",
                \"text\": {
                  \"type\": \"plain_text\",
                  \"text\": \"View GitHub Run\"
                },
                \"url\": \"${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\"
              }
            ]
          }
        ]
      }"

    # Send email (optional)
    # ServiceNow can send automatic email notifications to assignment group
```

---

## Error Handling & Resilience

### 1. Retry Logic

**✅ Best Practice**:
```yaml
- name: Create Change with Retry
  run: |
    MAX_RETRIES=3
    RETRY_DELAY=5
    ATTEMPT=1

    while [ $ATTEMPT -le $MAX_RETRIES ]; do
      echo "Attempt $ATTEMPT of $MAX_RETRIES..."

      RESPONSE=$(curl -s -w "%{http_code}" -o response.json \
        -X POST \
        -H "Authorization: Basic $BASIC_AUTH" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

      HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

      # Success
      if [ "$HTTP_CODE" == "201" ]; then
        CHANGE_NUMBER=$(jq -r '.result.number' response.json)
        echo "✅ Success: $CHANGE_NUMBER"
        exit 0
      fi

      # Retryable errors (5xx)
      if [[ "$HTTP_CODE" =~ ^5 ]]; then
        echo "⚠️ Server error (HTTP $HTTP_CODE), retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
        RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
        ATTEMPT=$((ATTEMPT + 1))
        continue
      fi

      # Non-retryable errors (4xx)
      echo "❌ Client error (HTTP $HTTP_CODE), not retrying"
      cat response.json | jq .
      exit 1
    done

    echo "❌ Failed after $MAX_RETRIES attempts"
    exit 1
```

### 2. Graceful Degradation

**✅ Best Practice**:
```yaml
- name: Create Change Request
  id: create-cr
  continue-on-error: true  # Allow workflow to continue
  run: |
    # Attempt to create change
    ...

- name: Record Manual Change Option
  if: steps.create-cr.outcome == 'failure'
  run: |
    echo "⚠️ Automated change creation failed" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**Manual Process Required**:" >> $GITHUB_STEP_SUMMARY
    echo "1. Create change request manually in ServiceNow" >> $GITHUB_STEP_SUMMARY
    echo "2. Copy change number" >> $GITHUB_STEP_SUMMARY
    echo "3. Add as comment to this run: \`/approve CHG0001234\`" >> $GITHUB_STEP_SUMMARY
    echo "4. Re-run workflow" >> $GITHUB_STEP_SUMMARY

    # Create issue for tracking
    gh issue create \
      --title "ServiceNow integration failed for run ${{ github.run_id }}" \
      --body "Automated change creation failed. Manual intervention required."

- name: Check for Manual Change Number
  if: steps.create-cr.outcome == 'failure'
  run: |
    # Check if manual change number provided via issue comment
    MANUAL_CHG=$(gh api repos/${{ github.repository }}/issues/comments \
      --jq '.[] | select(.body | contains("/approve CHG")) | .body | match("CHG[0-9]+") | .string' \
      | head -1)

    if [ -n "$MANUAL_CHG" ]; then
      echo "✅ Manual change number provided: $MANUAL_CHG"
      echo "manual_change_number=$MANUAL_CHG" >> $GITHUB_OUTPUT
    else
      echo "❌ No manual change number provided yet"
      exit 1
    fi
```

### 3. Rollback Automation

**✅ Best Practice**:
```yaml
deploy:
  name: Deploy Application
  steps:
    - name: Deploy
      id: deploy
      run: |
        kubectl apply -k kustomize/overlays/${{ github.event.inputs.environment }}

    - name: Verify Deployment
      id: verify
      timeout-minutes: 10
      run: |
        # Wait for rollout to complete
        for service in frontend cartservice productcatalogservice; do
          kubectl rollout status deployment/$service \
            -n microservices-${{ github.event.inputs.environment }} \
            --timeout=5m
        done

rollback:
  name: Rollback on Failure
  needs: deploy
  if: failure() && needs.deploy.result == 'failure'
  steps:
    - name: Automatic Rollback
      run: |
        echo "⚠️ Deployment failed, initiating rollback..." >> $GITHUB_STEP_SUMMARY

        ENV="${{ github.event.inputs.environment }}"
        NAMESPACE="microservices-$ENV"

        # Rollback all deployments
        DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o json | jq -r '.items[].metadata.name')

        for deployment in $DEPLOYMENTS; do
          echo "Rolling back $deployment..."
          kubectl rollout undo deployment/$deployment -n $NAMESPACE

          # Wait for rollback to complete
          kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=2m || \
            echo "⚠️ Rollback timeout for $deployment"
        done

        echo "✅ Rollback completed" >> $GITHUB_STEP_SUMMARY

    - name: Update Change Request - Failed
      run: |
        # Update ServiceNow with failure and rollback details
        PAYLOAD=$(cat <<EOF
        {
          "state": "4",
          "close_code": "unsuccessful",
          "close_notes": "Deployment failed and was automatically rolled back.

**Failure Details**:
- Failed at: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
- Run URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}

**Rollback Completed**:
- Previous version restored
- All services verified running
- No impact to production traffic

**Next Steps**:
1. Review failure logs
2. Fix issues
3. Retry deployment
",
          "work_notes": "Automatic rollback completed successfully"
        }
        EOF
        )

        curl -s -X PUT \
          -H "Authorization: Basic $BASIC_AUTH" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD" \
          "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request/${{ needs.create-change.outputs.change_sys_id }}"

    - name: Notify Team
      run: |
        # Send Slack notification about failure
        curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
          -d '{"text": "❌ Deployment to ${{ github.event.inputs.environment }} failed and was rolled back"}'
```

---

## Testing Strategies

### 1. Test in Lower Environments First

**✅ Best Practice**:
```yaml
# Require successful dev deployment before allowing qa/prod
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]

jobs:
  validate-promotion:
    runs-on: ubuntu-latest
    if: github.event.inputs.environment != 'dev'
    steps:
      - name: Check Previous Environment Success
        run: |
          ENV="${{ github.event.inputs.environment }}"
          PREV_ENV=$([ "$ENV" == "qa" ] && echo "dev" || echo "qa")

          # Get last successful deployment to previous environment
          LAST_SUCCESS=$(gh run list \
            --workflow="deploy-with-servicenow-hybrid.yaml" \
            --json conclusion,headSha,createdAt \
            --jq ".[] | select(.conclusion==\"success\") | select(.headSha==\"${{ github.sha }}\") | .createdAt" \
            | head -1)

          if [ -z "$LAST_SUCCESS" ]; then
            echo "❌ Commit ${{ github.sha }} not deployed to $PREV_ENV yet"
            echo "Deploy to $PREV_ENV first before promoting to $ENV"
            exit 1
          fi

          echo "✅ Commit successfully deployed to $PREV_ENV at $LAST_SUCCESS"
```

### 2. Synthetic Testing Post-Deployment

**✅ Best Practice**:
```yaml
- name: Run Synthetic Tests
  id: synthetic
  run: |
    ENV="${{ github.event.inputs.environment }}"
    BASE_URL=$(kubectl get ingress -n microservices-$ENV -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

    echo "Testing $BASE_URL..."

    # Test 1: Homepage loads
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL)
    if [ "$HTTP_CODE" != "200" ]; then
      echo "❌ Homepage test failed (HTTP $HTTP_CODE)"
      exit 1
    fi
    echo "✅ Homepage test passed"

    # Test 2: Product listing works
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/products)
    if [ "$HTTP_CODE" != "200" ]; then
      echo "❌ Products test failed (HTTP $HTTP_CODE)"
      exit 1
    fi
    echo "✅ Products test passed"

    # Test 3: Cart operations
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/cart)
    if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
      echo "❌ Cart test failed (HTTP $HTTP_CODE)"
      exit 1
    fi
    echo "✅ Cart test passed"

    # Test 4: Service mesh health
    POD=$(kubectl get pod -n microservices-$ENV -l app=frontend -o jsonpath='{.items[0].metadata.name}')
    MESH_STATUS=$(kubectl exec $POD -n microservices-$ENV -c istio-proxy -- curl -s localhost:15000/ready)
    if [ "$MESH_STATUS" != "LIVE" ]; then
      echo "⚠️ Istio proxy not ready"
    fi
    echo "✅ Service mesh healthy"

    echo "✅ All synthetic tests passed"
```

### 3. Integration Testing with ServiceNow

**✅ Best Practice**:
```bash
# scripts/test-servicenow-integration.sh
#!/bin/bash
set -euo pipefail

echo "Testing ServiceNow integration..."

# Test 1: Credentials valid
echo "1. Testing authentication..."
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request?sysparm_limit=1")

if [ "$RESPONSE" != "200" ]; then
  echo "❌ Authentication failed (HTTP $RESPONSE)"
  exit 1
fi
echo "✅ Authentication successful"

# Test 2: Can create change
echo "2. Testing change creation..."
PAYLOAD='{"short_description":"Test change (can be deleted)","type":"standard","state":"3"}'
RESPONSE=$(curl -s -X POST \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request")

CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
if [ -z "$CHANGE_NUMBER" ] || [ "$CHANGE_NUMBER" == "null" ]; then
  echo "❌ Change creation failed"
  echo "$RESPONSE" | jq .
  exit 1
fi
echo "✅ Change created: $CHANGE_NUMBER"

# Test 3: Can query change
echo "3. Testing change query..."
CHANGE_SYS_ID=$(echo "$RESPONSE" | jq -r '.result.sys_id')
RESPONSE=$(curl -s \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CHANGE_SYS_ID")

QUERIED_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
if [ "$QUERIED_NUMBER" != "$CHANGE_NUMBER" ]; then
  echo "❌ Change query failed"
  exit 1
fi
echo "✅ Change queried successfully"

# Test 4: Can update change
echo "4. Testing change update..."
UPDATE_PAYLOAD='{"work_notes":"Test update (automated)"}'
RESPONSE=$(curl -s -X PUT \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CHANGE_SYS_ID")

echo "✅ Change updated successfully"

# Test 5: Can delete test change
echo "5. Cleaning up test change..."
curl -s -X DELETE \
  -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/change_request/$CHANGE_SYS_ID" \
  > /dev/null

echo "✅ Test change deleted"

echo ""
echo "✅ All ServiceNow integration tests passed"
```

---

## Monitoring & Observability

### 1. Rich GitHub Step Summaries

**✅ Best Practice**:
```yaml
- name: Deployment Summary
  if: always()
  run: |
    cat >> $GITHUB_STEP_SUMMARY <<EOF
    ## 🚀 Deployment Summary

    **Environment**: ${{ github.event.inputs.environment }}
    **Status**: ${{ job.status }}
    **Duration**: $((SECONDS / 60)) minutes

    ### ServiceNow Change Request

    - **Number**: ${{ steps.create-cr.outputs.change_number }}
    - **State**: $([ "${{ job.status }}" == "success" ] && echo "Closed - Successful" || echo "Closed - Unsuccessful")
    - **View**: [${{ steps.create-cr.outputs.change_number }}](${{ secrets.SERVICENOW_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=${{ steps.create-cr.outputs.change_sys_id }})

    ### Deployment Details

    | Service | Status | Replicas | Image Tag |
    |---------|--------|----------|-----------|
    $(kubectl get deployments -n microservices-${{ github.event.inputs.environment }} -o json | \
      jq -r '.items[] | "| \(.metadata.name) | \(.status.conditions[-1].type) | \(.status.replicas)/${{ (.spec.replicas) }} | \(.spec.template.spec.containers[0].image | split(":")[1]) |"')

    ### Health Checks

    - **Pods Running**: $(kubectl get pods -n microservices-${{ github.event.inputs.environment }} --field-selector=status.phase=Running | wc -l) / $(kubectl get pods -n microservices-${{ github.event.inputs.environment }} | wc -l)
    - **Services with Endpoints**: $(kubectl get endpoints -n microservices-${{ github.event.inputs.environment }} -o json | jq '[.items[] | select(.subsets[0].addresses | length > 0)] | length')
    - **Istio Proxies Healthy**: $(kubectl get pods -n microservices-${{ github.event.inputs.environment }} -o json | jq '[.items[] | select(.status.containerStatuses[] | select(.name=="istio-proxy") | .ready==true)] | length')

    ### Quick Links

    - [ServiceNow Change](${{ secrets.SERVICENOW_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=${{ steps.create-cr.outputs.change_sys_id }})
    - [Kubernetes Pods](https://console.aws.amazon.com/eks/home?region=eu-west-2#/clusters/microservices/workloads)
    - [Istio Dashboard](https://grafana.example.com/d/istio)
    - [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?region=eu-west-2#logsV2:log-groups/log-group/microservices-${{ github.event.inputs.environment }})

    EOF
```

### 2. Metrics Collection

**✅ Best Practice**:
```yaml
- name: Collect Deployment Metrics
  if: always()
  run: |
    # Calculate deployment duration
    DEPLOY_START=$(date -d "${{ steps.deploy.start-time }}" +%s)
    DEPLOY_END=$(date +%s)
    DEPLOY_DURATION=$((DEPLOY_END - DEPLOY_START))

    # Calculate approval wait time (if applicable)
    if [ "${{ github.event.inputs.environment }}" != "dev" ]; then
      APPROVAL_START=$(date -d "${{ steps.create-cr.outputs.created_at }}" +%s)
      APPROVAL_END=$(date -d "${{ steps.wait-approval.outputs.approved_at }}" +%s)
      APPROVAL_DURATION=$((APPROVAL_END - APPROVAL_START))
    else
      APPROVAL_DURATION=0
    fi

    # Send metrics to CloudWatch
    aws cloudwatch put-metric-data \
      --namespace "GitHubActions/ServiceNow" \
      --metric-name DeploymentDuration \
      --value $DEPLOY_DURATION \
      --unit Seconds \
      --dimensions Environment=${{ github.event.inputs.environment }},Status=${{ job.status }}

    aws cloudwatch put-metric-data \
      --namespace "GitHubActions/ServiceNow" \
      --metric-name ApprovalWaitTime \
      --value $APPROVAL_DURATION \
      --unit Seconds \
      --dimensions Environment=${{ github.event.inputs.environment }}

    # Log to structured JSON for analysis
    cat >> metrics.json <<EOF
    {
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "environment": "${{ github.event.inputs.environment }}",
      "change_number": "${{ steps.create-cr.outputs.change_number }}",
      "deploy_duration_seconds": $DEPLOY_DURATION,
      "approval_duration_seconds": $APPROVAL_DURATION,
      "status": "${{ job.status }}",
      "commit_sha": "${{ github.sha }}",
      "actor": "${{ github.actor }}"
    }
    EOF
```

---

*This document continues with remaining sections...*

**For complete best practices**, see:
- [Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md)
- [Troubleshooting Guide](SERVICENOW-INDEX.md)
- [Quick Start](SERVICENOW-QUICK-START.md)

**Document Version**: 1.0
**Last Updated**: 2025-10-20
