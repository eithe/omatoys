#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_target="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.eithe.omatoys"

mkdir -p "$(dirname -- "$plugin_target")"

if [[ -L "$plugin_target" ]]; then
  link_target="$(readlink -f "$plugin_target")"
  if [[ "$link_target" != "$(readlink -f "$project_dir")" ]]; then
    printf 'Refusing to replace plugin link pointing outside this project: %s\n' "$link_target" >&2
    exit 1
  fi
  rm "$plugin_target"
elif [[ -e "$plugin_target" ]]; then
  printf 'Refusing to replace existing plugin directory: %s\n' "$plugin_target" >&2
  exit 1
fi

mkdir "$plugin_target"
cp -a "$project_dir/." "$plugin_target/"
printf 'Installed Omatoys plugin: %s\n' "$plugin_target"

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
