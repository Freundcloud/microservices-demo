#!/usr/bin/env bash
# servicenow-workflow-examples.sh - Code examples for ServiceNow integration
# Usage: Source this file or copy functions into your workflows

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXAMPLE 1: Create Change Request with Correlation ID
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_change_request_with_correlation() {
    local environment="$1"
    local commit_sha="$2"
    local actor="$3"
    local run_id="$4"

    log_info "Creating ServiceNow change request for $environment..."

    # Build correlation ID (unique identifier linking GitHub to ServiceNow)
    local correlation_id="github-${GITHUB_REPOSITORY:-microservices-demo}-${run_id}"

    # Create Basic Auth header
    local basic_auth
    basic_auth=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    # Build comprehensive change request payload
    local payload
    payload=$(cat <<EOF
{
  "short_description": "Deploy Online Boutique to ${environment}",
  "description": "Automated deployment via GitHub Actions

**Application**: Online Boutique Microservices
**Environment**: ${environment}
**Commit SHA**: ${commit_sha}
**Triggered By**: ${actor}
**GitHub Run**: https://github.com/${GITHUB_REPOSITORY:-org/repo}/actions/runs/${run_id}

**Services Being Deployed** (11 microservices):
- frontend (Go) - Web UI
- cartservice (C#) - Shopping cart with Redis
- productcatalogservice (Go) - Product inventory
- currencyservice (Node.js) - Currency conversion
- paymentservice (Node.js) - Payment processing
- shippingservice (Go) - Shipping calculations
- emailservice (Python) - Order confirmations
- checkoutservice (Go) - Checkout orchestration
- recommendationservice (Python) - Product recommendations
- adservice (Java) - Contextual ads
- loadgenerator (Python) - Load testing (dev/qa only)
",
  "implementation_plan": "**Pre-Deployment Validation**:
1. Verify all security scans passed (CodeQL, Trivy, Gitleaks, Semgrep)
2. Validate Kubernetes manifests (kubectl apply --dry-run)
3. Check EKS cluster health (nodes ready, sufficient resources)
4. Verify namespace exists with correct labels

**Deployment Process**:
5. Deploy using Kustomize overlay: kubectl apply -k kustomize/overlays/${environment}
6. Wait for all deployments to reach Ready state (timeout: 10 minutes)
7. Verify Istio sidecar injection (all pods should have 2/2 containers)

**Post-Deployment Verification**:
8. Check pod status: kubectl get pods -n microservices-${environment}
9. Verify all services have endpoints
10. Run health checks against frontend service
11. Check Istio metrics in Grafana
12. Verify no errors in CloudWatch Logs

**Estimated Duration**: 15-25 minutes",
  "backout_plan": "**Rollback Procedure**:
1. Immediate rollback: kubectl rollout undo deployment -n microservices-${environment}
2. OR delete and reapply previous version: kubectl delete -k kustomize/overlays/${environment}
3. Verify rollback: kubectl rollout status deployment -n microservices-${environment}
4. Confirm traffic is being served correctly
5. Update this change request with rollback details

**Recovery Time Objective**: 10 minutes
**Last Known Good Version**: Check previous successful deployment in GitHub Actions",
  "test_plan": "**Automated Checks**:
- All pods running (11/11 in prod, 12/12 in dev/qa with loadgenerator)
- All services have endpoints
- Health check endpoints responding
- No CrashLoopBackOff or ImagePullBackOff states

**Functional Testing**:
- Homepage loads successfully (< 500ms response time)
- Browse 3 product pages
- Add items to cart (test cart persistence)
- Complete test checkout with test credit card
- Verify order confirmation email received

**Performance Checks**:
- P95 latency < 1 second for all endpoints
- Error rate < 0.1%
- All Istio circuit breakers in healthy state
- CPU/Memory usage within expected ranges

**Monitoring** (15-minute observation period):
- Watch CloudWatch metrics for anomalies
- Monitor Istio Grafana dashboards
- Check error logs in CloudWatch Logs
- Verify no alerts triggered",
  "type": "standard",
  "risk": "$(get_risk_for_environment "$environment")",
  "priority": "$(get_priority_for_environment "$environment")",
  "state": "$(get_state_for_environment "$environment")",
  "assignment_group": "$(get_assignment_group_for_environment "$environment")",
  "requested_by": "${SERVICENOW_USERNAME}",
  "business_service": "${SERVICENOW_APP_SYS_ID:-}",
  "cmdb_ci": "${SERVICENOW_APP_SYS_ID:-}",
  "u_application": "Online Boutique",
  "u_environment": "${environment}",
  "correlation_id": "${correlation_id}",
  "correlation_display": "GitHub Actions Run #${run_id}",
  "u_source": "GitHub Actions",
  "work_notes": "Created by GitHub Actions automation
Workflow: Deploy with ServiceNow
Run ID: ${run_id}
Commit: ${commit_sha}
Actor: ${actor}"
}
EOF
    )

    # Make API call with retry logic
    local max_retries=3
    local retry_delay=5
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        log_info "Attempt $attempt of $max_retries..."

        local response
        local http_code

        response=$(curl -s -w "%{http_code}" -o /tmp/servicenow_response.json \
            -X POST \
            -H "Authorization: Basic $basic_auth" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request")

        http_code=$(tail -n1 <<< "$response")

        # Success
        if [ "$http_code" == "201" ]; then
            local change_number
            local change_sys_id

            change_number=$(jq -r '.result.number' /tmp/servicenow_response.json)
            change_sys_id=$(jq -r '.result.sys_id' /tmp/servicenow_response.json)

            log_success "Change request created: $change_number"
            echo "CHANGE_NUMBER=$change_number"
            echo "CHANGE_SYS_ID=$change_sys_id"
            echo "CORRELATION_ID=$correlation_id"

            return 0
        fi

        # Retryable error (5xx)
        if [[ "$http_code" =~ ^5 ]]; then
            log_warning "Server error (HTTP $http_code), retrying in ${retry_delay}s..."
            cat /tmp/servicenow_response.json | jq . || cat /tmp/servicenow_response.json
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))  # Exponential backoff
            attempt=$((attempt + 1))
            continue
        fi

        # Non-retryable error (4xx)
        log_error "Client error (HTTP $http_code), not retrying"
        cat /tmp/servicenow_response.json | jq . || cat /tmp/servicenow_response.json
        return 1
    done

    log_error "Failed after $max_retries attempts"
    return 1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXAMPLE 2: Wait for Change Approval with Smart Polling
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

wait_for_approval() {
    local change_sys_id="$1"
    local change_number="$2"
    local environment="$3"

    log_info "Waiting for approval on $change_number..."

    # Create Basic Auth
    local basic_auth
    basic_auth=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    # Set timeout based on environment
    local timeout
    case "$environment" in
        dev)
            log_info "Dev environment - no approval required"
            return 0
            ;;
        qa)
            timeout=7200  # 2 hours
            ;;
        prod)
            timeout=86400  # 24 hours
            ;;
        *)
            timeout=7200  # Default 2 hours
            ;;
    esac

    # Smart polling interval (adjust based on time of day)
    local interval
    local current_hour
    current_hour=$(date +%H)

    if [ "$current_hour" -ge 9 ] && [ "$current_hour" -le 17 ]; then
        interval=30  # 30 seconds during business hours
    else
        interval=300  # 5 minutes after hours
    fi

    local elapsed=0
    local warning_threshold=$((timeout * 80 / 100))
    local sent_warning=false

    echo ""
    log_info "⏸️  Waiting for approval..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Change Request: $change_number"
    echo "Environment: $environment"
    echo "Timeout: $((timeout / 3600)) hours"
    echo "Polling Interval: $interval seconds"
    echo ""
    echo "Approve in ServiceNow:"
    echo "${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=change_request.do?sys_id=$change_sys_id"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    while [ $elapsed -lt $timeout ]; do
        # Get change request status
        local response
        response=$(curl -s \
            -H "Authorization: Basic $basic_auth" \
            "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request/${change_sys_id}?sysparm_fields=state,approval,approval_set")

        local state
        local approval

        state=$(echo "$response" | jq -r '.result.state')
        approval=$(echo "$response" | jq -r '.result.approval')

        # Calculate progress
        local percent=$((elapsed * 100 / timeout))
        local hours=$((elapsed / 3600))
        local minutes=$(( (elapsed % 3600) / 60 ))
        local seconds=$((elapsed % 60))

        printf "[%3d%%] %02d:%02d:%02d | State: %-15s | Approval: %-15s\n" \
            "$percent" "$hours" "$minutes" "$seconds" "$state" "$approval"

        # Check if approved
        if [ "$approval" == "approved" ]; then
            echo ""
            log_success "Change request approved!"
            echo "Approved at: $(date)"
            echo "Total wait time: ${hours}h ${minutes}m ${seconds}s"
            return 0
        fi

        # Check if rejected
        if [ "$approval" == "rejected" ]; then
            echo ""
            log_error "Change request rejected!"
            echo "Rejected at: $(date)"
            return 1
        fi

        # Send reminder at warning threshold
        if [ $elapsed -ge $warning_threshold ] && [ "$sent_warning" != "true" ]; then
            log_warning "Approval pending for $((elapsed / 3600)) hours - sending reminder"
            # TODO: Send Slack notification to approval group
            sent_warning=true
        fi

        # Wait before next poll
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    # Timeout reached
    echo ""
    log_error "Approval timeout reached ($((timeout / 3600)) hours)"
    echo "Change request: $change_number"
    echo "Status at timeout: State=$state, Approval=$approval"
    # TODO: Send timeout notification
    return 1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXAMPLE 3: Update Change Request with Deployment Result
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

update_change_request() {
    local change_sys_id="$1"
    local status="$2"  # "success" or "failure"
    local deployment_details="$3"

    log_info "Updating change request with $status status..."

    # Create Basic Auth
    local basic_auth
    basic_auth=$(echo -n "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" | base64)

    # Build update payload based on status
    local payload
    if [ "$status" == "success" ]; then
        payload=$(cat <<EOF
{
  "state": "3",
  "close_code": "successful",
  "close_notes": "Deployment completed successfully

**Deployment Summary**:
${deployment_details}

**Verification**:
- All pods reached Running state
- All services have endpoints
- Health checks passing
- No errors in logs
- Metrics within normal ranges

**Completed At**: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
",
  "work_notes": "Deployment successful at $(date)
All verification checks passed
Application serving traffic normally"
}
EOF
        )
    else
        payload=$(cat <<EOF
{
  "state": "4",
  "close_code": "unsuccessful",
  "close_notes": "Deployment failed

**Failure Details**:
${deployment_details}

**Actions Taken**:
- Automatic rollback initiated
- Previous version restored
- Application confirmed stable
- No customer impact

**Failed At**: $(date -u +'%Y-%m-%d %H:%M:%S UTC')
**Next Steps**: Review failure logs and retry after fixing issues
",
  "work_notes": "Deployment failed at $(date)
Automatic rollback completed successfully
Previous version confirmed working
Requires investigation before retry"
}
EOF
        )
    fi

    # Make API call
    local response
    local http_code

    response=$(curl -s -w "%{http_code}" -o /tmp/servicenow_update.json \
        -X PUT \
        -H "Authorization: Basic $basic_auth" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${SERVICENOW_INSTANCE_URL}/api/now/table/change_request/${change_sys_id}")

    http_code=$(tail -n1 <<< "$response")

    if [ "$http_code" == "200" ]; then
        log_success "Change request updated successfully"
        return 0
    else
        log_error "Failed to update change request (HTTP $http_code)"
        cat /tmp/servicenow_update.json | jq . || cat /tmp/servicenow_update.json
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

get_risk_for_environment() {
    case "$1" in
        dev) echo "3" ;;   # Low
        qa) echo "2" ;;    # Medium
        prod) echo "1" ;;  # High
        *) echo "3" ;;
    esac
}

get_priority_for_environment() {
    case "$1" in
        dev) echo "3" ;;   # Low
        qa) echo "2" ;;    # Medium
        prod) echo "1" ;;  # Critical
        *) echo "3" ;;
    esac
}

get_state_for_environment() {
    case "$1" in
        dev) echo "3" ;;   # Closed/Complete (auto-approved)
        qa) echo "-5" ;;   # Pending approval
        prod) echo "-5" ;; # Pending approval
        *) echo "-5" ;;
    esac
}

get_assignment_group_for_environment() {
    case "$1" in
        dev) echo "" ;;    # No assignment needed
        qa) echo "QA Team" ;;
        prod) echo "Change Advisory Board" ;;
        *) echo "" ;;
    esac
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EXAMPLE 4: Complete End-to-End Workflow
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

deploy_with_servicenow() {
    local environment="$1"
    local commit_sha="${2:-$(git rev-parse HEAD)}"
    local actor="${3:-$(git config user.name)}"
    local run_id="${4:-$$}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Starting deployment to $environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Step 1: Create change request
    echo ""
    echo "STEP 1: Creating ServiceNow Change Request"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local change_output
    change_output=$(create_change_request_with_correlation "$environment" "$commit_sha" "$actor" "$run_id")

    if [ $? -ne 0 ]; then
        log_error "Failed to create change request"
        return 1
    fi

    local change_number
    local change_sys_id

    change_number=$(echo "$change_output" | grep "CHANGE_NUMBER=" | cut -d= -f2)
    change_sys_id=$(echo "$change_output" | grep "CHANGE_SYS_ID=" | cut -d= -f2)

    # Step 2: Wait for approval (if needed)
    echo ""
    echo "STEP 2: Waiting for Approval (if required)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! wait_for_approval "$change_sys_id" "$change_number" "$environment"; then
        log_error "Approval denied or timed out"
        return 1
    fi

    # Step 3: Deploy application
    echo ""
    echo "STEP 3: Deploying Application"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    log_info "Deploying to Kubernetes..."

    # Simulate deployment (replace with actual kubectl commands)
    if kubectl apply -k "kustomize/overlays/$environment" 2>&1; then
        log_success "Deployment successful"

        # Step 4: Update change request with success
        local deployment_details="Environment: $environment
Commit: $commit_sha
Namespace: microservices-$environment
All services deployed successfully"

        update_change_request "$change_sys_id" "success" "$deployment_details"

        echo ""
        log_success "Deployment completed successfully!"
        echo "Change Request: $change_number"
        echo "View in ServiceNow: ${SERVICENOW_INSTANCE_URL}/nav_to.do?uri=change_request.do?sys_id=$change_sys_id"
        return 0
    else
        log_error "Deployment failed"

        # Step 4: Update change request with failure
        local deployment_details="Environment: $environment
Commit: $commit_sha
Deployment failed - check logs for details"

        update_change_request "$change_sys_id" "failure" "$deployment_details"

        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Script
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    echo "ServiceNow Workflow Examples"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This script contains reusable functions for ServiceNow integration."
    echo ""
    echo "Available functions:"
    echo "  1. create_change_request_with_correlation <env> <sha> <actor> <run_id>"
    echo "  2. wait_for_approval <sys_id> <number> <env>"
    echo "  3. update_change_request <sys_id> <status> <details>"
    echo "  4. deploy_with_servicenow <env> [sha] [actor] [run_id]"
    echo ""
    echo "Example usage:"
    echo "  source scripts/servicenow-workflow-examples.sh"
    echo "  deploy_with_servicenow dev"
    echo ""
    echo "For complete documentation, see:"
    echo "  - docs/GITHUB-SERVICENOW-INTEGRATION-GUIDE.md"
    echo "  - docs/GITHUB-SERVICENOW-BEST-PRACTICES.md"
    echo "  - docs/GITHUB-SERVICENOW-DEVELOPER-ONBOARDING.md"
}

# If script is executed (not sourced), show help
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main
fi
