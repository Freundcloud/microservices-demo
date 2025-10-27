#!/bin/bash
# Retag existing ECR images with version numbers

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <source-tag> <target-version>"
    echo "Example: $0 dev 1.1.6"
    exit 1
fi

SOURCE_TAG="$1"
TARGET_VERSION="$2"
REGION="eu-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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

echo "🏷️  Retagging ECR images from '$SOURCE_TAG' to '$TARGET_VERSION'"
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    echo "Processing $SERVICE..."
    
    # Get the image manifest for the source tag
    MANIFEST=$(aws ecr batch-get-image \
        --repository-name "$SERVICE" \
        --image-ids imageTag="$SOURCE_TAG" \
        --region "$REGION" \
        --query 'images[0].imageManifest' \
        --output text 2>/dev/null)
    
    if [ -z "$MANIFEST" ] || [ "$MANIFEST" == "None" ]; then
        echo "  ⚠️  No image found with tag '$SOURCE_TAG', skipping"
        continue
    fi
    
    # Put the same image with the new tag
    aws ecr put-image \
        --repository-name "$SERVICE" \
        --image-tag "$TARGET_VERSION" \
        --image-manifest "$MANIFEST" \
        --region "$REGION" >/dev/null 2>&1
    
    echo "  ✅ Tagged ${SERVICE}:${TARGET_VERSION}"
done

echo ""
echo "✅ Retagging complete!"
echo ""
echo "Update kustomization with:"
echo "  sed -i 's/newTag: .*/newTag: ${TARGET_VERSION}/' kustomize/overlays/*/kustomization.yaml"
