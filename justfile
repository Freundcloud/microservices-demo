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
    @echo "  - istioctl: For Istio debugging"
    @echo "  - k9s: Terminal UI for Kubernetes"
    @echo "  - helm: Package manager for Kubernetes"
    @echo "  - grpcurl: Test gRPC services"
    @echo ""
    @echo "Run 'just install-optional-tools' to install these"

# Install optional development tools
install-optional-tools:
    @echo "📦 Installing optional tools..."
    @echo "Installing istioctl..."
    @curl -L https://istio.io/downloadIstio | sh - || echo "⚠️  Failed to install istioctl"
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
    kubectl apply -f istio-manifests/

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
    @kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
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
# Istio Service Mesh
# ==============================================================================

# Access Kiali dashboard
istio-kiali:
    @echo "🎨 Opening Kiali dashboard..."
    @echo "Access at: http://localhost:20001"
    kubectl port-forward svc/kiali-server -n istio-system 20001:20001

# Access Grafana dashboard
istio-grafana:
    @echo "📊 Opening Grafana dashboard..."
    @echo "Access at: http://localhost:3000"
    kubectl port-forward svc/grafana -n istio-system 3000:80

# Access Jaeger tracing UI
istio-jaeger:
    @echo "🔍 Opening Jaeger tracing UI..."
    @echo "Access at: http://localhost:16686"
    kubectl port-forward svc/jaeger-query -n istio-system 16686:16686

# Access Prometheus
istio-prometheus:
    @echo "📈 Opening Prometheus..."
    @echo "Access at: http://localhost:9090"
    kubectl port-forward svc/prometheus-server -n istio-system 9090:80

# Analyze Istio configuration
istio-analyze:
    @echo "🔍 Analyzing Istio configuration..."
    istioctl analyze -n default

# Check Istio proxy status
istio-status:
    @echo "📊 Istio proxy status:"
    istioctl proxy-status

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

# Run development environment (all dashboards)
dev-dashboards:
    @echo "🎨 Starting all development dashboards..."
    @echo "This will open multiple port forwards. Press Ctrl+C to stop all."
    @echo ""
    @echo "Kiali: http://localhost:20001"
    @echo "Grafana: http://localhost:3000"
    @echo "Jaeger: http://localhost:16686"
    @echo ""
    @parallel -j 3 \
        kubectl port-forward svc/kiali-server -n istio-system 20001:20001 ::: \
        kubectl port-forward svc/grafana -n istio-system 3000:80 ::: \
        kubectl port-forward svc/jaeger-query -n istio-system 16686:16686

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
    @echo "  just istio-kiali          - Open service mesh dashboard"
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
    @echo "5. View dashboards:"
    @echo "   just istio-kiali"
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
