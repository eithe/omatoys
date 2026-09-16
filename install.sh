#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/lib/omatoys-common.sh
source "$project_dir/tools/lib/omatoys-common.sh"

plugin_id="$(omatoys_manifest_id "$project_dir/manifest.json")" ||
  omatoys_die "Cannot read a plugin id from $project_dir/manifest.json"
plugin_target="$(omatoys_config_home)/omarchy/plugins/$plugin_id"

mkdir -p "$(dirname -- "$plugin_target")"

if [[ -L "$plugin_target" ]]; then
  link_target="$(readlink -f "$plugin_target")"
  if [[ "$link_target" != "$(readlink -f "$project_dir")" ]]; then
    omatoys_die "Refusing to replace plugin link pointing outside this project: $link_target"
  fi
  rm "$plugin_target"
elif [[ -e "$plugin_target" ]]; then
  installed_id=""
  if [[ -d "$plugin_target" ]]; then
    installed_id="$(omatoys_manifest_id "$plugin_target/manifest.json" || true)"
  fi
  if [[ "$installed_id" != "$plugin_id" ]]; then
    omatoys_die "Refusing to replace existing unrelated plugin path: $plugin_target"
  fi
  rm -rf "$plugin_target"
fi

mkdir "$plugin_target"
# Ship only what the running plugin needs; skip VCS metadata and dev scripts.
tar -c -C "$project_dir" \
  --exclude=.git \
  --exclude=.github \
  --exclude=.claude \
  --exclude=install.sh \
  --exclude=uninstall.sh \
  --exclude=tests \
  --exclude=pyproject.toml \
  --exclude=__pycache__ \
  . | tar -x -C "$plugin_target"
printf 'Installed Omatoys plugin: %s\n' "$plugin_target"

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
fi
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable "$plugin_id"
fi

elevate="$(omatoys_elevation_tool)" ||
  omatoys_die 'A privilege escalation tool (sudo or pkexec) is required for the input filters.'
"$elevate" pacman -S --needed --noconfirm python-evdev

# Stage the privileged helper into its root-owned directory now. This is the
# supported way to update it after source changes, and it means the first
# filter enable never has to run anything out of the plugin directory as root.
"$elevate" "$plugin_target/tools/install-filter-service.sh" --stage
