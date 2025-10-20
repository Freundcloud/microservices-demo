# GitHub + ServiceNow Integration - Antipatterns

**Last Updated**: 2025-10-20
**Version**: 1.0
**Purpose**: Learn from common mistakes to avoid pitfalls

---

## Table of Contents

1. [Workflow Design Antipatterns](#workflow-design-antipatterns)
2. [Security Antipatterns](#security-antipatterns)
3. [Change Management Antipatterns](#change-management-antipatterns)
4. [Approval Workflow Antipatterns](#approval-workflow-antipatterns)
5. [Error Handling Antipatterns](#error-handling-antipatterns)
6. [Testing Antipatterns](#testing-antipatterns)
7. [Performance Antipatterns](#performance-antipatterns)
8. [Documentation Antipatterns](#documentation-antipatterns)

---

## Workflow Design Antipatterns

### 🚫 Antipattern 1: The Monolithic Workflow

**❌ What It Looks Like**:
```yaml
name: Do Everything

jobs:
  mega-job:
    runs-on: ubuntu-latest
    steps:
      - name: Do absolutely everything
        run: |
          # 1000 lines of bash that:
          # - Creates change request
          # - Waits for approval
          # - Builds application
          # - Runs tests
          # - Deploys to cluster
          # - Updates CMDB
          # - Closes change request
          # - Sends notifications
          # ... and more
```

**Why It's Bad**:
- ❌ Impossible to debug when it fails
- ❌ Can't retry individual steps
- ❌ No visibility into progress
- ❌ Violates single responsibility principle
- ❌ Can't reuse components

**✅ Better Approach**:
```yaml
jobs:
  create-change:
    name: Create ServiceNow Change
    steps:
      - name: Create change request
      - name: Validate creation
      - name: Output change details

  wait-approval:
    needs: create-change
    name: Wait for Approval
    if: needs.create-change.outputs.needs_approval == 'true'
    steps:
      - name: Poll for approval

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
      - name: Update with results
```

---

### 🚫 Antipattern 2: The "Fire and Forget" Integration

**❌ What It Looks Like**:
```yaml
- name: Create Change and Deploy
  run: |
    # Create change request
    curl -X POST ... # Returns change number

    # Immediately deploy without checking approval
    kubectl apply -f manifests/

    # Mark as complete
    curl -X PUT ... -d '{"state": "3"}'
```

**Why It's Bad**:
- ❌ Completely defeats the purpose of change management
- ❌ No approval enforcement
- ❌ Compliance violation
- ❌ Audit trail is meaningless
- ❌ No risk management

**✅ Better Approach**:
```yaml
- name: Create Change Request
  id: create
  run: |
    # Create and capture details
    ...

- name: Wait for Approval
  run: |
    # Poll until approved or timeout
    while true; do
      STATUS=$(get approval status)
      if [ "$STATUS" == "approved" ]; then
        break
      fi
      sleep 30
    done

- name: Deploy (Only After Approval)
  run: |
    kubectl apply -f manifests/
```

---

### 🚫 Antipattern 3: The Copy-Paste Workflow

**❌ What It Looks Like**:
```yaml
# deploy-dev.yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Create change
        run: |
          curl -X POST ... # Hardcoded for dev

# deploy-qa.yaml (exact copy with minor changes)
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Create change
        run: |
          curl -X POST ... # Hardcoded for qa

# deploy-prod.yaml (exact copy with minor changes)
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Create change
        run: |
          curl -X POST ... # Hardcoded for prod
```

**Why It's Bad**:
- ❌ Violates DRY principle
- ❌ Bug fixes must be applied three times
- ❌ Inconsistencies creep in over time
- ❌ Difficult to maintain
- ❌ Testing is 3x the effort

**✅ Better Approach**:
```yaml
# deploy-multi-env.yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Set environment-specific settings
        id: settings
        run: |
          case "${{ github.event.inputs.environment }}" in
            dev) echo "state=3" >> $GITHUB_OUTPUT ;;
            qa) echo "state=-5" >> $GITHUB_OUTPUT ;;
            prod) echo "state=-5" >> $GITHUB_OUTPUT ;;
          esac

      - name: Create change
        run: |
          # Single workflow, environment-aware
          ...
```

---

## Security Antipatterns

### 🚫 Antipattern 4: The Credential Exposure

**❌ What It Looks Like**:
```yaml
- name: Create Change
  run: |
    # Credentials in plain text!
    curl -X POST \
      -u "admin:P@ssw0rd123" \
      https://instance.service-now.com/api/now/table/change_request

    # Or stored in repository
    PASSWORD="MySecretPassword"
    curl -u "user:$PASSWORD" ...

    # Or logged to output
    echo "Using credentials: $USERNAME:$PASSWORD"
```

**Why It's Bad**:
- ❌ Credentials exposed in workflow file
- ❌ Credentials in GitHub Actions logs
- ❌ Credentials in Git history
- ❌ Anyone with repo access can see them
- ❌ No rotation capability
- ❌ Severe security violation

**✅ Better Approach**:
```yaml
# Store in GitHub Secrets
# Settings > Secrets > Actions > New repository secret

- name: Create Change (Secure)
  run: |
    # Credentials from secrets
    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

    # Use in header (not logged)
    RESPONSE=$(curl -s \
      -H "Authorization: Basic $BASIC_AUTH" \
      ...)

    # Never echo credentials
    echo "Change created successfully"
    # NOT: echo "$RESPONSE" (might contain sensitive data)
```

---

### 🚫 Antipattern 5: The Over-Privileged Account

**❌ What It Looks Like**:
```
ServiceNow User: admin
Roles: admin, security_admin, user_admin, ...

# Used for everything including automation
```

**Why It's Bad**:
- ❌ Violates least privilege principle
- ❌ If compromised, full system access
- ❌ Can't audit what automation did vs human
- ❌ No separation of duties
- ❌ Compliance failure

**✅ Better Approach**:
```
ServiceNow User: github_integration
Roles (minimum required):
- change_manager (create/update changes)
- itil (read CMDB)

NOT required:
- admin
- security_admin
- user_admin
```

---

## Change Management Antipatterns

### 🚫 Antipattern 6: The Vague Change Description

**❌ What It Looks Like**:
```json
{
  "short_description": "Deploy",
  "description": "Deployment",
  "implementation_plan": "Deploy the application",
  "backout_plan": "Rollback",
  "test_plan": "Test it"
}
```

**Why It's Bad**:
- ❌ No context for approvers
- ❌ Can't understand impact
- ❌ Impossible to audit later
- ❌ Doesn't help with troubleshooting
- ❌ Looks unprofessional

**✅ Better Approach**:
```json
{
  "short_description": "Deploy Online Boutique v1.2.3 to production",
  "description": "Deploy Online Boutique microservices application version 1.2.3 to production EKS cluster\n\n**Changes**:\n- Frontend: Security fix for XSS vulnerability (CVE-2025-1234)\n- Payment service: Performance improvement (50% faster checkout)\n- Cart service: Bug fix for cart persistence\n\n**Impact**: All 11 microservices will be updated\n\n**Commit**: abc123def456\n**GitHub Run**: https://github.com/org/repo/actions/runs/123456\n**Triggered by**: john.doe",
  "implementation_plan": "1. Verify all security scans passed\n2. Deploy using Kustomize: kubectl apply -k kustomize/overlays/prod\n3. Wait for all services to reach Ready state (timeout: 10 minutes)\n4. Verify Istio sidecar injection\n5. Run smoke tests\n6. Monitor metrics for 15 minutes\nEstimated duration: 25 minutes",
  "backout_plan": "1. Rollback: kubectl rollout undo deployment -n microservices-prod\n2. Verify previous version (v1.2.2) active\n3. Confirm traffic serving correctly\n4. Update change request\nRTO: 10 minutes",
  "test_plan": "1. All pods running (11/11)\n2. Services have endpoints\n3. Homepage loads (< 500ms)\n4. Place test order successfully\n5. No errors in logs\n6. Istio metrics within thresholds"
}
```

---

### 🚫 Antipattern 7: The "One Size Fits All" Risk

**❌ What It Looks Like**:
```yaml
# Same risk and approval for all environments
- name: Create Change
  run: |
    curl -X POST ... -d '{
      "risk": "1",           # High risk
      "state": "-5",         # Pending approval
      "priority": "1"        # Critical
    }'

# Even for dev deployments!
```

**Why It's Bad**:
- ❌ Slows down dev iterations
- ❌ Requires approval for non-production
- ❌ Doesn't reflect actual risk
- ❌ Frustrates developers
- ❌ People start bypassing process

**✅ Better Approach**:
```yaml
- name: Set Risk Based on Environment
  run: |
    case "$ENV" in
      dev)
        RISK="3"    # Low
        STATE="3"   # Auto-approved
        PRIORITY="3"  # Low
        ;;
      qa)
        RISK="2"    # Medium
        STATE="-5"  # Pending
        PRIORITY="2"  # Medium
        ;;
      prod)
        RISK="1"    # High
        STATE="-5"  # Pending
        PRIORITY="1"  # Critical
        ;;
    esac
```

---

## Approval Workflow Antipatterns

### 🚫 Antipattern 8: The Infinite Timeout

**❌ What It Looks Like**:
```yaml
- name: Wait for Approval
  run: |
    while true; do
      STATUS=$(check approval)
      if [ "$STATUS" == "approved" ]; then
        break
      fi
      sleep 30
    done
    # No timeout! Runs forever!
```

**Why It's Bad**:
- ❌ Workflow can run indefinitely
- ❌ Wastes GitHub Actions minutes
- ❌ No escalation path
- ❌ Change requests abandoned in pending state
- ❌ No notification when stuck

**✅ Better Approach**:
```yaml
- name: Wait for Approval with Timeout
  run: |
    TIMEOUT=7200  # 2 hours for QA, 24 hours for prod
    ELAPSED=0
    INTERVAL=30

    while [ $ELAPSED -lt $TIMEOUT ]; do
      STATUS=$(check approval)
      if [ "$STATUS" == "approved" ]; then
        exit 0
      elif [ "$STATUS" == "rejected" ]; then
        exit 1
      fi

      # Warning at 80% of timeout
      if [ $ELAPSED -eq $((TIMEOUT * 80 / 100)) ]; then
        notify_approvers "Approval pending for $((ELAPSED / 3600)) hours"
      fi

      sleep $INTERVAL
      ELAPSED=$((ELAPSED + INTERVAL))
    done

    echo "Timeout reached after $((TIMEOUT / 3600)) hours"
    notify_approvers "Approval timeout - workflow failed"
    exit 1
```

---

### 🚫 Antipattern 9: The Aggressive Polling

**❌ What It Looks Like**:
```yaml
- name: Poll ServiceNow
  run: |
    while true; do
      STATUS=$(curl ... ) # Every 1 second!
      sleep 1
    done
```

**Why It's Bad**:
- ❌ Hammers ServiceNow API
- ❌ May hit rate limits
- ❌ Wastes resources
- ❌ Approver needs instant response (unrealistic)
- ❌ Can cause throttling

**✅ Better Approach**:
```yaml
- name: Poll with Reasonable Interval
  run: |
    INTERVAL=30  # 30 seconds during business hours

    # Adjust for after-hours
    HOUR=$(date +%H)
    if [ $HOUR -lt 9 ] || [ $HOUR -gt 17 ]; then
      INTERVAL=300  # 5 minutes after hours
    fi

    while [ $ELAPSED -lt $TIMEOUT ]; do
      STATUS=$(curl ...)
      # Check status...
      sleep $INTERVAL
    done
```

---

## Error Handling Antipatterns

### 🚫 Antipattern 10: The Silent Failure

**❌ What It Looks Like**:
```yaml
- name: Update Change Request
  run: |
    curl -X PUT ... > /dev/null 2>&1
    # Suppress all output, including errors!

- name: Create Change
  run: |
    RESPONSE=$(curl -X POST ...)
    # Assume it worked, don't check
    echo "Change created"
```

**Why It's Bad**:
- ❌ Hides API errors
- ❌ Leaves changes in wrong state
- ❌ No visibility into failures
- ❌ Difficult to troubleshoot
- ❌ False sense of success

**✅ Better Approach**:
```yaml
- name: Update Change Request
  run: |
    RESPONSE=$(curl -s -w "%{http_code}" -o response.json ...)
    HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

    if [ "$HTTP_CODE" != "200" ]; then
      echo "❌ Failed to update change (HTTP $HTTP_CODE)"
      cat response.json | jq .
      exit 1
    fi

    echo "✅ Change updated successfully"
    cat response.json | jq -r '.result | "Number: \(.number), State: \(.state)"'
```

---

### 🚫 Antipattern 11: The Assumed Success

**❌ What It Looks Like**:
```yaml
- name: Deploy Application
  run: |
    kubectl apply -f manifests/
    # Didn't check if it actually worked

- name: Mark Change as Successful
  run: |
    # Always mark as successful, even if deploy failed!
    curl -X PUT ... -d '{"state": "3", "close_code": "successful"}'
```

**Why It's Bad**:
- ❌ Reports success when deployment failed
- ❌ Incorrect audit trail
- ❌ Wrong DORA metrics
- ❌ No rollback triggered
- ❌ False confidence

**✅ Better Approach**:
```yaml
- name: Deploy Application
  id: deploy
  run: |
    kubectl apply -f manifests/

    # Wait for rollout to complete
    kubectl rollout status deployment/frontend --timeout=5m

- name: Update Change - Success
  if: success() && steps.deploy.outcome == 'success'
  run: |
    curl -X PUT ... -d '{"state": "3", "close_code": "successful"}'

- name: Update Change - Failed
  if: failure() || steps.deploy.outcome == 'failure'
  run: |
    curl -X PUT ... -d '{"state": "4", "close_code": "unsuccessful"}'
```

---

## Testing Antipatterns

### 🚫 Antipattern 12: The "Skip Testing" Shortcut

**❌ What It Looks Like**:
```yaml
# No testing workflow
- name: Create Change
- name: Deploy to Production
  run: kubectl apply -f manifests/
# Ship it! 🚀
```

**Why It's Bad**:
- ❌ No validation before production
- ❌ Breaks production regularly
- ❌ No confidence in deployments
- ❌ Difficult to isolate issues
- ❌ High change failure rate

**✅ Better Approach**:
```yaml
- name: Create Change
- name: Pre-Deployment Validation
  run: |
    # Validate manifests
    kubectl apply --dry-run=client -f manifests/
    kubeval manifests/*.yaml

    # Run unit tests
    npm test

    # Check security scans passed
    check_security_results

- name: Deploy to Dev First
  run: kubectl apply -k overlays/dev

- name: Run Integration Tests
  run: npm run test:integration

- name: Deploy to Production
  if: success()
  run: kubectl apply -k overlays/prod
```

---

### 🚫 Antipattern 13: The "Production is Staging"

**❌ What It Looks Like**:
```yaml
# Deploy directly to production for testing
- name: Deploy to Production
  run: kubectl apply -k overlays/prod

- name: Test in Production
  run: run_tests_against_prod
```

**Why It's Bad**:
- ❌ Uses customers as testers
- ❌ Breaks production service
- ❌ No safety net
- ❌ Violates change management principles
- ❌ Unprofessional

**✅ Better Approach**:
```yaml
- name: Deploy to Dev
  run: kubectl apply -k overlays/dev

- name: Test in Dev
  run: run_tests_against_dev

- name: Deploy to QA (if dev passed)
  run: kubectl apply -k overlays/qa

- name: QA Approval Required
  # Wait for QA team approval

- name: Deploy to Production (if QA approved)
  run: kubectl apply -k overlays/prod

- name: Production Smoke Tests Only
  run: run_minimal_smoke_tests
```

---

## Performance Antipatterns

### 🚫 Antipattern 14: The Synchronous Bottleneck

**❌ What It Looks Like**:
```yaml
jobs:
  deploy:
    steps:
      - name: Build service 1
      - name: Build service 2
      - name: Build service 3
      # ... 11 services built sequentially!
      - name: Deploy service 1
      - name: Deploy service 2
      # ... 11 services deployed sequentially!
```

**Why It's Bad**:
- ❌ Takes unnecessarily long
- ❌ Blocks on slow tasks
- ❌ Wastes GitHub Actions time
- ❌ Poor developer experience

**✅ Better Approach**:
```yaml
jobs:
  build:
    strategy:
      matrix:
        service: [frontend, cart, product, ...]
    steps:
      - name: Build ${{ matrix.service }}
        run: docker build ...

  deploy:
    needs: build
    steps:
      - name: Deploy all services
        run: kubectl apply -k overlays/prod
        # Kubernetes handles parallel deployment
```

---

## Documentation Antipatterns

### 🚫 Antipattern 15: The Undocumented Magic

**❌ What It Looks Like**:
```yaml
- name: Do the thing
  run: |
    # 200 lines of complex bash
    # No comments
    # No documentation
    # "It works on my machine"
```

**Why It's Bad**:
- ❌ No one else can maintain it
- ❌ Breaks when author leaves
- ❌ No onboarding possible
- ❌ Can't troubleshoot issues
- ❌ Knowledge silos

**✅ Better Approach**:
```yaml
- name: Create ServiceNow Change Request
  run: |
    # Purpose: Create a standard change request in ServiceNow for this deployment
    # Returns: change_number and change_sys_id as outputs
    # Requires: SERVICENOW_USERNAME, SERVICENOW_PASSWORD, SERVICENOW_INSTANCE_URL secrets

    # Build correlation ID for tracking (format: github-repo-run-id)
    CORRELATION_ID="github-${{ github.repository }}-${{ github.run_id }}"

    # Create payload with all required fields
    PAYLOAD=$(cat <<'EOF'
    {
      "short_description": "Deploy to ${{ github.event.inputs.environment }}",
      "correlation_id": "$CORRELATION_ID"
    }
    EOF
    )

    # Create basic auth header (base64 encoded username:password)
    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)

    # Call ServiceNow REST API
    RESPONSE=$(curl -s -X POST \
      -H "Authorization: Basic $BASIC_AUTH" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/change_request")

    # Extract and validate response
    CHANGE_NUMBER=$(echo "$RESPONSE" | jq -r '.result.number')
    if [ -z "$CHANGE_NUMBER" ] || [ "$CHANGE_NUMBER" == "null" ]; then
      echo "❌ Failed to create change request"
      echo "$RESPONSE" | jq .
      exit 1
    fi

    # Export for use in subsequent steps
    echo "change_number=$CHANGE_NUMBER" >> $GITHUB_OUTPUT
```

**Additional Documentation**:
```markdown
# docs/SERVICENOW-CHANGE-CREATION.md

## How Change Request Creation Works

This workflow creates a ServiceNow change request using the REST API...

## Required Secrets

- `SERVICENOW_INSTANCE_URL`: Your ServiceNow instance (e.g., https://dev12345.service-now.com)
- `SERVICENOW_USERNAME`: Service account username (e.g., github_integration)
- `SERVICENOW_PASSWORD`: Service account password

## Troubleshooting

### Error: "Required to provide Auth information"
**Cause**: Credentials missing or incorrect
**Solution**: Verify secrets are set correctly...
```

---

## Summary: Top 10 Worst Antipatterns

1. **🚫 Fire and Forget** - Creating changes but not waiting for approval
2. **🚫 Credential Exposure** - Hardcoding credentials in workflows
3. **🚫 Vague Changes** - "Deploy" with no details
4. **🚫 Infinite Timeout** - Waiting forever for approval
5. **🚫 Silent Failures** - Suppressing errors
6. **🚫 Assumed Success** - Not checking if deployment worked
7. **🚫 One Size Fits All** - Same rules for dev and prod
8. **🚫 Skip Testing** - Deploy directly to production
9. **🚫 Undocumented Magic** - Complex scripts with no documentation
10. **🚫 Over-Privileged Accounts** - Using admin for everything

---

## Antipattern Detection Checklist

Use this checklist to review your workflows:

### Security
- [ ] ❌ Credentials hardcoded in workflow?
- [ ] ❌ Credentials in repository variables?
- [ ] ❌ Credentials logged to output?
- [ ] ❌ Using admin account?
- [ ] ❌ Secrets not rotated regularly?

### Change Management
- [ ] ❌ Change descriptions too vague?
- [ ] ❌ No implementation plan?
- [ ] ❌ No backout plan?
- [ ] ❌ No test plan?
- [ ] ❌ Same risk for all environments?

### Approval Workflow
- [ ] ❌ No approval for production?
- [ ] ❌ Approval required for dev?
- [ ] ❌ No timeout configured?
- [ ] ❌ Polling too aggressively (< 15s)?
- [ ] ❌ No notification when stuck?

### Error Handling
- [ ] ❌ Errors suppressed or ignored?
- [ ] ❌ No validation of API responses?
- [ ] ❌ Assumes operations always succeed?
- [ ] ❌ No retry logic for transient failures?
- [ ] ❌ Leaves changes in wrong state?

### Testing
- [ ] ❌ No testing before production?
- [ ] ❌ Testing in production?
- [ ] ❌ No validation of deployment?
- [ ] ❌ No smoke tests?
- [ ] ❌ Can't rollback automatically?

### Documentation
- [ ] ❌ No comments in complex code?
- [ ] ❌ No README or guide?
- [ ] ❌ No troubleshooting section?
- [ ] ❌ No runbook for common issues?
- [ ] ❌ No onboarding guide?

**If you checked any boxes, you have antipatterns to fix!**

---

## How to Fix Antipatterns

### Step-by-Step Remediation

1. **Audit Current State**
   - Run through checklist above
   - Document all antipatterns found
   - Prioritize by risk (security first!)

2. **Create Fix Plan**
   - List antipatterns to fix
   - Estimate effort for each
   - Plan phased approach

3. **Fix High-Risk Issues First**
   - Security (credentials, auth)
   - Compliance (approval bypasses)
   - Safety (error handling)

4. **Improve Gradually**
   - One antipattern per week
   - Test thoroughly after each fix
   - Document changes

5. **Prevent Recurrence**
   - Code review checklist
   - Automated linting where possible
   - Team training
   - Documentation

---

## Additional Resources

- [Integration Guide](GITHUB-SERVICENOW-INTEGRATION-GUIDE.md) - Correct patterns
- [Best Practices](GITHUB-SERVICENOW-BEST-PRACTICES.md) - How to do it right
- [Quick Start](SERVICENOW-QUICK-START.md) - Get started correctly
- [Troubleshooting](SERVICENOW-INDEX.md) - Fix common issues

**Remember**: Everyone makes mistakes. The key is to learn from them and improve continuously!

---

**Document Version**: 1.0
**Last Updated**: 2025-10-20
**Questions?**: See [SERVICENOW-INDEX.md](SERVICENOW-INDEX.md)
