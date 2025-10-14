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
    @kubectl get pods --all-namespaces | grep -E "NAMESPACE|istio-system|microservices|kube-system" | grep -v "Completed"
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
    @echo "✅ Checking Istio..."
    @kubectl get pods -n istio-system --no-headers | grep -v Running | grep -v Completed || echo "  All Istio pods running"
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

# Monitor Istio service mesh health
istio-health:
    @echo "🕸️  Istio Service Mesh Health"
    @echo "============================"
    @echo ""
    @echo "Control Plane:"
    @kubectl get pods -n istio-system -l app=istiod
    @echo ""
    @echo "Ingress Gateway:"
    @kubectl get pods -n istio-system -l app=istio-ingressgateway
    @echo ""
    @echo "Proxy Status:"
    @istioctl proxy-status 2>/dev/null || echo "⚠️  istioctl not installed"
    @echo ""
    @echo "Configuration Analysis:"
    @istioctl analyze --all-namespaces 2>/dev/null || echo "⚠️  istioctl not installed"

# Show Istio ingress gateway URL and status
istio-ingress-info:
    @echo "🌐 Istio Ingress Gateway Information"
    @echo "===================================="
    @echo ""
    @echo "Gateway Service:"
    @kubectl get svc -n istio-system istio-ingressgateway
    @echo ""
    @echo "External URL:"
    @echo "  http://$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    @echo ""
    @echo "Gateway Configuration:"
    @kubectl get gateway -n default

# Tail logs from all pods in a deployment
logs-tail DEPLOYMENT NAMESPACE="default":
    @echo "📜 Tailing logs for {{DEPLOYMENT}} in {{NAMESPACE}}..."
    @kubectl logs -f -n {{NAMESPACE}} -l app={{DEPLOYMENT}} --all-containers=true --tail=50

# Show logs from Istio sidecar proxy
logs-proxy POD NAMESPACE="default":
    @echo "📜 Istio proxy logs for {{POD}} in {{NAMESPACE}}..."
    @kubectl logs -n {{NAMESPACE}} {{POD}} -c istio-proxy --tail=100

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
    
    echo "Collecting Istio info..."
    kubectl get all -n istio-system > {{OUTPUT_DIR}}/istio-resources.txt 2>&1
    istioctl proxy-status > {{OUTPUT_DIR}}/istio-proxy-status.txt 2>&1 || true
    
    echo "Collecting logs..."
    mkdir -p {{OUTPUT_DIR}}/logs
    for ns in kube-system istio-system default; do
        for pod in $(kubectl get pods -n $ns -o name); do
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
    @echo "🕸️  Istio Service Mesh:"
    @echo "  just istio-health            - Istio control plane status"
    @echo "  just istio-ingress-info      - Gateway URL and status"
    @echo "  just istio-kiali             - Open Kiali dashboard"
    @echo "  just istio-grafana           - Open Grafana dashboard"
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
    @echo "  just logs-proxy POD [NS]     - Istio sidecar logs"
    @echo ""
    @echo "Run 'just' to see all commands"

