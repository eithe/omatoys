#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_source="$project_dir/plugin/local.omatoys"
plugin_target="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/local.omatoys"
filter_source="$project_dir/key-filter/omatoys-key-filter.py"
click_filter_source="$project_dir/click-filter/omatoys-click-filter.py"

mkdir -p "$(dirname -- "$plugin_target")"

if [[ -e "$plugin_target" && ! -L "$plugin_target" ]]; then
  printf 'Refusing to replace existing non-symlink: %s\n' "$plugin_target" >&2
  exit 1
fi

ln -sfn "$plugin_source" "$plugin_target"
printf 'Installed Omatoys plugin: %s -> %s\n' "$plugin_target" "$plugin_source"

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
fi

if [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
  elevate=(sudo)
elif command -v pkexec >/dev/null 2>&1; then
  elevate=(pkexec)
else
  printf 'A privilege escalation tool (sudo or pkexec) is required for Key Filter.\\n' >&2
  exit 1
fi

"${elevate[@]}" pacman -S --needed --noconfirm python-evdev
