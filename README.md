# Omatoys

Omatoys is a shareable collection of small productivity tools for Omarchy.
Tools are available from the Omatoys icon in the Omarchy top bar.

## Available tools

- **Cleaning Mode** — Captures keyboard and pointer input while you clean
  your keyboard. Every connected monitor is covered. Press Escape five times
  to exit.
- **Key Filter** — Filters accidental duplicate keyboard presses caused by a
  worn keyboard. It is off by default and uses a 10 ms debounce window.
- **Click Filter** — Filters rapid repeated left, right, and middle mouse
  clicks. It is off by default and uses a 25 ms debounce window. Touchpads,
  touchscreens, and graphics tablets are deliberately left alone.
- **Focus Follows Mouse** — Disables Hyprland's behavior of focusing a window
  when the pointer moves over it. It is off by default.

Key Filter and Click Filter can be enabled independently. Enabling a filter
starts its systemd service immediately and enables it for future boots;
disabling it stops the service and removes its boot-time enablement. If a
service is enabled but not running, the menu says so instead of reporting it
as on, and a failed action shows its error at the bottom of the menu.

Both filters keep watching for input devices while they run, so a keyboard or
mouse plugged in later is filtered too, and unplugging one does not stop the
service.

## Installation

Install the published plugin through Omarchy:

```bash
omarchy plugin add https://github.com/eithe/omatoys.git --enable
```

The plugin is identified as `io.github.eithe.omatoys` and appears in the
configured bar layout. Key Filter and Click Filter install `python-evdev`,
their shared helper, and their systemd service only when first enabled.

For development from a local checkout, clone the project and run the
installer:

```bash
git clone https://github.com/eithe/omatoys.git omatoys
cd omatoys
./install.sh
```

The development installer:

- Copies the Omatoys shell plugin under
  `~/.config/omarchy/plugins/io.github.eithe.omatoys/`, excluding VCS metadata
  and the development scripts.
- Installs `python-evdev` with the Arch package manager.
- Reloads the Omarchy shell.

The privileged input helper is not installed during normal setup. The first
time a user enables Key Filter or Click Filter from the Omatoys menu, the
shared helper and that filter's systemd service are installed through a
graphical `pkexec` authentication prompt, started immediately, and enabled for
future boots. Disabling a filter stops the service and removes its boot-time
enablement, but leaves the installed files available for the next enable.

### Tuning the debounce windows

Both services read `OMATOYS_FILTER_WINDOW_MS`, so a window can be changed
without editing the source:

```bash
sudo systemctl edit omatoys-key-filter.service
```

```ini
[Service]
Environment=OMATOYS_FILTER_WINDOW_MS=20
```

Then `sudo systemctl restart omatoys-key-filter.service`. An unset, invalid, or
negative value falls back to the built-in default.

## Uninstalling

To remove the project-managed installation, run:

```bash
./uninstall.sh
```

The uninstall script removes the Omatoys plugin directory, removes its bar
entry from `~/.config/omarchy/shell.json` (writing a `.omatoys-backup` copy
first and swapping the file atomically), disables and stops both filter
services, removes their systemd units and the helper binary, reloads systemd,
and reloads the Omarchy shell. It intentionally leaves the shared
`python-evdev` package installed because other applications may use it.

The equivalent manual cleanup is:

```bash
pkexec systemctl disable --now omatoys-key-filter.service
pkexec systemctl disable --now omatoys-click-filter.service
pkexec rm -f \
  /etc/systemd/system/omatoys-key-filter.service \
  /etc/systemd/system/omatoys-click-filter.service \
  /usr/local/libexec/omatoys-input-filter
pkexec systemctl daemon-reload
rm -rf ~/.config/omarchy/plugins/io.github.eithe.omatoys
```

## Development

The plugin entry point lives in the repository root and individual tools live
under `tools/`:

| Path | Purpose |
| --- | --- |
| `BarWidget.qml` | Bar entry point and the tools menu |
| `tools/cleaning-mode/` | The full-screen input-blocking overlay |
| `tools/focus-follows-mouse/` | Hyprland `follow_mouse` toggle |
| `tools/input-filter/` | Shared key and click debounce helper, plus its units |
| `tools/install-filter-service.sh` | Root-side installer, invoked via `pkexec` |
| `tools/lib/omatoys-common.sh` | Helpers shared by `install.sh` and `uninstall.sh` |

Install into the current user's Omarchy configuration with `./install.sh`.
Rerun the installer after source changes, then use a plugin rescan or shell
restart.

Both filters are the same program, `tools/input-filter/omatoys-input-filter.py`,
selected by a `key` or `click` argument in the unit file. It is installed once
as `/usr/local/libexec/omatoys-input-filter`.

The plugin id lives in `manifest.json` and is read from there by the install
and uninstall scripts. `BarWidget.qml` repeats it as `moduleName`; CI fails if
the two drift apart.

### Checks

CI runs shellcheck over the shell scripts, `ruff` over the Python, the unit
tests, and a manifest consistency check. To run the same checks locally:

```bash
shellcheck install.sh uninstall.sh tools/install-filter-service.sh \
  tools/focus-follows-mouse/toggle.sh tools/lib/omatoys-common.sh
ruff check .
python -m unittest discover -s tests
python3 .github/scripts/check-manifest.py
```

The tests stub out device access, so they run unprivileged, but they do import
`evdev` for its event code constants.
