#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
workflow_dir = root / ".github" / "workflows"

required = {
    "actions/checkout": 5,
    "docker/setup-buildx-action": 4,
    "docker/login-action": 4,
    "docker/build-push-action": 7,
}

errors = []

for path in sorted(workflow_dir.glob("*.y*ml")):
    text = path.read_text(encoding="utf-8")
    for action, minimum in required.items():
        for match in re.finditer(rf"{re.escape(action)}@v(\d+)", text):
            major = int(match.group(1))
            if major < minimum:
                errors.append(
                    f"{path.relative_to(root)}: {action}@v{major} is below Node 24 baseline v{minimum}"
                )

deprecated_literals = (
    "actions/checkout@v4",
    "docker/setup-buildx-action@v3",
    "docker/login-action@v3",
    "docker/build-push-action@v6",
)
for path in sorted(workflow_dir.glob("*.y*ml")):
    text = path.read_text(encoding="utf-8")
    for token in deprecated_literals:
        if token in text:
            errors.append(f"{path.relative_to(root)}: deprecated Node 20 action remains: {token}")
    if "runs-on: ubuntu-latest" in text:
        errors.append(f"{path.relative_to(root)}: ubuntu-latest is not allowed; pin ubuntu-24.04 explicitly")

if errors:
    print("\n".join(errors))
    raise SystemExit(1)

print("PASS test_actions_node24_and_runner_pins")
