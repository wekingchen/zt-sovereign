#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "ui" / "ztncui" / "src"

files = list((ui / "views").glob("*.pug"))
files += [
    ui / "controllers" / "networkController.js",
    ui / "controllers" / "usersController.js",
    ui / "controllers" / "auth.js",
    ui / "routes" / "index.js",
]

forbidden = [
    "'Home'",
    "'Users'",
    "'Networks'",
    "'Add network'",
    "'Create user'",
    "|  Login",
    "|  Logout",
    " Network name:",
    " Member name:",
    " Member ID",
    " Authorized",
    " Active bridge",
    " Peer status",
    " Peer address / latency",
    " Easy setup",
    " Assignment Pools",
    " Managed routes",
    " Create Network",
    " Set password",
    " Change password on next login:",
    " Warning! Deleting",
    " There are no networks",
    " There are no members",
    " No such user",
    " You may not delete yourself",
    " Access denied!",
    " Authentication failed",
    " Network setup succeeded",
    " Target network is required",
    " Gateway must be a valid",
    " Network address is required",
    " Start of IP assignment pool",
    " End of IP assignment pool",
    "placeholder='e.g.",
]

errors = []
for path in files:
    text = path.read_text(encoding="utf-8")
    for phrase in forbidden:
        if phrase in text:
            errors.append(f"{path.relative_to(root)}: residual English UI phrase: {phrase!r}")

head = (ui / "views" / "head_layout.pug").read_text(encoding="utf-8")
if "html(lang='zh-CN')" not in head:
    errors.append("head_layout.pug: html lang is not zh-CN")

detail = (ui / "views" / "network_detail.pug").read_text(encoding="utf-8")
member = (ui / "views" / "member_detail.pug").read_text(encoding="utf-8")
if "zhLabel(key)" not in detail or "zhLabel(key)" not in member:
    errors.append("detail views must use zhLabel() for ZeroTier field names")

locale = (ui / "locales" / "zh-cn.js").read_text(encoding="utf-8")
for key in ("nwid", "private", "routes", "ipAssignmentPools", "authorized", "activeBridge", "ipAssignments"):
    if f"{key}:" not in locale:
        errors.append(f"zh-cn.js: missing field label for {key}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)

print("PASS test_ztncui_zh_cn")
