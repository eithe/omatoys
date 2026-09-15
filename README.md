# Omatoys

Omatoys is a shareable collection of small productivity tools for Omarchy.
Tools are available from the Omatoys icon in the Omarchy top bar.

## Available tools

- **Cleaning Mode** — Captures keyboard and pointer input while you clean
  your keyboard. Press Escape five times to exit.
- **Key Filter** — Filters accidental duplicate keyboard presses caused by a
  worn keyboard. It is off by default and currently uses a separate 10 ms
  debounce window.
- **Click Filter** — Filters rapid repeated left, right, and middle mouse
  clicks. It is off by default and currently uses a separate 25 ms debounce
  window.
- **Focus Follows Mouse** — Disables Hyprland's behavior of focusing a window
  when the pointer moves over it. It is off by default.

Key Filter and Click Filter can be enabled independently. Enabling a filter
starts its systemd service immediately and enables it for future boots;
disabling it stops the service and removes its boot-time enablement.

## Installation

Install the published plugin through Omarchy:

```bash
omarchy plugin add https://github.com/eithe/omatoys.git --enable
```

The plugin is identified as `io.github.eithe.omatoys` and appears in the
configured bar layout. Key Filter and Click Filter install `python-evdev`,
their helper, and their systemd service only when first enabled.

For development from a local checkout, clone the project and run the
installer:

```bash
git clone https://github.com/eithe/omatoys.git omatoys
cd omatoys
./install.sh
```

The development installer:

- Copies the Omatoys shell plugin under
  `~/.config/omarchy/plugins/io.github.eithe.omatoys/`.
- Installs `python-evdev` with the Arch package manager.
- Reloads the Omarchy shell.

The privileged input helpers are not installed during normal setup. The first
time a user enables Key Filter or Click Filter from the Omatoys menu, that
filter's helper and systemd service are installed through a graphical
`pkexec` authentication prompt, started immediately, and enabled for future
boots. Disabling a filter stops the service and removes its boot-time
enablement, but leaves its installed files available for the next enable.

To remove the project-managed installation, run:

```bash
./uninstall.sh
```

The uninstall script removes the Omatoys plugin directory, removes its bar
entry from `~/.config/omarchy/shell.json`, disables and stops both filter
services, removes their systemd units and helper binaries, reloads systemd,
and reloads the Omarchy shell. It intentionally leaves the shared
`python-evdev` package installed because other applications may use it.

The equivalent manual cleanup is:

```bash
pkexec systemctl disable --now omatoys-key-filter.service
pkexec systemctl disable --now omatoys-click-filter.service
pkexec rm -f \
  /etc/systemd/system/omatoys-key-filter.service \
  /etc/systemd/system/omatoys-click-filter.service \
  /usr/local/libexec/omatoys-key-filter \
  /usr/local/libexec/omatoys-click-filter
pkexec systemctl daemon-reload
rm -rf ~/.config/omarchy/plugins/io.github.eithe.omatoys
```

## Development

The plugin entry point lives in the repository root, and individual tools
live under `tools/`. Install it into the
current user's Omarchy configuration with:

```bash
./install.sh
```

The installer copies the plugin into the user's Omarchy plugin directory.
Rerun the installer after source changes, then use a plugin rescan or shell
restart.

## Cleaning Mode

Click the Omatoys bar icon, choose **Cleaning Mode**, and press Escape five
times to exit. While active, keyboard and pointer input are captured and a
theme-aware dialog explains how to unlock it.
