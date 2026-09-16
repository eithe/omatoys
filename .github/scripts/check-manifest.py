#!/usr/bin/env python3
"""Guard the plugin metadata that nothing else can type-check.

Verifies that manifest.json is well formed, that its entry points exist, that
the plugin id in BarWidget.qml still matches the manifest, and that each
systemd unit points at a helper this repository actually ships.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HELPER_TARGET = "/usr/local/lib/omatoys/omatoys-input-filter"

# The helper runs as root, so the units confine it. These are asserted here
# because a dropped line would weaken the sandbox silently and no test would
# notice.
REQUIRED_HARDENING = (
    "NoNewPrivileges=yes",
    "ProtectSystem=strict",
    "ProtectHome=yes",
    "PrivateNetwork=yes",
    "IPAddressDeny=any",
    "ProtectKernelModules=yes",
    "ProtectKernelTunables=yes",
    "RestrictNamespaces=yes",
    "RestrictSUIDSGID=yes",
    "LockPersonality=yes",
    "SystemCallFilter=@system-service",
    "CapabilityBoundingSet=CAP_DAC_OVERRIDE",
    "DevicePolicy=closed",
    "DeviceAllow=char-input rw",
    "DeviceAllow=/dev/uinput rw",
)

errors = []


def check(condition, message):
    if not condition:
        errors.append(message)
    return condition


manifest_path = ROOT / "manifest.json"
try:
    manifest = json.loads(manifest_path.read_text())
except (OSError, ValueError) as exc:
    print(f"manifest.json is not readable JSON: {exc}", file=sys.stderr)
    raise SystemExit(1) from exc

plugin_id = manifest.get("id")
check(isinstance(plugin_id, str) and plugin_id, "manifest.json has no string id")

for field in ("schemaVersion", "name", "version", "license", "description", "kinds"):
    check(field in manifest, f"manifest.json is missing {field!r}")

version = manifest.get("version", "")
check(
    bool(re.fullmatch(r"\d+\.\d+\.\d+", str(version))),
    f"manifest.json version {version!r} is not semver",
)

for name, relative in manifest.get("entryPoints", {}).items():
    check(
        (ROOT / relative).is_file(),
        f"entryPoints.{name} points at missing file {relative!r}",
    )

# The plugin id also appears as the widget's moduleName; keep the two in step.
bar_widget = (ROOT / "BarWidget.qml").read_text()
module_names = re.findall(r'moduleName:\s*"([^"]+)"', bar_widget)
check(
    module_names == [plugin_id],
    f"BarWidget.qml moduleName {module_names} does not match manifest id {plugin_id!r}",
)

# Every script the widget shells out to must exist at the path it resolves.
for relative in re.findall(r'scriptPath\("([^"]+)"\)', bar_widget):
    check((ROOT / relative).is_file(), f"BarWidget.qml references missing script {relative!r}")

units = sorted((ROOT / "tools" / "input-filter").glob("*.service"))
check(bool(units), "no systemd units found under tools/input-filter")
for unit in units:
    text = unit.read_text()
    exec_start = re.search(r"^ExecStart=(\S+)", text, re.MULTILINE)
    if check(exec_start is not None, f"{unit.name} has no ExecStart"):
        check(
            exec_start.group(1) == HELPER_TARGET,
            f"{unit.name} ExecStart is {exec_start.group(1)!r}, expected {HELPER_TARGET!r}",
        )
    check(
        "WantedBy=multi-user.target" in text,
        # graphical-session.target only exists in the user manager, so a system
        # unit wanted by it is never pulled in at boot.
        f"{unit.name} must be WantedBy=multi-user.target as a system unit",
    )
    for directive in REQUIRED_HARDENING:
        check(directive in text, f"{unit.name} is missing {directive!r}")
    check(
        # PrivateDevices gives the unit a minimal private /dev, which would
        # hide the very input devices the filter exists to read.
        "PrivateDevices=" not in text,
        f"{unit.name} must not set PrivateDevices; it would hide the input devices",
    )

# The widget must never elevate the plugin-directory copy once a root-owned
# one exists, so the staged path has to be an absolute literal it prefers.
check(
    f'"{HELPER_TARGET.rsplit("/", 1)[0]}/install-filter-service.sh"' in bar_widget,
    "BarWidget.qml does not reference the staged, root-owned installer path",
)

if errors:
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"manifest.json and entry points look consistent ({plugin_id} {version})")
