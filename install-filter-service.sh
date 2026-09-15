#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'This script must run as root.\\n' >&2
  exit 1
fi

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
filter="${1:-}"

case "$filter" in
  key)
    helper_source="$project_dir/key-filter/omatoys-key-filter.py"
    service_source="$project_dir/key-filter/omatoys-key-filter.service"
    helper_target="/usr/local/libexec/omatoys-key-filter"
    service_target="/etc/systemd/system/omatoys-key-filter.service"
    service_name="omatoys-key-filter.service"
    ;;
  click)
    helper_source="$project_dir/click-filter/omatoys-click-filter.py"
    service_source="$project_dir/click-filter/omatoys-click-filter.service"
    helper_target="/usr/local/libexec/omatoys-click-filter"
    service_target="/etc/systemd/system/omatoys-click-filter.service"
    service_name="omatoys-click-filter.service"
    ;;
  *)
    printf 'Usage: %s <key|click>\\n' "$0" >&2
    exit 2
    ;;
esac

install -Dm755 "$helper_source" "$helper_target"
install -Dm644 "$service_source" "$service_target"
systemctl daemon-reload
systemctl enable --now "$service_name"
