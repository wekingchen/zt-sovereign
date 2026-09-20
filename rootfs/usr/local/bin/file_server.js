#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const path = require("path");

const DIST = process.env.DIST_DIR || "/data/planet/dist";
const CONFIG = process.env.CONFIG_DIR || "/data/planet/config";
const PORT = Number(process.env.PLANET_FILE_SERVER_PORT || "3001");
const BIND = process.env.PLANET_FILE_SERVER_BIND || "0.0.0.0";
const KEY_FILE = path.join(CONFIG, "file_server.key");

function safeEqual(a, b) {
  const aa = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return aa.length === bb.length && crypto.timingSafeEqual(aa, bb);
}

function loadKey() {
  fs.mkdirSync(CONFIG, { recursive: true });
  const envKey = (process.env.PLANET_FILE_KEY || "").trim();
  if (fs.existsSync(KEY_FILE)) {
    const key = fs.readFileSync(KEY_FILE, "utf8").trim();
    if (envKey && !safeEqual(key, envKey)) {
      console.warn("WARNING: PLANET_FILE_KEY differs from persisted key; persisted key wins.");
    }
    return key;
  }
  const key = envKey || crypto.randomBytes(24).toString("hex");
  fs.writeFileSync(KEY_FILE, `${key}\n`, { encoding: "utf8", mode: 0o600 });
  fs.chmodSync(KEY_FILE, 0o600);
  console.log(`Generated persistent file-server key at ${KEY_FILE}`);
  return key;
}

const SECRET = loadKey();

function sendJson(res, code, obj) {
  const body = Buffer.from(`${JSON.stringify(obj)}\n`);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": String(body.length),
  });
  res.end(body);
}

function authorized(req, query) {
  const qkey = query.get("key") || "";
  const auth = req.headers.authorization || "";
  const bearer = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : "";
  const candidate = qkey || bearer;
  return Boolean(candidate) && safeEqual(candidate, SECRET);
}

function resolveArtifact(target) {
  const distReal = fs.realpathSync(DIST);
  const resolved = fs.realpathSync(target);
  if (path.dirname(resolved) !== distReal || !fs.statSync(resolved).isFile()) {
    throw new Error("invalid artifact path");
  }
  return resolved;
}

const server = http.createServer((req, res) => {
  const rawUrl = req.url || "/";
  const qpos = rawUrl.indexOf("?");
  const rawPath = qpos >= 0 ? rawUrl.slice(0, qpos) : rawUrl;
  const queryText = qpos >= 0 ? rawUrl.slice(qpos + 1) : "";
  let pathname;
  try {
    pathname = decodeURIComponent(rawPath);
  } catch {
    return sendJson(res, 400, { error: "bad request" });
  }
  const query = new URLSearchParams(queryText);

  if (pathname === "/healthz") {
    return sendJson(res, 200, { ok: true });
  }
  if (!authorized(req, query)) {
    return sendJson(res, 401, { error: "unauthorized" });
  }

  if (pathname === "/files") {
    const files = fs.existsSync(DIST)
      ? fs.readdirSync(DIST)
          .filter((name) => name === "planet" || name.endsWith(".moon"))
          .filter((name) => fs.statSync(path.join(DIST, name)).isFile())
          .sort()
      : [];
    return sendJson(res, 200, { files });
  }

  let target;
  if (pathname === "/planet") {
    target = path.join(DIST, "planet");
  } else if (pathname.startsWith("/moon/")) {
    const name = path.posix.basename(pathname);
    if (!name.endsWith(".moon") || name === "." || name === "..") {
      return sendJson(res, 404, { error: "not found" });
    }
    target = path.join(DIST, name);
  } else {
    return sendJson(res, 404, { error: "not found" });
  }

  try {
    const resolved = resolveArtifact(target);
    const body = fs.readFileSync(resolved);
    res.writeHead(200, {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": `attachment; filename="${path.basename(resolved)}"`,
      "Content-Length": String(body.length),
    });
    res.end(body);
  } catch {
    sendJson(res, 404, { error: "not found" });
  }
});

server.listen(PORT, BIND, () => {
  console.log(`PLANET file server listening on ${BIND}:${PORT}`);
});
