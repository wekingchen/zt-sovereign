#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
source ./versions.env
set +a

python3 - <<'PY'
from pathlib import Path
import os

path = Path('.env.example')
text = path.read_text()
keys = [
    'SOVEREIGN_VERSION',
    'PLANET_ZEROTIER_VERSION',
    'PLANET_ZEROTIER_SOURCE_REF',
    'CONTROLLER_ZEROTIER_VERSION',
    'CONTROLLER_ZEROTIER_SOURCE_REF',
    'ZTNET_VERSION',
    'ZTNET_SOURCE_REF',
    'ZTNET_NODE_IMAGE',
]
lines = text.splitlines()
for i, line in enumerate(lines):
    for key in keys:
        if line.startswith(key + '='):
            lines[i] = f"{key}={os.environ[key]}"
path.write_text('\n'.join(lines) + '\n')
PY
