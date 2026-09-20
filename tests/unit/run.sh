#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
./tests/unit/test_planetctl.sh
python3 ./tests/unit/test_file_server.py
python3 ./tests/unit/test_ztncui_zh_cn.py
python3 ./tests/unit/test_ztncui_modern_ui.py
./tests/unit/test_version_sync.sh
