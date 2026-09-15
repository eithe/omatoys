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

Key Filter and Click Filter can be enabled independently. Enabling a filter
starts its systemd service immediately and enables it for future boots;
disabling it stops the service and removes its boot-time enablement.

## Installation

Clone the project and run the installer:

```bash
git clone <repository-url> omatoys
cd omatoys
./install.sh
```

The installer:

- Installs the Omatoys shell plugin as a symlink under
  `~/.config/omarchy/plugins/local.omatoys/`.
- Installs `python-evdev` with the Arch package manager.
- Installs the privileged Key Filter and Click Filter systemd services.
- Reloads the Omarchy shell.

The installer may show a graphical authentication prompt through `pkexec`
when installing the privileged input helpers. The helpers are disabled by
default. Enable a filter from the Omatoys menu to start it immediately and
persist it across reboots; disabling it stops the service and removes its
boot-time enablement.

To remove the project-managed installation, disable the services and remove
the plugin symlink:

```bash
pkexec systemctl disable --now omatoys-key-filter.service
pkexec systemctl disable --now omatoys-click-filter.service
rm ~/.config/omarchy/plugins/local.omatoys
```

## Development

The plugin source lives in `plugin/local.omatoys/`. Install it into the
current user's Omarchy configuration with:

```bash
./install.sh
```

The installer creates a symlink, so edits in this project are picked up by
the running Omarchy shell after a plugin rescan or shell restart.

## Cleaning Mode

Click the Omatoys bar icon, choose **Cleaning Mode**, and press Escape five
times to exit. While active, keyboard and pointer input are captured and a
theme-aware dialog explains how to unlock it.
