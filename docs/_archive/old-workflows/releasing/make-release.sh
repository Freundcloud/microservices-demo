#!/usr/bin/env bash

# Copyright 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script creates a new release by:
# - 1. building/pushing images to AWS ECR
# - 2. injecting tags into YAML manifests
# - 3. creating a new git tag
# - 4. pushing the tag/commit to main.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT=$SCRIPT_DIR/../..
[[ -n "${DEBUG:-}" ]] && set -x

log() { echo "$1" >&2; }
fail() { log "$1"; exit 1; }

TAG="${TAG:?TAG env variable must be specified}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID env variable must be specified}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
REPO_PREFIX="${REPO_PREFIX:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com}"

if [[ "$TAG" != v* ]]; then
    fail "\$TAG must start with 'v', e.g. v0.1.0 (got: $TAG)"
fi

# Ensure there are no uncommitted changes
if [[ $(git status -s | wc -l) -gt 0 ]]; then
    echo "error: can't have uncommitted changes"
    exit 1
fi

# Verify AWS credentials are configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    fail "AWS credentials are not configured. Run 'aws configure' or 'source .envrc'"
fi

# Make sure local source is up to date
git checkout main
git pull

# Build and push images to ECR
log "Building and pushing Docker images to ECR..."
"${SCRIPT_DIR}"/make-docker-images.sh

# Update YAML manifests with new image tags
log "Updating Kubernetes and Istio manifests..."
"${SCRIPT_DIR}"/make-release-artifacts.sh

# Build and push Helm chart to ECR
log "Building and pushing Helm chart to ECR..."
"${SCRIPT_DIR}"/make-helm-chart.sh

# Create git release / push to new branch
log "Creating release branch and tag..."
git checkout -b "release/${TAG}"
git add "${REPO_ROOT}/release/"
git add "${REPO_ROOT}/kustomize/base/"
git add "${REPO_ROOT}/helm-chart/"
git commit --allow-empty -m "Release $TAG"
log "Pushing k8s manifests to release/${TAG}..."
git tag "$TAG"
git push --set-upstream origin "release/${TAG}"
git push --tags

log "Successfully tagged release $TAG."
log ""
log "Next steps:"
log "  1. Create a pull request for branch 'release/${TAG}' on GitHub"
log "  2. Review and merge the PR"
log "  3. Create a GitHub release with notes"
log "  4. Deploy to EKS: kubectl apply -f ./release/kubernetes-manifests.yaml"
log "  5. Apply Istio routing: kubectl apply -f ./release/istio-manifests.yaml"
