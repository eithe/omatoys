#!/usr/bin/env bash
set -euo pipefail

state_file="$HOME/.local/state/omarchy/toggles/hypr/omatoys-focus-follows-mouse.lua"

case "${1:-}" in
  status)
    if [[ -f "$state_file" ]]; then
      printf 'disabled\n'
    else
      printf 'enabled\n'
    fi
    ;;
  on)
    mkdir -p "$(dirname -- "$state_file")"
    printf '%s\n' \
      'hl.config({' \
      '  input = {' \
      '    follow_mouse = 0,' \
      '  },' \
      '})' >"$state_file"
    hyprctl reload >/dev/null
    ;;
  off)
    rm -f "$state_file"
    hyprctl reload >/dev/null
    ;;
  *)
    printf 'Usage: %s {status|on|off}\n' "$0" >&2
    exit 2
    ;;
esac
