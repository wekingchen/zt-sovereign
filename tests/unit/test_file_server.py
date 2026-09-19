#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
SERVER = ROOT / "rootfs/usr/local/bin/file_server.py"


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


def get(url: str, headers: dict[str, str] | None = None) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=2) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


with tempfile.TemporaryDirectory() as td:
    base = Path(td)
    dist = base / "dist"
    cfg = base / "config"
    dist.mkdir()
    (dist / "planet").write_bytes(b"test-planet")
    (dist / "abc.moon").write_bytes(b"test-moon")
    port = free_port()
    env = os.environ.copy()
    env.update(
        {
            "DIST_DIR": str(dist),
            "CONFIG_DIR": str(cfg),
            "PLANET_FILE_SERVER_PORT": str(port),
            "PLANET_FILE_SERVER_BIND": "127.0.0.1",
            "PLANET_FILE_KEY": "unit-test-key",
        }
    )
    proc = subprocess.Popen([str(SERVER)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        base_url = f"http://127.0.0.1:{port}"
        for _ in range(50):
            try:
                if get(base_url + "/healthz")[0] == 200:
                    break
            except OSError:
                pass
            time.sleep(0.1)
        else:
            raise SystemExit("file server did not start")

        assert get(base_url + "/planet")[0] == 401
        status, body = get(base_url + "/planet?key=unit-test-key")
        assert status == 200 and body == b"test-planet"
        status, body = get(base_url + "/moon/abc.moon", {"Authorization": "Bearer unit-test-key"})
        assert status == 200 and body == b"test-moon"
        assert get(base_url + "/moon/../planet?key=unit-test-key")[0] == 404
        assert (cfg / "file_server.key").read_text().strip() == "unit-test-key"
    finally:
        proc.terminate()
        proc.wait(timeout=5)

print("PASS test_file_server")
