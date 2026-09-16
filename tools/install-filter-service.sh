#!/usr/bin/env bash
# Installs and starts one of the Omatoys input filter services. Runs as root,
# normally via pkexec from the Omatoys bar widget.
#
# This script runs from one of two places:
#
#   1. The plugin directory under ~/.config, the first time a filter is
#      enabled. That directory is writable by the user, so this is the one
#      moment Omatoys executes user-writable content as root. It is also the
#      moment this script copies itself, the helper, and the unit files into
#      LIB_DIR, which is root-owned.
#
#   2. LIB_DIR, for every enable after that. The bar widget prefers that copy
#      whenever it exists, so the plugin directory is never executed as root
#      again.
#
# Re-staging after a plugin update is deliberate and never automatic:
#   sudo <plugin-dir>/tools/install-filter-service.sh --stage
# Re-staging automatically whenever the plugin copy differed from the staged
# one would defeat the whole arrangement, because "this file changed" is
# exactly what an attacker who rewrote it would produce.
set -euo pipefail

readonly LIB_DIR="/usr/local/lib/omatoys"
readonly HELPER_TARGET="$LIB_DIR/omatoys-input-filter"
readonly INSTALLER_TARGET="$LIB_DIR/install-filter-service.sh"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'This script must run as root.\n' >&2
  exit 1
fi

self="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
mode="${1:-}"

case "$mode" in
  key | click | --stage) ;;
  *)
    printf 'Usage: %s <key|click|--stage>\n' "$0" >&2
    exit 2
    ;;
esac

# Where this invocation reads its sources from. Staged copies sit flat in
# LIB_DIR; the plugin checkout keeps them under tools/input-filter/.
if [[ "$self" == "$INSTALLER_TARGET" ]]; then
  already_staged=true
  helper_source="$HELPER_TARGET"
  unit_source_dir="$LIB_DIR"
else
  already_staged=false
  helper_source="$(dirname -- "$self")/input-filter/omatoys-input-filter.py"
  unit_source_dir="$(dirname -- "$self")/input-filter"
fi

unit_source() {
  printf '%s/omatoys-%s-filter.service\n' "$unit_source_dir" "$1"
}

require_sources() {
  local filter unit
  if [[ ! -f "$helper_source" ]]; then
    printf 'Missing helper: %s\n' "$helper_source" >&2
    exit 1
  fi
  for filter in key click; do
    unit="$(unit_source "$filter")"
    if [[ ! -f "$unit" ]]; then
      printf 'Missing unit file: %s\n' "$unit" >&2
      exit 1
    fi
  done
}

# Copy the helper, both unit files, and this script into the root-owned
# directory. install(1) writes root:root because we are root and no --owner is
# given, and it replaces the target atomically rather than truncating it.
stage_into_lib_dir() {
  local filter
  install -Dm755 "$helper_source" "$HELPER_TARGET"
  install -Dm755 "$self" "$INSTALLER_TARGET"
  for filter in key click; do
    install -Dm644 "$(unit_source "$filter")" "$LIB_DIR/omatoys-$filter-filter.service"
  done
  printf 'Staged the Omatoys filter helper and units in %s\n' "$LIB_DIR"
}

# Refresh any unit already present in /etc and restart what is running, so a
# re-stage actually takes effect.
refresh_installed_units() {
  local filter installed changed=false
  for filter in key click; do
    installed="/etc/systemd/system/omatoys-$filter-filter.service"
    if [[ -f "$installed" ]]; then
      install -Dm644 "$LIB_DIR/omatoys-$filter-filter.service" "$installed"
      changed=true
    fi
  done
  if [[ "$changed" == true ]]; then
    systemctl daemon-reload
    for filter in key click; do
      if systemctl is-active --quiet "omatoys-$filter-filter.service"; then
        systemctl restart "omatoys-$filter-filter.service"
      fi
    done
  fi
}

require_sources

if [[ "$already_staged" == false ]]; then
  stage_into_lib_dir
fi

if [[ "$mode" == "--stage" ]]; then
  if [[ "$already_staged" == true ]]; then
    printf 'Already running from %s; nothing to stage.\n' "$LIB_DIR" >&2
    exit 1
  fi
  refresh_installed_units
  printf 'Re-staged. Any installed filter services were restarted.\n'
  exit 0
fi

# python-evdev is the only runtime dependency. Checking first keeps toggling a
# filter fast, and keeps it working offline once the package is present.
if ! python3 -c 'import evdev' >/dev/null 2>&1; then
  pacman -S --needed --noconfirm python-evdev
fi

service_name="omatoys-$mode-filter.service"
install -Dm644 "$LIB_DIR/$service_name" "/etc/systemd/system/$service_name"
# Earlier versions installed the helper under libexec; drop the strays so
# nothing keeps running from the old location.
rm -f \
  /usr/local/libexec/omatoys-input-filter \
  /usr/local/libexec/omatoys-key-filter \
  /usr/local/libexec/omatoys-click-filter
systemctl daemon-reload
systemctl enable --now "$service_name"
