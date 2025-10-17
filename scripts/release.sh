#!/usr/bin/env bash
set -euo pipefail

# release.sh - Comprehensive release management script
# Usage: ./scripts/release.sh [version] [environment]
# Example: ./scripts/release.sh 1.0.1 prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

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

# Parse arguments
VERSION="${1:-}"
ENVIRONMENT="${2:-dev}"

if [ -z "$VERSION" ]; then
    log_error "Version is required"
    echo "Usage: $0 <version> [environment]"
    echo "Example: $0 1.0.1 prod"
    echo ""
    echo "Environments:"
    echo "  dev  - Deploy to dev (no branch, no tag)"
    echo "  qa   - Deploy to qa (create release branch, create tag)"
    echo "  prod - Deploy to prod (create release branch, create tag)"
    exit 1
fi

# Validate version format (semantic versioning)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format. Use semantic versioning: MAJOR.MINOR.PATCH (e.g., 1.0.1)"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|qa|prod)$ ]]; then
    log_error "Invalid environment. Use: dev, qa, or prod"
    exit 1
fi

# Extract major.minor for branch name
MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1-2)

log_info "Release Configuration:"
echo "  Version: $VERSION"
echo "  Environment: $ENVIRONMENT"
echo "  Release Branch: release/$MAJOR_MINOR (qa/prod only)"
echo ""

# Check if on main branch for qa/prod
if [[ "$ENVIRONMENT" != "dev" ]]; then
    CURRENT_BRANCH=$(git branch --show-current)
    if [[ "$CURRENT_BRANCH" != "main" ]]; then
        log_warning "You are on branch '$CURRENT_BRANCH', not 'main'"
        read -p "Do you want to switch to main? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout main
            git pull origin main
        else
            log_error "Release must be created from main branch"
            exit 1
        fi
    fi
fi

# Step 1: Update VERSION file
log_info "Step 1/7: Updating VERSION file to $VERSION"
echo "$VERSION" > VERSION
log_success "VERSION file updated"

# Step 2: Commit version change (dev only)
if [[ "$ENVIRONMENT" == "dev" ]]; then
    log_info "Step 2/7: Committing version change to main"
    git add VERSION
    if git diff --staged --quiet; then
        log_warning "No changes to commit (VERSION already at $VERSION)"
    else
        git commit -m "chore: Bump version to $VERSION for dev deployment"
        git push origin main
        log_success "Version committed to main"
    fi
else
    log_info "Step 2/7: Skipping commit (will be done in release branch)"
fi

# Step 3: Create release branch (qa/prod only)
if [[ "$ENVIRONMENT" != "dev" ]]; then
    log_info "Step 3/7: Creating release branch release/$MAJOR_MINOR"

    # Check if branch exists
    if git show-ref --verify --quiet refs/heads/release/$MAJOR_MINOR; then
        log_warning "Branch release/$MAJOR_MINOR already exists, checking out"
        git checkout release/$MAJOR_MINOR
        git merge main --no-edit || {
            log_error "Failed to merge main into release/$MAJOR_MINOR"
            exit 1
        }
    else
        git checkout -b release/$MAJOR_MINOR
    fi

    # Commit VERSION change in release branch
    git add VERSION
    if ! git diff --staged --quiet; then
        git commit -m "chore: Set version to $VERSION"
    fi

    git push -u origin release/$MAJOR_MINOR
    log_success "Release branch created and pushed"

    # Step 4: Create Git tag
    log_info "Step 4/7: Creating Git tag v$VERSION"

    # Check if tag exists
    if git tag -l "v$VERSION" | grep -q .; then
        log_warning "Tag v$VERSION already exists, skipping tag creation"
    else
        git tag -a "v$VERSION" -m "Release v$VERSION

Environment: $ENVIRONMENT
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

🤖 Generated with release automation script"
        git push origin "v$VERSION"
        log_success "Git tag v$VERSION created and pushed"
    fi
else
    log_info "Step 3/7: Skipping release branch creation (dev deployment)"
    log_info "Step 4/7: Skipping Git tag creation (dev deployment)"
fi

# Step 5: Build container images
log_info "Step 5/7: Building container images with tags: $VERSION and $ENVIRONMENT"

# Login to ECR
log_info "Logging into AWS ECR..."
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 533267307120.dkr.ecr.eu-west-2.amazonaws.com

# Get ECR registry
ECR_REGISTRY="533267307120.dkr.ecr.eu-west-2.amazonaws.com"

# Build all services
log_info "Building all microservices..."
just docker-build-all

# Build cartservice separately (different Dockerfile location)
log_info "Building cartservice..."
cd src/cartservice/src
docker buildx build -t cartservice:local -f Dockerfile .
cd "$PROJECT_ROOT"

log_success "All images built successfully"

# Step 6: Tag and push images
log_info "Step 6/7: Tagging and pushing images to ECR"

SERVICES=(
    "frontend"
    "cartservice"
    "productcatalogservice"
    "currencyservice"
    "paymentservice"
    "shippingservice"
    "emailservice"
    "checkoutservice"
    "recommendationservice"
    "adservice"
    "loadgenerator"
)

for service in "${SERVICES[@]}"; do
    log_info "Processing $service..."

    # Tag with version
    docker tag ${service}:local $ECR_REGISTRY/$service:v$VERSION
    docker tag ${service}:local $ECR_REGISTRY/$service:$VERSION
    docker tag ${service}:local $ECR_REGISTRY/$service:$MAJOR_MINOR
    docker tag ${service}:local $ECR_REGISTRY/$service:$ENVIRONMENT

    # Push all tags
    docker push $ECR_REGISTRY/$service:v$VERSION
    docker push $ECR_REGISTRY/$service:$VERSION
    docker push $ECR_REGISTRY/$service:$MAJOR_MINOR
    docker push $ECR_REGISTRY/$service:$ENVIRONMENT

    log_success "$service pushed with all tags"
done

log_success "All images tagged and pushed to ECR"

# Step 7: Update Kustomize overlay and deploy
log_info "Step 7/7: Updating Kustomize overlay for $ENVIRONMENT and deploying"

KUSTOMIZE_OVERLAY="kustomize/overlays/$ENVIRONMENT"

# Update image tags in kustomization.yaml
log_info "Updating $KUSTOMIZE_OVERLAY/kustomization.yaml with version v$VERSION"

# Create a temporary file with updated tags
cat > /tmp/kustomization_update.yaml <<EOF
images:
  - name: frontend
    newName: $ECR_REGISTRY/frontend
    newTag: v$VERSION
  - name: cartservice
    newName: $ECR_REGISTRY/cartservice
    newTag: v$VERSION
  - name: productcatalogservice
    newName: $ECR_REGISTRY/productcatalogservice
    newTag: v$VERSION
  - name: currencyservice
    newName: $ECR_REGISTRY/currencyservice
    newTag: v$VERSION
  - name: paymentservice
    newName: $ECR_REGISTRY/paymentservice
    newTag: v$VERSION
  - name: shippingservice
    newName: $ECR_REGISTRY/shippingservice
    newTag: v$VERSION
  - name: emailservice
    newName: $ECR_REGISTRY/emailservice
    newTag: v$VERSION
  - name: checkoutservice
    newName: $ECR_REGISTRY/checkoutservice
    newTag: v$VERSION
  - name: recommendationservice
    newName: $ECR_REGISTRY/recommendationservice
    newTag: v$VERSION
  - name: adservice
    newName: $ECR_REGISTRY/adservice
    newTag: v$VERSION
  - name: loadgenerator
    newName: $ECR_REGISTRY/loadgenerator
    newTag: v$VERSION
EOF

# Backup existing kustomization.yaml
cp "$KUSTOMIZE_OVERLAY/kustomization.yaml" "$KUSTOMIZE_OVERLAY/kustomization.yaml.bak"

# Update the images section in kustomization.yaml
# Read the file, find the images: section, and replace it
python3 -c "
import yaml

with open('$KUSTOMIZE_OVERLAY/kustomization.yaml', 'r') as f:
    kustomization = yaml.safe_load(f)

with open('/tmp/kustomization_update.yaml', 'r') as f:
    updates = yaml.safe_load(f)

kustomization['images'] = updates['images']

with open('$KUSTOMIZE_OVERLAY/kustomization.yaml', 'w') as f:
    yaml.dump(kustomization, f, default_flow_style=False, sort_keys=False)
"

log_success "Kustomization overlay updated"

# Commit Kustomize changes
git add "$KUSTOMIZE_OVERLAY/kustomization.yaml"
if ! git diff --staged --quiet; then
    git commit -m "chore: Update $ENVIRONMENT overlay to version v$VERSION"

    if [[ "$ENVIRONMENT" == "dev" ]]; then
        git push origin main
    else
        git push origin release/$MAJOR_MINOR
    fi

    log_success "Kustomization changes committed and pushed"
fi

# Deploy using GitHub Actions workflow
log_info "Triggering deployment to $ENVIRONMENT via GitHub Actions..."

# Determine which workflow to use
if [[ "$ENVIRONMENT" == "dev" ]]; then
    # For dev, use direct deployment (no ServiceNow)
    gh workflow run deploy-application.yaml \
        --field environment=$ENVIRONMENT

    log_success "Deployment triggered for $ENVIRONMENT"
    log_info "Monitor deployment: gh run list --workflow=deploy-application.yaml"
else
    # For qa/prod, use ServiceNow hybrid workflow
    gh workflow run deploy-with-servicenow-hybrid.yaml \
        --field environment=$ENVIRONMENT

    log_success "Deployment triggered for $ENVIRONMENT with ServiceNow change management"
    log_info "Monitor deployment: gh run list --workflow=deploy-with-servicenow-hybrid.yaml"
    log_warning "Remember to approve the ServiceNow change request!"
fi

# Switch back to main if we were on a release branch
if [[ "$ENVIRONMENT" != "dev" ]]; then
    log_info "Merging release branch back to main"
    git checkout main
    git merge release/$MAJOR_MINOR --no-edit
    git push origin main
    log_success "Release branch merged back to main"
fi

# Summary
echo ""
log_success "🎉 Release v$VERSION deployment initiated for $ENVIRONMENT!"
echo ""
echo "Summary:"
echo "  ✅ Version: $VERSION"
echo "  ✅ Environment: $ENVIRONMENT"
echo "  ✅ Images built and pushed: 11 services × 4 tags = 44 images"
if [[ "$ENVIRONMENT" != "dev" ]]; then
    echo "  ✅ Release branch: release/$MAJOR_MINOR"
    echo "  ✅ Git tag: v$VERSION"
fi
echo "  ✅ Kustomize overlay updated: $KUSTOMIZE_OVERLAY"
echo "  ✅ Deployment triggered via GitHub Actions"
echo ""
echo "Next steps:"
if [[ "$ENVIRONMENT" != "dev" ]]; then
    echo "  1. Approve ServiceNow change request"
    echo "  2. Monitor deployment: gh run watch"
    echo "  3. View release: https://github.com/Freundcloud/microservices-demo/releases/tag/v$VERSION"
else
    echo "  1. Monitor deployment: gh run watch"
    echo "  2. Check dev environment: kubectl get pods -n microservices-dev"
fi
echo ""
