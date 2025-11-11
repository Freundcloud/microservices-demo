#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=${1:-}
TAG=${2:-}

if [[ -z "$ENVIRONMENT" || -z "$TAG" ]]; then
  echo "Usage: $0 <env: dev|qa|prod> <tag>" >&2
  exit 1
fi

case "$ENVIRONMENT" in
dev | qa | prod) ;;
*)
  echo "Invalid environment: $ENVIRONMENT (expected dev|qa|prod)" >&2
  exit 1
  ;;
esac

FILE="kustomize/overlays/${ENVIRONMENT}/kustomization.yaml"
if [[ ! -f "$FILE" ]]; then
  echo "Overlay file not found: $FILE" >&2
  exit 1
fi

echo "🔧 Bumping ${ENVIRONMENT} image tags to ${TAG} in ${FILE}"

# Check if all newTag values are already set to the target tag
CURRENT_TAGS=$(grep -E '^\s*newTag:' "$FILE" | awk '{print $2}' | sort -u)
if [[ "$CURRENT_TAGS" == "$TAG" ]]; then
  echo "ℹ️  All image tags are already set to ${TAG} for ${ENVIRONMENT}"
  echo "✅ No changes needed"
  exit 0
fi

# Replace all newTag values to the desired tag (safe in-place with backup)
sed -i.bak -E "s/^(\s*newTag:)\s*.*/\1 ${TAG}/" "$FILE"
rm -f "${FILE}.bak"

echo "✅ Updated image tags to ${TAG} for ${ENVIRONMENT}"
