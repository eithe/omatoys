#!/usr/bin/env bash
# Shared helpers for the Omatoys install and uninstall scripts.
# Source this file; do not execute it.

# Print a message to stderr.
omatoys_warn() {
  printf '%s\n' "$*" >&2
}

# Print a message to stderr and exit non-zero.
omatoys_die() {
  omatoys_warn "$@"
  exit 1
}

# Read the "id" field out of a manifest.json. Prints nothing and returns 1 when
# the file is missing, unreadable, not JSON, or has no string id.
omatoys_manifest_id() {
  python3 -c '
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text())
except (OSError, ValueError):
    raise SystemExit(1)
plugin_id = data.get("id") if isinstance(data, dict) else None
if not isinstance(plugin_id, str) or not plugin_id:
    raise SystemExit(1)
print(plugin_id)
' "$1"
}

# The user config root Omarchy reads from.
omatoys_config_home() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

# Choose a privilege escalation tool, preferring sudo on a terminal and falling
# back to pkexec for graphical invocations. Populates the named array.
omatoys_select_elevate() {
  local -n _elevate="$1"
  if [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
    _elevate=(sudo)
  elif command -v pkexec >/dev/null 2>&1; then
    _elevate=(pkexec)
  else
    omatoys_die 'A privilege escalation tool (sudo or pkexec) is required.'
  fi
}
