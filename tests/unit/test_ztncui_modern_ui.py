#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "ui" / "ztncui" / "src"
views = ui / "views"
css = (ui / "public" / "stylesheets" / "style.css").read_text(encoding="utf-8")
head = (views / "head_layout.pug").read_text(encoding="utf-8")
detail = (views / "network_detail.pug").read_text(encoding="utf-8")
login = (views / "login.pug").read_text(encoding="utf-8")

required_css = [
    "--zt-primary:",
    ".app-container",
    ".page-surface",
    ".auth-card",
    ".network-actions",
    ".table-responsive",
    ".status-pill",
    ".detail-grid",
    ".metric-grid",
    ".setting-row",
    "@media (max-width: 767px)",
]
errors = [f"style.css missing {token}" for token in required_css if token not in css]

required_head = [
    "width=device-width, initial-scale=1, viewport-fit=cover",
    "ZeroTier Sovereign",
    "网络控制台",
    "app-footer",
]
errors += [f"head_layout.pug missing {token}" for token in required_head if token not in head]

# Bootstrap's table-responsive class belongs on a wrapper, not on <table>.
for path in views.glob("*.pug"):
    text = path.read_text(encoding="utf-8")
    if "table.table.table-responsive" in text:
        errors.append(f"{path.name}: legacy table.table.table-responsive remains")

# Preserve the existing member-management hooks and login field names.
for token in (".authCheck", ".bridgeCheck", ".text", "id='members'"):
    if token not in detail:
        errors.append(f"network_detail.pug lost functional hook {token}")

for token in ("name='username'", "name='password'"):
    if token not in login:
        errors.append(f"login.pug lost functional field {token}")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)

print("PASS test_ztncui_modern_ui")
