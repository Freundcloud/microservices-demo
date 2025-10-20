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

# Builds and pushes Docker images for each microservice to AWS ECR.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT=$SCRIPT_DIR/../..

log() { echo "$1" >&2; }

TAG="${TAG:?TAG env variable must be specified}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID env variable must be specified}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
REPO_PREFIX="${REPO_PREFIX:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com}"

# Login to ECR
log "Logging in to AWS ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$REPO_PREFIX"

# Build and push images
while IFS= read -d $'\0' -r dir; do
    svcname="$(basename "${dir}")"
    builddir="${dir}"

    # PR 516 moved cartservice build artifacts one level down to src
    if [ "$svcname" == "cartservice" ]; then
        builddir="${dir}/src"
    fi

    image="${REPO_PREFIX}/$svcname:$TAG"
    image_latest="${REPO_PREFIX}/$svcname:latest"

    (
        cd "${builddir}"
        log "Building image: ${image}"

        # Build for multiple architectures
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag "${image}" \
            --tag "${image_latest}" \
            --push \
            .

        log "Successfully built and pushed: ${image}"
    )
done < <(find "${REPO_ROOT}/src" -mindepth 1 -maxdepth 1 -type d -print0)

log "Successfully built and pushed all images to ECR."
