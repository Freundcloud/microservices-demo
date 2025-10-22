#!/bin/bash
# Enterprise ECR Image Multi-Tagging Script
#
# Purpose: Apply multiple tags to ECR images for version tracking, security scanning, and audit
# Usage: ./tag-ecr-images-with-version.sh <version> <git-sha> [environment]
#
# Example: ./tag-ecr-images-with-version.sh v1.2.3 e48fda1b dev

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="eu-west-2"
ACCOUNT_ID="533267307120"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Microservices to tag
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
  "shoppingassistantservice"
)

# Functions
usage() {
  cat <<EOF
${BLUE}Enterprise ECR Image Multi-Tagging Script${NC}

${YELLOW}Usage:${NC}
  $0 <semantic-version> <git-sha> [environment] [options]

${YELLOW}Arguments:${NC}
  semantic-version   Semantic version (e.g., v1.2.3)
  git-sha            Git commit SHA (short or full)
  environment        Environment name (default: dev) [optional]

${YELLOW}Options:${NC}
  --source-tag TAG   Source tag to use (default: latest untagged image)
  --build-time TIME  Build timestamp (default: current time)
  --dry-run          Show what would be done without making changes
  --help             Show this help message

${YELLOW}Examples:${NC}
  # Tag images with version v1.2.3 from commit e48fda1b for dev environment
  $0 v1.2.3 e48fda1b dev

  # Tag images using semantic version and git SHA only
  $0 v1.2.3 e48fda1b

  # Dry run to see what would happen
  $0 v1.2.3 e48fda1b dev --dry-run

  # Use specific source tag
  $0 v1.2.3 e48fda1b prod --source-tag dev

${YELLOW}Tags Created:${NC}
  For each service, the following tags will be created:
  - <semantic-version>        (e.g., v1.2.3) - Immutable release version
  - git-<short-sha>           (e.g., git-e48fda1) - Git commit reference
  - <environment>             (e.g., dev) - Mutable environment tag
  - build-<timestamp>         (e.g., build-20251022-083045) - Build audit trail

${YELLOW}Purpose:${NC}
  - Security scanning with Trivy/Snyk
  - Compliance and audit requirements
  - Version tracking across environments
  - Rollback capabilities
  - Change management integration

${YELLOW}See Also:${NC}
  docs/VERSION-TRACKING-STRATEGY.md

EOF
  exit 1
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
if [ $# -lt 2 ]; then
  usage
fi

SEMANTIC_VERSION="$1"
GIT_SHA="$2"
ENVIRONMENT="${3:-dev}"
SOURCE_TAG=""
BUILD_TIME=$(date '+%Y%m%d-%H%M%S')
DRY_RUN=false

# Parse options
shift 2
if [ $# -gt 0 ]; then
  shift 1  # Skip environment if provided
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --source-tag)
      SOURCE_TAG="$2"
      shift 2
      ;;
    --build-time)
      BUILD_TIME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate semantic version format
if [[ ! "$SEMANTIC_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  log_error "Semantic version must be in format v<major>.<minor>.<patch> (e.g., v1.2.3)"
  exit 1
fi

# Get short SHA if full SHA provided
SHORT_SHA="${GIT_SHA:0:7}"

# Display configuration
echo ""
log_info "==================================================================="
log_info "          Enterprise ECR Image Multi-Tagging"
log_info "==================================================================="
echo ""
log_info "Configuration:"
echo "  Registry:          ${REGISTRY}"
echo "  Semantic Version:  ${SEMANTIC_VERSION}"
echo "  Git SHA:           ${GIT_SHA}"
echo "  Short SHA:         ${SHORT_SHA}"
echo "  Environment:       ${ENVIRONMENT}"
echo "  Build Time:        ${BUILD_TIME}"
echo "  Source Tag:        ${SOURCE_TAG:-<latest untagged image>}"
echo "  Dry Run:           ${DRY_RUN}"
echo ""

if [ "$DRY_RUN" = true ]; then
  log_warning "DRY RUN MODE - No changes will be made"
  echo ""
fi

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  log_error "AWS credentials not configured or invalid"
  log_error "Please run: source .envrc"
  exit 1
fi

log_success "AWS credentials validated"
echo ""

# Process each service
TOTAL_SERVICES=${#SERVICES[@]}
CURRENT=0
TAGGED_COUNT=0
FAILED_COUNT=0

for service in "${SERVICES[@]}"; do
  CURRENT=$((CURRENT + 1))
  echo ""
  log_info "[$CURRENT/$TOTAL_SERVICES] Processing: ${service}"
  echo "-------------------------------------------------------------------"

  # Determine source image and get manifest
  if [ -n "$SOURCE_TAG" ]; then
    # Use specified source tag
    SOURCE_IMAGE="${REGISTRY}/${service}:${SOURCE_TAG}"
    log_info "  Source: ${SOURCE_TAG} tag"

    # Check if source tag exists and get manifest
    if ! MANIFEST=$(aws ecr batch-get-image \
      --repository-name "$service" \
      --region "$REGION" \
      --image-ids imageTag="$SOURCE_TAG" \
      --query 'images[0].imageManifest' \
      --output text 2>/dev/null); then
      log_warning "  Source tag '${SOURCE_TAG}' not found in ${service}, skipping"
      FAILED_COUNT=$((FAILED_COUNT + 1))
      continue
    fi
  else
    # Find most recent image
    DIGEST=$(aws ecr describe-images \
      --repository-name "$service" \
      --region "$REGION" \
      --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageDigest' \
      --output text 2>/dev/null || echo "")

    if [ -z "$DIGEST" ] || [ "$DIGEST" == "None" ]; then
      log_warning "  No images found in ${service}, skipping"
      FAILED_COUNT=$((FAILED_COUNT + 1))
      continue
    fi

    SOURCE_IMAGE="${REGISTRY}/${service}@${DIGEST}"
    log_info "  Source: Latest image (${DIGEST:0:19}...)"

    # Get manifest by digest
    MANIFEST=$(aws ecr batch-get-image \
      --repository-name "$service" \
      --region "$REGION" \
      --image-ids imageDigest="$DIGEST" \
      --query 'images[0].imageManifest' \
      --output text 2>/dev/null || echo "")
  fi

  # Validate manifest
  log_info "  Fetching image manifest..."

  if [ -z "$MANIFEST" ] || [ "$MANIFEST" == "None" ]; then
    log_error "  Failed to fetch manifest for ${service}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  log_success "  Manifest fetched successfully"

  # Define all tags to apply
  TAGS=(
    "${SEMANTIC_VERSION}"           # v1.2.3
    "git-${SHORT_SHA}"              # git-e48fda1
    "${ENVIRONMENT}"                # dev/qa/prod
    "build-${BUILD_TIME}"           # build-20251022-083045
  )

  # Apply each tag
  log_info "  Applying tags:"
  for tag in "${TAGS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
      echo "    [DRY RUN] Would tag: ${service}:${tag}"
    else
      if echo "$MANIFEST" | aws ecr put-image \
        --repository-name "$service" \
        --region "$REGION" \
        --image-tag "$tag" \
        --image-manifest file:///dev/stdin \
        --output json &>/dev/null; then
        echo "    ✓ ${tag}"
      else
        log_warning "    ✗ ${tag} (may already exist)"
      fi
    fi
  done

  log_success "  ${service} tagged successfully"
  TAGGED_COUNT=$((TAGGED_COUNT + 1))
done

# Summary
echo ""
echo "==================================================================="
log_info "                        SUMMARY"
echo "==================================================================="
echo ""
echo "Total Services:    ${TOTAL_SERVICES}"
echo "Successfully Tagged: ${GREEN}${TAGGED_COUNT}${NC}"
echo "Failed/Skipped:    ${RED}${FAILED_COUNT}${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
  log_success "Multi-tagging completed!"
  echo ""
  log_info "Verify tags with:"
  echo "  aws ecr describe-images --repository-name frontend --region ${REGION}"
  echo ""
  log_info "View in AWS Console:"
  echo "  https://${REGION}.console.aws.amazon.com/ecr/repositories/private/${ACCOUNT_ID}/frontend"
else
  log_info "Dry run completed - no changes were made"
  echo ""
  log_info "To apply these tags, run without --dry-run flag"
fi

echo ""

exit 0
