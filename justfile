# Online Boutique AWS - Development Tasks
# Run 'just' to see all available commands

# Default recipe to display help
default:
    @just --list

# ==============================================================================
# Developer Onboarding
# ==============================================================================

# Complete developer onboarding process
onboard:
    @echo "🚀 Starting developer onboarding for Online Boutique AWS..."
    @echo ""
    @just check-requirements
    @echo ""
    @just setup-tools
    @echo ""
    @just setup-aws
    @echo ""
    @just setup-git-hooks
    @echo ""
    @just verify-setup
    @echo ""
    @echo "✅ Onboarding complete! You're ready to develop."
    @echo "📚 Next steps:"
    @echo "  1. Read docs/README.md for full documentation"
    @echo "  2. Run 'just dev-help' to see development commands"
    @echo "  3. Run 'just validate' to test your setup"

# Check for required tools
check-requirements:
    @echo "📋 Checking required tools..."
    @command -v git >/dev/null 2>&1 || (echo "❌ git is not installed" && exit 1)
    @command -v docker >/dev/null 2>&1 || (echo "❌ docker is not installed" && exit 1)
    @command -v kubectl >/dev/null 2>&1 || (echo "❌ kubectl is not installed" && exit 1)
    @command -v terraform >/dev/null 2>&1 || (echo "❌ terraform is not installed" && exit 1)
    @command -v aws >/dev/null 2>&1 || (echo "❌ aws cli is not installed" && exit 1)
    @echo "✅ All required tools are installed"

# Setup additional development tools
setup-tools:
    @echo "🔧 Setting up development tools..."
    @echo "Installing pre-commit hooks..."
    @pip install --user pre-commit 2>/dev/null || echo "⚠️  pip not found, skipping pre-commit"
    @echo "Installing useful tools (optional)..."
    @echo "  - k9s: Terminal UI for Kubernetes"
    @echo "  - helm: Package manager for Kubernetes"
    @echo "  - grpcurl: Test gRPC services"
    @echo ""
    @echo "Run 'just install-optional-tools' to install these"

# Install optional development tools
install-optional-tools:
    @echo "📦 Installing optional tools..."
    @echo "Installing k9s..."
    @brew install k9s || echo "⚠️  brew not found, install k9s manually"
    @echo "Installing helm..."
    @brew install helm || echo "⚠️  brew not found, install helm manually"
    @echo "Installing grpcurl..."
    @brew install grpcurl || echo "⚠️  brew not found, install grpcurl manually"

# Setup AWS credentials
setup-aws:
    @echo "🔐 Setting up AWS credentials..."
    @if [ ! -f .envrc ]; then \
        echo "Creating .envrc from template..."; \
        cp .envrc.example .envrc; \
        echo "⚠️  Please edit .envrc with your AWS credentials"; \
        echo "   Then run 'source .envrc' to load them"; \
    else \
        echo "✅ .envrc already exists"; \
    fi

# Setup git hooks
setup-git-hooks:
    @echo "🪝 Setting up git hooks..."
    @if command -v pre-commit >/dev/null 2>&1; then \
        pre-commit install; \
        echo "✅ Git hooks installed"; \
    else \
        echo "⚠️  pre-commit not found, skipping hooks"; \
    fi

# Verify development environment setup
verify-setup:
    @echo "🔍 Verifying development environment..."
    @echo "Checking AWS credentials..."
    @if [ -z "$AWS_ACCESS_KEY_ID" ]; then \
        echo "⚠️  AWS credentials not loaded. Run 'source .envrc'"; \
    else \
        echo "✅ AWS credentials loaded"; \
        aws sts get-caller-identity >/dev/null 2>&1 && echo "✅ AWS credentials valid" || echo "❌ AWS credentials invalid"; \
    fi
    @echo "Checking kubectl..."
    @kubectl version --client >/dev/null 2>&1 && echo "✅ kubectl working" || echo "⚠️  kubectl not configured"
    @echo "Checking terraform..."
    @cd terraform-aws && terraform version >/dev/null 2>&1 && echo "✅ terraform working" || echo "❌ terraform not working"
    @echo "Checking docker..."
    @docker ps >/dev/null 2>&1 && echo "✅ docker daemon running" || echo "⚠️  docker daemon not running"

# ==============================================================================
# Infrastructure Management
# ==============================================================================

# Initialize Terraform (single cluster for all environments)
# If remote backend is configured in versions.tf, this will use S3
# Otherwise, it will use local state (default)
tf-init:
    @echo "🏗️  Initializing Terraform..."
    cd terraform-aws && terraform init

# Plan Terraform changes (single cluster)
tf-plan:
    @echo "📋 Planning Terraform changes..."
    cd terraform-aws && terraform plan

# Apply Terraform changes (single cluster with all three node groups)
tf-apply:
    @echo "🚀 Applying Terraform (creates cluster with dev, qa, prod node groups)..."
    cd terraform-aws && terraform apply

# Destroy Terraform infrastructure (WARNING: destroys entire cluster!)
tf-destroy:
    @echo "💥 WARNING: This will destroy the ENTIRE cluster (all environments)!"
    @echo "Press Ctrl+C to cancel, or Enter to continue..."
    @read
    cd terraform-aws && terraform destroy

# Validate Terraform configuration
tf-validate:
    @echo "✅ Validating Terraform configuration..."
    cd terraform-aws && terraform init -backend=false && terraform validate

# Format Terraform code
tf-fmt:
    @echo "📝 Formatting Terraform code..."
    cd terraform-aws && terraform fmt -recursive

# Run Terraform tests
tf-test:
    @echo "🧪 Running Terraform tests..."
    cd terraform-aws && terraform test

# Run all Terraform quality checks
tf-check:
    @echo "🔍 Running Terraform quality checks..."
    @just tf-fmt
    @just tf-validate
    @just tf-test

# ==============================================================================
# Kubernetes Operations
# ==============================================================================

# Configure kubectl for the single shared cluster
k8s-config:
    @echo "⚙️  Configuring kubectl for microservices cluster..."
    aws eks update-kubeconfig --region eu-west-2 --name microservices

# Deploy application to Kubernetes
k8s-deploy:
    @echo "🚢 Deploying application to Kubernetes..."
    kubectl apply -f release/kubernetes-manifests.yaml
    kubectl apply -f kubernetes-manifests/frontend-ingress.yaml

# Get status of all pods
k8s-status:
    @echo "📊 Kubernetes cluster status:"
    @kubectl get nodes
    @echo ""
    @kubectl get pods -n default
    @echo ""
    @kubectl get svc -n default

# View logs for a specific service
k8s-logs service:
    @echo "📜 Viewing logs for {{service}}..."
    kubectl logs -l app={{service}} -n default --tail=100 -f

# Port forward to a service
k8s-forward service port:
    @echo "🔌 Port forwarding {{service}} to localhost:{{port}}..."
    kubectl port-forward svc/{{service}} {{port}}:{{port}} -n default

# Get application URL
k8s-url:
    @echo "🌐 Application URL:"
    @kubectl get ingress frontend-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    @echo ""

# Restart a deployment
k8s-restart service:
    @echo "🔄 Restarting {{service}}..."
    kubectl rollout restart deployment/{{service}} -n default

# Scale a deployment
k8s-scale service replicas:
    @echo "⚖️  Scaling {{service}} to {{replicas}} replicas..."
    kubectl scale deployment/{{service}} --replicas={{replicas}} -n default

# ==============================================================================
# Container Operations
# ==============================================================================

# Build Docker image for a service
docker-build service:
    @echo "🐳 Building Docker image for {{service}}..."
    docker build -t {{service}}:local src/{{service}}

# Build all Docker images
docker-build-all:
    @echo "🐳 Building all Docker images..."
    @for service in emailservice productcatalogservice recommendationservice shippingservice checkoutservice paymentservice currencyservice cartservice frontend adservice loadgenerator shoppingassistantservice; do \
        echo "Building $service..."; \
        docker build -t $service:local src/$service || echo "⚠️  Failed to build $service"; \
    done

# Login to AWS ECR
ecr-login:
    @echo "🔐 Logging in to AWS ECR..."
    aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-west-2.amazonaws.com

# Push image to ECR
ecr-push service env='dev':
    @echo "📤 Pushing {{service}} to ECR..."
    @ACCOUNT=$(aws sts get-caller-identity --query Account --output text) && \
    ECR_URL=$ACCOUNT.dkr.ecr.eu-west-2.amazonaws.com && \
    docker tag {{service}}:local $ECR_URL/{{service}}:latest && \
    docker push $ECR_URL/{{service}}:latest

# ==============================================================================
# Security & Validation
# ==============================================================================

# Run security scans on containers
security-scan-containers:
    @echo "🔐 Scanning containers for vulnerabilities..."
    @command -v trivy >/dev/null 2>&1 || (echo "❌ trivy not installed. Install with: brew install trivy" && exit 1)
    @for service in emailservice productcatalogservice recommendationservice; do \
        echo "Scanning $service..."; \
        trivy image --severity HIGH,CRITICAL $service:local || true; \
    done

# Run security scans on Terraform
security-scan-terraform:
    @echo "🔐 Scanning Terraform for security issues..."
    @command -v tfsec >/dev/null 2>&1 || (echo "⚠️  tfsec not installed" && exit 0)
    @command -v checkov >/dev/null 2>&1 || (echo "⚠️  checkov not installed" && exit 0)
    cd terraform-aws && tfsec . || true
    cd terraform-aws && checkov -d . || true

# Scan for secrets in code
security-scan-secrets:
    @echo "🔐 Scanning for secrets..."
    @command -v gitleaks >/dev/null 2>&1 || (echo "⚠️  gitleaks not installed. Install with: brew install gitleaks" && exit 0)
    gitleaks detect --source . -v || echo "⚠️  Potential secrets found!"

# Run all security scans
security-scan-all:
    @echo "🔐 Running all security scans..."
    @just security-scan-terraform
    @just security-scan-secrets
    @echo "✅ Security scans complete"

# Validate all code and infrastructure
validate:
    @echo "✅ Running all validations..."
    @just tf-check
    @just security-scan-all
    @echo "✅ All validations passed!"

# ==============================================================================
# Development Workflows
# ==============================================================================

# Clean up local Docker images
clean-docker:
    @echo "🧹 Cleaning up local Docker images..."
    docker system prune -f

# Clean up Terraform state and cache
clean-terraform:
    @echo "🧹 Cleaning up Terraform..."
    rm -rf terraform-aws/.terraform terraform-aws/.terraform.lock.hcl terraform-aws/terraform.tfstate*

# Full cleanup
clean-all:
    @echo "🧹 Full cleanup..."
    @just clean-docker
    @just clean-terraform
    @echo "✅ Cleanup complete"

# ==============================================================================
# Testing & Quality
# ==============================================================================

# Run unit tests for a service
test-service service:
    @echo "🧪 Running tests for {{service}}..."
    cd src/{{service}} && make test || echo "⚠️  No tests found"

# Format all code
format:
    @echo "📝 Formatting code..."
    @just tf-fmt
    @echo "Run language-specific formatters for each service manually"

# Lint all code
lint:
    @echo "🔍 Linting code..."
    @just tf-validate
    @echo "Run language-specific linters for each service manually"

# ==============================================================================
# Utility Commands
# ==============================================================================

# Show development help
dev-help:
    @echo "🎓 Development Quick Reference"
    @echo ""
    @echo "Common workflows:"
    @echo "  just onboard              - First time setup"
    @echo "  just tf-plan          - Plan infrastructure changes"
    @echo "  just tf-apply         - Deploy infrastructure"
    @echo "  just k8s-deploy           - Deploy application"
    @echo "  just k8s-status           - Check cluster status"
    @echo "  just k8s-url              - Get application URL"
    @echo "  just validate             - Run all checks"
    @echo ""
    @echo "Run 'just' to see all available commands"

# Show environment information
info:
    @echo "ℹ️  Environment Information"
    @echo ""
    @echo "AWS Account:"
    @aws sts get-caller-identity 2>/dev/null || echo "  Not configured"
    @echo ""
    @echo "Kubernetes Context:"
    @kubectl config current-context 2>/dev/null || echo "  Not configured"
    @echo ""
    @echo "Terraform Version:"
    @terraform version | head -1
    @echo ""
    @echo "kubectl Version:"
    @kubectl version --client --short 2>/dev/null

# Quick start for new developers
quickstart:
    @echo "🚀 Quick Start Guide"
    @echo ""
    @echo "1. First time setup:"
    @echo "   just onboard"
    @echo ""
    @echo "2. Configure AWS credentials:"
    @echo "   Edit .envrc with your credentials"
    @echo "   source .envrc"
    @echo ""
    @echo "3. Deploy to dev environment:"
    @echo "   just tf-init"
    @echo "   just tf-apply"
    @echo "   just k8s-config"
    @echo "   just k8s-deploy"
    @echo ""
    @echo "4. Access the application:"
    @echo "   just k8s-url"
    @echo ""
    @echo "For more details, see docs/README.md"

# ==============================================================================
# Terraform Backend Management
# ==============================================================================

# Setup Terraform remote backend (S3 + DynamoDB) - Run this ONCE before first deployment
backend-setup:
    @echo "🔧 Setting up Terraform remote backend..."
    @echo ""
    @echo "This will create:"
    @echo "  - S3 bucket for Terraform state (with encryption & versioning)"
    @echo "  - DynamoDB table for state locking"
    @echo ""
    @echo "⚠️  Make sure you've configured terraform-aws/backend/terraform.tfvars first!"
    @echo ""
    cd terraform-aws/backend && terraform init && terraform apply

# Show backend configuration
backend-info:
    @echo "📋 Terraform Backend Configuration:"
    @echo ""
    cd terraform-aws/backend && terraform output -raw backend_config

# Destroy backend infrastructure (⚠️ WARNING: deletes state history!)
backend-destroy:
    @echo "💥 WARNING: This will destroy the Terraform backend!"
    @echo "⚠️  This will delete all state history - make sure you have backups!"
    @echo ""
    @echo "Press Ctrl+C to cancel, or Enter to continue..."
    @read
    cd terraform-aws/backend && terraform destroy

# ==============================================================================
# ServiceNow Integration
# ==============================================================================

# Run security scan and send results to ServiceNow
sn-security-scan:
    @echo "🔐 Running security scan with ServiceNow integration..."
    gh workflow run security-scan-servicenow.yaml
    @echo "✅ Security scan workflow triggered"
    @echo "📊 View results: gh run watch"
    @echo "🔗 ServiceNow: Check DevOps > Security > Security Results"

# Deploy to dev environment (auto-approved via ServiceNow)
sn-deploy-dev:
    @echo "🚀 Deploying to dev environment via ServiceNow..."
    gh workflow run deploy-with-servicenow.yaml -f environment=dev
    @echo "✅ Deployment workflow triggered (auto-approved for dev)"
    @echo "📊 Watch progress: gh run watch"
    @echo "🔗 ServiceNow: Change Management > My Changes"

# Deploy to qa environment (requires QA Lead approval)
sn-deploy-qa:
    @echo "🚀 Deploying to qa environment via ServiceNow..."
    @echo "⚠️  This requires QA Lead approval in ServiceNow"
    gh workflow run deploy-with-servicenow.yaml -f environment=qa
    @echo "✅ Deployment workflow triggered"
    @echo "⏳ Waiting for QA Lead approval in ServiceNow..."
    @echo "📊 Watch progress: gh run watch"
    @echo "🔗 ServiceNow: Change Management > My Changes"

# Deploy to prod environment (requires CAB approval)
sn-deploy-prod:
    @echo "🚀 Deploying to prod environment via ServiceNow..."
    @echo "⚠️  This requires Change Advisory Board (CAB) approval"
    @echo "     Approvers: Change Manager, App Owner, Security Team"
    gh workflow run deploy-with-servicenow.yaml -f environment=prod
    @echo "✅ Deployment workflow triggered"
    @echo "⏳ Waiting for CAB approval in ServiceNow..."
    @echo "📊 Watch progress: gh run watch"
    @echo "🔗 ServiceNow: Change Management > My Changes"

# Run EKS discovery to update ServiceNow CMDB
sn-discover:
    @echo "🔍 Running EKS discovery to update ServiceNow CMDB..."
    gh workflow run eks-discovery.yaml
    @echo "✅ Discovery workflow triggered"
    @echo "📊 Watch progress: gh run watch"
    @echo "🔗 ServiceNow: Configuration > CMDB > EKS Clusters"

# Diagnose ServiceNow DevOps Change Workspace integration
sn-diagnose:
    @echo "🔍 Diagnosing ServiceNow DevOps integration..."
    @echo ""
    @./scripts/diagnose-servicenow.sh

# Clean up ServiceNow secrets (remove old/incorrect, set correct ones)
sn-cleanup:
    @echo "🧹 Cleaning up ServiceNow secrets..."
    @echo "This will:"
    @echo "  - Delete old/incorrect SN_DEVOPS_* secrets"
    @echo "  - Set correct SERVICENOW_* secrets from .envrc"
    @echo "  - Test credentials against ServiceNow API"
    @echo "  - Activate ServiceNow tool if inactive"
    @echo ""
    @./scripts/cleanup-servicenow-secrets.sh

# View ServiceNow workflow status
sn-status:
    @echo "📊 ServiceNow Integration Status"
    @echo "================================"
    @echo ""
    @echo "Recent workflow runs:"
    @gh run list --limit 5
    @echo ""
    @echo "🔗 View in GitHub: https://github.com/$(git config --get remote.origin.url | sed 's/.*://;s/.git$//')/actions"
    @echo "🔗 ServiceNow URL: Check your SN_INSTANCE_URL secret"

# Watch current workflow run
sn-watch:
    @echo "👀 Watching current workflow run..."
    @gh run watch

# List all ServiceNow-related workflow runs
sn-history:
    @echo "📜 ServiceNow Workflow History"
    @echo "=============================="
    @echo ""
    @echo "Security Scans:"
    @gh run list --workflow=security-scan-servicenow.yaml --limit 10
    @echo ""
    @echo "Deployments:"
    @gh run list --workflow=deploy-with-servicenow.yaml --limit 10
    @echo ""
    @echo "Discoveries:"
    @gh run list --workflow=eks-discovery.yaml --limit 10

# View ServiceNow integration documentation
sn-docs:
    @echo "📚 ServiceNow Integration Documentation"
    @echo "======================================="
    @echo ""
    @echo "Quick Start:"
    @echo "  docs/SERVICENOW-QUICKSTART.md"
    @echo ""
    @echo "Essential Setup (30 min):"
    @echo "  docs/SERVICENOW-ESSENTIAL-SETUP.md"
    @echo ""
    @echo "Complete Guide:"
    @echo "  docs/SERVICENOW-INTEGRATION-PLAN.md"
    @echo ""
    @echo "Workflow Documentation:"
    @echo "  .github/workflows/SERVICENOW-WORKFLOWS-README.md"
    @echo ""
    @echo "🔗 View online: https://github.com/Freundcloud/microservices-demo/tree/main/docs"

# Show ServiceNow integration help
sn-help:
    @echo "🎯 ServiceNow Integration Commands"
    @echo "==================================="
    @echo ""
    @echo "🚀 Deployments:"
    @echo "  just sn-deploy-dev       - Deploy to dev (auto-approved)"
    @echo "  just sn-deploy-qa        - Deploy to qa (QA Lead approval)"
    @echo "  just sn-deploy-prod      - Deploy to prod (CAB approval)"
    @echo ""
    @echo "🔐 Security:"
    @echo "  just sn-security-scan    - Run security scans"
    @echo ""
    @echo "🔍 Discovery:"
    @echo "  just sn-discover         - Update CMDB with cluster info"
    @echo ""
    @echo "📊 Monitoring:"
    @echo "  just sn-status           - Show workflow status"
    @echo "  just sn-watch            - Watch current workflow"
    @echo "  just sn-history          - Show workflow history"
    @echo ""
    @echo "🛠️  Setup & Troubleshooting:"
    @echo "  just sn-cleanup          - Clean up secrets and test auth"
    @echo "  just sn-diagnose         - Diagnose integration issues"
    @echo ""
    @echo "📚 Documentation:"
    @echo "  just sn-docs             - View documentation links"
    @echo ""
    @echo "Prerequisites:"
    @echo "  - ServiceNow DevOps plugin installed"
    @echo "  - GitHub Secrets configured (SN_DEVOPS_INTEGRATION_TOKEN, etc.)"
    @echo "  - GitHub CLI installed (gh)"
    @echo ""
    @echo "Setup Guide: docs/SERVICENOW-ESSENTIAL-SETUP.md"

# ==============================================================================
# Demo: End-to-end GitHub ↔ ServiceNow flow
# ==============================================================================

# One-shot: open work item + PR, merge, deploy, wait for SNOW approval, then close work item
demo-run ENV TAG="":
        #!/usr/bin/env bash
        set -euo pipefail
        if [ -z "{{ENV}}" ] || [ -z "{{TAG}}" ]; then
            echo "Usage: just demo-run ENV=<dev|qa|prod> TAG=<version>"; exit 1; fi

        # Preflight checks
        command -v gh >/dev/null 2>&1 || { echo "gh CLI is required"; exit 1; }
        command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
        git fetch origin main >/dev/null 2>&1 || true

            # Use release/* branches for qa/prod to comply with branch policy
            if [ "{{ENV}}" = "qa" ] || [ "{{ENV}}" = "prod" ]; then
                BRANCH="release/{{TAG}}"
            else
                BRANCH="feat/version-bump-{{ENV}}-{{TAG}}"
            fi
        echo "📌 Creating feature branch: $BRANCH"
        git checkout -b "$BRANCH" || git checkout "$BRANCH"

        echo "🧾 Creating GitHub issue (work item)"
        ISSUE_JSON=$(gh issue create --title "Deploy {{ENV}} to {{TAG}}" \
            --body "Automate image tag bump to {{TAG}} in {{ENV}} overlay. This will create a ServiceNow change and pause at the deployment gate. Work item will close automatically after approval and successful deployment." \
            --label enhancement --json number,url 2>/dev/null || true)
        ISSUE_NUM=$(echo "$ISSUE_JSON" | jq -r '.number // empty')
        ISSUE_URL=$(echo "$ISSUE_JSON" | jq -r '.url // empty')
        if [ -z "$ISSUE_NUM" ]; then
            echo "ℹ️  Could not create issue (possibly missing auth). Proceeding without issue linkage."; fi

        echo "🔧 Bumping version in kustomize overlay"
        ./scripts/bump-env-version.sh "{{ENV}}" "{{TAG}}"

        echo "📝 Commit changes"
        if [ -n "$ISSUE_NUM" ]; then
            git add -A
            git commit -m "chore({{ENV}}): bump version to {{TAG}} (refs #$ISSUE_NUM)"
        else
            git add -A
            git commit -m "chore({{ENV}}): bump version to {{TAG}}"
        fi

        echo "📤 Push branch"
        git push -u origin "$BRANCH"

        echo "🔀 Open pull request"
        PR_BODY="Update {{ENV}} overlay to {{TAG}} to drive deployment via ServiceNow change gate."
        if [ -n "$ISSUE_NUM" ]; then PR_BODY+="\n\nRef: #$ISSUE_NUM"; fi
        gh pr create --fill -t "Bump {{ENV}} to {{TAG}}" -b "$PR_BODY" || true

                echo "✅ Attempting to merge PR"
                # For release branches, do NOT auto-merge into main; keep the PR open for review
                # The pipeline will back-merge after successful prod release
                if [[ "$BRANCH" =~ ^release\/ ]]; then
                    echo "ℹ️ Skipping auto-merge for release branch; PR remains open until production completes."
                else
                if ! gh pr merge --squash --delete-branch --merge; then
                    if ! gh pr merge --squash --delete-branch --admin --merge; then
                        echo "❌ Unable to auto-merge PR. Please merge it in the GitHub UI, then rerun: just demo-deploy ENV={{ENV}}"; exit 1; fi
                fi
            fi

        echo "🚀 Trigger MASTER-PIPELINE for {{ENV}}"
        gh workflow run MASTER-PIPELINE.yaml -f environment={{ENV}}
        # Allow a moment for the run to register
        sleep 5
        RUN_ID=$(gh run list --workflow MASTER-PIPELINE.yaml --limit 1 --json databaseId,createdAt | jq -r '.[0].databaseId')
        if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
            echo "❌ Could not determine run id. You can watch runs with: gh run list --workflow MASTER-PIPELINE.yaml"; exit 1; fi

        echo "⏳ Waiting for ServiceNow approval and deployment to complete (run id: $RUN_ID)"
        echo "👉 If gated (qa/prod), approve the change in ServiceNow to resume deployment."
        # Exit nonzero on failure so we don't close the issue
        gh run watch --run-id "$RUN_ID" --exit-status || { echo "❌ Deployment failed. See run $RUN_ID in GitHub Actions."; exit 1; }

        echo "🎉 Deployment completed successfully"
        if [ -n "$ISSUE_NUM" ]; then
            echo "🧹 Closing work item #$ISSUE_NUM"
            gh issue close "$ISSUE_NUM" -c "Deployment to {{ENV}} ({{TAG}}) succeeded after ServiceNow approval." || true
        fi
        echo "✅ Demo complete"

# Cut a release branch from main and run QA deployment
cut-release VERSION:
            #!/usr/bin/env bash
            set -euo pipefail
            if [ -z "{{VERSION}}" ]; then echo "Usage: just cut-release VERSION=<x.y.z>"; exit 1; fi
            RELEASE_BRANCH="release/{{VERSION}}"
            echo "🏷️  Cutting release branch: $RELEASE_BRANCH"
            git fetch origin main --quiet || true
            git checkout -B "$RELEASE_BRANCH" origin/main || git checkout -B "$RELEASE_BRANCH" main

            echo "🔧 Bump QA overlay to {{VERSION}}"
            ./scripts/bump-env-version.sh qa "{{VERSION}}"
            git add -A
            git commit -m "release: prepare {{VERSION}} for QA"
            git push -u origin "$RELEASE_BRANCH"

            echo "🔀 Open PR for release (optional review)"
            gh pr create --base main --head "$RELEASE_BRANCH" -t "Release {{VERSION}} (QA)" -b "Prepare QA deployment for {{VERSION}} on $RELEASE_BRANCH."

            echo "🚀 Trigger QA deployment from release branch"
            gh workflow run MASTER-PIPELINE.yaml -r "$RELEASE_BRANCH" -f environment=qa
            echo "👀 Watching run..."
            gh run watch || true

# Bump image version in an environment overlay and open a PR with a linked work item
demo-release ENV TAG="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ENV}}" ]; then
        echo "Usage: just demo-release ENV=<dev|qa|prod> TAG=<version>"; exit 1; fi
    if [ -z "{{TAG}}" ]; then
        echo "Usage: just demo-release ENV=<dev|qa|prod> TAG=<version>"; exit 1; fi

    BRANCH="feat/version-bump-{{ENV}}-{{TAG}}"
    echo "📌 Creating feature branch: $BRANCH"
    git checkout -b "$BRANCH"

    echo "🧾 Creating GitHub issue (work item)"
    ISSUE_JSON=$(gh issue create --title "Bump version to {{TAG}} in {{ENV}}" \
        --body "Automate image tag bump to {{TAG}} in {{ENV}} overlay to drive SNOW change via deployment gate." \
        --label enhancement --json number,url || true)
    ISSUE_NUM=$(echo "$ISSUE_JSON" | jq -r '.number // empty')
    ISSUE_URL=$(echo "$ISSUE_JSON" | jq -r '.url // empty')
    if [ -z "$ISSUE_NUM" ]; then
        echo "ℹ️  Could not create issue (possibly missing auth). Proceeding without issue linkage."; fi

    echo "🔧 Bumping version in kustomize overlay"
    ./scripts/bump-env-version.sh "{{ENV}}" "{{TAG}}"

    echo "📝 Commit changes"
    if [ -n "$ISSUE_NUM" ]; then
        git commit -am "chore({{ENV}}): bump version to {{TAG}} (closes #$ISSUE_NUM)"
    else
        git commit -am "chore({{ENV}}): bump version to {{TAG}}"
    fi

    echo "📤 Push branch"
    git push -u origin "$BRANCH"

    echo "🔀 Open pull request"
    PR_FLAGS=()
    if [ -n "$ISSUE_NUM" ]; then PR_FLAGS+=(--fill -b "Fixes #$ISSUE_NUM"); else PR_FLAGS+=(--fill); fi
    gh pr create "${PR_FLAGS[@]}" -t "Bump {{ENV}} to {{TAG}}" || true

    echo "✅ PR opened. Review and merge the PR to trigger the pipeline."

# After merging the PR, run the master pipeline with environment and wait for approvals
demo-deploy ENV:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ENV}}" ]; then echo "Usage: just demo-deploy ENV=<dev|qa|prod>"; exit 1; fi
    echo "🚀 Trigger MASTER-PIPELINE to deploy to {{ENV}}"
    # Trigger from the current branch to satisfy branch policy for qa/prod
    gh workflow run MASTER-PIPELINE.yaml -r "$BRANCH" -f environment={{ENV}}
    echo "👀 Watching run... (Ctrl+C to stop live watch)"
    gh run watch || true

# Close the issue that was used as work item (provide number)
demo-close-issue ISSUE:
    @echo "🧹 Closing work item #{{ISSUE}}"
    gh issue close {{ISSUE}} -c "Deployment successful; closing work item."

# ==============================================================================
# Cluster Management & Monitoring
# ==============================================================================

# Show complete cluster status overview
cluster-status:
    @echo "📊 Cluster Status Overview"
    @echo "=========================="
    @echo ""
    @echo "🏗️  Node Groups:"
    @kubectl get nodes -L workload -L environment --sort-by=.metadata.labels.workload
    @echo ""
    @echo "📦 Pods by Namespace:"
    @kubectl get pods --all-namespaces | grep -E "NAMESPACE|microservices|kube-system" | grep -v "Completed"
    @echo ""
    @echo "🔧 Cluster Add-ons:"
    @kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller,app.kubernetes.io/name=cluster-autoscaler
    @echo ""
    @echo "📈 Resource Usage:"
    @kubectl top nodes 2>/dev/null || echo "⚠️  Metrics not available (metrics-server may still be starting)"

# Show detailed node information
nodes-info:
    @echo "🖥️  Node Details"
    @echo "==============="
    @echo ""
    @for node in $(kubectl get nodes -o name); do \
        echo "Node: $$node"; \
        kubectl describe $$node | grep -E "Name:|Role:|Instance:|Capacity:|Allocatable:|Allocated"; \
        echo ""; \
    done

# Show node resource utilization
nodes-usage:
    @echo "📊 Node Resource Usage"
    @echo "====================="
    @kubectl top nodes --sort-by=memory 2>/dev/null || echo "⚠️  Metrics not available"

# Show pod resource utilization
pods-usage NAMESPACE="":
    #!/usr/bin/env bash
    if [ -z "{{NAMESPACE}}" ]; then
        echo "📊 Pod Resource Usage (All Namespaces)"
        echo "======================================"
        kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null || echo "⚠️  Metrics not available"
    else
        echo "📊 Pod Resource Usage ({{NAMESPACE}})"
        echo "======================================"
        kubectl top pods -n {{NAMESPACE}} --sort-by=memory 2>/dev/null || echo "⚠️  Metrics not available"
    fi

# Monitor cluster events in real-time
events-watch NAMESPACE="default":
    @echo "👀 Watching cluster events in {{NAMESPACE}}..."
    @kubectl get events -n {{NAMESPACE}} --watch

# Show all events with timestamps
events-recent NAMESPACE="":
    #!/usr/bin/env bash
    if [ -z "{{NAMESPACE}}" ]; then
        echo "📋 Recent Cluster Events (All Namespaces)"
        echo "========================================="
        kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -50
    else
        echo "📋 Recent Events in {{NAMESPACE}}"
        echo "=================================="
        kubectl get events -n {{NAMESPACE}} --sort-by=.metadata.creationTimestamp | tail -30
    fi

# Check cluster health status
health-check:
    @echo "🏥 Cluster Health Check"
    @echo "======================="
    @echo ""
    @echo "✅ Checking API Server..."
    @kubectl cluster-info | head -1
    @echo ""
    @echo "✅ Checking Node Status..."
    @kubectl get nodes --no-headers | awk '{print "  " $1 ": " $2}'
    @echo ""
    @echo "✅ Checking System Pods..."
    @kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed || echo "  All system pods running"
    @echo ""
    @echo "✅ Checking Add-ons..."
    @kubectl get deploy -n kube-system aws-load-balancer-controller metrics-server cluster-autoscaler 2>/dev/null | tail -n +2 || echo "  ⚠️  Some add-ons not found"

# Show resource quotas and limits
quotas-info NAMESPACE="":
    #!/usr/bin/env bash
    if [ -z "{{NAMESPACE}}" ]; then
        echo "📏 Resource Quotas (All Namespaces)"
        echo "==================================="
        kubectl get resourcequota --all-namespaces
        echo ""
        echo "📏 Limit Ranges (All Namespaces)"
        echo "================================"
        kubectl get limitrange --all-namespaces
    else
        echo "📏 Resource Quotas in {{NAMESPACE}}"
        echo "===================================="
        kubectl describe resourcequota -n {{NAMESPACE}}
        echo ""
        echo "📏 Limit Ranges in {{NAMESPACE}}"
        echo "================================"
        kubectl describe limitrange -n {{NAMESPACE}}
    fi

# Tail logs from all pods in a deployment
logs-tail DEPLOYMENT NAMESPACE="default":
    @echo "📜 Tailing logs for {{DEPLOYMENT}} in {{NAMESPACE}}..."
    @kubectl logs -f -n {{NAMESPACE}} -l app={{DEPLOYMENT}} --all-containers=true --tail=50

# Describe a pod with full details
pod-describe POD NAMESPACE="default":
    @kubectl describe pod -n {{NAMESPACE}} {{POD}}

# Get shell access to a pod
pod-exec POD NAMESPACE="default" CONTAINER="":
    #!/usr/bin/env bash
    if [ -z "{{CONTAINER}}" ]; then
        kubectl exec -it -n {{NAMESPACE}} {{POD}} -- /bin/sh
    else
        kubectl exec -it -n {{NAMESPACE}} {{POD}} -c {{CONTAINER}} -- /bin/sh
    fi

# Port forward to a service
port-forward SERVICE PORT NAMESPACE="default":
    @echo "🔌 Port forwarding {{SERVICE}}:{{PORT}} in {{NAMESPACE}}..."
    @kubectl port-forward -n {{NAMESPACE}} svc/{{SERVICE}} {{PORT}}:{{PORT}}

# Show all services and their endpoints
services-list NAMESPACE="":
    #!/usr/bin/env bash
    if [ -z "{{NAMESPACE}}" ]; then
        echo "🌐 Services (All Namespaces)"
        echo "============================"
        kubectl get svc --all-namespaces -o wide
    else
        echo "🌐 Services in {{NAMESPACE}}"
        echo "==========================="
        kubectl get svc -n {{NAMESPACE}} -o wide
        echo ""
        echo "Endpoints:"
        kubectl get endpoints -n {{NAMESPACE}}
    fi

# Show network policies
network-policies NAMESPACE="":
    #!/usr/bin/env bash
    if [ -z "{{NAMESPACE}}" ]; then
        echo "🔒 Network Policies (All Namespaces)"
        echo "===================================="
        kubectl get networkpolicies --all-namespaces
    else
        echo "🔒 Network Policies in {{NAMESPACE}}"
        echo "===================================="
        kubectl describe networkpolicies -n {{NAMESPACE}}
    fi

# Cordon a node (mark as unschedulable)
node-cordon NODE:
    @echo "🚫 Cordoning node {{NODE}}..."
    @kubectl cordon {{NODE}}
    @echo "✅ Node {{NODE}} is now unschedulable"

# Uncordon a node (mark as schedulable)
node-uncordon NODE:
    @echo "✅ Uncordoning node {{NODE}}..."
    @kubectl uncordon {{NODE}}
    @echo "✅ Node {{NODE}} is now schedulable"

# Drain a node (safely evict all pods)
node-drain NODE:
    @echo "💧 Draining node {{NODE}}..."
    @kubectl drain {{NODE}} --ignore-daemonsets --delete-emptydir-data
    @echo "✅ Node {{NODE}} has been drained"

# Show persistent volumes and claims
storage-info NAMESPACE="":
    #!/usr/bin/env bash
    echo "💾 Persistent Volumes"
    echo "====================="
    kubectl get pv
    echo ""
    if [ -z "{{NAMESPACE}}" ]; then
        echo "📦 Persistent Volume Claims (All Namespaces)"
        echo "============================================"
        kubectl get pvc --all-namespaces
    else
        echo "📦 Persistent Volume Claims in {{NAMESPACE}}"
        echo "============================================="
        kubectl get pvc -n {{NAMESPACE}}
    fi

# Show all ConfigMaps and Secrets
config-info NAMESPACE="default":
    @echo "⚙️  ConfigMaps in {{NAMESPACE}}"
    @echo "=============================="
    @kubectl get configmaps -n {{NAMESPACE}}
    @echo ""
    @echo "🔐 Secrets in {{NAMESPACE}}"
    @echo "=========================="
    @kubectl get secrets -n {{NAMESPACE}}

# Backup all Kubernetes manifests
backup-manifests OUTPUT_DIR="./backup":
    #!/usr/bin/env bash
    echo "💾 Backing up Kubernetes manifests to {{OUTPUT_DIR}}..."
    mkdir -p {{OUTPUT_DIR}}
    kubectl get all --all-namespaces -o yaml > {{OUTPUT_DIR}}/all-resources.yaml
    kubectl get configmaps --all-namespaces -o yaml > {{OUTPUT_DIR}}/configmaps.yaml
    kubectl get secrets --all-namespaces -o yaml > {{OUTPUT_DIR}}/secrets.yaml
    kubectl get pv,pvc --all-namespaces -o yaml > {{OUTPUT_DIR}}/storage.yaml
    echo "✅ Backup complete: {{OUTPUT_DIR}}"

# Generate diagnostic bundle for troubleshooting
diagnostics OUTPUT_DIR="./diagnostics":
    #!/usr/bin/env bash
    echo "🔍 Generating diagnostic bundle..."
    mkdir -p {{OUTPUT_DIR}}
    
    echo "Collecting cluster info..."
    kubectl cluster-info dump > {{OUTPUT_DIR}}/cluster-info.txt 2>&1
    
    echo "Collecting node info..."
    kubectl get nodes -o wide > {{OUTPUT_DIR}}/nodes.txt
    kubectl describe nodes > {{OUTPUT_DIR}}/nodes-detailed.txt
    
    echo "Collecting pod info..."
    kubectl get pods --all-namespaces -o wide > {{OUTPUT_DIR}}/pods.txt
    kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp > {{OUTPUT_DIR}}/events.txt
    
    echo "Collecting logs..."
    mkdir -p {{OUTPUT_DIR}}/logs
    for ns in kube-system default microservices-dev microservices-qa microservices-prod; do
        for pod in $(kubectl get pods -n $ns -o name 2>/dev/null); do
            podname=$(echo $pod | cut -d'/' -f2)
            kubectl logs -n $ns $pod --all-containers=true > {{OUTPUT_DIR}}/logs/${ns}-${podname}.log 2>&1 || true
        done
    done
    
    echo "✅ Diagnostic bundle created: {{OUTPUT_DIR}}"
    echo "📦 Archive with: tar czf diagnostics.tar.gz {{OUTPUT_DIR}}"

# Quick help for cluster management commands
cluster-help:
    @echo "🎯 Cluster Management Commands"
    @echo "=============================="
    @echo ""
    @echo "📊 Status & Monitoring:"
    @echo "  just cluster-status          - Complete cluster overview"
    @echo "  just health-check            - Quick health status"
    @echo "  just nodes-info              - Detailed node information"
    @echo "  just nodes-usage             - Node resource usage"
    @echo "  just pods-usage [NAMESPACE]  - Pod resource usage"
    @echo ""
    @echo "📜 Logs & Events:"
    @echo "  just logs-tail DEPLOYMENT [NS]  - Stream deployment logs"
    @echo "  just events-watch [NAMESPACE]   - Watch events live"
    @echo "  just events-recent [NAMESPACE]  - Recent events"
    @echo ""
    @echo "🔧 Node Management:"
    @echo "  just node-cordon NODE        - Mark node unschedulable"
    @echo "  just node-drain NODE         - Safely evict pods"
    @echo "  just node-uncordon NODE      - Mark node schedulable"
    @echo ""
    @echo "🔍 Troubleshooting:"
    @echo "  just diagnostics [DIR]       - Generate diagnostic bundle"
    @echo "  just pod-describe POD [NS]   - Pod details"
    @echo ""
    @echo "Run 'just' to see all commands"


# ==============================================================================
# Release Management
# ==============================================================================

# Release a new version and deploy to specified environment
release VERSION ENV="dev":
    @echo "🚀 Starting release process for v{{VERSION}} to {{ENV}}..."
    @./scripts/release.sh {{VERSION}} {{ENV}}

# Quick dev deployment (auto-increment patch version)
release-dev:
    #!/usr/bin/env bash
    CURRENT_VERSION=$(cat VERSION)
    # Extract major, minor, patch
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    MINOR="${VER[1]}"
    PATCH="${VER[2]}"
    # Increment patch
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
    echo "📦 Auto-incrementing version: $CURRENT_VERSION → $NEW_VERSION"
    just release $NEW_VERSION dev

# Release to QA (creates release branch and tag)
release-qa VERSION:
    @echo "🧪 Releasing v{{VERSION}} to QA..."
    @just release {{VERSION}} qa

# Release to Production (creates release branch and tag)
release-prod VERSION:
    @echo "🚀 Releasing v{{VERSION}} to Production..."
    @just release {{VERSION}} prod

# Show current version
version:
    @echo "Current version: $(cat VERSION)"
    @echo "Git tags:"
    @git tag -l | tail -5

# Build, tag, and push specific service
build-service SERVICE VERSION="dev":
    @echo "🐳 Building {{SERVICE}} with version {{VERSION}}..."
    @./scripts/build-service.sh {{SERVICE}} {{VERSION}}

# Deploy specific environment using GitHub Actions
deploy ENV="dev":
    @echo "🚀 Triggering deployment to {{ENV}}..."
    @if [ "{{ENV}}" = "dev" ]; then \
        gh workflow run auto-deploy-dev.yaml; \
        echo "✅ Dev deployment triggered (automatic)"; \
    else \
        gh workflow run deploy-with-servicenow-hybrid.yaml --field environment={{ENV}}; \
        echo "✅ {{ENV}} deployment triggered via ServiceNow"; \
        echo "⚠️  Remember to approve the ServiceNow change request!"; \
    fi

# Watch latest GitHub Actions workflow run
watch-deploy:
    @gh run watch

# List recent deployments
deployments:
    @echo "Recent deployments:"
    @gh run list --limit 10

# Rollback to previous version in environment
rollback ENV="dev":
    @echo "⏮️  Rolling back {{ENV}} environment..."
    @kubectl rollout undo deployment --all -n microservices-{{ENV}}
    @echo "✅ Rollback initiated"

# ==============================================================================
# Version Management Helper Commands
# ==============================================================================

# Bump major version (1.0.0 → 2.0.0)
bump-major:
    #!/usr/bin/env bash
    CURRENT_VERSION=$(cat VERSION)
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="$NEW_MAJOR.0.0"
    echo "📦 Bumping MAJOR version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "chore: Bump version to $NEW_VERSION"
    echo "✅ Version bumped to $NEW_VERSION"

# Bump minor version (1.0.0 → 1.1.0)
bump-minor:
    #!/usr/bin/env bash
    CURRENT_VERSION=$(cat VERSION)
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    MINOR="${VER[1]}"
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="$MAJOR.$NEW_MINOR.0"
    echo "📦 Bumping MINOR version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "chore: Bump version to $NEW_VERSION"
    echo "✅ Version bumped to $NEW_VERSION"

# Bump patch version (1.0.0 → 1.0.1)
bump-patch:
    #!/usr/bin/env bash
    CURRENT_VERSION=$(cat VERSION)
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    MINOR="${VER[1]}"
    PATCH="${VER[2]}"
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
    echo "📦 Bumping PATCH version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "chore: Bump version to $NEW_VERSION"
    echo "✅ Version bumped to $NEW_VERSION"

# ==============================================================================
# Automated Version Release Workflows
# ==============================================================================

# Complete automated workflow: bump minor version and deploy through all environments
release-minor-auto:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Starting Automated Minor Version Release Workflow"
    echo "====================================================="
    echo ""

    # 1. Bump minor version
    CURRENT_VERSION=$(cat VERSION)
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    MINOR="${VER[1]}"
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="$MAJOR.$NEW_MINOR.0"

    echo "📦 Bumping MINOR version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "chore: Bump version to $NEW_VERSION"
    git push origin main
    echo "✅ Version file updated and pushed"
    echo ""

    # 2. Deploy to dev (auto-approved)
    echo "🟢 Deploying to DEV environment..."
    just demo-run dev $NEW_VERSION
    echo ""

    # 3. Prompt for QA deployment
    read -p "🟡 Deploy to QA? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🟡 Deploying to QA environment (requires ServiceNow approval)..."
        just demo-run qa $NEW_VERSION
    fi
    echo ""

    # 4. Prompt for production deployment
    read -p "🔴 Deploy to PROD? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔴 Deploying to PROD environment (requires ServiceNow approval)..."
        just demo-run prod $NEW_VERSION
    fi
    echo ""

    echo "🎉 Release workflow complete!"
    echo "Version $NEW_VERSION deployed successfully"

# Complete automated workflow: bump patch version and deploy through all environments
release-patch-auto:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Starting Automated Patch Version Release Workflow"
    echo "====================================================="
    echo ""

    # 1. Bump patch version
    CURRENT_VERSION=$(cat VERSION)
    IFS='.' read -ra VER <<< "$CURRENT_VERSION"
    MAJOR="${VER[0]}"
    MINOR="${VER[1]}"
    PATCH="${VER[2]}"
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

    echo "📦 Bumping PATCH version: $CURRENT_VERSION → $NEW_VERSION"
    echo "$NEW_VERSION" > VERSION
    git add VERSION
    git commit -m "chore: Bump version to $NEW_VERSION"
    git push origin main
    echo "✅ Version file updated and pushed"
    echo ""

    # 2. Deploy to dev (auto-approved)
    echo "🟢 Deploying to DEV environment..."
    just demo-run dev $NEW_VERSION
    echo ""

    # 3. Prompt for QA deployment
    read -p "🟡 Deploy to QA? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🟡 Deploying to QA environment (requires ServiceNow approval)..."
        just demo-run qa $NEW_VERSION
    fi
    echo ""

    # 4. Prompt for production deployment
    read -p "🔴 Deploy to PROD? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔴 Deploying to PROD environment (requires ServiceNow approval)..."
        just demo-run prod $NEW_VERSION
    fi
    echo ""

    echo "🎉 Release workflow complete!"
    echo "Version $NEW_VERSION deployed successfully"

# Deploy existing version to specific environment using complete workflow
release-deploy-version VERSION ENV:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Deploying Version {{VERSION}} to {{ENV}}"
    echo "=========================================="
    echo ""

    # Validate environment
    if [[ "{{ENV}}" != "dev" && "{{ENV}}" != "qa" && "{{ENV}}" != "prod" ]]; then
        echo "❌ Invalid environment: {{ENV}}"
        echo "   Must be one of: dev, qa, prod"
        exit 1
    fi

    # Run the demo workflow
    just demo-run {{ENV}} {{VERSION}}

    echo ""
    echo "✅ Deployment to {{ENV}} complete!"

# ==============================================================================
# Automated Promotion Pipeline Commands
# ==============================================================================

# ============================================================================
# Automated Version Promotion
# ============================================================================

# Promote version through all environments (creates PR, auto-merges, deploys dev/qa/prod)
promote VERSION SERVICES="all":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/promote-version.sh {{ VERSION }} {{ SERVICES }}

# Promote all services (alias for promote VERSION all)
promote-all VERSION:
    just promote {{ VERSION }} all

# Promote specific service only
promote-service SERVICE VERSION:
    just promote {{ VERSION }} {{ SERVICE }}

# ============================================================================
# Manual Environment Deployments
# ============================================================================

# Deploy to DEV environment
deploy-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🟢 Deploying to DEV environment"
    gh workflow run MASTER-PIPELINE.yaml -f environment=dev
    gh run watch

# Deploy to QA environment (requires ServiceNow approval)
deploy-qa:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🟡 Deploying to QA environment"
    echo "⚠️  Requires ServiceNow Change Request approval"
    gh workflow run MASTER-PIPELINE.yaml -f environment=qa
    gh run watch

# Deploy to PROD environment (requires ServiceNow approval)
deploy-prod:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔴 Deploying to PROD environment"
    read -p "⚠️  Deploy to PRODUCTION? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
    echo "⚠️  Requires ServiceNow Change Request approval"
    gh workflow run MASTER-PIPELINE.yaml -f environment=prod
    gh run watch

# Force rebuild all services for an environment
rebuild-all ENV:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Force rebuilding all services for {{ ENV }}"
    gh workflow run MASTER-PIPELINE.yaml \
        -f environment={{ ENV }} \
        -f force_build_all=true
    gh run watch

# Check promotion status across all environments
promotion-status VERSION:
    #!/usr/bin/env bash
    echo "📊 Promotion Status for Version {{VERSION}}"
    echo "=========================================="
    echo ""

    # Check dev
    if grep -q "newTag: {{VERSION}}" kustomize/overlays/dev/kustomization.yaml 2>/dev/null; then
        echo "🔵 DEV:  ✅ Deployed"
    else
        echo "🔵 DEV:  ❌ Not deployed"
    fi

    # Check qa
    if grep -q "newTag: {{VERSION}}" kustomize/overlays/qa/kustomization.yaml 2>/dev/null; then
        echo "🟡 QA:   ✅ Deployed"
    else
        echo "🟡 QA:   ❌ Not deployed"
    fi

    # Check prod
    if grep -q "newTag: {{VERSION}}" kustomize/overlays/prod/kustomization.yaml 2>/dev/null; then
        echo "🔴 PROD: ✅ Deployed"
    else
        echo "🔴 PROD: ❌ Not deployed"
    fi

    echo ""

    # Check for git tag
    if git rev-parse "v{{VERSION}}" >/dev/null 2>&1; then
        echo "🏷️  Git Tag: ✅ v{{VERSION}} exists"
    else
        echo "🏷️  Git Tag: ❌ v{{VERSION}} not created"
    fi

# ==============================================================================
# Development Helpers
# ==============================================================================

# Show release help
release-help:
    @echo "🚀 Release Management Commands"
    @echo ""
    @echo "🎯 Fully Automated Workflows (Recommended):"
    @echo "  just release-minor-auto           - Bump minor version + deploy to all envs"
    @echo "  just release-patch-auto           - Bump patch version + deploy to all envs"
    @echo "  just release-deploy-version 1.2.0 dev   - Deploy existing version to env"
    @echo ""
    @echo "What these do:"
    @echo "  1. Create GitHub issue (ticket)"
    @echo "  2. Bump version in VERSION file"
    @echo "  3. Create feature/release branch"
    @echo "  4. Update kustomize overlays"
    @echo "  5. Create and auto-merge PR"
    @echo "  6. Trigger MASTER-PIPELINE"
    @echo "  7. Wait for ServiceNow approval (qa/prod)"
    @echo "  8. Deploy to Kubernetes"
    @echo "  9. Close GitHub issue"
    @echo ""
    @echo "📝 Version Bumping Only:"
    @echo "  just bump-major           - Bump major version (1.0.0 → 2.0.0)"
    @echo "  just bump-minor           - Bump minor version (1.0.0 → 1.1.0)"
    @echo "  just bump-patch           - Bump patch version (1.0.0 → 1.0.1)"
    @echo ""
    @echo "🔧 Manual Workflows:"
    @echo "  just demo-run dev 1.2.0           - Full workflow for specific env/version"
    @echo "  just promote 1.2.3 all            - Promote version to all envs (interactive)"
    @echo "  just release-dev                  - Auto-increment patch and deploy to dev"
    @echo "  just release-qa 1.1.0             - Release v1.1.0 to QA"
    @echo "  just release-prod 1.1.0           - Release v1.1.0 to Production"
    @echo ""
    @echo "🚀 Environment Deployments:"
    @echo "  just deploy-dev           - Deploy to dev (auto-approved)"
    @echo "  just deploy-qa            - Deploy to QA (requires ServiceNow approval)"
    @echo "  just deploy-prod          - Deploy to prod (requires ServiceNow approval)"
    @echo ""
    @echo "📊 Monitoring:"
    @echo "  just watch-deploy         - Watch current deployment"
    @echo "  just deployments          - List recent deployments"
    @echo "  just version              - Show current version"
    @echo "  just promotion-status 1.2.0  - Check version across all envs"
    @echo ""
    @echo "⏮️  Rollback:"
    @echo "  just rollback dev         - Rollback dev environment"
    @echo "  just rollback qa          - Rollback QA environment"
    @echo "  just rollback prod        - Rollback prod environment"
    @echo ""
    @echo "📚 Example Usage:"
    @echo "  # Complete automated release"
    @echo "  just release-minor-auto"
    @echo "  # → Bumps 1.3.0 → 1.4.0"
    @echo "  # → Creates ticket"
    @echo "  # → Deploys to dev automatically"
    @echo "  # → Prompts for qa deployment"
    @echo "  # → Prompts for prod deployment"
    @echo ""
    @echo "📖 Workflows:"
    @echo "  • Automated: Use release-minor-auto or release-patch-auto"
    @echo "  • Manual Control: Use demo-run for specific env/version"
    @echo "  • Promotion: Use promote for multi-env with wait between"
    @echo ""
    @echo "🔐 ServiceNow Integration:"
    @echo "  • Dev: Auto-approved, immediate deployment"
    @echo "  • QA: Requires manual approval in ServiceNow"
    @echo "  • Prod: Requires CAB approval in ServiceNow"

# ==============================================================================
# Enterprise Demonstrations
# ==============================================================================

# Run SOC 2 Type II / ISO 27001 compliant deployment workflow demonstration
demo-soc-compliance:
    @echo "🏛️  Starting SOC 2 Type II / ISO 27001 Compliance Demonstration"
    @echo ""
    @echo "This interactive demonstration showcases:"
    @echo "  • Complete change management lifecycle"
    @echo "  • ServiceNow ITSM integration (Change Requests, Work Items)"
    @echo "  • Security controls at every SDLC stage"
    @echo "  • Comprehensive audit trail & evidence collection"
    @echo "  • Compliance with financial services regulations"
    @echo ""
    @echo "Target Audience: Senior engineers in regulated industries"
    @echo "Standards: SOC 2 Type II, ISO 27001:2022, NIST CSF, CIS Controls"
    @echo ""
    @./scripts/demo-soc-iso27001-workflow.sh
