#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_target="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.eithe.omatoys"
shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"

if [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
  elevate=(sudo)
elif command -v pkexec >/dev/null 2>&1; then
  elevate=(pkexec)
else
  printf 'A privilege escalation tool (sudo or pkexec) is required.\\n' >&2
  exit 1
fi

if [[ -L "$plugin_target" ]]; then
  link_target="$(readlink -f "$plugin_target")"
  expected_target="$(readlink -f "$project_dir")"
  if [[ "$link_target" == "$expected_target" ]]; then
    rm "$plugin_target"
  else
    printf 'Refusing to remove plugin link pointing outside this project: %s\\n' "$link_target" >&2
    exit 1
  fi
elif [[ -d "$plugin_target" ]]; then
  if ! python3 - "$plugin_target/manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except (OSError, ValueError):
    raise SystemExit(1)
raise SystemExit(0 if data.get("id") == "io.github.eithe.omatoys" else 1)
PY
  then
    printf 'Refusing to remove plugin directory without an Omatoys manifest: %s\\n' "$plugin_target" >&2
    exit 1
  fi
  rm -rf "$plugin_target"
elif [[ -e "$plugin_target" ]]; then
  printf 'Refusing to remove unsupported plugin path: %s\\n' "$plugin_target" >&2
  exit 1
fi

if [[ -f "$shell_config" ]]; then
  python3 - "$shell_config" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
layout = data.get("bar", {}).get("layout", {})
for section in ("left", "center", "right"):
    entries = layout.get(section, [])
    layout[section] = [entry for entry in entries if entry.get("id") != "io.github.eithe.omatoys"]
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
fi

for service in omatoys-key-filter.service omatoys-click-filter.service; do
  "${elevate[@]}" systemctl disable --now "$service" 2>/dev/null || true
done

"${elevate[@]}" rm -f \
  /etc/systemd/system/omatoys-key-filter.service \
  /etc/systemd/system/omatoys-click-filter.service \
  /usr/local/libexec/omatoys-key-filter \
  /usr/local/libexec/omatoys-click-filter
"${elevate[@]}" systemctl daemon-reload

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
fi

printf 'Omatoys has been uninstalled. The shared python-evdev package was left installed.\\n'
