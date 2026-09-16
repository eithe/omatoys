#!/usr/bin/env bash
set -euo pipefail

state_file="$HOME/.local/state/omarchy/toggles/hypr/omatoys-focus-follows-mouse.lua"

case "${1:-}" in
  status)
    option="$(hyprctl getoption input:follow_mouse -j)"
    if [[ "$option" =~ \"int\"[[:space:]]*:[[:space:]]*[1-9] ]]; then
      printf 'enabled\n'
    else
      printf 'disabled\n'
    fi
    ;;
  on)
    rm -f "$state_file"
    hyprctl reload >/dev/null
    ;;
  off)
    mkdir -p "$(dirname -- "$state_file")"
    printf '%s\n' \
      'hl.config({' \
      '  input = {' \
      '    follow_mouse = 0,' \
      '  },' \
      '})' >"$state_file"
    hyprctl reload >/dev/null
    ;;
  *)
    printf 'Usage: %s {status|on|off}\n' "$0" >&2
    exit 2
    ;;
esac
