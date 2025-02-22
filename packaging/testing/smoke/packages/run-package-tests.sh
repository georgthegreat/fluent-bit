#!/bin/bash
# Copyright 2021 Calyptia, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file  except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the  License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eux
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

PACKAGE_TEST=${PACKAGE_TEST:-centos7}
RELEASE_URL=${RELEASE_URL:-https://packages.fluentbit.io}
STAGING_URL=${STAGING_URL:-https://fluentbit-staging.s3.amazonaws.com}

if [[ ! -f "$SCRIPT_DIR/Dockerfile.$PACKAGE_TEST" ]]; then
    echo "No definition for $SCRIPT_DIR/Dockerfile.$PACKAGE_TEST"
    exit 1
fi

declare -a CONTAINER_TARGETS=("official-install" "staging-install" "staging-upgrade")

# Build all containers required
for TARGET in "${CONTAINER_TARGETS[@]}"
do
    BUILD_ARGS=""
    if [[ $TARGET == "staging-upgrade" ]]; then
        BUILD_ARGS="--build-arg STAGING_BASE=staging-upgrade-prep"
    fi

    CONTAINER_NAME="package-verify-$PACKAGE_TEST-$TARGET"

    docker rm -f "$CONTAINER_NAME"

    # We do want splitting for build args
    # shellcheck disable=SC2086
    docker build \
                --build-arg STAGING_URL=$STAGING_URL \
                --build-arg RELEASE_URL=$RELEASE_URL $BUILD_ARGS \
                --target "$TARGET" \
                -t "$CONTAINER_NAME" \
                -f "$SCRIPT_DIR/Dockerfile.$PACKAGE_TEST" "$SCRIPT_DIR/"

    docker run --rm -d \
        --privileged \
        -v /sys/fs/cgroup/:/sys/fs/cgroup:ro \
        --name "$CONTAINER_NAME" \
        "$CONTAINER_NAME"

    docker exec -t "$CONTAINER_NAME" /test.sh

    docker rm -f "$CONTAINER_NAME"
done
