#!/usr/bin/env python3
"""Minimal authenticated file server for generated PLANET/moon artifacts."""
from __future__ import annotations

import hmac
import http.server
import json
import os
import pathlib
import secrets
import urllib.parse

DIST = pathlib.Path(os.environ.get("DIST_DIR", "/data/planet/dist"))
CONFIG = pathlib.Path(os.environ.get("CONFIG_DIR", "/data/planet/config"))
PORT = int(os.environ.get("PLANET_FILE_SERVER_PORT", "3001"))
BIND = os.environ.get("PLANET_FILE_SERVER_BIND", "0.0.0.0")
KEY_FILE = CONFIG / "file_server.key"


def load_key() -> str:
    CONFIG.mkdir(parents=True, exist_ok=True)
    env_key = os.environ.get("PLANET_FILE_KEY", "").strip()
    if KEY_FILE.exists():
        key = KEY_FILE.read_text(encoding="utf-8").strip()
        if env_key and not hmac.compare_digest(key, env_key):
            print("WARNING: PLANET_FILE_KEY differs from persisted key; persisted key wins.", flush=True)
        return key
    key = env_key or secrets.token_hex(24)
    KEY_FILE.write_text(key + "\n", encoding="utf-8")
    os.chmod(KEY_FILE, 0o600)
    print(f"Generated persistent file-server key at {KEY_FILE}", flush=True)
    return key


SECRET = load_key()


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "ZTPlanetFiles/2.0"

    def _json(self, code: int, obj: dict) -> None:
        body = (json.dumps(obj, ensure_ascii=False) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self, query: dict[str, list[str]]) -> bool:
        qkey = (query.get("key") or [""])[0]
        auth = self.headers.get("Authorization", "")
        bearer = auth[7:].strip() if auth.lower().startswith("bearer ") else ""
        candidate = qkey or bearer
        return bool(candidate) and hmac.compare_digest(candidate, SECRET)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path == "/healthz":
            return self._json(200, {"ok": True})

        query = urllib.parse.parse_qs(parsed.query)
        if not self._authorized(query):
            return self._json(401, {"error": "unauthorized"})

        if parsed.path == "/files":
            names = (
                sorted(p.name for p in DIST.iterdir() if p.is_file() and (p.name == "planet" or p.suffix == ".moon"))
                if DIST.exists()
                else []
            )
            return self._json(200, {"files": names})

        if parsed.path == "/planet":
            target = DIST / "planet"
        elif parsed.path.startswith("/moon/"):
            name = pathlib.PurePosixPath(parsed.path).name
            if not name.endswith(".moon") or name in {".", ".."}:
                return self._json(404, {"error": "not found"})
            target = DIST / name
        else:
            return self._json(404, {"error": "not found"})

        try:
            resolved = target.resolve(strict=True)
            if resolved.parent != DIST.resolve() or not resolved.is_file():
                raise FileNotFoundError
        except (FileNotFoundError, RuntimeError):
            return self._json(404, {"error": "not found"})

        body = resolved.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Disposition", f'attachment; filename="{resolved.name}"')
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} - {fmt % args}", flush=True)


if __name__ == "__main__":
    http.server.ThreadingHTTPServer((BIND, PORT), Handler).serve_forever()
