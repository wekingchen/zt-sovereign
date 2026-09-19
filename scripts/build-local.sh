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
  --build-arg "PLANET_ZEROTIER_VERSION=${PLANET_ZEROTIER_VERSION}" \
  --build-arg "PLANET_ZEROTIER_SOURCE_REF=${PLANET_ZEROTIER_SOURCE_REF}" \
  --build-arg "CONTROLLER_ZEROTIER_VERSION=${CONTROLLER_ZEROTIER_VERSION}" \
  --build-arg "CONTROLLER_ZEROTIER_SOURCE_REF=${CONTROLLER_ZEROTIER_SOURCE_REF}" \
  --build-arg "ZTNET_VERSION=${ZTNET_VERSION}" \
  --build-arg "ZTNET_SOURCE_REF=${ZTNET_SOURCE_REF}" \
  --build-arg "NEXT_PUBLIC_APP_VERSION=${ZTNET_VERSION}" \
  --build-arg "NODEJS_IMAGE=${ZTNET_NODE_IMAGE}" \
  -t "$image" .

echo "Built $image"
