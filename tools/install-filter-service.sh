#!/usr/bin/env bash
# Installs and starts one of the Omatoys input filter services. Runs as root,
# normally via pkexec from the Omatoys bar widget.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'This script must run as root.\n' >&2
  exit 1
fi

tools_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
filter="${1:-}"

case "$filter" in
  key | click) ;;
  *)
    printf 'Usage: %s <key|click>\n' "$0" >&2
    exit 2
    ;;
esac

helper_source="$tools_dir/input-filter/omatoys-input-filter.py"
helper_target="/usr/local/libexec/omatoys-input-filter"
service_source="$tools_dir/input-filter/omatoys-$filter-filter.service"
service_name="omatoys-$filter-filter.service"
service_target="/etc/systemd/system/$service_name"

for source in "$helper_source" "$service_source"; do
  if [[ ! -f "$source" ]]; then
    printf 'Missing source file: %s\n' "$source" >&2
    exit 1
  fi
done

pacman -S --needed --noconfirm python-evdev
install -Dm755 "$helper_source" "$helper_target"
install -Dm644 "$service_source" "$service_target"
# Earlier versions shipped a separate binary per filter; drop the strays.
rm -f /usr/local/libexec/omatoys-key-filter /usr/local/libexec/omatoys-click-filter
systemctl daemon-reload
systemctl enable --now "$service_name"
