#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/lib/omatoys-common.sh
source "$project_dir/tools/lib/omatoys-common.sh"

plugin_id="$(omatoys_manifest_id "$project_dir/manifest.json")" ||
  omatoys_die "Cannot read a plugin id from $project_dir/manifest.json"
config_home="$(omatoys_config_home)"
plugin_target="$config_home/omarchy/plugins/$plugin_id"
shell_config="$config_home/omarchy/shell.json"

omatoys_select_elevate elevate

if [[ -L "$plugin_target" ]]; then
  link_target="$(readlink -f "$plugin_target")"
  if [[ "$link_target" != "$(readlink -f "$project_dir")" ]]; then
    omatoys_die "Refusing to remove plugin link pointing outside this project: $link_target"
  fi
  rm "$plugin_target"
elif [[ -d "$plugin_target" ]]; then
  installed_id="$(omatoys_manifest_id "$plugin_target/manifest.json" || true)"
  if [[ "$installed_id" != "$plugin_id" ]]; then
    omatoys_die "Refusing to remove plugin directory without an Omatoys manifest: $plugin_target"
  fi
  rm -rf "$plugin_target"
elif [[ -e "$plugin_target" ]]; then
  omatoys_die "Refusing to remove unsupported plugin path: $plugin_target"
fi

if [[ -f "$shell_config" ]]; then
  python3 - "$shell_config" "$plugin_id" <<'PY'
import json
import os
import sys
import tempfile
from pathlib import Path

path = Path(sys.argv[1])
plugin_id = sys.argv[2]

try:
    data = json.loads(path.read_text())
except (OSError, ValueError) as exc:
    print(f"Leaving {path} untouched: {exc}", file=sys.stderr)
    raise SystemExit(0)

bar = data.get("bar") if isinstance(data, dict) else None
layout = bar.get("layout") if isinstance(bar, dict) else None
if not isinstance(layout, dict):
    raise SystemExit(0)


def keep(entry):
    # Layout entries are usually objects, but tolerate bare id strings and any
    # other shape rather than aborting a half-finished uninstall.
    if isinstance(entry, dict):
        return entry.get("id") != plugin_id
    if isinstance(entry, str):
        return entry != plugin_id
    return True


changed = False
for section in ("left", "center", "right"):
    entries = layout.get(section)
    if not isinstance(entries, list):
        continue
    remaining = [entry for entry in entries if keep(entry)]
    if len(remaining) != len(entries):
        layout[section] = remaining
        changed = True

if not changed:
    raise SystemExit(0)

# Back up, then swap atomically so an interrupted write cannot leave the bar
# configuration truncated.
backup = path.with_suffix(path.suffix + ".omatoys-backup")
backup.write_text(path.read_text())
rendered = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
fd, tmp_name = tempfile.mkstemp(dir=str(path.parent), prefix=path.name + ".", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as handle:
        handle.write(rendered)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp_name, path)
except BaseException:
    Path(tmp_name).unlink(missing_ok=True)
    raise
print(f"Removed {plugin_id} from {path} (backup at {backup})")
PY
fi

for service in omatoys-key-filter.service omatoys-click-filter.service; do
  "${elevate[@]}" systemctl disable --now "$service" 2>/dev/null || true
done

"${elevate[@]}" rm -f \
  /etc/systemd/system/omatoys-key-filter.service \
  /etc/systemd/system/omatoys-click-filter.service \
  /usr/local/libexec/omatoys-input-filter \
  /usr/local/libexec/omatoys-key-filter \
  /usr/local/libexec/omatoys-click-filter
"${elevate[@]}" systemctl daemon-reload

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
fi

printf 'Omatoys has been uninstalled. The shared python-evdev package was left installed.\n'
