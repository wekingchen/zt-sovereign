#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

set -a
# shellcheck disable=SC1091
source ./versions.env
set +a

image=${SOVEREIGN_IMAGE:-zerotier-sovereign:local}

docker build \
  --build-arg "SOVEREIGN_VERSION=${SOVEREIGN_VERSION}" \
  --build-arg "ZEROTIER_VERSION=${ZEROTIER_VERSION}" \
  --build-arg "ZEROTIER_SOURCE_REF=${ZEROTIER_SOURCE_REF}" \
  --build-arg "MKWORLD_SOURCE_REF=${MKWORLD_SOURCE_REF}" \
  --build-arg "NODEJS_IMAGE=${NODEJS_IMAGE}" \
  -t "$image" .

echo "Built $image"
