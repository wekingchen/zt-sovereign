#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
./tests/unit/test_planetctl.sh
python3 ./tests/unit/test_file_server.py
./tests/unit/test_version_sync.sh
