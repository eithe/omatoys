#!/usr/bin/env bash
# Exercises tools/install-filter-service.sh without root, by rewriting the
# absolute paths it touches and stubbing pacman and systemctl. The control
# flow, the staged-versus-plugin detection, and where files land are all the
# real thing.
#
# The property this exists to protect: once the helper has been staged into the
# root-owned directory, enabling a filter must never again read anything out of
# the user-writable plugin directory.
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

lib="$work/lib/omatoys"
etc="$work/etc/systemd/system"
libexec="$work/libexec"
bin="$work/bin"
plugin="$work/plugin"
mkdir -p "$etc" "$libexec" "$bin" "$plugin/tools/input-filter"
# GNU install -D would create this; pre-creating it keeps the test runnable on
# systems with BSD install too.
mkdir -p "$lib"

# Stub the privileged commands and record what they were asked to do.
for cmd in pacman systemctl; do
  cat >"$bin/$cmd" <<EOF
#!/bin/sh
echo "$cmd \$*" >>"$work/calls.log"
# 'systemctl is-active --quiet' must report "not running" so restart is skipped.
case "\$*" in *is-active*) exit 1 ;; esac
exit 0
EOF
  chmod +x "$bin/$cmd"
done
export PATH="$bin:$PATH"
: >"$work/calls.log"

# Build a plugin-directory layout from the real sources, with absolute paths
# redirected into the sandbox and the root guard removed.
# shellcheck disable=SC2016  # the ${EUID} below is a literal sed pattern, not an expansion
sed \
  -e "s|/usr/local/lib/omatoys|$lib|g" \
  -e "s|/etc/systemd/system|$etc|g" \
  -e "s|/usr/local/libexec|$libexec|g" \
  -e '/^if \[\[ "${EUID}" -ne 0 \]\]; then$/,/^fi$/d' \
  "$repo/tools/install-filter-service.sh" >"$plugin/tools/install-filter-service.sh"
chmod +x "$plugin/tools/install-filter-service.sh"
cp "$repo/tools/input-filter/omatoys-input-filter.py" "$plugin/tools/input-filter/"
for unit in "$repo"/tools/input-filter/*.service; do
  sed "s|/usr/local/lib/omatoys|$lib|g" "$unit" \
    >"$plugin/tools/input-filter/$(basename "$unit")"
done

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- 1. Bootstrap from the plugin directory ---------------------------------
"$plugin/tools/install-filter-service.sh" key >"$work/out1.log" 2>&1 || {
  cat "$work/out1.log" >&2
  fail "bootstrap run exited non-zero"
}

[[ -x "$lib/omatoys-input-filter" ]] || fail "helper was not staged"
[[ -x "$lib/install-filter-service.sh" ]] || fail "installer did not stage itself"
[[ -f "$lib/omatoys-key-filter.service" ]] || fail "key unit was not staged"
[[ -f "$lib/omatoys-click-filter.service" ]] || fail "click unit was not staged"
[[ -f "$etc/omatoys-key-filter.service" ]] || fail "key unit was not installed"
[[ -f "$etc/omatoys-click-filter.service" ]] && fail "click unit should not be installed yet"
grep -q "enable --now omatoys-key-filter.service" "$work/calls.log" ||
  fail "key service was not enabled"
grep -q "pacman -S" "$work/calls.log" || fail "python-evdev install was not attempted"
printf 'ok 1: bootstrap stages helper, units and installer, and enables the key filter\n'

# --- 2. A later run from the staged copy ignores the plugin directory -------
echo "# TAMPERED" >>"$plugin/tools/input-filter/omatoys-input-filter.py"
: >"$work/calls.log"

"$lib/install-filter-service.sh" click >"$work/out2.log" 2>&1 || {
  cat "$work/out2.log" >&2
  fail "staged run exited non-zero"
}

[[ -f "$etc/omatoys-click-filter.service" ]] || fail "click unit was not installed"
grep -q "enable --now omatoys-click-filter.service" "$work/calls.log" ||
  fail "click service was not enabled"
if grep -q "TAMPERED" "$lib/omatoys-input-filter"; then
  fail "SECURITY: the staged run copied the tampered plugin helper"
fi
if grep -q "Staged the Omatoys" "$work/out2.log"; then
  fail "staged run re-staged instead of using the root-owned copy"
fi
printf 'ok 2: staged run ignores a tampered plugin copy and does not re-stage\n'

# --- 3. An explicit --stage does pick up genuine changes --------------------
: >"$work/calls.log"
"$plugin/tools/install-filter-service.sh" --stage >"$work/out3.log" 2>&1 || {
  cat "$work/out3.log" >&2
  fail "--stage exited non-zero"
}
grep -q "TAMPERED" "$lib/omatoys-input-filter" || fail "--stage did not refresh the helper"
grep -q "daemon-reload" "$work/calls.log" || fail "--stage did not reload systemd"
printf 'ok 3: explicit --stage refreshes the staged helper and reloads systemd\n'

# --- 4. --stage from the staged copy is refused -----------------------------
if "$lib/install-filter-service.sh" --stage >"$work/out4.log" 2>&1; then
  fail "--stage from the staged copy should have failed"
fi
grep -q "nothing to stage" "$work/out4.log" || fail "wrong error for a staged --stage"
printf 'ok 4: --stage from the staged copy is refused\n'

# --- 5. Invalid modes -------------------------------------------------------
if "$lib/install-filter-service.sh" bogus >/dev/null 2>&1; then
  fail "an unknown mode should have failed"
fi
if "$lib/install-filter-service.sh" >/dev/null 2>&1; then
  fail "a missing mode should have failed"
fi
printf 'ok 5: invalid modes are rejected\n'

printf '\nAll install-filter-service tests passed.\n'
