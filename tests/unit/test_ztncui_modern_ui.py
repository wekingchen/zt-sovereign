#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "ui" / "ztncui" / "src"
views = ui / "views"
css = (ui / "public" / "stylesheets" / "style.css").read_text(encoding="utf-8")
head = (views / "head_layout.pug").read_text(encoding="utf-8")
detail = (views / "network_detail.pug").read_text(encoding="utf-8")
login = (views / "login.pug").read_text(encoding="utf-8")
controller_layout = (views / "controller_layout.pug").read_text(encoding="utf-8")
users_layout = (views / "users_layout.pug").read_text(encoding="utf-8")
login_layout = (views / "login_layout.pug").read_text(encoding="utf-8")
networks = (views / "networks.pug").read_text(encoding="utf-8")
member_detail = (views / "member_detail.pug").read_text(encoding="utf-8")
member_delete = (views / "member_delete.pug").read_text(encoding="utf-8")
not_implemented = (views / "not_implemented.pug").read_text(encoding="utf-8")
network_detail = (views / "network_detail.pug").read_text(encoding="utf-8")
routes = (views / "routes.pug").read_text(encoding="utf-8")
users = (views / "users.pug").read_text(encoding="utf-8")
pools = (views / "ipAssignmentPools.pug").read_text(encoding="utf-8")
assignments = (views / "ipAssignments.pug").read_text(encoding="utf-8")

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
    ".context-header",
    ".btn-link-danger",
    ".mobile-stack",
    "safe-area-inset-top",
    "safe-area-inset-bottom",
    "100dvh",
    "@media (max-width: 359px)",
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

for token in ("apple-mobile-web-app-capable", "black-translucent", "telephone=no"):
    if token not in head:
        errors.append(f"head_layout.pug missing iOS metadata {token}")

if "min-width: 720px" in css:
    errors.append("mobile CSS must not force 720px tables")

if 'font-size: 16px;' not in css:
    errors.append("mobile form controls must use 16px font size to avoid iOS focus zoom")

# Bootstrap's table-responsive class belongs on a wrapper, not on <table>.
for path in views.glob("*.pug"):
    text = path.read_text(encoding="utf-8")
    if "table.table.table-responsive" in text:
        errors.append(f"{path.name}: legacy table.table.table-responsive remains")

# Preserve the existing member-management hooks and login field names.
for token in (".authCheck", ".bridgeCheck", ".text", "h3#members"):
    if token not in detail:
        errors.append(f"network_detail.pug lost functional hook {token}")

for token in ("name='username'", "name='password'"):
    if token not in login:
        errors.append(f"login.pug lost functional field {token}")

# Global navigation contains modules only; creation actions are contextual.
for label in ("新建网络", "新建管理员"):
    if label in controller_layout or label in users_layout:
        errors.append(f"global navigation must not contain contextual action {label}")

if "block nav_toggle" not in login_layout or "block nav_login" not in login_layout:
    errors.append("login layout must suppress redundant navbar actions")

# Empty/list states must not render two primary creation CTAs at once.
if "if networks && networks.length" not in networks:
    errors.append("networks.pug must conditionally separate populated and empty CTAs")

# Context header is the single return mechanism on nested network pages.
if "返回成员列表" in member_detail:
    errors.append("member_detail.pug has duplicate return action")
if "返回网络列表" in network_detail:
    errors.append("network_detail.pug has duplicate return action")
if "返回成员列表" in member_delete:
    errors.append("member_delete.pug has duplicate return action")
if "返回成员列表" in not_implemented:
    errors.append("not_implemented.pug has duplicate return action")

for name, text in {
    "networks.pug": networks,
    "users.pug": users,
    "routes.pug": routes,
    "ipAssignmentPools.pug": pools,
    "ipAssignments.pug": assignments,
    "network_detail.pug": network_detail,
}.items():
    if "mobile-stack" not in text:
        errors.append(f"{name}: mobile card table class missing")
    if "data-label=" not in text:
        errors.append(f"{name}: mobile field labels missing")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)

print("PASS test_ztncui_modern_ui")
