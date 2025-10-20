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

# Packages and pushes Online Boutique's Helm chart to AWS ECR.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT=$SCRIPT_DIR/../..

log() { echo "$1" >&2; }

TAG="${TAG:?TAG env variable must be specified}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID env variable must be specified}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
HELM_CHART_REPO="${HELM_CHART_REPO:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/helm-charts}"

# Ensure ECR repository exists for Helm charts
log "Ensuring ECR repository exists for Helm charts..."
aws ecr describe-repositories --repository-names helm-charts --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name helm-charts --region "$AWS_REGION" >/dev/null

# Login to ECR for Helm
log "Logging in to AWS ECR for Helm..."
aws ecr get-login-password --region "$AWS_REGION" | \
    helm registry login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

cd "${REPO_ROOT}/helm-chart"

# Update Chart.yaml with new version
# Use sed or gsed depending on platform
if command -v gsed >/dev/null 2>&1; then
    SED_CMD="gsed"
else
    SED_CMD="sed"
fi

$SED_CMD -i "s/^appVersion:.*/appVersion: \"${TAG}\"/" Chart.yaml
$SED_CMD -i "s/^version:.*/version: ${TAG:1}/" Chart.yaml

# Package and push the Helm chart
helm package .
helm push onlineboutique-${TAG:1}.tgz oci://$HELM_CHART_REPO

# Cleanup
rm ./onlineboutique-${TAG:1}.tgz

log "Successfully built and pushed the Helm chart to ECR."
