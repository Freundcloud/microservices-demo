#!/usr/bin/env bash
# Bump version for a specific service in a specific environment
# Usage: ./bump-service-version.sh <env> <service> <version>
# Example: ./bump-service-version.sh dev paymentservice 1.1.5.1

set -euo pipefail

ENVIRONMENT=${1:-}
SERVICE=${2:-}
VERSION=${3:-}

if [[ -z "$ENVIRONMENT" || -z "$SERVICE" || -z "$VERSION" ]]; then
  echo "Usage: $0 <env: dev|qa|prod> <service> <version>" >&2
  echo ""
  echo "Examples:"
  echo "  $0 dev paymentservice 1.1.5.1"
  echo "  $0 qa cartservice v2.0.1"
  echo "  $0 prod adservice 1.2.0"
  echo ""
  echo "Available services:"
  echo "  adservice, cartservice, checkoutservice, currencyservice,"
  echo "  emailservice, frontend, loadgenerator, paymentservice,"
  echo "  productcatalogservice, recommendationservice, shippingservice,"
  echo "  shoppingassistantservice"
  exit 1
fi

# Validate environment
case "$ENVIRONMENT" in
dev | qa | prod) ;;
*)
  echo "❌ Invalid environment: $ENVIRONMENT (expected dev|qa|prod)" >&2
  exit 1
  ;;
esac

# Validate service name
VALID_SERVICES=(
  "adservice"
  "cartservice"
  "checkoutservice"
  "currencyservice"
  "emailservice"
  "frontend"
  "loadgenerator"
  "paymentservice"
  "productcatalogservice"
  "recommendationservice"
  "shippingservice"
  "shoppingassistantservice"
)

SERVICE_VALID=false
for valid_service in "${VALID_SERVICES[@]}"; do
  if [[ "$SERVICE" == "$valid_service" ]]; then
    SERVICE_VALID=true
    break
  fi
done

if [[ "$SERVICE_VALID" == "false" ]]; then
  echo "❌ Invalid service: $SERVICE" >&2
  echo "Valid services: ${VALID_SERVICES[*]}" >&2
  exit 1
fi

FILE="kustomize/overlays/${ENVIRONMENT}/kustomization.yaml"
if [[ ! -f "$FILE" ]]; then
  echo "❌ Overlay file not found: $FILE" >&2
  exit 1
fi

echo "🔧 Bumping ${SERVICE} version to ${VERSION} in ${ENVIRONMENT}"
echo "📁 File: ${FILE}"

# Update only the specific service's newTag
# This uses awk to find the service name (including full image paths) and update the NEXT newTag line
awk -v service="$SERVICE" -v version="$VERSION" '
  /^  - name:/ {
    # Extract service name from full image path if present
    # e.g., us-central1-docker.pkg.dev/google-samples/microservices-demo/paymentservice
    name_field = $3
    split(name_field, parts, "/")
    extracted_service = parts[length(parts)]

    if (extracted_service == service || name_field == service) {
      found = 1
    } else {
      found = 0
    }
  }
  /^    newTag:/ {
    if (found) {
      print "    newTag: " version
      found = 0
      next
    }
  }
  { print }
' "$FILE" > "${FILE}.tmp"

# Check if anything actually changed
if ! diff -q "$FILE" "${FILE}.tmp" >/dev/null 2>&1; then
  mv "${FILE}.tmp" "$FILE"
  echo "✅ Updated ${SERVICE} to version ${VERSION} in ${ENVIRONMENT}"
  echo ""
  echo "📋 Changes made:"
  git diff "$FILE" | grep -A 2 -B 2 "$SERVICE" || true
else
  rm "${FILE}.tmp"
  echo "⚠️  No changes made - service may not exist or version already set"
  exit 1
fi
